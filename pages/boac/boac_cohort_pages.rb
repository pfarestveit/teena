require_relative '../../util/spec_helper'

module BOACCohortPages

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACListViewPages

  h1(:results, xpath: '//h1')
  button(:rename_cohort_button, id: 'rename-cohort-button')
  text_area(:rename_cohort_input, id: 'rename-cohort-input')
  button(:delete_cohort_button, id: 'delete-cohort-button')
  button(:confirm_delete_button, xpath: '//div[@id="myModal"]//button[contains(text(), "Delete")]')
  button(:cancel_delete_button, xpath: '//div[@id="myModal"]//button[contains(text(), "Cancel")]')
  span(:no_access_msg, xpath: '//span[text()="You are unauthorized to access student data managed by other departments"]')

  # Returns the search results count in the page heading
  # @return [Integer]
  def results_count
    sleep 1
    results_element.when_visible Utils.short_wait
    results.split(' ')[0].to_i
  end

  # Deletes a cohort unless it is read-only (e.g., CoE default cohorts).
  # @param cohort [Cohort]
  def delete_cohort(cohort)
    logger.info "Deleting a cohort named #{cohort.name}"
    wait_for_load_and_click delete_cohort_button_element
    wait_for_update_and_click confirm_delete_button_element
    wait_until(Utils.short_wait) { current_url == "#{BOACUtils.base_url}/home" }
    sleep Utils.click_wait
  end

  # Begins deleting a cohort but cancels
  # @param cohort [Cohort]
  def cancel_cohort_deletion(cohort)
    logger.info "Canceling the deletion of cohort #{cohort.name}"
    wait_for_load_and_click delete_cohort_button_element
    wait_for_update_and_click cancel_delete_button_element
    cancel_delete_button_element.when_not_present Utils.short_wait
    wait_until(1) { current_url.include? cohort.id }
  end

  # LIST VIEW - shared by filtered cohorts and curated groups

  # Returns the XPath for a user
  # @param user [User]
  # @return [String]
  def cohort_list_view_user_xpath(user)
    "//div[contains(@class,\"list-group-item\")][contains(.,\"#{user.sis_id}\")]"
  end

  # Returns the level displayed for a user
  # @param user [User]
  # @return [String]
  def cohort_list_view_user_level(user)
    el = span_element(xpath: "#{cohort_list_view_user_xpath user}//*[@data-ng-bind='student.level']")
    el.text if el.exists?
  end

  # Returns the major(s) displayed for a user
  # @param driver [Selenium::WebDriver]
  # @param user [User]
  # @return [Array<String>]
  def cohort_list_view_user_majors(driver, user)
    els = driver.find_elements(xpath: "#{cohort_list_view_user_xpath user}//div[@data-ng-bind='major']")
    els.map &:text if els.any?
  end

  # Returns the sport(s) displayed for a user
  # @param driver [Selenium::WebDriver]
  # @param user [User]
  # @return [Array<String>]
  def cohort_list_view_user_sports(driver, user)
    els = driver.find_elements(xpath: "#{cohort_list_view_user_xpath user}//div[@data-ng-bind='membership.groupName']")
    els.map &:text if els.any?
  end

  # Returns a user's SIS data visible on the cohort page
  # @param [Selenium::WebDriver]
  # @param user [User]
  # @return [Hash]
  def visible_sis_data(driver, user)
    wait_until(Utils.medium_wait) { player_link_elements.any? }
    wait_until(Utils.short_wait) { cohort_list_view_user_level(user) }
    gpa_el = div_element(xpath: "#{cohort_list_view_user_xpath user}//span[contains(@data-ng-bind,'student.cumulativeGPA')]")
    term_units_el = div_element(xpath: "#{cohort_list_view_user_xpath user}//div[contains(@data-ng-bind,'student.term.enrolledUnits')]")
    cumul_units_el = div_element(xpath: "#{cohort_list_view_user_xpath user}//div[contains(@data-ng-bind,'student.cumulativeUnits')]")
    class_els = driver.find_elements(xpath: "#{cohort_list_view_user_xpath user}//div[@data-ng-bind='enrollment.displayName']")
    {
      :level => cohort_list_view_user_level(user),
      :majors => cohort_list_view_user_majors(driver, user),
      :gpa => (gpa_el.text if gpa_el.exists?),
      :term_units => (term_units_el.text if term_units_el.exists?),
      :units_cumulative => ((cumul_units_el.text == '--' ? '0' : cumul_units_el.text) if cumul_units_el.exists?),
      :classes => class_els.map(&:text)
    }
  end

  # SORTING

  select_list(:cohort_sort_select, id: 'cohort-sort-by')

  # Sorts cohort search results by a given option
  # @param option [String]
  def sort_by(option)
    logger.info "Sorting by #{option}"
    wait_for_element_and_select_js(cohort_sort_select_element, option)
    sleep 1
  end

  # Sorts cohort search results by first name
  def sort_by_first_name
    sort_by 'First Name'
  end

  # Sorts cohort search results by last name
  def sort_by_last_name
    sort_by 'Last Name'
  end

  # Sorts cohort search results by team
  def sort_by_team
    sort_by 'Team'
  end

  # Sorts cohort search results by GPA
  def sort_by_gpa
    sort_by 'GPA'
  end

  # Sorts cohort search results by level
  def sort_by_level
    sort_by 'Level'
  end

  # Sorts cohort search results by major
  def sort_by_major
    sort_by 'Major'
  end

  # Sorts cohort search results by units
  def sort_by_units
    sort_by 'Units Completed'
  end

end
