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

      # Clicks the link for a given My Saved Cohort
      # @param cohort [Cohort]
      def click_my_cohort(cohort)
        logger.debug "Clicking link to my cohort '#{cohort.name}'"
        wait_until(Utils.short_wait) { my_cohort_link_elements.any? }
        wait_for_update_and_click (my_cohort_link_elements.find { |e| e.text == cohort.name })
      end

    end
  end
end
