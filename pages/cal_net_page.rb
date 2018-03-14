require_relative '../util/spec_helper'

module Page

  class CalNetPage

    include PageObject
    include Logging
    include Page

    text_field(:username, id: 'username')
    text_field(:password, id: 'password')
    button(:sign_in_button, name: 'submit')
    paragraph(:logout_conf_heading, xpath: '//p[contains(.,"You have successfully logged out")]')
    span(:access_denied_msg, xpath: '//span[contains(.,"Service access denied due to missing privileges.")]')

    # Logs in to CAS. If no real credentials available in a Settings override, then waits for manual login using a real
    # person's credentials.
    # @param username [String]
    # @param password [String]
    # @param event [Event]
    def log_in(username, password, event = nil)
      # If no credentials are available, then wait for manual login
      if username == 'secret' || password == 'secret'
        if Utils.config['webdriver']['headless']
          logger.error 'Browser is running in headless mode, manual login is not supported'
          fail
        else
          logger.debug 'Waiting for manual login'
          wait_for_element_and_type(username_element, 'PLEASE LOG IN MANUALLY')
          username_element.flash
          sign_in_button_element.when_not_present Utils.long_wait
        end
      else
        logger.debug "#{username} is logging in"
        wait_for_element_and_type(username_element, username)
        wait_for_element_and_type(password_element, password)
        wait_for_update_and_click_js sign_in_button_element
        add_event(event, EventType::LOGGED_IN)
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
