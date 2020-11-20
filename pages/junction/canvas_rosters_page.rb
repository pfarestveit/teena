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
      button(:export_roster_link, xpath: '//button[contains(.,"Export")]')
      link(:print_roster_link, xpath: '//button[contains(.,"Print")]')

      radio_button(:photo_view_radio, xpath: '//div[@id="toggle-view-mode"]//input[@value="photos"]')
      radio_button(:list_view_radio, xpath: '//div[@id="toggle-view-mode"]//input[@value="list"]')
      button(:sort_by_sid, xpath: '//div[text()="SID"]')
      button(:sort_by_name, xpath: '//div[text()="Name"]')
      button(:sort_by_email, xpath: '//div[text()="Email"]')

      paragraph(:no_access_msg, xpath: '//p[contains(.,"You must be a teacher in this bCourses course to view official student rosters.")]')
      paragraph(:no_students_msg, xpath: '//p[contains(.,"Students have not yet signed up for this class.")]')

      elements(:roster_photo, :image, xpath: '//div[@class="cc-page-roster"]//img[contains(@src, "/photo/")]')
      elements(:roster_photo_placeholder, :image, xpath: '//div[@class="cc-page-roster"]//img[contains(@src, "photo_unavailable")]')
      elements(:roster_sid, :span, xpath: '//div[@class="cc-page-roster"]//div[contains(@id, "student-id")]')

      # Loads the LTI tool in the context of a Canvas course site
      # @param course [Course]
      def load_embedded_tool(course)
        logger.info 'Loading embedded version of Roster Photos tool'
        load_tool_in_canvas"/courses/#{course.site_id}/external_tools/#{JunctionUtils.canvas_rosters_tool}"
      end

      # Loads the LTI tool in the Junction context
      # @param course [Course]
      def load_standalone_tool(course)
        logger.info 'Loading standalone version of Roster Photos tool'
        navigate_to "#{JunctionUtils.junction_base_url}/canvas/rosters/#{course.site_id}"
      end

      # Clicks the sidebar Roster Photos link and shifts focus to the tool
      def click_roster_photos_link
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

      def set_photo_view
        logger.info 'Setting photo view'
        js_click photo_view_radio_element
      end

      def set_list_view
        logger.info 'Setting list view'
        js_click list_view_radio_element
      end

      def sort_list_by_sid
        logger.info 'Sorting by SID'
        wait_for_update_and_click sort_by_sid_element
        sleep 1
      end

      def sort_list_by_name
        logger.info 'Sorting by Name'
        wait_for_update_and_click sort_by_name_element
        sleep 1
      end

      def sort_list_by_email
        logger.info 'Sorting by Email'
        wait_for_update_and_click sort_by_email_element
        sleep 1
      end

      def list_view_student_data
        rows_xpath = '//tbody/tr'
        rows = row_elements(xpath: '//tbody/tr')
        wait_until(1) { rows.any? }
        rows.map.with_index do |row, i|
          row_xpath = "#{rows_xpath}[#{i + 1}]"
          sid_el = cell_element(xpath: "#{row_xpath}/td[1]")
          name_el = span_element(xpath: "#{row_xpath}/td[2]/span")
          email_el = cell_element(xpath: "#{row_xpath}/td[3]")
          section_els = div_elements(xpath: "#{row_xpath}/td[4]/div")
          {
              sid: (sid_el.text if sid_el.exists?),
              name: (name_el.text if name_el.exists?),
              email: (email_el.text if email_el.exists?),
              sections: (section_els.map { |el| el.text.strip })
          }
        end
      end

      # Returns an array of all SIDs visible on the page
      # @return [Array<String>]
      def all_sids
        roster_sid_elements.map { |el| el.attribute('id').gsub('student-id-', '') }
      end

    end
  end
end
