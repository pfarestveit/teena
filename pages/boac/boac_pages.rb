require_relative '../../util/spec_helper'

module Page

  module BOACPages

    include PageObject
    include Logging
    include Page

    link(:home_link, text: 'Home')
    button(:header_dropdown, id: 'header-dropdown-under-name')
    link(:admin_link, text: 'Admin')
    link(:log_out_link, text: 'Log Out')
    link(:feedback_link, text: 'Feedback/Help')
    div(:spinner, class: 'loading-spinner-large')
    div(:modal, class: 'modal-content')
    h1(:student_name_heading, class: 'student-section-header')

    # Waits for an expected page title
    # @param page_title [String]
    def wait_for_title(page_title)
      start = Time.now
      wait_until(Utils.medium_wait) { title == "#{page_title} | BOAC" }
      logger.debug "Page title updated in #{Time.now - start} seconds"
    end

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

    # COHORTS - validation errors shared on various pages

    div(:dupe_curated_name_msg, xpath: '//div[text()="You have an existing curated cohort with this name. Please choose a different name."]')
    div(:dupe_filtered_name_msg, xpath: '//div[text()="You have an existing filtered cohort with this name. Please choose a different name."]')

    # CURATED COHORTS

    # 'Create' modal
    text_area(:curated_name_input, id: 'curated-cohort-create-input')
    button(:curated_save_button, id: 'curated-cohort-create-confirm-btn')
    button(:curated_cancel_button, id: 'curated-cohort-create-cancel-btn')

    # Sidebar
    link(:sidebar_create_curated_link, id: 'sidebar-curated-cohort-create')
    link(:sidebar_manage_curated_link, id: 'sidebar-curated-cohorts-manage')
    elements(:sidebar_curated_cohort_link, :link, xpath: '//div[@data-ng-repeat="cohort in myCuratedCohorts"]//a[contains(@class,"sidebar")]')

    # Clicks the sidebar button to manage the user's curated cohorts
    def sidebar_click_manage_curated
      wait_for_update_and_click sidebar_manage_curated_link_element
      wait_for_title 'Manage Curated Cohorts'
    end

    # Clicks the sidebar button to create a new curated cohort
    def sidebar_click_create_curated
      wait_for_load_and_click sidebar_create_curated_link_element
      curated_name_input_element.when_visible Utils.short_wait
    end

    # Enters a curated cohort name in the 'create' modal
    # @param cohort [CuratedCohort]
    def enter_curated_cohort_name(cohort)
      logger.debug "Entering curated cohort name '#{cohort.name}'"
      wait_for_element_and_type(curated_name_input_element, cohort.name)
    end

    # Enters a curated cohort name in the 'create' modal and clicks Save
    # @param cohort [CuratedCohort]
    def name_and_save_curated_cohort(cohort)
      enter_curated_cohort_name cohort
      wait_for_update_and_click curated_save_button_element
    end

    # Clicks Cancel in the curated cohort 'create' modal if it is open
    def cancel_curated_cohort
      curated_cancel_button
      modal_element.when_not_present Utils.short_wait
    rescue
      logger.warn 'No cancel button to click'
    end

    # Creates a curated cohort using the sidebar 'create' button and waits for the new cohort to appear in the sidebar
    # @param cohort [CuratedCohort]
    def sidebar_create_curated(cohort)
      logger.info "Using the sidebar link to create a curated cohort named '#{cohort.name}'"
      sidebar_click_create_curated
      name_and_save_curated_cohort cohort
      wait_for_sidebar_curated cohort
    end

    # Returns the names of all the curated cohorts in the sidebar
    # @return [Array<String>]
    def sidebar_curated_cohorts
      sidebar_curated_cohort_link_elements.map &:text
    end

    # Waits for a curated cohort's member count in the sidebar to match expectations
    # @param cohort [CuratedCohort]
    def wait_for_sidebar_curated_member_count(cohort)
      logger.debug "Waiting for curated cohort member count of #{cohort.members.length}"
      wait_until(Utils.short_wait) do
        el = span_element(xpath: "//div[@data-ng-repeat=\"cohort in myCuratedCohorts\"]//a[contains(.,\"#{cohort.name}\")][contains(@class,\"sidebar\")]/following-sibling::span")
        (el && el.text) == cohort.members.length.to_s
      end
    end

    # Waits for a curated cohort to appear in the sidebar with the right member count and obtains the cohort's ID
    # @param cohort [CuratedCohort]
    def wait_for_sidebar_curated(cohort)
      wait_until(Utils.short_wait) { sidebar_curated_cohorts.include? cohort.name }
      wait_for_sidebar_curated_member_count cohort
      BOACUtils.set_curated_cohort_id cohort
    end

    # Selector 'create' and 'add student(s)' UI shared by list view pages (filtered cohort page and class page)
    button(:selector_create_curated_button, id: 'curated-cohort-create')
    checkbox(:add_all_to_curated_checkbox, id: 'curated-cohort-checkbox-add-all')
    elements(:add_individual_to_curated_checkbox, :checkbox, xpath: '//input[@data-ng-model="student.selectedForCuratedCohort"]')
    button(:add_to_curated_button, id: 'add-to-curated-cohort-button')
    button(:added_to_curated_conf, id: 'added-to-curated-cohort-confirmation')

    # Selects the add-to-cohort checkboxes for a given set of students
    # @param students [Array<User>]
    def select_students_to_add(students)
      logger.info "Adding student UIDs: #{students.map &:uid}"
      students.each { |s| wait_for_update_and_click checkbox_element(id: "student-#{s.uid}-curated-cohort-checkbox") }
    end

    # Selects a curated cohort for adding users and waits for the 'added' confirmation.
    # @param students [Array<User>]
    # @param cohort [CuratedCohort]
    def select_curated_and_add(students, cohort)
      wait_for_update_and_click add_to_curated_button_element
      wait_for_update_and_click checkbox_element(xpath: "//span[text()='#{cohort.name}']/preceding-sibling::input")
      added_to_curated_conf_element.when_visible Utils.short_wait
      cohort.members << students
      cohort.members.flatten!
    end

    # Adds a given set of students to an existing curated cohort
    # @param students [Array<User>]
    # @param cohort [CuratedCohort]
    def selector_add_students_to_curated(students, cohort)
      select_students_to_add students
      select_curated_and_add(students, cohort)
    end

    # Adds a given set of students to a new curated cohort, which is created as part of the process
    # @param students [Array<User>]
    # @param cohort [CuratedCohort]
    def selector_add_students_to_new_curated(students, cohort)
      select_students_to_add students
      wait_for_update_and_click add_to_curated_button_element
      logger.debug 'Clicking curated cohort selector button to create a new cohort'
      wait_for_load_and_click selector_create_curated_button_element
      curated_name_input_element.when_visible Utils.short_wait
      name_and_save_curated_cohort cohort
      cohort.members << students
      cohort.members.flatten!
      added_to_curated_conf_element.when_visible Utils.short_wait
      wait_for_sidebar_curated cohort
    end

    # Adds all the students on a page to a curated cohort
    # @param cohort [CuratedCohort]
    def selector_add_all_students_to_curated(cohort)
      wait_until(Utils.short_wait) { add_individual_to_curated_checkbox_elements.any? &:visible? }
      wait_for_update_and_click add_all_to_curated_checkbox_element
      logger.debug "There are #{add_individual_to_curated_checkbox_elements.length} individual checkboxes"
      students = add_individual_to_curated_checkbox_elements.map { |el| User.new({uid: el.attribute('id').split('-')[1]}) }
      select_curated_and_add(students, cohort)
    end

    # FILTERED COHORTS

    link(:create_filtered_cohort_link, id: 'sidebar-filtered-cohort-create')
    link(:manage_filtered_cohorts_link, id: 'sidebar-filtered-cohorts-manage')
    link(:view_everyone_cohorts_link, id: 'sidebar-filtered-cohorts-all')
    link(:team_list_link, id: 'sidebar-teams-link')
    link(:intensive_cohort_link, text: 'Intensive Students')
    link(:inactive_cohort_link, text: 'Inactive Students')
    link(:my_students_link, text: 'My Students')
    elements(:filtered_cohort_link, :link, xpath: '//div[@data-ng-repeat="cohort in myCohorts"]//a')

    # Clicks the button to create a new custom cohort
    def click_sidebar_create_filtered
      wait_for_load_and_click create_filtered_cohort_link_element
      wait_for_title 'Filtered Cohort'
      sleep 3
    end

    # Clicks the button to manage the user's own filtered cohorts
    def click_sidebar_manage_filtered
      wait_for_load_and_click manage_filtered_cohorts_link_element
      wait_for_title 'Manage Filtered Cohorts'
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
      wait_for_load_and_click view_everyone_cohorts_link_element
      wait_for_title 'Filtered Cohorts All'
    end

    # Clicks the link for My Students
    def click_my_students
      wait_for_load_and_click my_students_link_element
      wait_for_title 'My Students'
    end

    # Clicks the sidebar link to a filtered cohort
    # @param cohort [FilteredCohort]
    def click_sidebar_filtered_link(cohort)
      link = filtered_cohort_link_elements.find(&:text) == cohort.name
      wait_for_update_and_click link
    end

    # USER SEARCH AND STUDENT LISTS (homepage and search results)

    text_area(:user_search_input, id: 'search-students-input')

    # Searches for a string using the sidebar search input
    # @param string [String]
    def enter_search_string(string)
      logger.info "Searching for '#{string}'"
      user_search_input_element.when_visible Utils.short_wait
      sleep Utils.click_wait
      self.user_search_input = string
      user_search_input_element.send_keys :enter
    end

    # Returns the data visible for a user on the search results page or in a filtered or curated cohort on the homepage. If a cohort,
    # then an XPath is required in order to find the user under the right cohort heading.
    # @param driver [Selenium::WebDriver]
    # @param user [User]
    # @param xpath [String]
    # @return [Hash]
    def user_row_data(driver, user, xpath = nil)
      row_xpath = "#{xpath}//div[contains(@data-ng-repeat,'student in students')][contains(.,'#{user.sis_id}')]"
      {
        :name => link_element(xpath: "#{row_xpath}//a").text,
        :sid => span_element(xpath: "#{row_xpath}//span[@data-ng-bind='student.sid']").text,
        :majors => driver.find_elements(xpath: "#{row_xpath}//span[@data-ng-repeat='major in student.majors']").map(&:text),
        :units_in_progress => div_element(xpath: "#{row_xpath}//div[contains(@data-ng-bind,'student.term.enrolledUnits')]").text,
        :cumulative_units => div_element(xpath: "#{row_xpath}//div[contains(@data-ng-bind,'student.cumulativeUnits')]").text,
        :gpa => div_element(xpath: "#{row_xpath}//div[contains(@data-ng-bind, 'student.cumulativeGPA')]").text,
        :alert_count => div_element(xpath: "#{row_xpath}//div[contains(@class,'home-issues-pill')]").text
      }
    end

    button(:list_view_button, xpath: '//button[contains(.,"List")]')
    button(:matrix_view_button, xpath: '//button[contains(.,"Matrix")]')

    # Clicks the list view button
    def click_list_view
      logger.info 'Switching to list view'
      wait_for_load_and_click list_view_button_element
    end

    # Clicks the matrix view button
    def click_matrix_view
      logger.info 'Switching to matrix view'
      wait_for_load_and_click matrix_view_button_element
    end

    # LIST VIEW PAGINATION

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

    # DATA FOR ALL USERS PRESENT

    elements(:player_link, :link, xpath: '//div[contains(@data-ng-repeat,"student in cohort.students")]//a')
    elements(:player_name, :h3, xpath: '//div[contains(@data-ng-repeat,"student in cohort.students")]//h3')
    elements(:player_sid, :div, xpath: '//div[contains(@data-ng-repeat,"student in cohort.students")]//div[contains(@class, "student-sid")]')

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
      player_sid_elements.map { |el| el.text.gsub(/(INACTIVE)/, '').strip }
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
      page_count = results_page_link_elements.any? ? results_page_link_elements.last.text.to_i : 1
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
          logger.debug "Clicking page #{page}"
          list_view_page_link(page).exists? ?
              (wait_for_update_and_click list_view_page_link(page)) :
              (wait_for_update_and_click page_ellipsis_link_elements.last)
          sleep 1
          wait_until(Utils.medium_wait) { player_link_elements.any? }
          logger.warn "Page #{page} took #{Time.now - start_time} seconds to load" unless page == 1
          visible_sids << list_view_sids
        end
      end
      visible_sids.flatten
    end

    # DATA FOR A SINGLE USER

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
      el && el.text
    end

    # Returns the major(s) displayed for a user
    # @param driver [Selenium::WebDriver]
    # @param user [User]
    # @return [Array<String>]
    def list_view_user_majors(driver, user)
      els = driver.find_elements(xpath: "#{list_view_user_xpath user}//div[@data-ng-bind='major']")
      els && (els.map &:text)
    end

    # Returns the sport(s) displayed for a user
    # @param driver [Selenium::WebDriver]
    # @param user [User]
    # @return [Array<String>]
    def list_view_user_sports(driver, user)
      els = driver.find_elements(xpath: "#{list_view_user_xpath user}//div[@data-ng-bind='membership.groupName']")
      els && (els.map &:text)
    end

    # Clicks the link for a given player
    # @param player [User]
    def click_player_link(player)
      logger.info "Clicking the link for UID #{player.uid}"
      wait_for_load_and_click link_element(xpath: "//a[@id=\"#{player.uid}\"]")
      student_name_heading_element.when_visible Utils.medium_wait
    end

  end
end
