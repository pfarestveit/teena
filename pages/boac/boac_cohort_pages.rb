module BOACCohortPages

  include PageObject
  include Logging
  include Page
  include BOACPages

  h1(:results, xpath: '//h1')
  button(:export_list_button, id: 'export-student-list-button')
  button(:history_button, id: 'show-cohort-history-button')

  def cohort_heading(cohort)
    h1_element(xpath: "//h1[contains(text(),\"#{cohort.name}\")]")
  end

  def results_count
    sleep 1
    results_element.when_visible Utils.short_wait
    results.split[0].to_i
  end

  # SAVE/CREATE

  button(:save_cohort_button_one, id: 'save-button')
  text_area(:cohort_name_input, id: 'create-input')
  button(:save_cohort_button_two, id: 'create-confirm')
  button(:cancel_cohort_button, id: 'create-cancel')
  button(:apply_button, id: 'unsaved-filter-apply')

  def click_save_cohort_button_one
    wait_until(Utils.medium_wait) { save_cohort_button_one_element.visible?; save_cohort_button_one_element.enabled? }
    wait_for_update_and_click save_cohort_button_one_element
  end

  def apply_and_save_cohort
    wait_for_update_and_click apply_button_element
    wait_for_update_and_click save_cohort_button_one_element
  end

  def name_cohort(cohort)
    wait_for_element_and_type(cohort_name_input_element, cohort.name)
    wait_for_update_and_click save_cohort_button_two_element
  end

  def save_and_name_cohort(cohort)
    click_save_cohort_button_one
    name_cohort cohort
  end

  def wait_for_filtered_cohort(cohort)
    cohort_heading(cohort).when_present Utils.medium_wait
    BOACUtils.set_filtered_cohort_id cohort
  end

  def cancel_cohort
    wait_for_update_and_click cancel_cohort_button_element
    modal_element.when_not_present Utils.short_wait
  rescue
    logger.warn 'No cancel button to click'
  end

  def create_new_cohort(cohort)
    logger.info "Creating a new cohort named #{cohort.name}"
    save_and_name_cohort cohort
    wait_for_filtered_cohort cohort
  end

  def search_and_create_new_cohort(cohort, opts = {})
    if opts[:default]
      click_sidebar_create_filtered
      perform_student_search cohort
    elsif opts[:admits]
      click_sidebar_create_ce3_filtered
      perform_admit_search cohort
    end
    create_new_cohort cohort
  end

  # RENAME

  button(:rename_cohort_button, id: 'rename-button')
  button(:rename_cohort_confirm_button, id: 'rename-confirm')
  button(:rename_cohort_cancel_button, id: 'rename-cancel')
  text_area(:rename_cohort_input, id: 'rename-cohort-input')

  def rename_cohort(cohort, new_name)
    logger.info "Changing the name of cohort ID #{cohort.id} to #{new_name}"
    load_cohort cohort
    wait_for_load_and_click rename_cohort_button_element
    cohort.name = new_name
    wait_for_element_and_type(rename_cohort_input_element, new_name)
    wait_for_update_and_click rename_cohort_confirm_button_element
    h1_element(xpath: "//h1[contains(text(),\"#{cohort.name}\")]").when_present Utils.short_wait
  end

  # DELETE

  button(:delete_cohort_button, id: 'delete-button')
  button(:confirm_delete_button, id: 'delete-confirm')
  button(:cancel_delete_button, id: 'delete-cancel')

  def delete_cohort(cohort)
    logger.info "Deleting a cohort named #{cohort.name}"
    wait_for_load_and_click delete_cohort_button_element
    wait_for_update_and_click confirm_delete_button_element
    wait_until(Utils.short_wait) { current_url.include? "#{BOACUtils.base_url}/home" }
    sleep Utils.click_wait
  end

  def cancel_cohort_deletion(cohort)
    logger.info "Canceling the deletion of cohort #{cohort.name}"
    wait_for_load_and_click delete_cohort_button_element
    wait_for_update_and_click cancel_delete_button_element
    cancel_delete_button_element.when_not_present Utils.short_wait
    wait_until(1) { current_url.include? cohort.id }
  end

  # SORTING

  button(:cohort_sort_button, id: 'students-sort-by__BV_toggle_')

  def sort_by(option)
    logger.info "Sorting by #{option}"
    wait_for_update_and_click cohort_sort_button_element
    wait_for_update_and_click button_element(xpath: "//button[@id='sort-by-option-#{option}']")
    wait_for_spinner
  end

  def sort_by_first_name
    sort_by 'first_name'
  end

  def sort_by_last_name
    sort_by 'last_name'
  end

end
