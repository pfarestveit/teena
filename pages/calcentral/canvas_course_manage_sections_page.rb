require_relative '../../util/spec_helper'

module Page

  module CalCentralPages

    class CanvasCourseManageSectionsPage

      include PageObject
      include Logging
      include Page
      include CalCentralPages

      link(:official_sections_link, text: 'Official Sections')
      button(:edit_sections_button, xpath: '//button[contains(text(),"Edit Sections")]')

      button(:maintenance_notice_button, xpath: '//button[contains(.,"From 8 - 9 AM, you may experience delays of up to 10 minutes")]')
      paragraph(:maintenance_detail, xpath: '//p[contains(.,"bCourses performs scheduled maintenance every day between 8-9AM, during which time bCourses user and enrollment information is synchronized with other campus systems. This process may cause delays of up to 10 minutes before your request is completed.")]')
      link(:bcourses_service_link, xpath: '//a[contains(.,"bCourses service page")]')

      table(:current_sections_table, xpath: '//h3[contains(text(),"Sections in this Course Site")]/../../following-sibling::div//table')
      button(:save_changes_button, xpath: '//button[contains(text(),"Save Changes")]')
      button(:cancel_button, xpath: '//button[contains(text(),"Cancel")]')

      h2(:updating_sections_msg, xpath: '//h2[contains(text(),"Updating Official Sections in Course Site")]')
      span(:sections_updated_msg, xpath: '//span[contains(text(),"The sections in this course site have been updated successfully.")]')
      button(:update_msg_close_button, xpath: '//button[@aria-controls="bc-page-course-official-sections-job-status-notice"]')

      h1(:unexpected_error, xpath: '//h1[contains(text(),"Unexpected Error")]')

      # Loads the Official Sections LTI tool within a course site
      # @param driver [Selenium::WebDriver]
      # @param course [Course]
      def load_embedded_tool(driver, course)
        navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/external_tools/#{Utils.canvas_official_sections_tool}"
        switch_to_canvas_iframe driver
      end

      # Loads the standalone version of the Official Sections tool
      # @param course [Course]
      def load_standalone_tool(course)
        navigate_to "#{Utils.calcentral_base_url}/canvas/course_manage_official_sections/#{course.site_id}"
      end

      # Clicks the sidebar Official Sections link and shifts focus to the tool
      # @param driver [Selenium::WebDriver]
      def click_official_sections_link(driver)
        logger.info 'Clicking Official Sections link'
        wait_for_page_load_and_click official_sections_link_element
        switch_to_canvas_iframe driver
      end

      # Clicks the Edit Sections button and waits for the available sections table to appear
      def click_edit_sections
        logger.debug 'Clicking edit sections button'
        wait_for_page_load_and_click edit_sections_button_element
        save_changes_button_element.when_visible Utils.short_wait
      end

      # Clicks the Save Changes button on the editing interface
      def click_save_changes
        logger.debug 'Clicking save changes button'
        wait_for_page_update_and_click save_changes_button_element
      end

      # Closes the 'success' message after sections are updated
      def close_section_update_success
        logger.debug 'Closing the section update success message'
        wait_for_page_update_and_click update_msg_close_button_element
      end

      # CURRENT SECTIONS

      # Returns the table element containing sections currently in the site
      # @return [PageObject::Elements::Table]
      def current_sections_table
        table_element(xpath: "//h3[contains(text(),'Sections in this Course Site')]/../../following-sibling::div//table")
      end

      # Returns the number of sections currently in the site by counting the 'Sections in this Course Site' table rows minus the heading row
      # @return [Integer]
      def current_sections_count
        current_sections_table_element.when_visible Utils.short_wait
        current_sections_table_element.rows - 1
      end

      # Returns the 'Sections in this Course Site' table cell element containing a given section ID
      # @param section [Section]
      # @return [PageObject::Elements::TableCell]
      def current_section_id_element(section)
        cell_element(xpath: "//h3[contains(text(),'Sections in this Course Site')]/../../following-sibling::div//table//td[contains(.,'#{section.id}')]")
      end

      # Returns the course code displayed for a given section in the 'Sections in this Course Site' table
      # @param section [Section]
      # @return [String]
      def current_section_course(section)
        cell_element(xpath: "//h3[contains(text(),'Sections in this Course Site')]/../../following-sibling::div//table//td[contains(.,'#{section.id}')]/preceding-sibling::td[contains(@class,'course-code')]").text
      end

      # Returns the label displayed for a given section in the 'Sections in this Course Site' table
      # @param section [Section]
      # @return [String]
      def current_section_label(section)
        cell_element(xpath: "//h3[contains(text(),'Sections in this Course Site')]/../../following-sibling::div//table//td[contains(.,'#{section.id}')]/preceding-sibling::td[contains(@class,'section-label')]").text
      end

      # Returns the schedules displayed for a given section in the 'Sections in this Course Site' table
      # @param section [Section]
      # @return [String]
      def current_section_schedules(section)
        cell_element(xpath: "//h3[contains(text(),'Sections in this Course Site')]/../../following-sibling::div//table//td[contains(.,'#{section.id}')]/following-sibling::td[contains(@class,'section-timestamps')]").text
      end

      # Returns the locations displayed for a given section in the 'Sections in this Course Site' table
      # @param section [Section]
      # @return [String]
      def current_section_locations(section)
        cell_element(xpath: "//h3[contains(text(),'Sections in this Course Site')]/../../following-sibling::div//table//td[contains(.,'#{section.id}')]/following-sibling::td[contains(@class,'section-locations')]").text
      end

      # Returns the instructors displayed for a given section in the 'Sections in this Course Site' table
      # @param section [Section]
      # @return [String]
      def current_section_instructors(section)
        cell_element(xpath: "//h3[contains(text(),'Sections in this Course Site')]/../../following-sibling::div//table//td[contains(.,'#{section.id}')]/following-sibling::td[contains(@class,'section-instructors')]").text
      end

      # Returns the Delete button element for a given section in the 'Sections in this Course Site' table
      # @param section [Section]
      # @return [PageObject::Elements::Button]
      def section_delete_button(section)
        button_element(xpath: "//h3[contains(text(),'Sections in this Course Site')]/../../following-sibling::div//table//td[contains(.,'#{section.id}')]/following-sibling::td[contains(@class,'section-action-option')]//button[contains(.,'Delete')]")
      end

      # Clicks the Delete button for a given section in the 'Sections in this Course Site' table and pauses to allow the DOM to update
      # @param section [Section]
      def click_delete_section(section)
        logger.debug "Clicking delete button for section #{section.id}"
        wait_for_page_update_and_click section_delete_button(section)
        sleep 1
      end

      # Deletes a collection of sections and saves the changes
      # @param sections [Array<Section>]
      def delete_sections(sections)
        sections.each { |section| click_delete_section(section) }
        click_save_changes
      end

      # Returns the Undo Add button element for a given section in the 'Sections in this Course Site' table
      # @param section [Section]
      # @return [PageObject::Elements::Button]
      def section_undo_add_button(section)
        button_element(xpath: "//h3[contains(text(),'Sections in this Course Site')]/../../following-sibling::div//table//td[contains(.,'#{section.id}')]/following-sibling::td[contains(@class,'section-action-option')]//button[contains(.,'Undo Add')]")
      end

      # Clicks the Undo Add button for a given section in the 'Sections in this Course Site' table and pauses to allow the DOM to update
      # @param section [Section]
      def click_undo_add_section(section)
        logger.debug "Clicking undo add button for section #{section.id}"
        wait_for_page_update_and_click section_undo_add_button(section)
        sleep 1
      end

      # AVAILABLE SECTIONS

      # Returns the button element to expand or collapse the table of available sections in a course
      # @param course_code [String]
      # @return [PageObject::Elements::Button]
      def available_sections_form_button(course_code)
        button_element(xpath: "//button[contains(@class,'sections-form-course-button')][contains(.,'#{course_code}')]")
      end

      def available_sections_course_title(course_code)
        span_element(xpath: "//button[contains(@class,'sections-form-course-button')][contains(.,'#{course_code}')]//span[contains(.,'course.title')]").when_visible Utils.short_wait
        span_element(xpath: "//button[contains(@class,'sections-form-course-button')][contains(.,'#{course_code}')]//span[contains(.,'course.title')]").text
      end

      # Returns the table element containing a given course's sections available to add to a course site
      # @param course_code [String]
      # @return [PageObject::Elements::Table]
      def available_sections_table(course_code)
        table_element(xpath: "//button[contains(@class,'sections-form-course-button')][contains(.,'#{course_code}')]//following-sibling::div//table")
      end

      # Expands the table of available sections in a course
      # @param course_code [String]
      def expand_available_sections(course_code)
        if available_sections_table(course_code).visible?
          logger.debug "The sections table is already expanded for #{course_code}"
        else
          wait_for_page_update_and_click available_sections_form_button(course_code)
          available_sections_table(course_code).when_visible Utils.short_wait
        end
      end

      # Collapses the table of available sections in a course
      # @param course_code [String]
      def collapse_available_sections(course_code)
        if available_sections_table(course_code).visible?
          wait_for_page_update_and_click available_sections_form_button(course_code)
          available_sections_table(course_code).when_not_visible Utils.short_wait
        else
          logger.debug "The sections table is already collapsed for #{course_code}"
        end
      end

      # Returns the number of a given course's sections available to add to a course site by counting the table rows minus the heading row
      # @param driver [Selenium::WebDriver]
      # @param course [Course]
      # @return [Integer]
      def available_sections_count(driver, course)
        driver.find_elements(xpath: "//button[contains(@class,'sections-form-course-button')][contains(.,'#{course.code}')]//following-sibling::div//table/tbody").length
      end

      # Returns the 'Sections in this Course Site' table cell element containing a given section ID
      # @param section [Section]
      # @return [PageObject::Elements::TableCell]
      def available_section_id_element(course, section)
        cell_element(xpath: "//button[contains(@class,'sections-form-course-button')][contains(.,'#{course.code}')]//following-sibling::div//table//td[contains(.,'#{section.id}')]")
      end

      # Returns the course code displayed for a given section in a course's available sections
      # @param course [Course]
      # @param section [Section]
      # @return [String]
      def available_section_course(course, section)
        cell_element(xpath: "//button[contains(@class,'sections-form-course-button')][contains(.,'#{course.code}')]//following-sibling::div//table//td[contains(.,'#{section.id}')]/preceding-sibling::td[contains(@class,'course-code')]").text
      end

      # Returns the label displayed for a given section in a course's available sections
      # @param course [Course]
      # @param section [Section]
      # @return [String]
      def available_section_label(course, section)
        cell_element(xpath: "//button[contains(@class,'sections-form-course-button')][contains(.,'#{course.code}')]//following-sibling::div//table//td[contains(.,'#{section.id}')]/preceding-sibling::td[contains(@class,'section-label')]").text
      end

      # Returns the schedules displayed for a given section in a course's available sections
      # @param course [Course]
      # @param section [Section]
      # @return [String]
      def available_section_schedules(course, section)
        cell_element(xpath: "//button[contains(@class,'sections-form-course-button')][contains(.,'#{course.code}')]//following-sibling::div//table//td[contains(.,'#{section.id}')]/following-sibling::td[contains(@class,'section-timestamps')]").text
      end

      # Returns the locations displayed for a given section in a course's available sections
      # @param course [Course]
      # @param section [Section]
      # @return [String]
      def available_section_locations(course, section)
        cell_element(xpath: "//button[contains(@class,'sections-form-course-button')][contains(.,'#{course.code}')]//following-sibling::div//table//td[contains(.,'#{section.id}')]/following-sibling::td[contains(@class,'section-locations')]").text
      end

      # Returns the instructors displayed for a given section in a course's available sections
      # @param course [Course]
      # @param section [Section]
      # @return [String]
      def available_section_instructors(course, section)
        cell_element(xpath: "//button[contains(@class,'sections-form-course-button')][contains(.,'#{course.code}')]//following-sibling::div//table//td[contains(.,'#{section.id}')]/following-sibling::td[contains(@class,'section-instructors')]").text
      end

      # Returns all the section IDs displayed in a course's available sections table
      # @param driver [Selenium::WebDriver]
      # @param course_code [String]
      # @return [Array<String>]
      def visible_section_ids(driver, course_code)
        elements = driver.find_elements(xpath: "//button[contains(.,'#{course_code}')]//following-sibling::div//table//td[contains(@class,'section-ccn')]")
        elements.map &:text
      end

      # Returns all the course codes displayed in a course's available sections table
      # @param driver [Selenium::WebDriver]
      # @param course_code [String]
      # @return [Array<String>]
      def visible_course_codes(driver, course_code)
        elements = driver.find_elements(xpath: "//button[contains(@class,'sections-form-course-button')][contains(.,'#{course_code}')]//following-sibling::div//table//td[contains(@class,'course-code')]")
        elements.map &:text
      end

      # Returns all the section labels displayed in a course's available sections table
      # @param driver [Selenium::WebDriver]
      # @param course_code [String]
      # @return [Array<String>]
      def visible_section_labels(driver, course_code)
        elements = driver.find_elements(xpath: "//button[contains(@class,'sections-form-course-button')][contains(.,'#{course_code}')]//following-sibling::div//table//td[contains(@class,'section-label')]")
        elements.map &:text
      end

      # Returns all the section schedules displayed in a course's available sections table
      # @param driver [Selenium::WebDriver]
      # @param course_code [String]
      # @return [Array<String>]
      def visible_section_schedules(driver, course_code)
        elements = driver.find_elements(xpath: "//button[contains(@class,'sections-form-course-button')][contains(.,'#{course_code}')]//following-sibling::div//table//td[contains(@class,'section-timestamps')]")
        elements.map &:text
      end

      # Returns all the section locations displayed in a course's available sections table
      # @param driver [Selenium::WebDriver]
      # @param course_code [String]
      # @return [Array<String>]
      def visible_section_locations(driver, course_code)
        elements = driver.find_elements(xpath: "//button[contains(@class,'sections-form-course-button')][contains(.,'#{course_code}')]//following-sibling::div//table//td[contains(@class,'section-locations')]")
        elements.map &:text
      end

      # Returns all the section instructors displayed in a course's available sections table
      # @param driver [Selenium::WebDriver]
      # @param course_code [String]
      # @return [Array<String>]
      def visible_section_instructors(driver, course_code)
        elements = driver.find_elements(xpath: "//button[contains(@class,'sections-form-course-button')][contains(.,'#{course_code}')]//following-sibling::div//table//td[contains(@class,'section-instructors')]")
        elements.map &:text
      end

      # Returns the Add button for a given section in a course's available sections table
      # @param course [Course]
      # @param section [Section]
      # @return [PageObject::Elements::Button]
      def section_add_button(course, section)
        button_element(xpath: "//button[contains(@class,'sections-form-course-button')][contains(.,'#{course.code}')]//following-sibling::div//table//td[contains(.,'#{section.id}')]/following-sibling::td[contains(@class,'section-action-option')]//button[contains(.,'Add')]")
      end

      # Clicks the Add button for a given section in a course's available sections table and pauses to allow the DOM to update
      # @param course [Course]
      # @param section [Section]
      def click_add_section(course, section)
        logger.debug "Clicking add button for section #{section.id}"
        wait_for_page_update_and_click section_add_button(course, section)
        sleep 1
      end

      # Adds a collection of sections from a course and saves changes
      # @param course [Course]
      # @param sections [Array<Section>]
      def add_sections(course, sections)
        sections.each { |section| click_add_section(course, section) }
        click_save_changes
      end

      # Returns the div containing the 'Added' message when a course section is staged for adding to the course site
      # @param course [Course]
      # @param section [Section]
      # @return [PageObject::Elements::Div]
      def section_added_element(course, section)
        div_element(xpath: "//button[contains(@class,'sections-form-course-button')][contains(.,'#{course.code}')]//following-sibling::div//table//td[contains(.,'#{section.id}')]/following-sibling::td[contains(@class,'section-action-option')]//div[contains(.,'Added')]")
      end

      # Returns the Undo Delete button for a given section in a course's available sections table
      # @param course [Course]
      # @param section [Section]
      # @return [PageObject::Elements::Button]
      def section_undo_delete_button(course, section)
        button_element(xpath: "//button[contains(@class,'sections-form-course-button')][contains(.,'#{course.code}')]//following-sibling::div//table//td[contains(.,'#{section.id}')]/following-sibling::td[contains(@class,'section-action-option')]//button[contains(.,'Undo Delete')]")
      end

      # Clicks the Undo Delete button for a given section in a course's available sections table and pauses to allow the DOM to update
      # @param course [Course]
      # @param section [Section]
      def click_undo_delete_section(course, section)
        logger.debug "Clicking undo delete button section #{section.id}"
        wait_for_page_update_and_click section_undo_delete_button(course, section)
        sleep 1
      end

    end
  end
end
