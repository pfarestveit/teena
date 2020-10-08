require_relative '../../util/spec_helper'

module Page

  module JunctionPages

    class CanvasCourseAddUserPage

      include PageObject
      include Logging
      include Page
      include JunctionPages

      button(:maintenance_button, xpath: '//button[contains(@class, "bc-template-canvas-maintenance-notice-button")]')
      span(:maintenance_notice, class: 'bc-template-canvas-maintenance-notice-text')
      paragraph(:maintenance_detail, xpath: '//div[@id="maintenance-details"]//p')
      link(:bcourses_service_link, xpath: '//a[contains(text(),"bCourses service page")]')

      h1(:page_heading, xpath: '//h1[text()="Find a Person to Add"]')

      span(:no_access_msg, xpath: '//span[text()="You must be a teacher in this bCourses course to import users."]')
      span(:no_sections_msg, xpath: '//span[text()="Course sections failed to load"]')
      div(:no_results_msg, xpath: '//div[contains(text(),"Your search did not match any users with a CalNet ID.")]')
      div(:too_many_results_msg, xpath: '//div[contains(.,"Please refine your search to limit the number of results.")]')
      div(:blank_search_msg, xpath: '//div[contains(text(),"You did not enter any search terms. Please try again.")]')
      div(:success_msg, xpath: '//div[@class="bc-alert bc-alert-success bc-page-course-add-user-alert"]')

      text_area(:search_term, id: 'search-text')
      select_list(:search_type, id: 'search-type')
      button(:search_button, id: 'submit-search')

      button(:need_help_button, xpath: '//button[contains(text(),"Need help finding someone?")]')
      div(:help_notice, id: 'bc-page-help-notice')
      link(:cal_net_dir_link, xpath: '//a[contains(text(),"CalNet Directory")]')
      link(:cal_net_guest_acct_link, xpath: '//a[contains(text(),"CalNet Guest Account")]')
      link(:bcourses_help_link, xpath: '//a[contains(text(),"bCourses help page")]')

      table(:results_table, xpath: '//h2[text()="User Search Results"]/following-sibling::div//table')

      select_list(:user_role, id: 'user-role')
      select_list(:course_section, id: 'course-section')
      button(:add_user_button, xpath: '//button[contains(text(), "Add User")]')
      button(:start_over_button, xpath: '//button[contains(text(), "Start Over")]')

      # Loads the LTI tool in the context of a Canvas course site
      # @param course [Course]
      def load_embedded_tool(course)
        logger.info 'Loading embedded version of Find a Person to Add tool'
        load_tool_in_canvas("/courses/#{course.site_id}/external_tools/#{JunctionUtils.canvas_course_add_user_tool}")
      end

      # Loads the LTI tool in the Junction context
      # @param course [Course]
      def load_standalone_tool(course)
        logger.info 'Loading standalone version of Find a Person to Add tool'
        navigate_to "#{JunctionUtils.junction_base_url}/canvas/course_add_user/#{course.site_id}"
      end

      # Expands the maintenance notice and confirms its visibility
      def expand_maintenance_notice
        wait_for_load_and_click_js maintenance_button_element
        maintenance_detail_element.when_visible Utils.short_wait
      end

      # Hides the maintenance notice and confirms it invisibility
      def hide_maintenance_notice
        wait_for_load_and_click_js maintenance_button_element
        maintenance_detail_element.when_not_visible Utils.short_wait
      end

      # Expands the help notice and confirms its visibility
      def expand_help_notice
        wait_for_load_and_click_js need_help_button_element
        help_notice_element.when_visible Utils.short_wait
      end

      # Hides the help notice and confirms its invisibility
      def hide_help_notice
        wait_for_load_and_click_js need_help_button_element
        help_notice_element.when_not_visible Utils.short_wait
      end

      # Searches for a user using a search term string and a select option string
      # @param text [String]
      # @param option [String]
      def search(text, option)
        logger.info "Searching for string '#{text}' by #{option}"
        search_type_element.when_visible Utils.medium_wait
        wait_for_element_and_select_js(search_type_element, option)
        wait_for_element_and_type_js(search_term_element, text)
        wait_for_update_and_click_js search_button_element
      end

      # Returns all user names displayed in search results
      # @return [Array<String>]
      def name_results
        (span_elements(xpath: '//span[contains(@data-ng-bind,"user.firstName")]').map &:text).to_a
      end

      # Returns all user UIDs displayed in search results
      # @return [Array<String>]
      def uid_results
        (span_elements(xpath: '//span[@data-ng-bind="user.ldapUid"]').map &:text).to_a
      end

      # Returns all user email addresses displayed in search results
      # @return [Array<String>]
      def email_results
        (cell_elements(xpath: '//td[@data-ng-bind="user.emailAddress"]').map &:text).to_a
      end

      # Returns the checkbox element for selecting a user in search results
      # @param user [User]
      # @return [PageObject::Elements::Checkbox]
      def user_checkbox(user)
        checkbox_element(xpath: "//span[contains(.,'#{user.uid}')]/ancestor::tr//input[@name='selectedUser']")
      end

      # Selects a user, a course section, and a user role; clicks the add button; and waits for the success message
      # @param user [User]
      # @param section [Section]
      # @param event [Event]
      def add_user_by_uid(user, section = nil, event = nil)
        logger.info "Adding UID #{user.uid} with role '#{user.role}'%s" % (" to section '#{section.course} #{section.label}'" if section)
        user_checkbox(user).when_present Utils.medium_wait
        user_checkbox(user).check
        if section
          option = section.sis_id ? section.sis_id : "#{section.course} #{section.label}"
          wait_for_element_and_select_js(course_section_element, option)
        end
        wait_for_element_and_select_js(user_role_element, user.role)
        wait_for_update_and_click_js add_user_button_element
        success_msg_element.when_visible Utils.medium_wait
        add_event(event, EventType::CREATE, user.full_name)
      end

    end
  end
end
