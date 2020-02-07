require_relative '../../util/spec_helper'

class BOACFlightDeckPage

  include PageObject
  include Logging
  include Page
  include BOACPages

  h2(:my_profile_heading, xpath: '//h2[text()="My Profile"]')
  checkbox(:demo_mode_toggle, id: 'toggle-demo-mode')
  h2(:status_heading, id: 'system-status-header')

  # Loads the admin page
  def load_page
    navigate_to "#{BOACUtils.base_url}/admin"
  end

  def drop_in_advising_toggle_el(dept)
    button_element(xpath: "//button[@id='toggle-drop-in-advising-#{dept.code if dept}']")
  end

  def drop_in_advising_enabled?(dept)
    drop_in_advising_toggle_el(dept).when_visible Utils.short_wait
    span_element(xpath: "//button[@id='toggle-drop-in-advising-#{dept.code}']/span/span").text == 'YES'
  end

  def disable_drop_in_advising_role(dept_membership)
    if drop_in_advising_enabled? dept_membership.dept
      logger.info "Drop-in role is enabled in dept #{dept_membership.dept.code}, removing"
      wait_for_update_and_click drop_in_advising_toggle_el(dept_membership.dept)
    else
      logger.info "Drop-in role is already disabled in dept #{dept_membership.dept.code}"
    end
    dept_membership.is_drop_in_advisor = false
  end

  def enable_drop_in_advising_role(dept_membership = nil)
    if drop_in_advising_enabled?(dept_membership&.dept)
      logger.info "Drop-in role is already enabled#{ + ' in dept ' + dept_membership.dept.code if dept_membership}"
    else
      logger.info "Drop-in role is disabled#{ + 'in dept ' + dept_membership.dept.code if dept_membership}, adding"
      wait_for_update_and_click drop_in_advising_toggle_el(dept_membership&.dept)
    end
    dept_membership.is_drop_in_advisor = true
  end

  #### SERVICE ANNOUNCEMENTS ####

  checkbox(:post_service_announcement_checkbox, id: 'checkbox-publish-service-announcement')
  h2(:edit_service_announcement, id: 'edit-service-announcement')
  text_area(:update_service_announcement, xpath: '//div[@role="textbox"]')
  button(:update_service_announcement_button, id: 'button-update-service-announcement')
  span(:service_announcement_banner, id: 'service-announcement-banner')
  span(:service_announcement_checkbox_label, id: 'checkbox-service-announcement-label')

  # Updates service announcement without touching the 'Post' checkbox
  # @param announcement [String]
  def update_service_announcement(announcement)
    logger.info "Entering service announcement '#{announcement}'"
    wait_for_textbox_and_type(update_service_announcement_element, announcement)
    wait_for_update_and_click update_service_announcement_button_element
  end

  # Checks or un-checks the service announcement "Post" checkbox
  def toggle_service_announcement_checkbox
    logger.info 'Clicking the service announcement posting checkbox'
    (el = post_service_announcement_checkbox_element).when_present Utils.short_wait
    js_click el
  end

  # Posts service announcement
  def post_service_announcement
    logger.info 'Posting a service announcement'
    service_announcement_checkbox_label_element.when_visible Utils.short_wait
    tries ||= 2
    begin
      tries -= 1
      sleep Utils.click_wait
      toggle_service_announcement_checkbox if service_announcement_checkbox_label == 'Post'
      wait_until(Utils.short_wait) { service_announcement_checkbox_label == 'Posted' }
    rescue
      if tries.zero?
        logger.error 'Failed to post service alert'
        fail
      else
        logger.warn 'Failed to post service alert, retrying'
        retry
      end
    end
  end

  # Unposts service announcement
  def unpost_service_announcement
    logger.info 'Un-posting a service announcement'
    service_announcement_checkbox_label_element.when_visible Utils.medium_wait
    tries ||= 2
    begin
      tries -= 1
      sleep Utils.click_wait
      toggle_service_announcement_checkbox if service_announcement_checkbox_label == 'Posted'
      wait_until(Utils.short_wait) { service_announcement_checkbox_label == 'Post' }
    rescue
      if tries.zero?
        logger.error 'Failed to unpost a service alert'
        fail
      else
        logger.warn 'Failed to unpost a service alert, retrying'
        retry
      end

    end
  end

  ### SCHEDULERS ###

  text_field(:add_scheduler_input, id: 'add-scheduler-input-input')
  button(:add_scheduler_button, id: 'add-scheduler-input-add-button')
  elements(:add_scheduler_option, :link, xpath: '//a[contains(@id, "add-scheduler-input-suggestion-")]')
  elements(:scheduler_uid, :div, xpath: '//div[@id="scheduler-rows"]/div')
  button(:confirm_remove_scheduler, id: 'remove-scheduler-confirm')
  button(:cancel_remove_scheduler, id: 'remove-scheduler-cancel')

  # Adds a scheduler
  # @param scheduler [BOACUser]
  def add_scheduler(scheduler)
    logger.info "Adding scheduler SID #{scheduler.sis_id}"
    wait_for_element_and_type(add_scheduler_input_element, scheduler.sis_id)
    sleep Utils.click_wait
    wait_until(2) { auto_suggest_option_elements.any? }
    link_element = auto_suggest_option_elements.first
    wait_for_load_and_click link_element
    wait_for_update_and_click add_scheduler_button_element
    sleep 1
  end

  # Returns the UIDs of the visible schedulers
  # @return [Array<String>]
  def visible_scheduler_uids
    scheduler_uid_elements.map { |el| el.attribute('id').split('-').last }.sort
  end

  # Clicks the Remove button for a scheduler
  # @param scheduler [BOACUser]
  def click_remove_scheduler(scheduler)
    wait_for_update_and_click button_element(xpath: "//button[@id='scheduler-row-#{scheduler.uid}-remove-button']")
  end

  # Removes a scheduler
  # @param scheduler [BOACUser]
  def remove_scheduler(scheduler)
    logger.info "Removing scheduler UID #{scheduler.uid}"
    click_remove_scheduler scheduler
    wait_for_update_and_click confirm_remove_scheduler_element
    sleep 1
    wait_until(Utils.short_wait) { !visible_scheduler_uids.include? scheduler.uid }
  end

  # Clicks the cancel button when removing a scheduler
  def click_cancel_remove_scheduler
    wait_for_update_and_click cancel_remove_scheduler_element
  end

end
