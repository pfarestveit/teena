require_relative '../../util/spec_helper'

class BOACCuratedGroupPage

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACListViewPages
  include BOACCohortPages

  span(:cohort_not_found_msg, xpath: '//span[contains(.,"No curated group found with id: ")]')
  text_area(:rename_group_input, id: 'rename-input')

  # Loads a curated group
  # @param group [CuratedGroup]
  def load_page(group)
    navigate_to "#{BOACUtils.base_url}/curated_group/#{group.id}"
    wait_for_spinner
  end

  # Returns the error message element shown when a user attempts to view a curated group it does not own
  # @param user [User]
  # @param group [CuratedGroup]
  def no_group_access_msg(user, group)
    span_element(xpath: "//span[text()='Current user, #{user.uid}, does not own curated group #{group.id}']")
  end

  # Renames a curated group
  # @param group [CuratedGroup]
  # @param new_name [String]
  def rename_curated(group, new_name)
    logger.info "Changing the name of curated cohort ID #{group.id} to #{new_name}"
    load_page group
    wait_for_load_and_click rename_cohort_button_element
    group.name = new_name
    wait_for_element_and_type(rename_group_input_element, new_name)
    wait_for_update_and_click rename_cohort_confirm_button_element
    span_element(xpath: "//span[text()=\"#{group.name}\"]").when_present Utils.short_wait
  end

  # Removes a student from a curated group
  # @param student [User]
  # @param group [CuratedGroup]
  def curated_remove_student(student, group)
    logger.info "Removing UID #{student.uid} from cohort '#{group.name}'"
    wait_for_student_list
    wait_for_update_and_click button_element(:id => "student-#{student.uid}-curated-group-remove")
    group.members.delete student
    sleep 2
    wait_until(Utils.short_wait) { list_view_uids.sort == group.members.map(&:uid).sort }
    wait_for_sidebar_group_member_count group
  end

end
