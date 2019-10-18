require_relative '../../util/spec_helper'

class BOACFlightDeckPage

  include PageObject
  include Logging
  include Page
  include BOACPages

  checkbox(:demo_mode_toggle, id: 'toggle-demo-mode')
  h2(:status_heading, id: 'system-status-header')

  # Loads the admin page
  def load_page
    navigate_to "#{BOACUtils.base_url}/admin"
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
    toggle_service_announcement_checkbox if service_announcement_checkbox_label == 'Post'
    wait_until(Utils.short_wait) { service_announcement_checkbox_label == 'Posted' }
  end

  # Unposts service announcement
  def unpost_service_announcement
    logger.info 'Un-posting a service announcement'
    service_announcement_checkbox_label_element.when_visible Utils.medium_wait
    toggle_service_announcement_checkbox if service_announcement_checkbox_label == 'Posted'
    wait_until(Utils.short_wait) { service_announcement_checkbox_label_element.text == 'Post' }
  end

end
