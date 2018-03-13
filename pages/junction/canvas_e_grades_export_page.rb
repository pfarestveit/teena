require_relative '../../util/spec_helper'

module Page

  module JunctionPages

    class CanvasEGradesExportPage

      include PageObject
      include Logging
      include Page
      include JunctionPages

      link(:back_to_gradebook_link, text: 'Back to Gradebook')
      span(:not_auth_msg, xpath: '//span[contains(.,"You must be a teacher in this bCourses course to export to E-Grades CSV.")]')

      h1(:required_adjustments_heading, xpath: '//h1[text()="Required adjustments before downloading E-Grades"]')
      h2(:un_mute_assignments_heading, xpath: '//h2[text()="Unmute All Assignments"]')
      link(:how_to_mute_link, xpath: '//a[contains(.,"How to mute assignments in Gradebook")]')
      button(:see_gradebook_button, xpath: '//button[contains(.,"See in Gradebook")]')
      checkbox(:un_mute_all_cbx, id: 'bc-page-course-grade-export-unmute-assignments')

      h2(:set_grading_scheme_heading, xpath: '//h2[text()="Set Grading Scheme"]')
      link(:how_to_set_scheme_link, xpath: '//a[contains(.,"How to set a Grading Scheme")]')
      button(:course_settings_button, xpath: '//button[contains(.,"Course Settings")]')
      checkbox(:set_scheme_cbx, id: 'bc-page-course-grade-export-enable-grading-scheme')

      button(:cancel_button, xpath: '//button[contains(.,"Cancel")]')
      button(:continue_button, xpath: '//button[contains(.,"Continue")]')

      select_list(:sections_select, id: 'course-sections')
      button(:download_current_grades, xpath: '//button[text()="Download Current Grades"]')
      button(:download_final_grades, xpath: '//button[text()="Download Final Grades"]')
      link(:bcourses_to_egrades_link, xpath: '//a[contains(.,"From bCourses to E-Grades")]')

      # Loads the LTI tool in the context of a Canvas course site
      # @param driver [Selenium::WebDriver]
      # @param course [Course]
      def load_embedded_tool(driver, course)
        load_tool_in_canvas(driver, "/courses/#{course.site_id}/external_tools/#{JunctionUtils.canvas_e_grades_export_tool}")
      end

      # Loads the LTI tool in the Junction context
      # @param course [Course]
      def load_standalone_tool(course)
        navigate_to "#{JunctionUtils.junction_base_url}/canvas/course_grade_export/#{course.site_id}"
      end

      # Clicks the 'un-mute all assignments' checkbox
      def click_un_mute_all
        logger.debug 'Clicking the un-mute checkbox'
        wait_for_load_and_click un_mute_all_cbx_element
      end

      # Clicks the 'set default grading scheme' checkbox
      def click_set_default_scheme
        logger.debug 'Clicking the set default scheme checkbox'
        wait_for_load_and_click set_scheme_cbx_element
      end

      # Clicks the Continue button
      def click_continue
        logger.debug 'Clicking continue'
        wait_for_load_and_click_js continue_button_element
      end

      # Sets the default grading scheme
      # @param driver [Selenium::WebDriver]
      # @param course [Course]
      def set_default_grading_scheme(driver, course)
        load_embedded_tool(driver, course)
        click_set_default_scheme
        click_continue
        download_final_grades_element.when_visible Utils.medium_wait
      end

      # Un-mutes any muted assignments and sets the default grading scheme
      # @param driver [Selenium::WebDriver]
      # @param course [Course]
      def resolve_all_issues(driver, course)
        load_embedded_tool(driver, course)
        required_adjustments_heading_element.when_present Utils.medium_wait
        if required_adjustments_heading_element.visible?
          logger.debug "Adjustments needed on site #{course.site_id}"
          un_mute_all_cbx_element.when_present Utils.short_wait
          sleep 1
          click_un_mute_all if un_mute_all_cbx_element.visible?
          click_set_default_scheme if set_scheme_cbx_element.visible?
          click_continue
          logger.debug 'Waiting for sections selection'
          sections_select_element.when_visible Utils.medium_wait
        else
          logger.debug "No adjustments needed on site #{course.site_id}"
        end
      end

      # Selects a section for which to download the E-Grades CSV and preps the download dir to receive the file
      # @param section [Section]
      def choose_section(section)
        section_name = "#{section.course} #{section.label}"
        Utils.prepare_download_dir
        wait_for_element_and_select_js(sections_select_element, section_name)
      end

      # Waits for the E-Grades CSV to download and then parses it
      # @param file_path [String]
      # @return [Array<Array>]
      def parse_grades_csv(file_path)
        wait_until(Utils.long_wait) { Dir[file_path].any? }
        file = Dir[file_path].first
        sleep 2
        CSV.read(file, headers: true, header_converters: :symbol)
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
      # @return [Array<Hash>]
      def download_current_grades(course, section)
        logger.info "Downloading current grades for #{course.code} #{section.label}"
        choose_section section if course.sections.length > 1
        wait_for_load_and_click download_current_grades_element
        file_path = "#{Utils.download_dir}/egrades-current-#{section.id}-#{course.term.gsub(' ', '-')}-*.csv"
        csv = parse_grades_csv file_path
        csv.map { |r| r.to_hash }
      end

      # Downloads final grades for a given section
      # @param course [Course]
      # @param section [Section]
      # @return [Array<Hash>]
      def download_final_grades(course, section)
        logger.info "Downloading final grades for #{course.code} #{section.label}"
        choose_section section if course.sections.length > 1
        wait_for_load_and_click download_final_grades_element
        file_path = "#{Utils.download_dir}/egrades-final-#{section.id}-#{course.term.gsub(' ', '-')}-*.csv"
        csv = parse_grades_csv file_path
        csv.map { |r| r.to_hash }
      end

    end
  end
end
