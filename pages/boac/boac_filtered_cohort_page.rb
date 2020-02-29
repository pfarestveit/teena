require_relative '../../util/spec_helper'

class BOACFilteredCohortPage

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACListViewPages
  include BOACCohortPages
  include BOACFilteredCohortPageFilters
  include BOACFilteredCohortPageResults
  include BOACGroupModalPages
  include BOACAddGroupSelectorPages

  def initialize(driver, advisor)
    super driver
    @advisor = advisor
  end

  # COHORT NAVIGATION

  button(:history_button, id: 'show-cohort-history-button')

  def filtered_cohort_base_url(id)
    "#{BOACUtils.base_url}/cohort/#{id}"
  end

  # Loads the cohort page by the cohort's ID
  # @param cohort [FilteredCohort]
  def load_cohort(cohort)
    logger.info "Loading cohort '#{cohort.name}'"
    navigate_to(filtered_cohort_base_url(cohort.id))
    wait_for_title cohort.name
  end

  # Hits a cohort URL and expects the 404 page to load
  # @param cohort [FilteredCohort]
  def hit_non_auth_cohort(cohort)
    navigate_to filtered_cohort_base_url(cohort.id)
    wait_for_title 'Page not found'
  end

  # Loads the Everyone's Cohorts page
  def load_everyone_cohorts_page
    navigate_to "#{BOACUtils.base_url}/cohorts/all"
    wait_for_title 'Cohorts'
  end

  # Returns all the cohorts displayed on the Everyone's Cohorts page
  # @return [Array<FilteredCohort>]
  def visible_everyone_cohorts
    click_view_everyone_cohorts
    wait_for_spinner
    begin
      wait_until(Utils.short_wait) { everyone_cohort_link_elements.any? }
      cohorts = everyone_cohort_link_elements.map { |link| FilteredCohort.new({id: link.attribute('href').gsub("#{BOACUtils.base_url}/cohort/", ''), name: link.text}) }
    rescue
      cohorts = []
    end
    cohorts.flatten!
    logger.info "Visible Everyone's Cohorts are #{cohorts.map &:name}"
    cohorts
  end

  # Clicks the History button
  def click_history
    logger.info 'Clicking History'
    wait_for_update_and_click history_button_element
    wait_until(Utils.short_wait) { button_element(xpath: '//button[contains(text(), "Back to Cohort")]') }
  end

  # COHORT MANAGEMENT

  elements(:everyone_cohort_link, :link, xpath: '//h1[text()="Everyone\'s Cohorts"]/following-sibling::div//a')

end
