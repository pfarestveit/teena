require_relative '../../util/spec_helper'

class RipleyOfficialSectionsPage

  include PageObject
  include Logging
  include Page
  include RipleyPages
  include RipleyCourseSectionsModule

  link(:official_sections_link, text: 'Official Sections')
  button(:edit_sections_button, id: 'official-sections-edit-btn')

  elements(:current_sections_table_row, :row, xpath: '//h3[text()=" Sections in this Course Site "]/../following-sibling::div//tbody/tr')
  div(:section_name_msg, xpath: '//div[contains(., "The section name in bCourses no longer matches the Student Information System.")]')
  button(:cancel_button, id: 'official-sections-cancel-btn')
  button(:save_changes_button, id: 'official-sections-save-btn')

  h2(:updating_sections_msg, xpath: '//*[contains(., "Updating Official Sections in Course Site")]')
  div(:sections_updated_msg, xpath: '//div[text()="The sections in this course site have been updated successfully."]')
  button(:update_msg_close_button, xpath: '//button[@aria-label="Hide notice"]')

  def embedded_tool_path(course)
    "/courses/#{course.site_id}/external_tools/#{RipleyTool::OFFICIAL_SECTIONS.tool_id}"
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
    wait_for_load_and_click edit_sections_button_element
    save_changes_button_element.when_visible Utils.short_wait
  end

  def click_save_changes
    logger.debug 'Clicking save changes button'
    wait_for_update_and_click save_changes_button_element
  end

  def save_changes_and_wait_for_success
    click_save_changes
    updating_sections_msg_element.when_visible Utils.short_wait
    sections_updated_msg_element.when_visible Utils.long_wait
  end

  def close_section_update_success
    logger.debug 'Closing the section update success message'
    wait_for_update_and_click update_msg_close_button_element
  end

  # LIST VIEW - CURRENT SECTIONS

  def list_section_row(section)
    row_element(id: "template-sections-table-row-preview-#{section.id}")
  end

  def list_section_row_xpath(section)
    "//tr[@id=\"template-sections-table-row-preview-#{section.id}\"]"
  end

  def list_section_course(section)
    cell_element(xpath: "#{list_section_row_xpath(section)}//td[contains(@class,\"course-code\")]").text
  end

  def list_section_label(section)
    cell_element(xpath: "#{list_section_row_xpath(section)}//td[contains(@class,\"section-label\")]").text
  end


  # EDIT MODE - CURRENT SECTIONS

  def current_sections_table_xpath
    "//h3[text()=\" Sections in this Course Site \"]/../following-sibling::div//table"
  end

  def current_section_row(section)
    row_element(id: "template-sections-table-row-currentstaging-#{section.id}")
  end

  def current_section_row_xpath(section)
    "//tr[@id=\"template-sections-table-row-currentstaging-#{section.id}\"]"
  end

  def current_section_id_cell_xpath(section)
    "#{current_section_row_xpath section}//td[contains(@class, \"section-id\")]"
  end

  def current_sections_table
    table_element(xpath: current_sections_table_xpath)
  end

  def current_sections_count
    current_sections_table.when_visible Utils.medium_wait
    wait_until(Utils.short_wait) { current_sections_table_row_elements.any? }
    current_sections_table_row_elements.length
  end

  def current_section_id_element(section)
    cell_element(xpath: current_section_id_cell_xpath(section))
  end

  def current_section_course(section)
    cell_element(xpath: "#{current_section_row_xpath(section)}//td[contains(@class,\"course-code\")]").text
  end

  def current_section_label(section)
    cell_element(xpath: "#{current_section_row_xpath(section)}//td[contains(@class,\"section-label\")]").text
  end

  def section_update_button(section)
    button_element(id: "section-#{section.id}-update-btn")
  end

  def click_update_section(section)
    logger.debug "Clicking update button for section #{section.id}"
    wait_for_update_and_click section_update_button(section)
    sleep 1
  end

  def section_delete_button(section)
    button_element(id: "section-#{section.id}-unlink-btn")
  end

  def click_delete_section(section)
    logger.debug "Clicking delete button for section #{section.id}"
    wait_for_update_and_click section_delete_button(section)
    sleep 1
  end

  def delete_sections(sections)
    sections.each { |section| click_delete_section(section) }
    click_save_changes
  end

  def section_undo_add_button(section)
    button_element(id: "section-#{section.id}-undo-unlink-btn")
  end

  def click_undo_add_section(section)
    logger.debug "Clicking undo add button for section #{section.id}"
    wait_for_update_and_click section_undo_add_button(section)
    sleep 1
  end

  # EDIT MODE - AVAILABLE SECTIONS

  def available_section_cell_xpath(course, section)
    "#{available_sections_os_table_xpath(course, section)}//td[contains(.,\"#{section.id}\")]"
  end

  def available_sections_count(course, section)
    div_elements(xpath: "#{available_sections_os_table_xpath(course, section)}/tbody").length
  end

  def available_section_data(course, section)
    {
      code: available_section_course(course, section),
      label: available_section_label(course, section),
      schedules: available_section_schedules(course, section),
      locations: available_section_locations(course, section),
      instructors: available_section_instructors(course, section)
    }
  end

  def available_section_id_element(course, section)
    cell_element(xpath: "#{available_sections_os_table_xpath(course, section)}//td[contains(.,\"#{section.id}\")]")
  end

  def available_section_course(course, section)
    cell_element(xpath: "#{available_section_cell_xpath(course, section)}/preceding-sibling::td[contains(@class,\"course-code\")]").text
  end

  def available_section_label(course, section)
    cell_element(xpath: "#{available_section_cell_xpath(course, section)}/preceding-sibling::td[contains(@class,\"section-label\")]").text
  end

  def available_section_schedules(course, section)
    sched = cell_element(xpath: "#{available_section_cell_xpath(course, section)}/following-sibling::td[contains(@class,\"section-timestamps\")]").text.to_s
    sched = sched.upcase.split("\n") unless sched.empty?
    sched
  end

  def available_section_locations(course, section)
    loc = cell_element(xpath: "#{available_section_cell_xpath(course, section)}/following-sibling::td[contains(@class,\"section-locations\")]").text.to_s
    loc = loc.split("\n") unless loc.empty?
    loc
  end

  def available_section_instructors(course, section)
    cell_element(xpath: "#{available_section_cell_xpath(course, section)}/following-sibling::td[contains(@class,\"section-instructors\")]").text
  end

  def section_add_button(section)
    button_element(id: "section-#{section.id}-link-btn")
  end

  def click_add_section(course, section)
    logger.debug "Clicking add button for section #{section.id}"
    wait_for_update_and_click section_add_button(section)
    sleep 1
  end

  def add_sections(course, sections)
    sections.each { |section| click_add_section(course, section) }
    click_save_changes
  end

  def section_added_element(course, section)
    div_element(xpath: "#{available_section_cell_xpath(course, section)}/following-sibling::td[contains(@class,\"section-action-option\")]//div[contains(.,'Linked')]")
  end

  def section_undo_delete_button(section)
    button_element(id: "section-#{section.id}-undo-unlink-btn")
  end

  def click_undo_delete_section(section)
    logger.debug "Clicking undo delete button section #{section.id}"
    wait_for_update_and_click section_undo_delete_button(section)
    sleep 1
  end
end
