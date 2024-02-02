class RipleyGradeDistributionPage

  include Logging
  include PageObject
  include Page
  include RipleyPages

  h1(:page_heading, xpath: '//h1[contains(., "Grade Distribution")]')
  div(:sorry_not_auth_msg, xpath: '//div[text()="Sorry, you are not authorized to use this tool."]')
  div(:no_grade_dist_msg, xpath: '//div[text()="This course does not meet the requirements necessary to generate a Grade Distribution."]')
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
  button(:demographics_table_toggle, id: 'grade-distribution-demographics-show-btn')
  table(:demographics_table, id: 'grade-distribution-demo-table')
  elements(:demographics_table_row, :row, xpath: '//tr[contains(@id, "grade-distribution-demo-table-row")]')

  def select_demographic(demographic)
    logger.info "Selecting demographic '#{demographic}'"
    wait_for_element_and_select(demographics_select_element, demographic)
    sleep 2
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
    count = enrollments.length
    config = RipleyUtils.newt_small_cell_suppression
    (count >= 1 && count < config) ? 'Small sample size' : count.to_s
  end

  def expected_avg_grade_points(enrollments)
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
    avg = (grades.inject { |ttl, g| ttl + g }.to_f / grades.length).round(1)
    avg = (sprintf '%.1f', avg).to_f
    ((avg.floor == avg) ? avg.floor : avg).to_s
  end

  def visible_demographics_term_data(term)
    sleep 1
    xpath = "//tr[contains(@id, 'grade-distribution-demo-table-row')][contains(., '#{term.name}')]"
    row_element(xpath: xpath).when_visible 10 rescue TimeoutError
    ttl_avg_el = cell_element(xpath: "#{xpath}/td[2]")
    ttl_count_el = cell_element(xpath: "#{xpath}/td[3]")
    sub_avg_el = cell_element(xpath: "#{xpath}/td[4]")
    sub_count_el = cell_element(xpath: "#{xpath}/td[5]")
    data = {
      term: term.name,
      ttl_avg: (ttl_avg_el.text if ttl_avg_el.exists?).to_s,
      ttl_ct: (ttl_count_el.text if ttl_count_el.exists?).to_s,
      sub_avg: (sub_avg_el.text if sub_avg_el.exists?).to_s,
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
    sleep 2
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
    wait_for_textbox_and_type(prior_enrollment_course_input_element, course_code)
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
      result = (grade_count.to_f/ttl_count.to_f).round(3) * 100
      result = (sprintf '%.1f', result).to_f
      result = (result.floor == result) ? result.floor : result
    end
    result = "#{result}%"
    logger.info "Result is #{result}"
    result
  end

  def visible_prior_enroll_grade_data(grade)
    sleep 1
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
