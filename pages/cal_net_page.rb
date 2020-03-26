require_relative '../util/spec_helper'

module Page

  class CalNetPage

    include PageObject
    include Logging
    include Page

    text_field(:username, id: 'username')
    text_field(:password, id: 'password')
    text_area(:sign_in_button, xpath: '//input[@value="Sign In"]')
    h3(:logout_conf_heading, xpath: '//h3[text()="Logout Successful"]')
    span(:access_denied_msg, xpath: '//span[contains(.,"Service access denied due to missing privileges.")]')

    # Logs in to CAS. If no real credentials available in a Settings override, then waits for manual login using a real
    # person's credentials.
    # @param username [String]
    # @param password [String]
    # @param event [Event]
    def log_in(username, password, event = nil)
      # If no credentials are available, then wait for manual login
      wait_until(Utils.medium_wait) { title.include? 'CAS – Central Authentication Service' }
      if username == 'secret' || password == 'secret'
        if Utils.config['webdriver']['headless']
          logger.error 'Browser is running in headless mode, manual login is not supported'
          fail
        else
          logger.debug 'Waiting for manual login'
          wait_for_element_and_type(username_element, 'PLEASE LOG IN MANUALLY')
        end
      else
        logger.debug "#{username} is logging in"
        wait_for_element_and_type(username_element, username)
        wait_for_element_and_type(password_element, password)
        wait_for_update_and_click sign_in_button_element
        sleep 2
        add_event(event, EventType::LOGGED_IN)
      end
      wait_until(Utils.long_wait) do
        # If login is to resolve a Junction session conflict, then logout should occur. Otherwise, expect successful login.
        logout_conf_heading_element.visible? || !title.include?('CAS – Central Authentication Service')
      end
    end

    # Hits the CAS logout URL directly
    def log_out
      navigate_to "#{Utils.cal_net_url}/cas/logout"
      logout_conf_heading_element.when_visible Utils.medium_wait
      sleep 1
    end

  end
end
