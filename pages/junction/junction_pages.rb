require_relative '../../util/spec_helper'

module Page

  module JunctionPages

    include PageObject
    include Logging
    include Page

    # Header
    link(:log_out_link, text: 'Log out')

    # Footer
    div(:toggle_footer_link, xpath: '//div[@class="cc-footer-berkeley"]/div')
    text_field(:basic_auth_uid_input, name: 'email')
    text_field(:basic_auth_password_input, name: 'password')
    button(:basic_auth_log_in_button, xpath: '//button[contains(text(),"Login")]')

    # Opens the Profile popover and clicks the log out link
    def click_log_out_link
      logger.info 'Logging out of Junction'
      wait_for_update_and_click log_out_link_element
    end

    # Logs the user out if the user is logged in
    # @param splash_page [Page::JunctionPages::SplashPage]
    def log_out(splash_page)
      navigate_to Utils.junction_base_url
      toggle_footer_link_element.when_visible Utils.medium_wait
      click_log_out_link if title.include? 'Toolbox'
      splash_page.sign_in_element.when_visible Utils.medium_wait
    end

  end
end
