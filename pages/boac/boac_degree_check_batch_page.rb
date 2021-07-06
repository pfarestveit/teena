class BOACDegreeCheckBatchPage

  include PageObject
  include Logging
  include Page
  include BOACPages

  # Students

  text_area(:student_input, id: 'degree-check-add-student')
  button(:student_add_button, id: 'degree-check-add-sids-btn')

  def added_student_element(student)
    span_element(xpath: "//span[contains(text(), '#{student.sis_id}')]")
  end

  def student_remove_button(student)
    button_element(xpath: "//span[contains(text(), '#{student.sis_id}')]/following-sibling::button")
  end

  def add_sids_to_batch(degree_batch, students)
    sids = students.map &:sis_id
    logger.debug "Adding SIDs #{sids} to batch degree"
    wait_for_textbox_and_type(student_input_element, sids.join(', '))
    wait_for_update_and_click student_add_button_element
    students.each do |student|
      logger.debug "Checking for SID '#{student.full_name} (#{student.sis_id})'"
      added_student_element(student).when_present Utils.short_wait
    end
    degree_batch.students += students
  end

  def remove_students_from_batch(degree_batch, students)
    students.each do |student|
      logger.info "Removing SID #{student.sis_id} from batch degree check"
      wait_for_update_and_click student_remove_button(student)
      added_student_element(student).when_not_visible 2
      degree_batch.students.delete student
    end
  end

  # Cohorts

  button(:select_cohort_button, id: 'batch-degree-check-cohort__BV_toggle_')
  elements(:select_cohort_link, :link, xpath: '//a[contains(@id, "batch-degree-check-cohort-option-")]"')

  def cohort_option(cohort)
    link_element(id: "batch-degree-check-cohort-option-#{cohort.id}")
  end

  def added_cohort_element(cohort)
    span_element(xpath: "//span[contains(@id, \"batch-degree-check-cohort\")][text()=\"#{cohort.name}\"]")
  end

  def cohort_remove_button(cohort)
    button_element(xpath: "//span[contains(@id, 'batch-degree-check-cohort')][text()='#{cohort.name}']/following-sibling::button")
  end

  def add_cohorts_to_batch(degree_batch, cohorts)
    cohorts.each do |cohort|
      logger.debug "Cohort '#{cohort.name}' will be used in creation of batch degree check"
      wait_for_update_and_click select_cohort_button_element
      wait_for_update_and_click cohort_option(cohort)
      wait_for_element(added_cohort_element(cohort), Utils.short_wait)
      degree_batch.cohorts << cohort
    end
  end

  def remove_cohorts_from_batch(degree_batch, cohorts)
    cohorts.each do |cohort|
      logger.info "Removing cohort '#{cohort.name}' from batch degree check"
      wait_for_update_and_click cohort_remove_button(cohort)
      added_cohort_element(cohort).when_not_visible 1
      degree_batch.cohorts.delete cohort
    end
  end

  # Groups

  button(:select_group_button, id: 'batch-degree-check-curated__BV_toggle_')
  elements(:select_group_link, :link, xpath: '//a[contains(@id, "batch-degree-check-curated-option-")]"')

  def group_option(group)
    link_element(id: "batch-degree-check-curated-option-#{group.id}")
  end

  def added_group_element(group)
    span_element(xpath: "//span[contains(@id, \"batch-degree-check-curated\")][text()=\"#{group.name}\"]")
  end

  def group_remove_button(group)
    button_element(xpath: "//span[contains(@id, 'batch-degree-check-curated')][text()='#{group.name}']/following-sibling::button")
  end

  def add_curated_groups_to_batch(degree_batch, groups)
    groups.each do |group|
      logger.debug "Curated group '#{group.name}' will be used in creation of batch degree check"
      wait_for_update_and_click select_group_button_element
      wait_for_update_and_click group_option(group)
      wait_for_element(added_group_element(group), Utils.short_wait)
      degree_batch.curated_groups << group
    end
  end

  def remove_groups_from_batch(degree_batch, groups)
    groups.each do |group|
      logger.info "Removing group '#{group.name}' from batch degree check"
      wait_for_update_and_click group_remove_button(group)
      added_group_element(group).when_not_visible 1
      degree_batch.curated_groups.delete group
    end
  end

  # Degrees

  button(:select_degree_button, id: 'degree-template-select__BV_toggle_')
  elements(:select_degree_link, :link, xpath: '//a[contains(@id, "degree-template-option")]')

  def degree_option(degree)
    link_element(id: "degree-template-option-#{degree.id}")
  end

  def select_degree(degree)
    logger.info "Selecting '#{degree.name}'"
    wait_for_update_and_click select_degree_button_element
    wait_for_update_and_click degree_option(degree)
  end

  # Save / Cancel

  div(:dupe_degree_check_msg, xpath: '//div[contains(text(), "The degree check will not be added to their student record")]')
  span(:student_count_msg, id: 'target-student-count-alert')
  button(:batch_degree_check_save_button, id: 'batch-degree-check-save')
  button(:batch_degree_check_cancel_button, id: 'batch-degree-check-cancel')

  def click_save_batch_degree_check
    logger.info 'Clicking batch degree check save button'
    wait_for_update_and_click batch_degree_check_save_button_element
  end

  def click_cancel_batch_degree_check
    logger.info 'Clicking batch degree check cancel button'
    wait_for_update_and_click batch_degree_check_cancel_button_element
  end

end
