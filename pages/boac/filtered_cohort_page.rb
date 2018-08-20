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

        def filtered_cohort_base_url
          "#{BOACUtils.base_url}/cohort/filtered?"
        end

        # If a cohort is a team, loads the team page using search queries; otherwise loads the cohort page by the cohort's ID
        # @param cohort [FilteredCohort]
        def load_cohort(cohort)
          logger.info "Loading cohort '#{cohort.name}'"
          if cohort.instance_of? Team
            load_team_page(cohort)
          else
            navigate_to("#{filtered_cohort_base_url}c=#{cohort.id}")
            wait_for_title cohort.name
          end
        end

        # Loads a cohort directly in matrix view
        # @param cohort [FilteredCohort]
        def load_cohort_matrix(cohort)
          logger.info "Loading cohort '#{cohort.name}' ID #{cohort.id} in matrix view"
          cohort.instance_of?(Team) ?
              navigate_to("#{filtered_cohort_base_url}c=#{cohort.code}&tab=matrix") :
              navigate_to("#{filtered_cohort_base_url}c=#{cohort.id}&tab=matrix")
          wait_for_title cohort.name
        end

        # Hits a cohort URL and expects the 404 page to load
        # @param cohort [FilteredCohort]
        def hit_non_auth_cohort(cohort)
          navigate_to "#{filtered_cohort_base_url}c=#{cohort.id}"
          wait_for_title '404'
        end

        # Hits a team page URL
        # @param team [Team]
        def hit_team_url(team)
          squads = Squad::SQUADS.select { |s| s.parent_team == team }
          squads.delete_if { |s| s.code.include? '-AA' }
          query_string = squads.map { |s| "t=#{s.code}&" }
          navigate_to "#{filtered_cohort_base_url}#{query_string.join}c=search"
        end

        # Navigates directly to a team page
        # @param team [Team]
        def load_team_page(team)
          logger.info "Loading cohort page for team #{team.name}"
          hit_team_url team
          wait_for_title 'Search'
        end

        # Hits a cohort search URL for a squad
        # @param squad [Squad]
        def load_squad(squad)
          logger.info "Loading cohort page for squad #{squad.name}"
          navigate_to "#{filtered_cohort_base_url}c=search&p=1&t=#{squad.code}"
          wait_for_title 'Filtered Cohort'
        end

        # FILTERED COHORTS - Creation

        button(:save_cohort_button_one, id: 'create-cohort-btn')
        text_area(:cohort_name_input, id: 'filtered-cohort-create-input')
        span(:title_required_msg, xpath: '//span[text()="Required"]')
        button(:save_cohort_button_two, id: 'confirm-create-filtered-cohort-btn')
        button(:cancel_cohort_button, id: 'cancel-create-filtered-cohort-btn')
        span(:cohort_not_found_msg, xpath: '//span[contains(.,"No cohort found with identifier: ")]')
        elements(:everyone_cohort_link, :link, xpath: '//h1[text()="Everyone\'s Cohorts"]/following-sibling::div//a[@data-ng-bind="cohort.name"]')

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
          wait_for_spinner
          sleep 1
          cohorts = everyone_cohort_link_elements.map { |link| FilteredCohort.new({id: link.attribute('href').gsub("#{BOACUtils.base_url}/cohort/filtered?c=", ''), name: link.text}) }
          cohorts = cohorts.flatten
          logger.info "Visible Everyone's Cohorts are #{cohorts.map &:name}"
          cohorts
        end

        # Navigates to the Inactive Students page
        def load_inactive_students_page
          navigate_to "#{filtered_cohort_base_url}v=true&c=search"
        end

        # Navigates to the Intensive Students page
        def load_intensive_students_page
          navigate_to "#{filtered_cohort_base_url}i=true&c=search"
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

        text_area(:inactive_cbx, id: 'inactive-checkbox')
        text_area(:intensive_cbx, id: 'intensive-checkbox')
        text_area(:my_students_cbx, id: 'advisor-ldap-uid-checkbox')

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

        # Clicks the Inactive checkbox
        def click_inactive
          wait_for_update_and_click inactive_cbx_element
        end

        # Clicks the Intensive checkbox
        def click_intensive
          wait_for_update_and_click intensive_cbx_element
        end

        # Clicks the My Students checkbox
        def click_my_students
          wait_for_update_and_click my_students_cbx_element
        end

        # Verifies that a set of cohort search criteria are currently selected
        # @param search_criteria [CohortFilter]
        # @return [boolean]
        def search_criteria_selected?(search_criteria)
          wait_until(Utils.short_wait) { level_option_elements.any? }
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

        # Waits for a search to complete, returning the spinner duration
        # @return [Float]
        def wait_for_search_results
          time = wait_for_spinner
          results_element.when_present Utils.short_wait
          sleep 1
          time
        end

        # Checks a search filter option
        # @param element [PageObject::Elements::Option]
        def check_search_option(element)
          begin
            tries ||= 2
            wait_for_update_and_click element
            wait_until(1) { element.attribute('class').include?('not-empty') }
          rescue
            logger.debug 'Trying to check a search option again'
            (tries -= 1).zero? ? fail : retry
          end
        end

        # Deselects all search options on a given filter
        # @param filter_button_el [PageObject::Elements::Element]
        # @param option_els [Array<PageObject::Elements::Element>]
        def clear_search_options(filter_button_el, option_els)
          unless option_els.all? &:visible?
            wait_for_update_and_click filter_button_el
            wait_until(1) { option_els.all? &:visible? }
          end
          option_els.each { |o| wait_for_update_and_click(o) if o.attribute('class').include?('not-empty') }
        end

        # Executes a custom cohort search using search criteria associated with a cohort and stores the result count. Optionally writes
        # performance info to a CSV.
        # @param cohort [FilteredCohort]
        # @param csv [CSV]
        def perform_search(cohort, csv = nil)
          criteria = cohort.search_criteria
          logger.info "Searching for squads '#{criteria.squads && (criteria.squads.map &:name)}', levels '#{criteria.levels}', majors '#{criteria.majors}', GPA ranges '#{criteria.gpa_ranges}', units '#{criteria.units}'"
          wait_until(Utils.short_wait) { level_option_elements.any? }
          sleep 3

          # Uncheck any options that are already checked from a previous search, then check those that apply to the current search.
          # Do not look for squad options if the search criteria do not include teams, as non-ASC advisors cannot search by teams.

          # Squads

          if criteria.squads
            clear_search_options(squad_filter_button_element, squad_option_elements)
            criteria.squads.each do |s|
              # The squads list can change over time. Avoid test failures if the search criteria is out of sync with actual squads.
              if squad_option_element(s).exists?
                logger.debug "Selecting #{s.name}"
                check_search_option squad_option_element(s)
              else
                logger.warn "The squad '#{s.name}' is not among the list of squads, removing from search criteria"
                criteria.squads.delete_if { |i| i == s }
              end
            end
          end

          # Levels

          clear_search_options(level_filter_button_element, level_option_elements)
          criteria.levels.each do |l|
            logger.debug "Selecting #{l}"
            check_search_option levels_option_element(l)
          end if criteria.levels

          # Majors

          clear_search_options(major_filter_button_element, major_option_elements)
          if criteria.majors
            # If 'Declared' is selected, then no other majors can be used as search criteria.
            criteria.majors = ['Declared'] if criteria.majors.include? 'Declared'
            # Majors are only shown if they apply to users, so the majors list will change over time. Avoid test failures if
            # the search criteria is out of sync with actual user majors.
            criteria.majors.delete_if { |m| !majors_option_element(m).exists? }
            logger.warn "The majors actually available to select are #{criteria.majors}"
            criteria.majors.each do |m|
              logger.debug "Selecting #{m}"
              check_search_option majors_option_element(m)
            end
          end

          # GPA ranges

          clear_search_options(gpa_range_filter_button_element, gpa_range_option_elements)
          criteria.gpa_ranges.each do |g|
            logger.debug "Selecting #{g}"
            check_search_option gpa_range_option_element(g)
          end if criteria.gpa_ranges

          # Units ranges

          clear_search_options(units_filter_button_element, units_option_elements)
          criteria.units.each do |u|
            logger.debug "Selecting #{u}"
            check_search_option units_option_element(u)
          end if criteria.units

          # Execute search and log time search took to complete
          wait_for_update_and_click search_button_element
          search_wait = wait_for_search_results
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
        # @param search_criteria [CohortFilter]
        # @return [Array<Hash>]
        def expected_search_results(user_data, search_criteria)
          matching_squad_users = (search_criteria.squads && search_criteria.squads.any?) ?
              (user_data.select { |u| (u[:squad_names] & (search_criteria.squads.map { |s| s.name })).any? }) : user_data
          matching_level_users = (search_criteria.levels && search_criteria.levels.any?) ?
              (user_data.select { |u| search_criteria.levels.include?(u[:level]) if u[:level]}) : user_data

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
                if u[:gpa]
                  gpa = u[:gpa].to_f
                  (gpa != 0) && (low_end.to_f <= gpa) && ((high_end == '4.00') ? (gpa <= high_end.to_f.round(1)) : (gpa < high_end.to_f.round(1)))
                end
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
                matching_units_users << user_data.select { |user| user[:units].to_f >= 120 if user[:units] }
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
          span_element(xpath: "//span[text()=\"#{cohort.name}\"]")
        end

        # Returns the element containing the cohort rename button on the Manage Cohorts page
        # @param cohort [Cohort]
        # @return [PageObject::Elements::Button]
        def cohort_rename_button(cohort)
          button_element(xpath: "//span[text()=\"#{cohort.name}\"]/ancestor::div[contains(@class,\"cohort-manage-name\")]/following-sibling::div//button[contains(text(),\"Rename\")]")
        end

        # Returns the element containing the cohort delete button on the Manage Cohorts page
        # @param cohort [Cohort]
        # @return [PageObject::Elements::Button]
        def cohort_delete_button(cohort)
          button_element(xpath: "//span[text()=\"#{cohort.name}\"]/ancestor::div[contains(@class,\"cohort-manage-name\")]/following-sibling::div//button[contains(text(),\"Delete\")]")
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

        # Deletes a cohort unless it is read-only (e.g., CoE default cohorts).
        # @param cohorts [Array<FilteredCohort>]
        # @param cohort [FilteredCohort]
        def delete_cohort(cohorts, cohort)
          if cohort.read_only
            logger.warn "Unable to delete cohort named #{cohort.name} because it is read-only"
          else
            logger.info "Deleting a cohort named #{cohort.name}"
            click_sidebar_manage_filtered
            sleep 3
            wait_for_load_and_click cohort_delete_button(cohort)
            wait_for_update_and_click confirm_delete_button_element
            cohort_on_manage_cohorts(cohort).when_not_present Utils.short_wait
            cohorts.delete cohort
          end
        end

      end
    end
  end
end
