require_relative '../../util/spec_helper'

describe 'BOAC', order: :defined do

  include Logging

  all_students = NessieUtils.get_all_students
  test = BOACTestConfig.new
  test.filtered_cohorts all_students
  pre_existing_cohorts = BOACUtils.get_user_filtered_cohorts test.advisor

  before(:all) do
    @driver = Utils.launch_browser
    @analytics_page = ApiUserAnalyticsPage.new @driver
    @homepage = Page::BOACPages::HomePage.new @driver
    @cohort_page = Page::BOACPages::CohortPages::FilteredCohortPage.new @driver
    @student_page = Page::BOACPages::StudentPage.new @driver

    # Get the student data relevant to all search filters.
    @all_searchable_students = @analytics_page.users_searchable_data
    unless @all_searchable_students
      @homepage.dev_auth
      test.dept_students.keep_if &:active_asc if test.dept == BOACDepartments::ASC
      @all_searchable_students = @analytics_page.collect_users_searchable_data(@driver, all_students)

      @homepage.load_page
      @homepage.log_out
    end
    @searchable_students = @analytics_page.applicable_user_search_data(@all_searchable_students, test)
    @homepage.dev_auth test.advisor
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when an advisor has no filtered cohorts' do

    before(:all) do
      @homepage.load_page
      pre_existing_cohorts.each { |c| @cohort_page.delete_cohort c }
    end

    it('shows a No Filtered Cohorts message on the homepage') do
      @homepage.load_page
      @homepage.no_filtered_cohorts_msg_element.when_visible Utils.short_wait
    end
  end

  context 'filtered cohort search' do

    before(:each) { @cohort_page.cancel_cohort if @cohort_page.cancel_cohort_button? }

    test.searches.each do |cohort|

      it "shows all the students sorted by Last Name who match #{cohort.search_criteria.list_filters}" do
        @cohort_page.click_sidebar_create_filtered
        @cohort_page.perform_search cohort
        expected_results = @cohort_page.expected_sids_by_last_name(@searchable_students, cohort.search_criteria)
        visible_results = cohort.member_count.zero? ? [] : @cohort_page.visible_sids
        @cohort_page.wait_until(1, "Expected but not present: #{expected_results - visible_results}. Present but not expected: #{visible_results - expected_results}") { visible_results.sort == expected_results.sort }
        @cohort_page.verify_list_view_sorting(expected_results, visible_results)
      end

      it "shows by First Name all the students who match #{cohort.search_criteria.list_filters}" do
        expected_results = @cohort_page.expected_sids_by_first_name(@searchable_students, cohort.search_criteria)
        if expected_results.length.zero?
          logger.warn 'Skipping sort-by-first-name test since there are no results'
        else
          @cohort_page.sort_by_first_name if expected_results.any?
          visible_results = @cohort_page.visible_sids
          @cohort_page.verify_list_view_sorting(expected_results, visible_results)
          @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
        end
      end

      it "sorts by Team all the students who match #{cohort.search_criteria.list_filters}" do
        if test.dept == BOACDepartments::ASC
          expected_results = @cohort_page.expected_sids_by_team(@searchable_students, cohort.search_criteria)
          if expected_results.length.zero?
            logger.warn 'Skipping sort-by-team test since there are no results'
          else
            @cohort_page.sort_by_team if expected_results.any?
            visible_results = @cohort_page.visible_sids
            @cohort_page.verify_list_view_sorting(expected_results, visible_results)
            @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
          end
        else
          logger.warn 'Skipping sort-by-team since the user is not with ASC'
        end
      end

      it "sorts by GPA all the students who match #{cohort.search_criteria.list_filters}" do
        expected_results = @cohort_page.expected_sids_by_gpa(@searchable_students, cohort.search_criteria)
        if expected_results.length.zero?
          logger.warn 'Skipping sort-by-GPA test since there are no results'
        else
          @cohort_page.sort_by_gpa if expected_results.any?
          visible_results = @cohort_page.visible_sids
          @cohort_page.verify_list_view_sorting(expected_results, visible_results)
          @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
        end
      end

      it "sorts by Level all the students who match #{cohort.search_criteria.list_filters}" do
        expected_results = @cohort_page.expected_sids_by_level(@searchable_students, cohort.search_criteria)
        if expected_results.length.zero?
          logger.warn 'Skipping sort-by-level test since there are no results'
        else
          @cohort_page.sort_by_level if expected_results.any?
          visible_results = @cohort_page.visible_sids
          @cohort_page.verify_list_view_sorting(expected_results, visible_results)
          @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
        end
      end

      it "sorts by Major all the students who match #{cohort.search_criteria.list_filters}" do
        expected_results = @cohort_page.expected_sids_by_major(@searchable_students, cohort.search_criteria)
        if expected_results.length.zero?
          logger.warn 'Skipping sort-by-major test since there are no results'
        else
          @cohort_page.sort_by_major if expected_results.any?
          visible_results = @cohort_page.visible_sids
          @cohort_page.verify_list_view_sorting(expected_results, visible_results)
          @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
        end
      end

      it "sorts by Units all the students who match #{cohort.search_criteria.list_filters}" do
        expected_results = @cohort_page.expected_sids_by_units(@searchable_students, cohort.search_criteria)
        if expected_results.length.zero?
          logger.warn 'Skipping sort-by-units test since there are no results'
        else
          @cohort_page.sort_by_units if expected_results.any?
          visible_results = @cohort_page.visible_sids
          @cohort_page.verify_list_view_sorting(expected_results, visible_results)
          @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
        end
      end

      it("allows the advisor to create a cohort using #{cohort.search_criteria.list_filters}") { @cohort_page.create_new_cohort cohort }

      it("shows the cohort filters for a cohort using #{cohort.search_criteria.list_filters}") { @cohort_page.verify_filters_present cohort }

      it "shows the filtered cohort on the homepage with criteria #{cohort.search_criteria.list_filters}" do
        @homepage.load_page
        @homepage.wait_until(Utils.medium_wait) { @homepage.filtered_cohorts.include? cohort.name }
      end

      it "shows the filtered cohort members who have alerts on the homepage with criteria #{cohort.search_criteria.list_filters}" do
        member_sids = @cohort_page.expected_sids_by_last_name(@searchable_students, cohort.search_criteria)
        @homepage.wait_until(Utils.short_wait) { @homepage.filtered_cohort_member_count(cohort) == member_sids.length }
        members = test.dept_students.select { |u| member_sids.include? u.sis_id }
        @homepage.verify_cohort_alert_rows(@driver, cohort, members, test.advisor)
      end

      it "offers a link to the filtered cohort with criteria #{cohort.search_criteria.list_filters}" do
        @homepage.click_filtered_cohort cohort
        @cohort_page.cohort_heading(cohort).when_visible Utils.medium_wait
      end
    end

    it 'requires a title' do
      @homepage.click_sidebar_create_filtered
      @cohort_page.perform_search test.searches.first
      @cohort_page.click_save_cohort_button_one
      expect(@cohort_page.save_cohort_button_two_element.disabled?).to be true
    end

    it 'truncates a title over 255 characters' do
      cohort = FilteredCohort.new({name: "#{test.id}#{'A loooooong title ' * 15}?"})
      @homepage.click_sidebar_create_filtered
      @cohort_page.perform_search test.searches.first
      @cohort_page.save_and_name_cohort cohort
      cohort.name = cohort.name[0..254]
      @cohort_page.wait_for_filtered_cohort cohort
      test.searches << cohort
    end

    it 'requires that a title be unique among the user\'s existing cohorts' do
      cohort = FilteredCohort.new({name: test.searches.first.name})
      @cohort_page.click_sidebar_create_filtered
      @cohort_page.perform_search test.searches.first
      @cohort_page.save_and_name_cohort cohort
      @cohort_page.dupe_filtered_name_msg_element.when_visible Utils.short_wait
    end
  end

  context 'when the advisor views its cohorts' do

    it('shows only the advisor\'s cohorts on the homepage') do
      test.searches.flatten!
      @homepage.load_page
      @homepage.wait_until(Utils.short_wait) { @homepage.filtered_cohorts.any? }
      @homepage.wait_until(1, "Expected #{(test.searches.map &:name).sort}, but got #{@homepage.filtered_cohorts.sort}") { @homepage.filtered_cohorts.sort == (test.searches.map &:name).sort }
    end
  end

  context 'when the advisor edits a cohort\'s search filters' do

    before(:all) { @cohort_page.search_and_create_new_cohort test.default_cohort }

    it 'allows the advisor to edit a GPA filter' do
      test.default_cohort.search_criteria.gpa = ['3.50 - 4.00']
      @cohort_page.edit_filter_and_confirm('GPA', test.default_cohort.search_criteria.gpa.first)
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove a GPA filter' do
      test.default_cohort.search_criteria.gpa = []
      @cohort_page.remove_filter_of_type 'GPA'
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to edit a Level filter' do
      test.default_cohort.search_criteria.level = ['Junior (60-89 Units)']
      @cohort_page.edit_filter_and_confirm('Level', test.default_cohort.search_criteria.level.first)
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove a Level filter' do
      test.default_cohort.search_criteria.level = []
      @cohort_page.remove_filter_of_type 'Level'
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to edit a Units Completed filter' do
      test.default_cohort.search_criteria.units_completed = ['60 - 89']
      @cohort_page.edit_filter_and_confirm('Units Completed', test.default_cohort.search_criteria.units_completed.first)
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove a Units Completed filter' do
      test.default_cohort.search_criteria.units_completed = []
      @cohort_page.remove_filter_of_type 'Units Completed'
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to edit a Major filter' do
      if test.default_cohort.search_criteria.major.any?
        test.default_cohort.search_criteria.major = ['Bioengineering BS']
        @cohort_page.edit_filter_and_confirm('Major', test.default_cohort.search_criteria.major.first)
        @cohort_page.verify_filters_present test.default_cohort
      else
        logger.warn 'Skipping test for editing majors since there is nothing to edit'
      end
    end

    it 'allows the advisor to remove a Major filter' do
      if test.default_cohort.search_criteria.major.any?
        test.default_cohort.search_criteria.major = []
        @cohort_page.remove_filter_of_type 'Major'
        @cohort_page.verify_filters_present test.default_cohort
      else
        logger.warn 'Skipping test for removing majors since there is nothing to remove'
      end
    end

    it 'allows the advisor to edit an Ethnicity filter' do
      if test.default_cohort.search_criteria.ethnicity
        test.default_cohort.search_criteria.ethnicity = ['Mexican / Mexican-American / Chicano']
        @cohort_page.edit_filter_and_confirm('Ethnicity', test.default_cohort.search_criteria.ethnicity.first)
        @cohort_page.verify_filters_present test.default_cohort
      else
        logger.warn 'Skipping test for editing ethnicity since the filter is not available to the user'
      end
    end

    it 'allows the advisor to remove an Ethnicity filter' do
      if test.default_cohort.search_criteria.ethnicity
        test.default_cohort.search_criteria.ethnicity = []
        @cohort_page.remove_filter_of_type 'Ethnicity'
        @cohort_page.verify_filters_present test.default_cohort
      else
        logger.warn 'Skipping test for removing ethnicity since the filter is not available to the user'
      end
    end

    it 'allows the advisor to edit a Gender filter' do
      if test.default_cohort.search_criteria.gender
        test.default_cohort.search_criteria.gender = ['Male']
        @cohort_page.edit_filter_and_confirm('Gender', test.default_cohort.search_criteria.gender.first)
        @cohort_page.verify_filters_present test.default_cohort
      else
        logger.warn 'Skipping test for editing genders since the filter is not available to the user'
      end
    end

    it 'allows the advisor to remove a Gender filter' do
      if test.default_cohort.search_criteria.gender
        test.default_cohort.search_criteria.gender = []
        @cohort_page.remove_filter_of_type 'Gender'
        @cohort_page.verify_filters_present test.default_cohort
      else
        logger.warn 'Skipping test for removing genders since the filter is not available to the user'
      end
    end

    it 'allows the advisor to remove an Underrepresented Minority filter' do
      if test.default_cohort.search_criteria.underrepresented_minority
        test.default_cohort.search_criteria.underrepresented_minority = false
        @cohort_page.remove_filter_of_type 'Underrepresented Minority'
        @cohort_page.verify_filters_present test.default_cohort
      else
        logger.warn 'Skipping test for removing underrepresented minority since the filter is not available to the user'
      end
    end

    it 'allows the advisor to remove an Inactive filter' do
      if test.default_cohort.search_criteria.inactive
        test.default_cohort.search_criteria.inactive = false
        @cohort_page.remove_filter_of_type 'Inactive'
        @cohort_page.verify_filters_present test.default_cohort
      else
        logger.warn 'Skipping test for removing inactive since the filter is not available to the user'
      end
    end

    it 'allows the advisor to remove an Intensive filter' do
      if test.default_cohort.search_criteria.intensive
        test.default_cohort.search_criteria.intensive = false
        @cohort_page.remove_filter_of_type 'Intensive'
        @cohort_page.verify_filters_present test.default_cohort
      else
        logger.warn 'Skipping test for removing intensive since the filter is not available to the user'
      end
    end

    it 'allows the advisor to edit a Team filter' do
      if test.default_cohort.search_criteria.team && test.default_cohort.search_criteria.team.any?
        test.default_cohort.search_criteria.team = [Squad::WCR]
        @cohort_page.edit_filter_and_confirm('Team', test.default_cohort.search_criteria.team.first.name)
        @cohort_page.verify_filters_present test.default_cohort
      else
        logger.warn 'Skipping test for editing teams since the filter is not available to the user or there is nothing to edit'
      end
    end

    it 'allows the advisor to remove a Team filter' do
      if test.default_cohort.search_criteria.team && test.default_cohort.search_criteria.team.any?
        test.default_cohort.search_criteria.team = []
        @cohort_page.remove_filter_of_type 'Team'
        @cohort_page.verify_filters_present test.default_cohort
      else
        logger.warn 'Skipping test for removing teams since the filter is not available to the user or there is nothing to edit'
      end
    end

    it 'allows the advisor to edit a PREP filter' do
      if test.default_cohort.search_criteria.prep
        test.default_cohort.search_criteria.prep = ['T-PREP']
        @cohort_page.edit_filter_and_confirm('PREP', test.default_cohort.search_criteria.prep.first)
        @cohort_page.verify_filters_present test.default_cohort
      else
        logger.warn 'Skipping test for editing PREPs since the filter is not available to the user'
      end
    end

    it 'allows the advisor to remove a PREP filter' do
      if test.default_cohort.search_criteria.prep
        test.default_cohort.search_criteria.prep = []
        @cohort_page.remove_filter_of_type 'PREP'
        @cohort_page.verify_filters_present test.default_cohort
      else
        logger.warn 'Skipping test for removing PREPs since the filter is not available to the user'
      end
    end

    it 'allows the advisor to edit a Last Name filter' do
      test.default_cohort.search_criteria.last_name = 'BY'
      @cohort_page.edit_filter_and_confirm('Last Name', test.default_cohort.search_criteria.last_name)
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove a Last Name filter' do
      test.default_cohort.search_criteria.last_name = nil
      @cohort_page.remove_filter_of_type 'Last Name'
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to edit an Advisor filter' do
      if test.default_cohort.search_criteria.advisor
        test.default_cohort.search_criteria.advisor = [BOACUtils.get_dept_advisors(BOACDepartments::COE).last.uid.to_s]
        @cohort_page.edit_filter_and_confirm('Advisor', test.default_cohort.search_criteria.advisor.first)
        @cohort_page.verify_filters_present test.default_cohort
      else
        logger.warn 'Skipping test for editing advisors since the filter is not available to the user'
      end
    end

    it 'allows the advisor to remove an Advisor filter' do
      if test.default_cohort.search_criteria.advisor
        test.default_cohort.search_criteria.advisor = []
        @cohort_page.remove_filter_of_type 'Advisor'
        @cohort_page.verify_filters_present test.default_cohort
      else
        logger.warn 'Skipping test for removing advisors since the filter is not available to the user'
      end
    end

  end

  context 'when the advisor edits a cohort\'s name' do

    it 'renames the existing cohort' do
      cohort = test.searches.first
      id = cohort.id
      @cohort_page.rename_cohort(cohort, "#{cohort.name} - Renamed")
      expect(cohort.id).to eql(id)
    end
  end

  context 'when the advisor deletes a cohort and tries to navigate to the deleted cohort' do

    before(:all) do
      @cohort_to_delete = test.searches.find { |c| !c.read_only }
      @cohort_page.delete_cohort @cohort_to_delete
    end

    it 'shows a Not Found page' do
      @cohort_page.navigate_to "#{BOACUtils.base_url}/cohort/filtered?id=#{@cohort_to_delete.id}"
      @cohort_page.wait_for_title '404'
    end
  end

end
