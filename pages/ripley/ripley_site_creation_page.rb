require_relative '../../util/spec_helper'

class RipleySiteCreationPage

  include PageObject
  include Logging
  include Page
  include RipleyPages

  h1(:page_heading, id: 'TBD "Create a Site"')

  def load_embedded_tool(user)
    logger.info 'Loading embedded version of Create Course Site tool'
    load_tool_in_canvas"/users/#{user.canvas_id}/external_tools/#{Utils.canvas_create_site_tool}"
  end

  def load_standalone_tool
    navigate_to "#{RipleyUtils.base_url} TBD"
  end

  def wait_for_site_id(course)
    wait_until(Utils.long_wait) { current_url.include? "#{Utils.canvas_base_url}/courses" }
    course.site_id = current_url.delete "#{Utils.canvas_base_url}/courses/"
    logger.info "Site ID is #{course.site_id}"
  end

  # Course site

  link(:create_course_site_link, id: 'TBD')
  paragraph(:course_sites_msg, id: 'TBD "Set up course sites to communicate with and manage the work of students enrolled in your classes."')
  paragraph(:no_course_sites_msg, id: 'TBD "It appears that you do not have permissions to create a Course Site in the current or upcoming terms."')
  link(:bcourses_support_link, id: 'TBD "bCourses support"')

  def click_create_course_site
    wait_for_load_and_click create_course_site_link_element
  end

  # Project site

  link(:create_project_site_link, id: 'TBD')
  link(:project_help_link, id: 'TBD')
  link(:projects_learn_more_link, id: 'TBD')

  def click_create_project_site
    wait_for_update_and_click create_project_site_link_element
  end
end
