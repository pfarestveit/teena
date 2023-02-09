require_relative '../../util/spec_helper'

class RipleyRosterPhotosPage

  include PageObject
  include Logging
  include Page
  include RipleyPages

  link(:roster_photos_link, text: 'Roster Photos')

  text_area(:search_input, id: 'TBD')
  select_list(:section_select, id: 'TBD')
  button(:export_roster_link, id: 'TBD')
  link(:print_roster_link, id: 'TBD')

  div(:no_access_msg, id: 'TBD "You must be a teacher in this bCourses course to view official student rosters."')
  div(:no_students_msg, id: 'TBD "Students have not yet signed up for this class."')

  elements(:roster_photo, :image, id: 'TBD')
  elements(:roster_photo_placeholder, :image, id: 'TBD')
  elements(:roster_sid, :span, id: 'TBD')

  def embedded_tool_path(course)
    "/courses/#{course.site_id}/external_tools/#{Utils.canvas_rosters_tool}"
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
    navigate_to "#{RipleyUtils.base_url}/canvas/rosters/#{course.site_id}"
  end

  def click_roster_photos_link
    logger.info 'Clicking Roster Photos link'
    wait_for_load_and_click_js roster_photos_link_element
    switch_to_canvas_iframe RipleyUtils.base_url
  end

  def section_options
    section_select_options.reject { |o| o == 'All sections' }
  end

  def filter_by_string(string)
    logger.debug "Filtering roster by '#{string}'"
    wait_for_element_and_type(search_input_element, string)
    sleep 1
  end

  def filter_by_section(section)
    wait_for_element_and_select(section_select_element, "#{section.course} #{section.label}")
    sleep 1
  end

  def export_roster(course)
    logger.info "Downloading roster CSV for course ID #{course.site_id}"
    Utils.prepare_download_dir
    wait_for_update_and_click export_roster_link_element
    csv_file_path = "#{Utils.download_dir}/course_#{course.site_id}_rosters.csv"
    wait_until(Utils.medium_wait) { Dir[csv_file_path].any? }
    csv = CSV.read(csv_file_path, headers: true)
    sids = []
    csv.each { |r| sids << r['Student ID'] }
    sids
  end

  def all_sids
    roster_sid_elements.map { |el| 'TBD' }
  end
end
