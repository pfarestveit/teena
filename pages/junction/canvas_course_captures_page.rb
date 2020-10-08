require_relative '../../util/spec_helper'

module Page

  module JunctionPages

    class CanvasCourseCapturesPage

      include PageObject
      include Logging
      include Page
      include JunctionPages

      link(:course_captures_link, text: 'Course Captures')
      elements(:section_content, :div, xpath: '//div[contains(@class, "cc-webcast-table")]')
      elements(:section_code, :h3, xpath: '//h3')
      elements(:you_tube_alert, :div, xpath: '//div[contains(.,"Log in to YouTube with your bConnected account to watch the videos below.")]')
      link(:report_problem, xpath: '//a[contains(text(),"Report a problem")]')

      # Loads the course capture LTI tool within a course site
      # @param course [Course]
      def load_embedded_tool(course)
        logger.info "Loading course capture tool on site ID #{course.site_id}"
        load_tool_in_canvas"/courses/#{course.site_id}/external_tools/#{JunctionUtils.canvas_course_captures_tool}"
      end

      # Loads the standalone version of the course capture tool
      # @param course [Course]
      def load_standalone_tool(course)
        logger.info "Loading standalone course capture tool for site ID #{course.site_id}"
        navigate_to "#{JunctionUtils.junction_base_url}/canvas/course_mediacasts/#{course.site_id}"
      end

      # Returns the course plus section code at a given index, which is shown when more than one set of recordings is present
      # @param index [Integer]
      # @return [String]
      def section_course_code(index)
        section_code_elements[index] && section_code_elements[index].text
      end

      # Returns the index of the set of recordings for a given section
      # @param section_code [String]
      # @return [Integer]
      def section_recordings_index(section_code = nil)
        wait_until(Utils.medium_wait) { section_content_elements.any? }
        section_els = section_content_elements
        if section_els.length > 1
          el = section_els.find { |el| el.attribute('innerText').include? section_code }
          section_els.index el
        else
          0
        end
      end

      # Returns an array of links to YouTube recordings in a set of recordings at a given index
      # @param index [Integer]
      # @return [Array<Selenium::WebDriver::Element>]
      def you_tube_recording_elements(index)
        link_elements(xpath: "//div[contains(@class, 'cc-webcast-table')][#{index + 1}]/table//a")
      end

      # Returns the link element whose href attribute includes a given YouTube video ID
      # @param video_id [String]
      # @return [PageObject::Elements::Link]
      def you_tube_link(video_id)
        link_element(xpath: "//a[contains(@href,'#{video_id}')]")
      end

      # Returns the 'help page' link in a set of recordings at a given index
      # @param index [Integer]
      # @return [PageObject::Elements::Link]
      def help_page_link(index)
        link_element(xpath: "//div[contains(@class, 'cc-webcast-table')][#{index + 1}]//a[contains(.,'help page')]")
      end

    end
  end
end
