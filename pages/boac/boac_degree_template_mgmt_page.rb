class BOACDegreeTemplateMgmtPage

  include PageObject
  include Logging
  include Page
  include BOACPages

  # CREATE

  link(:create_degree_check_link, id: 'degree-check-create-link')
  link(:batch_degree_check_link, id: 'degree-check-batch-link')
  button(:create_degree_save_button, id: 'start-degree-btn')
  text_field(:create_degree_name_input, id: 'create-degree-input')
  span(:dupe_name_msg, xpath: '//span[contains(., " already exists. Please choose a different name.")]')

  def click_create_degree
    logger.info 'Clicking the add-degree button'
    wait_for_load_and_click create_degree_check_link_element
  end

  def enter_degree_name(name)
    logger.info "Entering degree check template name '#{name}'"
    wait_for_element_and_type(create_degree_name_input_element, name)
  end

  def click_save_new_degree
    logger.info 'Clicking new degree check template save button'
    wait_for_update_and_click create_degree_save_button_element
  end

  def create_new_degree(template)
    click_create_degree
    enter_degree_name template.name
    click_save_new_degree
  end

  def click_batch_degree_checks
    logger.info 'Clicking the link to create batch degree checks'
    wait_for_update_and_click batch_degree_check_link_element
  end

  # LIST

  elements(:template_link, :link, xpath: '//a[contains(@id, "degree-check-") and not(contains(@id, "print"))]')

  def visible_template_names
    template_link_elements.map &:text
  end

  def visible_template_create_dates
    div_elements(xpath: '//td[@data-label="Created"]/div/div').map { |el| el.text.strip }
  end

  def degree_check_row_xpath(degree_check)
    "//tr[contains(., \"#{degree_check.name}\")]"
  end

  def degree_check_link(degree_check)
    link_element(xpath: "#{degree_check_row_xpath degree_check}//a")
  end

  def degree_check_create_date(degree_check)
    el = div_element(xpath: "#{degree_check_row_xpath degree_check}/td[@data-label='Created']/div")
    str = el.text.strip
    Date.parse(str, '%B %-d, %Y')
  end

  def click_degree_link(degree_check)
    logger.info "Clicking the link for '#{degree_check.name}'"
    wait_for_update_and_click degree_check_link(degree_check)
  end

  # RENAME

  text_field(:rename_degree_name_input, id: 'rename-template-input')
  button(:rename_degree_save_button, id: 'confirm-rename-btn')
  button(:rename_degree_cancel_button, id: 'rename-cancel-btn')

  def degree_check_rename_button(degree_check)
    button_element(xpath: "#{degree_check_row_xpath degree_check}//button[contains(@id, '-rename-btn')]")
  end

  def click_rename_button(degree_check)
    logger.info "Clicking the rename button for template '#{degree_check.name}'"
    wait_for_update_and_click degree_check_rename_button(degree_check)
  end

  def enter_new_name(name)
    logger.info "Entering new degree name '#{name}'"
    wait_for_element_and_type(rename_degree_name_input_element, name)
  end

  def click_save_new_name
    logger.info 'Clicking rename save button'
    wait_for_update_and_click rename_degree_save_button_element
  end

  def click_cancel_new_name
    logger.info 'Clicking rename cancel button'
    wait_for_update_and_click rename_degree_cancel_button_element
  end

  # COPY

  text_field(:copy_degree_name_input, id: 'degree-name-input')
  button(:copy_degree_save_button, id: 'clone-confirm')
  button(:copy_degree_cancel_button, id: 'clone-cancel')

  def degree_check_copy_button(degree_check)
    button_element(xpath: "#{degree_check_row_xpath degree_check}//button[contains(@id, '-copy-btn')]")
  end

  def click_copy_button(degree_check)
    logger.info "Clicking the copy button for template '#{degree_check.name}'"
    wait_for_update_and_click degree_check_copy_button degree_check
  end

  def enter_copy_name(name)
    logger.info "Entering copied degree name '#{name}'"
    wait_for_element_and_type(copy_degree_name_input_element, name)
  end

  def click_save_copy
    logger.info 'Clicking copy save button'
    wait_for_update_and_click copy_degree_save_button_element
  end

  def click_cancel_copy
    logger.info 'Clicking copy cancel button'
    wait_for_update_and_click copy_degree_cancel_button_element
  end

  # DELETE

  def degree_check_delete_button(degree_check)
    button_element(xpath: "#{degree_check_row_xpath degree_check}//button[contains(@id, '-delete-btn')]")
  end

  def click_delete_degree(degree_check)
    logger.info "Clicking the delete button for template '#{degree_check.name}'"
    wait_for_update_and_click degree_check_delete_button(degree_check)
  end

  def click_confirm_delete
    logger.info 'Clicking the delete confirm button'
    wait_for_update_and_click confirm_delete_or_discard_button_element
    sleep 1
  end

  def click_cancel_delete
    logger.info 'Clicking delete cancel button'
    wait_for_update_and_click cancel_delete_or_discard_button_element
  end

  # PRINT

  def degree_check_print_button(degree_check)
    button_element(xpath: "#{degree_check_row_xpath degree_check}//button[text()=' Print ']")
  end

  # BATCH SUCCESS

  div(:batch_success_msg, id: 'alert-batch-created')

end
