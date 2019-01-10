require_relative '../../util/spec_helper'

class BOACStudentPage

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACAddCuratedModalPages

  # Loads a student page directly
  # @param user [User]
  def load_page(user)
    logger.info "Loading student page for UID #{user.uid}"
    navigate_to "#{BOACUtils.base_url}/student/#{user.uid}"
    wait_for_title "#{user.full_name}"
    wait_for_spinner
  end

  # SIS PROFILE DATA

  h1(:not_found_msg, xpath: '//h1[text()="Not Found"]')

  div(:preferred_name, :id => 'student-preferred-name')
  span(:sid, id: 'student-bio-sid')
  span(:phone, id: 'student-phone-number')
  link(:email, id: 'student-mailto')
  div(:cumulative_units, id: 'student-status-units-completed')
  div(:cumulative_gpa, id: 'student-status-cumulative-gpa')
  div(:inactive_flag, xpath: '//div[text()="INACTIVE"]')
  elements(:major, :div, xpath: '//div[@id="student-bio-majors"]//div[@class="student-bio-header"]')
  elements(:college, :div, xpath: '//div[@id="student-bio-majors"]//div[@class="student-bio-details"]')
  div(:level, id: 'student-bio-level')
  span(:terms_in_attendance, id: 'student-bio-terms-in-attendance')
  span(:expected_graduation, id: 'student-bio-expected-graduation')

  cell(:writing_reqt, xpath: '//td[text()="Entry Level Writing"]/following-sibling::td')
  cell(:history_reqt, xpath: '//td[text()="American History"]/following-sibling::td')
  cell(:institutions_reqt, xpath: '//td[text()="American Institutions"]/following-sibling::td')
  cell(:cultures_reqt, xpath: '//td[text()="American Cultures"]/following-sibling::td')

  # Returns a user's SIS data visible on the student page
  # @return [Hash]
  def visible_sis_data
    {
      :name => (student_name_heading if student_name_heading?),
      :preferred_name => (preferred_name if preferred_name?),
      :email => (email_element.text if email?),
      :phone => (phone if phone?),
      :cumulative_units => (cumulative_units.gsub("UNITS COMPLETED\n",'').gsub("\nNo data", '') if cumulative_units?),
      :cumulative_gpa => (cumulative_gpa.gsub("CUMULATIVE GPA\n",'').gsub("\nNo data", '').strip if cumulative_gpa?),
      :majors => (major_elements.map { |m| m.text.strip }),
      :colleges => (college_elements.map { |c| c.text.strip }).reject(&:empty?),
      :level => (level.gsub("Level\n",'') if level?),
      :terms_in_attendance => (terms_in_attendance if terms_in_attendance?),
      :expected_graduation => (expected_graduation.gsub('Expected graduation','').strip if expected_graduation?),
      :reqt_writing => (writing_reqt.strip if writing_reqt_element.exists?),
      :reqt_history => (history_reqt.strip if history_reqt_element.exists?),
      :reqt_institutions => (institutions_reqt.strip if institutions_reqt_element.exists?),
      :reqt_cultures => (cultures_reqt.strip if cultures_reqt_element.exists?)
    }
  end

  # ALERTS

  elements(:non_dismissed_alert_button, :button, xpath: '//button[contains(@id,"dismiss-alert")]')
  elements(:non_dismissed_alert_msg, :span, xpath: '//button[contains(@id,"dismiss-alert")]/preceding-sibling::span')
  elements(:dismissed_alert, :div, xpath: '//button[contains(text(),"Hide dismissed status alerts"]/following-sibling::div')
  elements(:dismissed_alert_msg, :span, xpath: '//button[contains(text(),"Hide dismissed status alerts"]/following-sibling::div//span')
  button(:view_dismissed_button, xpath: '//button[contains(.,"View dismissed status alerts")]')
  button(:hide_dismissed_button, xpath: '//button[contains(.,"Hide dismissed status alerts")]')
  span(:withdrawal_msg, class: 'red-flag-small')

  # Returns the IDs of non-dismissed alerts
  # @return [Array<String>]
  def non_dismissed_alert_ids
    non_dismissed_alert_button_elements.map { |a| a.attribute('id').split('-')[2] }
  end

  # Returns the message text of non-dismissed alerts
  # @return [Array<String>]
  def non_dismissed_alert_msgs
    non_dismissed_alert_msg_elements.map &:text
  end

  # Returns the message text of dismissed alerts
  # @return [Array<String>]
  def dismissed_alert_msgs
    click_view_dismissed_alerts
    msgs = dismissed_alert_msg_elements.map &:text
    click_hide_dismissed_alerts
    msgs
  end

  # Returns the IDs of dismissed alerts
  # @return [Array<String>]
  def dismissed_alert_ids
    dismissed_alert_elements.map { |a| a.attribute('id').split('-')[1] }
  end

  # Clicks the button to reveal dismissed alerts
  def click_view_dismissed_alerts
    logger.info "Clicking view dismissed alerts button"
    wait_for_load_and_click view_dismissed_button_element
  end

  # Clicks the button to hide dismissed alerts
  def click_hide_dismissed_alerts
    logger.info "Clicking hide dismissed alerts button"
    wait_for_load_and_click hide_dismissed_button_element
  end

  # Dismisses an alert
  # @param alert [Alert]
  def dismiss_alert(alert)
    logger.info "Dismissing alert ID #{alert.id}"
    wait_for_load_and_click non_dismissed_alert_button_elements.find { |el| el.attribute('id').include?(alert.id) }
  end

  # TODO - CURATED GROUPS

  button(:student_create_curated_group, id: 'curated-group-create-btn')
  elements(:student_curated_group_name, :link, xpath: '//div[@id="student-curated-groups-box"]//a')

  def curated_cbx(group)
    checkbox_element(xpath: "//div[@class=\"student-curated-group-checkbox\"][contains(.,\"#{group.name}\")]/input")
  end

  # Clicks the checkbox to add or remove a student from a curated group
  # @param group [CuratedGroup]
  def click_curated_cbx(group)
    wait_for_update_and_click curated_cbx(group)
  end

  # Adds a student to a curated group
  # @param student [User]
  # @param group [CuratedGroup]
  def add_student_to_curated(student, group)
    logger.info "Adding UID #{student.uid} to group '#{group.name}'"
    click_curated_cbx group
    group.members << student
    wait_for_sidebar_group_member_count group
  end

  # Removes a student from a curated group
  # @param student [User]
  # @param group [CuratedGroup]
  def remove_student_from_curated(student, group)
    logger.info "Removing UID #{student.uid} from group '#{group.name}'"
    click_curated_cbx group
    group.members.delete student
    wait_for_sidebar_group_member_count group
  end

  # Clicks the link to create a curated group
  def click_create_curated_link
    wait_for_update_and_click student_create_curated_group_element
  end

  # Creates a curated group using the create button on the student page
  # @param group [CuratedGroup]
  def create_student_curated(group)
    click_create_curated_link
    name_and_save_group group
    wait_for_sidebar_group group
  end

  # Returns all the curated groups shown on the student page
  # @return [Array<String>]
  def visible_curated_names
    student_curated_group_name_elements.map &:text
  end

  # Whether or not a curated group is selected on the student page
  # @param group [CuratedGroup]
  # @return [boolean]
  def curated_selected?(group)
    checkbox_element(xpath: "//div[contains(@class,\"curated-cohort-checkbox\")][contains(.,\"#{group.name}\")]//input[contains(@class,\"ng-not-empty\")]").exists?
  end

  # COURSES

  button(:view_more_button, :xpath => '//button[contains(.,"View Previous Semesters")]')

  # Clicks the button to expand previous semester data
  def click_view_previous_semesters
    logger.debug 'Expanding previous semesters'
    scroll_to_bottom
    wait_for_load_and_click view_more_button_element
  end

  # Returns the XPath to a semester's courses
  # @param [String] term_name
  # @return [String]
  def term_data_xpath(term_name)
    "//h3[text()=\"#{term_name}\"]/following-sibling::div"
  end

  # Returns the XPath to the SIS data shown for a given course in a term
  # @param term_name [String]
  # @param course_code [String]
  # @return [String]
  def course_data_xpath(term_name, course_code)
    "#{term_data_xpath term_name}//h4[text()=\"#{course_code}\"]/ancestor::div[@class=\"student-course\"]"
  end

  # Returns the link to a class page
  # @param term_code [String]
  # @param ccn [Integer]
  # @return [PageObject::Elements::Link]
  def class_page_link(term_code, ccn)
    link_element(id: "term-#{term_code}-section-#{ccn}")
  end

  # Clicks the class page link for a given section
  # @param term_code [String]
  # @param ccn [Integer]
  def click_class_page_link(term_code, ccn)
    logger.info "Clicking link for term #{term_code} section #{ccn}"
    start = Time.now
    wait_for_load_and_click class_page_link(term_code, ccn)
    wait_for_spinner
    div_element(class: 'course-column-schedule').when_visible Utils.short_wait
    logger.warn "Took #{Time.now - start} seconds for the term #{term_code} section #{ccn} page to load"
  end

  # Returns the SIS data shown for a course with a given course code
  # @param term_name [String]
  # @param course_code [String]
  # @return [Hash]
  def visible_course_sis_data(term_name, course_code)
    course_xpath = course_data_xpath(term_name, course_code)
    title_xpath = "#{course_xpath}//div[@class='student-course-name']"
    units_xpath = "#{course_xpath}//div[@class='student-course-heading-units']"
    grading_basis_xpath = "#{course_xpath}//span[@class='student-course-grading-basis']"
    mid_point_grade_xpath = "#{course_xpath}//div[contains(text(),'Mid:')]/span"
    grade_xpath = "#{course_xpath}//div[contains(text(),'Final:')]/span"
    wait_list_xpath = "#{course_xpath}//span[@data-ng-if='course.waitlisted']"
    {
      :title => (h4_element(:xpath => title_xpath).text if h4_element(:xpath => title_xpath).exists?),
      :units_completed => (div_element(:xpath => units_xpath).text.delete('Units').strip if div_element(:xpath => units_xpath).exists?),
      :grading_basis => (span_element(:xpath => grading_basis_xpath).text if span_element(:xpath => grading_basis_xpath).exists?),
      :mid_point_grade => (span_element(:xpath => mid_point_grade_xpath).text.gsub("\n", '') if span_element(:xpath => mid_point_grade_xpath).exists?),
      :grade => (span_element(:xpath => grade_xpath).text if span_element(:xpath => grade_xpath).exists?),
      :wait_list => (span_element(:xpath => wait_list_xpath).exists?)
    }
  end

  # Returns the SIS data shown for a given section in a course at a specific index
  # @param term_name [String]
  # @param course_code [String]
  # @param index [Integer]
  # @return [Hash]
  def visible_section_sis_data(term_name, course_code, index)
    section_xpath = "#{course_data_xpath(term_name, course_code)}//div[@class='student-course-sections']/span[#{index + 1}]"
    {
     :section => (span_element(:xpath => section_xpath).text.delete('(|)').strip if span_element(:xpath => section_xpath).exists?)
    }
  end

  # Returns the element containing a dropped section
  # @param term_name [String]
  # @param course_code [String]
  # @param component [String]
  # @param number [String]
  # @return [PageObject::Elements::Div]
  def visible_dropped_section_data(term_name, course_code, component, number)
    div_element(:xpath => "#{term_data_xpath term_name}//div[@class='student-course student-course-dropped'][contains(.,\"#{course_code} - #{component} #{number}\")]")
  end

  # COURSE SITES

  # Expands course data
  # @param term_name [String]
  # @param course_code [String]
  def expand_course_data(term_name, course_code)
    toggle = button_element(:xpath => "#{course_data_xpath(term_name, course_code)}//button")
    wait_for_update_and_click toggle
  end

  # Returns the XPath to a course site associated with a course in a term
  # @param term_name [String]
  # @param course_code [String]
  # @param index [Integer]
  # @return [String]
  def course_site_xpath(term_name, course_code, index)
    "#{course_data_xpath(term_name, course_code)}//div[@class='student-bcourses-wrapper'][#{index + 1}]"
  end

  # Returns the XPath to a course site in a term not matched to a SIS enrollment
  # @param term_name [String]
  # @param site_code [String]
  # @return [String]
  def unmatched_site_xpath(term_name, site_code)
    "#{term_data_xpath term_name}//h4[text()=\"#{site_code}\"]/ancestor::div[@class='student-course']//div[@class='student-bcourses-wrapper']"
  end

  # Returns the XPath to the user percentile analytics data for a given category, for example 'page views'
  # @param site_xpath [String]
  # @param label [String]
  # @return [String]
  def site_analytics_percentile_xpath(site_xpath, label)
    "#{site_xpath}//th[contains(text(),'#{label}')]/following-sibling::td[1]"
  end

  # Returns the XPath to the detailed score and percentile analytics data for a given category, for example 'page views'
  # @param site_xpath [String]
  # @param label [String]
  # @return [String]
  def site_analytics_score_xpath(site_xpath, label)
    "#{site_xpath}//th[contains(text(),'#{label}')]/following-sibling::td[2]"
  end

  # Returns the XPath to the boxplot graph for a particular set of analytics data for a given site, for example 'page views'
  # @param site_xpath [String]
  # @param label [String]
  # @return [String]
  def site_boxplot_xpath(site_xpath, label)
    "#{site_analytics_score_xpath(site_xpath, label)}#{boxplot_xpath}"
  end

  # Returns the element that triggers the analytics tooltip for a particular set of analytics data for a given site, for example 'page views'
  # @param driver [Selenium::WebDriver]
  # @param site_xpath [String]
  # @param label [String]
  # @return [Selenium::WebDriver::Element]
  def analytics_trigger_element(driver, site_xpath, label)
    driver.find_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}#{boxplot_trigger_xpath}")
  end

  # Checks the existence of a 'no data' message for a particular set of analytics for a given site, for example 'page views'
  # @param site_xpath [String]
  # @param label [String]
  # @return [boolean]
  def no_data?(site_xpath, label)
    cell_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}[contains(.,'No Data')]").exists?
  end

  # Returns the user's percentile displayed for a particular set of analytics data for a given site
  # @param site_xpath [String]
  # @param label [String]
  # @return [String]
  def perc_round(site_xpath, label)
    logger.debug "Hitting XPath: #{site_analytics_percentile_xpath(site_xpath, label)}"
    cell_element(:xpath => "#{site_analytics_percentile_xpath(site_xpath, label)}//strong").text
  end

  # When a boxplot is shown for a set of analytics, returns the user score shown on the tooltip
  # @param site_xpath [String]
  # @param label [String]
  # @return [String]
  def graphable_user_score(site_xpath, label)
    el = div_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}//div[@class='student-chart-tooltip-header']/div[2]")
    el.text if el.exists?
  end

  # When no boxplot is shown for a set of analytics, returns the user score shown
  # @param site_xpath [String]
  # @param label [String]
  # @return [String]
  def non_graphable_user_score(site_xpath, label)
    el = cell_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}/strong")
    el.text if el.exists?
  end

  # When no boxplot is shown for a set of analytics, returns the maximum score shown
  # @param site_xpath [String]
  # @param label [String]
  # @return [String]
  def non_graphable_maximum(site_xpath, label)
    el = cell_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}/span/span")
    el.text if el.exists?
  end

  # Returns all the analytics data shown for a given category, whether with boxplot or without
  # @param driver [Selenium::WebDriver]
  # @param site_xpath [String]
  # @param label [String]
  # @param api_analytics [Hash]
  # @return [Hash]
  def visible_analytics(driver, site_xpath, label, api_analytics)
    # If a boxplot should be present, hover over it to reveal the tooltip detail
    if api_analytics[:graphable]
      wait_until(Utils.short_wait) { analytics_trigger_element(driver, site_xpath, label) }
      mouseover(driver, analytics_trigger_element(driver, site_xpath, label))
      div_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}//div[@class='student-chart-tooltip-header']").when_visible Utils.short_wait
    end
    tool_tip_detail_elements = driver.find_elements(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}//div[@class='student-chart-tooltip-value']")
    tool_tip_detail = []
    tool_tip_detail = tool_tip_detail_elements.map &:text if tool_tip_detail_elements.any?
    {
      :perc_round => perc_round(site_xpath, label),
      :score => (api_analytics[:graphable] ? graphable_user_score(site_xpath, label) : non_graphable_user_score(site_xpath, label)),
      :max => (api_analytics[:graphable] ? tool_tip_detail[0] : non_graphable_maximum(site_xpath, label)),
      :perc_70 => tool_tip_detail[1],
      :perc_50 => tool_tip_detail[2],
      :perc_30 => tool_tip_detail[3],
      :minimum => tool_tip_detail[4]
    }
  end

  # Returns the assignments-submitted analytics data shown for a given site
  # @param driver [Selenium::WebDriver]
  # @param site_xpath [String]
  # @param api_analytics [Hash]
  # @return [Hash]
  def visible_assignment_analytics(driver, site_xpath, api_analytics)
    visible_analytics(driver, site_xpath, 'Assignments Submitted', api_analytics)
  end

  # Returns the assignments-grades analytics data shown for a given site
  # @param driver [Selenium::WebDriver]
  # @param site_xpath [String]
  # @param api_analytics [Hash]
  # @return [Hash]
  def visible_grades_analytics(driver, site_xpath, api_analytics)
    visible_analytics(driver, site_xpath, 'Assignment Grades', api_analytics)
  end

  # Returns the last activity data shown for a given site
  # @param term_name [String]
  # @param course_code [String]
  # @param index [Integer]
  # @return [String]
  def visible_last_activity(term_name, course_code, index)
    xpath = "#{course_site_xpath(term_name, course_code, index)}//th[contains(.,\"Last bCourses Activity\")]/following-sibling::td/div"
    div_element(:xpath => xpath).when_visible(Utils.click_wait)
    text = div_element(:xpath => xpath).text.strip
    {
      :days => text.split('.')[0],
      :context => text.split('.')[1]
    }
  end

end
