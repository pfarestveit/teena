require_relative '../../util/spec_helper'

module Page

  module JunctionPages

    include PageObject
    include Logging
    include Page

    # Header
    button(:log_out_link, id: 'log-out')

    h1(:unexpected_error, xpath: '//h1[contains(text(),"Error")]')

    # Footer
    button(:stop_viewing_as_button, id: 'stop-viewing-as')
    h4(:build_summary_heading, xpath: '//h4[text()="Build Summary"]')
    div(:toggle_footer_link, id: 'toggle-show-dev-auth')
    text_field(:basic_auth_uid_input, id: 'basic-auth-uid')
    text_field(:basic_auth_password_input, id: 'basic-auth-password')
    button(:basic_auth_log_in_button, id: 'basic-auth-submit-button')

    # Loads a Junction LTI tool in Canvas and switches focus to the iframe
    # @param path [String]
    def load_tool_in_canvas(path)
      navigate_to "#{Utils.canvas_base_url}#{path}"
      switch_to_canvas_iframe JunctionUtils.junction_base_url
    end

    # Logs the user out
    def log_out
      wait_for_update_and_click log_out_link_element unless title.include? 'Welcome. Please log in. | bCourses Support'
      log_out_link_element.when_not_present Utils.short_wait
    end

    def stop_viewing_as
      logger.info 'Clicking stop-view-as'
      wait_for_load_and_click stop_viewing_as_button_element
      stop_viewing_as_button_element.when_not_present Utils.short_wait
    end

  end
end
