require_relative '../../util/spec_helper'

module BOACStudentPageAppointment

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACStudentPageTimeline

  ### EXISTING APPOINTMENTS ###

  button(:appts_button, id: 'timeline-tab-appointment')
  button(:show_hide_appts_button, id: 'timeline-tab-appointment-previous-messages')
  button(:toggle_all_appts_button, id: 'toggle-expand-all-appointments')
  span(:appts_expanded_msg, xpath: '//span[text()="Collapse all appointments"]')
  span(:appts_collapsed_msg, xpath: '//span[text()="Expand all appointments"]')
  elements(:appt_msg_row, :div, xpath: '//div[contains(@id,"timeline-tab-appointment-message")]')
  elements(:topic, :list_item, xpath: '//li[contains(@id, "topic")]')

  # Clicks the Appointments tab and expands the list of appointments
  def show_appts
    logger.info 'Checking appointments tab'
    wait_for_update_and_click appts_button_element
    wait_for_update_and_click show_hide_appts_button_element if show_hide_appts_button? && show_hide_appts_button_element.text.include?('Show')
  end

  # Expands all appointment messages
  def expand_all_appts
    logger.info 'Expanding all appointments'
    wait_for_update_and_click toggle_all_appts_button_element
    appts_expanded_msg_element.when_visible 2
  end

  # Collapses all appointment messages
  def collapse_all_appts
    logger.info 'Collapsing all appointments'
    wait_for_update_and_click toggle_all_appts_button_element
    appts_collapsed_msg_element.when_visible 2
  end

  # # Returns the expected sort order of a student's appointments
  # # @param appts [Array<Appointment>]
  # # @return [Array<String>]
  # def expected_appt_id_sort_order(appts)
  #   (appts.sort_by {|a| [a.updated_date, a.created_date, a.id] }).reverse.map &:id
  # end

  # Returns the visible sequence of appointment ids
  # @return [Array<String>]
  def visible_collapsed_appt_ids
    visible_collapsed_item_ids 'appointment'
  end

  # Returns the Check-in button on an expanded appointment
  # @param appt [Appointment]
  # @return [PageObject::Elements::Button]
  def check_in_button(appt)
    button_element(id: "appointment-#{appt.id}-check-in-dropdown__BV_button_")
  end

  # Clicks the Check-in button on an expanded appointment
  # @param appt [Appointment]
  def click_check_in_button(appt)
    wait_for_update_and_click check_in_button(appt)
  end

  # Clicks the Cancel button on an expanded appointment
  # @param appt [Appointment]
  def click_cancel_appt_button(appt)
    wait_for_update_and_click button_element(id: "appointment-#{appt.id}-cancel")
  end

  # Toggles the Check-in dropdown for a given appointment
  # @param appt [Appointment]
  def click_appt_dropdown_button(appt)
    logger.info "Clicking check-in dropdown for appt #{appt.id}"
    wait_for_update_and_click button_element(id: "appointment-#{appt.id}-check-in-dropdown__BV_toggle_")
  end

  # Returns the element containing the appointment advisor name
  # @param appt [Appointment]
  # @return [PageObject::Elements::Link]
  def appt_advisor_el(appt)
    link_element(id: "appointment-#{appt.id}-advisor-name")
  end

  # Search

  text_field(:timeline_appts_query_input, id: 'timeline-appointments-query-input')
  div(:timeline_appts_spinner, id: 'timeline-appointments-spinner')

  def search_within_timeline_appts(query)
    timeline_appts_query_input_element.when_visible Utils.short_wait
    timeline_appts_query_input_element.clear
    self.timeline_appts_query_input = query
    timeline_appts_query_input_element.send_keys :enter
    sleep 1
    timeline_appts_spinner_element.when_not_visible Utils.medium_wait rescue Selenium::WebDriver::Error::StaleElementReferenceError
  end

  def clear_timeline_appts_search
    search_within_timeline_appts ''
  end

  # Returns the data visible when an appointment is collapsed
  # @param appt [Appointment]
  # @return [Hash]
  def visible_collapsed_appt_data(appt)
    detail_el = span_element(id: "appointment-#{appt.id}-details-closed")
    status_el = div_element(xpath: "//div[starts-with(@id, 'collapsed-appointment-#{appt.id}-status-')]")
    date_el = div_element(id: "collapsed-appointment-#{appt.id}-created-at")
    {
        detail: (detail_el.text if detail_el.exists?),
        status: (status_el.text if status_el.exists?),
        created_date: (date_el.attribute('innerText').gsub('Last updated on', '').strip if date_el.exists?)
    }
  end

  # Returns the data visible when an appointment is expanded
  # @param appt [Appointment]
  # @return [Hash]
  def visible_expanded_appt_data(appt)
    details_el = span_element(id: "appointment-#{appt.id}-details")
    date_el = div_element(id: "expanded-appointment-#{appt.id}-created-at")
    check_in_time_el = span_element(id: "appointment-#{appt.id}-checked-in-at")
    cancel_reason_el = span_element(id: "appointment-#{appt.id}-cancel-reason")
    cancel_addl_info_el = span_element(id: "appointment-#{appt.id}-cancel-explained")
    advisor_role_el = span_element(id: "appointment-#{appt.id}-advisor-role")
    advisor_dept_els = span_elements(xpath: "//span[contains(@id, 'appointment-#{appt.id}-advisor-dept-')]")
    type_el = div_element(id: "appointment-#{appt.id}-type")
    topic_els = topic_elements.select { |el| el.attribute('id').include? "appointment-#{appt.id}-topic-" }
    {
        detail: (details_el.text if details_el.exists?),
        created_date: (date_el.attribute('innerText').strip if date_el.exists?),
        check_in_time: (check_in_time_el.text if check_in_time_el.exists?),
        cancel_reason: (cancel_reason_el.text if cancel_reason_el.exists?),
        cancel_addl_info: (cancel_addl_info_el.text if cancel_addl_info_el.exists?),
        advisor_name: (appt_advisor_el(appt).text if appt_advisor_el(appt).exists?),
        advisor_role: (advisor_role_el.text if advisor_role_el.exists?),
        advisor_depts: advisor_dept_els.map(&:text).sort,
        type: (type_el.text if type_el.exists?),
        topics: topic_els.map(&:text).sort,
    }
  end

end
