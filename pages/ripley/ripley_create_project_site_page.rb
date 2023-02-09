require_relative '../../util/spec_helper'

class RipleyCreateProjectSitePage < RipleySiteCreationPage

  include PageObject
  include Logging
  include Page
  include RipleyPages

  text_area(:site_name_input, id: 'TBD')
  button(:create_site_button, id: 'TBD "Create a Project Site"')
  paragraph(:name_too_long_msg, id: 'TBD "Project site name must be no more than 255 characters in length"')

  def load_standalone_tool
    logger.info 'Loading standalone version of Create Project Site tool'
    navigate_to "#{RipleyUtils.base_url} TBD"
  end

  def enter_site_name(name)
    logger.info "Entering project site name '#{name}'"
    wait_for_element_and_type(site_name_input_element, name)
  end

  def create_project_site(name)
    logger.info 'Creating a project site'
    enter_site_name name
    wait_for_update_and_click create_site_button_element
  end
end
