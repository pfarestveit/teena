require_relative '../../util/spec_helper'

module Page

  module BOACPages

    class CohortPage

      include PageObject
      include Logging
      include Page
      include BOACPages

      # LIST VIEW

      elements(:player_link, :link, class: 'cohort-member-list-item')
      elements(:player_name, :h3, class: 'cohort-member-name')
      elements(:player_sid, :div, class: 'cohort-member-sid')
      elements(:page_link, :link, xpath: '//a[contains(@ng-click, "selectPage")]')

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

      # Returns the XPath for a user link at a given node
      # @param node [Integer]
      # @return [String]
      def list_view_user_xpath(node)
        "//a[contains(@class, 'cohort-member-list-item')][#{node}]"
      end

      # Returns the level displayed for a user at a given list view node
      # @param driver [Selenium::WebDriver]
      # @param node [Integer]
      # @return [String]
      def list_view_user_level(driver, node)
        el = driver.find_element(xpath: "#{list_view_user_xpath node}//div[@data-ng-bind='row.level']")
        el && el.text
      end

      # Returns the cumulative GPA displayed for a user at a given list view node
      # @param driver [Selenium::WebDriver]
      # @param node [Integer]
      # @return [String]
      def list_view_user_gpa(driver, node)
        el = driver.find_element(xpath: "#{list_view_user_xpath node}//div[contains(@data-ng-bind,'row.cumulativeGPA')]")
        el && (el.text == '--' ? '0' : el.text)
      end

      # Returns the cumulative units displayed for a user at a given list view node
      # @param driver [Selenium::WebDriver]
      # @param node [Integer]
      # @return [String]
      def list_view_user_units(driver, node)
        el = driver.find_element(xpath: "#{list_view_user_xpath node}//div[contains(@data-ng-bind,'row.cumulativeUnits')]")
        el && (el.text == '--' ? '0' : el.text)
      end

      # Returns the page link element for a given page number
      # @param number [Integer]
      # @return [PageObject::Elements::Link]
      def list_view_page_link(number)
        page_link_elements.find { |el| el.text == "#{number}" }
      end

      # Clicks the link for a given player
      # @param player [User]
      def click_player_link(player)
        logger.info "Clicking the link for UID #{player.uid}"
        wait_for_load_and_click link_element(xpath: "//a[contains(.,\"#{player.sis_id}\")]")
        h1_element(xpath: '//h1[@data-ng-bind="student.sisProfile.primaryName"]').when_visible Utils.medium_wait
      end

      # CUSTOM COHORTS - Search

      button(:teams_filter_button, id: 'search-filter-teams')
      button(:search_button, id: 'execute-search')
      elements(:results_page_link, class: 'pagination-page')
      elements(:squad_option, :checkbox, xpath: '//input[contains(@id,"search-option-team")]')
      # TODO - the 'no results' element
      div(:no_results, id: 'no-results')

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
        text_area_element(id: "search-option-team-#{squad.code}")
      end

      # Waits for a search to complete, returning either a set of results or 'no results'
      def wait_for_search_results
        begin
          # TODO - no results element
          no_results_element.when_visible Utils.short_wait
        rescue
          wait_until(Utils.medium_wait) { player_link_elements.any? }
        end
      end

      # Executes a custom cohort search using given search criteria
      # @param criteria [CohortSearchCriteria]
      def perform_search(criteria)
        logger.info "Searching for squads '#{criteria.squads.map &:name}', levels '#{criteria.levels}', terms '#{criteria.terms}', GPA '#{criteria.gpa}', and units '#{criteria.units}'"
        wait_for_update_and_click teams_filter_button_element
        wait_until(1) { squad_option_elements.all? &:visible? }
        # Uncheck any options that are already checked from a previous search
        squad_option_elements.each { |o| o.click if o.attribute('class').include?('not-empty') }
        # Check all the options that apply to the new search
        criteria.squads.each { |s| wait_for_update_and_click squad_option_element(s) } if criteria.squads
        # TODO: the other filters when the UI is done
        wait_for_update_and_click search_button_element
        wait_for_search_results
      end

      # Returns the cohort data displayed for a user with a link at a given index
      # @param driver [Selenium::WebDriver]
      # @param link [PageObject::Elements::Link]
      # @param index [Integer]
      # @return [Hash]
      def visible_player_data(driver, link, index)
        node = index + 1
        {
            uid: link.attribute('data-ng-href').delete('/student'),
            level: list_view_user_level(driver, node),
            gpa: list_view_user_gpa(driver, node),
            units: list_view_user_units(driver, node)
        }
      end

      # Returns a collection of the cohort data displayed for all users in search results
      # @param driver [Selenium::WebDriver]
      # @return [Array<Hash>]
      def visible_search_results(driver)
        start_time = Time.now
        # TODO - account for no results
        visible_users_data = []
        logger.warn "Search took #{Time.now - start_time}"
        page_count = results_page_link_elements.length
        logger.debug "There are #{page_count} pages"
        if page_count.zero?
          player_link_elements.each { |link| visible_users_data << visible_player_data(driver, link, player_link_elements.index(link)) }
        else
          page_count.times do |page|
            start_time = Time.now
            page += 1
            unless page == 1
              logger.debug "Clicking page #{page}"
              wait_for_update_and_click list_view_page_link(page)
              sleep 1
            end
            wait_until(Utils.medium_wait) { player_link_elements.any? }
            logger.warn "Search took #{Time.now - start_time}" unless page == 1
            player_link_elements.each { |link| visible_users_data << visible_player_data(driver, link, player_link_elements.index(link)) }
          end
        end
        visible_users_data
      end

      # Verifies that the search results match expectations for given search criteria
      # @param driver [Selenium::WebDriver]
      # @param criteria [CohortSearchCriteria]
      def verify_search_results(driver, criteria)
        # TODO: the other search criteria when the UI is done
        visible_results = visible_search_results driver
        if criteria.squads
          expected_uids = (BOACUtils.get_squad_members(criteria.squads).map &:uid).sort
          visible_uids = (visible_results.map { |r| r[:uid] }).sort
          wait_until(1, "Expected #{expected_uids}, but got #{visible_uids}") { visible_uids == expected_uids }
        end
      end

      # CUSTOM COHORTS - Creation and Management

      button(:create_cohort_button, id: 'create-cohort-btn')
      text_area(:cohort_name_input, class: 'cohort-create-input-name')
      span(:title_required_msg, xpath: '//span[text()="Required"]')
      div(:title_dupe_msg, xpath: '//div[text()="You have a cohort with this name. Please choose a different name."]')
      button(:save_cohort_button, id: 'confirm-create-cohort-btn')
      button(:cancel_cohort_button, id: 'cancel-create-cohort-btn')
      div(:cohort_not_found_msg, xpath: '//div[contains(.,"Sorry, there was an error retrieving cohort data.")]')
      elements(:everyone_cohort_owner, :span, xpath: '//li[@data-ng-repeat="(uid, cohorts) in allCohorts"]/span')

      # Loads a cohort page by the cohort's ID
      # @param cohort [Cohort]
      def load_cohort(cohort)
        logger.info "Loading cohort '#{cohort.name}'"
        navigate_to "#{BOACUtils.base_url}/cohort/#{cohort.id}"
      end

      # Enters a cohort name and clicks the Save button
      # @param cohort [Cohort]
      def name_cohort(cohort)
        wait_for_element_and_type(cohort_name_input_element, cohort.name)
        wait_for_update_and_click save_cohort_button_element
      end

      # Clicks the Save Cohort button, enters a cohort name, and clicks the Save button
      # @param cohort [Cohort]
      def create_and_name_cohort(cohort)
        wait_for_update_and_click create_cohort_button_element
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
        cohort_name_input_element.when_not_visible Utils.short_wait
      end

      # Creates a new cohort
      # @param cohort [Cohort]
      def create_new_cohort(cohort)
        logger.info "Creating a new cohort named #{cohort.name}"
        click_create_new_cohort
        perform_search cohort.search_criteria
        create_and_name_cohort cohort
        wait_for_cohort cohort
      end

      # Creates a new cohort by editing the search criteria of an existing one
      # @param old_cohort [Cohort]
      # @param new_cohort [Cohort]
      def create_edited_cohort(old_cohort, new_cohort)
        load_cohort old_cohort
        perform_search new_cohort.search_criteria
        create_and_name_cohort new_cohort
        wait_for_cohort new_cohort
      end

      # Renames a cohort
      # @param cohort [Cohort]
      def rename_cohort(cohort)
        logger.info "Changing the name of cohort ID to #{cohort.name}"
        click_manage_my_cohorts
        wait_for_load_and_click button_element(xpath: "//span[text()='#{cohort.name}']/ancestor::div/following-sibling::div//button[text()='Rename']")
        name_cohort cohort
        wait_for_cohort cohort
      end

      # Deletes a cohort
      # @param cohort [Cohort]
      def delete_cohort(cohort)
        logger.info "Deleting a cohort named #{cohort.name}"
        click_manage_my_cohorts
        confirm(true) { wait_for_load_and_click button_element(xpath: "//span[text()='#{cohort.name}']/ancestor::div/following-sibling::div//button[text()='Delete']") }
        span_element(xpath: "//span[text()='#{cohort.name}']").when_not_present Utils.short_wait
      end

      # Returns all the cohorts displayed on the Everyone's Cohorts page
      # @param driver [Selenium::WebDriver]
      # @return [Array<Cohort>]
      def visible_everyone_cohorts(driver)
        click_view_everyone_cohorts
        wait_until(Utils.short_wait) { everyone_cohort_owner_elements.any? }
        uids = everyone_cohort_owner_elements.map { |o| o.text[13..-1] }
        cohorts = uids.each do |uid|
          names = driver.find_elements(xpath: "//li[@data-ng-repeat='(uid, cohorts) in allCohorts'][contains(.,'#{uid}')]//a")
          names.map { |n| Cohort.new({id: n.attribute('href').delete('/cohort/'), name: n.text, owner_uid: uid}) }
        end
        cohorts.flatten
      end

    end
  end
end
