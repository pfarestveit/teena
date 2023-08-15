require_relative '../../util/spec_helper'

module Page
  module JunctionPages
    class CanvasMailingListsPage

      include PageObject
      include Logging
      include Page
      include JunctionPages

      # Search
      text_area(:site_id_input, id: 'bc-page-site-mailing-list-site-id')
      button(:get_list_button, id: 'btn-get-mailing-list')
      div(:bad_input_msg, xpath: '//div[contains(.,"Canvas site ID must be a numeric string.")]')
      div(:not_found_msg, xpath: '//div[contains(.,"No bCourses site with ID")]')

      # Create list
      span(:site_name, xpath: '//h2[@id="mailing-list-details-header"]/span')
      div(:site_code, id: 'mailing-list-canvas-code-and-term')
      div(:site_id, id: 'mailing-list-canvas-course-id')
      link(:view_site_link, xpath: '//a[contains(.,"View course site")]')
      text_area(:list_name_input, id: 'mailingListName')
      button(:register_list_button, id: 'btn-create-mailing-list')
      div(:list_name_error_msg, xpath: '//div[contains(.,"List name may contain only lowercase, numeric, underscore and hyphen characters.")]')
      div(:list_creation_error_msg, xpath: '//div[contains(.,"A Mailing List cannot be created for the site)]')
      div(:list_name_taken_error_msg, xpath: '//div[contains(.,"is already in use by another Mailing List.")]')

      # View list
      span(:list_address, xpath: '//h2[@id="mailing-list-details-header"]/span')
      div(:list_membership_count, id: 'mailing-list-member-count')
      div(:list_update_time, id: 'mailing-list-membership-last-updated')
      link(:list_site_link, id: 'mailing-list-court-site-name')

      # Update membership
      button(:cancel_button, id: 'btn-cancel')
      button(:update_membership_button, id: 'btn-populate-mailing-list')
      div(:membership_updated_msg, xpath: '//div[contains(.,"Memberships were successfully updated.")]')
      div(:no_membership_change_msg, xpath: '//div[contains(.,"No changes in membership were found.")]')
      div(:member_removed_msg, xpath: '//div[contains(.,"removed.")]')
      div(:member_added_msg, xpath: '//div[contains(.,"added.")]')

      def embedded_tool_path
        "/accounts/#{Utils.canvas_admin_sub_account}/external_tools/#{JunctionUtils.canvas_mailing_lists_tool}"
      end

      def hit_embedded_tool_url
        navigate_to "#{Utils.canvas_base_url}#{embedded_tool_path}"
      end

      # Loads the admin Mailing Lists LTI tool within the admin sub-account
      def load_embedded_tool
        logger.info 'Loading embedded admin Mailing Lists tool'
        load_tool_in_canvas embedded_tool_path
      end

      # Loads the standalone version of the admin Mailing Lists tool
      def load_standalone_tool
        logger.info 'Loading standalone admin Mailing Lists tool'
        navigate_to "#{JunctionUtils.junction_base_url}/canvas/site_mailing_lists"
      end

      # Searches for a mailing list
      # @param search_term [String]
      def search_for_list(search_term)
        logger.info "Searching for mailing list for course site ID #{search_term}"
        wait_for_element_and_type(site_id_input_element, search_term)
        wait_for_update_and_click get_list_button_element
      end

      # Returns the element containing the 'no results' message for an unsuccessful mailing list search
      # @param input [String]
      # @return [PageObject::Elements::Div]
      def site_not_found_msg(input)
        div_element(xpath: "//div[contains(.,'No bCourses site with ID \"#{input}\" was found.')]")
      end

      # Returns the default email for a course site, which is the course title and term downcased and hyphenated.
      # @param course [Course]
      def default_list_name(course)
        part = course.title
        course.term.nil? ? (part = "#{part} list") : (part = "#{part} #{course.term[0..1]}#{course.term[-2..-1]}")
        part.downcase.gsub(/[ :]/, '-')
      end

      # Enters a name for a Mailgun list and clicks the 'register' button
      # @param text [String]
      def enter_mailgun_list_name(text)
        logger.info "Entering mailing list name '#{text}'"
        wait_for_element_and_type(list_name_input_element, text)
        wait_for_update_and_click register_list_button_element
      end

      # Clicks the 'update memberships' button
      def click_update_memberships
        wait_for_update_and_click update_membership_button_element
        membership_updated_msg_element.when_visible Utils.short_wait
      end

      # Clicks the 'cancel' button
      def click_cancel
        logger.debug 'Clicking cancel'
        wait_for_update_and_click cancel_button_element
      end
    end
  end
end
