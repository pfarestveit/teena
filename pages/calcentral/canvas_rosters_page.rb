require_relative '../../util/spec_helper'

module Page

  module CalCentralPages

    class CanvasRostersPage

      include PageObject
      include Logging
      include Page
      include CalCentralPages

      link(:roster_photos_link, text: 'Roster Photos')

      text_area(:search_input, id: 'roster-search')
      select_list(:section_select, id: 'section-select')
      link(:export_roster_link, xpath: '//a[contains(.,"Export")]')
      link(:print_roster_link, xpath: '//a[contains(.,"Print")]')

      paragraph(:no_access_msg, xpath: '//p[contains(.,"You must be a teacher in this bCourses course to view official student rosters.")]')
      paragraph(:no_students_msg, xpath: '//p[contains(.,"Students have not yet signed up for this class.")]')

      elements(:roster_photo, :image, xpath: '//ul[@class="cc-page-roster-list"]/li//img')
      elements(:roster_photo_placeholder, :span, xpath: '//ul[@class="cc-page-roster-list"]/li//span[text()="No Official Photo is Available"]')
      elements(:roster_sid, :span, xpath: '//ul[@class="cc-page-roster-list"]/li//span[@data-ng-bind="student.student_id"]')

      # Loads the LTI tool in the context of a Canvas course site
      # @param driver [Selenium::WebDriver]
      # @param course [Course]
      def load_embedded_tool(driver, course)
        logger.info 'Loading embedded version of Roster Photos tool'
        navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/external_tools/#{Utils.canvas_rosters_tool}"
        switch_to_canvas_iframe driver
      end

      # Loads the LTI tool in the CalCentral context
      # @param course [Course]
      def load_standalone_tool(course)
        logger.info 'Loading standalone version of Roster Photos tool'
        navigate_to "#{Utils.calcentral_base_url}/canvas/rosters/#{course.site_id}"
      end

      # Clicks the sidebar Roster Photos link and shifts focus to the tool
      # @param driver [Selenium::WebDriver]
      def click_roster_photos_link(driver)
        logger.info 'Clicking Roster Photos link'
        wait_for_page_load_and_click roster_photos_link_element
        switch_to_canvas_iframe driver
      end

      # Enters a string in the search input and pauses for DOM update
      # @param string [String]
      def filter_by_string(string)
        wait_for_element_and_type(search_input_element, string)
        sleep 1
      end

      # Selects a section and pauses for DOM update
      # @param section [Section]
      def filter_by_section(section)
        wait_for_page_update_and_click section_select_element
        self.section_select = "#{section.course} #{section.label}"
        sleep 1
      end

      # Clicks the Export roster button and returns the count of user rows in the downloaded file
      # @param course [Course]
      # @return Integer
      def export_roster(course)
        logger.info "Downloading roster CSV for course ID #{course.site_id}"
        Utils.prepare_download_dir
        wait_for_page_update_and_click export_roster_link_element
        export_roster_link
        csv_file_path = "#{Utils.download_dir}/course_#{course.site_id}_rosters.csv"
        wait_until { Dir[csv_file_path].any? }
        csv = Dir[csv_file_path].first
        # Get row count and subtract one for the heading
        rows = IO.readlines csv
        rows.count - 1
      end

      # Returns an array of all SIDs visible on the page
      # @return [Array<String>]
      def all_sids
        (roster_sid_elements.map &:text).to_a
      end

    end
  end
end
