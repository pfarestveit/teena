require_relative '../../util/spec_helper'

module Page

  module JunctionPages

    class CanvasCourseManageSectionsPage < CanvasCourseSectionsPage

      include PageObject
      include Logging
      include Page
      include JunctionPages

      link(:official_sections_link, text: 'Official Sections')
      button(:edit_sections_button, xpath: '//button[contains(text(),"Edit Sections")]')

      button(:maintenance_notice_button, xpath: '//button[contains(.,"From 8 - 9 AM, you may experience delays of up to 10 minutes")]')
      paragraph(:maintenance_detail, xpath: '//p[contains(.,"bCourses performs scheduled maintenance every day between 8-9AM, during which time bCourses user and enrollment information is synchronized with other campus systems. This process may cause delays of up to 10 minutes before your request is completed.")]')
      link(:bcourses_service_link, xpath: '//a[contains(.,"bCourses service page")]')
      div(:section_name_msg, xpath: '//div[@class="bc-template-sections-table-sites-container"][contains(., "The section name in bCourses no longer matches the Student Information System.")]')

      elements(:current_sections_table_row, :row, xpath: '//h3[contains(text(),"Sections in this Course Site")]/../../following-sibling::div//table//tr')
      button(:save_changes_button, xpath: '//button[contains(text(),"Save Changes")]')
      button(:cancel_button, xpath: '//button[contains(text(),"Cancel")]')

      h2(:updating_sections_msg, xpath: '//h2[contains(text(),"Updating Official Sections in Course Site")]')
      div(:sections_updated_msg, xpath: '//div[contains(text(),"The sections in this course site have been updated successfully.")]')
      button(:update_msg_close_button, xpath: '//button[@aria-controls="bc-page-course-official-sections-job-status-notice"]')

      def embedded_tool_path(course)
        "/courses/#{course.site_id}/external_tools/#{JunctionUtils.canvas_official_sections_tool}"
      end

      def hit_embedded_tool_url(course)
        navigate_to "#{Utils.canvas_base_url}#{embedded_tool_path course}"
      end

      # Loads the Official Sections LTI tool within a course site
      # @param course [Course]
      def load_embedded_tool(course)
        load_tool_in_canvas embedded_tool_path(course)
      end

      # Loads the standalone version of the Official Sections tool
      # @param course [Course]
      def load_standalone_tool(course)
        navigate_to "#{JunctionUtils.junction_base_url}/canvas/course_manage_official_sections/#{course.site_id}"
      end

      # Clicks the Edit Sections button and waits for the available sections table to appear
      def click_edit_sections
        logger.debug 'Clicking edit sections button'
        wait_for_load_and_click_js edit_sections_button_element
        save_changes_button_element.when_visible Utils.short_wait
      end

      # Clicks the Save Changes button on the editing interface
      def click_save_changes
        logger.debug 'Clicking save changes button'
        wait_for_update_and_click_js save_changes_button_element
      end

      def save_changes_and_wait_for_success
        click_save_changes
        updating_sections_msg_element.when_visible Utils.short_wait
        sections_updated_msg_element.when_visible Utils.long_wait
      end

      # Closes the 'success' message after sections are updated
      def close_section_update_success
        logger.debug 'Closing the section update success message'
        wait_for_update_and_click_js update_msg_close_button_element
      end

      # CURRENT SECTIONS

      def current_sections_table_xpath
        '//h3[contains(text(), "Sections in this Course Site")]/../../following-sibling::div//table'
      end

      def current_section_id_cell_xpath(section)
        "#{current_sections_table_xpath}//td[contains(.,'#{section.id}')]"
      end

      # Returns the table element containing sections currently in the site
      # @return [PageObject::Elements::Table]
      def current_sections_table
        table_element(xpath: current_sections_table_xpath)
      end

      # Returns the number of sections currently in the site by counting the 'Sections in this Course Site' table rows minus the heading row
      # @return [Integer]
      def current_sections_count
        wait_until(Utils.short_wait) { current_sections_table_row_elements.any? }
        current_sections_table_row_elements.length - 1
      end

      # Returns the 'Sections in this Course Site' table cell element containing a given section ID
      # @param section [Section]
      # @return [PageObject::Elements::TableCell]
      def current_section_id_element(section)
        cell_element(xpath: current_section_id_cell_xpath(section))
      end

      # Returns the course code displayed for a given section in the 'Sections in this Course Site' table
      # @param section [Section]
      # @return [String]
      def current_section_course(section)
        cell_element(xpath: "#{current_section_id_cell_xpath(section)}/preceding-sibling::td[contains(@class,'course-code')]").text
      end

      # Returns the label displayed for a given section in the 'Sections in this Course Site' table
      # @param section [Section]
      # @return [String]
      def current_section_label(section)
        cell_element(xpath: "#{current_section_id_cell_xpath(section)}/preceding-sibling::td[contains(@class,'section-label')]").text
      end

      # Returns the Update button element for a given section in the 'Sections in this Course Site' table
      # @param section [Section]
      # @return [PageObject::Elements::Button]
      def section_update_button(section)
        button_element(xpath: "#{current_section_id_cell_xpath(section)}/following-sibling::td[contains(@class,'section-action-option')]//button[contains(.,'Update')]")
      end

      # Clicks the Update button for a given section in the 'Sections in this Course Site' table and pauses to allow the DOM to update
      # @param section [Section]
      def click_update_section(section)
        logger.debug "Clicking update button for section #{section.id}"
        wait_for_update_and_click_js section_update_button(section)
        sleep 1
      end

      # Returns the Delete button element for a given section in the 'Sections in this Course Site' table
      # @param section [Section]
      # @return [PageObject::Elements::Button]
      def section_delete_button(section)
        button_element(xpath: "#{current_section_id_cell_xpath(section)}/following-sibling::td[contains(@class,'section-action-option')]//button[contains(.,'Delete')]")
      end

      # Clicks the Delete button for a given section in the 'Sections in this Course Site' table and pauses to allow the DOM to update
      # @param section [Section]
      def click_delete_section(section)
        logger.debug "Clicking delete button for section #{section.id}"
        wait_for_update_and_click_js section_delete_button(section)
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
        button_element(xpath: "#{current_section_id_cell_xpath(section)}/following-sibling::td[contains(@class,'section-action-option')]//button[contains(.,'Undo Add')]")
      end

      # Clicks the Undo Add button for a given section in the 'Sections in this Course Site' table and pauses to allow the DOM to update
      # @param section [Section]
      def click_undo_add_section(section)
        logger.debug "Clicking undo add button for section #{section.id}"
        wait_for_update_and_click_js section_undo_add_button(section)
        sleep 1
      end

      # AVAILABLE SECTIONS

      def available_sections_table_xpath(course_code)
        "//button[contains(@class,'sections-form-course-button')][contains(.,'#{course_code}')]//following-sibling::div//table"
      end

      def available_section_cell_xpath(course_code, section_id)
        "#{available_sections_table_xpath(course_code)}//td[contains(.,'#{section_id}')]"
      end

      # Returns the number of a given course's sections available to add to a course site by counting the table rows minus the heading row
      # @param course [Course]
      # @return [Integer]
      def available_sections_count(course)
        div_elements(xpath: "#{available_sections_table_xpath(course.code)}/tbody").length
      end

      # Returns a hash of data displayed for a given section ID in a course's available sections table
      # @param course_code [String]
      # @param section_id [String]
      # @return [Hash]
      def available_section_data(course_code, section_id)
        {
          code: available_section_course(course_code, section_id),
          label: available_section_label(course_code, section_id),
          schedules: available_section_schedules(course_code, section_id),
          locations: available_section_locations(course_code, section_id),
          instructors: available_section_instructors(course_code, section_id)
        }
      end

      # Returns the 'Sections in this Course Site' table cell element containing a given section ID
      # @param section_id [String]
      # @return [PageObject::Elements::TableCell]
      def available_section_id_element(course_code, section_id)
        cell_element(xpath: "#{available_sections_table_xpath(course_code)}//td[contains(.,'#{section_id}')]")
      end

      # Returns the course code displayed for a given section in a course's available sections
      # @param course_code [String]
      # @param section_id [String]
      # @return [String]
      def available_section_course(course_code, section_id)
        cell_element(xpath: "#{available_section_cell_xpath(course_code, section_id)}/preceding-sibling::td[contains(@class,'course-code')]").text
      end

      # Returns the label displayed for a given section in a course's available sections
      # @param course_code [String]
      # @param section_id [String]
      # @return [String]
      def available_section_label(course_code, section_id)
        cell_element(xpath: "#{available_section_cell_xpath(course_code, section_id)}/preceding-sibling::td[contains(@class,'section-label')]").text
      end

      # Returns the schedules displayed for a given section in a course's available sections
      # @param course_code [String]
      # @param section_id [String]
      # @return [String]
      def available_section_schedules(course_code, section_id)
        cell_element(xpath: "#{available_section_cell_xpath(course_code, section_id)}/following-sibling::td[contains(@class,'section-timestamps')]").text
      end

      # Returns the locations displayed for a given section in a course's available sections
      # @param course_code [String]
      # @param section_id [String]
      # @return [String]
      def available_section_locations(course_code, section_id)
        cell_element(xpath: "#{available_section_cell_xpath(course_code, section_id)}/following-sibling::td[contains(@class,'section-locations')]").text
      end

      # Returns the instructors displayed for a given section in a course's available sections
      # @param course_code [String]
      # @param section_id [String]
      # @return [String]
      def available_section_instructors(course_code, section_id)
        cell_element(xpath: "#{available_section_cell_xpath(course_code, section_id)}/following-sibling::td[contains(@class,'section-instructors')]").text
      end

      # Returns the Add button for a given section in a course's available sections table
      # @param course [Course]
      # @param section [Section]
      # @return [PageObject::Elements::Button]
      def section_add_button(course, section)
        button_element(xpath: "#{available_section_cell_xpath(course.code, section.id)}/following-sibling::td[contains(@class,'section-action-option')]//button[contains(.,'Add')]")
      end

      # Clicks the Add button for a given section in a course's available sections table and pauses to allow the DOM to update
      # @param course [Course]
      # @param section [Section]
      def click_add_section(course, section)
        logger.debug "Clicking add button for section #{section.id}"
        wait_for_update_and_click_js section_add_button(course, section)
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
        div_element(xpath: "#{available_section_cell_xpath(course.code, section.id)}/following-sibling::td[contains(@class,'section-action-option')]//div[contains(.,'Added')]")
      end

      # Returns the Undo Delete button for a given section in a course's available sections table
      # @param course [Course]
      # @param section [Section]
      # @return [PageObject::Elements::Button]
      def section_undo_delete_button(course, section)
        button_element(xpath: "#{available_section_cell_xpath(course.code, section.id)}/following-sibling::td[contains(@class,'section-action-option')]//button[contains(.,'Undo Delete')]")
      end

      # Clicks the Undo Delete button for a given section in a course's available sections table and pauses to allow the DOM to update
      # @param course [Course]
      # @param section [Section]
      def click_undo_delete_section(course, section)
        logger.debug "Clicking undo delete button section #{section.id}"
        wait_for_update_and_click_js section_undo_delete_button(course, section)
        sleep 1
      end

    end
  end
end
