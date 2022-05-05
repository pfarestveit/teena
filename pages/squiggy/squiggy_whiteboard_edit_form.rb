module SquiggyWhiteboardEditForm

  include PageObject
  include Logging
  include Page
  include SquiggyPages

  text_field(:whiteboard_title_input, id: 'whiteboard-title-input')
  elements(:collaborator_name, :span, xpath: '//span[@class="v-chip__content"]')
  text_area(:collaborators_input, id: 'whiteboard-users-select')
  elements(:remove_collaborator_button, :button, xpath: '//span[@class="v-chip__content"]/button')
  div(:title_max_length_msg, xpath: '//div[text()="Title must be 255 characters or less"]')
  div(:no_collaborators_msg, xpath: 'TODO')

  def enter_whiteboard_title(title)
    wait_for_element_and_type_js(whiteboard_title_input_element, title)
  end

  def collaborator_option_link(user)
    menu_option_el(user.full_name)
  end

  def collaborator_name(user)
    span_element(xpath: "//span[@class=\"v-chip__content\"][contains(text(), \"#{user.full_name}\")]")
  end

  def enter_whiteboard_collaborator(user)
    wait_for_update_and_click_js collaborators_input_element
    select_squiggy_option user.full_name
    collaborator_name(user).when_visible Utils.short_wait
  end

  def save_whiteboard
    wait_for_update_and_click_js save_button_element
    save_button_element.when_not_present Utils.short_wait
  end

  def click_remove_collaborator(user)
    logger.debug "Clicking the remove button for #{user.full_name}"
    wait_for_update_and_click button_element(xpath: 'TODO')
    collaborator_name(user).when_not_visible Utils.short_wait
  end

end
