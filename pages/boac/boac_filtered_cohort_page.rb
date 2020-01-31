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

  # Returns the heading for a given cohort page
  # @param cohort [FilteredCohort]
  # @return [PageObject::Elements::Span]
  def cohort_heading(cohort)
    h1_element(xpath: "//h1[contains(text(),\"#{cohort.name}\")]")
  end

  # COHORT NAVIGATION

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

  # COHORT MANAGEMENT

  button(:save_cohort_button_one, id: 'save-button')
  text_area(:cohort_name_input, id: 'create-input')
  button(:save_cohort_button_two, id: 'create-confirm')
  button(:cancel_cohort_button, id: 'create-cancel')
  text_area(:rename_cohort_input, id: 'rename-cohort-input')
  elements(:everyone_cohort_link, :link, xpath: '//h1[text()="Everyone\'s Cohorts"]/following-sibling::div//a')

  # Clicks the button to save a new cohort, which triggers the name input modal
  def click_save_cohort_button_one
    wait_until(Utils.medium_wait) { save_cohort_button_one_element.visible?; save_cohort_button_one_element.enabled? }
    wait_for_update_and_click save_cohort_button_one_element
  end

  # Enters a cohort name and clicks the Save button
  # @param cohort [FilteredCohort]
  def name_cohort(cohort)
    wait_for_element_and_type(cohort_name_input_element, cohort.name)
    wait_for_update_and_click save_cohort_button_two_element
  end

  # Clicks the Save Cohort button, enters a cohort name, and clicks the Save button
  # @param cohort [FilteredCohort]
  def save_and_name_cohort(cohort)
    click_save_cohort_button_one
    name_cohort cohort
  end

  # Waits for a cohort page to load and obtains the cohort's ID
  # @param cohort [FilteredCohort]
  # @return [Integer]
  def wait_for_filtered_cohort(cohort)
    cohort_heading(cohort).when_present Utils.medium_wait
    BOACUtils.set_filtered_cohort_id cohort
  end

  # Clicks the Cancel button during cohort creation
  def cancel_cohort
    wait_for_update_and_click cancel_cohort_button_element
    modal_element.when_not_present Utils.short_wait
  rescue
    logger.warn 'No cancel button to click'
  end

  # Creates a new cohort
  # @param cohort [FilteredCohort]
  def create_new_cohort(cohort)
    logger.info "Creating a new cohort named #{cohort.name}"
    save_and_name_cohort cohort
    wait_for_filtered_cohort cohort
  end

  # Combines methods to load the create filtered cohort page, perform a search, and create a filtered cohort
  # @param cohort [FilteredCohort]
  # @param test [BOACTestConfig]
  def search_and_create_new_cohort(cohort, test)
    click_sidebar_create_filtered
    perform_search cohort
    create_new_cohort cohort
  end

  # Renames a cohort
  # @param cohort [FilteredCohort]
  # @param new_name [String]
  def rename_cohort(cohort, new_name)
    logger.info "Changing the name of cohort ID #{cohort.id} to #{new_name}"
    load_cohort cohort
    wait_for_load_and_click rename_cohort_button_element
    cohort.name = new_name
    wait_for_element_and_type(rename_cohort_input_element, new_name)
    wait_for_update_and_click rename_cohort_confirm_button_element
    h1_element(xpath: "//h1[contains(text(),\"#{cohort.name}\")]").when_present Utils.short_wait
  end

end
