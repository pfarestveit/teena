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

    # Loads a Junction LTI tool in Canvas and switches focus to the iframe
    # @param driver [Selenium::WebDriver]
    # @param path [String]
    def load_tool_in_canvas(driver, path)
      navigate_to "#{Utils.canvas_base_url}#{path}"
      switch_to_canvas_iframe JunctionUtils.junction_base_url
    end

    # Logs the user out if the user is logged in
    # @param splash_page [Page::JunctionPages::SplashPage]
    def log_out(splash_page)
      toggle_footer_link_element.when_visible Utils.medium_wait
      wait_for_update_and_click(log_out_link_element) if title.include? 'Toolbox'
      splash_page.sign_in_element.when_visible Utils.medium_wait
    end

  end
end
