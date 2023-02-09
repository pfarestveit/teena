require_relative '../../util/spec_helper'

class RipleyOfficialSectionsPage

  include PageObject
  include Logging
  include Page
  include RipleyPages

  link(:official_sections_link, text: 'Official Sections')
  button(:edit_sections_button, id: 'TBD "Edit Sections"')

  elements(:current_sections_table_row, :row, id: 'TBD')
  div(:section_name_msg, id: 'TBD "The section name in bCourses no longer matches the Student Information System."')
  button(:save_changes_button, id: 'TBD "Save Changes"')

  h2(:updating_sections_msg, id: 'TBD "Updating Official Sections in Course Site"')
  div(:sections_updated_msg, id: 'TBD "The sections in this course site have been updated successfully."')
  button(:update_msg_close_button, id: 'TBD')

  def embedded_tool_path(course)
    "/courses/#{course.site_id}/external_tools/#{Utils.canvas_official_sections_tool}"
  end

  def hit_embedded_tool_url(course)
    navigate_to "#{Utils.canvas_base_url}#{embedded_tool_path course}"
  end

  def load_embedded_tool(course)
    load_tool_in_canvas embedded_tool_path(course)
  end

  def load_standalone_tool(course)
    navigate_to "#{RipleyUtils.base_url}/canvas/course_manage_official_sections/#{course.site_id}"
  end

  def click_edit_sections
    logger.debug 'Clicking edit sections button'
    wait_for_load_and_click_js edit_sections_button_element
    save_changes_button_element.when_visible Utils.short_wait
  end

  def click_save_changes
    logger.debug 'Clicking save changes button'
    wait_for_update_and_click_js save_changes_button_element
  end

  def save_changes_and_wait_for_success
    click_save_changes
    updating_sections_msg_element.when_visible Utils.short_wait
    sections_updated_msg_element.when_visible Utils.long_wait
  end

  def close_section_update_success
    logger.debug 'Closing the section update success message'
    wait_for_update_and_click_js update_msg_close_button_element
  end

  # CURRENT SECTIONS

  def current_sections_table_xpath
    'TBD "Sections in this Course Site"'
  end

  def current_section_id_cell_xpath(section)
    "#{current_sections_table_xpath} TBD #{section.id}"
  end

  def current_sections_table
    table_element(xpath: current_sections_table_xpath)
  end

  def current_sections_count
    current_sections_table.when_visible Utils.medium_wait
    wait_until(Utils.short_wait) { current_sections_table_row_elements.any? }
    current_sections_table_row_elements.length - 1
  end

  def current_section_id_element(section)
    cell_element(xpath: current_section_id_cell_xpath(section))
  end

  def current_section_course(section)
    cell_element(xpath: "#{current_section_id_cell_xpath(section)} TBD").text
  end

  def current_section_label(section)
    cell_element(xpath: "#{current_section_id_cell_xpath(section)} TBD").text
  end

  def section_update_button(section)
    button_element(xpath: "#{current_section_id_cell_xpath(section)} TBD 'Update'")
  end

  def click_update_section(section)
    logger.debug "Clicking update button for section #{section.id}"
    wait_for_update_and_click_js section_update_button(section)
    sleep 1
  end

  def section_delete_button(section)
    button_element(xpath: "#{current_section_id_cell_xpath(section)} TBD 'Unlink'")
  end

  def click_delete_section(section)
    logger.debug "Clicking delete button for section #{section.id}"
    wait_for_update_and_click_js section_delete_button(section)
    sleep 1
  end

  def delete_sections(sections)
    sections.each { |section| click_delete_section(section) }
    click_save_changes
  end

  def section_undo_add_button(section)
    button_element(xpath: "#{current_section_id_cell_xpath(section)} TBD 'Undo Link'")
  end

  def click_undo_add_section(section)
    logger.debug "Clicking undo add button for section #{section.id}"
    wait_for_update_and_click_js section_undo_add_button(section)
    sleep 1
  end

  # AVAILABLE SECTIONS

  def available_sections_table_xpath(course_code)
    "TBD #{course_code}')]"
  end

  def available_section_cell_xpath(course_code, section_id)
    "#{available_sections_table_xpath(course_code)} TBD #{section_id}"
  end

  def available_sections_count(course)
    div_elements(xpath: "#{available_sections_table_xpath(course.code)} TBD").length
  end

  def available_section_data(course_code, section_id)
    {
      code: available_section_course(course_code, section_id),
      label: available_section_label(course_code, section_id),
      schedules: available_section_schedules(course_code, section_id),
      locations: available_section_locations(course_code, section_id),
      instructors: available_section_instructors(course_code, section_id)
    }
  end

  def available_section_id_element(course_code, section_id)
    cell_element(xpath: "#{available_sections_table_xpath(course_code)} TBD #{section_id}")
  end

  def available_section_course(course_code, section_id)
    cell_element(xpath: "#{available_section_cell_xpath(course_code, section_id)} TBD").text
  end

  def available_section_label(course_code, section_id)
    cell_element(xpath: "#{available_section_cell_xpath(course_code, section_id)} TBD").text
  end

  def available_section_schedules(course_code, section_id)
    cell_element(xpath: "#{available_section_cell_xpath(course_code, section_id)} TBD").text
  end

  def available_section_locations(course_code, section_id)
    cell_element(xpath: "#{available_section_cell_xpath(course_code, section_id)} TBD").text
  end

  def available_section_instructors(course_code, section_id)
    cell_element(xpath: "#{available_section_cell_xpath(course_code, section_id)} TBD").text
  end

  def section_add_button(course, section)
    button_element(xpath: "#{available_section_cell_xpath(course.code, section.id)} TBD")
  end

  def click_add_section(course, section)
    logger.debug "Clicking add button for section #{section.id}"
    wait_for_update_and_click_js section_add_button(course, section)
    sleep 1
  end

  def add_sections(course, sections)
    sections.each { |section| click_add_section(course, section) }
    click_save_changes
  end

  def section_added_element(course, section)
    div_element(xpath: "#{available_section_cell_xpath(course.code, section.id)} TBD")
  end

  def section_undo_delete_button(course, section)
    button_element(xpath: "#{available_section_cell_xpath(course.code, section.id)} TBD")
  end

  def click_undo_delete_section(course, section)
    logger.debug "Clicking undo delete button section #{section.id}"
    wait_for_update_and_click_js section_undo_delete_button(course, section)
    sleep 1
  end
end
