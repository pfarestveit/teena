require_relative '../../util/spec_helper'

module Page

  module CalCentralPages

    class CanvasCourseCapturesPage < MyAcademicsCourseCapturesCard

      include PageObject
      include Logging
      include Page
      include CalCentralPages

      link(:course_captures_link, text: 'Course Captures')

      # Loads the course capture LTI tool within a course site
      # @param driver [Selenium::WebDriver]
      # @param course [Course]
      def load_embedded_tool(driver, course)
        logger.info "Loading course capture tool on site ID #{course.site_id}"
        navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/external_tools/#{Utils.canvas_course_captures_tool}"
        switch_to_canvas_iframe driver
      end

      # Loads the standalone version of the course capture tool
      # @param course [Course]
      def load_standalone_tool(course)
        logger.info "Loading standalone course capture tool for site ID #{course.site_id}"
        navigate_to "#{Utils.calcentral_base_url}/canvas/course_mediacasts/#{course.site_id}"
      end

    end
  end
end
