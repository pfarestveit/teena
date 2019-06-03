require_relative '../../util/spec_helper'

module BOACGroupModalPages

  include PageObject
  include Logging
  include Page
  include BOACPages

  text_area(:grp_name_input, id: 'create-input')
  button(:grp_save_button, id: 'create-confirm')
  button(:grp_cancel_button, id: 'create-cancel')
  div(:dupe_grp_name_msg, xpath: '//div[text()="You have an existing curated group with this name. Please choose a different name."]')

  # Enters a group name in the 'create' modal
  # @param group [CuratedGroup]
  def enter_group_name(group)
    logger.debug "Entering group name '#{group.name}'"
    wait_for_element_and_type(grp_name_input_element, group.name)
  end

  # Enters a group name in the 'create' modal and clicks Save
  # @param group [CuratedGroup]
  def name_and_save_group(group)
    enter_group_name group
    wait_for_update_and_click grp_save_button_element
  end

  # Clicks Cancel in the group 'create' modal
  def cancel_group
    grp_cancel_button
    modal_element.when_not_present Utils.short_wait
  end

end
