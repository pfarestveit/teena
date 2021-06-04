class BOACDegreeTemplatePage

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

  def create_unit_req(req, template)
    req.name = req.name[0..254]
    click_add_unit_req
    enter_unit_req_name req.name
    enter_unit_req_num req.unit_count
    click_create_unit_req
    unit_req_create_button_element.when_not_present Utils.short_wait
    sleep Utils.click_wait
    req.set_id template.id
  end

  # List

  div(:unit_reqs_empty_msg, xpath: '//div[text()=" No unit requirements created "]')

  def unit_req_row_xpath(req)
    "//table[@id=\"unit-requirements-table\"]//tr[contains(., \"#{req.name}\")]"
  end

  def unit_req_name_el(req)
    cell_element(xpath: "#{unit_req_row_xpath(req)}/td[1]")
  end

  def visible_unit_req_name(req)
    unit_req_name_el(req).when_visible Utils.short_wait
    unit_req_name_el(req).text
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

  def click_confirm_delete
    logger.info 'Clicking the delete confirm button'
    wait_for_update_and_click confirm_delete_or_discard_button_element
  end

  def click_cancel_delete
    logger.info 'Clicking delete cancel button'
    wait_for_update_and_click cancel_delete_or_discard_button_element
    confirm_delete_or_discard_button_element.when_not_present 1
  end

  # COLUMN

  # Create

  select_list(:col_req_type_select, xpath: '//select[contains(@id, "add-category-select")]')
  text_field(:col_req_name_input, xpath: '//input[contains(@id, "name-input")]')
  text_area(:col_req_desc_input, xpath: '//textarea[contains(@id, "description-input")]')
  select_list(:col_req_parent_select, xpath: '//select[contains(@id, "parent-category-select")]')
  text_field(:col_req_course_units_input, xpath: '//input[contains(@id, "units-input")]')
  button(:unit_req_range_toggle, id: 'show-upper-units-input')
  text_field(:unit_req_num_input_0, id: 'units-input')
  text_field(:unit_req_num_input_1, id: 'upper-units-input')
  span(:col_req_course_units_error_msg, xpath: '//span[text()=" Invalid "]')
  span(:col_req_course_units_required_msg, xpath: '//span[text()=" Required "]')
  elements(:col_req_course_units_req_pill, :div, xpath: '//div[contains(@class, "pill-unit-requirement")]')
  select_list(:col_req_course_units_req_select, xpath: '//select[contains(@id, "unit-requirement-select")]')
  elements(:col_req_course_units_req_remove_button, :button, xpath: '//button[contains(@id, "unit-requirement-remove")]')
  button(:col_req_create_button, xpath: '//button[contains(@id, "create-requirement-btn")]')
  button(:col_req_cancel_create_button, xpath: '//button[contains(@id, "cancel-create-requirement-btn")]')

  def add_col_req_button(col_num)
    button_element(id: "column-#{col_num}-create-btn")
  end

  def click_add_col_req_button(col_num)
    logger.info "Clicking the add button for column #{col_num}"
    wait_for_update_and_click add_col_req_button(col_num)
  end

  def col_req_type_options
    wait_until(1) { col_req_type_select_element.options&.any? }
    col_req_type_select_element.options
  end

  def select_col_req_type(type)
    logger.info "Selecting column requirement type '#{type}'"
    wait_for_element_and_select_js(col_req_type_select_element, type)
  end

  def enter_col_req_name(name)
    logger.info "Entering column requirement name '#{name}'"
    wait_for_element_and_type(col_req_name_input_element, name)
  end

  def enter_col_req_desc(desc)
    logger.info "Entering column requirement description '#{desc}'"
    wait_for_textbox_and_type(col_req_desc_input_element, desc)
  end

  def col_req_parent_options
    wait_until(1) { col_req_parent_select_element.options&.any? }
    col_req_parent_select_element.options
  end

  def select_col_req_parent(parent = nil)
    if parent
      logger.info "Selecting column requirement parent '#{parent.name}'"
      wait_for_element_and_select_js(col_req_parent_select_element, parent.name)
    else
      wait_for_element_and_select_js(col_req_parent_select_element, col_req_parent_options.first)
    end
  end

  def col_req_unit_req_pill(unit_req)
    div_element(xpath: "//div[contains(@class, \"pill-unit-requirement\")]/div[contains(text(), \"#{unit_req.name}\")]")
  end

  def col_req_unit_req_remove_button(idx)
    button_element(xpath: "//button[contains(@id, 'unit-requirement-remove-#{idx}')]")
  end

  def select_col_req_unit_req(unit_req)
    logger.info "Selecting column requirement unit fulfillment '#{unit_req}'"
    wait_for_element_and_select_js(col_req_course_units_req_select_element, unit_req)
  end

  def remove_col_req_unit_req(idx)
    logger.info "Removing unit fulfillment at index #{idx}"
    wait_for_update_and_click col_req_unit_req_remove_button(idx)
    col_req_unit_req_remove_button(idx).when_not_present 2
  end

  def enter_col_req_units(units)
    logger.info "Entering column requirement units '#{units}'"
    if units.include? '-'
      range = units.split('-')
      wait_for_update_and_click unit_req_range_toggle_element
      wait_for_element_and_type(unit_req_num_input_0_element, range[0])
      wait_for_element_and_type(unit_req_num_input_1_element, range[1])
    else
      wait_for_element_and_type(unit_req_num_input_0_element, units)
    end
  end

  def click_create_col_req
    logger.info 'Clicking the create column requirement button'
    wait_for_update_and_click col_req_create_button_element
  end

  def click_cancel_col_req
    logger.info 'Clicking the cancel column requirement button'
    wait_for_update_and_click col_req_cancel_create_button_element
    col_req_cancel_create_button_element.when_not_present 1
  end

  def enter_col_req_metadata(req)
    enter_col_req_name req.name
    enter_col_req_desc req.desc if req.instance_of? DegreeReqtCategory
    select_col_req_parent req.parent if req.parent
    if req.instance_of? DegreeReqtCourse
      enter_col_req_units req.units if req.units
      req.units_reqts&.each { |u_req| select_col_req_unit_req u_req.name }
    end
  end

  def save_col_req
    click_create_col_req
    col_req_create_button_element.when_not_present Utils.short_wait
    sleep 1
  end

  def create_col_req(req, template)
    click_add_col_req_button req.column_num
    if req.instance_of? DegreeReqtCategory
      req.parent ? select_col_req_type('Subcategory') : select_col_req_type('Category')
    else
      select_col_req_type 'Course Requirement'
    end
    enter_col_req_metadata req
    save_col_req
    req.set_id template.id
  end

  # View

  def top_cat_xpath(cat)
    "//div[@id='column-#{cat.column_num}-category-#{cat.id}']"
  end

  def cat_drop_zone_el(cat)
    div_element(xpath: "#{cat_xpath cat}//div[@id='drop-zone-category']")
  end

  def subcat_xpath(subcat)
    "//div[@id='column-#{subcat.parent.column_num}-subcategory-#{subcat.id}']"
  end

  def cat_xpath(cat)
    cat.parent ? "#{subcat_xpath(cat)}" : "#{top_cat_xpath(cat)}"
  end

  def cat_name_el(cat)
    xpath = cat.parent ? "#{subcat_xpath(cat)}//h3" : "#{top_cat_xpath(cat)}//h2"
    h2_element(xpath: xpath)
  end

  def visible_cat_name(cat)
    cat_name_el(cat).text if cat_name_el(cat).exists?
  end

  def visible_cat_desc(cat)
    desc_el = div_element(xpath: "#{cat_xpath(cat)}/div/div/following-sibling::div")
    desc_el.text.strip if desc_el.exists?
  end

  def course_req_xpath(course)
    "//table[@id='column-#{course.parent.column_num}-courses-of-category-#{course.parent.id}']//tr[contains(@id, 'course-#{course.id}-table-row')]"
  end

  def course_req_row(course)
    row_element(xpath: course_req_xpath(course))
  end

  def visible_course_req_name(course)
    name_el = cell_element(xpath: "#{course_req_xpath course}/td[1]//div")
    name_el.text if name_el.exists?
  end

  def visible_course_req_units(course)
    units_el = span_element(xpath: "#{course_req_xpath course}/td[2]/span")
    units_el.text if units_el.exists?
  end

  def visible_course_req_fulfillment(course)
    fulfillment_el = cell_element(xpath: "#{course_req_xpath course}/td[3]")
    fulfillment_el.text.strip if fulfillment_el.exists?
  end

  # Edit

  elements(:cat_edit_button, :button, xpath: '//button[contains(@id, "-edit-category-")]')
  elements(:cat_delete_button, :button, xpath: '//button[contains(@id, "-delete-category-")]')

  def cat_edit_button(cat)
    col = cat.parent ? cat.parent.column_num : cat.column_num
    button_element(id: "column-#{col}-edit-category-#{cat.id}-btn")
  end

  def click_edit_cat(cat)
    logger.info "Clicking the edit button for category ID #{cat.id}"
    wait_for_update_and_click cat_edit_button(cat)
  end

  # Delete

  def cat_delete_button(cat)
    col = cat.parent ? cat.parent.column_num : cat.column_num
    type = cat.instance_of?(DegreeCourse) ? 'course' : 'category'
    button_element(id: "column-#{col}-delete-#{type}-#{cat.id}-btn")
  end

  def click_delete_cat(cat)
    logger.info "Clicking the delete button for category ID #{cat.id}"
    wait_for_update_and_click cat_delete_button(cat)
  end

  def complete_template(template)
    template_heading(template).when_visible Utils.short_wait
    template.set_new_template_id
    template.unit_reqts&.each { |u| create_unit_req(u, template) }
    template.categories&.each do |cat|
      create_col_req(cat, template)
      cat.course_reqs&.each { |course| create_col_req(course, template) }
      cat.sub_categories&.each do |subcat|
        create_col_req(subcat, template)
        subcat.course_reqs&.each { |course| create_col_req(course, template) }
      end
    end
  end

end
