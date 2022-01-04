module BOACGroupAddSelectorPages

  include PageObject
  include Logging
  include Page
  include BOACPages

  button(:removed_from_grp_conf, xpath: '//*[contains(text(), "Removed")]')

  def grp_selected?(group)
    grp_checkbox_link(group).when_visible Utils.short_wait
    grp_checkbox_link(group).text.include? 'is selected'
  end

  # STUDENT GROUPS

  link(:selector_create_grp_button, id: 'create-curated-group')
  checkbox(:add_all_to_grp_checkbox, xpath: '//input[@id="add-all-to-curated-group"]/..')
  button(:add_to_grp_button, id: 'add-to-curated-group')
  button(:student_added_to_grp_conf, id: 'added-to-curated-group')
  button(:students_added_to_grp_conf, id: 'add-to-curated-group-confirmation')
  elements(:add_individual_to_grp_checkbox, :checkbox, xpath: "//input[contains(@id,'curated-group-checkbox')]")
  elements(:add_individual_to_grp_input, :text_field, xpath: "//input[contains(@id,'curated-group-checkbox')]")

  def click_add_to_grp_button
    wait_for_update_and_click add_to_grp_button_element
  end

  # Clicks the button to create a new group
  def click_create_new_grp
    logger.debug 'Clicking group selector button to create a new group'
    wait_for_load_and_click selector_create_grp_button_element
    grp_name_input_element.when_visible Utils.short_wait
  end

  def grp_checkbox_link(group)
    link_element(xpath: "//input[@id='curated-group-#{group.id}-checkbox']/../..")
  end

  def check_grp(group)
    wait_for_update_and_click grp_checkbox_link(group)
  end

  def select_students_to_add(students)
    logger.debug "Selecting UIDs: #{students.map &:uid}"
    students.each { |s| wait_for_update_and_click checkbox_element(xpath: "//input[@id='student-#{s.sis_id}-curated-group-checkbox']/..") }
  end

  def add_student_to_grp(student, group)
    logger.info "Adding SID #{student.sis_id} to group #{group.name} ID #{group.id}"
    click_add_to_grp_button
    check_grp group
    student_added_to_grp_conf_element.when_visible Utils.short_wait
    group.members << student
    wait_for_sidebar_group group
  end

  def add_students_to_grp(students, group)
    logger.info "Adding SIDs #{students.map &:sis_id} to group #{group.name} ID #{group.id}"
    click_add_to_grp_button
    check_grp group
    students_added_to_grp_conf_element.when_present Utils.short_wait
    group.members << students
    group.members.flatten!
    wait_for_sidebar_group group
  end

  def remove_student_from_grp(student, group)
    logger.info "Removing SID #{student.sis_id} from group #{group.name} ID #{group.id}"
    click_add_to_grp_button
    check_grp group
    removed_from_grp_conf_element.when_visible Utils.short_wait
    group.members.delete student
    wait_for_sidebar_group group
  end

  def add_student_to_new_grp(student, group)
    logger.info "Adding SID #{student.sis_id} to new group #{group.name}"
    click_add_to_grp_button
    click_create_new_grp
    name_and_save_group group
    student_added_to_grp_conf_element.when_visible Utils.short_wait
    group.members << student
    wait_for_sidebar_group group
  end

  def add_students_to_new_grp(students, group)
    logger.info "Adding SIDs #{students.map &:sis_id} to new group #{group.name}"
    click_add_to_grp_button
    click_create_new_grp
    name_and_save_group group
    students_added_to_grp_conf_element.when_present Utils.short_wait
    group.members << students
    group.members.flatten!
    wait_for_sidebar_group group
  end

  def select_and_add_students_to_grp(students, group)
    select_students_to_add students
    add_students_to_grp(students, group)
  end

  def select_and_add_students_to_new_grp(students, group)
    select_students_to_add students
    add_students_to_new_grp(students, group)
  end

  def select_and_add_all_students_to_grp(all_students, group)
    wait_until(Utils.short_wait) { add_individual_to_grp_checkbox_elements.any? }
    wait_for_update_and_click add_all_to_grp_checkbox_element
    logger.debug "There are #{add_individual_to_grp_checkbox_elements.length} individual checkboxes"
    # Don't try to add users to the group if they're already in the group
    group_sids = group.members.map &:sis_id
    visible_sids = add_individual_to_grp_input_elements.map { |el| el.attribute('id').split('-')[1] }
    sids_to_add = visible_sids - group_sids
    students_to_add = all_students.select { |student| sids_to_add.include? student.sis_id }
    add_students_to_grp(students_to_add, group)
  end

  # CE3 GROUPS

  link(:selector_create_ce3_grp_button, id: 'create-admissions-group')
  checkbox(:add_all_to_ce3_grp_checkbox, xpath: '//input[@id="add-all-to-admissions-group"]/..')
  button(:add_to_ce3_group_button, id: 'add-to-admissions-group')
  button(:student_added_to_ce3_grp_conf, id: 'added-to-admissions-group')
  button(:students_added_to_ce3_grp_conf, id: 'add-to-admissions-group-confirmation')
  elements(:add_individual_to_ce3_grp_checkbox, :checkbox, xpath: "//input[contains(@id, 'admissions-group-checkbox')]/..")
  elements(:add_individual_to_ce3_grp_input, :text_field, xpath: "//input[contains(@id, 'admissions-group-checkbox')]")

  def click_add_to_ce3_grp_button
    wait_for_update_and_click add_to_ce3_group_button_element
  end

  def click_create_new_ce3_grp
    logger.debug 'Clicking group selector button to create a new CE3 group'
    wait_for_update_and_click selector_create_ce3_grp_button_element
    grp_name_input_element.when_visible Utils.short_wait
  end

  def ce3_grp_checkbox_link(group)
    link_element(xpath: "//input[@id='admissions-group-#{group.id}-checkbox']/../..")
  end

  def check_ce3_grp(group)
    wait_for_update_and_click ce3_grp_checkbox_link(group)
  end

  def ce3_grp_selected?(group)
    ce3_grp_checkbox_link(group).when_visible Utils.short_wait
    ce3_grp_checkbox_link(group).text.include? 'is selected'
  end

  def select_admits_to_add(admits)
    logger.debug "Selecting SIDs: #{admits.map &:sis_id}"
    admits.each { |s| wait_for_update_and_click checkbox_element(xpath: "//input[@id='admit-#{s.sis_id}-admissions-group-checkbox']/..") }
  end

  def add_admit_to_ce3_grp(admit, group)
    logger.info "Adding SID #{admit.sis_id} to group #{group.name} ID #{group.id}"
    click_add_to_ce3_grp_button
    check_ce3_grp group
    student_added_to_ce3_grp_conf_element.when_present Utils.short_wait
    group.members << admit
    wait_for_sidebar_group group
  end

  def add_admits_to_ce3_grp(admits, group)
    logger.info "Adding SIDs #{admits.map &:sis_id} to group #{group.name} ID #{group.id}"
    click_add_to_ce3_grp_button
    check_ce3_grp group
    students_added_to_ce3_grp_conf_element.when_present Utils.short_wait
    group.members << admits
    group.members.flatten!
    wait_for_sidebar_group group
  end

  def remove_admit_from_ce3_grp(admit, group)
    logger.info "Removing SID #{admit.sis_id} from group #{group.name} ID #{group.id}"
    click_add_to_ce3_grp_button
    check_ce3_grp group
    removed_from_grp_conf_element.when_present Utils.short_wait
    group.members.delete admit
    wait_for_sidebar_group group
  end

  def add_admit_to_new_ce3_grp(admit, group)
    logger.info "Adding SID #{admit.sis_id} to new group #{group.name}"
    click_add_to_ce3_grp_button
    click_create_new_ce3_grp
    name_and_save_group group
    student_added_to_ce3_grp_conf_element.when_present Utils.short_wait
    group.members << admit
    wait_for_sidebar_group group
  end

  def add_admits_to_new_ce3_grp(students, group)
    logger.info "Adding SIDs #{students.map &:sis_id} to new group #{group.name}"
    click_add_to_ce3_grp_button
    click_create_new_ce3_grp
    name_and_save_group group
    students_added_to_ce3_grp_conf_element.when_present Utils.short_wait
    group.members << students
    group.members.flatten!
    wait_for_sidebar_group group
  end

  def select_and_add_admits_to_ce3_grp(admits, group)
    select_admits_to_add admits
    add_admits_to_ce3_grp(admits, group)
  end

  def select_and_add_admits_to_new_ce3_grp(admits, group)
    select_admits_to_add admits
    add_admits_to_new_ce3_grp(admits, group)
  end

  def select_and_add_all_admits_to_ce3_grp(admits, group)
    wait_until(Utils.short_wait) { add_individual_to_ce3_grp_checkbox_elements.any? &:visible? }
    wait_for_update_and_click add_all_to_ce3_grp_checkbox_element
    logger.debug "There are #{add_individual_to_ce3_grp_checkbox_elements.length} individual checkboxes"
    add_admits_to_ce3_grp(admits, group)
  end

end
