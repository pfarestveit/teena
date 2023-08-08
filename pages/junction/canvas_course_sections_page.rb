require_relative '../../util/spec_helper'

module Page

  module JunctionPages

    class CanvasCourseSectionsPage

      include PageObject
      include Logging
      include Page
      include JunctionPages

      # Returns the button element to expand or collapse the table of available sections in a course
      # @param course_code [String]
      # @return [PageObject::Elements::Button]
      def available_sections_form_button(course_code)
        button_element(xpath: "//button[contains(.,'#{course_code}')]")
      end

      # Returns the course title displayed in the available sections form
      # @param course_code [String]
      # @return [String]
      def available_sections_course_title(course_code)
        logger.debug "Looking for the course title for course code #{course_code}"
        begin
          el = span_element(xpath: "//h3[contains(., '#{course_code}')]/span")
          el.when_visible Utils.short_wait
          el.text[2..-1]
        rescue
          ''
        end
      end

      # Returns the table element containing a given course's sections available to add to a course site
      # @param course_code [String]
      # @return [PageObject::Elements::Table]
      def available_sections_table(course_code)
        table_element(xpath: "//div[contains(@id, '#{course_code.downcase.gsub(' ', '-')}-')]//table")
      end

      # Expands the table of available sections in a course
      # @param course_code [String]
      def expand_available_sections(course_code)
        if available_sections_table(course_code).exists? && available_sections_table(course_code).visible?
          logger.debug "The sections table is already expanded for #{course_code}"
        else
          available_sections_form_button(course_code).click
          sleep Utils.click_wait
        end
      end

      # Collapses the table of available sections in a course
      # @param course_code [String]
      def collapse_available_sections(course_code)
        if available_sections_table(course_code).exists? && available_sections_table(course_code).visible?
          available_sections_form_button(course_code).click
          available_sections_table(course_code).when_not_visible Utils.short_wait
        else
          logger.debug "The sections table is already collapsed for #{course_code}"
        end
      end

    end
  end
end
