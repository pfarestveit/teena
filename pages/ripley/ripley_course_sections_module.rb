require_relative '../../util/spec_helper'

module RipleyCourseSectionsModule

  include PageObject
  include Logging
  include Page
  include RipleyPages

  def available_sections_form_button(course_code)
    button_element(id: "TBD #{course_code}")
  end

  def available_sections_course_title(course_code)
    logger.debug "Looking for the course title for course code #{course_code}"
    el = span_element(id: "TBD #{course_code}")
    el.when_visible Utils.short_wait
    el.text.strip
  rescue
    ''
  end

  def available_sections_table(course_code)
    table_element(id: "TBD #{course_code.downcase.gsub(' ', '-')}")
  end

  def expand_available_sections(course_code)
    if available_sections_table(course_code).exists? && available_sections_table(course_code).visible?
      logger.debug "The sections table is already expanded for #{course_code}"
    else
      wait_for_update_and_click available_sections_form_button(course_code)
      available_sections_table(course_code).when_visible Utils.short_wait
      sleep Utils.click_wait
    end
  end

  def collapse_available_sections(course_code)
    if available_sections_table(course_code).exists? && available_sections_table(course_code).visible?
      wait_for_update_and_click available_sections_form_button(course_code)
      available_sections_table(course_code).when_not_visible Utils.short_wait
    else
      logger.debug "The sections table is already collapsed for #{course_code}"
    end
  end
end
