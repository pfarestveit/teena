require_relative '../util/spec_helper'

begin

  include Logging

  performance_data = File.join(Utils.initialize_test_output_dir, "boac-search-performance-#{Utils.get_test_id}.csv")
  all_students = NessieUtils.get_all_students
  test = BOACTestConfig.new
  test.filtered_cohorts all_students

  @driver = Utils.launch_browser
  @analytics_page = ApiUserAnalyticsPage.new @driver
  @homepage = Page::BOACPages::HomePage.new @driver
  @cohort_page = Page::BOACPages::CohortPages::FilteredCohortListViewPage.new @driver
  @homepage.dev_auth test.advisor

  test.searches.each do |cohort|
    begin

      # SEARCHING

      @homepage.load_page
      @homepage.click_sidebar_create_filtered
      @cohort_page.perform_search(cohort, performance_data)

      # SORTING

      if cohort.member_count.zero?
        logger.debug 'Skipping sort-by since there are no results'
      else

        # Team
        if dept == BOACDepartments::ASC
          @cohort_page.sort_by_team
          @cohort_page.wait_for_spinner
          @cohort_page.wait_for_student_list
        end

        # First Name
        @cohort_page.sort_by_first_name
        @cohort_page.wait_for_spinner
        @cohort_page.wait_for_student_list

        # GPA
        @cohort_page.sort_by_gpa
        @cohort_page.wait_for_spinner
        @cohort_page.wait_for_student_list

        # Level
        @cohort_page.sort_by_level
        @cohort_page.wait_for_spinner
        @cohort_page.wait_for_student_list

        # Major
        @cohort_page.sort_by_major
        @cohort_page.wait_for_spinner
        @cohort_page.wait_for_student_list

        # Units
        @cohort_page.sort_by_units
        @cohort_page.wait_for_spinner
        @cohort_page.wait_for_student_list

      end
    rescue => e
      Utils.log_error e
    end
  end

ensure
  Utils.quit_browser @driver
end
