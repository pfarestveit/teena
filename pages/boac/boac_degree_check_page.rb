class BOACDegreeCheckPage < BOACDegreeTemplatePage

  include PageObject
  include Page
  include Logging
  include BOACPages

  def degree_check_heading(degree)
    h2_element(xpath: "//h2[text()=\"#{degree.name}\"]")
  end

  def load_page(degree)
    logger.info "Loading degree check #{degree.id}"
    navigate_to "#{BOACUtils.base_url}/student/degree/#{degree.id}"
  end

  div(:template_updated_msg, xpath: '//div[contains(., "Please update below if necessary")]')
  link(:template_link, id: 'original-degree-template')
  div(:last_updated_msg, xpath: '//div[contains(text(), "Last updated by")]')
  link(:create_new_degree_link, id: 'create-new-degree')
  link(:view_degree_history_link, id: 'view-degree-history')

  def click_create_new_degree
    logger.info 'Clicking create-new-degree link'
    wait_for_update_and_click create_new_degree_link_element
  end

  def click_view_degree_history
    logger.info 'Clicking view-degree-history link'
    wait_for_update_and_click view_degree_history_link_element
  end

  # NOTES

  button(:create_or_edit_note_button, id: 'create-degree-note-btn')
  button(:print_note_toggle, id: 'degree-note-print-toggle')
  div(:print_note_toggle_label, class: 'toggle-label')
  span(:note_update_advisor, id: 'degree-note-updated-by')
  span(:note_update_date, xpath: '//h3[text()="Degree Notes"]/following-sibling::div/div/span[2]/span')
  text_area(:note_input, id: 'degree-note-input')
  button(:save_note_button, id: 'save-degree-note-btn')
  button(:cancel_note_button, id: 'cancel-degree-note-btn')
  paragraph(:note_body, id: 'degree-note-body')

  def click_print_note_toggle
    print_note_toggle_element.when_present Utils.short_wait
    js_click print_note_toggle_element
    sleep Utils.click_wait
  end

  def print_note_selected_option
    print_note_toggle_label.strip
  end

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

  def visible_note_update_advisor
    note_update_advisor_element.when_visible Utils.short_wait
    note_update_advisor
  end

  # UNIT REQUIREMENTS

  def visible_unit_req_completed(req)
    (unit_completed_el = cell_element(xpath: "#{unit_req_row_xpath(req)}/td[3]")).when_visible Utils.short_wait
    unit_completed_el.text
  end

  def units_added_to_unit_req?(req, course)
    expected = "#{req.units_completed + course.units.to_i}"
    verify_block do
      wait_for_unit_req_update(req, expected)
      req.units_completed += course.units.to_i
    end
  end

  def units_removed_from_unit_req?(req, course)
    expected = "#{req.units_completed - course.units.to_i}"
    verify_block do
      wait_for_unit_req_update(req, expected)
      req.units_completed -= course.units.to_i
    end
  end

  def wait_for_unit_req_update(req, expected)
    wait_until(3, "Expecting '#{expected}', got '#{visible_unit_req_completed(req)}'") do
      visible_unit_req_completed(req) == expected.to_s
    end
  end

  # COURSE REQUIREMENTS

  checkbox(:big_dot_cbx, id: 'recommended-course-checkbox')
  button(:save_edit_req_button, id: 'update-requirement-btn')
  button(:cancel_edit_req_button, id: 'cancel-edit-requirement-btn')

  def course_req_menu?(course)
    cell_element(xpath: "#{course_req_xpath course}/td[contains(@class, 'td-course-assignment-menu')]").exists?
  end

  def visible_course_req_name(course)
    node = course_req_menu?(course) ? '2' : '1'
    name_el = cell_element(xpath: "#{course_req_xpath course}/td[#{node}]//div")
    name_el.text if name_el.exists?
  end

  def visible_course_req_units(course)
    node = course_req_menu?(course) ? '3' : '2'
    units_el = span_element(xpath: "#{course_req_xpath course}/td[#{node}]/span")
    units_el.text if units_el.exists?
  end

  def visible_course_req_grade(course)
    node = course_req_menu?(course) ? '4' : '3'
    grade_el = cell_element(xpath: "#{course_req_xpath course}/td[#{node}]/span")
    grade_el.text.strip if grade_el.exists?
  end

  def visible_course_req_note(course)
    node = course_req_menu?(course) ? '5' : '4'
    note_el = cell_element(xpath: "#{course_req_xpath course}/td[#{node}]/span")
    note_el.text.strip if note_el.exists?
  end

  def click_edit_course_req(course)
    click_edit_cat(course)
  end

  def toggle_course_req_dot
    wait_for_update_and_click big_dot_cbx_element
  end

  def click_save_req_edit
    wait_for_update_and_click save_edit_req_button_element
    save_edit_req_button_element.when_not_present Utils.short_wait
    sleep Utils.click_wait
  end

  def is_recommended?(course)
    element(xpath: "//*[@id='category-#{course.id}-is-recommended']").exists?
  end

  # UNASSIGNED COURSES

  elements(:unassigned_course, :row, xpath: '//tr[contains(@id, "unassigned-course-")]')
  div(:unassigned_drop_zone, id: 'drop-zone-unassigned-courses')
  link(:unassigned_option, id: 'assign-course-to-option-null')

  def unassigned_course_ccns
    ids = unassigned_course_elements.map { |el| el.attribute('id') }
    ids.delete_if { |id| id.include? '-manually-created' }
    ids.map { |id| id.split('-')[2..3].join('-') }
  end

  def unassigned_course_xpath(course)
    str = course.manual ? "#{course.id}-manually-created" : "#{course.term_id}-#{course.ccn}"
    "//tr[@id='unassigned-course-#{str}']"
  end

  def unassigned_course_row(course)
    row_element(xpath: unassigned_course_xpath(course))
  end

  def unassigned_course_req_option(completed_course, req)
    link_element(xpath: "#{unassigned_course_xpath completed_course}/td[1]//a[text()=\" #{req.name} \"]")
  end

  def unassigned_course_code(course)
    code_el = cell_element(xpath: "#{unassigned_course_xpath course}/td[2]")
    code_el.text.strip if code_el.exists?
  end

  def unassigned_course_units(course)
    units_el = span_element(xpath: "#{unassigned_course_xpath course}/td[3]/span")
    units_el.text if units_el.exists?
  end

  def unassigned_course_units_flag?(course)
    flag_el = div_element(xpath: "#{unassigned_course_xpath course}/td[3]/*[name()='svg']")
    hover_el = span_element(xpath: "#{unassigned_course_xpath course}/td[3]/span[contains(text(), 'updated from')]")
    flag_el.exists? && hover_el.exists?
  end

  def unassigned_course_grade(course)
    grade_el = cell_element(xpath: "#{unassigned_course_xpath course}/td[4]")
    grade_el.text.strip if grade_el.exists?
  end

  def unassigned_course_term(course)
    term_el = cell_element(xpath: "#{unassigned_course_xpath course}/td[5]")
    term_el.text.strip if term_el.exists?
  end

  def unassigned_course_note(course)
    note_el = cell_element(xpath: "#{unassigned_course_xpath course}/td[6]")
    note_el.text.strip if note_el.exists?
  end

  def click_unassigned_course_select(course)
    wait_for_update_and_click button_element(xpath: "#{unassigned_course_xpath course}/td[1]//div[contains(@id, 'assign-course-')]")
  end

  def unassigned_course_option_els(course)
    link_elements(xpath: "#{unassigned_course_xpath course}/td[1]//a")
  end

  def unassigned_course_options(course)
    unassigned_course_option_els(course).map { |el| el.text.strip }
  end

  def click_unassigned_option
    wait_for_update_and_click unassigned_option_element
  end

  # JUNK DRAWER

  div(:junk_drop_zone, id: 'drop-zone-ignored-courses')
  link(:junk_option, id: 'course-to-option-ignore')

  def junk_course_xpath(course)
    str = course.manual ? "#{course.id}-manually-created" : "#{course.term_id}-#{course.ccn}"
    "//tr[@id='ignored-course-#{str}']"
  end

  def junk_course_row(course)
    row_element(xpath: junk_course_xpath(course))
  end

  def junk_course_req_option(completed_course, req)
    link_element(xpath: "#{junk_course_xpath completed_course}/td[1]//a[text()=\" #{req.name} \"]")
  end

  def junk_course_code(course)
    code_el = cell_element(xpath: "#{junk_course_xpath course}/td[2]")
    code_el.text.strip if code_el.exists?
  end

  def junk_course_units(course)
    units_el = span_element(xpath: "#{junk_course_xpath course}/td[3]/span")
    units_el.text if units_el.exists?
  end

  def junk_course_units_flag?(course)
    flag_el = div_element(xpath: "#{junk_course_xpath course}/td[3]/*[name()='svg']")
    hover_el = span_element(xpath: "#{junk_course_xpath course}/td[3]/span[contains(text(), 'updated from')]")
    flag_el.exists? && hover_el.exists?
  end

  def junk_course_grade(course)
    grade_el = cell_element(xpath: "#{junk_course_xpath course}/td[4]")
    grade_el.text.strip if grade_el.exists?
  end

  def junk_course_note(course)
    note_el = cell_element(xpath: "#{junk_course_xpath course}/td[5]")
    note_el.text.strip if note_el.exists?
  end

  def click_junk_course_select(course)
    wait_for_update_and_click button_element(xpath: "#{junk_course_xpath course}/td[1]//div[contains(@id, 'assign-course-')]")
  end

  def click_junk_option
    wait_for_update_and_click junk_option_element
  end

  # ASSIGNED COURSES

  def category_courses(category)
    row_elements(xpath: "//table[@id='column-#{category.column_num}-courses-of-category-#{category.id}']/tbody/tr[not(contains(., 'No completed requirements'))]")
  end

  def assigned_course_xpath(course)
    "//table[@id='column-#{course.req_course.parent.column_num}-courses-of-category-#{course.req_course.parent.id}']//tr[contains(.,\"#{course.name}\")]"
  end

  def assigned_course_row(course)
    row_element(xpath: assigned_course_xpath(course))
  end

  def assigned_course_name(course)
    name_el = cell_element(xpath: "#{assigned_course_xpath course}/td[2]")
    name_el.text.strip if name_el.exists?
  end

  def assigned_course_copy_flag?(course)
    flag_el = div_element(xpath: "#{assigned_course_xpath course}/td[2]//*[name()='svg']")
    hover_el = div_element(xpath: "#{assigned_course_xpath course}/td[2]//*[contains(text(), 'Course satisfies multiple requirements.')]")
    flag_el.exists? && hover_el.exists?
  end

  def assigned_course_units(course)
    units_el = span_element(xpath: "#{assigned_course_xpath course}/td[contains(@class, 'td-units')]/span")
    units_el.text if units_el.exists?
  end

  def assigned_course_units_flag?(course)
    flag_el = div_element(xpath: "#{assigned_course_xpath course}/td[contains(@class, 'td-units')]/*[name()='svg']")
    hover_el = span_element(xpath: "#{assigned_course_xpath course}/td[contains(@class, 'td-units')]/span[contains(text(), 'updated from')]")
    flag_el.exists? && hover_el.exists?
  end

  def assigned_course_fulfill_flag?(course)
    flag_el = span_element(xpath: "#{assigned_course_xpath course}/td[contains(@class, 'td-units')]//*[name()='title']")
    flag_el.exists?
  end

  def assigned_course_grade(course)
    grade_el = cell_element(xpath: "#{assigned_course_xpath course}/td[contains(@class, 'td-grade')]/span")
    grade_el.text.strip if grade_el.exists?
  end

  def assigned_course_note(course)
    note_el = cell_element(xpath: "#{assigned_course_xpath course}/td[contains(@class, 'td-note')]")
    note_el.text.strip if note_el.exists?
  end

  def verify_assigned_course_fulfillment(course)
    click_edit_assigned_course course
    col_req_course_units_req_select_element.when_present 1
    if course.units_reqts&.any?
      wait_until(1, "Expected #{course.units_reqts.length} reqts, got #{col_req_course_units_req_pill_elements.length}") do
        col_req_course_units_req_pill_elements.length == course.units_reqts.length
      end
      course.units_reqts.each { |req| col_req_unit_req_pill(req).when_present 1 }
    else
      wait_until(1, "Expected no reqts, got #{col_req_course_units_req_pill_elements.length}") do
        col_req_course_units_req_pill_elements.empty?
      end
    end
  end

  # COURSE ASSIGNMENT

  elements(:assign_course_button, :button, xpath: '//button[contains(@id, "assign-course-")]')

  def assign_completed_course(completed_course, req, opts = nil)
    logger.info "Assigning course #{completed_course.name}, #{completed_course.term_id}-#{completed_course.ccn} to #{req.name}"

    if opts && opts[:drag]
      target = req.instance_of?(DegreeReqtCourse) ? course_req_row(req) : cat_drop_zone_el(req)
      drag_and_drop(unassigned_course_row(completed_course), target)
    else
      if completed_course.junk
        click_junk_course_select completed_course
        wait_for_update_and_click junk_course_req_option(completed_course, req)
      else
        click_unassigned_course_select completed_course
        wait_for_update_and_click unassigned_course_req_option(completed_course, req)
      end
    end
    sleep Utils.click_wait

    completed_course.junk = false

    # If course is assigned to a cat, create a dummy course reqt within the cat
    course_req = if req.instance_of?(DegreeReqtCourse)
                   req
                 else
                   DegreeReqtCourse.new parent: req,
                                        units_reqts: req.units_reqts,
                                        dummy: true
                 end
    req.course_reqs << course_req unless req.instance_of?(DegreeReqtCourse)
    course_req.completed_course = completed_course
    completed_course.req_course = course_req
    completed_course.units_reqts = course_req.units_reqts
    wait_until(2, "Expected '#{completed_course.name}', got '#{assigned_course_name(completed_course)}'") do
      assigned_course_name(completed_course) == completed_course.name
    end
  end

  def assigned_course_select(course)
    button_element(xpath: "#{assigned_course_xpath course}/td[1]//div[contains(@id, 'assign-course-')]")
  end

  def assigned_course_req_option(completed_course, req)
    link_element(xpath: "#{assigned_course_xpath completed_course}/td[1]//a[text()=\" #{req.name} \"]")
  end

  # COURSE UN-ASSIGNMENT

  def unassign_course(completed_course, req = nil, opts = nil)
    logger.info "Un-assigning course #{completed_course.name}, #{completed_course.term_id}-#{completed_course.ccn}"
    assignment_el = completed_course.junk ? junk_course_row(completed_course) : assigned_course_row(completed_course)

    if opts && opts[:drag]
      drag_and_drop(assignment_el, unassigned_drop_zone_element)
    else
      if completed_course.junk
        click_junk_course_select completed_course
      else
        wait_for_update_and_click assigned_course_select(completed_course)
      end
      click_unassigned_option
    end
    sleep Utils.click_wait
    completed_course.junk = false

    # If course was assigned to course reqt, verify the reqt row reverts to template version
    if req
      if req.instance_of? DegreeReqtCourse
        req.completed_course = nil
        wait_until(2, "Expected '#{visible_course_req_name(req)}' to be '#{req.name}'") do
          visible_course_req_name(req) == req.name
        end
      else
        assigned_course_row(completed_course).when_not_present Utils.short_wait
        req.course_reqs.delete completed_course.req_course
      end
      completed_course.req_course = nil
      completed_course.units_reqts = []
    end
  end

  # COURSE REASSIGNMENT

  def reassign_course(completed_course, old_req, new_req, opts = nil)
    logger.info "Reassigning course #{completed_course.name}, #{completed_course.term_id}-#{completed_course.ccn} from #{old_req.name} to #{new_req.name}"
    row_count = category_courses(old_req).length if old_req.instance_of? DegreeReqtCategory

    if opts && opts[:drag]
      target = new_req.instance_of?(DegreeReqtCourse) ? course_req_row(new_req) : cat_drop_zone_el(new_req)
      drag_and_drop(assigned_course_row(completed_course), target)
    else
      wait_for_update_and_click assigned_course_select(completed_course)
      wait_for_update_and_click assigned_course_req_option(completed_course, new_req)
    end
    sleep Utils.click_wait

    # Detach the course from the old course reqt, dummy or otherwise
    old_course_req = old_req.instance_of?(DegreeReqtCourse) ? old_req : completed_course.req_course
    old_req.course_reqs.delete old_course_req if old_req.instance_of?(DegreeReqtCategory)
    old_course_req.completed_course = nil

    # Attach the course to the new course reqt, dummy or otherwise
    new_course_req = if new_req.instance_of?(DegreeReqtCourse)
                       new_req
                     else
                       DegreeReqtCourse.new parent: new_req,
                                            units_reqts: new_req.units_reqts,
                                            dummy: true
                     end
    new_req.course_reqs << new_course_req if new_req.instance_of? DegreeReqtCategory
    new_course_req.completed_course = completed_course

    completed_course.req_course = new_course_req
    completed_course.units_reqts = new_course_req.units_reqts

    if old_req.instance_of? DegreeReqtCourse
      wait_until(Utils.short_wait, "Expected '#{visible_course_req_name(old_req)}' to be '#{old_req.name}'") do
        visible_course_req_name(old_req) == old_req.name
      end
    else
      wait_until(Utils.short_wait) { category_courses(old_req).length == row_count - 1 }
    end

    wait_until(Utils.short_wait, "Expected '#{assigned_course_name(completed_course)}' to be '#{completed_course.name}'") do
      assigned_course_name(completed_course) == completed_course.name
    end
  end

  # COURSE JUNKIFICATION

  def wish_to_cornfield(completed_course, old_req = nil, opts = nil)
    logger.info "Wishing course #{completed_course.name}, #{completed_course.term_id}-#{completed_course.ccn} to the cornfield"
    course_el = old_req ? assigned_course_row(completed_course) : unassigned_course_row(completed_course)

    if opts && opts[:drag]
      drag_and_drop(course_el, junk_drop_zone_element)
    else
      if old_req
        wait_for_update_and_click assigned_course_select(completed_course)
      else
        click_unassigned_course_select completed_course
      end
      click_junk_option
    end
    sleep Utils.click_wait
    wait_until(2, "Expected '#{junk_course_code(completed_course)}' to be '#{completed_course.name}'") do
      junk_course_code(completed_course) == completed_course.name
    end
    completed_course.junk = true

    if old_req
      if old_req.instance_of? DegreeReqtCourse
        wait_until(2, "Expected '#{visible_course_req_name(old_req)}' to be '#{old_req.name}'") do
          visible_course_req_name(old_req) == old_req.name
        end
        old_req.completed_course = nil
      else
        course_el.when_not_present 2
        old_req.course_reqs.delete completed_course.req_course
      end
      completed_course.req_course = nil
      completed_course.units_reqts = []
    end
  end

  # COURSE CREATE / EDIT / DELETE

  button(:create_course_button, id: 'create-course-button')
  text_field(:course_name_input, id: 'course-name-input')
  text_field(:course_units_input, id: 'course-units-input')
  text_field(:course_grade_input, id: 'course-grade-input')
  button(:course_color_button, xpath: '//button[contains(@id, "color-code-select")]')
  select_list(:course_color_select, id: 'color-code-select')
  text_area(:course_note_input, id: 'course-note-textarea')

  button(:create_course_save_button, id: 'create-course-save-btn')
  button(:create_course_cancel_button, id: 'create-course-cancel-btn')
  button(:course_update_button, id: 'update-note-btn')
  button(:course_cancel_button, id: 'cancel-update-note-btn')

  # Any

  def enter_course_name(name)
    logger.info "Entering course name '#{name}'"
    wait_for_element_and_type(course_name_input_element, name)
  end

  def enter_course_units(units)
    logger.info "Entering units value '#{units}'"
    wait_for_textbox_and_type(course_units_input_element, units)
  end

  def enter_course_grade(grade)
    logger.info "Entering grade '#{grade}'"
    wait_for_textbox_and_type(course_grade_input_element, grade)
  end

  def select_course_unit_req(course)
    col_req_course_units_req_remove_button_elements.length.times do
      col_req_course_units_req_remove_button_elements.first.click
      sleep 1
    end
    course.units_reqts&.each { |u_req| select_col_req_unit_req u_req.name }
  end

  def select_color_option(color)
    logger.info "Setting color to '#{color}'"
    unless course_color_button_element.attribute('class').include? "border-color-#{color}"
      wait_for_update_and_click course_color_button_element
      id = color ? "color-code-#{color}-option" : 'border-color-none'
      wait_for_update_and_click link_element(id: id)
    end
  end

  def enter_course_note(note)
    logger.info "Entering note value '#{note}'"
    wait_for_element_and_type(course_note_input_element, note)
  end

  def click_create_course
    wait_for_update_and_click create_course_button_element
  end

  def click_cancel_course_create
    wait_for_update_and_click create_course_cancel_button_element
    create_course_cancel_button_element.when_not_present 2
  end

  def click_cancel_course_edit
    wait_for_update_and_click course_cancel_button_element
    course_units_input_element.when_not_present 1
  end

  def click_save_course_edit
    wait_for_update_and_click course_update_button_element
    course_update_button_element.when_not_present Utils.short_wait
  end

  def create_manual_course(degree, course)
    click_create_course
    enter_course_name course.name
    enter_course_units course.units
    enter_course_grade course.grade
    select_color_option course.color
    select_course_unit_req course
    enter_course_note course.note
    wait_for_update_and_click create_course_save_button_element
    create_course_save_button_element.when_not_present Utils.short_wait
    BOACUtils.set_degree_manual_course_id(degree, course)
  end

  # Edit unassigned

  def unassigned_course_edit_button(course)
    button_element(xpath: "#{unassigned_course_xpath course}/td[7]//button[contains(@id, 'edit')]")
  end

  def click_edit_unassigned_course(course)
    wait_for_update_and_click unassigned_course_edit_button(course)
  end

  def edit_unassigned_course(course)
    logger.info "Editing unassigned course #{course.name}#{ + ' ' + course.term_id if course.term_id}"
    click_edit_unassigned_course course
    enter_course_units course.units
    enter_course_note course.note
    if course.manual
      enter_course_name course.name
      enter_course_grade course.grade
      select_color_option course.color
      # TODO select_assigned_course_unit_req course
    end
    click_save_course_edit
  end

  # Edit junk

  def junk_course_edit_button(course)
    button_element(xpath: "#{junk_course_xpath course}/td[6]//button[contains(@id, 'edit')]")
  end

  def click_edit_junk_course(course)
    wait_for_update_and_click junk_course_edit_button(course)
  end

  def edit_junk_course(course)
    logger.info "Editing junk course #{course.name}#{ + ' ' + course.term_id if course.term_id}"
    click_edit_junk_course course
    enter_course_units course.units
    enter_course_note course.note
    if course.manual
      enter_course_name course.name
      enter_course_grade course.grade
      select_color_option course.color
      # TODO select_assigned_course_unit_req course
    end
    click_save_course_edit
  end

  # Edit assigned

  def assigned_course_edit_button(course)
    button_element(xpath: "#{assigned_course_xpath course}/td[last()]//button[contains(@id, 'edit')]")
  end

  def click_edit_assigned_course(course)
    logger.info "Clicking the edit button for course #{course.name} category ID #{course.req_course.id}"
    wait_for_update_and_click assigned_course_edit_button(course)
  end

  def edit_assigned_course(course)
    logger.info "Editing assigned course #{course.name}#{ + ' ' + course.term_id if course.term_id}"
    click_edit_assigned_course course
    enter_course_units course.units
    select_course_unit_req course
    enter_course_note course.note
    if course.manual
      enter_course_name course.name
      enter_course_grade course.grade
      select_color_option course.color
    end
    click_save_course_edit
    sleep Utils.click_wait
  end

  # Delete unassigned

  def unassigned_course_delete_button(course)
    button_element(xpath: "#{unassigned_course_xpath course}/td[7]//button[contains(@id, 'delete')]")
  end

  def click_delete_unassigned_course(course)
    wait_for_update_and_click unassigned_course_delete_button(course)
  end

  def delete_unassigned_course(course)
    logger.info "Deleting unassigned course #{course.name}#{ + ' ' + course.term_id if course.term_id}"
    click_delete_unassigned_course course
    wait_for_update_and_click confirm_delete_or_discard_button_element
    sleep 1
  end

  # Delete junk

  def junk_course_delete_button(course)
    button_element(xpath: "#{junk_course_xpath course}/td[6]//button[contains(@id, 'delete')]")
  end

  def click_delete_junk_course(course)
    wait_for_update_and_click junk_course_delete_button(course)
  end

  def delete_junk_course(course)
    logger.info "Deleting junk course #{course.name}#{ + ' ' + course.term_id if course.term_id}"
    click_delete_junk_course course
    wait_for_update_and_click confirm_delete_or_discard_button_element
    sleep 1
  end

  # Delete assigned

  def assigned_course_delete_button(course)
    button_element(xpath: "#{assigned_course_xpath course}/td[6]//button[contains(@id, 'delete')]")
  end

  def click_delete_assigned_course(course)
    wait_for_update_and_click assigned_course_delete_button(course)
  end

  def delete_assigned_course(course)
    logger.info "Deleting assigned course #{course.name}#{ + ' ' + course.term_id if course.term_id}"
    click_delete_assigned_course course
    wait_for_update_and_click confirm_delete_or_discard_button_element
    sleep 1
  end

  # COURSE COPY

  elements(:copy_course_button, :button, xpath: '//button[contains(@id, "-add-course-to-category-")]')
  select_list(:copy_course_select, id: 'add-course-select')
  button(:copy_course_save_button, id: 'add-course-save-btn')
  button(:copy_course_cancel_button, id: 'add-course-cancel-btn')

  def copy_course_button(destination_req)
    button_element(id: "column-#{destination_req.column_num}-add-course-to-category-#{destination_req.id}")
  end

  def copy_course_options
    wait_until(1) { copy_course_select_options&.any? }
    opts = copy_course_select_options
    opts.delete 'Choose...'
    opts
  end

  def click_copy_course_button(destination_req)
    wait_for_update_and_click copy_course_button(destination_req)
  end

  def click_cancel_course_copy
    logger.info 'Clicking course copy cancel button'
    wait_for_update_and_click copy_course_cancel_button_element
  end

  def copy_course(course, destination_req)
    logger.info "Copying #{course.name} to #{destination_req.name}"
    click_copy_course_button destination_req
    wait_for_element_and_select_js(copy_course_select_element, course.name)
    wait_for_update_and_click copy_course_save_button_element
    sleep Utils.click_wait
    dummy_req = DegreeReqtCourse.new parent: destination_req, dummy: true
    destination_req.course_reqs << dummy_req
    copy = DegreeCompletedCourse.new req_course: dummy_req,
                                     course_orig: course,
                                     name: course.name.to_s,
                                     grade: course.grade.to_s,
                                     units: course.units.to_i,
                                     units_reqts: destination_req.units_reqts,
                                     note: nil,
                                     manual: (true if course.manual)
    course.course_copies << copy
    wait_until(2, "Expected '#{copy.name}', got '#{assigned_course_name(copy)}'") do
      assigned_course_name(copy).include? copy.name
    end
    dummy_req.completed_course = copy
    dummy_req.set_dummy_reqt_id
    copy
  end

end
