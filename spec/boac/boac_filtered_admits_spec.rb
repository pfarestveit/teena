require_relative '../../util/spec_helper'

describe 'BOA' do

  include Logging

  test = BOACTestConfig.new
  test.filtered_admits
  existing_cohorts = BOACUtils.get_user_filtered_cohorts test.advisor, admits: true
  latest_update_date = NessieUtils.get_admit_data_update_date

  before(:all) do
    @driver = Utils.launch_browser test.chrome_profile
    @homepage = BOACHomePage.new @driver
    @cohort_page = BOACFilteredAdmitsPage.new @driver
    @admit_page = BOACAdmitPage.new @driver

    @homepage.dev_auth test.advisor
    existing_cohorts.each do |c|
      @cohort_page.load_cohort c
      @cohort_page.delete_cohort c
    end
  end

  after(:all) { Utils.quit_browser @driver }

  context 'filtered cohort search' do

    before(:each) { @cohort_page.cancel_cohort if @cohort_page.cancel_cohort_button? && @cohort_page.cancel_cohort_button_element.visible? }

    test.searches.each do |cohort|

      it "shows all the admits sorted by Last Name who match #{cohort.search_criteria.inspect}" do
        @cohort_page.click_sidebar_create_ce3_filtered
        @cohort_page.perform_admit_search cohort
        cohort.member_data = @cohort_page.expected_admit_search_results(test, cohort.search_criteria)
        expected_results = @cohort_page.expected_sids_by_last_name cohort.member_data
        if cohort.member_data.length.zero?
          @cohort_page.wait_until(Utils.short_wait) { @cohort_page.results_count == 0 }
        else
          @cohort_page.sort_by_last_name
          visible_results = @cohort_page.filter_result_all_row_cs_ids cohort
          @cohort_page.wait_until(1, "Expected but not present: #{expected_results - visible_results}. Present but not expected: #{visible_results - expected_results}") do
            visible_results.sort == expected_results.sort
          end
          @cohort_page.verify_list_view_sorting(expected_results, visible_results)
        end
      end

      it("shows the most recent data update date for #{cohort.search_criteria.inspect}") { @cohort_page.data_update_date_heading(latest_update_date).when_visible Utils.short_wait }

      it "shows the right data for the admits who match #{cohort.search_criteria.inspect}" do
        failures = []
        visible_sids = @cohort_page.filter_result_row_cs_ids
        expected_admit_data = cohort.member_data.select { |d| visible_sids.include? d[:sid] }
        expected_admit_data.each { |admit| @cohort_page.verify_admit_row_data(admit[:sid], admit, failures) }
        logger.error "Failures: #{failures}" unless failures.empty?
        expect(failures).to be_empty
      end

      it "sorts by First Name all the admits who match #{cohort.search_criteria.inspect}" do
        @cohort_page.sort_by_first_name
        expected_results = @cohort_page.expected_sids_by_first_name(cohort.member_data)
        visible_results = @cohort_page.filter_result_all_row_cs_ids cohort
        @cohort_page.verify_list_view_sorting(expected_results, visible_results)
        @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
      end

      it "sorts by CS ID all the admits who match #{cohort.search_criteria.inspect}" do
        @cohort_page.sort_by_cs_id
        expected_results = cohort.member_data.map { |u| u[:sid].to_i }.sort
        visible_results = @cohort_page.filter_result_all_row_cs_ids cohort
        @cohort_page.verify_list_view_sorting(expected_results, visible_results)
        @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
      end

      it("offers an Export List button for a search #{cohort.search_criteria.inspect}") { expect(@cohort_page.export_list_button?).to be true }

      it("allows the advisor to create a cohort using #{cohort.search_criteria.inspect}") { @cohort_page.create_new_cohort cohort }

      it("shows the cohort filters for a cohort using #{cohort.search_criteria.inspect}") { @cohort_page.verify_admit_filters_present cohort }

      it("shows the cohort member count in the sidebar using #{cohort.search_criteria.inspect}") { @cohort_page.wait_for_sidebar_cohort_member_count cohort }

      it("offers no cohort history button for a cohort using #{cohort.search_criteria.inspect}") { expect(@cohort_page.history_button?).to be false }

      # TODO it "allows the advisor to export a non-empty list of students in a cohort using #{cohort.search_criteria.list_filters}"
      # TODO it "allows the advisor to choose columns to include when exporting a cohort using #{cohort.search_criteria.list_filters}"
    end

    context 'when the advisor enters invalid filter input in a Dependents' do

      before(:all) { @homepage.click_sidebar_create_ce3_filtered }

      shared_examples 'dependent range validation' do |filter_name|
        before(:all) do
          @cohort_page.click_new_filter_button
          @cohort_page.wait_for_update_and_click @cohort_page.new_filter_option filter_name
        end

        it 'an error prompts for numeric input' do
          @cohort_page.choose_new_filter_sub_option(filter_name, {'min' => 'A', 'max' => ''})
          @cohort_page.depend_char_error_msg_element.when_visible 1
        end

        it 'an error prompts for logical numeric input' do
          @cohort_page.choose_new_filter_sub_option(filter_name, {'min' => '4', 'max' => '0'})
          @cohort_page.depend_logic_error_msg_element.when_visible 1
        end

        it 'an error prompts for numeric input from 0 to 4' do
          @cohort_page.choose_new_filter_sub_option(filter_name, {'min' => '-1', 'max' => '5'})
          @cohort_page.depend_char_error_msg_element.when_visible 1
        end

        it 'no Add button appears without two valid values' do
          @cohort_page.choose_new_filter_sub_option(filter_name, {'min' => '3.5', 'max' => ''})
          expect(@cohort_page.unsaved_filter_add_button?).to be false
        end
      end

      context 'in the Family Dependents filter' do
        include_examples 'dependent range validation', 'familyDependentRanges'
      end

      context 'in the Student Dependents filter' do
        include_examples 'dependent range validation', 'studentDependentRanges'
      end
    end
  end
end
