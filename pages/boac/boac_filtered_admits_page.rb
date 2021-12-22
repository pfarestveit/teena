require_relative '../../util/spec_helper'

class BOACFilteredAdmitsPage

  include PageObject
  include Page
  include BOACPages
  include BOACListViewAdmitPages
  include BOACCohortPages
  include BOACCohortAdmitPages
  include BOACFilteredStudentsPageFilters
  include BOACFilteredStudentsPageResults
  include BOACGroupAddSelectorPages
  include BOACGroupModalPages

  link(:create_cohort_button, id: 'admitted-students-cohort-show-filters')
  span(:depend_char_error_msg, xpath: '//span[text()="Dependents must be an integer greater than or equal to 0."]')
  span(:depend_logic_error_msg, xpath: '//span[text()="Dependents inputs must be in ascending order."]')

  # Loads the cohort page by the cohort's ID
  # @param cohort [FilteredCohort]
  def load_cohort(cohort)
    logger.info "Loading CE3 cohort '#{cohort.name}'"
    navigate_to "#{BOACUtils.base_url}/cohort/#{cohort.id}"
    wait_for_title cohort.name
  end

  def click_create_cohort
    logger.info 'Clicking the Create Cohort button'
    wait_for_load_and_click create_cohort_button_element
  end

end
