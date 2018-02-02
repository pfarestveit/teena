require_relative '../../util/spec_helper'

module Page

  module BOACPages

    class HomePage

      include PageObject
      include Logging
      include Page
      include BOACPages

      button(:sign_in, xpath: '//button[text()="Sign In"]')
      div(:sign_in_msg, xpath: '//div[text()="Please sign in."]')

      text_field(:dev_auth_uid_input, xpath: '//input[@placeholder="UID"]')
      text_field(:dev_auth_password_input, name: 'password')
      button(:dev_auth_log_in_button, xpath: '//button[text()="Dev Auth Login"]')

      # Loads the home page
      def load_page
        navigate_to BOACUtils.base_url
      end

      # Logs in via CAS
      # @param username [String]
      # @param password [String]
      # @param cal_net [Page::CalNetPage]
      def log_in(username, password, cal_net)
        load_page
        wait_for_load_and_click sign_in_element
        cal_net.log_in(username, password)
      end

      # Authenticates using dev auth
      # @param uid [String]
      def dev_auth(uid)
        logger.info "Logging in as #{uid} using developer auth"
        load_page
        scroll_to_bottom
        wait_for_element_and_type(dev_auth_uid_input_element, uid)
        wait_for_element_and_type(dev_auth_password_input_element, BOACUtils.password)
        wait_for_update_and_click dev_auth_log_in_button_element
      end

      # TEAMS

      elements(:team_cohort_link, :link, xpath: '//a[@data-ng-bind="team.name"]')

      # Returns the text of all the team cohort links
      # @return [Array<String>]
      def teams
        wait_until(Utils.medium_wait) { team_cohort_link_elements.any? }
        team_cohort_link_elements.map &:text
      end

      # Clicks the dashboard link for a team
      # @param team [Team]
      def click_team_link(team)
        logger.info "Clicking link for #{team.name}"
        wait_for_load_and_click link_element(xpath: "//a[text()=\"#{team.name}\"]")
      end

      # CUSTOM COHORTS

      elements(:my_cohort, :link, xpath: '//h2[text()="My Saved Cohorts"]/following-sibling::div//li[@data-ng-repeat="cohort in myCohorts"]/a')
      div(:you_have_no_cohorts_msg, xpath: '//div[contains(.,"You have no saved cohorts.")]')

      # Returns the names of My Saved Cohorts shown on the homepage
      # @return [Array<String>]
      def my_saved_cohorts
        wait_until(Utils.medium_wait) { team_cohort_link_elements.any? }
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
