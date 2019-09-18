require_relative '../../util/spec_helper'

class BOACGroupPage

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACListViewPages
  include BOACCohortPages
  include BOACGroupModalPages

  span(:grp_not_found_msg, xpath: '//span[contains(.,"No curated group found with id: ")]')
  text_area(:rename_group_input, id: 'rename-input')

  # Loads a group
  # @param group [CuratedGroup]
  def load_page(group)
    navigate_to "#{BOACUtils.base_url}/curated/#{group.id}"
    wait_for_spinner
  end

  # Returns the error message element shown when a user attempts to view a group it does not own
  # @param user [User]
  # @param group [CuratedGroup]
  def no_group_access_msg(user, group)
    span_element(xpath: "//span[text()='Current user, #{user.uid}, does not own curated group #{group.id}']")
  end

  # Renames a group
  # @param group [CuratedGroup]
  # @param new_name [String]
  def rename_grp(group, new_name)
    logger.info "Changing the name of group ID #{group.id} to #{new_name}"
    load_page group
    wait_for_load_and_click rename_cohort_button_element
    group.name = new_name
    wait_for_element_and_type(rename_group_input_element, new_name)
    wait_for_update_and_click rename_cohort_confirm_button_element
    span_element(xpath: "//span[text()=\"#{group.name}\"]").when_present Utils.short_wait
  end

  # Removes a student from a group
  # @param group [Group]
  # @param student [BOACUser]
  def remove_student_by_row_index(group, student)
    wait_for_student_list
    wait_for_update_and_click button_element(xpath: "#{student_row_xpath student}//button[contains(@id,'remove-student-from-curated-group')]")
    group.members.delete student
    sleep 2
    wait_until(Utils.short_wait) { list_view_uids.sort == group.members.map(&:uid).sort }
    wait_for_sidebar_group_member_count group
  end

  # ADD STUDENTS

  button(:add_students_button, id: 'bulk-add-sids-button')
  text_area(:create_group_textarea_sids, id: 'curated-group-bulk-add-sids')
  button(:add_sids_to_group_button, id: 'btn-curated-group-bulk-add-sids')
  span(:sids_bad_format_error_msg, xpath: '//span[contains(text(), "SIDs must be separated by commas, line breaks, or tabs.")]')
  span(:sids_not_found_error_msg, xpath: '//span[contains(text(), "not found")]')

  # Clicks the Add Students button on a curated group page
  def click_add_students_button
    wait_for_update_and_click add_students_button_element
  end

  # Enters text in the SID list text area
  # @param sids [String]
  def enter_sid_list(sids)
    logger.info "Entering SIDs to add to group: '#{sids}'"
    wait_for_element_and_type(create_group_textarea_sids_element, sids)
  end

  # Clicks the button to add entered SIDs to a curated group
  def click_add_sids_to_group_button
    wait_for_update_and_click add_sids_to_group_button_element
  end

  # Creates a group with list of SIDs
  # @param students [Array<BOACUser>]
  # @param group [CuratedGroup]
  def create_group_with_bulk_sids(students, group)
    enter_sid_list students.map(&:sis_id).join(', ')
    click_add_sids_to_group_button
    name_and_save_group(group)
    group.members << students
    group.members.flatten!
    group.members.uniq!
    wait_for_sidebar_group group
  end

  # Adds a comma-separated list of SIDs to an existing group
  # @param students [Array<BOACUser>]
  # @param group [CuratedGroup]
  def add_comma_sep_sids_to_existing_grp(students, group)
    click_add_students_button
    enter_sid_list students.map(&:sis_id).join(', ')
    click_add_sids_to_group_button
    group.members << students
    group.members.flatten!
    group.members.uniq!
  end

  # Adds a line-separated list of SIDs to an existing group
  # @param students [Array<BOACUser>]
  # @param group [CuratedGroup]
  def add_line_sep_sids_to_existing_grp(students, group)
    click_add_students_button
    enter_sid_list students.map(&:sis_id).join("\n")
    click_add_sids_to_group_button
    group.members << students
    group.members.flatten!
    group.members.uniq!
  end
end
