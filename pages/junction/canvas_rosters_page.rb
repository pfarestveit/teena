require_relative '../../util/spec_helper'

module Page

  module JunctionPages

    class CanvasRostersPage

      include PageObject
      include Logging
      include Page
      include JunctionPages

      link(:roster_photos_link, text: 'Roster Photos')

      text_area(:search_input, id: 'roster-search')
      select_list(:section_select, id: 'section-select')
      link(:export_roster_link, xpath: '//a[contains(.,"Export")]')
      link(:print_roster_link, xpath: '//button[contains(.,"Print")]')

      paragraph(:no_access_msg, xpath: '//p[contains(.,"You must be a teacher in this bCourses course to view official student rosters.")]')
      paragraph(:no_students_msg, xpath: '//p[contains(.,"Students have not yet signed up for this class.")]')

      elements(:roster_photo, :image, xpath: '//ul[@class="cc-page-roster-photos-list"]/li//img')
      elements(:roster_photo_placeholder, :span, xpath: '//ul[@class="cc-page-roster-photos-list"]/li//span[text()="No Official Photo is Available"]')
      elements(:roster_sid, :span, xpath: '//ul[@class="cc-page-roster-photos-list"]/li//span[@data-ng-bind="student.student_id"]')

      # Loads the LTI tool in the context of a Canvas course site
      # @param driver [Selenium::WebDriver]
      # @param course [Course]
      def load_embedded_tool(driver, course)
        logger.info 'Loading embedded version of Roster Photos tool'
        load_tool_in_canvas(driver, "/courses/#{course.site_id}/external_tools/#{JunctionUtils.canvas_rosters_tool}")
      end

      # Loads the LTI tool in the Junction context
      # @param course [Course]
      def load_standalone_tool(course)
        logger.info 'Loading standalone version of Roster Photos tool'
        navigate_to "#{JunctionUtils.junction_base_url}/canvas/rosters/#{course.site_id}"
      end

      # Clicks the sidebar Roster Photos link and shifts focus to the tool
      # @param driver [Selenium::WebDriver]
      def click_roster_photos_link(driver)
        logger.info 'Clicking Roster Photos link'
        wait_for_load_and_click_js roster_photos_link_element
        switch_to_canvas_iframe JunctionUtils.junction_base_url
      end

      # Returns an array of options in the section select
      # @return [Array<String>]
      def section_options
        section_select_options.reject { |o| o == 'All Sections' }
      end

      # Enters a string in the search input and pauses for DOM update
      # @param string [String]
      def filter_by_string(string)
        wait_for_element_and_type_js(search_input_element, string)
        sleep 1
      end

      # Selects a section and pauses for DOM update
      # @param section [Section]
      def filter_by_section(section)
        wait_for_element_and_select_js(section_select_element, "#{section.course} #{section.label}")
        sleep 1
      end

      # Clicks the Export roster button and returns the SIDs in the downloaded file
      # @param course [Course]
      # @return [Array<String>]
      def export_roster(course)
        logger.info "Downloading roster CSV for course ID #{course.site_id}"
        Utils.prepare_download_dir
        wait_for_update_and_click export_roster_link_element
        csv_file_path = "#{Utils.download_dir}/course_#{course.site_id}_rosters.csv"
        wait_until(Utils.medium_wait) { Dir[csv_file_path].any? }
        csv = CSV.read(csv_file_path, headers: true)
        sids = []
        csv.each { |r| sids << r['Student ID'] }
        sids
      end

      # Returns an array of all SIDs visible on the page
      # @return [Array<String>]
      def all_sids
        roster_sid_elements.map &:text
      end

    end
  end
end
