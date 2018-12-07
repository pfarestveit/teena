require_relative '../../util/spec_helper'

module Page

  module JunctionPages

    class SplashPage

      include PageObject
      include Logging
      include Page
      include JunctionPages

      button(:sign_in, xpath: '//button[@data-ng-click="api.user.signIn()"]')

      # Loads the Junction splash page
      def load_page
        navigate_to JunctionUtils.junction_base_url
      end

      # Authenticates using basic auth
      # @param uid [String]
      # @param cal_net [Page::CalNetPage]
      def basic_auth(uid, cal_net = nil)
        logger.info "Logging in as #{uid} using basic auth"
        load_page
        scroll_to_bottom
        begin
          wait_for_update_and_click toggle_footer_link_element
        rescue
          logger.warn 'Session conflict, CAS page loaded'
          cal_net.log_out
          navigate_to "#{JunctionUtils.junction_base_url}/logout"
          wait_until(Utils.short_wait) { text.include? 'redirectUrl' }
          load_page
          scroll_to_bottom
          wait_for_update_and_click toggle_footer_link_element
        end
        wait_for_element_and_type_js(basic_auth_uid_input_element, uid)
        wait_for_element_and_type_js(basic_auth_password_input_element, JunctionUtils.junction_basic_auth_password)
        # The log in button element will disappear and reappear
        button = basic_auth_log_in_button_element
        button.click
        button.when_not_present timeout=Utils.medium_wait
        basic_auth_log_in_button_element.when_present timeout
        basic_auth_uid_input_element.when_not_visible timeout
      end

      # Clicks the sign in button on the splash page
      def click_sign_in_button
        wait_for_load_and_click sign_in_element
      end

      # Loads the splash page, clicks the sign in button, authenticates in CalNet, and arrives on My Toolbox
      # @param driver [Selenium::WebDriver]
      # @param cal_net_page [Page::CalNetPage]
      # @param username [String]
      # @param password [String]
      # @return [JunctionPages::MyToolboxPage]
      def log_in_to_dashboard(driver, cal_net_page, username, password)
        load_page
        click_sign_in_button
        cal_net_page.log_in(username, password)
        JunctionPages::MyToolboxPage.new driver
      end

    end
  end
end
