require_relative '../util/spec_helper'

module Page

  class SalesforcePage

    include PageObject
    include Logging
    include Page

    text_area(:username, id: 'username')
    text_area(:password, id: 'password')
    button(:login_button, id: 'Login')
    link(:locations_link, text: 'Locations')
    button(:new_location_button, name: 'new')
    text_area(:location_agent_input, id: 'Name')
    text_area(:location_room_input, id: '00N3000000AT1hD')
    select_list(:location_type_select, id: '00N30000006Tn28')
    select_list(:location_capability_select, id: '00N3000000ASepl')
    select_list(:location_building_select, id: '00N30000006TLPQ')
    button(:location_save_button, name: 'save')
    div(:location_name, id: 'Name_ileinner')
    div(:location_building, id: '00N30000006TLPQ_ileinner')
    div(:location_room, id: '00N3000000AT1hD_ileinner')
    div(:location_type, id: '00N30000006Tn28_ileinner')

    # Logs in to Salesforce sandbox
    def log_in
      logger.info 'Logging in to Salesforce'
      navigate_to SalesforceUtils.base_url
      wait_for_element_and_type(username_element, SalesforceUtils.login_credentials[:username])
      wait_for_element_and_type(password_element, SalesforceUtils.login_credentials[:password])
      wait_for_update_and_click login_button_element
    end

    # Creates a capture agent 'location' in Salesforce
    # @param agent [Hash]
    def create_location(agent)
      logger.info "Creating '#{agent['captureAgent']}'"
      wait_for_load_and_click locations_link_element
      wait_for_load_and_click new_location_button_element
      wait_for_element_and_type(location_agent_input_element, agent['captureAgent'])
      wait_for_element_and_type(location_room_input_element, agent['room'])
      wait_for_element_and_select_js(location_type_select_element, 'GA Classroom')
      wait_for_element_and_select_js(location_capability_select_element, agent['capability'])
      wait_for_element_and_select_js(location_building_select_element, agent['building'])
      wait_for_update_and_click location_save_button_element
      location_name_element.when_visible Utils.medium_wait
      wait_until(1) { location_name == agent['captureAgent'] }
      wait_until(1) { location_building == agent['building'] }
      wait_until(1) { location_room == agent['room'] }
    end

  end
end
