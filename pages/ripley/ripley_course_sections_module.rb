require_relative '../../util/spec_helper'

module RipleyCourseSectionsModule

  include PageObject
  include Logging
  include Page
  include RipleyPages

  def available_sections_form_button(course)
    button_element(xpath: "//h4[@id=\"available-course-header\"][contains(., \"#{course.code}\")]/..")
  end

  def available_sections_course_title(course)
    el = div_element(xpath: "//h4[@id=\"available-course-header\"][contains(., \"#{course.code}\")]/div[2]")
    el.when_visible Utils.short_wait
    el.text.strip
  rescue
    ''
  end

  def available_sections_table_xpath(course, section)
    "//h4[@id=\"available-course-header\"][contains(., \"#{course.code}\")]/../following-sibling::div//table[contains(., \"#{section.id}\")]"
  end

  def available_sections_table(course, section)
    table_element(xpath: available_sections_table_xpath(course, section))
  end

  def expand_available_sections(course, section)
    if available_sections_table(course, section).exists?
      logger.debug "The available sections table is already expanded for #{course.code}"
    else
      logger.debug "Expanding available sections table for #{course.code}"
      wait_for_update_and_click available_sections_form_button(course)
      available_sections_table(course, section).when_visible Utils.short_wait
      sleep Utils.click_wait
    end
  end

  def collapse_available_sections(course, section)
    if available_sections_table(course, section).exists?
      logger.debug "Collapsing the sections table for #{course.code}"
      wait_for_update_and_click available_sections_form_button(course)
      available_sections_table(course, section).when_not_visible Utils.short_wait
    else
      logger.debug "The sections table is already collapsed for #{course.code}"
    end
  end
end
