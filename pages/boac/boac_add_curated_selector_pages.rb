require_relative '../../util/spec_helper'

module BOACAddCuratedSelectorPages

  include PageObject
  include Logging
  include Page
  include BOACPages

  # Selector 'create' and 'add student(s)' UI shared by list view pages (filtered cohort page and class page)
  button(:selector_create_curated_button, id: 'create-curated-group')
  checkbox(:add_all_to_curated_checkbox, id: 'add-all-to-curated-group')
  elements(:add_individual_to_curated_checkbox, :checkbox, xpath: "//input[contains(@id,'curated-cohort-checkbox')]")
  span(:add_to_curated_button, id: 'add-to-curated-group')
  button(:added_to_curated_conf, id: 'add-to-curated-group-confirmation')

  # Selects the add-to-group checkboxes for a given set of students
  # @param students [Array<User>]
  def select_students_to_add(students)
    logger.info "Adding student SIDs: #{students.map &:sis_id}"
    students.each { |s| wait_for_update_and_click checkbox_element(id: "student-#{s.sis_id}-curated-group-checkbox") }
  end

  # Selects a curated group for adding users and waits for the 'added' confirmation.
  # @param students [Array<User>]
  # @param group [CuratedGroup]
  def select_group_and_add(students, group)
    logger.info "Selecting group #{group.name}"
    wait_for_update_and_click add_to_curated_button_element
    wait_for_update_and_click checkbox_element(xpath: "//span[text()='#{group.name}']/preceding-sibling::input")
    added_to_curated_conf_element.when_visible Utils.short_wait
    group.members << students
    group.members.flatten!
  end

  # Creates a new curated group for adding users and waits for the 'added' confirmation and presence of the group in the sidebar
  # @param students [Array<User>]
  # @param group [CuratedGroup]
  def selector_create_new_group(students, group)
    wait_for_update_and_click add_to_curated_button_element
    logger.debug 'Clicking curated group selector button to create a new cohort'
    wait_for_load_and_click selector_create_curated_button_element
    curated_name_input_element.when_visible Utils.short_wait
    name_and_save_group group
    added_to_curated_conf_element.when_visible Utils.short_wait
    group.members << students
    group.members.flatten!
    wait_for_sidebar_group group
  end

  # Adds a given set of students to an existing curated group
  # @param students [Array<User>]
  # @param group [CuratedGroup]
  def selector_add_students_to_group(students, group)
    select_students_to_add students
    select_group_and_add(students, group)
  end

  # Adds a given set of students to a new curated group, which is created as part of the process
  # @param students [Array<User>]
  # @param group [CuratedGroup]
  def selector_add_students_to_new_group(students, group)
    select_students_to_add students
    selector_create_new_group(students, group)
  end

  # Adds all the students on a page to a curated group
  # @param all_students [Array<BOACUser>]
  # @param group [CuratedGroup]
  def selector_add_all_students_to_group(all_students, group)
    wait_until(Utils.short_wait) { add_individual_to_curated_checkbox_elements.any? &:visible? }
    wait_for_update_and_click add_all_to_curated_checkbox_element
    logger.debug "There are #{add_individual_to_curated_checkbox_elements.length} individual checkboxes"
    visible_sids = add_individual_to_curated_checkbox_elements.map { |el| el.attribute('id').split('-')[1] }
    visible_students = all_students.select { |student| visible_sids.include? student.sis_id }
    select_group_and_add(visible_students, group)
  end

end
