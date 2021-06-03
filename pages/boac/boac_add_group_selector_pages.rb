require_relative '../../util/spec_helper'

module BOACAddGroupSelectorPages

  include PageObject
  include Logging
  include Page
  include BOACPages

  link(:selector_create_grp_button, id: 'create-curated-group')
  checkbox(:add_all_to_grp_checkbox, xpath: '//input[@id="add-all-to-curated-group"]/..')
  elements(:add_individual_to_grp_checkbox, :checkbox, xpath: "//input[contains(@id,'curated-group-checkbox')]/..")
  elements(:add_individual_to_grp_input, :text_field, xpath: "//input[contains(@id,'curated-group-checkbox')]")
  button(:add_to_grp_button, id: 'add-to-curated-group')
  button(:students_added_to_grp_conf, id: 'add-to-curated-group-confirmation')
  button(:student_added_to_grp_conf, id: 'added-to-curated-group')
  button(:removed_from_grp_conf, id: 'removed-from-curated-group')

  # Clicks the Add-to-Group button
  def click_add_to_grp_button
    wait_for_update_and_click add_to_grp_button_element
  end

  # Returns a group checkbox
  # @param group [CuratedGroup]
  # @return [Element]
  def grp_checkbox_link(group)
    link_element(xpath: "//input[@id='curated-group-#{group.id}-checkbox']/../..")
  end

  # Checks or un-checks a group checkbox
  # @param group [CuratedGroup]
  def check_grp(group)
    wait_for_update_and_click grp_checkbox_link(group)
  end

  # Returns the state of a group checkbox
  # @param group [CuratedGroup]
  # @return [boolean]
  def grp_selected?(group)
    grp_checkbox_link(group).when_visible Utils.short_wait
    grp_checkbox_link(group).text.include? 'is selected'
  end

  # Clicks the button to create a new group
  def click_create_new_grp
    logger.debug 'Clicking group selector button to create a new group'
    wait_for_load_and_click selector_create_grp_button_element
    grp_name_input_element.when_visible Utils.short_wait
  end

  # Adds a single student to a group on the student page
  # @param student [BOACUser]
  # @param group [CuratedGroup]
  def add_student_to_grp(student, group)
    logger.info "Adding UID #{student.uid} to group #{group.name} ID #{group.id}"
    click_add_to_grp_button
    check_grp group
    # TODO - reenable this step for Firefox when bug is fixed
    student_added_to_grp_conf_element.when_visible Utils.short_wait if "#{browser.browser}" == 'chrome'
    group.members << student
    wait_for_sidebar_group group
  end

  # Adds multiple students to a group on the cohort or class pages
  # @param students [Array<BOACUser>]
  # @param group [CuratedGroup]
  def add_students_to_grp(students, group)
    logger.info "Adding UIDs #{students.map &:uid} to group #{group.name} ID #{group.id}"
    click_add_to_grp_button
    check_grp group
    # TODO - reenable this step for Firefox when bug is fixed
    students_added_to_grp_conf_element.when_visible Utils.short_wait if "#{browser.browser}" == 'chrome'
    group.members << students
    group.members.flatten!
    wait_for_sidebar_group group
  end

  # Removes a single student from a group on the student page
  # @param student [BOACUser]
  # @param group [CuratedGroup]
  def remove_student_from_grp(student, group)
    logger.info "Removing UID #{student.uid} from group #{group.name} ID #{group.id}"
    click_add_to_grp_button
    check_grp group
    removed_from_grp_conf_element.when_visible Utils.short_wait
    group.members.delete student
    wait_for_sidebar_group group
  end

  # Adds a single student to a new group on the student page
  # @param student [BOACUser]
  # @param group [CuratedGroup]
  def add_student_to_new_grp(student, group)
    logger.info "Adding UID #{student.uid} to new group #{group.name}"
    click_add_to_grp_button
    click_create_new_grp
    name_and_save_group group
    student_added_to_grp_conf_element.when_visible Utils.short_wait
    group.members << student
    wait_for_sidebar_group group
  end

  # Adds multiple students to a group on the cohort or class pages
  # @param students [Array<User>]
  # @param group [CuratedGroup]
  def add_students_to_new_grp(students, group)
    logger.info "Adding UIDs #{students.map &:uid} to new group #{group.name}"
    click_add_to_grp_button
    click_create_new_grp
    name_and_save_group group
    students_added_to_grp_conf_element.when_visible Utils.short_wait
    group.members << students
    group.members.flatten!
    wait_for_sidebar_group group
  end

  # Selects the add-to-group checkboxes for a given set of students in cohort and class page list views
  # @param students [Array<User>]
  def select_students_to_add(students)
    logger.debug "Selecting UIDs: #{students.map &:uid}"
    students.each { |s| wait_for_update_and_click checkbox_element(xpath: "//input[@id='student-#{s.sis_id}-curated-group-checkbox']/..") }
  end

  # Selects and adds multiple students to an existing group on the cohort and class page list views
  # @param students [Array<User>]
  # @param group [CuratedGroup]
  def select_and_add_students_to_grp(students, group)
    select_students_to_add students
    add_students_to_grp(students, group)
  end

  # Selects and adds multiple students to an new group on the cohort and class page list views
  # @param students [Array<User>]
  # @param group [CuratedGroup]
  def select_and_add_students_to_new_grp(students, group)
    select_students_to_add students
    add_students_to_new_grp(students, group)
  end

  # Selects and adds all students on a cohort or class page to a group
  # @param all_students [Array<BOACUser>]
  # @param group [CuratedGroup]
  def select_and_add_all_students_to_grp(all_students, group)
    wait_until(Utils.short_wait) { add_individual_to_grp_checkbox_elements.any? &:visible? }
    wait_for_update_and_click add_all_to_grp_checkbox_element
    logger.debug "There are #{add_individual_to_grp_checkbox_elements.length} individual checkboxes"

    # Don't try to add users to the group if they're already in the group
    group_sids = group.members.map &:sis_id
    visible_sids = add_individual_to_grp_input_elements.map { |el| el.attribute('id').split('-')[1] }
    sids_to_add = visible_sids - group_sids
    students_to_add = all_students.select { |student| sids_to_add.include? student.sis_id }
    add_students_to_grp(students_to_add, group)
  end

end
