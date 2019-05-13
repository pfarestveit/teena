require_relative '../../util/spec_helper'

class BOACAdminPage

  include PageObject
  include Logging
  include Page
  include BOACPages

  checkbox(:demo_mode_toggle, :id => 'toggle-demo-mode')
  h2(:status_heading, :id => 'system-status-header')
  h2(:dept_users_section, :id => 'dept-users-section')
  h2(:edit_service_alert, :id => 'edit-service-announcement')
  text_area(:update_service_alert_input, id: 'textarea-update-service-announcement')
  button(:update_service_alert_button, id: 'update-service-announcement')
  checkbox(:publish_service_alert_checkbox, id: 'checkbox-publish-service-announcement')
  div(:service_announcement_banner, id: 'service-announcement-banner')

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

  # Returns the state of a publish_service_alert checkbox
  # @return [boolean]
  def publish_service_alert_checked?
    publish_service_alert_checkbox_element.when_visible Utils.short_wait
    publish_service_alert_checkbox_element.attribute('aria-label') == 'Checked'
  end

  def toggle_publish_service_alert
    wait_for_update_and_click publish_service_alert_checkbox_element
  end

end
