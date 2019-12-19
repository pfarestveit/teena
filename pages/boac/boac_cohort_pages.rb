require_relative '../../util/spec_helper'

module BOACCohortPages

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACListViewPages

  h1(:results, xpath: '//h1')

  button(:rename_cohort_button, id: 'rename-button')
  button(:rename_cohort_confirm_button, id: 'rename-confirm')
  button(:rename_cohort_cancel_button, id: 'rename-cancel')

  button(:delete_cohort_button, id: 'delete-button')
  button(:confirm_delete_button, id: 'delete-confirm')
  button(:cancel_delete_button, id: 'delete-cancel')

  button(:export_list_button, id: 'export-student-list-button')
  button(:confirm_export_list_button, id: 'export-list-confirm')

  span(:no_access_msg, xpath: '//span[text()="You are unauthorized to access student data managed by other departments"]')
  span(:title_required_msg, xpath: '//span[text()="Required"]')

  # Returns the search results count in the page heading
  # @return [Integer]
  def results_count
    sleep 1
    results_element.when_visible Utils.short_wait
    results.split[0].to_i
  end

  # Deletes a cohort unless it is read-only (e.g., CoE default cohorts).
  # @param cohort [Cohort]
  def delete_cohort(cohort)
    logger.info "Deleting a cohort named #{cohort.name}"
    wait_for_load_and_click delete_cohort_button_element
    wait_for_update_and_click confirm_delete_button_element
    wait_until(Utils.short_wait) { current_url == "#{BOACUtils.base_url}/home" }
    sleep Utils.click_wait
  end

  # Begins deleting a cohort but cancels
  # @param cohort [Cohort]
  def cancel_cohort_deletion(cohort)
    logger.info "Canceling the deletion of cohort #{cohort.name}"
    wait_for_load_and_click delete_cohort_button_element
    wait_for_update_and_click cancel_delete_button_element
    cancel_delete_button_element.when_not_present Utils.short_wait
    wait_until(1) { current_url.include? cohort.id }
  end

  # Clicks the Export List button and parses the resulting file
  # @param cohort [Cohort]
  # @return [CSV::Table]
  def export_student_list(cohort)
    logger.info "Exporting student list with default columns for #{cohort.instance_of?(FilteredCohort) ? 'cohort' : 'group'} ID '#{cohort.id}'"
    Utils.prepare_download_dir
    wait_for_element(export_list_button_element, Utils.medium_wait)
    wait_until(3) { !export_list_button_element.disabled? }
    wait_for_update_and_click export_list_button_element
    wait_for_update_and_click confirm_export_list_button_element
    csv_file_path = "#{Utils.download_dir}/#{cohort.name + '-' if cohort.id}students-#{Time.now.strftime('%Y-%m-%d')}_*.csv"
    wait_until(20) { Dir[csv_file_path].any? }
    CSV.table Dir[csv_file_path].first
  end

  # Clicks the Export List button and parses the resulting file
  # @param cohort [Cohort]
  # @return [CSV::Table]
  def export_custom_student_list(cohort)
    logger.info "Exporting student list with custom columns for #{cohort.instance_of?(FilteredCohort) ? 'cohort' : 'group'} ID '#{cohort.id}'"
    Utils.prepare_download_dir
    wait_for_element(export_list_button_element, Utils.medium_wait)
    wait_until(3) { !export_list_button_element.disabled? }
    wait_for_update_and_click export_list_button_element
    13.times do |idx|
      (el = checkbox_element(id: "csv-column-options__BV_option_#{idx}_")).when_present Utils.short_wait
      js_click el
    end
    wait_for_update_and_click confirm_export_list_button_element
    csv_file_path = "#{Utils.download_dir}/#{cohort.name + '-' if cohort.id}students-#{Time.now.strftime('%Y-%m-%d')}_*.csv"
    wait_until(20) { Dir[csv_file_path].any? }
    CSV.table Dir[csv_file_path].first
  end

  # Verifies that the filtered cohort or curated group members in a CSV export match the actual members
  # @param cohort_members [Array<Object>]
  # @param parsed_csv [CSV::Table]
  def verify_student_list_default_export(cohort_members, parsed_csv)
    wait_until(1, "Expected #{cohort_members.length}, got #{parsed_csv.length}") { parsed_csv.length == cohort_members.length }
    # Curated groups contain user objects
    if cohort_members.all? { |m| m.instance_of? BOACUser }
      cohort_members.each do |stu|
        wait_until(1, "Unable to find SID #{stu.sis_id}") do
          parsed_csv.find do |r|
            (r.dig(:first_name) == stu.first_name) &&
                (r.dig(:last_name) == stu.last_name) &&
                (r.dig(:sid) == stu.sis_id.to_i)
          end
        end
      end
    # Filtered cohorts contain user hashes
    else
      cohort_members.each do |stu|
        wait_until(1, "Unable to find SID #{stu[:sid]}") do
          parsed_csv.find do |r|
            (r.dig(:first_name) == stu[:first_name]) &&
                (r.dig(:last_name) == stu[:last_name]) &&
                (r.dig(:sid) == stu[:sid].to_i)
          end
        end
      end
    end
    # Make sure there's some phone / email data
    wait_until(1) do
      parsed_csv.by_col!
      parsed_csv.dig(:email).compact.any?
      parsed_csv.dig(:phone).compact.any?
    end
  end

  # Verifies that the CSV export includes all available columns
  # @param cohort_members [Array<Object>]
  # @param parsed_csv [CSV::Table]
  def verify_student_list_custom_export(cohort_members, parsed_csv)
    wait_until(1, "Expected #{cohort_members.length}, got #{parsed_csv.length}") { parsed_csv.length == cohort_members.length }
    wait_until(1) do
      parsed_csv.by_col!
      parsed_csv.dig(:majors).compact.any?
      parsed_csv.dig(:level).compact.any?
      parsed_csv.dig(:terms_in_attendance).compact.any?
      parsed_csv.dig(:expected_graduation_date).compact.any?
      parsed_csv.dig(:units_completed).compact.any?
      parsed_csv.dig(:term_gpa).compact.any?
      parsed_csv.dig(:cumulative_gpa).compact.any?
      parsed_csv.dig(:program_status).compact.any?
    end

  end

  # LIST VIEW - shared by filtered cohorts and curated groups

  # Returns the XPath to the div containing data for a single student
  # @param student [BOACUser]
  # @return [String]
  def student_row_xpath(student)
    "//div[@id=\"student-#{student.uid}\"]"
  end

  # Returns a student's SIS data visible on the cohort page
  # @param [Selenium::WebDriver]
  # @param student [BOACUser]
  # @return [Hash]
  def visible_sis_data(driver, student)
    #
    # Note: 'row_index' is position of student in list. For each student listed, the page has two hidden span elements
    #       useful in determining (1) 'row_index' if you know the SID, or (2) SID if you know the 'row_index':
    #
    #          <span id="row-index-of-{student.sid}">{{ rowIndex }}</span>
    #          <span id="student-sid-of-row-{rowIndex}">{{ student.sid }}</span>
    #
    wait_until(Utils.medium_wait) { player_link_elements.any? }
    level_el = div_element(xpath: "#{student_row_xpath student}//div[contains(@id,\"student-level\")]")
    major_els = driver.find_elements(xpath: "#{student_row_xpath student}//span[contains(@id,\"student-major\")]")
    entered_term_el = div_element(xpath: "#{student_row_xpath student}//div[contains(@id,\"student-matriculation\")]")
    grad_term_el = div_element(xpath: "#{student_row_xpath student}//div[contains(@id,\"student-grad-term\")]")
    graduation_date_el = span_element(xpath: "#{student_row_xpath student}//span[starts-with(text(),\"Graduated\")]")
    graduation_college_els = driver.find_elements(xpath: "#{student_row_xpath student}//div/span[starts-with(text(),\"Graduated\")]/../following-sibling::div")
    sports_els = driver.find_elements(xpath: "#{student_row_xpath student}//span[contains(@id,\"student-team\")]")
    gpa_el = span_element(xpath: "#{student_row_xpath student}//span[contains(@id,\"student-cumulative-gpa\")]")
    term_units_el = div_element(xpath: "#{student_row_xpath student}//div[contains(@id,\"student-enrolled-units\")]")
    cumul_units_el = div_element(xpath: "#{student_row_xpath student}//div[contains(@id,\"cumulative-units\")]")
    class_els = driver.find_elements(xpath: "#{student_row_xpath student}//span[contains(@id,\"student-enrollment-name\")]")
    waitlisted_class_els = driver.find_elements(xpath: "#{student_row_xpath student}//span[contains(@id,\"-waitlisted-\")]/preceding-sibling::span")
    inactive_el = div_element(xpath: "#{student_row_xpath student}//div[contains(@class,\"student-sid\")]/div[contains(@id,\"-inactive\")]")
    {
      :level => (level_el.text.strip if level_el.exists?),
      :majors => (major_els.map &:text if major_els.any?),
      :entered_term => (entered_term_el.text.gsub('Entered', '').strip if entered_term_el.exists?),
      :grad_term => (("#{grad_term_el.text.split[1]} #{grad_term_el.text.split[2]}") if grad_term_el.exists?),
      :graduation_date => (graduation_date_el.text.strip if graduation_date_el.exists?),
      :graduation_colleges => (graduation_college_els.map &:text if graduation_college_els.any?),
      :sports => (sports_els.map &:text if sports_els.any?),
      :gpa => (gpa_el.text.gsub('No data', '').chomp if gpa_el.exists?),
      :term_units => (term_units_el.text if term_units_el.exists?),
      :units_cumulative => (cumul_units_el.text.gsub('No data', '').chomp if cumul_units_el.exists?),
      :classes => class_els.map(&:text),
      :waitlisted_classes => waitlisted_class_els.map(&:text),
      :inactive => (inactive_el.exists? && inactive_el.text.strip == 'INACTIVE')
    }
  end

  # SORTING

  select_list(:cohort_sort_select, id: 'students-sort-by')

  # Sorts cohort search results by a given option
  # @param option [String]
  def sort_by(option)
    logger.info "Sorting by #{option}"
    wait_for_element_and_select_js(cohort_sort_select_element, option)
    wait_until(2) { player_sid_elements.empty? }
    wait_for_spinner
  end

  # Sorts cohort search results by first name
  def sort_by_first_name
    sort_by 'First Name'
  end

  # Sorts cohort search results by last name
  def sort_by_last_name
    sort_by 'Last Name'
  end

  # Sorts cohort search results by team
  def sort_by_team
    sort_by 'Team'
  end

  # Sorts cohort search results by GPA (Cumulative)
  def sort_by_gpa_cumulative
    sort_by 'GPA (Cumulative)'
  end

  # Sorts cohort search results by a given previous term
  # @param term_code [String]
  def sort_by_last_term_gpa(term_code)
    sort_by "term_gpa_#{term_code}"
  end

  # Sorts cohort search results by level
  def sort_by_level
    sort_by 'Level'
  end

  # Sorts cohort search results by major
  def sort_by_major
    sort_by 'Major'
  end

  # Sorts cohort search results by entering term
  def sort_by_entering_term
    sort_by 'Entering Term'
  end

  # Sorts cohort search results by units in progress
  def sort_by_units_in_progress
    sort_by 'Units (In Progress)'
  end

  # Sorts cohort search results by units completed
  def sort_by_units_completed
    sort_by 'Units (Completed)'
  end

end
