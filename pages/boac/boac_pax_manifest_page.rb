require_relative '../../util/spec_helper'

class BOACPaxManifestPage

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACPagination

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

  select_list(:filter_mode_select, id: 'user-filter-options')
  text_area(:user_search_input, id: 'search-user-input')
  elements(:autocomplete_names, :link, xpath: '//a[contains(@id, "search-user-suggestion-")]')
  select_list(:permissions_select, id: 'user-permission-options')
  select_list(:status_select, id: 'user-status-options')
  select_list(:dept_select, id: 'department-select-list')

  # Sets text in a given element and waits for and clicks the first auto-suggest result
  # @param element [PageObject::Element]
  # @param name [String]
  def set_first_auto_suggest(element, name)
    wait_for_element_and_type(element, name)
    sleep Utils.click_wait
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
    wait_for_element_and_select_js(dept_select_element, 'All Departments')
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
    wait_until(Utils.short_wait) { advisor_uid_elements.any? }
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
    dept_els = browser.find_elements(xpath: "//span[contains(@id, 'dept-') and contains(@id, '-#{user.uid}')]/span")
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

end
