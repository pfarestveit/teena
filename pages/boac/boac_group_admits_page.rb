class BOACGroupAdmitsPage

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACListViewAdmitPages
  include BOACCohortAdmitPages
  include BOACGroupPages
  include BOACGroupModalPages

  def remove_admit_by_row_index(group, admit)
    wait_for_admit_cohort_sids
    wait_for_update_and_click button_element(xpath: "#{admit_row_xpath admit}//button[contains(@id,'remove-student-from-curated-group')]")
    group.members.delete admit
    sleep 2
    wait_until(Utils.short_wait) { admit_cohort_row_sids.sort == group.members.map(&:sis_id).sort }
    wait_for_sidebar_group_member_count group
  end

end
