require_relative '../../util/spec_helper'

module Page

  module BOACPages

    include PageObject
    include Logging
    include Page

    link(:home_link, text: 'Home')
    button(:log_out_button, xpath: '//button[contains(text(),"Log out")]')
    link(:feedback_link, text: 'ascpilot@lists.berkeley.edu')
    div(:spinner, class: 'loading-spinner-large')
    h1(:student_name_heading, class: 'student-section-header')

    # Waits for an expected page title
    # @param page_title [String]
    def wait_for_title(page_title)
      wait_until(Utils.medium_wait) { title == "#{page_title} | BOAC" }
    end

    # Clicks the 'Home' link in the header
    def click_home
      wait_for_load_and_click home_link_element
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

    # COHORTS - validation errors shared on various pages

    div(:dupe_curated_name_msg, xpath: '//div[text()="You have an existing curated cohort with this name. Please choose a different name."]')
    div(:dupe_filtered_name_msg, xpath: '//div[text()="You have an existing filtered cohort with this name. Please choose a different name."]')

    # CURATED COHORTS

    # 'Create' modal
    text_area(:curated_name_input, id: 'curated-cohort-create-input')
    button(:curated_save_button, id: 'confirm-create-curated-cohort-btn')
    button(:curated_cancel_button, id: 'cancel-create-curated-cohort-btn')

    # Sidebar
    link(:sidebar_create_curated_link, id: 'sidebar-curated-cohort-create')
    link(:sidebar_manage_curated_link, id: 'sidebar-curated-cohorts-manage')
    elements(:sidebar_curated_cohort_link, :link, xpath: '//div[@data-ng-repeat="group in myGroups"]//a')

    # Clicks the sidebar button to manage the user's curated cohorts
    def sidebar_click_manage_curated
      wait_for_update_and_click sidebar_manage_curated_link_element
      wait_for_title 'Manage Curated Cohorts'
    end

    # Clicks the sidebar button to create a new curated cohort
    def sidebar_click_create_curated
      wait_for_load_and_click sidebar_create_curated_link_element
      curated_name_input_element.when_visible Utils.short_wait
    end

    # Enters a curated cohort name in the 'create' modal
    # @param cohort [CuratedCohort]
    def enter_curated_cohort_name(cohort)
      logger.debug "Entering curated cohort name '#{cohort.name}'"
      wait_for_element_and_type(curated_name_input_element, cohort.name)
    end

    # Enters a curated cohort name in the 'create' modal and clicks Save
    # @param cohort [CuratedCohort]
    def name_and_save_curated_cohort(cohort)
      enter_curated_cohort_name cohort
      wait_for_update_and_click curated_save_button_element
    end

    # Clicks Cancel in the curated cohort 'create' modal if it is open
    def cancel_curated_cohort
      curated_cancel_button
      curated_name_input_element.when_not_visible Utils.short_wait
    rescue
      logger.warn 'No cancel button to click'
    end

    # Creates a curated cohort using the sidebar 'create' button and waits for the new cohort to appear in the sidebar
    # @param cohort [CuratedCohort]
    def sidebar_create_curated(cohort)
      logger.info "Using the sidebar link to create a curated cohort named '#{cohort.name}'"
      sidebar_click_create_curated
      name_and_save_curated_cohort cohort
      wait_for_sidebar_curated cohort
    end

    # Returns the names of all the curated cohorts in the sidebar
    # @return [Array<String>]
    def sidebar_curated_cohorts
      sidebar_curated_cohort_link_elements.map &:text
    end

    # Waits for a curated cohort's member count in the sidebar to match expectations
    # @param cohort [CuratedCohort]
    def wait_for_sidebar_curated_member_count(cohort)
      logger.debug "Waiting for curated cohort member count of #{cohort.members.length}"
      wait_until(Utils.short_wait) do
        el = span_element(xpath: "//div[@data-ng-repeat=\"group in myGroups\"]//a[contains(.,\"#{cohort.name}\")]/following-sibling::span")
        (el && el.text) == cohort.members.length.to_s
      end
    end

    # Waits for a curated cohort to appear in the sidebar with the right member count and obtains the cohort's ID
    # @param cohort [CuratedCohort]
    def wait_for_sidebar_curated(cohort)
      wait_until(Utils.short_wait) { sidebar_curated_cohorts.include? cohort.name }
      wait_for_sidebar_curated_member_count cohort
      BOACUtils.set_curated_cohort_id cohort
    end

    # Selector 'create' and 'add student(s)' UI shared by list view pages (filtered cohort page and class page)
    button(:selector_create_curated_button, id: 'curated-cohort-create')
    checkbox(:add_all_to_curated_checkbox, id: 'curated-cohort-checkbox-add-all')
    elements(:add_individual_to_curated_checkbox, :checkbox, xpath: '//input[@data-ng-click="curatedCohortStudentToggle(student)"]')
    button(:add_to_curated_button, id: 'add-to-curated-cohort-button')
    button(:added_to_curated_conf, id: 'added-to-curated-cohort-confirmation')

    # Selects the add-to-cohort checkboxes for a given set of students
    # @param students [Array<User>]
    def select_students_to_add(students)
      logger.info "Adding student UIDs: #{students.map &:uid}"
      students.each { |s| wait_for_update_and_click checkbox_element(id: "student-#{s.uid}-curated-cohort-checkbox") }
    end

    # Selects a curated cohort for adding users and waits for the 'added' confirmation.
    # @param students [Array<User>]
    # @param cohort [CuratedCohort]
    def select_curated_and_add(students, cohort)
      wait_for_update_and_click add_to_curated_button_element
      wait_for_update_and_click checkbox_element(xpath: "//span[text()='#{cohort.name}']/preceding-sibling::input")
      added_to_curated_conf_element.when_visible Utils.short_wait
      cohort.members << students
      cohort.members.flatten!
    end

    # Adds a given set of students to an existing curated cohort
    # @param students [Array<User>]
    # @param cohort [CuratedCohort]
    def selector_add_students_to_curated(students, cohort)
      select_students_to_add students
      select_curated_and_add(students, cohort)
    end

    # Adds a given set of students to a new curated cohort, which is created as part of the process
    # @param students [Array<User>]
    # @param cohort [CuratedCohort]
    def selector_add_students_to_new_curated(students, cohort)
      select_students_to_add students
      wait_for_update_and_click add_to_curated_button_element
      logger.debug 'Clicking curated cohort selector button to create a new cohort'
      wait_for_load_and_click selector_create_curated_button_element
      curated_name_input_element.when_visible Utils.short_wait
      name_and_save_curated_cohort cohort
      cohort.members << students
      cohort.members.flatten!
      wait_for_sidebar_curated cohort
      added_to_curated_conf_element.when_visible Utils.short_wait
    end

    # Adds all the students on a page to a curated cohort
    # @param cohort [CuratedCohort]
    def selector_add_all_students_to_curated(cohort)
      wait_until(Utils.short_wait) { add_individual_to_curated_checkbox_elements.any? &:visible? }
      wait_for_update_and_click add_all_to_curated_checkbox_element
      logger.debug "There are #{add_individual_to_curated_checkbox_elements.length} individual checkboxes"
      students = add_individual_to_curated_checkbox_elements.map { |el| User.new({uid: el.attribute('id').split('-')[1]}) }
      select_curated_and_add(students, cohort)
    end

    # FILTERED COHORTS

    link(:create_filtered_cohort_link, id: 'sidebar-filtered-cohort-create')
    link(:manage_filtered_cohorts_link, id: 'sidebar-filtered-cohorts-manage')
    link(:view_everyone_cohorts_link, id: 'sidebar-filtered-cohorts-all')
    link(:team_list_link, id: 'sidebar-teams-link')
    link(:intensive_cohort_link, text: 'Intensive')
    link(:inactive_cohort_link, text: 'Inactive')
    elements(:filtered_cohort_link, :link, xpath: '//div[@data-ng-repeat="cohort in myCohorts"]//a')

    # Clicks the button to create a new custom cohort
    def click_sidebar_create_filtered
      wait_for_load_and_click create_filtered_cohort_link_element
      wait_for_title 'Filtered Cohort'
    end

    # Clicks the button to manage the user's own filtered cohorts
    def click_sidebar_manage_filtered
      wait_for_load_and_click manage_filtered_cohorts_link_element
      wait_for_title 'Manage Filtered Cohorts'
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

    # Clicks the button to view all custom cohorts
    def click_view_everyone_cohorts
      wait_for_load_and_click view_everyone_cohorts_link_element
      wait_for_title 'Cohorts'
    end

    # Clicks the sidebar link to a filtered cohort
    # @param cohort [FilteredCohort]
    def click_sidebar_filtered_link(cohort)
      link = filtered_cohort_link_elements.find(&:text) == cohort.name
      wait_for_update_and_click link
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

  end
end
