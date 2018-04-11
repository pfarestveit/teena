require_relative '../../util/spec_helper'

module Page

  module BOACPages

    class CohortListViewPage < CohortPage

      include Logging
      include PageObject
      include Page
      include BOACPages

      # LIST VIEW

      elements(:player_link, :link, xpath: '//ul[@id="cohort-members-list"]//a')
      elements(:player_name, :h3, xpath: '//ul[@id="cohort-members-list"]//h3')
      elements(:player_sid, :div, xpath: '//ul[@id="cohort-members-list"]//div[contains(@class, "student-sid")]')
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
        player_sid_elements.map { |el| el.text.gsub(/(INACTIVE)/, '').strip }
      end

      # Returns the XPath for a user
      # @param user [User]
      # @return [String]
      def list_view_user_xpath(user)
        "//ul[@id=\"cohort-members-list\"]/div[contains(.,\"#{user.sis_id}\")]"
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
        el = driver.find_element(xpath: "#{list_view_user_xpath user}//div[contains(@data-ng-bind,'student.term.enrolledUnits')]")
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
        driver.find_element(xpath: "#{list_view_user_xpath user}//div[contains(@class,'student-course-activity-row')][contains(.,'#{class_code}')]//*[local-name()='svg']")
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
        logger.info "Clicking the link for UID #{player.uid}"
        wait_for_load_and_click link_element(xpath: "//a[@id=\"#{player.uid}\"]")
        student_name_heading_element.when_visible Utils.medium_wait
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

      # Returns the sequence of SIDs that should be present when search results are sorted by first name
      # @param user_data [Array<Hash>]
      # @param search_criteria [CohortSearchCriteria]
      # @return [Array<String>]
      def expected_results_by_first_name(user_data, search_criteria)
        expected_users = expected_search_results(user_data, search_criteria)
        sorted_users = expected_users.sort_by { |u| [u[:first_name_sortable], u[:last_name_sortable], u[:sid]] }
        sorted_users.map { |u| u[:sid] }
      end

      # Returns the sequence of SIDs that should be present when search results are sorted by last name
      # @param user_data [Array<Hash>]
      # @param search_criteria [CohortSearchCriteria]
      # @return [Array<String>]
      def expected_results_by_last_name(user_data, search_criteria)
        expected_users = expected_search_results(user_data, search_criteria)
        sorted_users = expected_users.sort_by { |u| [u[:last_name_sortable], u[:first_name_sortable], u[:sid]] }
        sorted_users.map { |u| u[:sid] }
      end

      # Returns the sequence of SIDs that should be present when search results are sorted by team
      # @param user_data [Array<Hash>]
      # @param search_criteria [CohortSearchCriteria]
      # @return [Array<String>]
      def expected_results_by_team(user_data, search_criteria)
        expected_users = expected_search_results(user_data, search_criteria)
        sorted_users = expected_users.sort_by { |u| [u[:squad_names].sort.first.gsub(/\W/, ''), u[:last_name_sortable], u[:first_name_sortable]] }
        sorted_users.map { |u| u[:sid] }
      end

      # Returns the sequence of SIDs that should be present when search results are sorted by GPA
      # @param user_data [Array<Hash>]
      # @param search_criteria [CohortSearchCriteria]
      # @return [Array<String>]
      def expected_results_by_gpa(user_data, search_criteria)
        expected_users = expected_search_results(user_data, search_criteria)
        sorted_users = expected_users.sort_by { |u| [u[:gpa].to_f, u[:last_name_sortable], u[:first_name_sortable]] }
        sorted_users.map { |u| u[:sid] }
      end

      # Returns the sequence of SIDs that should be present when search results are sorted by level
      # @param user_data [Array<Hash>]
      # @param search_criteria [CohortSearchCriteria]
      # @return [Array<String>]
      def expected_results_by_level(user_data, search_criteria)
        expected_users = expected_search_results(user_data, search_criteria)
        # Sort first by the secondary sort order
        users_by_first_name = expected_users.sort_by { |u| [u[:last_name_sortable], u[:first_name_sortable]] }
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
        sorted_users = expected_users.sort_by { |u| [u[:majors].sort.first.downcase, u[:last_name_sortable], u[:first_name_sortable]] }
        sorted_users.map { |u| u[:sid] }
      end

      # Returns the sequence of SIDs that should be present when search results are sorted by cumulative units
      # @param user_data [Array<Hash>]
      # @param search_criteria [CohortSearchCriteria]
      # @return [Array<String>]
      def expected_results_by_units(user_data, search_criteria)
        expected_users = expected_search_results(user_data, search_criteria)
        sorted_users = expected_users.sort_by { |u| [u[:units].to_f, u[:last_name_sortable], u[:first_name_sortable]] }
        sorted_users.map { |u| u[:sid] }
      end

      # Returns the sequence of SIDs that are actually present following a search and/or sort
      # @return [Array<String>]
      def visible_search_results
        wait_for_search_results
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

    end
  end
end
