require_relative '../../util/spec_helper'

module Page

  module CalCentralPages

    class CanvasCourseAddUserPage

      include PageObject
      include Logging
      include Page
      include CalCentralPages

      button(:maintenance_button, class: 'bc-template-canvas-maintenance-notice-button')
      span(:maintenance_notice, class: 'bc-template-canvas-maintenance-notice-text')
      paragraph(:maintenance_detail, xpath: '//div[@id="maintenance-details"]//p')
      link(:bcourses_service_link, xpath: '//a[contains(text(),"bCourses service page")]')

      h1(:page_heading, xpath: '//h1[text()="Find a Person to Add"]')

      span(:no_access_msg, xpath: '//span[text()="You must be a teacher in this bCourses course to import users."]')
      span(:no_sections_msg, xpath: '//span[text()="Course sections failed to load"]')
      div(:no_results_msg, xpath: '//div[contains(text(),"Your search did not match any users with a CalNet ID.")]')
      div(:too_many_results_msg, xpath: '//div[contains(.,"Please refine your search to limit the number of results.")]')
      div(:blank_search_msg, xpath: '//div[contains(text(),"You did not enter any search terms. Please try again.")]')
      div(:success_msg, xpath: '//div[@data-ng-show="additionSuccessMessage"]')

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
      button(:add_user_button, xpath: '//button[text()="Add User"]')
      button(:start_over_button, xpath: '//button[text()="Start Over"]')

      # Loads the LTI tool in the context of a Canvas course site
      # @param driver [Selenium::WebDriver]
      # @param course [Course]
      def load_embedded_tool(driver, course)
        logger.info 'Loading embedded version of Find a Person to Add tool'
        navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/external_tools/#{Utils.canvas_course_add_user_tool}"
        switch_to_canvas_iframe driver
      end

      # Loads the LTI tool in the CalCentral context
      # @param course [Course]
      def load_standalone_tool(course)
        logger.info 'Loading standalone version of Find a Person to Add tool'
        navigate_to "#{Utils.calcentral_base_url}/canvas/course_add_user/#{course.site_id}"
      end

      # Expands the maintenance notice and confirms its visibility
      def expand_maintenance_notice
        wait_for_page_load_and_click maintenance_button_element
        maintenance_detail_element.when_visible Utils.short_wait
      end

      # Hides the maintenance notice and confirms it invisibility
      def hide_maintenance_notice
        wait_for_page_load_and_click maintenance_button_element
        maintenance_detail_element.when_not_visible Utils.short_wait
      end

      # Expands the help notice and confirms its visibility
      def expand_help_notice
        wait_for_page_load_and_click need_help_button_element
        help_notice_element.when_visible Utils.short_wait
      end

      # Hides the help notice and confirms its invisibility
      def hide_help_notice
        wait_for_page_load_and_click need_help_button_element
        help_notice_element.when_not_visible Utils.short_wait
      end

      # Searches for a user using a search term string and a select option string
      # @param text [String]
      # @param option [String]
      def search(text, option)
        logger.info "Searching for string '#{text}' by #{option}"
        search_type_element.when_visible Utils.short_wait
        self.search_type = option
        wait_for_element_and_type(search_term_element, text)
        wait_for_page_update_and_click search_button_element
      end

      # Returns all user names displayed in search results
      # @param driver [Selenium::WebDriver]
      # @return [Array<String>]
      def name_results(driver)
        (driver.find_elements(xpath: '//span[contains(@data-ng-bind,"user.firstName")]').map &:text).to_a
      end

      # Returns all user UIDs displayed in search results
      # @param driver [Selenium::WebDriver]
      # @return [Array<String>]
      def uid_results(driver)
        (driver.find_elements(xpath: '//span[@data-ng-bind="user.ldapUid"]').map &:text).to_a
      end

      # Returns all user email addresses displayed in search results
      # @param driver [Selenium::WebDriver]
      # @return [Array<String>]
      def email_results(driver)
        (driver.find_elements(xpath: '//td[@data-ng-bind="user.emailAddress"]').map &:text).to_a
      end

      # Returns the checkbox element for selecting a user in search results
      # @param user [User]
      # @return [PageObject::Elements::Checkbox]
      def user_checkbox(user)
        checkbox_element(xpath: "//span[contains(text(),#{user.uid})]/ancestor::tr//input[@name='selectedUser']")
      end

      # Selects a user, a course section, and a user role; clicks the add button; and waits for the success message
      # @param user [User]
      # @param section [Section]
      def add_user_by_uid(user, section)
        logger.info "Adding UID #{user.uid} with role '#{user.role}' to section '#{section.code}'"
        user_checkbox(user).when_present Utils.medium_wait
        user_checkbox(user).check
        course_section_element.when_visible Utils.short_wait
        self.course_section = section.code
        self.user_role = user.role
        wait_for_page_update_and_click add_user_button_element
        success_msg_element.when_visible Utils.medium_wait
      end

    end
  end
end
