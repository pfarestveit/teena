class SquiggyWhiteboardsPage

  include PageObject
  include Logging
  include Page
  include SquiggyPages

  def load_page(test)
    navigate_to test.course.whiteboards_url
    wait_until(Utils.medium_wait) { title == "#{SquiggyTool::WHITEBOARDS.name}" }
    hide_canvas_footer_and_popup
    switch_to_canvas_iframe
  end

  # CREATE WHITEBOARD

  link(:create_first_whiteboard_link, text: 'TODO')
  link(:add_whiteboard_link, xpath: 'TODO')
  text_area(:new_title_input, id: 'TODO')
  text_area(:new_collaborator_input, xpath: 'TODO')
  button(:create_whiteboard_button, xpath: 'TODO')
  link(:cancel_new_whiteboard_link, text: 'TODO')

  div(:title_req_msg, xpath: 'TODO')
  div(:title_max_length_msg, xpath: 'TODO')
  div(:no_collaborators_msg, xpath: 'TODO')

  def click_add_whiteboard
    wait_for_update_and_click add_whiteboard_link_element
  end

  def enter_whiteboard_title(title)
    wait_for_element_and_type_js(new_title_input_element, title)
  end

  def collaborator_option_link(user)
    button_element(xpath: 'TODO')
  end

  def collaborator_name(user)
    list_item_element(xpath: 'TODO')
  end

  def enter_whiteboard_collaborators(users)
    users.each do |user|
      wait_for_element_and_type_js(new_collaborator_input_element, user.full_name)
      wait_for_update_and_click collaborator_option_link(user)
      wait_until(Utils.short_wait) { collaborator_name user }
    end
  end

  def click_create_whiteboard
    wait_for_update_and_click create_whiteboard_button_element
  end

  def create_whiteboard(whiteboard)
    logger.info "Creating a new whiteboard named '#{whiteboard.title}'"
    click_add_whiteboard
    enter_whiteboard_title whiteboard.title
    enter_whiteboard_collaborators whiteboard.collaborators
    click_create_whiteboard
    verify_first_whiteboard whiteboard
  end

  # OPEN WHITEBOARD

  h2(:launch_failure, xpath: 'TODO')

  def create_and_open_whiteboard(whiteboard)
    create_whiteboard whiteboard
    open_whiteboard whiteboard
  end

  def open_whiteboard(whiteboard)
    logger.info "Opening whiteboard ID #{whiteboard.id}"
    click_whiteboard_link whiteboard
    shift_to_whiteboard_window(whiteboard)
  end

  # WHITEBOARDS LIST VIEW

  elements(:list_view_whiteboard, :list_item, xpath: 'TODO')
  elements(:list_view_whiteboard_title, :div, xpath: 'TODO')
  elements(:list_view_whiteboard_link, :link, xpath: 'TODO')

  def visible_whiteboard_titles
    list_view_whiteboard_title_elements.map &:text
  end

  def get_first_whiteboard_id
    wait_until(Utils.short_wait) { list_view_whiteboard_link_elements.any? }
    href = list_view_whiteboard_link_elements.first.attribute('href')
    whiteboard_url = href.split('?').first
    whiteboard_url.sub("#{SquiggyUtils.base_url}/whiteboards/", '')
  end

  def verify_first_whiteboard(whiteboard)
    # Pause to allow DOM update to complete
    sleep 1
    logger.debug "Verifying list view whiteboard title includes '#{whiteboard.title}'"
    wait_until(Utils.short_wait) { list_view_whiteboard_title_elements[0].text.include? whiteboard.title }
    logger.info "New whiteboard ID is #{whiteboard.id = get_first_whiteboard_id}"
  end

  def click_whiteboard_link(whiteboard)
    wait_until(Utils.short_wait) { list_view_whiteboard_link_elements.any? }
    link = list_view_whiteboard_link_elements.find { |link| link.attribute('href').include?("/whiteboards/#{whiteboard.id}?") }
    wait_for_update_and_click_js link
  end

  # SEARCH

  text_area(:simple_search_input, id: 'TODO')
  button(:simple_search_button, xpath: 'TODO')
  button(:open_advanced_search_button, xpath: 'TODO')
  text_area(:advanced_search_keyword_input, id: 'TODO')
  select_list(:advanced_search_user_select, id: 'TODO')
  checkbox(:include_deleted_cbx, id: 'TODO')
  link(:cancel_search_link, text: 'TODO')
  button(:advanced_search_button, xpath: 'TODO')
  span(:no_results_msg, xpath: 'TODO')

  def simple_search(string)
    logger.info "Performing simple search for '#{string}'"
    if cancel_search_link_element.visible?
      cancel_search_link
    end
    wait_for_element_and_type_js(simple_search_input_element, string)
    sleep 1
    wait_for_update_and_click_js simple_search_button_element
  end

  def advanced_search(string, user, inc_deleted)
    logger.info 'Performing advanced search'
    open_advanced_search_button unless advanced_search_keyword_input_element.visible?
    logger.debug "Search keyword is '#{string}'"
    string.nil? ?
      wait_for_element_and_type_js(advanced_search_keyword_input_element, '') :
      wait_for_element_and_type_js(advanced_search_keyword_input_element, string)
    sleep 1
    option = user.nil? ? 'Collaborator' : user.full_name
    wait_for_element_and_select_js(advanced_search_user_select_element, option)
    sleep 1
    inc_deleted ? check_include_deleted_cbx : uncheck_include_deleted_cbx
    wait_for_update_and_click_js advanced_search_button_element
  end
end
