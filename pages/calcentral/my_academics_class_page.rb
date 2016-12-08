require_relative '../../util/spec_helper'

module Page

  module CalCentralPages

    class MyAcademicsClassPage

      include PageObject
      include Logging
      include Page
      include CalCentralPages

      # CLASS INFO
      h2(:class_info_heading, xpath: '//h2[text()="Class Information"]')
      div(:course_title, xpath: '//h3[text()="Class Title"]/following-sibling::div[@data-ng-bind="selectedCourse.title"]')

      # Loads a class page using a given URL path
      # @param path [String]
      def load_page(path)
        logger.info "Loading class page at #{path}"
        navigate_to "#{Utils.calcentral_base_url}#{path}"
      end

    end
  end
end
