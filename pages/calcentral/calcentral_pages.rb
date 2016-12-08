require_relative '../../util/spec_helper'

module Page

  module CalCentralPages

    include PageObject
    include Logging
    include Page

    # Header
    button(:profile_icon, xpath: '//button[@title="Settings"]')
    button(:log_out_link, xpath: '//button[contains(text(),"Log out")]')

    # Footer
    div(:toggle_footer_link, xpath: '//div[@class="cc-footer-berkeley"]/div')
    text_field(:basic_auth_uid_input, name: 'email')
    text_field(:basic_auth_password_input, name: 'password')
    button(:basic_auth_log_in_button, xpath: '//button[contains(text(),"Login")]')

    # Opens the Profile popover and clicks the log out link
    def click_log_out_link
      logger.info 'Logging out of CalCentral'
      wait_for_page_load_and_click profile_icon_element unless log_out_link_element.visible?
      wait_for_page_update_and_click log_out_link_element
    end

    # Logs the user out if the user is logged in
    def log_out(splash_page)
      navigate_to Utils.calcentral_base_url
      toggle_footer_link_element.when_visible Utils.medium_wait
      click_log_out_link if title.include? 'Dashboard'
      splash_page.sign_in_element.when_visible Utils.medium_wait
    end

    # Authenticates using basic auth
    # @param uid [String]
    def basic_auth(uid)
      logger.info "Logging in as #{uid} using basic auth"
      scroll_to_bottom
      wait_for_page_load_and_click toggle_footer_link_element
      wait_for_element_and_type(basic_auth_uid_input_element, uid)
      wait_for_element_and_type(basic_auth_password_input_element, Utils.calcentral_basic_auth_password)
      # The log in button element will disappear and reappear
      button = basic_auth_log_in_button_element
      button.click
      button.when_not_present timeout=Utils.medium_wait
      basic_auth_log_in_button_element.when_present timeout
      basic_auth_uid_input_element.when_not_visible timeout
    end

  end
end
