require_relative '../../util/spec_helper'

if (ENV['DEPS'] || ENV['DEPS'].nil?) && !ENV['NO_DEPS']

  describe 'BOA cohort history' do

    include Logging

    before(:all) do
      @test = BOACTestConfig.new
      @test.filtered_history

      @cohort_1_filters = CohortFilter.new
      @cohort_1_filters.set_custom_filters major: ['English BA'], gender: ['Female']
      @cohort_1 = FilteredCohort.new name: "Cohort 1 #{@test.id}", search_criteria: @cohort_1_filters

      @cohort_2_filters = CohortFilter.new
      @cohort_2_filters.set_custom_filters major: ['History BA'], college: ['Undergrad Non-Degree/NonFinAid']
      @cohort_2 = FilteredCohort.new name: "Cohort 2 #{@test.id}", search_criteria: @cohort_2_filters

      @driver = Utils.launch_browser
      @homepage = BOACHomePage.new @driver
      @cohort_page = BOACFilteredStudentsPage.new(@driver, @test.advisor)
      @group_page = BOACGroupStudentsPage.new @driver
      @cohort_history_page = BOACFilteredStudentsHistoryPage.new @driver

      @homepage.dev_auth @test.advisor
      BOACUtils.get_user_filtered_cohorts(@test.advisor, default: true).each do |c|
        @cohort_page.load_cohort c
        @cohort_page.delete_cohort c
      end
      BOACUtils.get_user_curated_groups(@test.advisor).each do |g|
        @group_page.load_page g
        @group_page.delete_cohort g
      end
    end

    after(:all) { Utils.quit_browser @driver }

    context 'when a cohort is created' do

      context 'and has members' do

        before(:all) do
          @homepage.click_sidebar_create_filtered
          @cohort_page.perform_student_search @cohort_1
          @cohort_page.create_new_cohort @cohort_1
          @cohort_page.set_cohort_members(@cohort_1, @test)
          @cohort_1.history += @cohort_history_page.expected_history_entries(@cohort_1.members, 'ADDED', Time.now)
          @cohort_page.load_cohort @cohort_1
          @cohort_page.click_history
        end

        it 'lists all members as "added" entries' do
          expect(@cohort_history_page.visible_history_entries).to eql(@cohort_1.history)
        end

        it 'offers a Back button on the history page' do
          @cohort_history_page.click_back_to_cohort
          @cohort_page.wait_for_search_results
        end
      end

      context 'and has no members' do

        before(:all) do
          @homepage.click_sidebar_create_filtered
          @cohort_page.perform_student_search @cohort_2
          @cohort_page.create_new_cohort @cohort_2
          @cohort_page.set_cohort_members(@cohort_2, @test)
          @cohort_2.history += @cohort_history_page.expected_history_entries(@cohort_2.members, 'ADDED', Time.now)
          @cohort_page.load_cohort @cohort_2
          @cohort_page.click_history
        end

        it 'shows a "no history" message' do
          @cohort_history_page.no_history_msg_element.when_visible Utils.short_wait
        end

        it 'offers a Back button on the history page' do
          @cohort_history_page.click_back_to_cohort
          @cohort_page.wait_for_search_results
        end
      end
    end

    context 'when an existing cohort\'s filters are modified' do

      before(:all) do
        @initial_members = @cohort_1.members
        @cohort_1.search_criteria.gender = ['Male']
        @cohort_page.load_cohort @cohort_1
        @cohort_page.show_filters
        @cohort_page.edit_filter('Gender', @cohort_1.search_criteria.gender.first)
        @cohort_page.apply_and_save_cohort
        @cohort_page.set_cohort_members(@cohort_1, @test)
        added_members = @cohort_1.members - @initial_members
        removed_members = @initial_members - @cohort_1.members
        @cohort_1.history += @cohort_history_page.expected_history_entries(added_members, 'ADDED', Time.now)
        @cohort_1.history += @cohort_history_page.expected_history_entries(removed_members, 'REMOVED', Time.now)
        @cohort_1.history = @cohort_1.history.sort_by { |s| [s[:sid], s[:status]] }
        @cohort_page.click_history
      end

      it 'shows the right "added" and "removed" entries' do
        expect(@cohort_history_page.visible_history_entries).to eql(@cohort_1.history)
      end

      it 'offers a Back button on the history page' do
        @cohort_history_page.click_back_to_cohort
        @cohort_page.wait_for_search_results
      end
    end

    context 'when an existing cohort\'s members are modified' do

      before(:all) do
        @group = CuratedGroup.new name: "Group #{@test.id}"
        @cohort_page.click_sidebar_create_student_group
        @group_page.create_group_with_bulk_sids(@test.students[0..19], @group)
        @group_page.wait_for_sidebar_group @group

        @cohort_3_filters = CohortFilter.new
        @cohort_3_filters.set_custom_filters curated_groups: [@group.id.to_s]
        @cohort_3 = FilteredCohort.new name: "Cohort 3 #{@test.id}", search_criteria: @cohort_3_filters

        # Restrict the searchable data to the group members
        group_sids = @group.members.map &:sis_id
        @test.students.keep_if { |s| group_sids.include? s.sis_id }

        @homepage.click_sidebar_create_filtered
        @cohort_page.perform_student_search @cohort_3
        @cohort_page.create_new_cohort @cohort_3
        @cohort_3.history += @cohort_history_page.expected_history_entries(@group.members, 'ADDED', Time.now)
        @cohort_page.load_cohort @cohort_3
        @cohort_page.click_history

        @group_page.load_page @group
        added_members = @test.students[20..29]
        @group_page.add_comma_sep_sids_to_existing_grp(added_members, @group)
        @group_page.wait_for_sidebar_group @group
        @cohort_3.history += @cohort_history_page.expected_history_entries(added_members, 'ADDED', Time.now)
        @cohort_3.history = @cohort_3.history.sort_by { |s| [s[:sid], s[:status]] }
        @cohort_page.load_cohort @cohort_3
        @cohort_page.click_history
      end

      it 'shows the right "added" and "removed" entries' do
        expect(@cohort_history_page.visible_history_entries).to eql(@cohort_3.history)
      end

      it 'offers a Back button on the history page' do
        @cohort_history_page.click_back_to_cohort
        @cohort_page.wait_for_search_results
      end
    end
  end
end
