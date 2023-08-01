require_relative '../../util/spec_helper'

class RipleyMailingListsPage

  include PageObject
  include Logging
  include Page
  include RipleyPages

  # Search
  text_area(:site_id_input, id: 'page-site-mailing-list-site-id')
  button(:get_list_button, id: 'btn-get-mailing-list')
  div(:not_found_msg, xpath: '//div[contains(., "bCourses site 99999999 was not found.")]')

  # Create list
  link(:site_name_link, id: 'course-site-href')
  div(:site_term, xpath: '//div[@class="text-subtitle-1"]')
  div(:site_id, xpath: '//div[contains(text(), "Site ID:")]')
  link(:view_site_link, id: 'mailing-list-course-site-name')
  text_area(:list_name_input, id: 'mailing-list-name-input')
  button(:register_list_button, id: 'btn-create-mailing-list')
  div(:list_name_error_msg, xpath: '//div[text()=" Only lowercase alphanumeric, underscore and hyphen characters allowed. "]')
  div(:list_creation_error_msg, id: 'TBD "A Mailing List cannot be created for the site"')
  div(:list_name_taken_error_msg, xpath: '//div[contains(., "List with name") and contains(., "already exists")]')

  # View list
  link(:list_site_link, id: 'mailing-list-course-site-name')
  div(:list_site_id, xpath: '//div[text()=" ID: "]/../following-sibling::div')
  div(:list_site_desc, xpath: '//div[text()=" Description: "]/../following-sibling::div')
  span(:list_address, xpath: '(//div[text()=" Name: "]/../following-sibling::div)[2]')
  div(:list_membership_count, id: 'mailing-list-member-count')
  div(:list_update_time, id: 'mailing-list-membership-last-updated')

  # Update membership
  button(:cancel_button, id: 'btn-cancel')
  button(:update_membership_button, id: 'btn-populate-mailing-list')
  div(:no_membership_change_msg, xpath: '//*[text()="Everything is up-to-date. No changes necessary."]')
  div(:member_removed_msg, xpath: '//span[contains(text(), "Removed")]')
  div(:member_added_msg, xpath: '//span[contains(text(), "Added")]')

  def embedded_tool_path
    "/accounts/#{Utils.canvas_admin_sub_account}/external_tools/#{RipleyUtils.mailing_lists_tool_id}"
  end

  def hit_embedded_tool_url
    navigate_to "#{Utils.canvas_base_url}#{embedded_tool_path}"
  end

  def load_embedded_tool
    logger.info 'Loading embedded admin Mailing Lists tool'
    load_tool_in_canvas embedded_tool_path
  end

  def load_standalone_tool
    logger.info 'Loading standalone admin Mailing Lists tool'
    navigate_to "#{RipleyUtils.base_url}/mailing_list/select_course"
  end

  def search_for_list(search_term)
    logger.info "Searching for mailing list for course site ID #{search_term}"
    wait_for_element_and_type_js(site_id_input_element, search_term)
    wait_for_update_and_click get_list_button_element
  end

  def site_not_found_msg(input)
    div_element(xpath: "//div[contains(., 'No bCourses site with ID \"#{input}\" was found.')]")
  end

  def default_list_name(site)
    part = site.title
    site.term.nil? ? (part = "#{part} list") : (part = "#{part} #{site.term.name[0..1]}#{site.term.name[-2..-1]}")
    part.downcase.gsub(/[ :]/, '-')
  end

  def enter_custom_list_name(text)
    logger.info "Entering mailing list name '#{text}'"
    wait_for_element_and_type_js(list_name_input_element, text)
    wait_for_update_and_click register_list_button_element
  end

  def click_update_memberships
    logger.info 'Clicking update membership button'
    wait_for_update_and_click update_membership_button_element
  end

  def click_cancel_list
    logger.info 'Clicking cancel'
    wait_for_update_and_click cancel_button_element
  end
end
