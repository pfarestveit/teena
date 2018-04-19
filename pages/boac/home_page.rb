require_relative '../../util/spec_helper'

module Page

  module BOACPages

    class HomePage

      include PageObject
      include Logging
      include Page
      include BOACPages

      button(:sign_in, id: 'splash-sign-in')
      div(:sign_in_msg, xpath: '//div[text()="Please sign in."]')

      text_field(:dev_auth_uid_input, id: 'dev-auth-uid')
      text_field(:dev_auth_password_input, id: 'dev-auth-password')
      button(:dev_auth_log_in_button, id: 'dev-auth-submit')

      # Loads the home page
      def load_page
        navigate_to BOACUtils.base_url
        wait_for_spinner
      end

      # Logs in via CAS
      # @param username [String]
      # @param password [String]
      # @param cal_net [Page::CalNetPage]
      def log_in(username, password, cal_net)
        load_page
        wait_for_title 'Welcome'
        wait_for_load_and_click sign_in_element
        cal_net.log_in(username, password)
        wait_for_title 'Home'
      end

      # Authenticates using dev auth
      # @param user [User]
      def dev_auth(user = nil)
        logger.info 'Logging in using developer auth'
        load_page
        scroll_to_bottom
        wait_for_element_and_type(dev_auth_uid_input_element, (user ? user.uid : Utils.super_admin_uid))
        wait_for_element_and_type(dev_auth_password_input_element, BOACUtils.password)
        wait_for_update_and_click dev_auth_log_in_button_element
        wait_for_title 'Home'
      end

      # GENERIC USER DATA UI

      # Returns all the user divs beneath a cohort or group designated by its XPath
      # @param driver [Selenium::WebDriver]
      # @param xpath [String]
      # @return [Array<Selenium::WebDriver::Element>]
      def user_rows(driver, xpath)
        driver.find_elements(xpath: "#{xpath}//div[contains(@data-ng-repeat,'student in group.students')]")
      end

      # Returns the data visible for a cohort or group member
      # @param driver [Selenium::WebDriver]
      # @param xpath [String]
      # @param user [User]
      # @return [Hash]
      def user_row_data(driver, xpath, user)
        row_xpath = "#{xpath}//div[contains(@data-ng-repeat,'student in group.students')][contains(.,'#{user.sis_id}')]"
        {
          :name => link_element(xpath: "#{row_xpath}//a").text,
          :sid => span_element(xpath: "#{row_xpath}//span").text,
          :majors => driver.find_elements(xpath: "#{row_xpath}//span[@data-ng-repeat='major in student.majors']").map(&:text),
          :units_in_progress => div_element(xpath: "#{row_xpath}//div[contains(@data-ng-bind,'student.term.enrolledUnits')]").text,
          :cumulative_units => div_element(xpath: "#{row_xpath}//div[contains(@data-ng-bind,'student.cumulativeUnits')]").text,
          :gpa => div_element(xpath: "#{row_xpath}//div[contains(@data-ng-bind, 'student.cumulativeGPA')]").text,
          :alert_count => div_element(xpath: "#{row_xpath}//div[contains(@class,'home-issues-pill')]").text
        }
      end

      # MY LIST

      div(:my_list_no_users_msg, xpath: '//div[text()="You have no students in your list. Add students from their profile pages."]')
      elements(:my_list_remove_button, :button, xpath: '//button[contains(@id,"watchlist-toggle")]')

      # Returns the element for a user on My List
      # @param user [User]
      # @return [PageObject::Elements::Row]
      def my_list_user_row(user)
        row_element(xpath: "//h2[text()='My List']/following-sibling::div//tr[contains(.,\"#{user.last_name}, #{user.first_name}\")][contains(.,\"#{user.sis_id}\")]")
      end

      # Checks if a user is marked inactive in My List
      # @param user [User]
      # @return [boolean]
      def my_list_user_inactive?(user)
        my_list_user_row(user).span_element(class: 'home-inactive-info-icon').exists?
      end

      # Removes a user from My List
      # @param user [User]
      def remove_user_from_watchlist(user)
        wait_for_load_and_click watchlist_toggle(user)
        my_list_user_row(user).when_not_present Utils.short_wait
      end

      # Removes all users from My List
      def remove_all_from_watchlist
        load_page
        if my_list_remove_button_elements.any?
          logger.info "Removing #{my_list_remove_button_elements.length} users from My List"
          my_list_remove_button_elements.each do |el|
            el.click
            el.when_not_present Utils.short_wait
          end
        else
          logger.info 'There are no users on My List'
        end
      end

      # CUSTOM COHORTS

      elements(:my_cohort, :link, xpath: '//h1[text()="Cohorts"]/following-sibling::div[@data-ng-repeat="cohort in myCohorts"]/h2/a')
      div(:you_have_no_cohorts_msg, xpath: '//div[contains(.,"You have no saved cohorts.")]')

      # Returns the names of My Saved Cohorts shown on the homepage
      # @return [Array<String>]
      def my_saved_cohorts
        h1_element(xpath: '//h1[text()="Cohorts"]').when_present Utils.medium_wait
        my_cohort_elements.map &:text
      end

      # Returns the XPath to a cohort's div
      # @param cohort [Cohort]
      # @return [String]
      def cohort_xpath(cohort)
        "//h1[text()=\"Cohorts\"]/following-sibling::div[contains(.,\"#{cohort.name}\")]"
      end

      # Returns all the user divs beneath a cohort
      # @param driver [Selenium::WebDriver]
      # @param cohort [Cohort]
      # @return [Array<Selenium::WebDriver::Element>]
      def cohort_member_rows(driver, cohort)
        user_rows(driver, cohort_xpath(cohort))
      end

      # Returns the membership count shown for a cohort
      # @param cohort [Cohort]
      # @return [Integer]
      def cohort_member_count(cohort)
        el = span_element(xpath: "#{cohort_xpath cohort}//span")
        el && el.text.to_i
      end

      # Verifies the user + alert data shown for a cohort's membership
      # @param driver [Selenium::WebDriver]
      # @param cohort [Cohort]
      # @param members [Array<User>]
      def verify_cohort_alert_rows(driver, cohort, members)

        # Only cohort members with alerts should be shown. Collect the expected alert count for each member, and toss out those with a zero count.
        member_alerts = members.any? ? BOACUtils.get_un_dismissed_users_alerts(members) : []
        members_and_alert_counts = members.map do |member|
          alert_count = member_alerts.count { |a| a.user.sis_id == member.sis_id }
          {:user => member, :alert_count => alert_count.to_s}
        end
        members_and_alert_counts.delete_if { |u| u[:alert_count] == '0' }

        # Verify that there are only rows for members with alerts
        expected_member_row_count = members_and_alert_counts.length
        visible_member_row_count = cohort_member_rows(driver, cohort).length
        wait_until(1, "Expecting #{expected_member_row_count}, got #{visible_member_row_count}") { visible_member_row_count == expected_member_row_count }

        # Verify that there is a row for each student with a positive alert count and that the alert count is right
        members_and_alert_counts.each do |member|
          logger.debug "Checking cohort row for SID #{member[:user].sis_id}"
          visible_row_data = user_row_data(driver, cohort_xpath(cohort), member[:user])
          wait_until(1, "Expecting name #{member[:user].last_name}, #{member[:user].first_name}, got #{visible_row_data[:name]}") { visible_row_data[:name] == "#{member[:user].last_name}, #{member[:user].first_name}" }
          wait_until(1, "Expecting SID #{member[:user].sis_id}, got #{visible_row_data[:sid]}") { visible_row_data[:sid] == member[:user].sis_id }
          wait_until(1, "Expecting alert count #{member[:alert_count]}, got #{visible_row_data[:alert_count]}") { visible_row_data[:alert_count] == member[:alert_count] }
          # The following data is verified on other pages, so just check that it's not blank on the homepage.
          wait_until(1) { ![visible_row_data[:majors], visible_row_data[:units_in_progress], visible_row_data[:cumulative_units], visible_row_data[:gpa]].any?(&:empty?) }
        end
      end

      # Clicks the link for a given My Saved Cohort
      # @param cohort [Cohort]
      def click_my_cohort(cohort)
        logger.debug "Clicking link to my cohort '#{cohort.name}'"
        wait_until(Utils.short_wait) { my_cohort_elements.any? }
        wait_for_update_and_click (my_cohort_elements.find { |e| e.text == cohort.name })
      end

    end
  end
end
