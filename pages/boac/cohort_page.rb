require_relative '../../util/spec_helper'

module Page

  module BOACPages

    class CohortPage

      include PageObject
      include Logging
      include Page
      include BOACPages

      button(:list_view_button, xpath: '//button[contains(.,"List")]')
      button(:matrix_view_button, xpath: '//button[contains(.,"Matrix")]')
      div(:spinner, class: 'loading-spinner-large')
      h1(:results, xpath: '//h1')

      # Navigates directly to a team page
      # @param team [Team]
      def load_team_page(team)
        logger.info "Loading cohort page for team #{team.name}"
        navigate_to "#{BOACUtils.base_url}/cohort?c=#{team.code}"
      end

      # Clicks the list view button
      def click_list_view
        wait_for_load_and_click list_view_button_element
      end

      # Clicks the matrix view button
      def click_matrix_view
        logger.info 'Switching to matrix view'
        wait_for_update_and_click matrix_view_button_element
        div_element(id: 'scatterplot').when_present Utils.medium_wait
      end

      # Returns the search results count in the page heading
      # @return [Integer]
      def results_count
        sleep 1
        results.split(' ')[0].to_i
      end

      # LIST VIEW

      elements(:player_link, :link, xpath: '//ul[@id="cohort-members-list"]/a')
      elements(:player_name, :h3, xpath: '//ul[@id="cohort-members-list"]//h3')
      elements(:player_sid, :div, xpath: '//ul[@id="cohort-members-list"]//div[@data-ng-bind="student.sid"]')
      elements(:page_list_item, :list_item, xpath: '//li[contains(@ng-repeat,"page in pages")]')
      elements(:page_link, :link, xpath: '//a[contains(@ng-click, "selectPage")]')

      # Waits for the number of players on the page to match expectations, and logs an error if it times out
      # @param cohort_size [Integer]
      def wait_for_page_load(cohort_size)
        wait_until(Utils.medium_wait) { player_link_elements.length == cohort_size } rescue logger.error("Expected #{cohort_size} members, but got #{player_link_elements.length}")
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
        player_sid_elements.map &:text
      end

      # Returns the XPath for a user
      # @param user [User]
      # @return [String]
      def list_view_user_xpath(user)
        "//a[contains(@class, 'cohort-member-list-item')][contains(.,'#{user.sis_id}')]"
      end

      # Returns the level displayed for a user
      # @param driver [Selenium::WebDriver]
      # @param user [User]
      # @return [String]
      def list_view_user_level(driver, user)
        el = driver.find_element(xpath: "#{list_view_user_xpath user}//div[@data-ng-bind='student.level']")
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

      # Returns the cumulative GPA displayed for a user
      # @param driver [Selenium::WebDriver]
      # @param user [User]
      # @return [String]
      def list_view_user_gpa(driver, user)
        el = driver.find_element(xpath: "#{list_view_user_xpath user}//div[contains(@data-ng-bind,'student.cumulativeGPA')]")
        el && el.text
      end

      # Returns the in-progress units displayed for a user
      # @param driver [Selenium::WebDriver]
      # @param user [User]
      # @return [String]
      def list_view_user_units_in_prog(driver, user)
        el = driver.find_element(xpath: "#{list_view_user_xpath user}//div[contains(@data-ng-bind,'student.currentTerm.enrolledUnits')]")
        el && el.text
      end

      # Returns the cumulative units displayed for a user
      # @param driver [Selenium::WebDriver]
      # @param user [User]
      # @return [String]
      def list_view_user_units(driver, user)
        el = driver.find_element(xpath: "#{list_view_user_xpath user}//div[contains(@data-ng-bind,'student.cumulativeUnits')]")
        el && (el.text == '--' ? '0' : el.text)
      end

      # Returns the classes displayed for a user
      # @param driver [Selenium::WebDriver]
      # @param user [User]
      # @return [Array<String>]
      def list_view_user_classes(driver, user)
        els = driver.find_elements(xpath: "#{list_view_user_xpath user}//div[@data-ng-bind='enrollment.displayName']")
        els && (els.map &:text)
      end

      # Returns a user's SIS data visible on the cohort page
      # @param [Selenium::WebDriver]
      # @param user [User]
      # @return [Hash]
      def visible_sis_data(driver, user)
        wait_until(Utils.medium_wait) { player_link_elements.any? }
        sleep 1
        {
            :level => list_view_user_level(driver, user),
            :majors => list_view_user_majors(driver, user),
            :gpa => list_view_user_gpa(driver, user),
            :units_in_progress => list_view_user_units_in_prog(driver, user),
            :units_cumulative => list_view_user_units(driver, user),
            :classes => list_view_user_classes(driver, user)
        }
      end

      # Returns the boxplot element for a user's site
      # @param driver [Selenium::WebDriver]
      # @param user [User]
      # @param class_code [String]
      # @return [Selenium::WebDriver::Element]
      def list_view_class_boxplot(driver, user, class_code)
        driver.find_element(xpath: "#{list_view_user_xpath user}//div[contains(@class,'cohort-member-course-activity-row')][contains(.,'#{class_code}')]//*[local-name()='svg']")
      end

      # Returns the page link element for a given page number
      # @param number [Integer]
      # @return [PageObject::Elements::Link]
      def list_view_page_link(number)
        page_link_elements.find { |el| el.text == "#{number}" }
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
          el = page_list_item_elements[number - 1]
          el.attribute('class').include? 'active'
        else
          page_list_item_elements.empty?
        end
      end

      # Clicks the link for a given player
      # @param player [User]
      def click_player_link(player)
        wait_for_load_and_click link_element(xpath: "//a[contains(.,\"#{player.sis_id}\")]")
        h1_element(class: 'student-profile-header-name').when_visible Utils.medium_wait
        player.uid = current_url.gsub("#{BOACUtils.base_url}/student/", '')
        logger.info "Viewing the student page for UID #{player.uid}"
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
        sort_by 'Units'
      end

      # CUSTOM COHORTS - Search

      button(:teams_filter_button, id: 'search-filter-teams')
      elements(:squad_option, :checkbox, xpath: '//input[contains(@id,"search-option-team")]')
      button(:level_filter_button, id: 'search-filter-level')
      elements(:level_option, :checkbox, xpath: '//input[contains(@id, "search-option-level")]')
      button(:major_filter_button, id: 'search-filter-majors')
      elements(:major_option, :checkbox, xpath: '//input[contains(@id, "search-option-major")]')
      button(:gpa_range_filter_button, id: 'search-filter-gpa-ranges')
      elements(:gpa_range_option, :checkbox, xpath: '//input[contains(@id, "search-option-gpa-range")]')

      button(:search_button, id: 'execute-search')
      elements(:results_page_link, class: 'pagination-page')

      # Returns the heading for a given cohort page
      # @param cohort [Cohort]
      # @return [PageObject::Elements::Span]
      def cohort_heading(cohort)
        span_element(xpath: "//h1/span[text()=\"#{cohort.name}\"]")
      end

      # Returns the option for a given squad
      # @param squad [Squad]
      # @return [PageObject::Elements::Option]
      def squad_option_element(squad)
        checkbox_element(xpath: "//input[@id='search-option-team-#{squad.code}']")
      end

      # Returns the option for a given level
      # @param level [String]
      # @return [PageObject::Elements::Option]
      def levels_option_element(level)
        checkbox_element(id: "search-option-level-#{level}")
      end

      # Returns the option for a given major
      # @param major [String]
      # @return [PageObject::Elements::Option]
      def majors_option_element(major)
        checkbox_element(id: "search-option-major-#{major}")
      end

      # Returns the option for a given GPA range
      # @param gpa_range [String]
      # @return [PageObject::Elements::Option]
      def gpa_range_option_element(gpa_range)
        checkbox_element(xpath: "//input[@aria-label='#{gpa_range}']")
      end

      # Verifies that a set of cohort search criteria are currently selected
      # @param search_criteria [CohortSearchCriteria]
      # @return [boolean]
      def search_criteria_selected?(search_criteria)
        wait_until(Utils.short_wait) { squad_option_elements.any? }
        search_criteria.squads.each do |s|
          wait_until(Utils.short_wait, "Squad #{s.name} is not selected") { squad_option_element(s).exists? && squad_option_element(s).attribute('class').include?('not-empty') }
        end if search_criteria.squads

        search_criteria.levels.each do |l|
          wait_until(Utils.short_wait, "Level #{l} is not selected") { levels_option_element(l).exists? && levels_option_element(l).attribute('class').include?('not-empty') }
        end if search_criteria.levels

        search_criteria.majors.each do |m|
          wait_until(Utils.short_wait, "Major #{m} is not selected") { majors_option_element(m).exists? && majors_option_element(m).attribute('class').include?('not-empty') }
        end if search_criteria.majors

        search_criteria.gpa_ranges.each do |g|
          wait_until(Utils.short_wait, "GPA range #{g} is not selected") { gpa_range_option_element(g).exists? && gpa_range_option_element(g).attribute('class').include?('not-empty') }
        end if search_criteria.gpa_ranges
        true
      end

      # Waits for a search to complete, returning either a set of results or 'no results'
      def wait_for_search_results
        sleep 1
        spinner_element.when_not_present Utils.medium_wait if spinner?
        results_element.when_present Utils.short_wait
      end

      # Checks a search filter option
      # @param element [PageObject::Elements::Option]
      def check_search_option(element)
        begin
          tries ||= 2
          element.click
          wait_until(1) { element.attribute('class').include?('not-empty') }
        rescue
          logger.debug 'Trying to check a search option again'
          (tries -= 1).zero? ? fail : retry
        end
      end

      # Executes a custom cohort search using given search criteria
      # @param criteria [CohortSearchCriteria]
      def perform_search(criteria)
        logger.info "Searching for squads '#{criteria.squads && (criteria.squads.map &:name)}', levels '#{criteria.levels}', majors '#{criteria.majors}', GPA ranges '#{criteria.gpa_ranges}'"
        sleep 2

        # Uncheck any options that are already checked from a previous search, then check those that apply to the current search
        unless squad_option_elements.all? &:visible?
          wait_for_update_and_click teams_filter_button_element
          wait_until(1) { squad_option_elements.all? &:visible? }
        end
        squad_option_elements.each { |o| o.click if o.attribute('class').include?('not-empty') }
        criteria.squads.each { |s| check_search_option squad_option_element(s) } if criteria.squads

        unless level_option_elements.all? &:visible?
          wait_for_update_and_click level_filter_button_element
          wait_until(1) { level_option_elements.all? &:visible? }
        end
        level_option_elements.each { |o| o.click if o.attribute('class').include?('not-empty') }
        criteria.levels.each { |l| check_search_option levels_option_element(l) } if criteria.levels

        unless major_option_elements.all? &:visible?
          wait_for_update_and_click major_filter_button_element
          wait_until(1) { major_option_elements.all? &:visible? }
        end
        major_option_elements.each { |o| o.click if o.attribute('class').include?('not-empty') }
        if criteria.majors
          criteria.majors.each do |m|
            # Majors are only shown if they apply to users, so the majors list will change over time. Avoid test failures if
            # the search criteria is out of sync with actual user majors.
            if majors_option_element(m).exists?
              check_search_option majors_option_element(m)
            else
              logger.warn "The major '#{m}' is not among the list of majors, removing from search criteria"
              criteria.majors.delete_if { |i| i == m }
            end
          end
        end

        unless gpa_range_option_elements.all? &:visible?
          wait_for_update_and_click gpa_range_filter_button_element
          wait_until(1) { gpa_range_option_elements.all? &:visible? }
        end
        gpa_range_option_elements.each { |o| o.click if o.attribute('class').include?('not-empty') }
        criteria.gpa_ranges.each { |g| check_search_option gpa_range_option_element(g) } if criteria.gpa_ranges

        # Execute search and log time search took to complete
        wait_for_update_and_click search_button_element
        start_time = Time.now
        wait_for_search_results
        logger.warn "Search took #{Time.now - start_time}"
      end

      # Filters an array of user data hashes according to search criteria and returns the users that should be present in the UI after
      # the search completes
      # @param user_data [Array<Hash>]
      # @param search_criteria [CohortSearchCriteria]
      # @return [Array<Hash>]
      def expected_search_results(user_data, search_criteria)
        matching_squad_users = search_criteria.squads ?
                                  (user_data.select { |u| (u[:squad_names] & (search_criteria.squads.map { |s| s.name })).any? }) : []
        matching_level_users = search_criteria.levels ?
                                  (user_data.select { |u| search_criteria.levels.include? u[:level] }) : []
        matching_major_users = search_criteria.majors ?
                                  (user_data.select { |u| (u[:majors] & search_criteria.majors).any? }) : []
        matching_gpa_range_users = []
        if search_criteria.gpa_ranges
         search_criteria.gpa_ranges.each do |range|
           array = range.include?('Below') ? %w(0 2.0) : range.delete(' ').split('-')
           matching_gpa_range_users << user_data.select do |u|
             (array[0].to_f <= u[:gpa].to_f) && ((array[1] == '4.00') ? (u[:gpa].to_f <= array[1].to_f.round(1)) : (u[:gpa].to_f < array[1].to_f.round(1)))
           end
         end
        end
        matching_users = [matching_squad_users, matching_level_users, matching_major_users, matching_gpa_range_users.flatten].delete_if { |a| a.empty? }
        matching_users.inject :'&'
      end

      # Returns the sequence of SIDs that should be present when search results are sorted by first name
      # @param user_data [Array<Hash>]
      # @param search_criteria [CohortSearchCriteria]
      # @return [Array<String>]
      def expected_results_by_first_name(user_data, search_criteria)
        expected_users = expected_search_results(user_data, search_criteria)
        sorted_users = expected_users.sort_by { |u| [u[:first_name_sortable], u[:last_name_sortable]] }
        sorted_users.map { |u| u[:sid] }
      end

      # Returns the sequence of SIDs that should be present when search results are sorted by last name
      # @param user_data [Array<Hash>]
      # @param search_criteria [CohortSearchCriteria]
      # @return [Array<String>]
      def expected_results_by_last_name(user_data, search_criteria)
        expected_users = expected_search_results(user_data, search_criteria)
        sorted_users = expected_users.sort_by { |u| [u[:last_name_sortable], u[:first_name_sortable]] }
        sorted_users.map { |u| u[:sid] }
      end

      # Returns the sequence of SIDs that should be present when search results are sorted by team
      # @param user_data [Array<Hash>]
      # @param search_criteria [CohortSearchCriteria]
      # @return [Array<String>]
      def expected_results_by_team(user_data, search_criteria)
        expected_users = expected_search_results(user_data, search_criteria)
        sorted_users = expected_users.sort_by { |u| [u[:squad_names].sort.first, u[:first_name_sortable]] }
        sorted_users.map { |u| u[:sid] }
      end

      # Returns the sequence of SIDs that should be present when search results are sorted by GPA
      # @param user_data [Array<Hash>]
      # @param search_criteria [CohortSearchCriteria]
      # @return [Array<String>]
      def expected_results_by_gpa(user_data, search_criteria)
        expected_users = expected_search_results(user_data, search_criteria)
        sorted_users = expected_users.sort_by { |u| [u[:gpa].to_f, u[:first_name_sortable]] }
        sorted_users.map { |u| u[:sid] }
      end

      # Returns the sequence of SIDs that should be present when search results are sorted by level
      # @param user_data [Array<Hash>]
      # @param search_criteria [CohortSearchCriteria]
      # @return [Array<String>]
      def expected_results_by_level(user_data, search_criteria)
        expected_users = expected_search_results(user_data, search_criteria)
        # Sort first by the secondary sort order
        users_by_first_name = expected_users.sort_by { |u| u[:first_name_sortable] }
        # Then arrange by the sort order for level
        users_by_level = []
        %w(Freshman Sophomore Junior Senior Graduate).each do |level|
          users_by_level << users_by_first_name.select do |u|
            u[:level] == level
          end
        end
        users_by_level.flatten.map { |u| u[:sid] }
      end

      # Returns the sequence of SIDs that should be present when search results are sorted by major
      # @param user_data [Array<Hash>]
      # @param search_criteria [CohortSearchCriteria]
      # @return [Array<String>]
      def expected_results_by_major(user_data, search_criteria)
        expected_users = expected_search_results(user_data, search_criteria)
        sorted_users = expected_users.sort_by { |u| [u[:majors].sort.first, u[:first_name_sortable]] }
        sorted_users.map { |u| u[:sid] }
      end

      # Returns the sequence of SIDs that should be present when search results are sorted by cumulative units
      # @param user_data [Array<Hash>]
      # @param search_criteria [CohortSearchCriteria]
      # @return [Array<String>]
      def expected_results_by_units(user_data, search_criteria)
        expected_users = expected_search_results(user_data, search_criteria)
        sorted_users = expected_users.sort_by { |u| [u[:units].to_f, u[:first_name_sortable]] }
        sorted_users.map { |u| u[:sid] }
      end

      # Returns the sequence of SIDs that are actually present following a search and/or sort
      # @return [Array<String>]
      def visible_search_results
        wait_until(Utils.medium_wait) { list_view_sids.any? }
        visible_sids = []
        page_count = results_page_link_elements.length
        if page_count.zero?
          logger.debug 'There is 1 page'
          visible_sids << list_view_sids
        else
          logger.debug "There are #{page_count} pages"
          page_count.times do |page|
            start_time = Time.now
            page += 1
            logger.debug "Clicking page #{page}"
            wait_for_update_and_click list_view_page_link(page)
            sleep 1
            wait_until(Utils.medium_wait) { player_link_elements.any? }
            logger.warn "Search took #{Time.now - start_time}" unless page == 1
            visible_sids << list_view_sids
          end
        end
        visible_sids.flatten
      end

      # CUSTOM COHORTS - Creation

      button(:save_cohort_button_one, id: 'create-cohort-btn')
      text_area(:cohort_name_input, class: 'cohort-create-input-name')
      span(:title_required_msg, xpath: '//span[text()="Required"]')
      div(:title_dupe_msg, xpath: '//div[text()="You have a cohort with this name. Please choose a different name."]')
      button(:save_cohort_button_two, id: 'confirm-create-cohort-btn')
      button(:cancel_cohort_button, id: 'cancel-create-cohort-btn')
      div(:cohort_not_found_msg, xpath: '//div[contains(.,"Sorry, there was an error retrieving cohort data.")]')
      elements(:everyone_cohort_owner, :span, xpath: '//li[@data-ng-repeat="(uid, cohorts) in allCohorts"]/span')

      # Loads a cohort page by the cohort's ID
      # @param cohort [Cohort]
      def load_cohort(cohort)
        logger.info "Loading cohort '#{cohort.name}'"
        navigate_to "#{BOACUtils.base_url}/cohort?c=#{cohort.id}"
      end

      # Clicks the button to save a new cohort, which triggers the name input modal
      def click_save_cohort_button_one
        wait_until(Utils.medium_wait) { save_cohort_button_one_element.enabled? }
        wait_for_update_and_click save_cohort_button_one_element
      end

      # Enters a cohort name and clicks the Save button
      # @param cohort [Cohort]
      def name_cohort(cohort)
        wait_for_element_and_type(cohort_name_input_element, cohort.name)
        wait_for_update_and_click save_cohort_button_two_element
      end

      # Clicks the Save Cohort button, enters a cohort name, and clicks the Save button
      # @param cohort [Cohort]
      def save_and_name_cohort(cohort)
        click_save_cohort_button_one
        name_cohort cohort
      end

      # Waits for a cohort page to load and obtains the cohort's ID
      # @param cohort [Cohort]
      # @return [Integer]
      def wait_for_cohort(cohort)
        cohort_heading(cohort).when_present Utils.medium_wait
        cohort.id = BOACUtils.get_custom_cohort_id cohort
      end

      # Clicks the Cancel button during cohort creation
      def cancel_cohort
        wait_for_update_and_click cancel_cohort_button_element
        cohort_name_input_element.when_not_visible Utils.short_wait rescue Selenium::WebDriver::Error::StaleElementReferenceError
      end

      # Creates a new cohort
      # @param cohort [Cohort]
      def search_and_create_new_cohort(cohort)
        logger.info "Creating a new cohort named #{cohort.name}"
        click_create_new_cohort
        perform_search cohort.search_criteria
        save_and_name_cohort cohort
        wait_for_cohort cohort
      end

      # Creates a new cohort by editing the search criteria of an existing one
      # @param old_cohort [Cohort]
      # @param new_cohort [Cohort]
      def search_and_create_edited_cohort(old_cohort, new_cohort)
        load_cohort old_cohort
        perform_search new_cohort.search_criteria
        save_and_name_cohort new_cohort
        wait_for_cohort new_cohort
      end

      # CUSTOM COHORTS - Management

      button(:save_rename_button, xpath: '//button[contains(@id,"cohort-save-btn")]')
      text_area(:rename_input, name: 'label')
      button(:confirm_delete_button, id: 'confirm-delete-cohort-btn')

      # Returns the element containing the cohort name on the Manage Cohorts page
      # @param cohort [Cohort]
      # @return [PageObject::Elements::Span]
      def cohort_on_manage_cohorts(cohort)
        span_element(xpath: "//span[text()='#{cohort.name}']")
      end

      # Returns the element containing the cohort rename button on the Manage Cohorts page
      # @param cohort [Cohort]
      # @return [PageObject::Elements::Button]
      def cohort_rename_button(cohort)
        button_element(xpath: "//span[text()='#{cohort.name}']/ancestor::div[contains(@class,'cohort-manage-label')]/following-sibling::div//button[contains(text(),'Rename')]")
      end

      # Returns the element containing the cohort delete button on the Manage Cohorts page
      # @param cohort [Cohort]
      # @return [PageObject::Elements::Button]
      def cohort_delete_button(cohort)
        button_element(xpath: "//span[text()='#{cohort.name}']/ancestor::div[contains(@class,'cohort-manage-label')]/following-sibling::div//button[contains(text(),'Delete')]")
      end

      # Renames a cohort
      # @param cohort [Cohort]
      # @param new_name [String]
      def rename_cohort(cohort, new_name)
        logger.info "Changing the name of cohort ID #{cohort.id} to #{new_name}"
        click_manage_my_cohorts
        wait_for_load_and_click cohort_rename_button(cohort)
        cohort.name = new_name
        rename_input_element.when_present Utils.short_wait
        wait_until(Utils.short_wait) { rename_input_element.enabled? }
        rename_input_element.clear
        rename_input_element.send_keys new_name
        wait_for_update_and_click save_rename_button_element
        cohort_on_manage_cohorts(cohort).when_present Utils.short_wait
      end

      # Deletes a cohort
      # @param cohort [Cohort]
      def delete_cohort(cohort)
        logger.info "Deleting a cohort named #{cohort.name}"
        click_manage_my_cohorts
        sleep 1
        wait_for_load_and_click cohort_delete_button(cohort)
        wait_for_update_and_click confirm_delete_button_element
        cohort_on_manage_cohorts(cohort).when_not_present Utils.short_wait
      end

      # Returns all the cohorts displayed on the Everyone's Cohorts page
      # @param driver [Selenium::WebDriver]
      # @return [Array<Cohort>]
      def visible_everyone_cohorts(driver)
        click_view_everyone_cohorts
        wait_until(Utils.short_wait) { everyone_cohort_owner_elements.any? }
        uids = everyone_cohort_owner_elements.map { |o| o.text[13..-1] }
        cohorts = uids.map do |uid|
          names = driver.find_elements(xpath: "//li[@data-ng-repeat='(uid, cohorts) in allCohorts'][contains(.,'#{uid}')]//a")
          names.map { |n| Cohort.new({id: n.attribute('data-ng-href').delete('/cohort/'), name: n.text, owner_uid: uid })}
        end
        cohorts.flatten
      end

    end
  end
end
