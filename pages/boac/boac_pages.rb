require_relative '../../util/spec_helper'

module Page

  module BOACPages

    include PageObject
    include Logging
    include Page

    link(:home_link, text: 'Home')
    button(:cohorts_button, id: 'btn-append-to-single-button')
    link(:no_cohorts_msg, text: 'No saved cohorts')
    link(:intensive_cohort_link, text: 'Intensive')
    link(:create_new_cohort_link, text: 'Create New Cohort')
    link(:manage_my_cohorts_link, text: 'Manage My Cohorts')
    link(:view_everyone_cohorts_link, text: "View Everyone's Cohorts")
    button(:log_out_button, xpath: '//button[contains(text(),"Log out")]')
    elements(:my_cohort_link, :link, :xpath => '//ul[@class="dropdown-menu"]/li[@data-ng-repeat="cohort in myCohorts"]/a')

    # Clicks the 'Home' link in the header
    def click_home
      wait_for_load_and_click home_link_element
    end

    # Clicks the 'Cohorts' button in the header
    def click_cohorts
      wait_for_load_and_click cohorts_button_element unless create_new_cohort_link_element.visible?
    end

    # Returns the names of My Saved Cohorts displayed in the header dropdown
    # @return [Array<String>]
    def dropdown_my_cohorts
      create_new_cohort_link_element.when_visible Utils.short_wait
      my_cohort_link_elements.map &:text
    end

    # Clicks the link for the Intensive cohort
    def click_intensive_cohort
      click_cohorts
      wait_for_load_and_click intensive_cohort_link_element
    end

    # Clicks the button to create a new custom cohort
    def click_create_new_cohort
      click_cohorts
      wait_for_load_and_click create_new_cohort_link_element
    end

    # Clicks the button to manage the user's own custom cohorts
    def click_manage_my_cohorts
      click_cohorts
      wait_for_load_and_click manage_my_cohorts_link_element
    end

    # Clicks the button to view all custom cohorts
    def click_view_everyone_cohorts
      click_cohorts
      wait_for_load_and_click view_everyone_cohorts_link_element
    end

    # Clicks the 'Log out' button in the header
    def log_out
      wait_for_update_and_click log_out_button_element
    end

  end
end
