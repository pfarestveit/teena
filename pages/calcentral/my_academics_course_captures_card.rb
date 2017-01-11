require_relative '../../util/spec_helper'

module Page

  module CalCentralPages

    class MyAcademicsCourseCapturesCard < MyAcademicsClassPage

      include PageObject
      include Logging
      include Page
      include CalCentralPages

      h2(:course_capture_heading, xpath: '//h2[text()="Course Captures"]')
      div(:no_course_capture_msg, xpath: '//div[contains(text(),"There are no recordings available.")]')
      div(:no_video_msg, xpath: '//div[contains(.,"No video content available.")]')
      elements(:section_content, :div, class: 'cc-webcast-table')
      elements(:section_code, :h3, xpath: '//h3[@data-ng-if="media.length > 1"]')
      elements(:video_table, :table, xpath: '//table[@data-ng-if="section.videos.length"]')
      elements(:you_tube_alert, :div, xpath: '//div[contains(.,"Log in to YouTube with your bConnected account to watch the videos below.")]')
      link(:report_problem, xpath: '//a[contains(text(),"Report a problem")]')

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
        show_more_button(index).click while show_more_button(index).exists?
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
