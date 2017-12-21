require_relative '../../util/spec_helper'

module Page

  module JunctionPages

    class CanvasCourseCapturesPage

      include PageObject
      include Logging
      include Page
      include JunctionPages

      link(:course_captures_link, text: 'Course Captures')
      elements(:section_content, :div, class: 'cc-webcast-table')
      elements(:section_code, :h3, xpath: '//h3[@data-ng-if="media.length > 1"]')
      elements(:you_tube_alert, :div, xpath: '//div[contains(.,"Log in to YouTube with your bConnected account to watch the videos below.")]')
      link(:report_problem, xpath: '//a[contains(text(),"Report a problem")]')

      # Loads the course capture LTI tool within a course site
      # @param driver [Selenium::WebDriver]
      # @param course [Course]
      def load_embedded_tool(driver, course)
        logger.info "Loading course capture tool on site ID #{course.site_id}"
        load_tool_in_canvas(driver, "/courses/#{course.site_id}/external_tools/#{JunctionUtils.canvas_course_captures_tool}")
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
        (section_content_elements.length > 1) ?
            section_content_elements.index(div_element(xpath: "//h3[text()='#{section_code}']/..")) : 0
      end

      # Returns an array of links to YouTube recordings in a set of recordings at a given index
      # @param driver [Selenium::WebDriver]
      # @param index [Integer]
      # @return [Array<Selenium::WebDriver::Element>]
      def you_tube_recording_elements(driver, index)
        driver.find_elements(xpath: "//div[@class='cc-table cc-webcast-table ng-scope'][#{index + 1}]/table//a[@data-ng-bind='video.lecture']")
      end

      # Returns the 'show more' button element in a set of recordings at a given index
      # @param index [Integer]
      # @return [PageObject::Elements::Button]
      def show_more_button(index)
        button_element(xpath: "//div[@class='cc-table cc-webcast-table ng-scope'][#{index + 1}]//div[@data-cc-show-more-list='section.videos']/button")
      end

      # Clicks the 'show more' button at a given index until the button disappears
      # @param index [Integer]
      def show_all_recordings(index)
        wait_for_update_and_click_js show_more_button(index) while show_more_button(index).exists?
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
        link_element(xpath: "//div[@class='cc-table cc-webcast-table ng-scope'][#{index + 1}]//a[contains(.,'help page')]")
      end

    end
  end
end
