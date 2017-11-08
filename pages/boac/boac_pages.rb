require_relative '../../util/spec_helper'

module Page

  module BOACPages

    include PageObject
    include Logging
    include Page

    link(:boac_link, text: 'BOAC')
    button(:log_out_button, xpath: '//button[contains(text(),"Log out")]')

    # Clicks the 'BOAC' link in the header
    def click_boac
      wait_for_load_and_click boac_link_element
    end

    # Clicks the 'Log out' button in the header
    def log_out
      wait_for_update_and_click log_out_button_element
    end

  end
end
