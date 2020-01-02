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

  # Splits a string containing one or more topics into separate topic downcased names
  # @param topic_string [String]
  # @return [Array<String>]
  def topics_from_string(topic_string)
    topics = if topic_string.include? ' and '
               topic_string.split(' and ').sort
             else
               topic_string.split(', ').map { |t| t.gsub(/^(and )/, '').strip }.sort
             end
    topics.map &:downcase
  end

  ### CREATE DROP-IN / UPDATE DROP-IN SHARED ELEMENTS ###

  select_list(:topic_select, id: 'add-topic-select-list')
  elements(:topic_option, :option, xpath: '//select[@id="add-topic-select-list"]/option')
  elements(:topic_pill, :div, xpath: '//div[contains(@id, "topic-label-")]')
  text_area(:addl_info_text_area, id: 'appointment-details')

  # Returns the UIDs of available advisors shown as appointment options
  # @return [Array<String>]
  def available_appt_advisor_uids
    if no_advisors_msg?
      []
    else
      wait_for_update_and_click reserve_advisor_select_element
      wait_until(1) { reserve_advisor_select_element.options.any? }
      (reserve_advisor_option_elements.map { |el| el.attribute('value') }).delete_if &:empty?
    end
  end

  # Selects an advisor for an appointment
  # @param advisor [BOACUser]
  def choose_reserve_advisor(advisor)
    logger.info "Reserving appointment for UID #{advisor.uid}"
    wait_for_element_and_select_js(reserve_advisor_select_element, advisor.uid.to_s)
  end

  # Returns all the available reasons for a new drop-in appointment
  # @return [Array<String>]
  def available_appt_reasons
    wait_for_update_and_click topic_select_element
    wait_until(1) { topic_select_element.options.any? }
    (topic_option_elements.map { |el| el.attribute 'value' }).delete_if &:empty?
  end

  # Returns all the visible appointment reasons (downcased)
  # @return [Array<String>]
  def appt_reasons
    topic_pill_elements.map { |el| el.text.strip.downcase }
  end

  # Returns the element element containing an added appointment reason
  # @param topic [Topic]
  # @return [PageObject::Elements::ListItem]
  def appt_reason_pill(topic)
    list_item_element(xpath: "//li[contains(@id, \"appointment-topic\") and contains(., \"#{topic.name}\")]")
  end

  # Returns the button for removing an added appointment reason
  # @param topic [Topic]
  # @return [PageObject::Elements::Button]
  def appt_reason_remove_button(topic)
    button_element(xpath: "//li[contains(@id, \"appointment-topic\") and contains(., \"#{topic.name}\")]//button[contains(@id, \"remove-appointment-topic-\")]")
  end

  # Selects drop-in appointment reasons
  # @param appt [Appointment]
  # @param topics [Array<Topic>]
  def add_reasons(appt, topics)
    topics.each do |t|
      logger.info "Adding reason #{t.name} to appt #{appt.id}"
      wait_for_element_and_select_js(topic_select_element, t.name)
      appt_reason_pill(t).when_present 1
      appt.topics << t if appt.id
    end
  end

  # Removes drop-in appointment reasons
  # @param appt [Appointment]
  # @param topics [Array<Topic>]
  def remove_reasons(appt, topics)
    removed_topics = []
    topics.each do |t|
      logger.info "Removing reason '#{t.name}' from appt #{appt.id}"
      wait_for_update_and_click appt_reason_remove_button(t)
      appt_reason_pill(t).when_not_visible 2
      removed_topics << t
    end
  ensure
    appt.topics -= removed_topics
  end

  # Enters drop-in appointment detail
  # @param appt [Appointment]
  def enter_detail(appt)
    logger.info "Entering appointment detail '#{appt.detail}'"
    wait_for_textbox_and_type(addl_info_text_area_element, appt.detail)
  end

  ### CREATE NEW DROP-IN APPOINTMENT ###

  text_field(:student_name_input, id: 'appointment-student-input')
  div(:student_double_booking_msg, xpath: '//div[contains(., "This student is already in the Drop-In Waitlist.")]')
  select_list(:reserve_advisor_select, id: 'create-modal-advisor-select')
  elements(:reserve_advisor_option, :option, xpath: '//select[@id="create-modal-advisor-select"]/option')
  div(:no_advisors_msg, xpath: '//div[contains(text(), "Sorry, no advisors are on duty.")]')
  button(:make_appt_button, id: 'create-appointment-confirm')
  button(:make_appt_cancel_button, id: 'create-appointment-cancel')

  # Clicks the button to cancel creation of a new appointment
  def click_cancel_new_appt
    logger.info 'Clicking the new appt Cancel button'
    wait_for_update_and_click make_appt_cancel_button_element
  end

  # Selects a drop-in appointment student
  # @param student [BOACUser]
  def choose_student(student)
    logger.info "Selecting student UID #{student.uid}"
    set_auto_suggest(student_name_input_element, student.full_name)
  end

  # Combines methods to create an appointment once the modal is open
  # @param appt [Appointment]
  def create_appt(appt)
    choose_student appt.student
    choose_reserve_advisor appt.reserve_advisor if appt.reserve_advisor
    add_reasons(appt, appt.topics)
    enter_detail appt
    wait_for_update_and_click make_appt_button_element
    set_new_appt_id appt
    appt.created_date = Time.now
    appt.status = AppointmentStatus::WAITING
    appt.inspect
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

  ### ADVISOR AVAILABILITY ###

  # Intake desk

  elements(:availability_toggle_button, :button, xpath: '//button[contains(@id, "toggle-drop-in-availability-")]')

  # Returns the UIDs of all drop-in advisors shown
  # @return [Array<String>]
  def drop_in_advisor_uids
    availability_toggle_button_elements.map { |el| el.attribute('id').split('-').last }
  end

  # Returns the button for toggling advisor availability
  # @return [PageObject::Elements::Button]
  def toggle_availability_button(advisor)
    button_element(id: "toggle-drop-in-availability-#{advisor.uid}")
  end

  # Returns the visible availability status for an advisor
  # @param advisor [BOACUser]
  # @return [Boolean]
  def advisor_available?(advisor)
    (el = div_element(xpath: "//button[@id='toggle-drop-in-availability-#{advisor.uid}']/../../div[contains(@class, 'availability-status-active')]")).when_present 2
    el.text.strip == 'ON DUTY'
  end

  # Sets an advisor's availability to true
  # @param advisor [BOACUser]
  def set_advisor_available(advisor)
    if advisor_available? advisor
      logger.warn "UID #{advisor.uid} is already available for drop-in appointments"
    else
      logger.info "Making UID #{advisor.uid} available for drop-in appointments"
      wait_for_update_and_click toggle_availability_button(advisor)
      wait_until(1) { advisor_available? advisor }
    end
  end

  # Sets an advisor's availability to false
  # @param advisor [BOACUser]
  def set_advisor_unavailable(advisor)
    if advisor_available? advisor
      logger.info "Making UID #{advisor.uid} unavailable for drop-in appointments"
      wait_for_update_and_click toggle_availability_button(advisor)
      wait_until(1) { !advisor_available? advisor }
    else
      logger.warn "UID #{advisor.uid} is already unavailable for drop-in appointments"
    end
  end

  # Waiting list

  button(:availability_toggle_me_button, id: 'toggle-drop-in-availability-me')

  # Returns the visible availability status for a logged-in advisor
  # @return [Boolean]
  def self_available?
    div_element(xpath: '//div[contains(@class, "availability-status-active")]').text.strip == 'ON DUTY'
  end

  # Sets a logged-in advisor's availability to true
  def set_self_available
    logger.info "Making the logged-in advisor available for drop-in appointments"
    wait_for_update_and_click availability_toggle_me_button_element
    wait_until(1) { self_available? }
  end

  # Sets a logged-in advisor's availability to false
  def set_self_unavailable
    logger.info "Making the logged-in advisor unavailable for drop-in appointments"
    wait_for_update_and_click availability_toggle_me_button_element
    wait_until(1) { !self_available? }
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
    logger.info "Clicking the student link for appt #{appt.id}, UID #{appt.student.uid}"
    wait_for_update_and_click student_link_el(appt)
  end

  # Returns the IDs of all visible drop-in appointments
  # @return [Array<String>]
  def visible_appt_ids
    appt_created_at_elements.map { |el| el.attribute('id').split('-')[1] }
  rescue Selenium::WebDriver::Error::StaleElementReferenceError
    []
  end

  # Returns the element indicating that an appointment is assigned to an advisor
  # @param appt [Appointment]
  # @return [PageObject::Elements::Span]
  def reserved_for_el(appt)
    span_element(id: "assigned-to-#{appt.id}")
  end

  # Returns the Undo button for a checked-in appointment
  # @param appt [Appointment]
  # @return [PageObject::Elements::Button]
  def check_in_undo_button(appt)
    button_element(xpath: "//div[@id='appointment-#{appt.id}-checked-in']/../preceding-sibling::div/button")
  end

  # Clicks the Undo button for a checked-in appointment
  # @param appt [Appointment]
  def undo_appt_check_in(appt)
    wait_for_update_and_click check_in_undo_button(appt)
    check_in_undo_button(appt).when_not_visible Utils.short_wait
    appt.status = AppointmentStatus::WAITING
  end

  # Returns the Undo button for a canceled appointment
  # @param appt [Appointment]
  # @return [PageObject::Elements::Button]
  def cancel_undo_button(appt)
    button_element(xpath: "//div[@id='appointment-#{appt.id}-cancelled']/preceding-sibling::div/button")
  end

  # Clicks the Undo button for a canceled appointment
  # @param appt [Appointment]
  def undo_appt_cancel(appt)
    wait_for_update_and_click cancel_undo_button(appt)
    cancel_undo_button(appt).when_not_visible Utils.short_wait
    appt.status = AppointmentStatus::WAITING
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
    canceled_el = div_element(id: "appointment-#{appt.id}-cancelled")
    {
        created_date: created_date_el.text,
        student_link_name: (student_link_el(appt).text if student_link_el(appt).exists?),
        student_non_link_name: (student_non_link_el.text if student_non_link_el.exists?),
        student_sid: (sid_el.text if sid_el.exists?),
        topics: (topics_from_string(topics_el.text) if topics_el.exists?),
        reserved_by: (reserved_for_el(appt).text if reserved_for_el(appt).exists?),
        checked_in_status: (checked_in_el.text if checked_in_el.exists?),
        canceled_status: (canceled_el.text if canceled_el.exists?)
    }
  end

  ### SHARED MODAL UI (check-in and details) ###

  h3(:modal_student_name, id: 'appointment-check-in-student')
  span(:modal_created_at, id: 'appointment-created-at')
  button(:modal_close_button, id: 'btn-appointment-close')

  # Toggles the Check-in dropdown for a given appointment
  # @param appt [Appointment]
  def click_appt_dropdown_button(appt)
    logger.info "Clicking check-in dropdown for appt #{appt.id}"
    wait_for_update_and_click button_element(id: "appointment-#{appt.id}-dropdown__BV_toggle_")
  end

  # Clicks the Cancel Appt button for a given appointment
  # @param appt [Appointment]
  def click_cancel_appt_button(appt)
    logger.info "Clicking cancel button for appt #{appt.id}"
    wait_for_update_and_click button_element(id: "btn-appointment-#{appt.id}-cancel")
  end

  ### CHECK-IN MODAL ###

  button(:modal_check_in_button, id: 'btn-appointment-check-in')
  h3(:check_in_student_name, id: '//div[@id="advising-appointment-check-in"]//h3')
  span(:modal_topics, id: 'appointment-topics')
  span(:modal_details, id: 'appointment-details')
  select_list(:check_in_advisor_select, id: 'checkin-modal-advisor-select')
  elements(:check_in_advisor_option, :option, xpath: '//select[@id="checkin-modal-advisor-select"]/option')
  button(:check_in_close_button, id: 'btn-appointment-close')

  def check_in_button(appt)
    button_element(id: "appointment-#{appt.id}-dropdown__BV_button_")
  end

  # Clicks the Check-in button on a modal
  def click_modal_check_in_button
    wait_for_update_and_click modal_check_in_button_element
  end

  # Clicks the Check-in button for a given appointment in the list
  # @param appt [Appointment]
  def click_appt_check_in_button(appt)
    logger.info "Clicking check-in button for appt #{appt.id}"
    wait_for_update_and_click check_in_button(appt)
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

  ### RESERVE / UN-RESERVE ###

  select_list(:assign_modal_advisor_select, id: 'assign-modal-advisor-select')
  button(:assign_modal_assign_button, id: 'btn-appointment-assign')

  # Returns the button for assigning an appointment
  # @param appt [Appointment]
  # @return [PageObject::Elements::Button]
  def reserve_appt_button(appt)
    button_element(id: "btn-appointment-#{appt.id}-reserve")
  end

  # Clicks the button for assigning an appointment
  # @param appt [Appointment]
  def click_reserve_appt_button(appt)
    logger.info "Clicking reserve button for appointment #{appt.id}"
    click_appt_dropdown_button appt
    wait_for_update_and_click reserve_appt_button(appt)
  end

  # Assigns an existing appointment to a given advisor
  # @param appt [Appointment]
  # @param advisor [BOACUser]
  def reserve_appt_for_advisor(appt, advisor)
    logger.info "Reserving appointment #{appt.id} for UID #{advisor.uid}"
    click_reserve_appt_button appt
    wait_for_element_and_select_js(assign_modal_advisor_select_element, advisor.uid)
    wait_for_update_and_click assign_modal_assign_button_element
  end

  # Returns the button for un-assigning an appointment
  # @param appt [Appointment]
  # @return [PageObject::Elements::Button]
  def unreserve_appt_button(appt)
    button_element(id: "btn-appointment-#{appt.id}-unreserve")
  end

  # Clicks the button for un-assigning an appointment
  # @param appt [Appointment]
  def click_unreserve_appt_button(appt)
    logger.info "Clicking unreserve button for appointment #{appt.id}"
    click_appt_dropdown_button appt
    wait_for_update_and_click unreserve_appt_button(appt)
  end

  ### DETAILS (UPDATE) MODAL ###

  h3(:details_student_name, id: 'appointment-check-in-student')
  button(:details_update_button, id: 'btn-appointment-details-update')
  button(:details_close_button, id: 'btn-appointment-cancel')

  # Clicks the Details button for a given appointment
  # @param appt [Appointment]
  def view_appt_details(appt)
    logger.info "Clicking details button for appt #{appt.id}"
    click_appt_dropdown_button appt
    wait_for_update_and_click button_element(id: "btn-appointment-#{appt.id}-details")
    modal_student_name_element.when_visible 1
  end

  # Clicks the Update button on the appointment details modal
  def click_details_update_button
    wait_for_update_and_click details_update_button_element
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
