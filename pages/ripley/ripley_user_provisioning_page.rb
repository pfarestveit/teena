require_relative '../../util/spec_helper'

class RipleyUserProvisioningPage

  include PageObject
  include Logging
  include Page
  include RipleyPages

  text_area(:uid_input, id: 'page-user-provision-uid-list')
  button(:import_button, id: 'user-provision-import-btn')
  div(:success_msg, xpath: '//div[contains(., "Success : The users specified were imported into bCourses.")]')
  div(:error_msg, id: 'TBD')
  div(:non_numeric_msg, xpath: '//div[contains(., "The following items in your list are not numeric:")]')
  div(:max_input_msg, xpath: '//div[contains(., "Maximum IDs: 200.")]')

  def load_embedded_tool
    logger.info 'Loading embedded version of the User Provisioning tool'
    load_tool_in_canvas "/accounts/#{Utils.canvas_uc_berkeley_sub_account}/external_tools/#{RipleyTool::USER_PROVISIONING.tool_id}"
  end

  def load_standalone_tool
    logger.info 'Loading standalone version of the User Provisioning tool'
    navigate_to "#{RipleyUtils.base_url} TBD"
  end

  def enter_uids_and_submit(uids_string)
    logger.info "Entering string to import: #{uids_string}"
    wait_for_textbox_and_type(uid_input_element, uids_string)
    wait_for_update_and_click import_button_element
  end
end
