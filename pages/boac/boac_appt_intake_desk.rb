require_relative '../../util/spec_helper'

module BOACApptIntakeDesk

  include PageObject
  include Logging
  include Page
  include BOACPages

  # Waits for The Poller to update the drop-in appointment UI
  def wait_for_poller(&blk)
    start = Time.now
    wait_until(Utils.boac_poller_wait) { yield }
    logger.warn "Took #{Time.now - start} seconds for The Poller to update the appointment queue"
  end

  # Returns the time format shown for appointments on the drop-in appointment lists
  # @param time [Time]
  # @return [String]
  def appt_time_created_format(time)
    time.strftime("%l:%M %p")
  end

  # Splits a string containing one or more topics into separate topic names
  # @param topic_string [String]
  # @return [Array<String>]
  def topics_from_string(topic_string)
    if topic_string.include? ' and '
      topic_string.split(' and ').sort
    else
      topic_string.split(', ').map { |t| t.gsub(/^(and )/, '').strip }.sort
    end
  end

  ### CREATE NEW DROP-IN APPOINTMENT ###

  text_field(:student_name_input, id: 'appointment-student-input')
  select_list(:topic_select, id: 'add-topic-select-list')
  elements(:topic_option, :option, xpath: '//select[@id="add-topic-select-list"]/option')
  text_area(:addl_info_text_area, id: 'appointment-details')
  button(:make_appt_button, id: 'create-appointment-confirm')
  button(:make_appt_cancel_button, id: 'create-appointment-cancel')

  # Clicks the button to cancel creation of a new appointment
  def click_cancel_new_appt
    wait_for_update_and_click make_appt_cancel_button_element
  end

  # Selects a drop-in appointment student
  # @param student [BOACUser]
  def choose_student(student)
    set_auto_suggest(student_name_input_element, student.full_name)
  end

  # Selects drop-in appointment reasons
  # @param topics [Array<Topic>]
  def choose_reasons(topics)
    topics.each { |t| wait_for_element_and_select_js(topic_select_element, t.name) }
  end

  # Enters drop-in appointment detail
  # @param detail [String]
  def enter_detail(detail)
    wait_for_textbox_and_type(addl_info_text_area_element, detail)
  end

  # Returns all the available reasons for a new drop-in appointment
  # @return [Array<String>]
  def new_appt_reasons
    wait_for_update_and_click topic_select_element
    wait_until(1) { topic_select_element.options.any? }
    (topic_option_elements.map { |el| el.attribute 'value' }).delete_if &:empty?
  end

  # Combines methods to create an appointment once the modal is open
  # @param appt [Appointment]
  def create_appt(appt)
    choose_student appt.student
    choose_reasons appt.topics
    enter_detail appt.detail
    wait_for_update_and_click make_appt_button_element
    set_new_appt_id appt
    appt.created_date = Time.now
  end

  # Sets the ID of a newly created drop-in appointment
  # @param appt [Appointment]
  def set_new_appt_id(appt)
    start_time = Time.now
    wait_until(3) do
      BOACUtils.get_appt_creation_data appt
      !appt.id.nil?
    end
    logger.warn "Appointment was created in #{Time.now - start_time} seconds"
  rescue
    logger.debug 'Timed out waiting for appointment ID'
    fail
  end

  ### LIST VIEW OF EXISTING APPOINTMENTS ###

  div(:empty_wait_list_msg, id: 'waitlist-is-empty')
  elements(:appt_created_at, :span, xpath: '//span[contains(@id, "appointment-") and contains(@id, "-created-at")]')

  # Returns the link from a drop-in appointment to a student page
  # @param appt [Appointment]
  # @return [PageObject::Elements::Link]
  def student_link_el(appt)
    link_element(xpath: "//a[@id='appointment-#{appt.id}-student-name'][contains(text(), '#{appt.student.full_name}')]")
  end

  # Clicks the link from a drop-in appointment to a student page
  # @param appt [Appointment]
  def click_student_link(appt)
    wait_for_update_and_click student_link_el(appt)
  end

  # Returns the IDs of all visible drop-in appointments
  # @return [Array<String>]
  def visible_appt_ids
    appt_created_at_elements.map { |el| el.attribute('id').split('-')[1] }
  end

  # Returns all the data visible for a given drop-in appointment
  # @param appt [Appointment]
  # @return [Hash]
  def visible_list_view_appt_data(appt)
    (created_date_el = span_element(id: "appointment-#{appt.id}-created-at")).when_visible Utils.short_wait
    student_non_link_el = span_element(xpath: "//span[@id='appointment-#{appt.id}-student-name'][text()='#{appt.student.full_name}']")
    sid_el = span_element(id: "appointment-#{appt.id}-student-sid")
    topics_el = div_element(id: "appointment-#{appt.id}-topics")
    checked_in_el = div_element(id: "appointment-#{appt.id}-checked-in")
    canceled_el = div_element(id: "appointment-#{appt.id}-canceled")
    {
        created_date: created_date_el.text,
        student_link_name: (student_link_el(appt).text if student_link_el(appt).exists?),
        student_non_link_name: (student_non_link_el.text if student_non_link_el.exists?),
        student_sid: (sid_el.text if sid_el.exists?),
        topics: (topics_from_string(topics_el.text) if topics_el.exists?),
        checked_in_status: (checked_in_el.text if checked_in_el.exists?),
        canceled_status: (canceled_el.text if canceled_el.exists?)
    }
  end

  ### SHARED MODAL UI (check-in and details) ###

  span(:modal_created_at, id: 'appointment-created-at')
  span(:modal_topics, id: 'appointment-topics')
  span(:modal_details, id: 'appointment-details')
  button(:modal_check_in_button, id: 'btn-appointment-check-in')
  button(:modal_close_button, id: 'btn-appointment-close')

  # Toggles the Check-in dropdown for a given appointment
  # @param appt [Appointment]
  def click_appt_dropdown_button(appt)
    logger.info "Clicking check-in dropdown for appt #{appt.id}"
    wait_for_update_and_click button_element(id: "appointment-#{appt.id}-dropdown__BV_toggle_")
  end

  # Clicks the Check-in button on a modal
  def click_modal_check_in_button
    wait_for_update_and_click modal_check_in_button_element
  end

  # Clicks the Cancel Appt button for a given appointment
  # @param appt [Appointment]
  def click_cancel_appt_button(appt)
    logger.info "Clicking cancel button for appt #{appt.id}"
    wait_for_update_and_click button_element(id: "btn-appointment-#{appt.id}-cancel")
  end

  ### CHECK-IN MODAL ###

  h3(:check_in_student_name, id: '//div[@id="advising-appointment-check-in"]//h3')
  select_list(:check_in_advisor_select, id: 'checkin-modal-advisor-select')
  elements(:check_in_advisor_option, :option, xpath: '//select[@id="checkin-modal-advisor-select"]/option')
  button(:check_in_close_button, id: 'btn-appointment-close')

  # Clicks the Check-in button for a given appointment in the list
  # @param appt [Appointment]
  def click_appt_check_in_button(appt)
    logger.info "Clicking check-in button for appt #{appt.id}"
    wait_for_update_and_click button_element(id: "appointment-#{appt.id}-dropdown__BV_button_")
  end

  # Returns the UIDs of available advisors
  # @return [Array<String>]
  def check_in_advisors
    wait_for_update_and_click check_in_advisor_select_element
    wait_until(1) { check_in_advisor_select_element.options.any? }
    (check_in_advisor_option_elements.map { |el| el.attribute 'value' }).delete_if &:empty?
  end

  # Selects a given advisor when checking in an appointment
  # @param advisor [BOACUser]
  def select_check_in_advisor(advisor)
    wait_for_element_and_select_js(check_in_advisor_select_element, advisor.uid)
  end

  ### DETAILS MODAL ###

  h3(:details_student_name, id: 'appointment-check-in-student')
  button(:details_check_in_button, id: 'btn-appointment-details-check-in')
  button(:details_close_button, id: 'btn-appointment-cancel')

  # Clicks the Details button for a given appointment
  # @param appt [Appointment]
  def view_appt_details(appt)
    logger.info "Clicking details button for appt #{appt.id}"
    click_appt_dropdown_button appt
    wait_for_update_and_click button_element(id: "btn-appointment-#{appt.id}-details")
    details_check_in_button_element.when_visible 1
  end

  # Clicks the Check-in button on the appointment details modal
  def click_details_check_in_button
    wait_for_update_and_click details_check_in_button_element
  end

  # Clicks the Close button on the appointment details modal
  def click_close_details_button
    logger.info 'Clicking the close button on appt details'
    wait_for_update_and_click details_close_button_element
  end

  ### CANCEL MODAL ###

  select_list(:cancel_reason_select, id: 'cancellation-reason')
  text_area(:cancel_explanation_input, id: 'cancellation-reason-explained')
  button(:cancel_confirm_button, id: 'btn-appointment-cancel')

  # Selects a cancel reason for a given appointment
  # @param appt [Appointment]
  def select_cancel_reason(appt)
    wait_for_element_and_select_js(cancel_reason_select_element, appt.cancel_reason)
  end

  # Enters additional info when canceling a given appointment
  # @param appt [Appointment]
  def enter_cancel_explanation(appt)
    wait_for_textbox_and_type(cancel_explanation_input_element, appt.cancel_detail)
  end

  # Clicks the Cancel button on the cancel modal
  def click_cancel_confirm_button
    wait_for_update_and_click cancel_confirm_button_element
  end

  # Clicks the Close button on the cancel modal
  def click_cancel_close_button
    wait_for_update_and_click modal_close_button_element
  end

end
