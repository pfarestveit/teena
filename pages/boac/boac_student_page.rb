require_relative '../../util/spec_helper'

class BOACStudentPage

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACAddGroupSelectorPages
  include BOACGroupModalPages
  include BOACStudentPageAdvisingNote

  # Loads a student page directly
  # @param user [User]
  def load_page(user)
    logger.info "Loading student page for UID #{user.uid}"
    navigate_to "#{BOACUtils.base_url}#{path_to_student_view(user.uid)}"
    wait_for_title "#{user.full_name}"
    wait_for_spinner
  end

  # SIS PROFILE DATA

  h1(:not_found_msg, xpath: '//h1[text()="Not Found"]')

  div(:preferred_name, :id => 'student-preferred-name')
  span(:sid, id: 'student-bio-sid')
  span(:phone, id: 'student-phone-number')
  link(:email, id: 'student-mailto')
  div(:cumulative_units, xpath: '//div[@id="cumulative-units"]/div')
  div(:cumulative_gpa, id: 'cumulative-gpa')
  div(:inactive_flag, id: 'student-bio-inactive')
  elements(:major, :div, xpath: '//div[@id="student-bio-majors"]//div[@class="font-weight-bolder"]')
  elements(:college, :div, xpath: '//div[@id="student-bio-majors"]//div[@class="text-muted"]')
  div(:level, xpath: '//div[@id="student-bio-level"]/div')
  div(:terms_in_attendance, id: 'student-bio-terms-in-attendance')
  div(:expected_graduation, id: 'student-bio-expected-graduation')

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
      :majors => (major_elements.map { |m| m.text.gsub('Major', '').strip }),
      :colleges => (college_elements.map { |c| c.text.strip }).reject(&:empty?),
      :level => (level.gsub("Level\n",'') if level?),
      :terms_in_attendance => (terms_in_attendance if terms_in_attendance?),
      :expected_graduation => (expected_graduation.gsub('Expected graduation','').strip if expected_graduation?)
    }
  end

  # Returns the link to the student overview page in CalCentral
  # @param student [BOACUser]
  # @return [PageObject::Elements::Link]
  def calcentral_link(student)
    link_element(xpath: "//a[@href='https://calcentral.berkeley.edu/user/overview/#{student.uid}']")
  end

  # TIMELINE

  div(:timeline_loaded_msg, xpath: '//div[text()="Academic Timeline has loaded"]')
  button(:show_hide_all_button, id: 'timeline-tab-all-previous-messages')

  def wait_for_timeline
    timeline_loaded_msg_element.when_present Utils.short_wait
  end

  # Requirements

  button(:reqts_button, id: 'timeline-tab-requirement')
  button(:show_hide_reqts_button, id: 'timeline-tab-requirement-previous-messages')
  div(:writing_reqt, xpath: '//span[contains(text(),"Entry Level Writing")]')
  div(:history_reqt, xpath: '//span[contains(text(),"American History")]')
  div(:institutions_reqt, xpath: '//span[contains(text(),"American Institutions")]')
  div(:cultures_reqt, xpath: '//span[contains(text(),"American Cultures")]')

  # Returns requirements statuses
  # @return [Hash]
  def visible_requirements
    logger.info 'Checking requirements tab'
    wait_for_update_and_click reqts_button_element if reqts_button? && !reqts_button_element.disabled?
    wait_for_update_and_click show_hide_reqts_button_element if show_hide_reqts_button? && show_hide_reqts_button_element.text.include?('Show')
    {
      :reqt_writing => (writing_reqt.gsub('Entry Level Writing', '').strip if writing_reqt_element.exists?),
      :reqt_history => (history_reqt.gsub('American History', '').strip if history_reqt_element.exists?),
      :reqt_institutions => (institutions_reqt.gsub('American Institutions', '').strip if institutions_reqt_element.exists?),
      :reqt_cultures => (cultures_reqt.gsub('American Cultures', '').strip if cultures_reqt_element.exists?)
    }
  end

  # Holds

  button(:holds_button, id: 'timeline-tab-hold')
  button(:show_hide_holds_button, id: 'timeline-tab-hold-previous-messages')
  elements(:hold, :div, xpath: '//div[contains(@id,"timeline-tab-hold-message")]/span[2]')

  # Returns an array of visible hold messages with all whitespace removed
  # @return [Array<String>]
  def visible_holds
    logger.info 'Checking holds tab'
    wait_for_update_and_click holds_button_element if holds_button? && !holds_button_element.disabled?
    wait_for_update_and_click show_hide_holds_button_element if show_hide_holds_button? && show_hide_holds_button_element.text.include?('Show')
    hold_elements.map { |h| h.text.gsub(/\W+/, '') }
  end

  # Alerts

  button(:alerts_button, id: 'timeline-tab-alert')
  button(:show_hide_alerts_button, id: 'timeline-tab-alert-previous-messages')
  elements(:alert, :div, xpath: '//div[contains(@id,"timeline-tab-alert-message")]/span[2]')

  # Returns an array of visible alert messages
  # @return [Array<String>]
  def visible_alerts
    logger.info 'Checking alerts tab'
    wait_for_update_and_click alerts_button_element if alerts_button? && !alerts_button_element.disabled?
    wait_for_update_and_click show_hide_alerts_button_element if show_hide_alerts_button? && show_hide_alerts_button_element.text.include?('Show')
    alert_elements.map { |a| a.text.strip }
  end

  # Notes - see BOACAdvisingNoteSection

  # COURSES

  span(:withdrawal_msg, class: 'red-flag-small')
  button(:view_more_button, :xpath => '//button[contains(.,"Show Previous Semesters")]')

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
    "//h3[text()=\"#{term_name}\"]"
  end

  # Returns the total term units and min/max override units shown for a given term
  # @param term_id [Integer]
  # @param term_name [String]
  # @return [Hash]
  def visible_term_data(term_id, term_name)
    term_units_el = span_element(xpath: "#{term_data_xpath term_name}/following-sibling::div[@class=\"student-course-heading student-course\"]//div[@class=\"student-course-heading-units-total\"]/span")
    term_units_min_el = span_element(id: "term-#{term_id}-min-units")
    term_units_max_el = span_element(id: "term-#{term_id}-max-units")
    {
      :term_units => (term_units_el.text.split[1] if term_units_el.exists?),
      :term_units_min => (term_units_min_el.text if term_units_min_el.exists?),
      :term_units_max => (term_units_max_el.text if term_units_max_el.exists?)
    }
  end

  # Returns the XPath to the SIS data shown for a given course in a term
  # @param term_name [String]
  # @param course_code [String]
  # @return [String]
  def course_data_xpath(term_name, course_code)
    "#{term_data_xpath term_name}/following-sibling::div[contains(., \"#{course_code}\")]"
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
    div_element(:class => 'course-column-schedule').when_visible Utils.short_wait
    logger.warn "Took #{Time.now - start} seconds for the term #{term_code} section #{ccn} page to load"
  end

  # Returns the SIS data shown for a course with a given course code
  # @param uid [Integer]
  # @param term_id [Integer]
  # @param term_name [String]
  # @param course_code [String]
  # @return [Hash]
  def visible_course_sis_data(uid, term_id, ccn, term_name, course_code)
    course_xpath = course_data_xpath(term_name, course_code)
    title_xpath = "#{course_xpath}//div[@class='student-course-name']"
    units_xpath = "#{course_xpath}//div[@class='student-course-heading-units']"
    grading_basis_xpath = "#{course_xpath}//div[contains(text(),'Final:')]/span"
    mid_point_grade_xpath = "#{course_xpath}//div[contains(text(),'Mid:')]/span"
    grade_xpath = "#{course_xpath}//div[contains(text(),'Final:')]/span"
    {
      :title => (h4_element(:xpath => title_xpath).text if h4_element(:xpath => title_xpath).exists?),
      :units_completed => (div_element(:xpath => units_xpath).text.delete('Units').strip if div_element(:xpath => units_xpath).exists?),
      :grading_basis => (span_element(:xpath => grading_basis_xpath).text if span_element(:xpath => grading_basis_xpath).exists?),
      :mid_point_grade => (span_element(:xpath => mid_point_grade_xpath).text.gsub("\n", '') if span_element(:xpath => mid_point_grade_xpath).exists?),
      :grade => (span_element(:xpath => grade_xpath).text if span_element(:xpath => grade_xpath).exists?),
      :wait_list => (span_element(:id => "student-#{uid}-waitlisted-for-#{term_id}-#{ccn}").exists?)
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
      logger.debug "Looking for tooltip header at '#{site_analytics_score_xpath(site_xpath, label)}//div[@class='student-chart-tooltip-header']'"
      div_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}//div[@class='student-chart-tooltip-header']").when_present Utils.short_wait
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
