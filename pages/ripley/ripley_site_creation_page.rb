require_relative '../../util/spec_helper'

class RipleySiteCreationPage

  include PageObject
  include Logging
  include Page
  include RipleyPages

  h1(:page_heading, xpath: '//h1[text()="Create a Site"]')
  button(:go_next_button, id: 'go-next-btn')

  def load_embedded_tool(user)
    logger.info 'Loading embedded version of Create Course Site tool'
    load_tool_in_canvas"/users/#{user.canvas_id}/external_tools/#{RipleyTool::MANAGE_SITES.tool_id}"
  end

  def load_standalone_tool
    navigate_to "#{RipleyUtils.base_url} TBD"
  end

  def wait_for_site_id(course_site)
    begin
      tries ||= Utils.long_wait
      wait_until(1) { current_url.include?("#{Utils.canvas_base_url}/courses") }
    rescue Selenium::WebDriver::Error::TimeoutError
      if sis_import_error?
        fail 'Site provisioning failed'
      elsif (tries -= 1).zero?
        fail 'Timed out waiting for site provisioning'
      else
        retry
      end
    end
    course_site.site_id = current_url.delete "#{Utils.canvas_base_url}/courses/"
    logger.info "Site ID is #{course_site.site_id}"
  end

  # Course site

  radio_button(:create_course_site_link, id: 'create-course-site')
  div(:course_sites_msg, xpath: '//div[text()=" Set up course sites to communicate with and manage the work of students enrolled in your classes. "]')
  div(:no_course_sites_msg, div: '//div[contains(text(), "To create a course site, you will need to be the official instructor of record for a course.")]')

  def click_create_course_site
    logger.info 'Selecting create course site and continue'
    wait_for_load_and_click create_course_site_link_element
    wait_for_update_and_click go_next_button_element
  end

  # Project site

  link(:create_project_site_link, id: 'create-project-site')
  link(:project_help_link, id: 'bcourses-project-sites-service-page')
  link(:projects_learn_more_link, id: 'berkeley-collaboration-services-information')

  def click_create_project_site
    logger.info 'Selecting create project site and continue'
    wait_for_update_and_click create_project_site_link_element
    wait_for_update_and_click go_next_button_element
  end

  # Manage official sections

  link(:manage_sections_link, id: 'manage-official-sections')
  span(:no_managing_sections_msg, xpath: '//span[contains(text(), "Sorry, we found neither")]')
  text_field(:manage_sections_site_input, id: 'canvas-site-id-input')
  select_list(:manage_sections_site_select, id: 'course-sections')

  def select_site_and_manage(course_site)
    logger.info "Selecting site ID #{course_site.site_id} in #{course_site.course.term.name} and continuing"
    wait_for_update_and_click manage_sections_link_element
    wait_for_element_and_select(manage_sections_site_select_element, course_site.site_id)
    wait_for_update_and_click go_next_button_element
  end

  def enter_site_and_manage(course_site)
    logger.info "Entering site ID #{course_site.site_id} and continuing"
    wait_for_update_and_click manage_sections_link_element
    wait_for_textbox_and_type(manage_sections_site_input_element, course_site.site_id)
    wait_for_update_and_click go_next_button_element
  end
end
