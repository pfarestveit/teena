require_relative '../../util/spec_helper'

class BOACAdminPage

  include PageObject
  include Logging
  include Page
  include BOACPages

  checkbox(:demo_mode_toggle, :id => 'toggle-demo-mode')
  checkbox(:post_service_announcement_checkbox, id: 'checkbox-publish-service-announcement')
  h2(:status_heading, :id => 'system-status-header')
  h2(:dept_users_section, :id => 'dept-users-section')
  h2(:edit_service_announcement, :id => 'edit-service-announcement')
  elements(:update_service_announcement, :text_area, xpath: '//div[@role="textbox"]')
  button(:update_service_announcement_button, id: 'button-update-service-announcement')
  span(:service_announcement_banner, id: 'service-announcement-banner')
  span(:service_announcement_checkbox_label, id: 'checkbox-service-announcement-label')

  # Loads the admin page
  def load_page
    navigate_to "#{BOACUtils.base_url}/admin"
  end

  # Returns link to dept tab on admin page
  # @param dept [BOACDepartment]
  # @return [PageObject::Elements::Link]
  def dept_tab_link_element(dept)
    link_element(xpath: "//a[starts-with(@id, 'dept-#{dept.code}')]")
  end

  # Returns link to dept tab on admin page
  # @param user [BOACUser]
  # @return [PageObject::Elements::Link]
  def become_user_link_element(user)
    link_element(id: "become-#{user.uid}")
  end

  # Clicks dept tab to view corresponding users
  # @param dept [BOACDepartment]
  def click_dept_tab_link_element(dept)
    logger.debug "Click '#{dept.name}' tab in 'Users' section"
    wait_for_load_and_click(dept_tab_link_element dept)
  end

  # Click link to become user
  # @param user [BOACUser]
  def click_become_user_link_element(user)
    logger.debug "Become user #{user.uid}"
    wait_for_load_and_click(become_user_link_element user)
  end

  def is_service_announcement_posted?
    service_announcement_checkbox_label_element.when_visible Utils.medium_wait
    sleep 2
    service_announcement_checkbox_label_element.text == 'Posted'
  end

  # Updates service announcement without touching the 'Post' checkbox
  # @param announcement [String]
  def update_service_announcement(announcement)
    service_announcement_textbox = update_service_announcement_elements[0]
    wait_for_textbox_and_type(service_announcement_textbox, announcement, 200)
    wait_for_update_and_click update_service_announcement_button_element
  end

  # Checks or un-checks the service announcement "Post" checkbox
  def toggle_service_announcement_checkbox
    wait_until(Utils.medium_wait) { service_announcement_checkbox_label_element.text.include? 'Post' }
    js_click post_service_announcement_checkbox_element
    # Wait for the checkbox to come back, indicating end of transaction
    sleep 2
    service_announcement_checkbox_label_element.when_present Utils.medium_wait
  end

  # Posts service announcement
  def post_service_announcement
    unless is_service_announcement_posted?
      toggle_service_announcement_checkbox
    end
    wait_until(Utils.medium_wait) { service_announcement_checkbox_label_element.text == 'Posted' }
  end

  # Unposts service announcement
  def unpost_service_announcement
    if is_service_announcement_posted?
      toggle_service_announcement_checkbox
    end
    wait_until(Utils.medium_wait) { service_announcement_checkbox_label_element.text == 'Post' }
  end

end
