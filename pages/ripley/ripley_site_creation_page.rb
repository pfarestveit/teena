require_relative '../../util/spec_helper'

class RipleySiteCreationPage

  include PageObject
  include Logging
  include Page
  include RipleyPages

  h1(:page_heading, xpath: '//h1[text()="Create a Site"]')

  def load_embedded_tool(user)
    logger.info 'Loading embedded version of Create Course Site tool'
    load_tool_in_canvas"/users/#{user.canvas_id}/external_tools/#{RipleyTool::CREATE_SITE.tool_id}"
  end

  def load_standalone_tool
    navigate_to "#{RipleyUtils.base_url} TBD"
  end

  def wait_for_site_id(site)
    wait_until(Utils.long_wait) { current_url.include? "#{Utils.canvas_base_url}/courses" }
    site.site_id = current_url.delete "#{Utils.canvas_base_url}/courses/"
    logger.info "Site ID is #{site.site_id}"
  end

  # Course site

  link(:create_course_site_link, id: 'create-course-site')
  paragraph(:course_sites_msg, xpath: '//div[text()=" Set up course sites to communicate with and manage the work of students enrolled in your classes. "]')
  paragraph(:no_course_sites_msg, id: 'TBD "It appears that you do not have permissions to create a Course Site in the current or upcoming terms."')
  link(:bcourses_support_link, id: 'TBD "bCourses support"')

  def click_create_course_site
    wait_for_load_and_click create_course_site_link_element
  end

  # Project site

  link(:create_project_site_link, id: 'create-project-site')
  link(:project_help_link, id: 'bcourses-project-sites-service-page')
  link(:projects_learn_more_link, id: 'berkeley-collaboration-services-information')

  def click_create_project_site
    wait_for_update_and_click create_project_site_link_element
  end
end
