class BOACDegreeCheckTemplatePage

  include PageObject
  include Page
  include BOACPages
  include Logging

  def template_heading(template)
    h1_element(xpath: "//h1[text()=\"#{template.name}\"]")
  end

  # UNIT REQS

  # Create

  button(:unit_req_add_button, id: 'unit-requirement-create-link')
  text_field(:unit_req_name_input, id: 'unit-requirement-name-input')
  text_field(:unit_req_num_input, id: 'unit-requirement-min-units-input')
  button(:unit_req_create_button, id: 'create-unit-requirement-btn')
  button(:unit_req_cancel_button, id: 'cancel-create-unit-requirement-btn')

  def click_add_unit_req
    logger.info 'Clicking the add unit req button'
    wait_for_update_and_click unit_req_add_button_element
  end

  def enter_unit_req_name(name)
    logger.info "Entering unit req '#{name}'"
    wait_for_textbox_and_type(unit_req_name_input_element, name)
  end

  def enter_unit_req_num(num)
    logger.info "Entering unit req count '#{num}'"
    wait_for_textbox_and_type(unit_req_num_input_element, num)
  end

  def click_create_unit_req
    logger.info 'Clicking the create unit req button'
    wait_for_update_and_click unit_req_create_button_element
  end

  def click_cancel_unit_req
    logger.info 'Clicking the cancel unit req button'
    wait_for_update_and_click unit_req_cancel_button_element
  end

  def create_unit_req(req)
    req.name = req.name[0..254]
    click_add_unit_req
    enter_unit_req_name req.name
    enter_unit_req_num req.unit_count
    click_create_unit_req
    unit_req_create_button_element.when_not_present Utils.short_wait
    sleep Utils.click_wait
    req.set_id
  end

  # List

  div(:unit_reqs_empty_msg, xpath: '//div[text()=" No unit requirements created "]')

  def unit_req_row_xpath(req)
    "//table[@id=\"unit-requirements-table\"]//tr[contains(., \"#{req.name}\")]"
  end
  
  def visible_unit_req_name(req)
    (unit_req_name_el = cell_element(xpath: "#{unit_req_row_xpath(req)}/td[1]")).when_visible Utils.short_wait
    unit_req_name_el.text
  end

  def visible_unit_req_num(req)
    (unit_req_num_el = cell_element(xpath: "#{unit_req_row_xpath(req)}/td[2]")).when_visible Utils.short_wait
    unit_req_num_el.text
  end

  # Edit

  button(:unit_req_save_button, id: 'update-unit-requirement-btn')

  def unit_req_edit_button(req)
    button_element(id: "unit-requirement-#{req.id}-edit-btn")
  end

  def click_edit_unit_req(req)
    logger.info "Clicking the edit button for unit req '#{req.name}'"
    wait_for_update_and_click unit_req_edit_button(req)
  end

  def click_save_unit_req_edit
    logger.info 'Clicking the save unit req edit button'
    wait_for_update_and_click unit_req_save_button_element
  end

  def edit_unit_req(req)
    req.name = req.name[0..254]
    click_edit_unit_req req
    enter_unit_req_name req.name
    enter_unit_req_num req.unit_count
    click_save_unit_req_edit
  end

  # Delete

  def unit_req_delete_button(req)
    button_element(id: "unit-requirement-#{req.id}-delete-btn")
  end

  def click_delete_unit_req(req)
    logger.info "Clicking the delete button for unit req '#{req.name}'"
    wait_for_update_and_click unit_req_delete_button(req)
  end

  # TODO - deletion workflow when UI is ready

end
