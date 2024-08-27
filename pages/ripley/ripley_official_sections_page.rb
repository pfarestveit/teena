require_relative '../../util/spec_helper'

class RipleyOfficialSectionsPage < RipleySiteCreationPage

  include PageObject
  include Logging
  include Page
  include RipleyPages
  include RipleyCourseSectionsModule

  link(:official_sections_link, text: 'Official Sections')
  button(:edit_sections_button, id: 'official-sections-edit-btn')

  div(:section_name_msg, xpath: '//div[contains(., "The section name in bCourses no longer matches the Student Information System.")]')
  button(:cancel_button, id: 'official-sections-cancel-btn')
  button(:save_changes_button, id: 'official-sections-save-btn')

  h2(:updating_sections_msg, xpath: '//*[contains(., "Updating Official Sections in Course Site")]')
  div(:sections_updated_msg, xpath: '//div[text()="The sections in this course site have been updated successfully."]')
  button(:update_msg_close_button, xpath: '//div[text()="The sections in this course site have been updated successfully."]/../following-sibling::div/button')

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

  def expected_instructors(section)
    section.instructors_and_roles.any? ? (section.instructors_and_roles.map { |i| i.user.full_name }).sort : ['—']
  end

  # STATIC VIEW - CURRENT SECTIONS

  elements(:static_view_section_row, :row, xpath: '//tr[contains(@id, "template-sections-table-preview")]')

  def static_view_sections_table
    table_element(id: 'template-sections-table-preview')
  end

  def static_sections_count
    static_view_sections_table.when_visible Utils.medium_wait
    wait_until(Utils.short_wait) { static_view_section_row_elements.any? }
    static_view_section_row_elements.length
  end

  def static_section_row(section)
    row_element(id: "template-sections-table-preview-#{section.id}")
  end

  def static_section_data(section)
    course_el = cell_element(id: "template-sections-table-preview-#{section.id}-course")
    label_el = cell_element(id: "template-sections-table-preview-#{section.id}-name")
    id_el = cell_element(id: "template-sections-table-preview-#{section.id}-id")
    schedule_els = div_elements(xpath: "//td[contains(@id, '#{section.id}-schedule')]/*")
    location_els = div_elements(xpath: "//td[contains(@id, '#{section.id}-location')]/*")
    instructor_el = div_element(xpath: "//td[contains(@id, '#{section.id}-instructors')]")
    {
      course: course_el&.text.to_s,
      label: label_el&.text.to_s,
      id: id_el&.text.to_s,
      schedules: (schedule_els.map { |el| el.text.strip.upcase }.delete_if(&:empty?) if schedule_els.any?),
      locations: (location_els.map { |el| el.text.strip }.delete_if(&:empty?) if location_els.any?),
      instructors: (instructor_el.text.gsub('Instructors:', '').strip.split("\n") if instructor_el.exists?)
    }
  end

  # EDIT MODE - CURRENT SECTIONS

  elements(:current_sections_table_row, :row, xpath: '//table[@id="template-sections-table"]/tbody/tr')

  def current_sections_table
    table_element(id: 'template-sections-table')
  end

  def current_sections_table_xpath
    '//table[@id="template-sections-table"]'
  end

  def current_sections_count
    current_sections_table.when_visible Utils.medium_wait
    wait_until(Utils.short_wait) { current_sections_table_row_elements.any? }
    current_sections_table_row_elements.length
  end

  def current_section_row(section)
    row_element(id: "template-sections-table-#{section.id}")
  end

  def current_section_data(section)
    course_el = cell_element(id: "template-sections-table-#{section.id}-course")
    label_el = cell_element(id: "template-sections-table-#{section.id}-name")
    id_el = cell_element(id: "template-sections-table-#{section.id}-id")
    schedule_els = div_elements(xpath: "#{current_sections_table_xpath}//td[contains(@id, '#{section.id}-schedule')]/*")
    location_els = div_elements(xpath: "#{current_sections_table_xpath}//td[contains(@id, '#{section.id}-location')]/*")
    instructor_el = div_element(xpath: "#{current_sections_table_xpath}//td[contains(@id, '#{section.id}-instructors')]")
    {
      course: course_el&.text.to_s,
      label: label_el&.text.to_s,
      id: id_el&.text.to_s,
      schedules: (schedule_els.map { |el| el.text.strip.upcase }.delete_if(&:empty?) if schedule_els.any?),
      locations: (location_els.map { |el| el.text.strip }.delete_if(&:empty?) if location_els.any?),
      instructors: (instructor_el.text.gsub('Instructors:', '').strip.split("\n") if instructor_el.exists?)
    }
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
    button_element(id: "section-#{section.id}-undo-link-btn")
  end

  def click_undo_add_section(section)
    logger.debug "Clicking undo add button for section #{section.id}"
    wait_for_update_and_click section_undo_add_button(section)
    sleep 1
  end

  # EDIT MODE - AVAILABLE SECTIONS

  def available_sections_count(course, section)
    div_elements(xpath: "#{available_sections_table_xpath(course, section)}//td[contains(@id, '-course')]").length
  end

  def available_section_row(course, section)
    row_element(xpath: "#{available_sections_table_xpath(course, section)}//tr[contains(@id, \"#{section.id}\")]")
  end

  def available_section_data(course, section)
    course_el = cell_element(xpath: "#{available_sections_table_xpath(course, section)}//td[contains(@id, \"#{section.id}-course\")]")
    label_el = cell_element(xpath: "#{available_sections_table_xpath(course, section)}//td[contains(@id, \"#{section.id}-name\")]")
    id_el = cell_element(xpath: "#{available_sections_table_xpath(course, section)}//td[contains(@id, \"#{section.id}-id\")]")
    schedule_els = div_elements(xpath: "#{available_sections_table_xpath(course, section)}//td[contains(@id, '#{section.id}-schedule')]/*")
    location_els = div_elements(xpath: "#{available_sections_table_xpath(course, section)}//td[contains(@id, '#{section.id}-location')]/*")
    instructor_el = div_element(xpath: "#{available_sections_table_xpath(course, section)}//td[contains(@id, '#{section.id}-instructors')]")
    {
      course: course_el&.text.to_s,
      label: label_el&.text.to_s,
      id: id_el&.text.to_s,
      schedules: (schedule_els.map { |el| el.text.strip.upcase }.delete_if(&:empty?) if schedule_els.any?),
      locations: (location_els.map { |el| el.text.strip }.delete_if(&:empty?) if location_els.any?),
      instructors: (instructor_el.text.gsub('Instructors:', '').strip.split("\n") if instructor_el.exists?)
    }
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
    div_element(xpath: "#{available_sections_table_xpath(course, section)}//td[contains(@id, '#{section.id}-actions')]/div[contains(.,'Linked')]")
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
