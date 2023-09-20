require_relative '../../util/spec_helper'

class RipleyCreateProjectSitePage < RipleySiteCreationPage

  include PageObject
  include Logging
  include Page
  include RipleyPages

  text_area(:site_name_input, id: 'page-create-project-site-name')
  button(:create_site_button, id: 'create-project-site-button')
  button(:cancel_project_site_button, id: 'cancel-and-return-to-site-creation')

  def load_standalone_tool
    logger.info 'Loading standalone version of Create Project Site tool'
    navigate_to "#{RipleyUtils.base_url} TBD"
  end

  def cancel_project_site
    logger.info 'Canceling project site'
    wait_for_update_and_click cancel_project_site_button_element
  end

  def enter_site_name(name)
    logger.info "Entering project site name '#{name}'"
    wait_for_textbox_and_type(site_name_input_element, name)
  end

  def create_project_site(name)
    logger.info 'Creating a project site'
    enter_site_name name
    wait_for_update_and_click create_site_button_element
  end
end
