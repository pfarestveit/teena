class BOACDegreeCheckCreatePage

  include PageObject
  include Logging
  include Page
  include BOACPages

  select_list(:degree_template_select, id: 'degree-template-select')
  button(:save_degree_check_button, id: 'save-degree-check-btn')
  button(:cancel_degree_check_button, id: 'cancel-create-degree-check-btn')

  def load_page(student)
    logger.info "Loading degree checks page for UID #{student.uid}"
    navigate_to "#{BOACUtils.base_url}/student/#{student.uid}/degree/create"
  end

  def select_template(template)
    wait_for_element_and_select_js(degree_template_select_element, template.name)
  end

  def click_save_degree
    wait_for_update_and_click save_degree_check_button_element
  end

  def click_cancel_degree
    wait_for_update_and_click cancel_degree_check_button_element
  end

  def create_new_degree_check(degree_check)
    logger.info "Creating a new degree check named '#{degree_check.name}'"
    select_template degree_check
    click_save_degree
    save_degree_check_button_element.when_not_present Utils.short_wait
    wait_for_spinner
    degree_check.set_degree_check_ids
  end

end
