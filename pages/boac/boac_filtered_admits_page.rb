require_relative '../../util/spec_helper'

class BOACFilteredAdmitsPage

  include PageObject
  include Page
  include BOACPages
  include BOACAdmitListPages
  include BOACCohortPages
  include BOACFilteredCohortPageFilters
  include BOACFilteredCohortPageResults

  span(:depend_char_error_msg, xpath: '//span[text()="Dependents must be a number greater than or equal to 0."]')
  span(:depend_logic_error_msg, xpath: '//span[text()="Dependents inputs must be in ascending order."]')

  # Loads the cohort page by the cohort's ID
  # @param cohort [FilteredCohort]
  def load_cohort(cohort)
    logger.info "Loading CE3 cohort '#{cohort.name}'"
    navigate_to "#{BOACUtils.base_url}/cohort/#{cohort.id}"
    wait_for_title cohort.name
  end

end
