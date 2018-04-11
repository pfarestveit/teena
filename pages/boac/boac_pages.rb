require_relative '../../util/spec_helper'

module Page

  module BOACPages

    include PageObject
    include Logging
    include Page

    link(:home_link, text: 'Home')
    button(:cohorts_button, id: 'btn-append-to-single-button')
    list_item(:no_cohorts_msg, xpath: '//li[contains(.,"No saved cohorts")]')
    link(:team_list_link, id: 'sidebar-teams-link')
    link(:intensive_cohort_link, text: 'Intensive')
    link(:inactive_cohort_link, text: 'Inactive')
    link(:create_new_cohort_link, id: 'sidebar-cohort-create')
    link(:manage_my_cohorts_link, id: 'sidebar-cohorts-manage')
    link(:view_everyone_cohorts_link, id: 'sidebar-cohorts-all')
    button(:log_out_button, xpath: '//button[contains(text(),"Log out")]')
    elements(:my_cohort_link, :link, :xpath => '//ul[@class="dropdown-menu"]/li[@data-ng-repeat="cohort in myCohorts"]/a')
    link(:feedback_link, text: 'ascpilot@lists.berkeley.edu')

    div(:spinner, class: 'loading-spinner-large')
    h1(:student_name_heading, class: 'student-bio-name')

    # Waits for an expected page title
    # @param page_title [String]
    def wait_for_title(page_title)
      wait_until(Utils.medium_wait) { title == "#{page_title} | BOAC" }
    end

    # Clicks the 'Home' link in the header
    def click_home
      wait_for_load_and_click home_link_element
    end

    # Returns the names of My Saved Cohorts displayed in the header dropdown
    # @return [Array<String>]
    def dropdown_my_cohorts
      create_new_cohort_link_element.when_visible Utils.short_wait
      my_cohort_link_elements.map &:text
    end

    # Clicks the link for the Teams List page
    def click_teams_list
      wait_for_load_and_click team_list_link_element
      wait_for_title 'Teams'
    end

    # Clicks the link for the Intensive cohort
    def click_intensive_cohort
      wait_for_load_and_click intensive_cohort_link_element
      wait_for_title 'Intensive'
    end

    # Clicks the link for the Inactive cohort
    def click_inactive_cohort
      wait_for_load_and_click inactive_cohort_link_element
      wait_for_title 'Inactive'
    end

    # Clicks the button to create a new custom cohort
    def click_create_new_cohort
      wait_for_load_and_click create_new_cohort_link_element
      wait_for_title 'Cohort'
    end

    # Clicks the button to manage the user's own custom cohorts
    def click_manage_my_cohorts
      wait_for_load_and_click manage_my_cohorts_link_element
      wait_for_title 'Cohorts Manage'
    end

    # Clicks the button to view all custom cohorts
    def click_view_everyone_cohorts
      wait_for_load_and_click view_everyone_cohorts_link_element
      wait_for_title 'Cohorts'
    end

    # Clicks the 'Log out' button in the header
    def log_out
      wait_for_update_and_click log_out_button_element
      wait_for_title 'Welcome'
    end

    # Waits for the spinner to vanish following a page load
    def wait_for_spinner
      sleep 1
      spinner_element.when_not_present Utils.medium_wait if spinner?
    end

    # USER SEARCH

    text_area(:user_search_input, xpath: '//div[@class="select-search"]//input')
    elements(:user_search_option, :list_item, xpath: '//*[name()="find-student"]//li')

    # Puts focus in the user search field
    def click_user_search_input
      wait_for_load_and_click user_search_input_element
    end

    # Returns the search option for a given user
    # @param user [User]
    # @return [PageObject::Elements::ListItem]
    def user_option(user)
      list_item_element(xpath: "//li[contains(@class,\"select-dropdown-optgroup-option\")][contains(.,\"#{user.full_name} - #{user.sis_id}\")]")
    end

    # Returns the search option for a given squad plus user combination
    # @param squad [Squad]
    # @param user [User]
    # @return [PageObject::Elements::ListItem]
    def squad_user_option(squad, user)
      list_item_element(xpath: "//div[@class=\"select-dropdown\"]//div[text()=\"#{squad.name}\"]/following-sibling::li[text()=\"#{user.full_name} - #{user.sis_id}\"]")
    end

    # Enters a string in the user search field and pauses to trigger a search
    # @param string [String]
    def enter_search_string(string)
      logger.info "Searching for '#{string}'"
      wait_for_element_and_type(user_search_input_element, string)
      sleep 2
    end

    # Returns the text of all the visible user search options
    # @return [Array<String>]
    def visible_user_options
      options = user_search_option_elements.map &:text
      options.reject &:empty?
    end

    # MY LIST

    # Returns the button for adding a user to or removing a user from My List
    # @param user [User]
    # @return [PageObject::Elements::Button]
    def watchlist_toggle(user)
      button_element(id: "watchlist-toggle-#{user.sis_id}")
    end

    # Adds a user to My List
    # @param user [User]
    def add_user_to_watchlist(user)
      wait_for_load_and_click watchlist_toggle(user)
      wait_until(1) { watchlist_toggle(user).span_element(xpath: "//span[contains(.,'Remove student #{user.sis_id} from my list')]") }
    end

    # Removes a user from My List
    # @param user [User]
    def remove_user_from_watchlist(user)
      wait_for_load_and_click watchlist_toggle(user)
      wait_until(1) { watchlist_toggle(user).span_element(xpath: "//span[contains(.,'Add student #{user.sis_id} to my list')]") }
    end

  end
end
