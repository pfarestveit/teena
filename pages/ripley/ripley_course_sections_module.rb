require_relative '../../util/spec_helper'

module RipleyCourseSectionsModule

  include PageObject
  include Logging
  include Page
  include RipleyPages

  def available_course_heading_xpath(course)
    "//*[starts-with(text(), \"#{course.code}\")]"
  end

  def available_sections_form_button(course)
    button_element(xpath: "#{available_course_heading_xpath(course)}/ancestor::button")
  end

  def available_sections_course_title(course)
    el = div_element(xpath: "#{available_course_heading_xpath(course)}/descendant::span[starts-with(text(), \"— \") or starts-with(text(), \" — \")]")
    el.when_present Utils.short_wait
    el.text.gsub('—', '').gsub(':', '').strip
  rescue
    ''
  end

  def available_sections_select_all(course)
    text_field_element(xpath: "#{available_course_heading_xpath(course)}/ancestor::button/following-sibling::div//input[starts-with(@id, 'select-all-toggle')]")
  end

  def available_sections_table_xpath(course, section)
    "#{available_course_heading_xpath(course)}/ancestor::button/following-sibling::div//table[contains(., \"#{section.id}\")]"
  end

  def available_sections_table(course, section)
    table_element(xpath: available_sections_table_xpath(course, section))
  end

  elements(:section_panel, :div, xpath: '//div[contains(@id, "sections-course-")]')

  def expand_all_available_sections
    logger.debug 'Expanding all available sections'
    wait_until(Utils.medium_wait) { section_panel_elements.any? }
    logger.debug "There are #{section_panel_elements.length} sets of sections to expand"
    section_panel_elements.each_with_index do |_, i|
      btn = button_element(xpath: "(//button[contains(@class, 'v-expansion-panel-title')])[#{i + 1}]")
      btn.when_present 3
      if btn.attribute('aria-expanded') == 'false'
        logger.debug "Panel expansion button aria-expanded attribute is #{btn.attribute('aria-expanded')}"
        logger.debug "Expanding course section set #{i}"
        wait_for_update_and_click btn
      else
        logger.debug "Course section set #{i} is already expanded"
      end
    end
  end

  def expand_available_course_sections(course, section)
    wait_until(Utils.short_wait) { section_panel_elements.any? }
    scroll_to_top
    if available_sections_table(course, section).visible?
      logger.debug "The available sections table is already expanded for #{course.code}"
    else
      logger.debug "Expanding available sections table for #{course.code}"
      wait_for_update_and_click available_sections_form_button(course)
      available_sections_table(course, section).when_visible Utils.short_wait
      sleep 2
    end
  end

  def collapse_available_sections(course, section)
    if available_sections_table(course, section).visible?
      logger.debug "Collapsing the sections table for #{course.code}"
      wait_for_update_and_click available_sections_form_button(course)
      available_sections_table(course, section).when_not_visible Utils.short_wait
    else
      logger.debug "The sections table is already collapsed for #{course.code}"
    end
  end
end
