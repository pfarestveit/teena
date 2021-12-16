class BOACGroupStudentsPage

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACCohortStudentPages
  include BOACGroupPages
  include BOACGroupModalPages

  span(:grp_not_found_msg, xpath: '//span[contains(.,"No curated group found with id: ")]')

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

end
