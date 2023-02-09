require_relative '../../util/spec_helper'

class RipleyAddUserPage

  include PageObject
  include Logging
  include Page
  include RipleyPages

  h1(:page_heading, id: 'TBD "Find a Person to Add"')

  span(:no_sections_msg, id: 'TBD')
  div(:no_results_msg, id: 'TBD "Your search did not match any users with a CalNet ID."')
  div(:too_many_results_msg, id: 'TBD "Please refine your search to limit the number of results."')
  div(:blank_search_msg, id: 'TBD "You did not enter any search terms.  Please try again."')
  div(:success_msg, id: 'TBD')

  text_area(:search_term, id: 'TBD')
  select_list(:search_type, id: 'TBD')
  button(:search_button, id: 'TBD')

  button(:need_help_button, id: 'TBD "Need help finding someone?"')
  div(:help_notice, id: 'TBD')
  link(:cal_net_dir_link, id: 'TBD "CalNet Directory"')
  link(:cal_net_guest_acct_link, id: 'TBD "CalNet Guest Account"')
  link(:bcourses_help_link, id: 'TBD "bCourses help page"')

  table(:results_table, id: 'TBD "User Search Results"')
  elements(:result_name, :span, id: 'TBD')
  elements(:result_uid, :span, id: 'TBD')
  elements(:result_email, :span, id: 'TBD')

  select_list(:user_role, id: 'TBD')
  select_list(:course_section, id: 'TBD')
  button(:add_user_button, id: 'TBD "Add User"')
  button(:start_over_button, id: 'TBD "Start Over"')

  def embedded_tool_path(course)
    "/courses/#{course.site_id}/external_tools/#{Utils.canvas_course_add_user_tool}"
  end

  def hit_embedded_tool_url(course)
    navigate_to "#{Utils.canvas_base_url}#{embedded_tool_path course}"
  end

  def load_embedded_tool(course)
    logger.info 'Loading embedded version of Find a Person to Add tool'
    load_tool_in_canvas embedded_tool_path(course)
  end

  def load_standalone_tool(course)
    logger.info 'Loading standalone version of Find a Person to Add tool'
    navigate_to "#{RipleyUtils.base_url}/TBD/#{course.site_id}"
  end

  def expand_help_notice
    wait_for_load_and_click need_help_button_element
    help_notice_element.when_visible Utils.short_wait
  end

  def hide_help_notice
    wait_for_load_and_click need_help_button_element
    help_notice_element.when_not_visible Utils.short_wait
  end

  def search(text, option)
    logger.info "Searching for string '#{text}' by #{option}"
    search_type_element.when_visible Utils.medium_wait
    wait_for_element_and_select(search_type_element, option)
    wait_for_element_and_type(search_term_element, text)
    wait_for_update_and_click search_button_element
  end

  def name_results
    result_name_elements.map(&:text).map &:strip
  end

  def uid_results
    result_uid_elements.map(&:text).map &:strip
  end

  def email_results
    result_email_elements.map(&:text).map &:strip
  end

  def user_checkbox(user)
    checkbox_element(id: "TBD #{user}")
  end

  def add_user_by_uid(user, section = nil)
    logger.info "Adding UID #{user.uid} with role '#{user.role}'"
    user_checkbox(user).when_present Utils.medium_wait
    user_checkbox(user).check
    if section
      option = section.sis_id ? section.sis_id : "#{section.course} #{section.label}"
      wait_for_element_and_select(course_section_element, option)
    end
    wait_for_element_and_select(user_role_element, user.role)
    wait_for_update_and_click add_user_button_element
    success_msg_element.when_visible Utils.medium_wait
  end
end
