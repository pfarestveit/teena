require_relative '../../util/spec_helper'

class BOACAdminPage

  include PageObject
  include Logging
  include Page
  include BOACPages

  checkbox(:demo_mode_toggle, :id => 'toggle-demo-mode')
  link(:download_users_button, :id => 'download-boa-users-csv')
  checkbox(:post_service_announcement_checkbox, id: 'checkbox-publish-service-announcement')
  h2(:status_heading, :id => 'system-status-header')
  h2(:dept_users_section, :id => 'dept-users-section')
  h2(:edit_service_announcement, :id => 'edit-service-announcement')
  text_area(:update_service_announcement, xpath: '//div[@role="textbox"]')
  button(:update_service_announcement_button, id: 'button-update-service-announcement')
  span(:service_announcement_banner, id: 'service-announcement-banner')
  span(:service_announcement_checkbox_label, id: 'checkbox-service-announcement-label')

  # Loads the admin page
  def load_page
    navigate_to "#{BOACUtils.base_url}/admin"
  end

  # Clicks the admin link to download a CSV of BOA users and returns the parsed date
  # @return [Array<Array>]
  def download_boa_users
    logger.info 'Downloading BOA users CSV'
    Utils.prepare_download_dir
    wait_for_update_and_click download_users_button_element
    csv_file_path = "#{Utils.download_dir}/boa_users_#{Date.today.strftime("%Y-%m-%d")}_*.csv"
    wait_until { Dir[csv_file_path].any? }
    csv = Dir[csv_file_path].first
    CSV.table csv
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

  # Updates service announcement without touching the 'Post' checkbox
  # @param announcement [String]
  def update_service_announcement(announcement)
    logger.info "Entering service announcement '#{announcement}'"
    wait_for_textbox_and_type(update_service_announcement_element, announcement, 200)
    wait_for_update_and_click update_service_announcement_button_element
  end

  # Checks or un-checks the service announcement "Post" checkbox
  def toggle_service_announcement_checkbox
    logger.info 'Clicking the service announcement posting checkbox'
    (el = post_service_announcement_checkbox_element).when_present Utils.short_wait
    js_click el
    el.when_not_present Utils.short_wait
    post_service_announcement_checkbox_element.when_present Utils.short_wait
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
