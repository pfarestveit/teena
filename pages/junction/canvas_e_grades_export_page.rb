require_relative '../../util/spec_helper'

module Page

  module JunctionPages

    class CanvasEGradesExportPage

      include PageObject
      include Logging
      include Page
      include JunctionPages

      link(:back_to_gradebook_link, text: 'Back to Gradebook')
      paragraph(:not_auth_msg, xpath: '//p[contains(.,"You must be a teacher in this bCourses course to export to E-Grades CSV.")]')

      link(:how_to_post_grades_link, xpath: '//a[contains(.,"How do I post grades for an assignment?")]')

      link(:course_settings_button, text: 'Course Settings')

      button(:cancel_button, xpath: '//button[contains(.,"Cancel")]')
      button(:continue_button, xpath: '//button[contains(.,"Continue")]')

      radio_button(:pnp_cutoff_radio, id: 'input-enable-pnp-conversion-true')
      radio_button(:no_pnp_cutoff_radio, id: 'input-enable-pnp-conversion-false')
      select_list(:cutoff_select, id: 'select-pnp-grade-cutoff')
      select_list(:sections_select, id: 'course-sections')
      button(:download_current_grades, xpath: '//button[contains(text(), "Download Current Grades")]')
      button(:download_final_grades, xpath: '//button[contains(text(), "Download Final Grades")]')
      link(:bcourses_to_egrades_link, xpath: '//a[contains(.,"From bCourses to E-Grades")]')

      def embedded_tool_path(course)
        "/courses/#{course.site_id}/external_tools/#{JunctionUtils.canvas_e_grades_export_tool}"
      end

      def hit_embedded_tool_url(course)
        navigate_to "#{Utils.canvas_base_url}#{embedded_tool_path course}"
      end

      # Loads the LTI tool in the context of a Canvas course site
      # @param course [Course]
      def load_embedded_tool(course)
        load_tool_in_canvas embedded_tool_path(course)
      end

      # Loads the LTI tool in the Junction context
      # @param course [Course]
      def load_standalone_tool(course)
        navigate_to "#{JunctionUtils.junction_base_url}/canvas/course_grade_export/#{course.site_id}"
      end

      def click_course_settings_button
        wait_for_load_and_click course_settings_button_element
      end

      # Clicks the Cancel button
      def click_cancel
        logger.debug 'Clicking cancel'
        wait_for_load_and_click cancel_button_element
      end

      # Clicks the Continue button
      def click_continue
        logger.debug 'Clicking continue'
        wait_for_load_and_click continue_button_element
      end

      # Selects a given P/NP grade cutoff
      def set_cutoff(cutoff)
        if cutoff
          logger.info "Setting P/NP cutoff to '#{cutoff}'"
          wait_for_element_and_select(cutoff_select_element, cutoff)
        else
          logger.info 'Setting no P/NP cutoff'
          wait_for_update_and_click no_pnp_cutoff_radio_element
        end
      end

      # Selects a section for which to download the E-Grades CSV and preps the download dir to receive the file
      # @param section [Section]
      def choose_section(section)
        # Parenthetical in section labels isn't shown on e-grades tool
        label = section.label.include?('(') ? section.label.split(' (').first : section.label
        section_name = "#{section.course} #{label}"
        Utils.prepare_download_dir
        wait_for_element_and_select(sections_select_element, section_name)
      end

      # Converts a parsed CSV to an array of hashes
      # @param [Array<Array>]
      # @return [Array<Hash>]
      def grades_to_hash(csv)
        csv.map { |r| r.to_hash }
      end

      # Downloads current grades for a given section
      # @param course [Course]
      # @param section [Section]
      # @param cutoff [String]
      # @return [Array<Hash>]
      def download_current_grades(course, section, cutoff = nil)
        logger.info "Downloading current grades for #{course.code} #{section.label}"
        load_embedded_tool course
        click_continue
        set_cutoff cutoff
        choose_section section if course.sections.length > 1
        file_name = "egrades-current-#{section.id}-#{course.term.gsub(' ', '-')}-*.csv"
        parse_downloaded_csv(download_current_grades_element, file_name)
      end

      # Downloads final grades for a given section
      # @param course [Course]
      # @param section [Section]
      # @param cutoff [String]
      # @return [Array<Hash>]
      def download_final_grades(course, section, cutoff = nil)
        logger.info "Downloading final grades for #{course.code} #{section.label}"
        load_embedded_tool course
        click_continue
        set_cutoff cutoff
        choose_section section if course.sections.length > 1
        file_name = "egrades-final-#{section.id}-#{course.term.gsub(' ', '-')}-*.csv"
        parse_downloaded_csv(download_final_grades_element, file_name)
      end

    end
  end
end
