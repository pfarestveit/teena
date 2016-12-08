require_relative '../../util/spec_helper'

module Page

  module CalCentralPages

    class MyDashboardMyClassesCard < MyDashboardPage

      include PageObject
      include Logging
      include Page
      include CalCentralPages

      span(:term_name, xpath: '//span[@data-ng-bind="current_term"]')

      div(:enrolled_classes_div, xpath: '//div[contains(@data-ng-class,"student")]')
      elements(:enrolled_course_site_link, :link, xpath: '//div[contains(@data-ng-class,"student")]//a[@data-ng-bind="subclass.name"]')
      elements(:enrolled_course_site_desc, :div, xpath: '//div[contains(@data-ng-class,"student")]//div[@data-ng-bind="subclass.shortDescription"]')

      div(:teaching_classes_div, xpath: '//div[contains(@data-ng-class,"instructor")]')
      elements(:teaching_course_site_link, :link, xpath: '//div[contains(@data-ng-class,"instructor")]//a[@data-ng-bind="subclass.name"]')
      elements(:teaching_course_site_desc, :div, xpath: '//div[contains(@data-ng-class,"instructor")]//div[@data-ng-bind="subclass.shortDescription"]')

      div(:other_sites_div, xpath: '//div[contains(@data-ng-class,"other")]')
      elements(:other_course_site_name, :link, xpath: '//div[contains(@data-ng-class,"other")]//div[@data-ng-bind="class.name"]')
      elements(:other_course_site_desc, :div, xpath: '//div[contains(@data-ng-class,"other")]//div[@data-ng-bind="class.shortDescription"]')

      # Loads My Dashboard and waits for the term name to appear on the My Classes card, indicating that the card content
      # has loaded
      def load_card
        load_page
        term_name_element.when_visible Utils.medium_wait
      end

      # Clicks a link element with an href attribute matching a given URL
      # @param url [String]
      def click_class_link_by_url(url)
        wait_for_page_load_and_click link_element(xpath: "//a[@href='#{url}']")
      end

      # Returns a collection of course site names displayed in the student section
      # @return [Array<String>]
      def enrolled_course_site_names
        enrolled_course_site_link_elements.map { |link| link.text.gsub("\n- opens in new window", '') }
      end

      # Returns a collection of course site descriptions displayed in the student section
      # @return [Array<String>]
      def enrolled_course_site_descrips
        enrolled_course_site_desc_elements.map { |descrip| descrip.text unless descrip.text == '' }
      end

      # Returns a collection of course site names displayed in the teaching section
      # @return [Array<String>]
      def teaching_course_site_names
        teaching_course_site_link_elements.map { |link| link.text.gsub("\n- opens in new window", '') }
      end

      # Returns a collection of course site descriptions displayed in the teaching section
      # @return [Array<String>]
      def teaching_course_site_descrips
        teaching_course_site_desc_elements.map &:text
      end

      # Returns a collection of course site names displayed in the other section
      # @return [Array<String>]
      def other_course_site_names
        other_course_site_name_elements.map &:text
      end

      # Returns a collection of course site descriptions displayed in the other section
      # @return [Array<String>]
      def other_course_site_descrips
        other_course_site_desc_elements.map &:text
      end

    end
  end
end
