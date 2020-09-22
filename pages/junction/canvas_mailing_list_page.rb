require_relative '../../util/spec_helper'

module Page
  module JunctionPages
    class CanvasMailingListPage

      include PageObject
      include Logging
      include Page
      include JunctionPages

      link(:mailing_list_link, text: 'Mailing List')
      div(:no_list_msg, xpath: '//div[contains(.,"No Mailing List has yet been created for this site.")]')
      button(:create_list_button, xpath: '//button[@data-ng-click="createMailingList()"]')
      div(:list_created_msg, xpath: '//div[contains(.,"A Mailing List has been created")]')
      div(:list_address, xpath: '//div[contains(.,"A Mailing List has been created")]/strong')
      div(:list_dupe_error_msg, xpath: '//div[contains(.,"A Mailing List cannot be created for the site")]')
      div(:list_dupe_email_msg, xpath: '//div[contains(.,"is already in use by another Mailing List.")]')

      # Loads the instructor Mailing List LTI tool in a course site
      # @param course [Course]
      def load_embedded_tool(course)
        logger.info "Loading embedded instructor Mailing List tool for course ID #{course.site_id}"
        load_tool_in_canvas"/courses/#{course.site_id}/external_tools/#{JunctionUtils.canvas_mailing_list_tool}"
      end

      # Loads the standalone version of the instructor Mailing List tool
      # @param course [Course]
      def load_standalone_tool(course)
        logger.info "Loading standalone instructor Mailing List tool for course ID #{course.site_id}"
        navigate_to "#{JunctionUtils.junction_base_url}/canvas/site_mailing_list/#{course.site_id}"
      end

      # Clicks the 'create list' button
      def create_list
        logger.info 'Clicking create-list button'
        wait_for_update_and_click create_list_button_element
      end

    end
  end
end
