require_relative '../../util/spec_helper'

class RipleyRosterPhotosPage

  include PageObject
  include Logging
  include Page
  include RipleyPages

  link(:roster_photos_link, text: RipleyTool::ROSTER_PHOTOS.name)

  text_field(:search_input, id: 'roster-search')
  select_list(:section_select, id: 'section-select')
  button(:export_roster_link, id: 'download-csv')
  link(:print_roster_link, id: 'print-roster')
  element(:wait_for_load_msg, xpath: '//*[text()="You can print when student images have loaded."]')

  div(:no_access_msg, xpath: '//div[text()="You must be a teacher in this bCourses course to view official student rosters."]')
  div(:no_students_msg, id: 'TBD "Students have not yet signed up for this class."')

  elements(:roster_photo, :image, xpath: '//img[contains(@src, "/cal1card-data/photos/")]')
  elements(:roster_photo_placeholder, :image, xpath: '//img[contains(@src, "photo_unavailable")]')
  elements(:roster_sid, :span, xpath: '//div[contains(@id, "student-id-")]')

  def embedded_tool_path(course)
    "/courses/#{course.site_id}/external_tools/#{RipleyTool::ROSTER_PHOTOS.tool_id}"
  end

  def hit_embedded_tool_url(course)
    navigate_to "#{Utils.canvas_base_url}#{embedded_tool_path course}"
  end

  def load_embedded_tool(course)
    logger.info 'Loading embedded version of Roster Photos tool'
    load_tool_in_canvas embedded_tool_path(course)
  end

  def load_standalone_tool(course)
    logger.info 'Loading standalone version of Roster Photos tool'
    navigate_to "#{RipleyUtils.base_url}/roster/#{course.site_id}"
    hide_header
  end

  def click_roster_photos_link
    logger.info 'Clicking Roster Photos link'
    wait_for_load_and_click roster_photos_link_element
    switch_to_canvas_iframe RipleyUtils.base_url
  end

  def wait_for_photos_to_load
    wait_for_load_msg_element.when_not_visible Utils.medium_wait
    wait_until(Utils.short_wait) { roster_photo_elements.any? }
  end

  def section_options
    section_select_options
  end

  def filter_by_string(string)
    logger.debug "Filtering roster by '#{string}'"
    wait_for_textbox_and_type(search_input_element, string)
    sleep 1
  end

  def filter_by_section(section)
    logger.info "Filtering roster by section "#{section.course} #{section.label}""
    wait_for_element_and_select(section_select_element, "#{section.course} #{section.label}")
    sleep 1
  end

  def click_student_profile_link(course, student)
    el = link_element(xpath: "//a[contains(@href, '#{course.site.id}/profile/#{student.canvas_id}')]")
    wait_for_update_and_click el
    wait_until(Utils.short_wait) { h1_element(xpath: "//h1[contains(text(), \"#{student.full_name}\")]") }
  end

  def export_roster(course)
    logger.info "Downloading roster CSV for course ID #{course.site_id}"
    parsed = parse_downloaded_csv(export_roster_link_element,"course_#{course.site_id}_rosters*.csv")
    parsed.map { |r| r[:student_id] }
  end

  def all_sids
    roster_sid_elements.map { |el| el.attribute('innerText').gsub('Student ID:', '').strip }
  end
end
