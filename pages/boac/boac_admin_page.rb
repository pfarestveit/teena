require_relative '../../util/spec_helper'

class BOACAdminPage

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACPagination

  checkbox(:demo_mode_toggle, id: 'toggle-demo-mode')
  h2(:status_heading, id: 'system-status-header')

  # Loads the admin page
  def load_page
    navigate_to "#{BOACUtils.base_url}/admin"
  end

  #### USERS ####

  h2(:dept_users_section, id: 'dept-users-section')

  # User export

  link(:download_users_button, id: 'download-boa-users-csv')

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

  # Filters

  text_area(:user_search_input, id: 'user-name-uid-search')
  select_list(:dept_select, id: 'department-select-list')
  elements(:filter_checkbox, :text_area, xpath: '//input[contains(@id, "user-permission-options")]')
  checkbox(:admins_cbx, xpath: '//input[@value="isAdmin"]')
  checkbox(:advisors_cbx, xpath: '//input[@value="isAdvisor"]')
  checkbox(:canvas_access_cbx, xpath: '//input[@value="canAccessCanvasData"]')
  checkbox(:directors_cbx, xpath: '//input[@value="isDirector"]')
  checkbox(:drop_in_advisors_cbx, xpath: '//input[@value="isDropInAdvisor"]')
  checkbox(:schedulers_cbx, xpath: '//input[@value="isScheduler"]')
  checkbox(:active_cbx, xpath: '//input[@value="isActive"]')
  checkbox(:deleted_cbx, xpath: '//input[@value="deletedAt"]')
  checkbox(:blocked_cbx, xpath: '//input[@value="isBlocked"]')
  checkbox(:expired_cbx, xpath: '//input[@value="isExpiredPerLdap"]')
  button(:reset_filters_button, id: 'user-filter-reset-button')

  # Enters an advisor UID in the user search input
  # @param advisor [BOACUser]
  def search_for_advisor(advisor)
    logger.info "Searching for advisor UID #{advisor.uid}"
    wait_for_element_and_type(user_search_input_element, advisor.uid)
  end

  # Clicks the Reset Filter button
  def reset_filters
    logger.info 'Resetting filters'
    wait_for_update_and_click reset_filters_button_element unless reset_filters_button_element.disabled?
  end

  # Selects the All Departments option
  def select_all_depts
    logger.info 'Selecting All Departments'
    wait_for_element_and_select_js(dept_select_element, 'All Departments')
  end

  # Selects a given department option
  # @param dept [BOACDepartments]
  def select_dept(dept)
    logger.info "Selecting department '#{dept.name}'"
    wait_for_element_and_select_js(dept_select_element, dept.name)
  end

  # Clicks the checkbox for a filter with a given label
  # @param label [String]
  def toggle_checkbox_filter(label)
    js_click checkbox_element(xpath: "//label[contains(.,'#{label}')]/preceding-sibling::input")
  end

  # Clicks the Reset Filter button and then clicks the unchecked filter checkboxes, effectively checking all boxes
  def check_all_filters
    logger.info 'Checking all filter checkboxes'
    reset_filters
    deleted_cbx_element.when_present Utils.short_wait
    js_click deleted_cbx_element
    js_click blocked_cbx_element
    js_click expired_cbx_element
  end

  # Clicks the Reset Filter button and then clicks the checked filter checkboxes, effectively un-checking all the boxes
  def uncheck_all_filters
    logger.info 'Un-checking all filter checkboxes'
    reset_filters
    admins_cbx_element.when_present Utils.short_wait
    js_click admins_cbx_element
    js_click advisors_cbx_element
    js_click canvas_access_cbx_element
    js_click directors_cbx_element
    js_click drop_in_advisors_cbx_element
    js_click schedulers_cbx_element
    js_click active_cbx_element
  end

  # Advisor list

  elements(:advisor_uid, :div, xpath: '//div[contains(@id, "uid-")]')
  elements(:advisor_name, :link, xpath: '//a[contains(@id, "directory-link-")]')
  elements(:advisor_title, :div, xpath: '//div[contains(@id, "title-")]')
  elements(:advisor_email, :div, xpath: '//div[contains(@id, "email-")]')

  # Waits briefly for at least one advisor row element to be present
  def wait_for_advisor_list
    sleep 1
    wait_until(Utils.short_wait) { advisor_uid_elements.any? }
  rescue
    logger.warn 'There are no advisors listed.'
  end

  # Returns all the UIDs in an advisor result set
  # @return [Array<String>]
  def list_view_uids
    wait_for_advisor_list
    visible_uids = []
    page_count = list_view_page_count
    page = 1
    if page_count == 1
      logger.debug 'There is 1 page'
      visible_uids << advisor_uid_elements.map(&:text)
    else
      logger.debug "There are #{page_count} pages"
      visible_uids << advisor_uid_elements.map(&:text)
      (page_count - 1).times do
        page += 1
        wait_for_update_and_click go_to_next_page_link_element
        wait_until(Utils.medium_wait) { advisor_uid_elements.any? }
        visible_uids << advisor_uid_elements.map(&:text)
      end
    end
    visible_uids.flatten
  end

  # Sorts an advisor result set by UID (asc or desc, whichever applies to the current state of the list)
  def sort_by_uid
    sort_by_option 'Uid'
  end

  # Returns all the department names shown for a given user row
  # @param user [BOACUser]
  # @return [Array<String>]
  def visible_advisor_depts(user)
    dept_els = browser.find_elements(xpath: "//span[contains(@id, 'dept-') and contains(@id, '-#{user.uid}')]")
    dept_els.map &:text
  end

  # Clicks the button to expand a given user row
  # @param user [BOACUser]
  def expand_user_row(user)
    wait_for_update_and_click button_element(id: "user-#{user.uid}-details-toggle")
  end

  # Returns the Canvas permission for a given user row
  # @param user [BOACUser]
  # @return [String]
  def visible_canvas_perm(user)
    canvas_el = list_item_element(id: "permission-canvas-data-#{user.uid}")
    canvas_el.text if canvas_el.exists?
  end

  # Returns the Admin status for a given user row
  # @param user [BOACUser]
  # @return [String]
  def visible_admin_perm(user)
    admin_el = list_item_element(id: "permission-admin-#{user.uid}")
    admin_el.text if admin_el.exists?
  end

  # Returns the deleted status for a given user row
  # @param user [BOACUser]
  # @return [String]
  def visible_deleted_status(user)
    status_el = list_item_element(id: "status-deleted-#{user.uid}")
    status_el.text if status_el.exists?
  end

  # Returns the blocked status for a given user row
  # @param user [BOACUser]
  # @return [String]
  def visible_blocked_status(user)
    status_el = list_item_element(id: "status-blocked-#{user.uid}")
    status_el.text if status_el.exists?
  end

  # Returns the expired status for a given user row
  # @param user [BOACUser]
  # @return [String]
  def visible_expired_status(user)
    status_el = list_item_element(id: "status-expired-#{user.uid}")
    status_el.text if status_el.exists?
  end

  # Returns the department roles for a given user row
  # @param user [BOACUser]
  # @return [Array<String>]
  def visible_dept_roles(user)
    dept_role_els = browser.find_elements(xpath: "//td[contains(@id, 'dept-roles-') and contains(@id, '-#{user.uid}')]")
    dept_role_els.map &:text
  end

  # Returns the department membership types for a given user row
  # @param user [BOACUser]
  # @return [Array<String>]
  def visible_dept_memberships(user)
    dept_memb_els = browser.find_elements(xpath: "//td[contains(@id, 'dept-membership-') and contains(@id, '-#{user.uid}')]")
    dept_memb_els.map &:text
  end

  # Returns link to dept tab on admin page
  # @param user [BOACUser]
  # @return [PageObject::Elements::Link]
  def become_user_link_element(user)
    link_element(id: "become-#{user.uid}")
  end

  # Click link to become user
  # @param user [BOACUser]
  def click_become_user_link_element(user)
    logger.debug "Become user #{user.uid}"
    wait_for_load_and_click(become_user_link_element user)
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
