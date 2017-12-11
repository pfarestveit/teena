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

      # CUSTOM COHORTS

      button(:teams_filter_button, id: 'search-filter-teams')
      button(:search_button, id: 'header-sign-in')
      button(:create_cohort_button, id: 'create-cohort-btn')
      elements(:results_page_link, class: 'pagination-page')

      # Returns the heading for a given cohort page
      # @param cohort [Cohort]
      # @return [PageObject::Elements::Span]
      def cohort_heading(cohort)
        span_element(xpath: "//h1/span[text()='#{cohort.name}']")
      end

      # Returns the option for a given squad
      # @param squad [Squad]
      # @return [PageObject::Elements::Option]
      def squad_option_element(squad)
        text_area_element(id: "search-option-team-#{squad.code}")
      end

      # Executes a custom cohort search using given search criteria
      # @param criteria [CohortSearchCriteria]
      def perform_search(criteria)
        logger.info "Searching for squads '#{criteria.squads.map &:name}', levels '#{criteria.levels}', terms '#{criteria.terms}', GPA '#{criteria.gpa}', and units '#{criteria.units}'"
        if criteria.squads
          wait_for_update_and_click teams_filter_button_element
          criteria.squads.each { |s| wait_for_update_and_click squad_option_element(s) }
        end
        # TODO: the other filters when the UI is done
        wait_for_update_and_click search_button_element
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
        # TODO - account for no results
        visible_users_data = []
        wait_until(Utils.medium_wait) { player_link_elements.any? }
        page_count = results_page_link_elements.length
        logger.debug "There are #{page_count} pages"
        if page_count.zero?
          player_link_elements.each { |link| visible_users_data << visible_player_data(driver, link, player_link_elements.index(link)) }
        else
          page_count.times do |page|
            page += 1
            unless page == 1
              logger.debug "Clicking page #{page}"
              wait_for_update_and_click list_view_page_link(page) unless page == 1
              sleep 1
            end
            wait_until(Utils.short_wait) { player_link_elements.any? }
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

    end
  end
end
