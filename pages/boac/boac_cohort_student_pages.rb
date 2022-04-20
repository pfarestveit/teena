require_relative '../../util/spec_helper'

module BOACCohortStudentPages

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACListViewStudentPages
  include BOACCohortPages

  button(:confirm_export_list_button, id: 'export-list-confirm')

  span(:no_access_msg, xpath: '//span[text()="You are unauthorized to access student data managed by other departments"]')
  span(:title_required_msg, xpath: '//span[text()="Required"]')

  # Clicks the Export List button and parses the resulting file
  # @param cohort [Cohort]
  # @return [CSV]
  def export_student_list(cohort)
    logger.info "Exporting student list with default columns for #{cohort.instance_of?(FilteredCohort) ? 'cohort' : 'group'} ID '#{cohort.id}'"
    Utils.prepare_download_dir
    wait_for_element(export_list_button_element, Utils.medium_wait)
    wait_until(3) { !export_list_button_element.disabled? }
    wait_for_update_and_click export_list_button_element
    if (cohort.instance_of?(FilteredCohort) && !cohort.search_criteria.instance_of?(CohortAdmitFilter)) || cohort.instance_of?(CuratedGroup)
      wait_for_update_and_click confirm_export_list_button_element
    end
    csv_file_path = "#{Utils.download_dir}/#{cohort.name + '-' if cohort.id}students-#{Time.now.strftime('%Y-%m-%d')}_*.csv"
    wait_until(20) { Dir[csv_file_path].any? }
    CSV.table Dir[csv_file_path].first
  end

  # Clicks the Export List button and parses the resulting file
  # @param cohort [Cohort]
  # @return [CSV]
  def export_custom_student_list(cohort)
    logger.info "Exporting student list with custom columns for #{cohort.instance_of?(FilteredCohort) ? 'cohort' : 'group'} ID '#{cohort.id}'"
    Utils.prepare_download_dir
    wait_for_element(export_list_button_element, Utils.medium_wait)
    wait_until(3) { !export_list_button_element.disabled? }
    wait_for_update_and_click export_list_button_element
    19.times do |idx|
      (el = checkbox_element(id: "csv-column-options_BV_option_#{idx}")).when_present Utils.short_wait
      js_click el
    end
    wait_for_update_and_click confirm_export_list_button_element
    csv_file_path = "#{Utils.download_dir}/#{cohort.name + '-' if cohort.id}students-#{Time.now.strftime('%Y-%m-%d')}_*.csv"
    wait_until(20) { Dir[csv_file_path].any? }
    CSV.table Dir[csv_file_path].first
  end

  # Verifies that the filtered cohort or curated group members in a CSV export match the actual members
  # @param cohort_members [Array<BOACUser>]
  # @param parsed_csv [CSV::Table]
  def verify_student_list_default_export(cohort_members, parsed_csv)
    wait_until(1, "Expected #{cohort_members.length}, got #{parsed_csv.length}") { parsed_csv.length == cohort_members.length }
    wait_until(1) do
      parsed_csv.dig(:email).compact.any?
      parsed_csv.dig(:phone).compact.any?
    end
    cohort_members.each do |stu|
      row = parsed_csv.find { |r| r[:sid] == stu.sis_id.to_i }
      wait_until(1, "SID '#{stu.sis_id}' either has a name mismatch or an empty phone or email") do
        row[:first_name] == stu.first_name
        row[:last_name] == stu.last_name
      end
    end
  end

  # Verifies that the CSV export includes all available columns
  # @param cohort_members [Array<Object>]
  # @param parsed_csv [CSV::Table]
  def verify_student_list_custom_export(cohort_members, parsed_csv)
    wait_until(1, "Expected #{cohort_members.length}, got #{parsed_csv.length}") { parsed_csv.length == cohort_members.length }
    prev_term_code = BOACUtils.previous_term_code
    prev_prev_term_code = BOACUtils.previous_term_code prev_term_code
    wait_until(1) do
      parsed_csv.by_col!
      parsed_csv.dig(:majors).compact.any?
      parsed_csv.dig(:minors).compact.any?
      parsed_csv.dig(:subplans).compact.any?
      parsed_csv.dig(:level).compact.any?
      parsed_csv.dig(:terms_in_attendance).compact.any?
      parsed_csv.dig(:expected_graduation_date).compact.any?
      parsed_csv.dig(:units_completed).compact.any?
      parsed_csv.dig("term_gpa_#{prev_term_code}".to_sym).compact.any?
      parsed_csv.dig("term_gpa_#{prev_prev_term_code}".to_sym).compact.any?
      parsed_csv.dig(:cumulative_gpa).compact.any?
      parsed_csv.dig(:program_status).compact.any?
      parsed_csv.dig(:transfer).compact.any?
      parsed_csv.dig(:intended_major).compact.any?
      parsed_csv.dig(:units_in_progress).compact.any?
    end
  end

  # LIST VIEW - shared by filtered cohorts and curated groups

  button(:term_select_button, id: 'students-term-select__BV_toggle_')
  elements(:site_activity_header, :row, xpath: "//th[text()='BCOURSES ACTIVITY']")

  def select_term(term_id)
    logger.info "Selecting term ID #{term_id}"
    wait_for_update_and_click_js term_select_button_element
    wait_for_update_and_click_js button_element(id: "term-select-option-#{term_id}")
  end

  # Returns the XPath to the div containing data for a single student
  # @param student [BOACUser]
  # @return [String]
  def student_row_xpath(student)
    "//div[@id=\"student-#{student.uid}\"]"
  end

  def scroll_to_student(student)
    scroll_to_element row_element(xpath: student_row_xpath(student))
  end

  # Returns a student's SIS data visible on the cohort page
  # @param student [BOACUser]
  # @return [Hash]
  def visible_sis_data(student)
    wait_until(Utils.medium_wait) { player_link_elements.any? }
    level_el = div_element(xpath: "#{student_row_xpath student}//div[contains(@id,\"student-level\")]")
    major_els = span_elements(xpath: "#{student_row_xpath student}//span[contains(@id,\"student-major\")]")
    entered_term_el = div_element(xpath: "#{student_row_xpath student}//div[contains(@id,\"student-matriculation\")]")
    grad_term_el = div_element(xpath: "#{student_row_xpath student}//div[contains(@id,\"student-grad-term\")]")
    graduation_el = div_element(xpath: "#{student_row_xpath student}//div[starts-with(text(),\" Graduated\")]")
    sports_els = span_elements(xpath: "#{student_row_xpath student}//span[contains(@id,\"student-team\")]")
    gpa_el = span_element(xpath: "#{student_row_xpath student}//span[contains(@id,\"student-cumulative-gpa\")]")
    class_els = span_elements(xpath: "#{student_row_xpath student}//span[contains(@id,\"student-enrollment-name\")]")
    waitlisted_class_els = span_elements(xpath: "#{student_row_xpath student}//span[contains(@id,\"-waitlisted-\")]/preceding-sibling::span")
    inactive_el = div_element(xpath: "#{student_row_xpath student}//div[contains(@class,\"student-sid\")]/div[contains(@id,\"-inactive\")]")
    cxl_el = span_element(xpath: "#{student_row_xpath student}//div[contains(@id, \"withdrawal-cancel\")]/span")
    {
      :level => (level_el.text.strip if level_el.exists?),
      :majors => (major_els.map &:text if major_els.any?),
      :entered_term => (entered_term_el.text.gsub('Entered', '').strip if entered_term_el.exists?),
      :grad_term => (("#{grad_term_el.text.split[1]} #{grad_term_el.text.split[2]}") if grad_term_el.exists?),
      :graduation => (graduation_el.text.gsub('Graduated', '').strip if graduation_el.exists?),
      :sports => (sports_els.map &:text if sports_els.any?),
      :gpa => (gpa_el.text.gsub('No data', '').chomp if gpa_el.exists?),
      :classes => class_els.map(&:text),
      :waitlisted_classes => waitlisted_class_els.map(&:text),
      :inactive => (inactive_el.exists? && inactive_el.text.strip == 'INACTIVE'),
      :academic_standing => student_academic_standing(student),
      :cxl_msg => (cxl_el.text.strip if cxl_el.exists?)
    }
  end

  def visible_term_units(student)
    term_units_el = div_element(xpath: "#{student_row_xpath student}//div[contains(@id,\"student-enrolled-units\")]")
    term_units_el.text if term_units_el.exists?
  end

  def visible_term_units_max(student)
    el = span_element(xpath: "#{student_row_xpath student}//span[contains(@id,\"student-max-units\")]")
    el.text if el.exists?
  end

  def visible_term_units_min(student)
    el = span_element(xpath: "#{student_row_xpath student}//div[contains(@id,\"student-min-units\")]")
    el.text if el.exists?
  end

  def visible_cumul_units(student)
    cumul_units_el = div_element(xpath: "#{student_row_xpath student}//div[contains(@id,\"cumulative-units\")]")
    cumul_units_el.text.gsub('No data', '').chomp if cumul_units_el.exists?
  end

  def visible_courses_data(student)
    wait_until(Utils.medium_wait) { player_link_elements.any? }
    row_xpath = "#{student_row_xpath student}//table[@class=\"cohort-course-activity-table\"]/tr"
    row_els = row_elements(xpath: row_xpath)
    rows_data = []
    row_els.each_with_index do |_, i|
      unless i.zero?
        mid_flag_el = div_element(xpath: "#{row_xpath}[#{i + 1}]/td[3]/*[name()=\"svg\"][@data-icon=\"exclamation-triangle\"]")
        final_flag_el = div_element(xpath: "#{row_xpath}[#{i + 1}]/td[4]/*[name()=\"svg\"][@data-icon=\"exclamation-triangle\"]")
        rows_data << {
          course_code: cell_element(xpath: "#{row_xpath}[#{i + 1}]/td[1]").text,
          activity: cell_element(xpath: "#{row_xpath}[#{i + 1}]/td[2]").text,
          mid_grade: cell_element(xpath: "#{row_xpath}[#{i + 1}]/td[3]").text,
          mid_flag: mid_flag_el.exists?,
          final_grade: cell_element(xpath: "#{row_xpath}[#{i + 1}]/td[4]").text,
          final_flag: final_flag_el.exists?
        }
      end
    end
    rows_data
  end

  # SORTING

  # Sorts cohort search results by team
  def sort_by_team
    sort_by 'group_name'
  end

  # Sorts cohort search results by GPA (Cumulative) ascending
  def sort_by_gpa_cumulative
    sort_by 'gpa'
  end

  # Sorts cohort search results by GPA (Cumulative) descending
  def sort_by_gpa_cumulative_desc
    sort_by 'gpa desc'
  end

  # Sorts cohort search results by a given previous term GPA ascending
  # @param term_code [String]
  def sort_by_last_term_gpa(term_code)
    sort_by "term_gpa_#{term_code}"
  end

  # Sorts cohort search results by a given previous term GPA descending
  # @param term_code [String]
  def sort_by_last_term_gpa_desc(term_code)
    sort_by "term_gpa_#{term_code} desc"
  end

  # Sorts cohort search results by level
  def sort_by_level
    sort_by 'level'
  end

  # Sorts cohort search results by major
  def sort_by_major
    sort_by 'major'
  end

  # Sorts cohort search results by entering term
  def sort_by_entering_term
    sort_by 'entering_term'
  end

  # Sorts cohort search results by terms in attendance ascending
  def sort_by_terms_in_attend
    sort_by 'terms_in_attendance'
  end

  # Sorts cohort search results by terms in attendance descending
  def sort_by_terms_in_attend_desc
    sort_by 'terms_in_attendance desc'
  end

  # Sorts cohort search results by units in progress ascending
  def sort_by_units_in_progress
    sort_by 'enrolled_units'
  end

  # Sorts cohort search results by units in progress descending
  def sort_by_units_in_progress_desc
    sort_by 'enrolled_units desc'
  end

  # Sorts cohort search results by units completed ascending
  def sort_by_units_completed
    sort_by 'units'
  end

  # Sorts cohort search results by units completed descending
  def sort_by_units_completed_desc
    sort_by 'units desc'
  end

end
