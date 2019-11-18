require_relative '../../util/spec_helper'

class BOACHomePage

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACPagesCreateNoteModal
  include BOACApptIntakeDesk
  include BOACUserListPages

  button(:sign_in, id: 'splash-sign-in')
  text_field(:dev_auth_uid_input, id: 'dev-auth-uid')
  text_field(:dev_auth_password_input, id: 'dev-auth-password')
  button(:dev_auth_log_in_button, id: 'dev-auth-submit')
  div(:copyright_year_login, class: 'splash-cell-copyright')
  div(:not_auth_msg, xpath: '//div[contains(., "Sorry, you are not registered to use BOA.")]')
  div(:footer_warning, id: 'fixed-warning-on-all-pages')

  # Loads the home page
  def load_page
    navigate_to BOACUtils.base_url
    wait_for_spinner
  end

  # Clicks the sign in button
  def click_sign_in_button
    wait_for_load_and_click sign_in_element
  end

  # Logs in via CAS
  # @param username [String]
  # @param password [String]
  # @param cal_net [Page::CalNetPage]
  def log_in(username, password, cal_net)
    load_page
    wait_for_title 'Welcome'
    wait_until(Utils.short_wait) { copyright_year_login.include? Time.now.strftime('%Y') }
    click_sign_in_button
    cal_net.log_in(username, password)
    wait_for_title 'Home'
    wait_until(Utils.short_wait) { copyright_year_footer.include? Time.now.strftime('%Y') }
  end

  # Authenticates using dev auth
  # @param user [User]
  def dev_auth(user = nil)
    logger.info "Logging in #{('UID ' + user.uid.to_s + ' ') if user}using developer auth"
    start = Time.now
    load_page
    footer_warning_element.when_visible Utils.short_wait
    scroll_to_bottom
    wait_for_element_and_type(dev_auth_uid_input_element, (user ? user.uid : Utils.super_admin_uid))
    logger.warn "Took #{Time.now - start - Utils.click_wait} seconds for dev auth input to become available"
    wait_for_element_and_type(dev_auth_password_input_element, BOACUtils.password)
    wait_for_update_and_click dev_auth_log_in_button_element
    wait_until(Utils.medium_wait) { ['Home | BOA', 'Drop-in Appointments Desk | BOA'].include? title }
  end

  # DROP-IN APPTS

  button(:new_appt_button, id: 'btn-homepage-create-appointment')

  # Clicks the button to create a new new drop-in appointment
  def click_new_appt
    wait_for_update_and_click new_appt_button_element
  end

  # GENERIC USER DATA UI

  # Returns all the user divs beneath a cohort or group designated by its XPath
  # @param driver [Selenium::WebDriver]
  # @param xpath [String]
  # @return [Array<Selenium::WebDriver::Element>]
  def user_rows(driver, xpath)
    driver.find_elements(xpath: "#{xpath}//tbody/tr")
  end

  # FILTERED COHORTS AND CURATED GROUPS

  elements(:filtered_cohort, :span, xpath: '//div[contains(@id,"sortable-cohort")]//h2/span[2]')
  h1(:no_filtered_cohorts_msg, id: 'no-cohorts-header')
  elements(:curated_group, :span, xpath: '//div[contains(@id,"sortable-curated")]//h2/span[2]')

  # Returns the names of filtered cohorts shown on the homepage
  # @return [Array<String>]
  def filtered_cohorts
    wait_until(Utils.medium_wait) { filtered_cohort_elements.any? }
    filtered_cohort_elements.map &:text
  end

  # Returns the XPath to a filtered cohort's div in the main content area on the homepage
  # @param cohort [FilteredCohort]
  # @return [String]
  def filtered_cohort_xpath(cohort)
    "//div[@id=\"sortable-cohort-#{cohort.id}\"]"
  end

  # Returns the names of curated groups shown on the homepage
  # @return [Array<String>]
  def curated_groups
    wait_until(Utils.medium_wait) { curated_group_elements.any? }
    curated_group_elements.map &:text
  end

  # Returns the XPath to a curated group's div in the main content area on the homepage
  # @param group [CuratedGroup]
  # @return [String]
  def curated_group_xpath(group)
    "//div[@id=\"sortable-curated-#{group.id}\"]"
  end

  # Returns the link to a filtered cohort or curated group in the main content area of the homepage
  # @param cohort [Cohort]
  # @return [PageObject::Elements::Link]
  def view_all_members_link(cohort)
    cohort.instance_of?(FilteredCohort) ?
        link_element(id: "sortable-cohort-#{cohort.id}-view-all") :
        link_element(id: "sortable-curated-#{cohort.id}-view-all")
  end

  # Expands a filtered cohort or curated group row in the main content area
  # @param cohort [Cohort]
  def expand_member_rows(cohort)
    unless view_all_members_link(cohort).visible?
      cohort.instance_of?(FilteredCohort) ?
          wait_for_update_and_click_js(link_element(id: "sortable-cohort-#{cohort.id}-toggle")) :
          wait_for_update_and_click_js(link_element(id: "sortable-curated-#{cohort.id}-toggle"))
    end
  end

  # Returns all the user divs beneath a filtered cohort or curated group
  # @param driver [Selenium::WebDriver]
  # @param cohort [Cohort]
  # @return [Array<Selenium::WebDriver::Element>]
  def member_rows(driver, cohort)
    cohort.instance_of?(FilteredCohort) ?
      user_rows(driver, filtered_cohort_xpath(cohort)) :
      user_rows(driver, curated_group_xpath(cohort))
  end

  # Returns the membership count shown for a filtered cohort or curated group
  # @param cohort [Cohort]
  # @return [Integer]
  def member_count(cohort)
    el = cohort.instance_of?(FilteredCohort) ?
        span_element(id: "sortable-cohort-#{cohort.id}-total-student-count") :
        span_element(xpath: "#{curated_group_xpath(cohort)}//h2/span[3]")
    el.text.to_i if el.exists?
  end

  # Verifies the user + alert data shown for a filtered cohort's or curated group's membership
  # @param driver [Selenium::WebDriver]
  # @param cohort [Cohort]
  # @param advisor [User]
  def verify_member_alerts(driver, cohort, advisor)

    # Only cohort members with alerts should be shown. Collect the expected alert count for each member, and toss out those with a zero count.
    member_alerts = cohort.members.any? ? BOACUtils.get_un_dismissed_users_alerts(cohort.members, advisor) : []
    cohort.member_data.keep_if do |member|
      alert_count = member_alerts.count { |a| a.user.sis_id == member[:sid] }
      logger.debug "SID #{member[:sid]} has alert count #{alert_count}" unless alert_count.zero?
      member.merge!(:alert_count => alert_count)
      member[:alert_count].to_i > 0
    end

    # Only cohort members with the highest alert counts should be shown, to a maximum of 50 members
    cohort.member_data = cohort.member_data.sort { |a, b| [b[:alert_count], a[:sid]] <=> [a[:alert_count], b[:sid]] }
    cohort.member_data = cohort.member_data[0..49]

    # Expand the cohort, and verify that there are only rows for members with alerts
    view_all_members_link(cohort).when_visible Utils.short_wait
    wait_until(Utils.short_wait, "Expecting cohort #{cohort.name} to have row count of #{cohort.member_data.length}, got #{member_rows(driver, cohort).length}") do
      member_rows(driver, cohort).length == cohort.member_data.length
    end

    # Verify that there is a row for each student with a positive alert count and that the alert count is right
    xpath = cohort.instance_of?(FilteredCohort) ? filtered_cohort_xpath(cohort) : curated_group_xpath(cohort)
    cohort.member_data.each do |member|
      logger.debug "Checking cohort row for SID #{member[:sid]}"
      wait_until(1, "Expecting SID #{member[:sid]} alert count #{member[:alert_count]}, got #{user_row_data(driver, member[:sid], xpath)[:alert_count]}") do
        user_row_data(driver, member[:sid], xpath)[:alert_count] == member[:alert_count].to_s
      end
    end
  end

  # Clicks the link for a given Filtered Cohort
  # @param cohort [FilteredCohort]
  def click_filtered_cohort(cohort)
    logger.debug "Clicking link to my cohort '#{cohort.name}'"
    wait_until(Utils.short_wait) { filtered_cohort_elements.any? }
    wait_for_update_and_click_js view_all_members_link(cohort)
  end

end
