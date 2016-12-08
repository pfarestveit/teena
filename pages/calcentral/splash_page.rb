require_relative '../../util/spec_helper'

module Page

  module CalCentralPages

    class SplashPage

      include PageObject
      include Logging
      include Page
      include CalCentralPages

      button(:sign_in, xpath: '//button[@data-ng-click="api.user.signIn()"]')

      # Loads the CalCentral splash page
      def load_page
        logger.info 'Loading splash page'
        navigate_to Utils.calcentral_base_url
      end

      # Clicks the sign in button on the splash page
      def click_sign_in_button
        wait_for_page_load_and_click sign_in_element
      end

      # Loads the splash page, clicks the sign in button, authenticates in CalNet, and arrives on My Dashboard
      # @param driver [Selenium::WebDriver]
      # @param cal_net_page [Page::CalNetPage]
      # @param username [String]
      # @param password [String]
      # @return [CalCentralPages::MyDashboardPage]
      def log_in_to_dashboard(driver, cal_net_page, username, password)
        load_page
        click_sign_in_button
        cal_net_page.log_in(username, password)
        CalCentralPages::MyDashboardPage.new driver
      end

    end
  end
end
