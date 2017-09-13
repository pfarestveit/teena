require_relative '../util/spec_helper'

module Page

  class CalNetPage

    include PageObject
    include Logging
    include Page

    h2(:page_heading, xpath: '//h2[contains(.,"CalNet Authentication Service")]')
    text_field(:username, id: 'username')
    text_field(:password, id: 'password')
    button(:sign_in_button, value: 'Sign In')
    paragraph(:logout_conf_heading, xpath: '//p[contains(.,"You have successfully logged out")]')

    # Loads CAS
    def load_page
      navigate_to Utils.cal_net_url
      page_heading_element.when_visible Utils.medium_wait
    end

    # Logs in to CAS. If no real credentials available in a Settings override, then waits for manual login using a real
    # person's credentials.
    # @param username [String]
    # @param password [String]
    # @param event [Event]
    def log_in(username, password, event = nil)
      # If no credentials are available, then wait for manual login
      if username == 'secret' || password == 'secret'
        logger.debug 'Waiting for manual login'
        wait_for_element_and_type(username_element, 'PLEASE LOG IN MANUALLY')
        username_element.flash
        sign_in_button_element.when_not_present Utils.long_wait
      else
        logger.debug "#{username} is logging in"
        wait_for_element_and_type_js(username_element, username)
        password_element.send_keys password
        wait_for_update_and_click sign_in_button_element
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
