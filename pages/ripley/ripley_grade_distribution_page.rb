class RipleyGradeDistributionPage

  include Logging
  include PageObject
  include Page
  include RipleyPages

  h1(:page_heading, xpath: '//h1[contains(., "Grade Distribution")]')
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

  # HIGHCHARTS

  def chart_xpath(select_id)
    "//select[@id='#{select_id}']/following-sibling::div//*[name()='g'][@class='highcharts-series-group']"
  end

  def reveal_tooltip(trigger_el, tooltip_el)
    mouseover trigger_el
    tooltip_el.when_visible 2
    mouseover(trigger_el, -15) if tooltip_el.text.empty?
    mouseover(trigger_el, 15) if tooltip_el.text.empty?
    mouseover(trigger_el, nil, -30) if tooltip_el.text.empty?
    mouseover(trigger_el, nil, 30) if tooltip_el.text.empty?
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
    logger.info 'Expanding demographics data table'
    wait_for_update_and_click demographics_table_toggle_element
    demographics_table_element.when_visible 2
  end

  def visible_demographics_term_data(term)
    sleep 1
    xpath = "//tr[contains(@id, 'grade-distribution-demo-table-row')][contains(., '#{term.name}')]"
    row_element(xpath: xpath).when_visible Utils.short_wait
    avg_el = cell_element(xpath: "#{xpath}/td[2]")
    count_el = cell_element(xpath: "#{xpath}/td[3]")
    [avg_el, count_el].each { |el| logger.debug "Checking demographic data at #{el.locator}" }
    data = {
      term: term.name,
      avg: (avg_el.text if avg_el.exists?).to_s,
      count: (count_el.text if count_el.exists?).to_s
    }
    logger.debug "Visible data: #{data}"
    data
  end

  def demographics_grade_el(grade)
    div_element(xpath: "#{chart_xpath 'grade-distribution-demographics-select'}//*[name()='path'][starts-with(@aria-label, '#{grade},')]")
  end

  def mouseover_demographics_grade(grade)
    demographics_grade_el(grade).when_present Utils.short_wait
    reveal_tooltip(demographics_grade_el(grade), tooltip_key_element)
  end

  # Prior enrollments

  h2(:prior_enrollment_heading, xpath: '//h2[text()="Grade Distribution by Prior Enrollment"]')
  select_list(:prior_enrollment_select, id: 'grade-distribution-enrollment-select')
  button(:prior_enrollment_table_toggle, id: 'grade-distribution-enrollments-show-btn')
  table(:prior_enrollment_table, id: 'grade-distribution-enroll-table')

  def select_prior_enrollment(course_code)
    logger.info "Selecting prior enrollment '#{course_code}'"
    wait_for_element_and_select(prior_enrollment_select_element, course_code)
    sleep 2
  end

  def expand_prior_enrollment_table
    logger.info 'Expanding prior enrollment data table'
    wait_for_update_and_click prior_enrollment_table_toggle_element
    prior_enrollment_table_element.when_visible 1
  end

  def enrollment_grade_el(grade)
    div_element(xpath: "#{chart_xpath 'grade-distribution-enrollment-select'}//*[name()='path'][starts-with(@aria-label, '#{grade},')]")
  end

  def mouseover_enrollment_grade(grade)
    enrollment_grade_el(grade).when_present Utils.short_wait
    reveal_tooltip(enrollment_grade_el(grade), tooltip_key_element)
  end
end
