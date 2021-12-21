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
    span(:invalid_credentials, xpath: '//span[contains(text(), "Invalid credentials.")]')
    span(:access_denied_msg, xpath: '//span[contains(.,"Service access denied due to missing privileges.")]')

    iframe(:duo_frame, xpath: '//div[@id="duo_iframe"]/iframe')
    checkbox(:remember_me, name: 'dampen_choice')
    button(:send_push, xpath: '//button[text()="Send Me a Push "]')

    def enter_credentials(username, password, event = nil, msg = nil)
      # If no credentials are available, then wait for manual login
      wait_until(Utils.medium_wait) { title.include? 'CAS – Central Authentication Service' }
      if username == 'secret' || password == 'secret'
        if Utils.config['webdriver']['headless']
          logger.error 'Browser is running in headless mode, manual login is not supported'
          fail
        else
          logger.debug 'Waiting for manual login'
          prompt_for_action msg
          wait_for_manual_login
        end
      else
        logger.debug "#{username} is logging in"
        wait_for_element_and_type(username_element, username)
        wait_for_element_and_type(password_element, password)
        wait_for_update_and_click sign_in_button_element
        sleep 2
        if duo_frame?
          @driver.switch_to.frame duo_frame_element.selenium_element
          remember_me_element.click unless remember_me_checked?
          send_push
        elsif invalid_credentials?
          fail('Invalid credentials')
        end
        add_event(event, EventType::LOGGED_IN)
      end
    end

    def prompt_for_action(msg)
      wait_for_element_and_type(username_element, msg)
    end

    def wait_for_manual_login
      wait_until(Utils.long_wait) do
        # If login is to resolve a Junction session conflict, then logout should occur. Otherwise, expect successful login.
        logout_conf_heading_element.visible? || !title.include?('CAS – Central Authentication Service')
      end
    end

    # Logs in to CAS. If no real credentials available in a Settings override, then waits for manual login using a real
    # person's credentials.
    # @param username [String]
    # @param password [String]
    # @param event [Event]
    def log_in(username, password, event = nil, msg = 'PLEASE LOG IN MANUALLY')
      enter_credentials(username, password, event, msg)
      wait_for_manual_login
    end

    # Hits the CAS logout URL directly
    def log_out
      navigate_to "#{Utils.cal_net_url}/cas/logout"
      logout_conf_heading_element.when_visible Utils.medium_wait
      sleep 1
    end

  end
end
