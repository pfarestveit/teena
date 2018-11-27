require_relative '../../util/spec_helper'

module Page

  module BOACPages

    include PageObject
    include Logging
    include Page

    ### PAGE LOADS ###

    div(:spinner, class: 'loading-spinner-large')

    # Waits for an expected page title
    # @param page_title [String]
    def wait_for_title(page_title)
      start = Time.now
      wait_until(Utils.medium_wait) { title == "#{page_title} | BOAC" }
      logger.debug "Page title updated in #{Time.now - start} seconds"
    end

    # Waits for the spinner to vanish following a page load and returns the number of seconds it took the spinner to vanish if greater than 1
    # @return [Float]
    def wait_for_spinner
      start = Time.now
      sleep 1
      if spinner?
        spinner_element.when_not_visible Utils.medium_wait rescue Selenium::WebDriver::Error::StaleElementReferenceError
        wait = Time.now - start
        logger.debug "Spinner lasted for #{wait} seconds"
        wait
      else
        logger.debug 'Spinner lasted less than 1 second'
      end
    end

    ### HEADER ###

    link(:home_link, text: 'Home')
    button(:header_dropdown, id: 'header-dropdown-under-name')
    link(:admin_link, text: 'Admin')
    link(:log_out_link, text: 'Log Out')
    link(:feedback_link, text: 'Feedback/Help')
    div(:modal, class: 'modal-content')
    h1(:student_name_heading, class: 'student-section-header')

    # Clicks the 'Home' link in the header
    def click_home
      wait_for_load_and_click home_link_element
    end

    # Clicks the header name button to reveal additional links
    def click_header_dropdown
      sleep 3
      wait_for_update_and_click_js header_dropdown_element
    end

    # Clicks the 'Log out' link in the header
    def log_out
      logger.info 'Logging out'
      click_header_dropdown
      wait_for_update_and_click_js log_out_link_element
      wait_for_title 'Welcome'
    end

    # Clicks the 'Admin' link in the header
    def click_admin_link
      click_header_dropdown
      wait_for_update_and_click_js admin_link_element
      wait_for_title 'Admin'
    end

    ### CURATED GROUPS - 'CREATE' MODAL ###

    text_area(:curated_name_input, id: 'curated-cohort-create-input')
    button(:curated_save_button, id: 'curated-cohort-create-confirm-btn')
    button(:curated_cancel_button, id: 'curated-cohort-create-cancel-btn')
    div(:dupe_curated_name_msg, xpath: '//div[text()="You have an existing curated group with this name. Please choose a different name."]')

    # Enters a curated group name in the 'create' modal
    # @param group [CuratedGroup]
    def enter_group_name(group)
      logger.debug "Entering curated group name '#{group.name}'"
      wait_for_element_and_type(curated_name_input_element, group.name)
    end

    # Enters a curated group name in the 'create' modal and clicks Save
    # @param group [CuratedGroup]
    def name_and_save_group(group)
      enter_group_name group
      wait_for_update_and_click curated_save_button_element
    end

    # Clicks Cancel in the curated group 'create' modal if it is open
    def cancel_group
      curated_cancel_button
      modal_element.when_not_present Utils.short_wait
    rescue
      logger.warn 'No cancel button to click'
    end

    ### CURATED GROUPS - SIDEBAR ###

    elements(:sidebar_curated_group_link, :link, xpath: '//div[@data-ng-repeat="cohort in profile.myCuratedCohorts"]//a[contains(@class,"sidebar")]')

    # Returns the names of all the curated groups in the sidebar
    # @return [Array<String>]
    def sidebar_groups
      sidebar_curated_group_link_elements.map &:text
    end

    # Waits for a curated group's member count in the sidebar to match expectations
    # @param group [CuratedGroup]
    def wait_for_sidebar_group_member_count(group)
      logger.debug "Waiting for curated group member count of #{group.members.length}"
      wait_until(Utils.short_wait) do
        el = span_element(xpath: "//div[contains(@class,\"sidebar-row-link\")][contains(.,\"#{group.name}\")]//span")
        (el && el.text.delete(' students').chomp) == group.members.length.to_s
      end
    end

    # Waits for a curated group to appear in the sidebar with the right member count and obtains the cohort's ID
    # @param group [CuratedGroup]
    def wait_for_sidebar_group(group)
      wait_until(Utils.short_wait) { sidebar_groups.include? group.name }
      wait_for_sidebar_group_member_count group
      BOACUtils.set_curated_group_id group
    end

    ### CURATED GROUPS - LIST VIEW ADD-TO-GROUP SELECTOR ###

    # Selector 'create' and 'add student(s)' UI shared by list view pages (filtered cohort page and class page)
    button(:selector_create_curated_button, id: 'curated-cohort-create')
    checkbox(:add_all_to_curated_checkbox, id: 'curated-cohort-checkbox-add-all')
    elements(:add_individual_to_curated_checkbox, :checkbox, xpath: '//input[@data-ng-model="student.selectedForCuratedCohort"]')
    button(:add_to_curated_button, id: 'add-to-curated-cohort-button')
    button(:added_to_curated_conf, id: 'added-to-curated-cohort-confirmation')

    # Selects the add-to-group checkboxes for a given set of students
    # @param students [Array<User>]
    def select_students_to_add(students)
      logger.info "Adding student UIDs: #{students.map &:uid}"
      students.each { |s| wait_for_update_and_click checkbox_element(id: "student-#{s.uid}-curated-cohort-checkbox") }
    end

    # Selects a curated group for adding users and waits for the 'added' confirmation.
    # @param students [Array<User>]
    # @param group [CuratedGroup]
    def select_group_and_add(students, group)
      wait_for_update_and_click add_to_curated_button_element
      wait_for_update_and_click checkbox_element(xpath: "//span[text()='#{group.name}']/preceding-sibling::input")
      added_to_curated_conf_element.when_visible Utils.short_wait
      group.members << students
      group.members.flatten!
    end

    # Creates a new curated group for adding users and waits for the 'added' confirmation and presence of the group in the sidebar
    # @param students [Array<User>]
    # @param group [CuratedGroup]
    def selector_create_new_group(students, group)
      wait_for_update_and_click add_to_curated_button_element
      logger.debug 'Clicking curated group selector button to create a new cohort'
      wait_for_load_and_click selector_create_curated_button_element
      curated_name_input_element.when_visible Utils.short_wait
      name_and_save_group group
      added_to_curated_conf_element.when_visible Utils.short_wait
      group.members << students
      group.members.flatten!
      wait_for_sidebar_group group
    end

    # Adds a given set of students to an existing curated group
    # @param students [Array<User>]
    # @param group [CuratedGroup]
    def selector_add_students_to_group(students, group)
      select_students_to_add students
      select_group_and_add(students, group)
    end

    # Adds a given set of students to a new curated group, which is created as part of the process
    # @param students [Array<User>]
    # @param group [CuratedGroup]
    def selector_add_students_to_new_group(students, group)
      select_students_to_add students
      selector_create_new_group(students, group)
    end

    # Adds all the students on a page to a curated group
    # @param group [CuratedGroup]
    def selector_add_all_students_to_group(group)
      wait_until(Utils.short_wait) { add_individual_to_curated_checkbox_elements.any? &:visible? }
      wait_for_update_and_click add_all_to_curated_checkbox_element
      logger.debug "There are #{add_individual_to_curated_checkbox_elements.length} individual checkboxes"
      students = add_individual_to_curated_checkbox_elements.map { |el| User.new({uid: el.attribute('id').split('-')[1]}) }
      select_group_and_add(students, group)
    end

    ### FILTERED COHORTS ###

    link(:create_filtered_cohort_link, id: 'sidebar-filtered-cohort-create')
    link(:view_everyone_cohorts_link, id: 'sidebar-filtered-cohorts-all')
    link(:team_list_link, id: 'sidebar-teams-link')
    link(:intensive_cohort_link, text: 'Intensive Students')
    link(:inactive_cohort_link, text: 'Inactive Students')
    link(:my_students_link, text: 'My Students')
    elements(:filtered_cohort_link, :link, xpath: '//div[@data-ng-repeat="cohort in myCohorts"]//a')
    div(:dupe_filtered_name_msg, xpath: '//div[text()="You have an existing filtered cohort with this name. Please choose a different name."]')

    # Clicks the button to create a new custom cohort
    def click_sidebar_create_filtered
      wait_for_load_and_click create_filtered_cohort_link_element
      wait_for_title 'Create a Filtered Cohort'
      sleep 3
    end

    # Clicks the link for the Teams List page
    def click_teams_list
      wait_for_load_and_click team_list_link_element
      wait_for_title 'Teams'
    end

    # Clicks the link for the Intensive cohort
    def click_intensive_cohort
      wait_for_load_and_click intensive_cohort_link_element
      wait_for_title 'Intensive'
    end

    # Clicks the link for the Inactive cohort
    def click_inactive_cohort
      wait_for_load_and_click inactive_cohort_link_element
      wait_for_title 'Inactive'
    end

    # Clicks the button to view all custom cohorts
    def click_view_everyone_cohorts
      sleep 2
      wait_for_load_and_click view_everyone_cohorts_link_element
      wait_for_title 'Filtered Cohorts All'
    end

    # Clicks the sidebar link to a filtered cohort
    # @param cohort [FilteredCohort]
    def click_sidebar_filtered_link(cohort)
      link = filtered_cohort_link_elements.find(&:text) == cohort.name
      wait_for_update_and_click link
    end

    ### USER SEARCH ###

    text_area(:search_input, id: 'search-students-input')

    # Searches for a string using the sidebar search input
    # @param string [String]
    def search(string)
      logger.info "Searching for '#{string}'"
      sleep 1
      search_input_element.when_visible Utils.short_wait
      self.search_input = string
      search_input_element.send_keys :enter
      wait_for_spinner
    end

    ### LIST VIEWS  - PAGINATION ###

    elements(:page_list_item, :list_item, xpath: '//li[contains(@ng-repeat,"page in pages")]')
    elements(:page_link, :link, xpath: '//a[contains(@ng-click, "selectPage")]')
    elements(:page_ellipsis_link, :link, xpath: '//a[contains(@ng-click, "selectPage")][text()="..."]')
    elements(:results_page_link, :class => 'pagination-page')

    # Returns the page link element for a given page number
    # @param number [Integer]
    # @return [PageObject::Elements::Link]
    def list_view_page_link(number)
      link_element(xpath: "//a[contains(@ng-click, 'selectPage')][text()='#{number}']")
    end

    # Returns the number of list view pages shown
    # @return [Integer]
    def list_view_page_count
      results_page_link_elements.any? ? results_page_link_elements.last.text.to_i : 1
    end

    # Returns the current page in list view
    # @return [Integer]
    def list_view_current_page
      if page_list_item_elements.any?
        page = page_list_item_elements.find { |el| el.attribute('class').include? 'active' }
        page.text.to_i
      else
        1
      end
    end

    # Checks whether a given page is the one currently shown in list view
    # @param number [Integer]
    # @return [boolean]
    def list_view_page_selected?(number)
      if number > 1
        wait_until(Utils.short_wait) { page_list_item_elements.any? }
        logger.debug "The page numbers visible are #{page_list_item_elements.map &:text}"
        el = page_list_item_elements.find { |el| el.text == number.to_s }
        el.attribute('class').include? 'active'
      else
        page_list_item_elements.empty?
      end
    end

    # Clicks a given page number and waits for student rows to appear
    # @param number [Integer]
    def click_list_view_page(number)
      logger.debug "Clicking page #{number}"
      list_view_page_link(number).exists? ?
          (wait_for_update_and_click list_view_page_link(number)) :
          (wait_for_update_and_click page_ellipsis_link_elements.last)
      sleep 1
      wait_until(Utils.medium_wait) { player_link_elements.any? }
    end

    ### LIST VIEWS - SETS OF USERS ###

    elements(:player_link, :link, xpath: '//div[contains(@class,"list-item")]//a')
    elements(:player_name, :h3, xpath: '//div[contains(@class,"list-item")]//h3')
    elements(:player_sid, :div, xpath: '//div[contains(@class,"list-item")]//div[contains(@class, "student-sid")]')

    # Waits for list view results to load
    def wait_for_student_list
      begin
        start_time = Time.now
        wait_until(Utils.medium_wait) { list_view_sids.any? }
        logger.debug "Took #{Time.now - start_time} seconds for users to appear"
        sleep 1
      rescue
        logger.warn 'There are no students listed.'
      end
    end

    # Returns all the names shown on list view
    # @return [Array<String>]
    def list_view_names
      wait_until(Utils.medium_wait) { player_link_elements.any? }
      player_name_elements.map &:text
    end

    # Returns all the SIDs shown on list view
    # @return [Array<String>]
    def list_view_sids
      wait_until(Utils.medium_wait) { player_link_elements.any? }
      sleep Utils.click_wait
      player_sid_elements.map { |el| el.text.gsub(/(INACTIVE)/, '').gsub(/(WAITLISTED)/, '').strip }
    end

    # Returns all the UIDs shown on list view
    # @return [Array<String>]
    def list_view_uids
      player_link_elements.map { |el| el.attribute 'id' }
    end

    # Returns the sequence of SIDs that are actually present following a search and/or sort
    # @param filtered_cohort [FilteredCohort]
    # @return [Array<String>]
    def visible_sids(filtered_cohort = nil)
      wait_for_student_list unless (filtered_cohort && filtered_cohort.member_count.zero?)
      visible_sids = []
      sleep 2
      page_count = list_view_page_count
      page = 1
      if page_count == 1
        logger.debug 'There is 1 page'
        visible_sids << list_view_sids
      else
        logger.debug "There are #{page_count} pages"
        visible_sids << list_view_sids
        (page_count - 1).times do
          start_time = Time.now
          page += 1
          click_list_view_page page
          logger.warn "Page #{page} took #{Time.now - start_time} seconds to load" unless page == 1
          visible_sids << list_view_sids
        end
      end
      visible_sids.flatten
    end

    ### LIST VIEWS - INDIVIDUAL USERS ###

    # Returns the XPath for a user
    # @param user [User]
    # @return [String]
    def list_view_user_xpath(user)
      "//div[contains(@class,\"list-group-item\")][contains(.,\"#{user.sis_id}\")]"
    end

    # Returns the level displayed for a user
    # @param user [User]
    # @return [String]
    def list_view_user_level(user)
      el = span_element(xpath: "#{list_view_user_xpath user}//*[@data-ng-bind='student.level']")
      el.text if el.exists?
    end

    # Returns the major(s) displayed for a user
    # @param driver [Selenium::WebDriver]
    # @param user [User]
    # @return [Array<String>]
    def list_view_user_majors(driver, user)
      els = driver.find_elements(xpath: "#{list_view_user_xpath user}//div[@data-ng-bind='major']")
      els.map &:text if els.any?
    end

    # Returns the sport(s) displayed for a user
    # @param driver [Selenium::WebDriver]
    # @param user [User]
    # @return [Array<String>]
    def list_view_user_sports(driver, user)
      els = driver.find_elements(xpath: "#{list_view_user_xpath user}//div[@data-ng-bind='membership.groupName']")
      els.map &:text if els.any?
    end

    # Clicks the link for a given student
    # @param student [BOACUser]
    def click_student_link(student)
      logger.info "Clicking the link for UID #{student.uid}"
      wait_for_load_and_click link_element(xpath: "//a[@id=\"#{student.uid}\"]")
      student_name_heading_element.when_visible Utils.medium_wait
    end

    # Verifies that SIDs are present in the expected sequence. If an SID is not at the expected index, then reports
    # what SID was there instead. If there are any mismatches, will throw an error.
    # @param expected_sids [Array<String>]
    # @param visible_sids [Array<String>]
    def verify_list_view_sorting(expected_sids, visible_sids)
      # Only compare sort order for SIDs that are both expected and visible
      unless expected_sids.sort == visible_sids.sort
        expected_sids.keep_if { |e| visible_sids.include? e }
        visible_sids.keep_if { |v| expected_sids.include? v }
      end

      # Collect any mismatches
      sorting_errors = []
      visible_sids.each do |v|
        e = expected_sids[visible_sids.index v]
        sorting_errors << "Expected #{e}, got #{v}" unless v == e
      end
      wait_until(0.5, "Mismatches: #{sorting_errors}") { sorting_errors.empty? }
    end

  end
end
