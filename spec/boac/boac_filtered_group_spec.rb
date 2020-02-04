require_relative '../../util/spec_helper'

test = BOACTestConfig.new
test.filtered_groups
test.students.shuffle!

group_1_students = test.students.first(1000)
group_1_sids = group_1_students.map &:sis_id
group_1_searchable_data = test.searchable_data.select { |d| group_1_sids.include? d[:sid] }

group_2_students = test.students.last(1000)
group_2_sids = group_2_students.map &:sis_id
group_2_searchable_data = test.searchable_data.select { |d| group_2_sids.include? d[:sid] }

all_searchable_data = group_1_searchable_data + group_2_searchable_data

describe 'A BOA filtered cohort' do

  include Logging

  before(:all) do

    @all_student_searchable_data = []
    @all_student_searchable_data << test.searchable_data
    @all_student_searchable_data.flatten!

    @students_to_add_remove = []
    @cohorts = []

    @group_1 = CuratedGroup.new(name: "Group 1 #{test.id}", members: [])
    @group_2 = CuratedGroup.new(name: "Group 2 #{test.id}", members: [])

    @driver = Utils.launch_browser
    @homepage = BOACHomePage.new @driver
    @group_page = BOACGroupPage.new @driver
    @cohort_page = BOACFilteredCohortPage.new(@driver, test.advisor)
    @student_page = BOACStudentPage.new @driver

    @homepage.dev_auth test.advisor

    pre_existing_cohorts = BOACUtils.get_user_filtered_cohorts test.advisor
    pre_existing_cohorts.each { |c| @cohort_page.load_cohort(c); @cohort_page.delete_cohort(c) }

    pre_existing_groups = BOACUtils.get_user_curated_groups test.advisor
    pre_existing_groups.each { |c| @group_page.load_page(c); @group_page.delete_cohort(c) }
  end

  context 'when a user has no groups' do

    it 'offers no group filter options' do
      @homepage.click_sidebar_create_filtered
      @cohort_page.click_new_filter_button
      @cohort_page.new_filter_option('curatedGroupIds').when_visible 1
      expect(@cohort_page.new_filter_option('curatedGroupIds').attribute('class')).to eql('dropdown-item disabled')
    end
  end

  context 'when a user has groups' do

    before(:all) do
      @cohort_page.click_sidebar_create_curated_group
      @group_page.create_group_with_bulk_sids(group_1_students, @group_1)
      @group_page.click_sidebar_create_curated_group
      @group_page.create_group_with_bulk_sids(group_2_students, @group_2)


    end

    it 'shows the user\'s own groups as filter options' do
      @group_page.click_sidebar_create_filtered
      @cohort_page.click_new_filter_button
      @cohort_page.wait_for_update_and_click @cohort_page.new_filter_option('curatedGroupIds')
      @cohort_page.new_filter_sub_option_element('curatedGroupIds', @group_1.id).when_present 1
      @cohort_page.new_filter_sub_option_element('curatedGroupIds', @group_2.id).when_present 1
    end

    test.searches.each do |cohort|

      it "allows the user to filter a group by active students with #{cohort.search_criteria.list_filters}" do
        # Add the groups to the search criteria, and restrict the searchable data to the group members
        cohort.search_criteria.curated_groups = [@group_1.id.to_s, @group_2.id.to_s]
        test.searchable_data = group_1_searchable_data + group_2_searchable_data

        # Determine which group members should match the other filters
        cohort.member_data = @cohort_page.expected_search_results(test, cohort.search_criteria)
        expected_results = @cohort_page.expected_sids_by_last_name cohort.member_data

        # Get the matching user objects in the groups
        cohort_member_sids = cohort.member_data.map { |d| d[:sid] }
        cohort.members = test.students.select { |s| cohort_member_sids.include? s.sis_id }

        @cohort_page.click_sidebar_create_filtered
        @cohort_page.perform_search cohort
        @cohort_page.wait_for_spinner
        @cohort_page.create_new_cohort cohort
        @cohorts << cohort

        if cohort.member_data.length.zero?
          @cohort_page.wait_until(Utils.short_wait) { @cohort_page.results_count == 0 }
        else
          visible_results = @cohort_page.visible_sids
          @cohort_page.wait_until(1, "Expected but not present: #{expected_results - visible_results}. Present but not expected: #{visible_results - expected_results}") do
            visible_results.sort == expected_results.sort
          end
        end
      end
    end

    context 'when a user has a cohort with group filters' do

      it 'shows the group filter on a cohort' do
        @cohort_page.show_filters
        @cohort_page.existing_filter_element('My Curated Groups', @group_1.name).when_visible 1
        @cohort_page.existing_filter_element('My Curated Groups', @group_2.name).when_visible 1
      end

      it 'updates the cohort member count in the sidebar when students are removed from the group' do
        # Get the cohort with the most students for further tests to guarantee there are enough students to use
        @cohorts.sort_by! { |c| c.members.length }
        @students_to_add_remove << @cohorts.last.members[0..1]
        @students_to_add_remove.flatten!
        @students_to_add_remove.each do |student|
          group = [@group_1, @group_2].find { |g| g.members.include? student }
          @student_page.load_page student
          @student_page.remove_student_from_grp(student, group)
          test.searchable_data.delete_if { |d| d[:sid] == student.sis_id }
          @cohorts.last.member_data = @cohort_page.expected_search_results(test, @cohorts.last.search_criteria)
          @student_page.wait_for_sidebar_cohort_member_count @cohorts.last
        end
      end

      it 'updates the cohort student list when students are removed from the group' do
        @cohort_page.load_cohort @cohorts.last
        expect(@cohort_page.visible_sids).to eql(@cohort_page.expected_sids_by_last_name @cohorts.last.member_data)
      end

      it 'updates the cohort member count on the homepage when students are removed from the group' do
        @homepage.load_page
        @homepage.wait_until(Utils.medium_wait) { @homepage.filtered_cohorts.include? @cohorts.last.name }
        @homepage.wait_until(Utils.short_wait, "Expected #{@cohorts.last.member_data.length} but got #{@homepage.member_count(@cohorts.last)}") do
          @homepage.member_count(@cohorts.last) == @cohorts.last.member_data.length
        end
      end

      it 'updates the cohort member count in the sidebar when students are added to the group via bulk-add' do
        @group_page.load_page @group_1
        @group_page.add_comma_sep_sids_to_existing_grp([@students_to_add_remove.first], @group_1)
        test.searchable_data << all_searchable_data.find { |d| d[:sid] == @students_to_add_remove.first.sis_id }
        @cohorts.last.member_data = @cohort_page.expected_search_results(test, @cohorts.last.search_criteria)
        @student_page.wait_for_sidebar_cohort_member_count @cohorts.last
      end

      it 'updates the cohort student list when students are added to the group via bulk-add' do
        @cohort_page.load_cohort @cohorts.last
        expect(@cohort_page.visible_sids).to eql(@cohort_page.expected_sids_by_last_name @cohorts.last.member_data)
      end

      it 'updates the cohort member count on the homepage when students are added to the group via bulk-add' do
        @homepage.load_page
        @homepage.wait_until(Utils.medium_wait) { @homepage.filtered_cohorts.include? @cohorts.last.name }
        @homepage.wait_until(Utils.short_wait, "Expected #{@cohorts.last.member_data.length} but got #{@homepage.member_count(@cohorts.last)}") do
          @homepage.member_count(@cohorts.last) == @cohorts.last.member_data.length
        end
      end

      it 'updates the cohort member count in the sidebar when students are added to the group via a group selector' do
        @student_page.load_page @students_to_add_remove.last
        @student_page.add_student_to_grp(@students_to_add_remove.last, @group_1)
        test.searchable_data << all_searchable_data.find { |d| d[:sid] == @students_to_add_remove.last.sis_id }
        @cohorts.last.member_data = @cohort_page.expected_search_results(test, @cohorts.last.search_criteria)
        @student_page.wait_for_sidebar_cohort_member_count @cohorts.last
      end

      it 'updates the cohort student list when students are added to the group via a group selector' do
        @cohort_page.load_cohort @cohorts.last
        expect(@cohort_page.visible_sids).to eql(@cohort_page.expected_sids_by_last_name @cohorts.last.member_data)
      end

      it 'updates the cohort member count on the homepage when students are added to the group via a group selector' do
        @homepage.load_page
        @homepage.wait_until(Utils.medium_wait) { @homepage.filtered_cohorts.include? @cohorts.last.name }
        @homepage.wait_until(Utils.short_wait, "Expected #{@cohorts.last.member_data.length} but got #{@homepage.member_count(@cohorts.last)}") do
          @homepage.member_count(@cohorts.last) == @cohorts.last.member_data.length
        end
      end

      it 'updates the cohort member count in the sidebar when a group is removed from the cohort' do
        @cohort_page.load_cohort @cohorts.last
        @cohort_page.show_filters
        @cohort_page.remove_filter_of_type 'My Curated Groups'
        @cohort_page.wait_for_update_and_click @cohort_page.unsaved_filter_apply_button_element
        @cohort_page.click_save_cohort_button_one
        @cohorts.last.search_criteria.curated_groups.delete @group_1.id.to_s
        test.searchable_data -= group_1_searchable_data
        @cohorts.last.member_data = @cohort_page.expected_search_results(test, @cohorts.last.search_criteria)
        @cohort_page.wait_for_sidebar_cohort_member_count @cohorts.last
      end

      it 'updates the cohort student list when a group is removed from the cohort' do
        expect(@cohort_page.visible_sids).to eql(@cohort_page.expected_sids_by_last_name @cohorts.last.member_data)
      end

      it 'updates the cohort member count on the homepage when a group is removed from the cohort' do
        @homepage.load_page
        @homepage.wait_until(Utils.medium_wait) { @homepage.filtered_cohorts.include? @cohorts.last.name }
        @homepage.wait_until(Utils.short_wait, "Expected #{@cohorts.last.member_data.length} but got #{@homepage.member_count(@cohorts.last)}") do
          @homepage.member_count(@cohorts.last) == @cohorts.last.member_data.length
        end
      end

      it 'shows no link to the cohort on the removed group' do
        @group_page.load_page @group_1
        expect(@group_page.linked_cohort_el(@cohorts.last).exists?).to be false
      end

      it 'updates the cohort member count in the sidebar when a group is added to the cohort' do
        @cohort_page.load_cohort @cohorts.last
        @cohort_page.show_filters
        @cohort_page.select_new_filter('curatedGroupIds', @group_1.id.to_s)
        @cohort_page.wait_for_update_and_click @cohort_page.unsaved_filter_apply_button_element
        @cohort_page.click_save_cohort_button_one
        @cohorts.last.search_criteria.curated_groups << @group_1.id.to_s
        test.searchable_data += group_1_searchable_data
        @cohorts.last.member_data = @cohort_page.expected_search_results(test, @cohorts.last.search_criteria)
        @cohort_page.wait_for_sidebar_cohort_member_count @cohorts.last
      end

      it 'updates the cohort student list when a group is added to the cohort' do
        expect(@cohort_page.visible_sids).to eql(@cohort_page.expected_sids_by_last_name @cohorts.last.member_data)
      end

      it 'updates the cohort member count on the homepage when a group is added to the cohort' do
        @homepage.load_page
        @homepage.wait_until(Utils.medium_wait) { @homepage.filtered_cohorts.include? @cohorts.last.name }
        @homepage.wait_until(Utils.short_wait, "Expected #{@cohorts.last.member_data.length} but got #{@homepage.member_count(@cohorts.last)}") do
          @homepage.member_count(@cohorts.last) == @cohorts.last.member_data.length
        end
      end

      it 'shows a link to the cohort on the added group' do
        @group_page.load_page @group_1
        expect(@group_page.linked_cohort_el(@cohorts.last).exists?).to be true
      end

      it 'prevents the user deleting the linked groups' do
        @group_page.wait_for_update_and_click @group_page.delete_cohort_button_element
        @group_page.no_deleting_el(@cohorts.last)
      end
    end

    context 'when another user views a cohort with a group filter' do

      before(:all) do
        @homepage.hit_escape
        @homepage.log_out
        @homepage.dev_auth BOACUser.new(uid: Utils.super_admin_uid)
      end

      it 'shows the user the filters' do
        @cohort_page.load_cohort @cohorts.last
        @cohort_page.show_filters
        @cohort_page.existing_filter_element('My Curated Groups', @group_1.name).when_visible 1
        @cohort_page.existing_filter_element('My Curated Groups', @group_2.name).when_visible 1

      end

      it('prevents the user from editing the filters') { expect(@cohort_page.cohort_edit_button_elements.any?).to be false }
    end
  end
end
