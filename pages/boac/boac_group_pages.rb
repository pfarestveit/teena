module BOACGroupPages

  include PageObject
  include Logging
  include Page
  include BOACPages

  text_area(:rename_group_input, id: 'rename-input')

  def load_page(group)
    navigate_to "#{BOACUtils.base_url}/curated/#{group.id}"
    wait_for_spinner
  end

  def hit_non_auth_group(group)
    navigate_to "#{BOACUtils.base_url}/curated/#{group.id}"
    wait_for_title 'Page not found'
  end

  def rename_grp(group, new_name)
    logger.info "Changing the name of group ID #{group.id} to #{new_name}"
    load_page group
    wait_for_load_and_click rename_cohort_button_element
    group.name = new_name
    wait_for_element_and_type(rename_group_input_element, new_name)
    wait_for_update_and_click rename_cohort_confirm_button_element
    cohort_heading(group).when_present Utils.short_wait
  end

  # ADD STUDENTS / ADMITS

  button(:add_students_button, id: 'bulk-add-sids-button')
  text_area(:create_group_textarea_sids, id: 'curated-group-bulk-add-sids')
  button(:add_sids_to_group_button, id: 'btn-curated-group-bulk-add-sids')
  div(:sids_bad_format_error_msg, xpath: '//div[contains(text(), "SIDs must be separated by commas, line breaks, or tabs.")]')
  div(:sids_not_found_error_msg, xpath: '//div[contains(text(), "not found")]')
  button(:remove_invalid_sids_button, id: 'remove-invalid-sids-btn')

  def click_add_sids_button
    wait_for_update_and_click add_students_button_element
  end

  def click_add_sids_to_group_button
    wait_for_load_and_click add_sids_to_group_button_element
  end

  def click_remove_invalid_sids
    logger.info 'Clicking button to remove invalid SIDs'
    remove_invalid_sids_button_element.when_present Utils.medium_wait
    js_click remove_invalid_sids_button_element
    # Sometimes it's hidden, sometimes it goes away
    remove_invalid_sids_button_element.when_not_visible Utils.short_wait rescue Selenium::WebDriver::Error::StaleElementReferenceError
  end

  def create_group_with_bulk_sids(members, group)
    enter_sid_list(create_group_textarea_sids_element, members.map(&:sis_id).join(', '))
    click_add_sids_to_group_button
    name_and_save_group(group)
    group.members << members
    group.members.flatten!
    group.members.uniq!
    wait_for_sidebar_group group
  end

  def add_comma_sep_sids_to_existing_grp(members, group)
    click_add_sids_button
    enter_sid_list(create_group_textarea_sids_element, members.map(&:sis_id).join(','))
    click_add_sids_to_group_button
    group.members << members
    group.members.flatten!
    group.members.uniq!
  end

  def add_line_sep_sids_to_existing_grp(members, group)
    click_add_sids_button
    enter_sid_list(create_group_textarea_sids_element, members.map(&:sis_id).join("\n"))
    click_add_sids_to_group_button
    group.members << members
    group.members.flatten!
    group.members.uniq!
  end

  def add_space_sep_sids_to_existing_grp(members, group)
    click_add_sids_button
    enter_sid_list(create_group_textarea_sids_element, members.map(&:sis_id).join(' '))
    click_add_sids_to_group_button
    group.members << members
    group.members.flatten!
    group.members.uniq!
  end

end
