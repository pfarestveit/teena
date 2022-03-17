require_relative '../../util/spec_helper'

class BOACPaxManifestPage

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACPagination

  h2(:dept_users_section, id: 'dept-users-section')

  # Hits the page URL without verifying that the page loads successfully
  def hit_page_url
    navigate_to "#{BOACUtils.base_url}/admin/passengers"
  end

  # Loads the Passenger Manifest
  def load_page
    hit_page_url
    user_search_input_element.when_visible Utils.medium_wait
  end

  # User export

  link(:download_users_button, id: 'download-boa-users-csv')

  # Clicks the admin link to download a CSV of BOA users and returns the parsed date
  # @return [Array<Array>]
  def download_boa_users
    logger.info 'Downloading BOA users CSV'
    Utils.prepare_download_dir
    wait_for_update_and_click download_users_button_element
    csv_file_path = "#{Utils.download_dir}/boa_users_#{Time.now.utc.strftime("%Y-%m-%d")}_*.csv"
    wait_until(Utils.medium_wait) { Dir[csv_file_path].any? }
    csv = Dir[csv_file_path].first
    CSV.table csv
  end

  # Filters

  select_list(:filter_mode_select, id: 'user-filter-options')
  text_area(:user_search_input, id: 'search-user-input')
  elements(:autocomplete_names, :link, xpath: '//a[contains(@id, "search-user-suggestion-")]')
  select_list(:permissions_select, id: 'user-permission-options')
  select_list(:status_select, id: 'user-status-options')
  select_list(:dept_select, id: 'department-select-list')

  # Sets text in a given element and waits for and clicks the first auto-suggest result
  # @param element [Element]
  # @param name [String]
  def set_first_auto_suggest(element, name)
    wait_for_element_and_type(element, name)
    sleep Utils.click_wait
    wait_until(Utils.short_wait) { auto_suggest_option_elements.any? }
    sleep 2
    link_element = auto_suggest_option_elements.first
    wait_for_load_and_click link_element
  end

  # Enters an advisor UID in the user search input
  # @param advisor [BOACUser]
  def search_for_advisor(advisor)
    logger.info "Searching for advisor UID #{advisor.uid}"
    wait_for_element(user_search_input_element, Utils.medium_wait)
    set_first_auto_suggest(user_search_input_element, advisor.uid)
  end

  # Selects the Filter option
  def select_filter_mode
    wait_for_element_and_select_js(filter_mode_select_element, 'Filter')
  end

  # Selects the All Departments option
  def select_all_depts
    logger.info 'Selecting All Departments'
    wait_for_element_and_select_js(dept_select_element, 'All')
  end

  # Selects a given department option
  # @param dept [BOACDepartments]
  def select_dept(dept)
    logger.info "Selecting department '#{dept.name}'"
    wait_for_element_and_select_js(dept_select_element, dept.name)
  end

  # Selects the BOA Admin option
  def select_admin_mode
    wait_for_element_and_select_js(filter_mode_select_element, 'BOA Admins')
  end

  # Advisor list

  elements(:advisor_uid, :span, xpath: '//span[contains(@id, "uid-")]')
  elements(:advisor_name, :link, xpath: '//a[contains(@id, "directory-link-")]')
  elements(:advisor_dept, :span, xpath: '//span[contains(@id, "dept-")]')
  elements(:advisor_email, :link, xpath: '//a[contains(@aria-label, "Send email")]')

  # Waits briefly for at least one advisor row element to be present
  def wait_for_advisor_list
    sleep 1
    wait_until(Utils.medium_wait) { advisor_uid_elements.any? }
  rescue
    logger.warn 'There are no advisors listed.'
  end

  # Returns all the UIDs in an advisor result set
  # @return [Array<String>]
  def list_view_uids
    wait_for_advisor_list
    advisor_uid_elements.map(&:text)
  end

  # Returns all the department names shown for a given user row
  # @param user [BOACUser]
  # @return [Array<String>]
  def visible_advisor_depts(user)
    dept_els = span_elements(xpath: "//span[contains(@id, 'dept-') and contains(@id, '-#{user.uid}')]/span")
    dept_els.map &:text
  end

  # Clicks the button to expand a given user row
  # @param user [BOACUser]
  def expand_user_row(user)
    wait_for_update_and_click button_element(id: "user-#{user.uid}-details-toggle")
  end

  # Returns the user details data for a given user row
  # @param user [BOACUser]
  # @return [Hash]
  def get_user_details(user)
    details_el = browser.find_element(id: "user-details-#{user.uid}")
    JSON.parse details_el.text
  end

  # Returns the department roles for a given user row
  # @param user [BOACUser]
  # @return [Array<String>]
  def visible_dept_roles(user, dept_code)
    dept_role_el = browser.find_element(id: "dept-#{dept_code}-#{user.uid}")
    dept_role_el.text
  end

  # Returns link to dept tab on admin page
  # @param user [BOACUser]
  # @return [Element]
  def become_user_link_element(user)
    link_element(id: "become-#{user.uid}")
  end

  # Click link to become user
  # @param user [BOACUser]
  def click_become_user_link_element(user)
    logger.debug "Become user #{user.uid}"
    wait_for_load_and_click(become_user_link_element user)
  end

  # Add / edit user

  button(:add_user_button, id: 'add-new-user-btn')
  text_field(:add_user_uid_input, id: 'uid-input')
  checkbox(:admin_cbx, id: 'is-admin')
  select_list(:deg_prog_select, id: 'degree-progress-permission-select')
  elements(:remove_dept_button, :button, xpath: '//button[contains(@id, "remove-department-")]')
  select_list(:department_select, id: 'department-select-list')
  checkbox(:automate_deg_prog_cbx, id: 'automate-degree-progress-permission')
  button(:save_user_button, id: 'save-changes-to-user-profile')
  button(:cancel_user_button, id: 'delete-cancel')

  # Returns the element containing a duplicate user error
  # @param user [BOACUser]
  # @return [Element]
  def dupe_user_el(user)
    div_element(xpath: "//div[contains(text(), 'User with UID #{user.uid} is already in the BOA database.')]")
  end

  # Returns the element for the is-admin checkbox
  # @return [Element]
  def is_admin_cbx
    text_area_element(id: 'is-admin')
  end

  # Returns the element for the is-blocked checkbox
  # @return [Element]
  def is_blocked_cbx
    text_area_element(id: 'is-blocked')
  end

  # Returns the element for the can-access-canvas-data checkbox
  # @return [Element]
  def can_access_canvas_data_cbx
    text_area_element(id: 'can-access-canvas-data')
  end

  # Returns the element for the can-access-advising-data checkbox
  # @return [Element]
  def can_access_advising_data_cbx
    text_area_element(id: 'can-access-advising-data')
  end

  # Returns the element for the is-deleted checkbox
  # @return [Element]
  def is_deleted_cbx
    text_area_element(id: 'is-deleted')
  end

  # Returns the button to remove a department role
  # @param dept [BOACDepartments]
  # @return [Element]
  def remove_dept_role_button(dept)
    button_element(id: "remove-department-#{dept.code}")
  end

  # Returns the select element for a given department
  # @param dept [BOACDepartments]
  # @return [Element]
  def dept_role_select(dept)
    select_list_element(id: "select-department-#{dept.code}-role")
  end

  # Returns the element for whether or not a department role is maintained automatically
  # @param dept [BOACDepartments]
  # @return [Element]
  def is_automated_dept_cbx(dept)
    text_area_element(xpath: "//input[@id='is-automate-membership-#{dept.code}']")
  end

  # Returns the button to open the Edit User modal
  # @param user [BOACUser]
  # @return [Element]
  def edit_user_button(user)
    button_element(id: "edit-#{user.uid}")
  end

  # Clicks the Add User button
  def click_add_user
    logger.info 'Clicking the add user button'
    wait_for_update_and_click add_user_button_element
  end

  # Clicks the Edit button for a given user
  # @param user [BOACUser]
  def click_edit_user(user)
    logger.info "Clicking the edit button for UID #{user.uid}"
    wait_for_update_and_click edit_user_button(user)
  end

  def click_cancel_button
    logger.info 'Clicking the cancel button'
    wait_for_update_and_click cancel_user_button_element
  end

  # Sets the user-level flags that are present on both the Add and Edit modals
  # @param user [BOACUser]
  def set_user_level_flags(user)
    logger.info "UID #{user.uid} is-admin is #{user.is_admin}"
    if (user.is_admin && !is_admin_cbx.selected?) || (!user.is_admin && is_admin_cbx.selected?)
      logger.debug 'Clicking is-admin checkbox'
      execute_script('arguments[0].click();', is_admin_cbx)
      sleep Utils.click_wait
    end
    if (user.is_blocked && !is_blocked_cbx.selected?) || (!user.is_blocked && is_blocked_cbx.selected?)
      logger.debug 'Clicking is-blocked checkbox'
      execute_script('arguments[0].click();', is_blocked_cbx)
      sleep Utils.click_wait
    end
    if (user.can_access_canvas_data && !can_access_canvas_data_cbx.selected?) || (!user.can_access_canvas_data && can_access_canvas_data_cbx.selected?)
      logger.debug 'Clicking can-access-canvas-data checkbox'
      execute_script('arguments[0].click();', can_access_canvas_data_cbx)
      sleep Utils.click_wait
    end
    if (user.can_access_advising_data && !can_access_advising_data_cbx.selected?) || (!user.can_access_advising_data && can_access_advising_data_cbx.selected?)
      logger.debug 'Clicking can-access-advising-data checkbox'
      execute_script('arguments[0].click();', can_access_advising_data_cbx)
      sleep Utils.click_wait
    end
    if user.depts&.include? BOACDepartments::COE
      select_deg_prog_option user
    end
  end

  def select_deg_prog_option(user)
    deg_prog_option = user.degree_progress_perm ? user.degree_progress_perm.desc : 'Select...'
    wait_for_element_and_select_js(deg_prog_select_element, deg_prog_option)
  end

  def click_automate_deg_prog
    automate_deg_prog_cbx_element.when_present Utils.short_wait
    execute_script('arguments[0].click();', automate_deg_prog_cbx_element)
  end

  # Adds the department roles associated with a given user
  # @param user [BOACUser]
  def add_user_dept_roles(user)
    user.dept_memberships.each do |membership|
      logger.info "Adding UID #{user.uid} department role #{membership.inspect}"
      wait_for_element_and_select_js(department_select_element, membership.dept.code)
      wait_for_element_and_select_js(dept_role_select(membership.dept), 'Advisor') if membership.advisor_role == AdvisorRole::ADVISOR
      wait_for_element_and_select_js(dept_role_select(membership.dept), 'Director') if membership.advisor_role == AdvisorRole::DIRECTOR
      if (membership.is_automated && !is_automated_dept_cbx(membership.dept).selected?) || (!membership.is_automated && is_automated_dept_cbx(membership.dept).selected?)
        execute_script('arguments[0].click();', is_automated_dept_cbx(membership.dept))
        sleep Utils.click_wait
      end
    end
  end

  def save_user
    wait_for_update_and_click save_user_button_element
    save_user_button_element.when_not_present Utils.short_wait
    sleep 1
  end

  # Enters new user data and clicks the save button
  # @param user [BOACUser]
  def enter_new_user_data(user)
    wait_for_element_and_type(add_user_uid_input_element, user.uid)
    set_user_level_flags user
    add_user_dept_roles user
    wait_for_update_and_click save_user_button_element
  end

  # Adds a given user
  # @param user [BOACUser]
  def add_user(user)
    logger.info "Adding UID #{user.uid}"
    click_add_user
    enter_new_user_data user
    save_user_button_element.when_not_present Utils.short_wait
  end

  # Edits a given user
  # @param user [BOACUser]
  def edit_user(user)
    logger.info "Editing UID #{user.uid} with attributes #{user.inspect}"
    click_edit_user user
    admin_cbx_element.when_present Utils.short_wait
    set_user_level_flags user
    if (user.active && is_deleted_cbx.selected?) || (!user.active && !is_deleted_cbx.selected?)
      logger.debug 'Clicking is-deleted checkbox'
      execute_script('arguments[0].click();', is_deleted_cbx)
      sleep Utils.click_wait
    end
    remove_dept_button_elements.each do |el|
      wait_for_update_and_click el
      el.when_not_present 2
    end
    add_user_dept_roles user
    select_deg_prog_option(user) if user.degree_progress_perm
    save_user
  end

  def search_for_and_edit_user(user)
    search_for_advisor user
    wait_until(Utils.short_wait) { list_view_uids.include? user.uid.to_s }
    edit_user user
  end

  def set_deg_prog_perm(user, dept, perm)
    unless user.degree_progress_perm == perm
      search_for_advisor user
      user.dept_memberships = [DeptMembership.new(dept: dept, advisor_role: AdvisorRole::ADVISOR)]
      user.degree_progress_perm = perm
      edit_user user
    end
  end

end
