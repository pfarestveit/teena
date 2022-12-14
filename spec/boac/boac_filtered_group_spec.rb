require_relative '../../util/spec_helper'

if (ENV['DEPS'] || ENV['DEPS'].nil?) && !ENV['NO_DEPS']

  test = BOACTestConfig.new
  test.filtered_groups
  test.students.shuffle!

  group_1_students = test.students.first(1000)
  group_2_students = test.students.last(1000)
  test.students = group_1_students + group_2_students

  describe 'A BOA filtered cohort' do

    include Logging

    before(:all) do
      @group_1 = CuratedGroup.new name: "Group 1 #{test.id}", members: []
      @group_2 = CuratedGroup.new name: "Group 2 #{test.id}", members: []
      @students_to_add_remove = []

      @driver = Utils.launch_browser
      @homepage = BOACHomePage.new @driver
      @group_page = BOACGroupStudentsPage.new @driver
      @cohort_page = BOACFilteredStudentsPage.new(@driver, test.advisor)
      @student_page = BOACStudentPage.new @driver

      @homepage.dev_auth test.advisor

      pre_existing_cohorts = BOACUtils.get_user_filtered_cohorts test.advisor, default: true
      pre_existing_cohorts.each { |c| @cohort_page.load_cohort(c); @cohort_page.delete_cohort(c) }

      pre_existing_groups = BOACUtils.get_user_curated_groups test.advisor
      pre_existing_groups.each { |c| @group_page.load_page(c); @group_page.delete_cohort(c) }
    end

    context 'when a user has no groups' do

      it 'offers no group filter options' do
        @homepage.click_sidebar_create_filtered
        @cohort_page.new_filter_select_element.when_visible Utils.short_wait
        opt = @cohort_page.new_filter_option_elements.find { |el| el.text.strip == 'My Curated Groups' }
        expect(opt.attribute('disabled')).to eql('true')
      end
    end

    context 'when a user has groups' do

      before(:all) do
        @cohort_page.click_sidebar_create_student_group
        @group_page.create_group_with_bulk_sids(group_1_students, @group_1)
        @group_page.click_sidebar_create_student_group
        @group_page.create_group_with_bulk_sids(group_2_students, @group_2)

        test.searches.each do |cohort|
          cohort.search_criteria.curated_groups = [@group_1.id.to_s, @group_2.id.to_s]
          @cohort_page.set_cohort_members(cohort, test)
        end
        test.searches.sort_by! { |c| c.members.length }
        @cohort = test.searches.last
      end

      it 'shows the user\'s own groups as filter options' do
        @group_page.click_sidebar_create_filtered
        @cohort_page.select_new_filter_option 'My Curated Groups'
        @cohort_page.wait_until(1) do
          opts = @cohort_page.new_sub_filter_option_elements.map { |el| el.text.strip }
          opts.include? @group_1.name
          opts.include? @group_2.name
        end
      end

      it 'allows the user to filter a group by active students with additional filters' do
        @cohort_page.click_sidebar_create_filtered
        @cohort_page.perform_student_search @cohort
        @cohort_page.wait_for_spinner
        @cohort_page.create_new_cohort @cohort
        expected = @cohort.members.map &:sis_id
        if @cohort.members.length.zero?
          @cohort_page.wait_until(Utils.short_wait) { @cohort_page.results_count == 0 }
        else
          visible = @cohort_page.visible_sids
          @cohort_page.wait_until(1, "Missing: #{expected - visible}. Unexpected: #{visible - expected}") do
            visible.sort == expected.sort
          end
        end
      end

      context 'and a user has a cohort with group filters' do

        it 'shows the group filter on a cohort' do
          @cohort_page.show_filters
          @cohort_page.existing_filter_element('My Curated Groups', @group_1.name).when_visible 1
          @cohort_page.existing_filter_element('My Curated Groups', @group_2.name).when_visible 1
        end

        it 'updates the cohort member count in the sidebar when students are removed from the group' do
          @students_to_add_remove << @cohort.members[0..1]
          @students_to_add_remove.flatten!
          @students_to_add_remove.each do |student|
            group = [@group_1, @group_2].find { |g| g.members.include? student }
            @student_page.load_page student
            @student_page.remove_student_from_grp(student, group)
            test.students.delete_if { |s| s.sis_id == student.sis_id }
            @cohort_page.set_cohort_members(@cohort, test)
            @homepage.load_page
            @student_page.wait_for_sidebar_cohort_member_count @cohort
          end
        end

        it 'updates the cohort student list when students are removed from the group' do
          @cohort_page.load_cohort @cohort
          expect(@cohort_page.visible_sids.sort).to eql(@cohort.members.map(&:sis_id).sort)
        end

        it 'updates the cohort member count on the homepage when students are removed from the group' do
          @homepage.load_page
          @homepage.wait_until(Utils.medium_wait) { @homepage.filtered_cohorts.include? @cohort.name }
          @homepage.wait_until(Utils.short_wait, "Expected #{@cohort.members.length} but got #{@homepage.member_count(@cohort)}") do
            @homepage.member_count(@cohort) == @cohort.members.length
          end
        end

        it 'updates the cohort member count in the sidebar when students are added to the group via bulk-add' do
          @group_page.load_page @group_1
          @group_page.add_comma_sep_sids_to_existing_grp([@students_to_add_remove.first], @group_1)
          test.students << @students_to_add_remove.first
          @cohort_page.set_cohort_members(@cohort, test)
          @homepage.load_page
          @student_page.wait_for_sidebar_cohort_member_count @cohort
        end

        it 'updates the cohort student list when students are added to the group via bulk-add' do
          @cohort_page.load_cohort @cohort
          expect(@cohort_page.visible_sids.sort).to eql(@cohort.members.map(&:sis_id).sort)
        end

        it 'updates the cohort member count on the homepage when students are added to the group via bulk-add' do
          @homepage.load_page
          @homepage.wait_until(Utils.medium_wait) { @homepage.filtered_cohorts.include? @cohort.name }
          @homepage.wait_until(Utils.short_wait, "Expected #{@cohort.members.length} but got #{@homepage.member_count(@cohort)}") do
            @homepage.member_count(@cohort) == @cohort.members.length
          end
        end

        it 'updates the cohort member count in the sidebar when students are added to the group via a group selector' do
          @student_page.load_page @students_to_add_remove.last
          @student_page.add_student_to_grp(@students_to_add_remove.last, @group_1)
          test.students << @students_to_add_remove.last
          @cohort_page.set_cohort_members(@cohort, test)
          @homepage.load_page
          @student_page.wait_for_sidebar_cohort_member_count @cohort
        end

        it 'updates the cohort student list when students are added to the group via a group selector' do
          @cohort_page.load_cohort @cohort
          expected = @cohort.members.map(&:sis_id).sort
          @cohort_page.wait_until(1, "Missing #{expected - @cohort_page.visible_sids.sort}, unexpected #{@cohort_page.visible_sids.sort - expected}") do
            @cohort_page.visible_sids.sort == expected
          end
        end

        it 'updates the cohort member count on the homepage when students are added to the group via a group selector' do
          @homepage.load_page
          @homepage.wait_until(Utils.medium_wait) { @homepage.filtered_cohorts.include? @cohort.name }
          @homepage.wait_until(Utils.short_wait, "Expected #{@cohort.members.length} but got #{@homepage.member_count(@cohort)}") do
            @homepage.member_count(@cohort) == @cohort.members.length
          end
        end

        it 'updates the cohort member count in the sidebar when a group is removed from the cohort' do
          @cohort_page.load_cohort @cohort
          @cohort_page.show_filters
          @cohort_page.remove_filter_of_type 'My Curated Groups'
          @cohort_page.wait_for_update_and_click @cohort_page.unsaved_filter_apply_button_element
          @cohort_page.click_save_cohort_button_one
          @cohort.search_criteria.curated_groups.delete @group_1.id.to_s
          test.students -= group_1_students
          @cohort_page.set_cohort_members(@cohort, test)
          @homepage.load_page
          @cohort_page.wait_for_sidebar_cohort_member_count @cohort
        end

        it 'updates the cohort student list when a group is removed from the cohort' do
          @cohort_page.load_cohort @cohort
          expect(@cohort_page.visible_sids.sort).to eql(@cohort.members.map(&:sis_id).sort)
        end

        it 'updates the cohort member count on the homepage when a group is removed from the cohort' do
          @homepage.load_page
          @homepage.wait_until(Utils.medium_wait) { @homepage.filtered_cohorts.include? @cohort.name }
          @homepage.wait_until(Utils.short_wait, "Expected #{@cohort.members.length} but got #{@homepage.member_count(@cohort)}") do
            @homepage.member_count(@cohort) == @cohort.members.length
          end
        end

        it 'shows no link to the cohort on the removed group' do
          @group_page.load_page @group_1
          expect(@group_page.linked_cohort_el(@cohort).exists?).to be false
        end

        it 'updates the cohort member count in the sidebar when a group is added to the cohort' do
          @cohort_page.load_cohort @cohort
          @cohort_page.show_filters
          @cohort_page.select_new_filter('My Curated Groups', @group_1.id.to_s)
          @cohort_page.wait_for_update_and_click @cohort_page.unsaved_filter_apply_button_element
          @cohort_page.click_save_cohort_button_one
          @cohort.search_criteria.curated_groups << @group_1.id.to_s
          test.students += group_1_students
          @cohort_page.set_cohort_members(@cohort, test)
          @homepage.load_page
          @cohort_page.wait_for_sidebar_cohort_member_count @cohort
        end

        it 'updates the cohort student list when a group is added to the cohort' do
          @cohort_page.load_cohort @cohort
          expected = @cohort.members.map(&:sis_id).sort
          @cohort_page.wait_until(1, "Missing #{expected - @cohort_page.visible_sids.sort}, unexpected #{@cohort_page.visible_sids.sort - expected}") do
            @cohort_page.visible_sids.sort == expected
          end
        end

        it 'updates the cohort member count on the homepage when a group is added to the cohort' do
          @homepage.load_page
          @homepage.wait_until(Utils.medium_wait) { @homepage.filtered_cohorts.include? @cohort.name }
          @homepage.wait_until(Utils.short_wait, "Expected #{@cohort.members.length} but got #{@homepage.member_count(@cohort)}") do
            @homepage.member_count(@cohort) == @cohort.members.length
          end
        end

        it 'shows a link to the cohort on the added group' do
          @group_page.load_page @group_1
          @group_page.linked_cohort_el(@cohort).when_present Utils.short_wait
        end

        it 'prevents the user deleting the linked groups' do
          @group_page.wait_for_update_and_click @group_page.delete_cohort_button_element
          @group_page.no_deleting_el(@cohort)
        end
      end

      context 'and another user views a cohort with a group filter' do

        before(:all) do
          @homepage.hit_escape
          @homepage.log_out
          @homepage.dev_auth BOACUser.new(uid: Utils.super_admin_uid)
        end

        it 'shows the user the filters' do
          @cohort_page.load_cohort @cohort
          @cohort_page.show_filters
          @cohort_page.existing_filter_element('My Curated Groups', @group_1.name).when_visible 1
          @cohort_page.existing_filter_element('My Curated Groups', @group_2.name).when_visible 1
        end

        it('prevents the user from editing the filters') { expect(@cohort_page.cohort_edit_button_elements.any?).to be false }
      end
    end
  end
end
