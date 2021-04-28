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

  # UNASSIGNED COURSES

  def unassigned_course_ccns
    els = row_elements(xpath: '//tr[contains(@id, "unassigned-course-")]')
    els.map { |el| el.attribute('id').split('-')[2..3].join('-') }
  end

  def unassigned_course_row_xpath(course)
    "//tr[@id='unassigned-course-#{course.term_id}-#{course.ccn}']"
  end

  def unassigned_course_row_el(course)
    row_element(xpath: course_row_xpath(course))
  end

  def unassigned_course_select(course)
    button_element(xpath: "#{unassigned_course_row_xpath course}/td[1]//button")
  end

  def unassigned_course_option(course, destination)
    link_element(xpath: "#{unassigned_course_row_xpath course}/td[1]//a[text()=\" #{destination.name} \"]")
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

  def unassigned_course_edit_button(course)
    button_element(xpath: "#{unassigned_course_row_xpath course}/td[7]/button")
  end

  def assign_course(course, destination)
    logger.info "Assigning course #{course.name}, #{course.term_id}-#{course.ccn} to #{destination.name}"
    wait_for_update_and_click unassigned_course_select(course)
    wait_for_update_and_click unassigned_course_option(course, destination)
    destination.assignment = course
    # TODO - moving course to category rather than course row
    wait_until(2) { visible_course_name(destination) == destination.assignment.name }
  end

end
