require_relative '../../util/spec_helper'

module BOACAddCuratedModalPages

  include PageObject
  include Logging
  include Page
  include BOACPages

  text_area(:curated_name_input, id: 'create-input')
  button(:curated_save_button, id: 'create-confirm')
  button(:curated_cancel_button, id: 'create-cancel')
  div(:dupe_curated_name_msg, xpath: '//div[text()="You have an existing curated group with this name. Please choose a different name."]')

  # Enters a curated group name in the 'create' modal
  # @param group [CuratedGroup]
  def enter_group_name(group)
    logger.debug "Entering curated group name '#{group.name}'"
    wait_for_element_and_type(curated_name_input_element, group.name)
  end

  # Enters a curated group name in the 'create' modal and clicks Save
  # @param group [CuratedGroup]
  def name_and_save_group(group)
    enter_group_name group
    wait_for_update_and_click curated_save_button_element
  end

  # Clicks Cancel in the curated group 'create' modal if it is open
  def cancel_group
    curated_cancel_button
    modal_element.when_not_present Utils.short_wait
  rescue
    logger.warn 'No cancel button to click'
  end

end
