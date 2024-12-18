class RipleyGradeDistributionPage

  include Logging
  include PageObject
  include Page
  include RipleyPages

  h1(:page_heading, xpath: '//h1[contains(., "Grade Distribution")]')
  div(:sorry_not_auth_msg, xpath: '//div[text()="Sorry, you are not authorized to use this tool."]')
  elements(:no_grades_msg, :div, xpath: '//*[text()="No data available until final grades are returned."]')
  div(:no_grade_dist_msg, xpath: '//div[text()="This course does not meet the requirements necessary to generate a Grade Distribution, or has not yet had final grades returned."]')
  div(:tooltip_key, xpath: '//div[@class="chart-tooltip-key"]')
  div(:tooltip_name, xpath: '//div[@class="chart-tooltip-name"]')

  def embedded_tool_path(course_site)
    "/courses/#{course_site.site_id}/external_tools/#{RipleyTool::NEWT.tool_id}"
  end

  def hit_embedded_tool_url(course_site)
    navigate_to "#{Utils.canvas_base_url}#{embedded_tool_path course_site}"
  end

  def load_embedded_tool(course_site)
    logger.info 'Loading embedded version of Grade Distribution tool'
    load_tool_in_canvas embedded_tool_path(course_site)
  end

  # Demographics

  h2(:demographics_heading, xpath: '//h2[text()="Grade Distribution by Demographics"]')
  select_list(:demographics_select, id: 'grade-distribution-demographics-select')
  select_list(:statistics_select, id: 'grade-distribution-statistic-select')
  button(:demographics_table_toggle, id: 'grade-distribution-demographics-show-btn')
  table(:demographics_table, id: 'grade-distribution-demo-table')
  elements(:demographics_table_row, :row, xpath: '//tr[contains(@id, "grade-distribution-demo-table-row")]')

  def select_demographic(demographic)
    logger.info "Selecting demographic '#{demographic}'"
    wait_for_element_and_select(demographics_select_element, demographic)
    sleep Utils.click_wait
  end

  def select_statistic(statistic)
    logger.info "Selecting statistic '#{statistic}'"
    wait_for_element_and_select(statistics_select_element, statistic)
    sleep Utils.click_wait
  end

  def expand_demographics_table
    if demographics_table_element.visible?
      logger.info 'Demographics table is already expanded'
    else
      logger.info 'Expanding demographics data table'
      wait_for_update_and_click demographics_table_toggle_element
      demographics_table_element.when_visible 2
    end
  end

  def visible_demographic_row_ct
    demographics_table_row_elements.length
  end

  def expected_demographic_count(enrollments)
    if enrollments.empty?
      'No data'
    else
      count = enrollments.length
      config = RipleyUtils.newt_small_cell_suppression
      (count >= 1 && count < config) ? 'Small sample size' : count.to_s
    end
  end

  def grades_to_grade_points(enrollments)
    grades = enrollments.map(&:grade).select { |g| %w(A+ A A- B+ B B- C+ C C- D+ D D- F I).include? g }
    grades.map! do |g|
      case g
      when 'A+', 'A'
        4.0
      when 'A-'
        3.7
      when 'B+'
        3.3
      when 'B'
        3.0
      when 'B-'
        2.7
      when 'C+'
        2.3
      when 'C'
        2.0
      when 'C-'
        1.7
      when 'D+'
        1.3
      when 'D'
        1.0
      when 'D-'
        0.7
      else
        0
      end
    end
    grades
  end

  def expected_mean_grade_points(enrollments)
    grades = grades_to_grade_points enrollments
    if grades.empty?
      'No data'
    else
      avg = (grades.inject { |ttl, g| ttl + g }.to_f / grades.length).round(1)
      avg = (sprintf '%.1f', avg).to_f
      ((avg.floor == avg) ? avg.floor : avg).to_s
    end
  end

  def expected_median_grade_points(enrollments)
    grades = grades_to_grade_points enrollments
    if grades.empty?
      'No data'
    else
      grades.sort!
      count = grades.length
      if count % 2 == 0
        bottom = (grades[0...(count / 2)])
        top = (grades[(count / 2)..-1])
        med = ((bottom[-1] + top[0]).to_f / 2.to_f)
      else
        med = grades[(count / 2).floor]
      end
      med = (sprintf '%.1f', med).to_f
      ((med.floor == med) ? med.floor : med).to_s
    end
  end

  def visible_demographics_term_data(term)
    sleep Utils.click_wait
    xpath = "//tr[contains(@id, 'grade-distribution-demo-table-row')][contains(., '#{term.name}')]"
    row_element(xpath: xpath).when_visible 10 rescue TimeoutError
    ttl_stat_el = cell_element(xpath: "#{xpath}/td[2]")
    ttl_count_el = cell_element(xpath: "#{xpath}/td[3]")
    sub_stat_el = cell_element(xpath: "#{xpath}/td[4]")
    sub_count_el = cell_element(xpath: "#{xpath}/td[5]")
    data = {
      term: term.name,
      ttl_stat: (ttl_stat_el.text if ttl_stat_el.exists?).to_s,
      ttl_ct: (ttl_count_el.text if ttl_count_el.exists?).to_s,
      sub_stat: (sub_stat_el.text if sub_stat_el.exists?).to_s,
      sub_ct: (sub_count_el.text if sub_count_el.exists?).to_s
    }
    logger.debug "Visible data: #{data}"
    data
  end

  # Prior enrollments

  h2(:prior_enrollment_heading, xpath: '//h2[text()="Grade Distribution by Prior Enrollment"]')
  select_list(:prior_enrollment_select, xpath: '//select[contains(@class, "grade-dist-enroll-term-select")]')
  text_field(:prior_enrollment_course_input, id: 'grade-distribution-enrollment-course-search')
  button(:prior_enrollment_course_add_button, id: 'grade-distribution-enroll-add-class-btn')
  button(:prior_enrollment_table_toggle, id: 'grade-distribution-enrollments-show-btn')
  table(:prior_enrollment_table, id: 'grade-distribution-enroll-table')

  def select_prior_enrollment_term(term)
    logger.info "Selecting prior enrollment '#{term.name}'"
    wait_for_element_and_select(prior_enrollment_select_element, term.name)
    sleep Utils.click_wait
  end

  def expand_prior_enrollment_table
    if prior_enrollment_table_element.visible?
      logger.info 'Prior enrollment table is already visible'
    else
      logger.info 'Expanding prior enrollment data table'
      wait_for_update_and_click prior_enrollment_table_toggle_element
      prior_enrollment_table_element.when_visible 1
    end
  end

  def choose_prior_enrollment_course(course_code)
    logger.info "Entering course name '#{course_code}'"
    wait_for_update_and_click prior_enrollment_course_input_element
    50.times { hit_backspace }
    50.times { hit_delete }
    prior_enrollment_course_input_element.send_keys course_code
    hit_tab
    wait_for_update_and_click prior_enrollment_course_add_button_element
  end

  def no_prior_enrollments_msg(course, prior_course_code)
    span_element(xpath: "//span[contains(., 'No #{course.code} #{course.term.name} students were previously enrolled in #{prior_course_code}.')]")
  end

  def prior_enrollment_data_heading(course, prior_course_code)
    span_element(xpath: "//span[contains(., 'Students Who Have Taken #{prior_course_code} to Overall Class')]")
  end

  def expected_grade_pct(grade_count, ttl_count)
    logger.info "Grade count is #{grade_count}, Total count is #{ttl_count}"
    if ttl_count.zero?
      result = 0
    else
      result = (grade_count.to_f / ttl_count.to_f).round(3) * 100
      result = (sprintf '%.1f', result).to_f
      result = (result.floor == result) ? result.floor : result
    end
    result = "#{result}%"
    logger.info "Result is #{result}"
    result
  end

  def visible_prior_enroll_grade_data(grade)
    sleep Utils.click_wait
    logger.info "Checking grade '#{grade}'"
    xpath = "//td[text()='#{grade}']"
    cell_element(xpath: xpath).when_visible Utils.short_wait
    ttl_pct_el = cell_element(xpath: "#{xpath}/following-sibling::td[1]")
    ttl_count_el = cell_element(xpath: "#{xpath}/following-sibling::td[2]")
    sub_pct_el = cell_element(xpath: "#{xpath}/following-sibling::td[3]")
    sub_count_el = cell_element(xpath: "#{xpath}/following-sibling::td[4]")
    data = {
      grade: grade,
      ttl_pct: (ttl_pct_el.text if ttl_pct_el.exists?).to_s,
      ttl_ct: (ttl_count_el.text if ttl_count_el.exists?).to_s,
      sub_pct: (sub_pct_el.text if sub_pct_el.exists?).to_s,
      sub_ct: (sub_count_el.text if sub_count_el.exists?).to_s
    }
    logger.debug "Visible data: #{data}"
    data
  end
end
