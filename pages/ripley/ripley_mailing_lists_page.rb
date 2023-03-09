require_relative '../../util/spec_helper'

class RipleyMailingListsPage

  include PageObject
  include Logging
  include Page
  include RipleyPages

  # Search
  text_area(:site_id_input, id: 'TBD')
  button(:get_list_button, id: 'TBD')
  div(:bad_input_msg, id: 'TBD "Canvas site ID must be a numeric string."')
  div(:not_found_msg, id: 'TBD "No bCourses site with ID"')

  # Create list
  span(:site_name, id: 'TBD')
  div(:site_code, id: 'TBD')
  div(:site_id, id: 'TBD')
  link(:view_site_link, id: 'TBD "View course site"')
  text_area(:list_name_input, id: 'TBD')
  button(:register_list_button, id: 'TBD')
  div(:list_name_error_msg, id: 'TBD "List name may contain only lowercase, numeric, underscore and hyphen characters."')
  div(:list_creation_error_msg, id: 'TBD "A Mailing List cannot be created for the site"')
  div(:list_name_taken_error_msg, id: 'TBD "is already in use by another Mailing List."')

  # View list
  span(:list_address, id: 'TBD')
  div(:list_membership_count, id: 'TBD')
  div(:list_update_time, id: 'TBD')
  link(:list_site_link, id: 'TBD')

  # Update membership
  button(:cancel_button, id: 'TBD')
  button(:update_membership_button, id: 'TBD')
  div(:membership_updated_msg, id: 'TBD "Memberships were successfully updated."')
  div(:no_membership_change_msg, id: 'TBD "No changes in membership were found."')
  div(:member_removed_msg, id: 'TBD')
  div(:member_added_msg, id: 'TBD')

  def embedded_tool_path
    "/accounts/#{Utils.canvas_admin_sub_account}/external_tools/#{Utils.canvas_mailing_lists_tool}"
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
    navigate_to "#{RipleyUtils.base_url} TBD"
  end

  def search_for_list(search_term)
    logger.info "Searching for mailing list for course site ID #{search_term}"
    wait_for_element_and_type(site_id_input_element, search_term)
    wait_for_update_and_click_js get_list_button_element
  end

  def site_not_found_msg(input)
    div_element(xpath: " 'No bCourses site with ID \"#{input}\" was found.'")
  end

  def default_list_name(site)
    part = site.course.title
    site.course.term.nil? ? (part = "#{part} list") : (part = "#{part} #{site.course.term.name[0..1]}#{site.course.term.name[-2..-1]}")
    part.downcase.gsub(/[ :]/, '-')
  end

  def enter_custom_list_name(text)
    logger.info "Entering mailing list name '#{text}'"
    wait_for_element_and_type(list_name_input_element, text)
    wait_for_update_and_click register_list_button_element
  end

  def click_update_memberships
    wait_for_update_and_click update_membership_button_element
    membership_updated_msg_element.when_visible Utils.short_wait
  end
end
