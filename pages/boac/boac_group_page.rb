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

  # Hits a cohort URL and expects a 404 page
  # @param group [CuratedGroup]
  def hit_non_auth_group(group)
    navigate_to "#{BOACUtils.base_url}/curated/#{group.id}"
    wait_for_title 'Page not found'
  end

  # Loads the Everyone's Groups page
  def load_everyone_groups_page
    navigate_to "#{BOACUtils.base_url}/groups/all"
    wait_for_title 'Groups'
  end

  # Returns the group page heading
  # @param group [CuratedGroup]
  # @return [Element]
  def group_name_heading(group)
    h1_element(xpath: "//h1[@id='curated-group-name'][contains(., \"#{group.name}\")]")
  end

  elements(:everyone_group_link, :link, xpath: '//h1[text()=" Everyone\'s Groups "]/following-sibling::div//a')

  # Returns all the curated groups displayed on the Everyone's Groups page
  # @return [Array<CuratedGroup>]
  def visible_everyone_groups
    click_view_everyone_groups
    wait_for_spinner
    begin
      wait_until(Utils.short_wait) { everyone_group_link_elements.any? }
      groups = everyone_group_link_elements.map do |link|
        CuratedGroup.new({id: link.attribute('href').gsub("#{BOACUtils.base_url}/curated/", ''), name: link.text})
      end
    rescue
      groups = []
    end
    groups.flatten!
    logger.info "Visible Everyone's Groups are #{groups.map &:name}"
    groups
  end

  # Returns the link element for a cohort using the group as a filter
  # @param cohort [FilteredCohort]
  # @return [Element]
  def linked_cohort_el(cohort)
    link_element(xpath: "//a[contains(@id, 'referencing-cohort-')][text()=\"#{cohort.name}\"]")
  end

  # Returns the element containing the 'NO!' message when attempting to delete a group in use as a cohort filter
  # @param cohort [FilteredCohort]
  # @return [Element]
  def no_deleting_el(cohort)
    div_element(xpath: "//div[@id='cohort-warning-body'][contains(., \"#{cohort.name}\")]")
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
    cohort_heading(group).when_present Utils.short_wait
  end

  # Removes a student from a group
  # @param group [CuratedGroup]
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
  div(:sids_bad_format_error_msg, xpath: '//div[contains(text(), "SIDs must be separated by commas, line breaks, or tabs.")]')
  div(:sids_not_found_error_msg, xpath: '//div[contains(text(), "not found")]')

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

  # Adds a space-separated list of SIDs to an existing group
  # @param students [Array<BOACUser>]
  # @param group [CuratedGroup]
  def add_space_sep_sids_to_existing_grp(students, group)
    click_add_students_button
    enter_sid_list students.map(&:sis_id).join(' ')
    click_add_sids_to_group_button
    group.members << students
    group.members.flatten!
    group.members.uniq!
  end

end
