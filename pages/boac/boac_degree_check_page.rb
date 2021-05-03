class BOACDegreeCheckPage < BOACDegreeCheckTemplatePage

  include PageObject
  include Page
  include Logging
  include BOACPages

  div(:last_updated_msg, xpath: '//div[contains(text(), "Last updated by")]')

  # NOTES

  div(:no_notes_msg, id: 'degree-note-no-data')
  button(:create_or_edit_note_button, id: 'create-degree-note-btn')
  button(:print_note_toggle, id: 'degree-note-print-toggle')
  div(:note_update_advisor, id: 'degree-note-updated-by')
  div(:note_update_date, id: 'degree-note-updated-at')
  text_area(:note_input, id: 'degree-note-input')
  button(:save_note_button, id: 'save-degree-note-btn')
  button(:cancel_note_button, id: 'cancel-degree-note-btn')
  paragraph(:note_body, id: 'degree-note-body')

  def click_create_or_edit_note
    wait_for_update_and_click create_or_edit_note_button_element
  end

  def enter_note_body(string)
    wait_for_element_and_type(note_input_element, string)
  end

  def click_save_note
    wait_for_update_and_click save_note_button_element
  end

  def click_cancel_note
    wait_for_update_and_click cancel_note_button_element
    cancel_note_button_element.when_not_present 1
  end

  def create_or_edit_note(string)
    logger.info "Entering degree note '#{string}'"
    click_create_or_edit_note
    enter_note_body string
    click_save_note
  end

  def visible_note_body
    note_body_element.when_visible Utils.short_wait
    note_body
  end

  # UNASSIGNED (COMPLETED) COURSES

  def unassigned_course_ccns
    els = row_elements(xpath: '//tr[contains(@id, "unassigned-course-")]')
    els.map { |el| el.attribute('id').split('-')[2..3].join('-') }
  end

  def unassigned_course_row_xpath(course)
    "//tr[@id='unassigned-course-#{course.term_id}-#{course.ccn}']"
  end

  def unassigned_course_row_el(course)
    row_element(xpath: unassigned_course_row_xpath(course))
  end

  def unassigned_course_select(course)
    button_element(xpath: "#{unassigned_course_row_xpath course}/td[1]//button")
  end

  def unassigned_course_req_option(completed_course, req)
    link_element(xpath: "#{unassigned_course_row_xpath completed_course}/td[1]//a[text()=\" #{req.name} \"]")
  end

  def unassigned_course_code(course)
    code_el = cell_element(xpath: "#{unassigned_course_row_xpath course}/td[2]")
    code_el.text.strip if code_el.exists?
  end

  def unassigned_course_units(course)
    units_el = span_element(xpath: "#{unassigned_course_row_xpath course}/td[3]/span")
    units_el.text if units_el.exists?
  end

  def unassigned_course_grade(course)
    grade_el = cell_element(xpath: "#{unassigned_course_row_xpath course}/td[4]")
    grade_el.text.strip if grade_el.exists?
  end

  def unassigned_course_term(course)
    term_el = cell_element(xpath: "#{unassigned_course_row_xpath course}/td[5]")
    term_el.text.strip if term_el.exists?
  end

  def unassigned_course_note(course)
    note_el = cell_element(xpath: "#{unassigned_course_row_xpath course}/td[6]")
    note_el.text.strip if note_el.exists?
  end

  # Course edits

  text_field(:unassigned_course_units_input, id: 'course-units-input')
  text_area(:unassigned_course_note_input, id: 'course-note-textarea')
  button(:unassigned_course_update_button, id: 'update-note-btn')
  button(:unassigned_course_cancel_button, id: 'cancel-update-note-btn')

  def unassigned_course_edit_button(course)
    button_element(xpath: "#{unassigned_course_row_xpath course}/td[7]/button")
  end

  def click_edit_unassigned_course(course)
    wait_for_update_and_click unassigned_course_edit_button(course)
  end

  def enter_unassigned_course_units(units)
    logger.info "Entering units value '#{units}'"
    wait_for_element_and_type(unassigned_course_units_input_element, units)
  end

  def enter_unassigned_course_note(note)
    logger.info "Entering note value '#{note}'"
    wait_for_element_and_type(unassigned_course_note_input_element, note)
  end

  def click_cancel_unassigned_course_edit
    wait_for_update_and_click unassigned_course_cancel_button_element
    unassigned_course_units_input_element.when_not_present 1
  end

  def click_save_unassigned_course_edit
    wait_for_update_and_click unassigned_course_update_button_element
  end

  def edit_unassigned_course(course)
    logger.info "Editing #{course.term_id} #{course.name}"
    click_edit_unassigned_course course
    enter_unassigned_course_units course.units
    enter_unassigned_course_note course.note
    click_save_unassigned_course_edit
    unassigned_course_update_button_element.when_not_present Utils.short_wait
  end

  # Course assignment

  def click_unassigned_course_select(course)
    wait_for_update_and_click unassigned_course_select(course)
  end

  def unassigned_course_options(course)
    link_elements(xpath: "#{unassigned_course_row_xpath course}/td[1]//a").map { |el| el.text.strip }
  end

  def assign_completed_course(completed_course, req)
    logger.info "Assigning course #{completed_course.name}, #{completed_course.term_id}-#{completed_course.ccn} to #{req.name}"
    click_unassigned_course_select completed_course
    wait_for_update_and_click unassigned_course_req_option(completed_course, req)
    sleep Utils.click_wait
    req.completed_course = completed_course
    completed_course.req_course = req
    # TODO - moving course to category rather than course row
    wait_until(2) { visible_course_req_name(req) == req.completed_course.name }
  end

  # ASSIGNED (COMPLETED) COURSES

  def assigned_course_select(course)
    button_element(xpath: "#{course_req_xpath course.req_course}/td[1]//button")
  end

  def assigned_course_req_option(completed_course, req = nil)
    link_text = req ? req.name : '-- Unassign --'
    link_element(xpath: "#{course_req_xpath completed_course.req_course}/td[1]//a[text()=\" #{link_text} \"]")
  end

  def unassign_course(completed_course, req)
    logger.info "Un-assigning course #{completed_course.name}, #{completed_course.term_id}-#{completed_course.ccn} from #{req.name}"
    wait_for_update_and_click assigned_course_select(completed_course)
    wait_for_update_and_click assigned_course_req_option(completed_course)
    sleep Utils.click_wait
    req.completed_course = nil
    completed_course.req_course = nil
    # TODO - moving course to category rather than course row
    wait_until(2) { visible_course_req_name(req) == req.name }
  end

  def reassign_course(completed_course, old_req, new_req)
    logger.info "Reassigning course #{completed_course.name}, #{completed_course.term_id}-#{completed_course.ccn} from #{completed_course.req_course.name} to #{new_req.name}"
    wait_for_update_and_click assigned_course_select(completed_course)
    wait_for_update_and_click assigned_course_req_option(completed_course, new_req)
    sleep Utils.click_wait
    old_req.completed_course = nil
    new_req.completed_course = completed_course
    completed_course.req_course = new_req
    # TODO - moving course to category rather than course row
    wait_until(2) { visible_course_req_name(old_req) == old_req.name }
  end

  # Course edits

  def assigned_course_edit_button(course)
    cat_edit_button(course.req_course)
  end

  def click_edit_assigned_course(course)
    logger.info "Clicking the edit button for course #{course.name} category ID #{course.req_course.id}"
    wait_for_update_and_click assigned_course_edit_button(course)
  end

  def enter_assigned_course_units(units)
    logger.info "Entering units value '#{units}'"
    enter_col_req_units units
  end

  # TODO def enter_assigned_course_note(note)

  def select_assigned_course_unit_req(course)
    col_req_course_units_req_remove_button_elements.each_with_index { |_, i| remove_col_req_unit_req i }
    course.units_reqts&.each { |u_req| select_col_req_unit_req u_req.name }
  end

  def click_cancel_assigned_course_edit
    wait_for_update_and_click unassigned_course_cancel_button_element
    unassigned_course_units_input_element.when_not_present 1
  end

  def click_save_assigned_course_edit
    wait_for_update_and_click unassigned_course_update_button_element
  end

  def edit_assigned_course(course)
    logger.info "Editing #{course.term_id} #{course.name}"
    click_edit_unassigned_course course
    enter_unassigned_course_units course.units
    enter_unassigned_course_note course.note
    click_save_unassigned_course_edit
    unassigned_course_update_button_element.when_not_present Utils.short_wait
  end
end
