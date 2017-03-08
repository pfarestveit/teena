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
      button(:get_list_button, xpath: '//button[@data-ng-click="findSiteMailingList()"]')
      div(:bad_input_msg, xpath: '//div[contains(.,"Canvas site ID must be a numeric string.")]')
      div(:not_found_msg, xpath: '//div[contains(.,"No bCourses site with ID")]')

      # Create list
      span(:site_name, xpath: '//div[@class="bc-page-site-mailing-list-info-box"]/h2/span')
      div(:site_code, xpath: '//div[@class="bc-page-site-mailing-list-info-box"]//div[@data-ng-bind="canvasSite.codeAndTerm"]')
      div(:site_id, xpath: '//div[@class="bc-page-site-mailing-list-info-box"]//div[@data-ng-bind="canvasSite.codeAndTerm"]/following-sibling::div')
      link(:view_site_link, xpath: '//a[contains(.,"View course site")]')
      radio_button(:cal_mail_radio, id: 'listTypeCalmail')
      radio_button(:mail_gun_radio, id: 'listTypeMailgun')
      text_area(:list_name_input, id: 'mailingListName')
      button(:register_list_button, xpath: '//button[@data-ng-click="registerMailingList()"]')
      div(:list_name_error_msg, xpath: '//div[contains(.,"List name may contain only lowercase, numeric, underscore and hyphen characters.")]')
      div(:list_creation_error_msg, xpath: '//div[contains(.,"A Mailing List cannot be created for the site)]')
      div(:list_name_taken_error_msg, xpath: '//div[contains(.,"is already in use by another Mailing List.")]')

      # View list
      span(:list_address, xpath: '//div[@class="bc-page-site-mailing-list-info-box"]/h2/span')
      div(:list_membership_count, xpath: '//div[@class="bc-page-site-mailing-list-info-box"]//div[contains(@count,"mailingList.membersCount")]')
      div(:list_update_time, xpath: '//div[@class="bc-page-site-mailing-list-info-box"]//div[contains(.,"Membership last updated")]/strong')
      link(:list_site_link, xpath: '//div[@class="bc-page-site-mailing-list-info-box"]//div[contains(.,"Course site:")]/a')

      # Update membership
      button(:cancel_button, xpath: '//button[contains(.,"Cancel")]')
      button(:update_membership_button, xpath: '//button[@data-ng-click="populateMailingList()"]')
      div(:membership_updated_msg, xpath: '//div[contains(.,"Memberships were successfully updated.")]')
      div(:no_membership_change_msg, xpath: '//div[contains(.,"No changes in membership were found.")]')
      div(:member_removed_msg, xpath: '//div[contains(.,"removed.")]')
      div(:member_added_msg, xpath: '//div[contains(.,"added.")]')

      # Loads the admin Mailing Lists LTI tool within the admin sub-account
      # @param driver [Selenium::WebDriver]
      def load_embedded_tool(driver)
        logger.info 'Loading embedded admin Mailing Lists tool'
        navigate_to "#{Utils.canvas_base_url}/accounts/#{Utils.canvas_admin_sub_account}/external_tools/#{Utils.canvas_mailing_lists_tool}"
        switch_to_canvas_iframe driver
      end

      # Loads the standalone version of the admin Mailing Lists tool
      def load_standalone_tool
        logger.info 'Loading standalone admin Mailing Lists tool'
        navigate_to "#{Utils.junction_base_url}/canvas/site_mailing_lists"
      end

      # Searches for a mailing list
      # @param search_term [String]
      def search_for_list(search_term)
        logger.info "Searching for mailing list for course site ID #{search_term}"
        wait_for_element_and_type(site_id_input_element, search_term)
        wait_for_update_and_click_js get_list_button_element
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
        course.term.nil? ? (part = "#{part} list") : (part = "#{part} #{course.term[0..1]} #{course.term[-2..-1]}")
        part.downcase.gsub(/[ :]/, '-')
      end

      # Enters a name for a Mailgun list and clicks the 'register' button
      # @param text [String]
      def enter_mailgun_list_name(text)
        logger.info "Entering mailing list name '#{text}'"
        wait_for_update_and_click mail_gun_radio_element
        wait_for_element_and_type(list_name_input_element, text)
        wait_for_update_and_click register_list_button_element
      end

      # Clicks the 'update memberships' button
      def click_update_memberships
        wait_for_update_and_click update_membership_button_element
      end

      # Clears the cached course site membership so that a membership change will be found immediately
      # @param driver [Selenium::WebDriver]
      # @param splash_page [Page::JunctionPages::SplashPage]
      # @param toolbox_page [Page::JunctionPages::MyToolboxPage]
      # @param course [Course]
      # @param uid [Integer]
      def clear_membership_cache(driver, splash_page, toolbox_page, course, uid)
        logger.info 'Updating mailing list memberships'
        key = "Canvas::CourseUsers/#{course.site_id}/#{uid}"
        Utils.clear_cache(driver, splash_page, toolbox_page, key)
      end

      # Clicks the 'cancel' button
      def click_cancel
        logger.debug 'Clicking cancel'
        wait_for_update_and_click cancel_button_element
      end
    end
  end
end
