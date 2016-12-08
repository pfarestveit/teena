require_relative '../../util/spec_helper'

module Page

  module CalCentralPages

    class MyAcademicsClassSitesCard < MyAcademicsClassPage

      include PageObject
      include Logging
      include Page
      include CalCentralPages

      h2(:class_sites_heading, xpath: '//h2[text()="Class Sites"]')
      elements(:class_site_link, :link, xpath: '//ul[@class = "cc-academics-class-sites-list"]//a')
      elements(:class_site_name, :div, xpath: '//ul[@class = "cc-academics-class-sites-list"]//strong')

      # Returns an array of visible class site names
      # @return [Array<String>]
      def class_site_names
        class_site_name_elements.map &:text
      end

      # Returns an array of href attributes from visible class site links
      # @return [Array<String>]
      def class_site_urls
        class_site_link_elements.map { |link| link.attribute 'href' }
      end

    end
  end
end
