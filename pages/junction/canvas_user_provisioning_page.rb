class CanvasUserProvisioningPage

  include PageObject
  include Logging
  include Page
  include JunctionPages

  text_area(:uid_input, id: 'cc-page-user-provision-uid-list')
  button(:import_button, xpath: '//button[contains(text(), "Import Users")]')
  div(:success_msg, xpath: '//div[contains(., "Success : The users specified were imported into bCourses.")]')
  div(:error_msg, xpath: '//div[@class="cc-page-user-provision-feedback"]//strong[contains(., "Error :")]')
  div(:non_numeric_msg, xpath: '//small[contains(., "The following items in your list are not numeric:")]')
  div(:max_input_msg, xpath: '//small[contains(., "Maximum IDs: 200.")]')

  def load_embedded_tool
    logger.info 'Loading embedded version of the User Provisioning tool'
    load_tool_in_canvas "/accounts/#{Utils.canvas_uc_berkeley_sub_account}/external_tools/#{JunctionUtils.user_prov_tool}"
  end

  def load_standalone_tool
    logger.info 'Loading standalone version of the User Provisioning tool'
    navigate_to "#{JunctionUtils.junction_base_url}/canvas/embedded/user_provision"
  end

  def enter_uids_and_submit(uids_string)
    logger.info "Entering string to import: #{uids_string}"
    wait_for_element_and_type(uid_input_element, uids_string)
    wait_for_update_and_click import_button_element
  end

end
