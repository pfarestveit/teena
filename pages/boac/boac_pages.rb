require_relative '../../util/spec_helper'

module Page

  module BOACPages

    include PageObject
    include Logging
    include Page

    link(:home_link, text: 'Home')
    button(:cohorts_button, id: 'btn-append-to-single-button')
    link(:no_cohorts_msg, text: 'No saved cohorts')
    link(:create_new_cohort_link, text: 'Create New Cohort')
    link(:manage_my_cohorts_link, text: 'Manage My Cohorts')
    link(:view_everyone_cohorts_link, text: "View Everyone's Cohorts")
    button(:log_out_button, xpath: '//button[contains(text(),"Log out")]')

    # Clicks the 'Home' link in the header
    def click_home
      wait_for_load_and_click home_link_element
    end

    def click_create_new_cohort
      wait_for_load_and_click create_new_cohort_link_element
    end

    def click_manage_my_cohorts
      wait_for_load_and_click manage_my_cohorts_link_element
    end

    def click_view_everyone_cohorts
      wait_for_load_and_click view_everyone_cohorts_link_element
    end

    # Clicks the 'Log out' button in the header
    def log_out
      wait_for_update_and_click log_out_button_element
    end

  end
end
