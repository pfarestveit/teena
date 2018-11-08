require_relative '../../util/spec_helper'

module Page
  module BOACPages
      module CohortPages

      include PageObject
      include Logging
      include Page
      include BOACPages

      h1(:results, xpath: '//h1')
      button(:confirm_delete_button, id: 'confirm-delete-btn')
      button(:cancel_delete_button, id: 'cancel-delete-btn')
      span(:no_access_msg, xpath: '//span[text()="You are unauthorized to access student data managed by other departments"]')

      # Returns the search results count in the page heading
      # @return [Integer]
      def results_count
        sleep 1
        results_element.when_visible Utils.short_wait
        results.split(' ')[0].to_i
      end

      # LIST VIEW - shared by filtered cohorts and curated cohorts

      # Returns a user's SIS data visible on the cohort page
      # @param [Selenium::WebDriver]
      # @param user [User]
      # @return [Hash]
      def visible_sis_data(driver, user)
        wait_until(Utils.medium_wait) { player_link_elements.any? }
        wait_until(Utils.short_wait) { list_view_user_level(user) }
        gpa_el = div_element(xpath: "#{list_view_user_xpath user}//span[contains(@data-ng-bind,'student.cumulativeGPA')]")
        term_units_el = div_element(xpath: "#{list_view_user_xpath user}//div[contains(@data-ng-bind,'student.term.enrolledUnits')]")
        cumul_units_el = div_element(xpath: "#{list_view_user_xpath user}//div[contains(@data-ng-bind,'student.cumulativeUnits')]")
        class_els = driver.find_elements(xpath: "#{list_view_user_xpath user}//div[@data-ng-bind='enrollment.displayName']")
        {
          :level => list_view_user_level(user),
          :majors => list_view_user_majors(driver, user),
          :gpa => (gpa_el.text if gpa_el.exists?),
          :term_units => (term_units_el.text if term_units_el.exists?),
          :units_cumulative => ((cumul_units_el.text == '--' ? '0' : cumul_units_el.text) if cumul_units_el.exists?),
          :classes => class_els.map(&:text)
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
  end
end
