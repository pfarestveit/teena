require_relative '../../util/spec_helper'

class RipleyCourseCapturesPage

  include PageObject
  include Logging
  include Page
  include RipleyPages

  link(:course_captures_link, text: 'Course Captures')
  elements(:section_content, :div, id: 'TBD')
  elements(:section_code, :h3, id: 'TBD')
  elements(:you_tube_alert, :div, id: 'TBD "Log in to YouTube with your bConnected account to watch the videos below."')
  link(:report_problem, id: 'TBD "Report a problem"')

  def load_embedded_tool(course)
    logger.info "Loading course capture tool on site ID #{course.site_id}"
    load_tool_in_canvas"/courses/#{course.site_id}/external_tools/#{Utils.canvas_course_captures_tool}"
  end

  def load_standalone_tool(course)
    logger.info "Loading standalone course capture tool for site ID #{course.site_id}"
    navigate_to "#{RipleyUtils.base_url}/ TBD /#{course.site_id}"
  end

  def section_course_code(index)
    section_code_elements[index]&.text
  end

  def section_recordings_index(section_code = nil)
    wait_until(Utils.medium_wait) { section_content_elements.any? }
    section_els = section_content_elements
    if section_els.length > 1
      el = section_els.find { |el| el.text.include? section_code }
      section_els.index el
    else
      0
    end
  end

  def you_tube_recording_elements(index)
    link_elements(id: "TBD #{index}")
  end

  def you_tube_link(video_id)
    link_element(id: "TBD #{video_id}")
  end

  def help_page_link(index)
    link_element(id: "TBD #{index}")
  end
end
