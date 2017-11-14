require_relative '../../util/spec_helper'

module Page

  module BOACPages

    include PageObject
    include Logging
    include Page

    link(:home_link, text: 'Home')
    button(:log_out_button, xpath: '//button[contains(text(),"Log out")]')

    # Clicks the 'Home' link in the header
    def click_home
      wait_for_load_and_click home_link_element
    end

    # Clicks the 'Log out' button in the header
    def log_out
      wait_for_update_and_click log_out_button_element
    end

  end
end
