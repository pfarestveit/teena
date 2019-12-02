require_relative '../../util/spec_helper'

describe 'BOAC', order: :defined do

  include Logging

  test = BOACTestConfig.new
  test.filtered_cohorts
  pre_existing_cohorts = BOACUtils.get_user_filtered_cohorts test.advisor

  before(:all) do
    @driver = Utils.launch_browser test.chrome_profile
    @analytics_page = BOACApiStudentPage.new @driver
    @homepage = BOACHomePage.new @driver
    @cohort_page = BOACFilteredCohortPage.new(@driver, test.advisor)
    @student_page = BOACStudentPage.new @driver

    @homepage.dev_auth test.advisor
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when an advisor has no filtered cohorts' do

    before(:all) do
      @homepage.load_page
      pre_existing_cohorts.each do |c|
        @cohort_page.load_cohort c
        @cohort_page.delete_cohort c
      end
    end

    it('shows a No Filtered Cohorts message on the homepage') do
      @homepage.load_page
      @homepage.no_filtered_cohorts_msg_element.when_visible Utils.short_wait
    end
  end

  context 'filtered cohort search' do

    before(:each) { @cohort_page.cancel_cohort if @cohort_page.cancel_cohort_button? && @cohort_page.cancel_cohort_button_element.visible? }

    test.searches.each do |cohort|

      it "shows all the students sorted by Last Name who match #{cohort.search_criteria.list_filters}" do
        @cohort_page.click_sidebar_create_filtered
        @cohort_page.perform_search cohort
        cohort.member_data = @cohort_page.expected_search_results(test, cohort.search_criteria)
        expected_results = @cohort_page.expected_sids_by_last_name cohort.member_data
        if cohort.member_data.length.zero?
          @cohort_page.wait_until(Utils.short_wait) { @cohort_page.results_count == 0 }
        else
          visible_results = @cohort_page.visible_sids
          @cohort_page.wait_until(1, "Expected but not present: #{expected_results - visible_results}. Present but not expected: #{visible_results - expected_results}") do
            visible_results.sort == expected_results.sort
          end
          @cohort_page.verify_list_view_sorting(expected_results, visible_results)
        end
      end

      it "sorts by First Name all the students who match #{cohort.search_criteria.list_filters}" do
        if (0..1) === cohort.member_data.length
          logger.warn 'Skipping sort-by-first-name test since there are no results or only one result'
        else
          @cohort_page.sort_by_first_name
          expected_results = @cohort_page.expected_sids_by_first_name cohort.member_data
          visible_results = @cohort_page.visible_sids
          @cohort_page.verify_list_view_sorting(expected_results, visible_results)
          @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
        end
      end

      it "sorts by Team all the students who match #{cohort.search_criteria.list_filters}" do
        if test.dept == BOACDepartments::ASC
          if (0..1) === cohort.member_data.length
            logger.warn 'Skipping sort-by-team test since there are no results or only one result'
          else
            @cohort_page.sort_by_team
            expected_results = @cohort_page.expected_sids_by_team cohort.member_data
            visible_results = @cohort_page.visible_sids
            @cohort_page.verify_list_view_sorting(expected_results, visible_results)
            @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
          end
        end
      end

      it "sorts by GPA all the students who match #{cohort.search_criteria.list_filters}" do
        if (0..1) === cohort.member_data.length
          logger.warn 'Skipping sort-by-GPA test since there are no results or only one result'
        else
          @cohort_page.sort_by_gpa_cumulative
          expected_results = @cohort_page.expected_sids_by_gpa cohort.member_data
          visible_results = @cohort_page.visible_sids
          @cohort_page.verify_list_view_sorting(expected_results, visible_results)
          @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
        end
      end

      it "sorts by Level all the students who match #{cohort.search_criteria.list_filters}" do
        if (0..1) === cohort.member_data.length
          logger.warn 'Skipping sort-by-level test since there are no results or only one result'
        else
          @cohort_page.sort_by_level
          expected_results = @cohort_page.expected_sids_by_level cohort.member_data
          visible_results = @cohort_page.visible_sids
          @cohort_page.verify_list_view_sorting(expected_results, visible_results)
          @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
        end
      end

      it "sorts by Major all the students who match #{cohort.search_criteria.list_filters}" do
        if (0..1) === cohort.member_data.length
          logger.warn 'Skipping sort-by-major test since there are no results or only one result'
        else
          @cohort_page.sort_by_major
          expected_results = @cohort_page.expected_sids_by_major cohort.member_data
          visible_results = @cohort_page.visible_sids
          @cohort_page.verify_list_view_sorting(expected_results, visible_results)
          @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
        end
      end

      it "sorts by Entering Term all the students who match #{cohort.search_criteria.list_filters}" do
        if (0..1) === cohort.member_data.length
          logger.warn 'Skipping sort-by-entering-term test since there are no results or only one result'
        else
          @cohort_page.sort_by_entering_term
          expected_results = @cohort_page.expected_sids_by_matriculation cohort.member_data
          visible_results = @cohort_page.visible_sids
          @cohort_page.verify_list_view_sorting(expected_results, visible_results)
          @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
        end
      end

      it "sorts by Units In Progress all the students who match #{cohort.search_criteria.list_filters}" do
        if (0..1) === cohort.member_data.length
          logger.warn 'Skipping sort-by-units-in-progress test since there are no results or only one result'
        else
          @cohort_page.sort_by_units_in_progress
          expected_results = @cohort_page.expected_sids_by_units_in_prog cohort.member_data
          visible_results = @cohort_page.visible_sids
          @cohort_page.verify_list_view_sorting(expected_results, visible_results)
          @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
        end
      end

      it "sorts by Units Completed all the students who match #{cohort.search_criteria.list_filters}" do
        if (0..1) === cohort.member_data.length
          logger.warn 'Skipping sort-by-units-completed test since there are no results or only one result'
        else
          @cohort_page.sort_by_units_completed
          expected_results = @cohort_page.expected_sids_by_units_completed cohort.member_data
          visible_results = @cohort_page.visible_sids
          @cohort_page.verify_list_view_sorting(expected_results, visible_results)
          @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
        end
      end

      it("offers an Export List button for a search #{cohort.search_criteria.list_filters}") { expect(@cohort_page.export_list_button?).to be true }

      it("allows the advisor to create a cohort using #{cohort.search_criteria.list_filters}") { @cohort_page.create_new_cohort cohort }

      it("shows the cohort filters for a cohort using #{cohort.search_criteria.list_filters}") { @cohort_page.verify_filters_present cohort }

      it "allows the advisor to export a non-empty list of students in a cohort using #{cohort.search_criteria.list_filters}" do
        if cohort.member_data.any?
          parsed_csv = @cohort_page.export_student_list cohort
          @cohort_page.verify_student_list_default_export(cohort.member_data, parsed_csv)
        else
          expect(@cohort_page.export_list_button_element.disabled?).to be true
        end
      end

      it "allows the advisor to choose columns to include when exporting a cohort using #{cohort.search_criteria.list_filters}" do
        if cohort.member_data.any?
          parsed_csv = @cohort_page.export_custom_student_list cohort
          @cohort_page.verify_student_list_custom_export(cohort.member_data, parsed_csv)
        else
          expect(@cohort_page.export_list_button_element.disabled?).to be true
        end
      end

      it "shows the filtered cohort on the homepage with criteria #{cohort.search_criteria.list_filters}" do
        @homepage.load_page
        @homepage.wait_until(Utils.medium_wait) { @homepage.filtered_cohorts.include? cohort.name }
      end

      it "shows the filtered cohort member count with criteria #{cohort.search_criteria.list_filters}" do
        @homepage.wait_until(Utils.short_wait, "Expected #{cohort.member_data.length} but got #{@homepage.member_count(cohort)}") { @homepage.member_count(cohort) == cohort.member_data.length }
      end

      it "shows the first 50 filtered cohort members who have alerts on the homepage with criteria #{cohort.search_criteria.list_filters}" do
        expected_sids_by_name = @homepage.expected_sids_by_name cohort.member_data
        cohort.members = test.students.select { |u| expected_sids_by_name.include? u.sis_id }
        @homepage.expand_member_rows cohort
        @homepage.verify_member_alerts(@driver, cohort, test.advisor)
      end

      it "by default sorts by alert count descending the first 50 cohort members who have alerts on the homepage with criteria #{cohort.search_criteria.list_filters}" do
        if cohort.member_data.any?
          expected_sequence = @homepage.expected_sids_by_alerts_desc cohort.member_data
          @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids(@driver, cohort)}") { @homepage.all_row_sids(@driver, cohort) == expected_sequence }
        end
      end

      it "allows the advisor to sort by alert count ascending the first 50 cohort members who have alerts on the homepage with criteria #{cohort.search_criteria.list_filters}" do
        if cohort.member_data.any?
          expected_sequence = @homepage.expected_sids_by_alerts cohort.member_data
          @homepage.sort_by_alert_count cohort
          @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids(@driver, cohort)}") { @homepage.all_row_sids(@driver, cohort) == expected_sequence }
        end
      end

      it "allows the advisor to sort by name ascending cohort the first 50 members who have alerts on the homepage with criteria #{cohort.search_criteria.list_filters}" do
        if cohort.member_data.any?
          expected_sequence = @homepage.expected_sids_by_name cohort.member_data
          @homepage.sort_by_name cohort
          @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids(@driver, cohort)}") { @homepage.all_row_sids(@driver, cohort) == expected_sequence }
        end
      end

      it "allows the advisor to sort by name descending the first 50 cohort members who have alerts on the homepage with criteria #{cohort.search_criteria.list_filters}" do
        if cohort.member_data.any?
          expected_sequence = @homepage.expected_sids_by_name_desc cohort.member_data
          @homepage.sort_by_name cohort
          @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids(@driver, cohort)}") { @homepage.all_row_sids(@driver, cohort) == expected_sequence }
        end
      end

      it "allows the advisor to sort by SID ascending the first 50 cohort members who have alerts on the homepage with criteria #{cohort.search_criteria.list_filters}" do
        if cohort.member_data.any?
          expected_sequence = @homepage.expected_sids_by_sid cohort.member_data
          @homepage.sort_by_sid cohort
          @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids(@driver, cohort)}") { @homepage.all_row_sids(@driver, cohort) == expected_sequence }
        end
      end

      it "allows the advisor to sort by SID descending the first 50 cohort members who have alerts on the homepage with criteria #{cohort.search_criteria.list_filters}" do
        if cohort.member_data.any?
          expected_sequence = @homepage.expected_sids_by_sid(cohort.member_data).reverse
          @homepage.sort_by_sid cohort
          @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids(@driver, cohort)}") { @homepage.all_row_sids(@driver, cohort) == expected_sequence }
        end
      end

      it "allows the advisor to sort by major ascending the first 50 cohort members who have alerts on the homepage with criteria #{cohort.search_criteria.list_filters}" do
        if cohort.member_data.any?
          expected_sequence = @homepage.expected_sids_by_major cohort.member_data
          @homepage.sort_by_major cohort
          @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids(@driver, cohort)}") { @homepage.all_row_sids(@driver, cohort) == expected_sequence }
        end
      end

      it "allows the advisor to sort by major descending the first 50 cohort members who have alerts on the homepage with criteria #{cohort.search_criteria.list_filters}" do
        if cohort.member_data.any?
          expected_sequence = @homepage.expected_sids_by_major_desc cohort.member_data
          @homepage.sort_by_major cohort
          @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids(@driver, cohort)}") { @homepage.all_row_sids(@driver, cohort) == expected_sequence }
        end
      end

      it "allows the advisor to sort by expected grad date ascending the first 50 cohort members who have alerts on the homepage with criteria #{cohort.search_criteria.list_filters}" do
        if cohort.member_data.any?
          expected_sequence = @homepage.expected_sids_by_grad_term cohort.member_data
          @homepage.sort_by_expected_grad cohort
          @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids@driver, cohort}") { @homepage.all_row_sids(@driver, cohort) == expected_sequence }
        end
      end

      it "allows the advisor to sort by expected grad date descending the first 50 cohort members who have alerts on the homepage with criteria #{cohort.search_criteria.list_filters}" do
        if cohort.member_data.any?
          expected_sequence = @homepage.expected_sids_by_grad_term_desc cohort.member_data
          @homepage.sort_by_expected_grad cohort
          @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids@driver, cohort}") { @homepage.all_row_sids(@driver, cohort) == expected_sequence }
        end
      end

      it "allows the advisor to sort by term units ascending the first 50 cohort members who have alerts on the homepage with criteria #{cohort.search_criteria.list_filters}" do
        if cohort.member_data.any?
          # Scrape the visible term units since it's not stored in the cohort member data
          cohort.member_data.each { |d| d.merge!({:term_units => @homepage.user_row_data(@driver, d[:sid], @homepage.filtered_cohort_xpath(cohort))[:term_units]}) }
          expected_sequence = @homepage.expected_sids_by_term_units cohort.member_data
          @homepage.sort_by_term_units cohort
          @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids(@driver, cohort)}") { @homepage.all_row_sids(@driver, cohort) == expected_sequence }
        end
      end

      it "allows the advisor to sort by term units descending the first 50 cohort members who have alerts on the homepage with criteria #{cohort.search_criteria.list_filters}" do
        if cohort.member_data.any?
          expected_sequence = @homepage.expected_sids_by_term_units_desc cohort.member_data
          @homepage.sort_by_term_units cohort
          @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids(@driver, cohort)}") { @homepage.all_row_sids(@driver, cohort) == expected_sequence }
        end
      end

      it "allows the advisor to sort by cumulative units ascending the first 50 cohort members who have alerts on the homepage with criteria #{cohort.search_criteria.list_filters}" do
        if cohort.member_data.any?
          expected_sequence = @homepage.expected_sids_by_units_cum cohort.member_data
          @homepage.sort_by_cumul_units cohort
          @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids(@driver, cohort)}") { @homepage.all_row_sids(@driver, cohort) == expected_sequence }
        end
      end

      it "allows the advisor to sort by cumulative descending the first 50 cohort members who have alerts on the homepage with criteria #{cohort.search_criteria.list_filters}" do
        if cohort.member_data.any?
          expected_sequence = @homepage.expected_sids_by_units_cum_desc cohort.member_data
          @homepage.sort_by_cumul_units cohort
          @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids(@driver, cohort)}") { @homepage.all_row_sids(@driver, cohort) == expected_sequence }
        end
      end

      it "allows the advisor to sort by GPA ascending the first 50 cohort members who have alerts on the homepage with criteria #{cohort.search_criteria.list_filters}" do
        if cohort.member_data.any?
          expected_sequence = @homepage.expected_sids_by_gpa cohort.member_data
          @homepage.sort_by_gpa cohort
          @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids(@driver, cohort)}") { @homepage.all_row_sids(@driver, cohort) == expected_sequence }
        end
      end

      it "allows the advisor to sort by GPA descending the first 50 cohort members who have alerts on the homepage with criteria #{cohort.search_criteria.list_filters}" do
        if cohort.member_data.any?
          expected_sequence = @homepage.expected_sids_by_gpa_desc cohort.member_data
          @homepage.sort_by_gpa cohort
          @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids(@driver, cohort)}") { @homepage.all_row_sids(@driver, cohort) == expected_sequence }
        end
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
      @homepage.load_page
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

  context 'when the advisor enters invalid filter input' do

    before(:all) { @homepage.click_sidebar_create_filtered }

    shared_examples 'GPA range validation' do |filter_name|
      before(:all) do
        @cohort_page.click_new_filter_button
        @cohort_page.wait_for_update_and_click @cohort_page.new_filter_option filter_name
      end

      it 'an error prompts for numeric input' do
        @cohort_page.choose_new_filter_sub_option(filter_name, {'min' => 'A', 'max' => ''})
        @cohort_page.gpa_filter_range_error_element.when_visible 1
      end

      it 'an error prompts for logical numeric input' do
        @cohort_page.choose_new_filter_sub_option(filter_name, {'min' => '4', 'max' => '0'})
        @cohort_page.gpa_filter_logical_error_element.when_visible 1
      end

      it 'an error prompts for numeric input from 0 to 4' do
        @cohort_page.choose_new_filter_sub_option(filter_name, {'min' => '-1', 'max' => '5'})
        @cohort_page.gpa_filter_range_error_element.when_visible 1
      end

      it 'no Add button appears without two valid values' do
        @cohort_page.choose_new_filter_sub_option(filter_name, {'min' => '3.5', 'max' => ''})
        expect(@cohort_page.unsaved_filter_add_button?).to be false
      end
    end

    context 'in the cumulative GPA filter' do
      include_examples 'GPA range validation', 'gpaRanges'
    end

    context 'in the term GPA filter' do
      include_examples 'GPA range validation', 'lastTermGpaRanges'
    end

    context 'in the Last Name filter' do

      before(:all) do
        @cohort_page.unsaved_filter_cancel_button
        @cohort_page.click_new_filter_button
        @cohort_page.wait_for_update_and_click @cohort_page.new_filter_option 'lastNameRanges'
      end

      it 'an error prompts for logical input' do
        @cohort_page.choose_new_filter_sub_option('lastNameRanges', {'min' => 'Z', 'max' => 'A'})
        @cohort_page.last_name_filter_logical_error_element.when_visible 1
      end

      it 'no Add button appears without two valid values' do
        @cohort_page.choose_new_filter_sub_option('lastNameRanges', {'min' => 'P', 'max' => ''})
        expect(@cohort_page.unsaved_filter_add_button?).to be false
      end
    end
  end

  context 'when the advisor edits a cohort\'s search filters' do

    before(:all) { @cohort_page.search_and_create_new_cohort(test.default_cohort, test) }

    it 'allows the advisor to edit a cumulative GPA filter' do
      test.default_cohort.search_criteria.gpa = [{'min' => '3.00', 'max' => '4'}]
      @cohort_page.edit_filter_and_confirm('GPA (Cumulative)', test.default_cohort.search_criteria.gpa.first)
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove a cumulative GPA filter' do
      test.default_cohort.search_criteria.gpa = []
      @cohort_page.remove_filter_of_type 'GPA (Cumulative)'
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to edit a term GPA filter' do
      test.default_cohort.search_criteria.gpa_last_term = [{'min' => '2', 'max' => '3.80'}]
      @cohort_page.edit_filter_and_confirm('GPA (Last Term)', test.default_cohort.search_criteria.gpa_last_term.first)
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove a term GPA filter' do
      test.default_cohort.search_criteria.gpa_last_term = []
      @cohort_page.remove_filter_of_type 'GPA (Last Term)'
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
      test.default_cohort.search_criteria.major = ['Bioengineering BS']
      @cohort_page.edit_filter_and_confirm('Major', test.default_cohort.search_criteria.major.first)
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove a Major filter' do
      test.default_cohort.search_criteria.major = []
      @cohort_page.remove_filter_of_type 'Major'
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove a Transfer Student filter' do
      test.default_cohort.search_criteria.transfer_student = false
      @cohort_page.remove_filter_of_type 'Transfer Student'
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to edit an Entering Term filter' do
      new_term_id = (test.default_cohort.search_criteria.entering_terms.first.to_i - 10).to_s
      test.default_cohort.search_criteria.entering_terms = [new_term_id]
      @cohort_page.edit_filter_and_confirm('Entering Term', test.default_cohort.search_criteria.entering_terms.first)
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove an Entering Term filter' do
      test.default_cohort.search_criteria.entering_terms = []
      @cohort_page.remove_filter_of_type 'Entering Term'
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to edit an Expected Graduation Term filter' do
      new_term_id = (test.default_cohort.search_criteria.expected_grad_terms.first.to_i + 10).to_s
      test.default_cohort.search_criteria.expected_grad_terms = [new_term_id]
      @cohort_page.edit_filter_and_confirm('Expected Graduation Term', test.default_cohort.search_criteria.expected_grad_terms.first)
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove an Expected Graduation Term filter' do
      test.default_cohort.search_criteria.expected_grad_terms = []
      @cohort_page.remove_filter_of_type 'Expected Graduation Term'
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove an Unrepresented Minority filter' do
      test.default_cohort.search_criteria.underrepresented_minority = false
      @cohort_page.remove_filter_of_type 'Underrepresented Minority'
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to edit an Ethnicity filter' do
      test.default_cohort.search_criteria.ethnicity = ['Thai']
      @cohort_page.edit_filter_and_confirm('Ethnicity', test.default_cohort.search_criteria.ethnicity.first)
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove an Ethnicity filter' do
      test.default_cohort.search_criteria.ethnicity = []
      @cohort_page.remove_filter_of_type 'Ethnicity'
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to edit a Gender filter' do
      test.default_cohort.search_criteria.gender = ['Female']
      @cohort_page.edit_filter_and_confirm('Gender', test.default_cohort.search_criteria.gender.first)
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove a Gender filter' do
      test.default_cohort.search_criteria.gender = []
      @cohort_page.remove_filter_of_type 'Gender'
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to edit an Ethnicity (COE) filter' do
      test.default_cohort.search_criteria.coe_ethnicity = ['Mexican / Mexican-American / Chicano']
      @cohort_page.edit_filter_and_confirm('Ethnicity (COE)', test.default_cohort.search_criteria.coe_ethnicity.first)
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove an Ethnicity (COE) filter' do
      test.default_cohort.search_criteria.coe_ethnicity = []
      @cohort_page.remove_filter_of_type 'Ethnicity (COE)'
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to edit a Gender (COE) filter' do
      test.default_cohort.search_criteria.coe_gender = ['Male']
      @cohort_page.edit_filter_and_confirm('Gender (COE)', test.default_cohort.search_criteria.coe_gender.first)
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove a Gender (COE) filter' do
      test.default_cohort.search_criteria.coe_gender = []
      @cohort_page.remove_filter_of_type 'Gender (COE)'
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove an Underrepresented Minority (COE) filter' do
      test.default_cohort.search_criteria.coe_underrepresented_minority = false
      @cohort_page.remove_filter_of_type 'Underrepresented Minority (COE)'
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove an Inactive (ASC) filter' do
      test.default_cohort.search_criteria.asc_inactive = false
      @cohort_page.remove_filter_of_type 'Inactive (ASC)'
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove an Intensive filter' do
      test.default_cohort.search_criteria.asc_intensive = false
      @cohort_page.remove_filter_of_type 'Intensive'
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to edit a Team filter' do
      test.default_cohort.search_criteria.asc_team = [Squad::WCR]
      @cohort_page.edit_filter_and_confirm('Team', test.default_cohort.search_criteria.asc_team.first.name)
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove a Team filter' do
      test.default_cohort.search_criteria.asc_team = []
      @cohort_page.remove_filter_of_type 'Team'
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to edit a PREP filter' do
      test.default_cohort.search_criteria.coe_prep = ['T-PREP']
      @cohort_page.edit_filter_and_confirm('PREP', test.default_cohort.search_criteria.coe_prep.first)
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove a PREP filter' do
      test.default_cohort.search_criteria.coe_prep = []
      @cohort_page.remove_filter_of_type 'PREP'
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to edit a Last Name filter' do
      test.default_cohort.search_criteria.last_name = [{'min' => 'B', 'max' => 'Y'}]
      @cohort_page.edit_filter_and_confirm('Last Name', test.default_cohort.search_criteria.last_name.first)
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove a Last Name filter' do
      test.default_cohort.search_criteria.last_name = nil
      @cohort_page.remove_filter_of_type 'Last Name'
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to edit a My Students filter' do
      if test.default_cohort.search_criteria.cohort_owner_academic_plans
        test.default_cohort.search_criteria.cohort_owner_academic_plans = ['*']
        @cohort_page.edit_filter_and_confirm('My Students', '*')
        @cohort_page.verify_filters_present test.default_cohort
      else
        logger.warn 'Skipping test for editing My Students since the filter is not available to the user'
      end
    end

    it 'allows the advisor to remove a My Students filter' do
      if test.default_cohort.search_criteria.cohort_owner_academic_plans
        test.default_cohort.search_criteria.cohort_owner_academic_plans = []
        @cohort_page.remove_filter_of_type 'My Students'
        @cohort_page.verify_filters_present test.default_cohort
      else
        logger.warn 'Skipping test for removing My Students since the filter is not available to the user'
      end
    end

    it 'allows the advisor to edit an Advisor (COE) filter' do
      test.default_cohort.search_criteria.coe_advisor = [BOACUtils.get_dept_advisors(BOACDepartments::COE).last.uid.to_s]
      @cohort_page.edit_filter_and_confirm('Advisor (COE)', test.default_cohort.search_criteria.coe_advisor.first)
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove an Advisor (COE) filter' do
      test.default_cohort.search_criteria.coe_advisor = []
      @cohort_page.remove_filter_of_type 'Advisor (COE)'
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove an Inactive (CoE) filter' do
      test.default_cohort.search_criteria.coe_inactive = false
      @cohort_page.remove_filter_of_type 'Inactive (COE)'
      @cohort_page.verify_filters_present test.default_cohort
    end

    it 'allows the advisor to remove a Probation filter' do
      test.default_cohort.search_criteria.coe_probation = false
      @cohort_page.remove_filter_of_type 'Probation'
      @cohort_page.verify_filters_present test.default_cohort
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
      @cohort_page.load_cohort test.searches.first
      @cohort_page.delete_cohort test.searches.first
    end

    it 'shows a Not Found page' do
      @cohort_page.navigate_to "#{BOACUtils.base_url}/cohort/#{test.searches.first.id}"
      @cohort_page.wait_for_title 'Page not found'
    end
  end

end
