require_relative '../../util/spec_helper'

module Page

  module BOACPages

    module CohortPages

      class FilteredCohortPage

        include PageObject
        include Logging
        include Page
        include BOACPages
        include CohortPages

        # Loads a cohort page by the cohort's ID
        # @param cohort [FilteredCohort]
        def load_cohort(cohort)
          logger.info "Loading cohort '#{cohort.name}'"
          navigate_to "#{BOACUtils.base_url}/cohort?c=#{cohort.id}"
          wait_for_title cohort.name
        end

        # Navigates directly to a team page
        # @param team [Team]
        def load_team_page(team)
          logger.info "Loading cohort page for team #{team.name}"
          navigate_to "#{BOACUtils.base_url}/cohort?c=#{team.code}"
          wait_for_title "#{team.name}"
        end

        # FILTERED COHORTS - Creation

        button(:save_cohort_button_one, id: 'create-cohort-btn')
        text_area(:cohort_name_input, id: 'filtered-cohort-create-input')
        span(:title_required_msg, xpath: '//span[text()="Required"]')
        button(:save_cohort_button_two, id: 'confirm-create-filtered-cohort-btn')
        button(:cancel_cohort_button, id: 'cancel-create-filtered-cohort-btn')
        span(:cohort_not_found_msg, xpath: '//span[contains(.,"No cohort found with identifier: ")]')
        elements(:everyone_cohort_link, :span, xpath: '//h1[text()="Everyone\'s Cohorts"]/following-sibling::div//a[@data-ng-bind="cohort.label"]')

        # Clicks the button to save a new cohort, which triggers the name input modal
        def click_save_cohort_button_one
          wait_until(Utils.medium_wait) { save_cohort_button_one_element.enabled? }
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

        # Creates a new cohort by editing the search criteria of an existing one
        # @param old_cohort [FilteredCohort]
        # @param new_cohort [FilteredCohort]
        def search_and_create_edited_cohort(old_cohort, new_cohort)
          load_cohort old_cohort
          perform_search new_cohort
          save_and_name_cohort new_cohort
          wait_for_filtered_cohort new_cohort
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
          wait_for_title 'Cohorts'
          wait_until(Utils.short_wait) { everyone_cohort_link_elements.any? }
          cohorts = everyone_cohort_link_elements.map { |link| FilteredCohort.new({id: link.attribute('href').delete('/cohort?c='), name: link.text}) }
          cohorts.flatten
        end

        # Navigates to the Inactive Students page
        def load_inactive_students_page
          navigate_to "#{BOACUtils.base_url}/cohort?inactive=true&c=search"
        end

        # Navigates to the Intensive Students page
        def load_intensive_students_page
          navigate_to "#{BOACUtils.base_url}/cohort?i=true&c=search"
        end

        # FILTERED COHORTS - Search

        button(:squad_filter_button, id: 'cohort-filter-group-codes')
        elements(:squad_option, :checkbox, xpath: '//input[contains(@id,"cohort-filter-option-group-codes")]')
        button(:level_filter_button, id: 'cohort-filter-levels')
        elements(:level_option, :checkbox, xpath: '//input[contains(@id, "cohort-filter-option-level")]')
        button(:major_filter_button, id: 'cohort-filter-majors')
        elements(:major_option, :checkbox, xpath: '//input[contains(@id, "cohort-filter-option-major")]')
        button(:gpa_range_filter_button, id: 'cohort-filter-gpa-ranges')
        elements(:gpa_range_option, :checkbox, xpath: '//input[contains(@id, "cohort-filter-option-gpa-range")]')
        button(:units_filter_button, id: 'cohort-filter-unit-ranges')
        elements(:units_option, :checkbox, xpath: '//input[contains(@id, "cohort-filter-option-unit-ranges")]')

        button(:search_button, id: 'apply-filters-btn')

        # Returns the heading for a given cohort page
        # @param cohort [FilteredCohort]
        # @return [PageObject::Elements::Span]
        def cohort_heading(cohort)
          span_element(xpath: "//h1/span[text()=\"#{cohort.name}\"]")
        end

        # Returns the option for a given squad
        # @param squad [Squad]
        # @return [PageObject::Elements::Option]
        def squad_option_element(squad)
          checkbox_element(xpath: "//span[text()=\"#{squad.name}\"]/preceding-sibling::input")
        end

        # Returns the option for a given level
        # @param level [String]
        # @return [PageObject::Elements::Option]
        def levels_option_element(level)
          checkbox_element(xpath: "//span[contains(text(),\"#{level}\")]/preceding-sibling::input")
        end

        # Returns the option for a given major
        # @param major [String]
        # @return [PageObject::Elements::Option]
        def majors_option_element(major)
          checkbox_element(xpath: "//span[text()=\"#{major}\"]/preceding-sibling::input")
        end

        # Returns the option for a given GPA range
        # @param gpa_range [String]
        # @return [PageObject::Elements::Option]
        def gpa_range_option_element(gpa_range)
          checkbox_element(xpath: "//input[@aria-label='#{gpa_range}']")
        end

        # Returns the option for a given units range
        # @param units [String]
        # @return [PageObject::Elements::Option]
        def units_option_element(units)
          checkbox_element(xpath: "//span[text()=\"#{units}\"]/preceding-sibling::input")
        end

        # Verifies that a set of cohort search criteria are currently selected
        # @param search_criteria [CohortSearchCriteria]
        # @return [boolean]
        def search_criteria_selected?(search_criteria)
          wait_until(Utils.short_wait) { squad_option_elements.any? }
          search_criteria.squads.each do |s|
            wait_until(Utils.short_wait, "Squad #{s.name} is not selected") { squad_option_element(s).exists? && squad_option_element(s).attribute('class').include?('not-empty') }
          end if search_criteria.squads

          search_criteria.levels.each do |l|
            wait_until(Utils.short_wait, "Level #{l} is not selected") { levels_option_element(l).exists? && levels_option_element(l).attribute('class').include?('not-empty') }
          end if search_criteria.levels

          search_criteria.majors.each do |m|
            wait_until(Utils.short_wait, "Major #{m} is not selected") { majors_option_element(m).exists? && majors_option_element(m).attribute('class').include?('not-empty') }
          end if search_criteria.majors

          search_criteria.gpa_ranges.each do |g|
            wait_until(Utils.short_wait, "GPA range #{g} is not selected") { gpa_range_option_element(g).exists? && gpa_range_option_element(g).attribute('class').include?('not-empty') }
          end if search_criteria.gpa_ranges

          search_criteria.units.each do |u|
            wait_until(Utils.short_wait, "Units #{u} is not selected") { units_option_element(u).exists? && units_option_element(u).attribute('class').include?('not-empty') }
          end if search_criteria.units
          true
        end

        # Waits for a search to complete, returning either a set of results or 'no results'
        def wait_for_search_results
          wait_for_spinner
          results_element.when_present Utils.short_wait
          sleep 1
        end

        # Checks a search filter option
        # @param element [PageObject::Elements::Option]
        def check_search_option(element)
          begin
            tries ||= 2
            element.click
            wait_until(1) { element.attribute('class').include?('not-empty') }
          rescue
            logger.debug 'Trying to check a search option again'
            (tries -= 1).zero? ? fail : retry
          end
        end

        # Executes a custom cohort search using search criteria associated with a cohort and stores the result count. Optionally writes
        # performance info to a CSV.
        # @param cohort [FilteredCohort]
        # @param csv [CSV]
        def perform_search(cohort, csv = nil)
          criteria = cohort.search_criteria
          logger.info "Searching for squads '#{criteria.squads && (criteria.squads.map &:name)}', levels '#{criteria.levels}', majors '#{criteria.majors}', GPA ranges '#{criteria.gpa_ranges}', units '#{criteria.units}'"
          wait_until(Utils.short_wait) { level_option_elements.any? }
          sleep 2

          # Uncheck any options that are already checked from a previous search, then check those that apply to the current search.
          # Do not look for squad options if the search criteria do not include teams, as non-ASC advisors cannot search by teams.
          if criteria.squads
            unless squad_option_elements.all? &:visible?
              wait_for_update_and_click squad_filter_button_element
              wait_until(1) { squad_option_elements.all? &:visible? }
            end
            squad_option_elements.each { |o| o.click if o.attribute('class').include?('not-empty') }
            criteria.squads.each { |s| check_search_option squad_option_element(s) }
          end

          unless level_option_elements.all? &:visible?
            wait_for_update_and_click level_filter_button_element
            wait_until(1) { level_option_elements.all? &:visible? }
          end
          level_option_elements.each { |o| o.click if o.attribute('class').include?('not-empty') }
          criteria.levels.each { |l| check_search_option levels_option_element(l) } if criteria.levels

          unless major_option_elements.all? &:visible?
            wait_for_update_and_click major_filter_button_element
            wait_until(1) { major_option_elements.all? &:visible? }
          end
          major_option_elements.each { |o| o.click if o.attribute('class').include?('not-empty') }
          if criteria.majors
            # If 'Declared' is selected, then no other majors can be used as search criteria.
            criteria.majors = ['Declared'] if criteria.majors.include? 'Declared'
            criteria.majors.each do |m|
              # Majors are only shown if they apply to users, so the majors list will change over time. Avoid test failures if
              # the search criteria is out of sync with actual user majors.
              if majors_option_element(m).exists?
                check_search_option majors_option_element(m)
              else
                logger.warn "The major '#{m}' is not among the list of majors, removing from search criteria"
                criteria.majors.delete_if { |i| i == m }
              end
            end
          end

          unless gpa_range_option_elements.all? &:visible?
            wait_for_update_and_click gpa_range_filter_button_element
            wait_until(1) { gpa_range_option_elements.all? &:visible? }
          end
          gpa_range_option_elements.each { |o| o.click if o.attribute('class').include?('not-empty') }
          criteria.gpa_ranges.each { |g| check_search_option gpa_range_option_element(g) } if criteria.gpa_ranges

          unless units_option_elements.all? &:visible?
            wait_for_update_and_click units_filter_button_element
            wait_until(1) { units_option_elements.all? &:visible? }
          end
          units_option_elements.each { |u| u.click if u.attribute('class').include?('not-empty') }
          criteria.units.each { |u| check_search_option units_option_element(u) } if criteria.units

          # Execute search and log time search took to complete
          wait_for_update_and_click search_button_element
          start_time = Time.now
          wait_for_search_results
          search_wait = "#{Time.now - start_time} seconds"
          logger.warn "Search took #{search_wait}"
          cohort.member_count = results_count
          logger.warn "No results found for #{criteria.squads && criteria.squads.map(&:name)}, #{criteria.majors}, #{criteria.levels}, #{criteria.gpa_ranges}, #{criteria.units}" if cohort.member_count.zero?
          # Optionally record the search criteria, result count, and time it took to load the first page of results.
          if csv
            Utils.add_csv_row(csv, [(criteria.squads && (criteria.squads.map &:name)), criteria.levels, criteria.majors, criteria.gpa_ranges, criteria.units, search_wait, cohort.member_count], %w(Squads Levels Majors GPAs Units Time Results))
          end
        end

        # Filters an array of user data hashes according to search criteria and returns the users that should be present in the UI after
        # the search completes
        # @param user_data [Array<Hash>]
        # @param search_criteria [CohortSearchCriteria]
        # @return [Array<Hash>]
        def expected_search_results(user_data, search_criteria)
          matching_squad_users = (search_criteria.squads && search_criteria.squads.any?) ?
              (user_data.select { |u| (u[:squad_names] & (search_criteria.squads.map { |s| s.name })).any? }) : user_data
          matching_level_users = (search_criteria.levels && search_criteria.levels.any?) ?
              (user_data.select { |u| search_criteria.levels.include? u[:level] }) : user_data

          matching_major_users = []
          if search_criteria.majors && search_criteria.majors.any?
            matching_major_users << user_data.select { |u| (u[:majors] & search_criteria.majors).any? }
            if search_criteria.majors.include? 'Undeclared'
              matching_major_users << user_data.select do |u|
                (u[:majors].select { |m| m.downcase.include? 'undeclared' }).any?
              end
            end
            if search_criteria.majors.include? 'Declared'
              matching_major_users << user_data.select do |u|
                (u[:majors].select { |m| !m.downcase.include? 'undeclared' }).any?
              end
            end
          else
            matching_major_users = user_data
          end
          matching_major_users = matching_major_users.uniq.flatten.compact

          matching_gpa_range_users = []
          if search_criteria.gpa_ranges && search_criteria.gpa_ranges.any?
            search_criteria.gpa_ranges.each do |range|
              array = range.include?('Below') ? %w(0 2.0) : range.delete(' ').split('-')
              low_end = array[0]
              high_end = array[1]
              matching_gpa_range_users << user_data.select do |u|
                gpa = u[:gpa].to_f
                (gpa != 0) && (low_end.to_f <= gpa) && ((high_end == '4.00') ? (gpa <= high_end.to_f.round(1)) : (gpa < high_end.to_f.round(1)))
              end
            end
          else
            matching_gpa_range_users = user_data
          end
          matching_gpa_range_users = matching_gpa_range_users.flatten

          matching_units_users = []
          if search_criteria.units
            search_criteria.units.each do |units|
              if units.include?('+')
                matching_units_users << user_data.select { |user| user[:units].to_f >= 120 }
              else
                range = units.split(' - ')
                low_end = range[0].to_f
                high_end = range[1].to_f
                matching_units_users << user_data.select { |user| (user[:units].to_f >= low_end) && (user[:units].to_f < high_end.round(-1)) }
              end
            end
          else
            matching_units_users = user_data
          end
          matching_units_users = matching_units_users.flatten

          matches = [matching_squad_users, matching_level_users, matching_major_users, matching_gpa_range_users, matching_units_users]
          matches.any?(&:empty?) ? [] : matches.inject(:'&')
        end

        # FILTERED COHORTS - Management

        elements(:cohort_name, :span, xpath: '//span[@data-ng-bind="cohort.name"]')
        elements(:rename_input, :text_area, name: 'name')
        elements(:rename_save_button, :button, xpath: '//button[contains(@id,"cohort-save-btn")]')

        # Returns the element containing the cohort name on the Manage Cohorts page
        # @param cohort [Cohort]
        # @return [PageObject::Elements::Span]
        def cohort_on_manage_cohorts(cohort)
          span_element(xpath: "//span[text()='#{cohort.name}']")
        end

        # Returns the element containing the cohort rename button on the Manage Cohorts page
        # @param cohort [Cohort]
        # @return [PageObject::Elements::Button]
        def cohort_rename_button(cohort)
          button_element(xpath: "//span[text()='#{cohort.name}']/ancestor::div[contains(@class,'cohort-manage-name')]/following-sibling::div//button[contains(text(),'Rename')]")
        end

        # Returns the element containing the cohort delete button on the Manage Cohorts page
        # @param cohort [Cohort]
        # @return [PageObject::Elements::Button]
        def cohort_delete_button(cohort)
          button_element(xpath: "//span[text()='#{cohort.name}']/ancestor::div[contains(@class,'cohort-manage-name')]/following-sibling::div//button[contains(text(),'Delete')]")
        end

        # Renames a cohort
        # @param cohort [FilteredCohort]
        # @param new_name [String]
        def rename_cohort(cohort, new_name)
          logger.info "Changing the name of cohort ID #{cohort.id} to #{new_name}"
          click_sidebar_manage_filtered
          wait_until(Utils.short_wait) do
            cohort_name_elements.any?
            cohort_name_elements.map(&:text).include? cohort.name
          end
          wait_for_load_and_click cohort_rename_button(cohort)
          cohort.name = new_name
          wait_until(Utils.short_wait) { rename_input_elements.any? }
          wait_for_element_and_type(rename_input_elements.first, new_name)
          wait_for_update_and_click rename_save_button_elements.first
          cohort_on_manage_cohorts(cohort).when_present Utils.short_wait
        end

        # Deletes a cohort
        # @param cohort [FilteredCohort]
        def delete_cohort(cohort)
          logger.info "Deleting a cohort named #{cohort.name}"
          click_sidebar_manage_filtered
          sleep 1
          wait_for_load_and_click cohort_delete_button(cohort)
          wait_for_update_and_click confirm_delete_button_element
          cohort_on_manage_cohorts(cohort).when_not_present Utils.short_wait
        end

      end
    end
  end
end
