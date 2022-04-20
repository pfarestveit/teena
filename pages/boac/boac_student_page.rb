require_relative '../../util/spec_helper'

class BOACStudentPage

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACGroupAddSelectorPages
  include BOACGroupModalPages
  include BOACStudentPageAdvisingNote
  include BOACStudentPageAppointment

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

  button(:toggle_personal_details, :id => 'show-hide-personal-details')
  div(:preferred_name, :xpath => '//div[@id="student-preferred-name"]/span[2]')
  span(:sid, id: 'student-bio-sid')
  span(:inactive, id: 'student-bio-inactive')
  span(:academic_standing, xpath: '//h2[text()="Profile"]/following-sibling::div[@class="student-academic-standing"]/span[contains(@id, "academic-standing-term-")]')
  span(:phone, id: 'student-phone-number')
  link(:email, id: 'student-mailto')
  div(:cumulative_units, xpath: '//div[@id="cumulative-units"]/div')
  div(:cumulative_gpa, id: 'cumulative-gpa')
  div(:inactive_asc_flag, id: 'student-bio-inactive-asc')
  div(:inactive_coe_flag, id: 'student-bio-inactive-coe')
  elements(:major, :div, xpath: '//div[@id="student-bio-majors"]//div[@class="font-weight-bolder"]')
  elements(:sub_plan, :div, xpath: '//div[@id="student-bio-subplans"]/div')
  elements(:minor, :div, xpath: '//div[@id="student-bio-minors"]//div[@class="font-weight-bolder"]')
  elements(:college, :div, xpath: '//div[@id="student-bio-majors"]//div[@class="text-muted"]')
  elements(:discontinued_major, :div, xpath: '//div[@id="student-details-discontinued-majors"]//div[@class="font-weight-bolder"]')
  elements(:discontinued_college, :div, xpath: '//div[@id="student-details-discontinued-majors"]//div[@class="text-muted"]')
  elements(:discontinued_minor, :div, xpath: '//div[@id="student-details-discontinued-minors"]//div[@class="font-weight-bolder"]')
  div(:level, xpath: '//div[@id="student-bio-level"]/div')
  div(:transfer, id: 'student-profile-transfer')
  div(:terms_in_attendance, id: 'student-bio-terms-in-attendance')
  div(:entered_term, id: 'student-bio-matriculation')
  div(:visa, id: 'student-profile-visa')
  elements(:advisor_plan, :div, xpath: '//div[@id="student-profile-advisors"]//div[contains(@id,"-plan")]')
  elements(:advisor_name, :div, xpath: '//div[@id="student-profile-advisors"]//div[contains(@id,"-name")]')
  elements(:advisor_email, :div, xpath: '//div[@id="student-profile-advisors"]//div[contains(@id,"-email")]')
  elements(:intended_major, :div, xpath: '//div[@id="student-details-intended-majors"]/div')
  div(:expected_graduation, id: 'student-bio-expected-graduation')
  div(:alternate_email, id: 'student-profile-other-email')
  div(:additional_information_outer, xpath: '//h3[text()=" Advisor(s) "]')

  # Expand personal details tab on student page profile
  def expand_personal_details
    if personal_details_expanded?
      logger.debug "Personal details tab is already expanded"
    else
      logger.debug "Expanding personal details tab"
      wait_for_update_and_click toggle_personal_details_element
      wait_for_element(additional_information_outer_element, Utils.medium_wait)
    end
  end

  def personal_details_expanded?
    additional_information_outer_element.visible?
  end

  # Returns a user's SIS data visible on the student page
  # @return [Hash]
  def visible_sis_data
    {
      :name => (student_name_heading if student_name_heading?),
      :preferred_name => (preferred_name if preferred_name?),
      :email => (email_element.text.split[3] if email?),
      :email_alternate => (alternate_email.strip if alternate_email?),
      :phone => (phone if phone?),
      :cumulative_units => (cumulative_units.gsub("UNITS COMPLETED\n", '').gsub("\nNo data", '') if cumulative_units?),
      :cumulative_gpa => (cumulative_gpa.gsub("CUMULATIVE GPA\n", '').gsub("\nNo data", '').strip if cumulative_gpa?),
      :majors => (major_elements.map { |m| m.text.gsub('Major', '').strip }),
      :colleges => (college_elements.map { |c| c.text.strip }).reject(&:empty?),
      :majors_discontinued => (discontinued_major_elements.map { |m| m.text.gsub('Major', '').strip }),
      :colleges_discontinued => (discontinued_college_elements.map { |c| c.text.strip }).reject(&:empty?),
      :sub_plans => (sub_plan_elements.map { |m| m.text.strip }),
      :minors => (minor_elements.map { |m| m.text.strip }),
      :minors_discontinued => (discontinued_minor_elements.map { |m| m.text.strip }),
      :level => (level.gsub("Level\n", '') if level?),
      :transfer => (transfer.strip if transfer?),
      :terms_in_attendance => (terms_in_attendance if terms_in_attendance?),
      :visa => (visa.strip if visa?),
      :entered_term => (entered_term.gsub('Entered', '').strip if entered_term?),
      :intended_majors => (intended_major_elements.map { |m| m.text.strip }),
      :expected_graduation => (expected_graduation.gsub('Expected graduation', '').strip if expected_graduation?),
      :advisor_plans => (advisor_plan_elements.map &:text),
      :advisor_names => (advisor_name_elements.map &:text),
      :advisor_emails => (advisor_email_elements.map &:text),
      :inactive => (inactive_element.exists? && inactive_element.text.strip == 'INACTIVE'),
      :academic_standing => (academic_standing.strip if academic_standing?)
    }
  end

  def visible_degree(field)
    xpath = "//h3[contains(text(), \"Degree\")]/following-sibling::div[contains(., \"#{field}\")]"
    deg_type_el = div_element(xpath: "#{xpath}/div[1]")
    deg_date_el = div_element(xpath: "#{xpath}/div[2]")
    deg_college_el = div_element(xpath: "#{xpath}/div[3]")
    logger.debug "Degree college XPath is '#{xpath}/div[3]'"
    {
      deg_type: (deg_type_el.text.strip if deg_type_el.exists?),
      deg_date: (deg_date_el.text if deg_date_el.exists?),
      deg_college: (deg_college_el.text if deg_college_el.exists?)
    }
  end

  def visible_degree_minor(field)
    xpath = "//h3[contains(text(), \"Minor\")]/following-sibling::"
    min_type_el = div_element(xpath: "#{xpath}div[contains(., \"#{field}\")]/div")
    min_date_el = span_element(xpath: "#{xpath}span")
    {
      min_type: (min_type_el.text.strip if min_type_el.exists?),
      min_date: (min_date_el.text if min_date_el.exists?)
    }
  end

  def perceptive_link
    link_element(text: 'Perceptive Content (Image Now) documents ')
  end

  # Returns the link to the student overview page in CalCentral
  # @param student [BOACUser]
  # @return [Element]
  def calcentral_link(student)
    link_element(xpath: "//a[@href='https://calcentral.berkeley.edu/user/overview/#{student.uid}']")
  end

  # TEAMS

  elements(:squad, :div, id: 'student-bio-athletics')

  # Returns the visible team information
  # @return [Array<String>]
  def sports
    squad_elements.map { |el| el.text.strip }
  end

  # TIMELINE

  div(:timeline_loaded_msg, xpath: '//div[text()="Academic Timeline has loaded"]')
  button(:timeline_all_button, id: 'timeline-tab-all')
  button(:show_hide_all_button, id: 'timeline-tab-all-previous-messages')

  def wait_for_timeline
    timeline_all_button_element.when_visible Utils.short_wait
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
      :reqt_writing => (writing_reqt if writing_reqt_element.exists?),
      :reqt_history => (history_reqt if history_reqt_element.exists?),
      :reqt_institutions => (institutions_reqt if institutions_reqt_element.exists?),
      :reqt_cultures => (cultures_reqt if cultures_reqt_element.exists?)
    }
  end

  # Holds

  button(:holds_button, id: 'timeline-tab-hold')
  button(:show_hide_holds_button, id: 'timeline-tab-hold-previous-messages')
  elements(:hold, :div, xpath: '//div[contains(@id,"timeline-tab-hold-message")]/span[1]')

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
  elements(:alert, :row, xpath: '//tr[contains(@id, "permalink-alert-")]')
  elements(:alert_text, :span, xpath: '//div[contains(@id,"timeline-tab-alert-message")]/span[1]')
  elements(:alert_date, :row, xpath: '//tr[contains(@id, "permalink-alert-")]//div[contains(@id, "collapsed-alert-")][contains(@id, "-created-at")]')

  # Returns an array of visible alert messages
  # @return [Array<String>]
  def visible_alerts
    logger.info 'Checking alerts tab'
    wait_for_update_and_click alerts_button_element if alerts_button? && !alerts_button_element.disabled?
    wait_for_update_and_click show_hide_alerts_button_element if show_hide_alerts_button? && show_hide_alerts_button_element.text.include?('Show')
    alert_elements.each_with_index.map do |_, i|
      { text: alert_text_elements[i].text.strip, date: alert_date_elements[i].text.gsub('Last updated on', '').strip }
    end
  end

  # Notes - see BOACAdvisingNoteSection

  # COURSES

  link(:degree_checks_link, id: 'view-degree-checks-link')
  span(:withdrawal_msg, xpath: '//span[contains(@id, "withdrawal-term-")]')
  button(:toggle_collapse_all_years, id: 'toggle-collapse-all-years')

  def click_degree_checks_button
    logger.info 'Clicking the degree checks link'
    wait_for_update_and_click degree_checks_link_element
    wait_until(2) { @driver.window_handles.length > 1 }
    @driver.close
    @driver.switch_to.window @driver.window_handles.first
  end

  def term_data_xpath(term_name)
    "//h3[text()='#{term_name}']"
  end

  def term_data_heading(term_name)
    h3_element(xpath: term_data_xpath(term_name))
  end

  def click_expand_collapse_years_toggle
    wait_for_update_and_click toggle_collapse_all_years_element
  end

  def expand_academic_year(term_name)
    if term_data_heading(term_name).visible?
      logger.info "Row containing #{term_name} is already expanded"
    else
      logger.info "Expanding row containing #{term_name}"
      year = term_name.split.last
      year = term_name.split.last.to_i + 1 if term_name.include? 'Fall'
      wait_for_update_and_click button_element(id: "academic-year-#{year}-toggle")
    end
  end

  def visible_term_data(term_id)
    term_units_el = div_element(id: "term-#{term_id}-units")
    term_units_el.when_visible 1
    term_gpa_el = div_element(id: "term-#{term_id}-gpa")
    term_units_min_el = div_element(id: "term-#{term_id}-min-units")
    term_units_max_el = div_element(id: "term-#{term_id}-max-units")
    term_academic_standing_el = span_element(id: "academic-standing-term-#{term_id}")
    {
      term_units: (term_units_el.text.split.last if term_units_el.exists?),
      term_gpa: (term_gpa_el.text.split.last if term_gpa_el.exists?),
      term_units_min: (term_units_min_el.text.split.last if term_units_min_el.exists?),
      term_units_max: (term_units_max_el.text.split.last if term_units_max_el.exists?),
      academic_standing: (term_academic_standing_el.text.strip if term_academic_standing_el.exists?)
    }
  end

  def visible_collapsed_course_data(term_id, i)
    code_el = span_element(id: "term-#{term_id}-course-#{i}-name")
    wait_list_el = div_element(xpath: "//button[@id='term-#{term_id}-course-#{i}-toggle']/following-sibling::div[contains(@id, 'waitlisted-for')]")
    mid_point_grade_el = span_element(id: "term-#{term_id}-course-#{i}-midterm-grade")
    final_grade_el = span_element(id: "term-#{term_id}-course-#{i}-final-grade")
    units_el = span_element(id: "term-#{term_id}-course-#{i}-units")
    {
      code: (code_el.text if code_el.exists?),
      wait_list: (wait_list_el.text.strip if wait_list_el.exists?),
      mid_point_grade: (mid_point_grade_el.text.gsub('No data', '') if mid_point_grade_el.exists?),
      final_grade: (final_grade_el.text if final_grade_el.exists?),
      units: (units_el.text if units_el.exists?)
    }
  end

  def course_expand_toggle(term_id, i)
    button_element(:xpath => "//button[@id='term-#{term_id}-course-#{i}-toggle']")
  end

  def expand_course_data(term_id, i)
    wait_for_update_and_click course_expand_toggle(term_id, i)
  end

  def expand_course_data_by_ccn(term_id, ccn)
    btn = button_element(xpath: "//a[@id='term-#{term_id}-section-#{ccn}']/ancestor::div[@class='student-course']")
    wait_for_update_and_click btn
  end

  def visible_expanded_course_data(term_id, i)
    title_el = div_element(id: "term-#{term_id}-course-#{i}-title")
    title_el.when_visible 1
    code_el = div_element(id: "term-#{term_id}-course-#{i}-details-name")
    section_els = span_elements(xpath: "//div[@id='term-#{term_id}-course-#{i}-details']/div[@class='student-course-sections']/span")
    {
      code: (code_el.text if code_el.exists?),
      sections: (section_els.map { |el| el.text.split("\n").last.gsub(' |', '') } if section_els.any?),
      title: (title_el.text if title_el.exists?)
    }
  end

  elements(:class_page_link, :link, xpath: '//a[contains(@href, "/course/")]')

  def class_page_link(term_code, ccn)
    link_element(id: "term-#{term_code}-section-#{ccn}")
  end

  def click_class_page_link(term_code, ccn)
    logger.info "Clicking link for term #{term_code} section #{ccn}"
    xpath = "//a[contains(@href, '/course/#{term_code}/#{ccn}')]/ancestor::div[@class='student-course']/div[1]"
    i = div_element(xpath: xpath).attribute('id').split('-').last
    expand_course_data(term_code, i)
    start = Time.now
    wait_for_load_and_click class_page_link(term_code, ccn)
    wait_for_spinner
    div_element(:class => 'course-column-schedule').when_visible Utils.short_wait
    logger.warn "Took #{Time.now - start} seconds for the term #{term_code} section #{ccn} page to load"
  end

  def visible_dropped_section_data(term_id, course_code, component, number)
    drop_el = div_element(:xpath => "//div[contains(@id, 'term-#{term_id}-dropped-course')][contains(.,\"#{course_code} - #{component} #{number}\")]")
    drop_el.text if drop_el.exists?
  end

  # COURSE SITES

  def course_site_xpath(term_id, ccn, index)
    "//a[@id='term-#{term_id}-section-#{ccn}']/ancestor::div[contains(@class, 'student-course-expanded')]//div[@class='student-bcourses-wrapper'][#{index + 1}]"
  end

  def unmatched_site_xpath(term_name, site_code)
    "#{term_data_xpath term_name}//h4[text()=\"#{site_code}\"]/ancestor::div[@class='student-course']//div[@class='student-bcourses-wrapper']"
  end

  def site_analytics_percentile_xpath(site_xpath, label)
    "#{site_xpath}//th[contains(text(),'#{label}')]/following-sibling::td[1]"
  end

  def site_analytics_score_xpath(site_xpath, label)
    "#{site_xpath}//th[contains(text(),'#{label}')]/following-sibling::td[2]"
  end

  def site_boxplot_xpath(site_xpath, label)
    "#{site_analytics_score_xpath(site_xpath, label)}#{boxplot_xpath}"
  end

  def analytics_trigger_element(site_xpath, label)
    div_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}#{boxplot_trigger_xpath}")
  end

  def no_data?(site_xpath, label)
    cell_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}[contains(.,'No Data')]").exists?
  end

  def perc_round(site_xpath, label)
    logger.debug "Hitting XPath: #{site_analytics_percentile_xpath(site_xpath, label)}"
    cell_element(:xpath => "#{site_analytics_percentile_xpath(site_xpath, label)}//strong").text
  end

  def graphable_user_score(site_xpath, label)
    el = div_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}//div[@class='student-chart-tooltip-header']/div[2]")
    el.text if el.exists?
  end

  def non_graphable_user_score(site_xpath, label)
    el = cell_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}/strong")
    el.text if el.exists?
  end

  def non_graphable_maximum(site_xpath, label)
    el = cell_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}/span/span")
    el.text if el.exists?
  end

  def visible_analytics(driver, site_xpath, label, api_analytics)
    # If a boxplot should be present, hover over it to reveal the tooltip detail
    if api_analytics[:graphable]
      wait_until(Utils.short_wait) { analytics_trigger_element(site_xpath, label) }
      mouseover(analytics_trigger_element(site_xpath, label))
      logger.debug "Looking for tooltip header at '#{site_analytics_score_xpath(site_xpath, label)}//div[@class='student-chart-tooltip-header']'"
      div_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}//div[@class='student-chart-tooltip-header']").when_present Utils.short_wait
    end
    tool_tip_detail_elements = div_elements(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}//div[@class='student-chart-tooltip-value']")
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

  def visible_assignment_analytics(driver, site_xpath, api_analytics)
    visible_analytics(driver, site_xpath, 'Assignments Submitted', api_analytics)
  end

  def visible_grades_analytics(driver, site_xpath, api_analytics)
    visible_analytics(driver, site_xpath, 'Assignment Grades', api_analytics)
  end

  def visible_last_activity(term_id, ccn, index)
    xpath = "#{course_site_xpath(term_id, ccn, index)}//th[contains(.,\"Last bCourses Activity\")]/following-sibling::td/div"
    logger.debug "Checking for last activity at '#{xpath}'"
    div_element(:xpath => xpath).when_visible(Utils.click_wait)
    text = div_element(:xpath => xpath).text.strip
    {
      :days => text.split('.')[0],
      :context => text.split('.')[1]
    }
  end

end
