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
            navigate_to("#{filtered_cohort_base_url}id=#{cohort.id}")
            wait_for_title cohort.name
          end
        end

        # Loads a cohort directly in matrix view
        # @param cohort [FilteredCohort]
        def load_cohort_matrix(cohort)
          logger.info "Loading cohort '#{cohort.name}' ID #{cohort.id} in matrix view"
          cohort.instance_of?(Team) ?
              navigate_to("#{filtered_cohort_base_url}c=#{cohort.code}&tab=matrix") :
              navigate_to("#{filtered_cohort_base_url}id=#{cohort.id}&tab=matrix")
          wait_for_title cohort.name
        end

        # Hits a cohort URL and expects the 404 page to load
        # @param cohort [FilteredCohort]
        def hit_non_auth_cohort(cohort)
          navigate_to "#{filtered_cohort_base_url}id=#{cohort.id}"
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

        button(:save_cohort_button_one, id: 'save-filtered-cohort')
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

        # Combines methods to load the create filtered cohort page, perform a search, and create a filtered cohort
        # @param cohort [FilteredCohort]
        def search_and_create_new_cohort(cohort)
          click_sidebar_create_filtered
          perform_search cohort
          create_new_cohort cohort
        end

        # Creates a new cohort by editing the search criteria of an existing one
        # @param old_cohort [FilteredCohort]
        # @param new_cohort [FilteredCohort]
        def search_and_create_edited_cohort(old_cohort, new_cohort)
          load_cohort old_cohort
          show_filters
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
          wait_until(Utils.short_wait) { everyone_cohort_link_elements.any? }
          cohorts = everyone_cohort_link_elements.map { |link| FilteredCohort.new({id: link.attribute('href').gsub("#{BOACUtils.base_url}/cohort/filtered?id=", ''), name: link.text}) }
          cohorts = cohorts.flatten
          logger.info "Visible Everyone's Cohorts are #{cohorts.map &:name}"
          cohorts
        end

        # Navigates to the Inactive Students page
        def load_inactive_students_page
          navigate_to "#{filtered_cohort_base_url}inactive"
        end

        # Navigates to the Intensive Students page
        def load_intensive_students_page
          navigate_to "#{filtered_cohort_base_url}intensive"
        end

        # FILTERED COHORTS - Search

        button(:show_filters_button, id: 'show-hide-details-button')
        button(:rename_button, id: 'rename-cohort-button')
        button(:delete_button, id: 'delete-cohort-button')

        button(:new_filter_button, id: 'draft-filter')
        button(:new_filter_sub_button, id: 'filter-subcategory')
        elements(:new_filter_option, :link, xpath: '//a[@data-ng-bind="option.name"]')
        button(:unsaved_filter_add_button, id: 'unsaved-filter-add')
        button(:unsaved_filter_cancel_button, id: 'unsaved-filter-reset')
        button(:unsaved_filter_apply_button, id: 'unsaved-filter-apply')
        button(:save_cohort_button, id: 'unsaved-filter-save-cohort')

        elements(:filter_row_type, :span, xpath: '//div[@class="cohort-filter-item-filter"]/span')
        elements(:filter_row_option, :span, xpath: '//div[@class="cohort-filter-item-name"]/span')
        button(:filter_row_remove_button, xpath: '//button[contains(@id,"remove-added-filter")]')

        # Returns the element containing an added cohort filter
        # @param filter_option [String]
        # @return [PageObject::Elements::Span]
        def existing_filter(filter_option)
          span_element(xpath: "//div[@class=\"cohort-filter-item-name\"]/span[text()=\"#{filter_option}\"]")
        end

        # Returns a filter option link with given text, used to find options other than 'Advisor'
        # @param option_name [String]
        # @return [PageObject::Elements::Link]
        def new_filter_option(option_name)
          link_element(xpath: "//a[text()=\"#{option_name}\"]")
        end

        # Returns a filter sub-option link with given text
        # @param option_name [String]
        # @return [PageObject::Elements::Link]
        def new_filter_sub_option(option_name)
          link_element(id: "cohort-filter-subcategory-#{option_name}")
        end

        # Returns a filter option list item with given text, used to find 'Advisor' options
        # @param advisor_uid [String]
        # @return [PageObject::Elements::ListItem]
        def new_filter_advisor_option(advisor_uid)
          list_item_element(id: "advisorLdapUids-#{advisor_uid}")
        end

        # Selects, adds, and applies a filter
        # @param filter_name [String]
        # @param filter_option [String]
        def select_filter(filter_name, filter_option = nil)
          logger.info "Selecting #{filter_name} #{filter_option}"
          wait_for_update_and_click new_filter_button_element
          wait_for_update_and_click new_filter_option(filter_name)

          # Inactive and Intensive have no sub-options
          if %w(Inactive Intensive).include? filter_name
            wait_for_update_and_click unsaved_filter_add_button_element
            unsaved_filter_apply_button_element.when_present Utils.short_wait

          # All other filters have sub-options
          else
            wait_for_update_and_click new_filter_sub_button_element
            option_element = (filter_name == 'Advisor') ? new_filter_advisor_option(filter_option) : new_filter_sub_option(filter_option)
            wait_for_update_and_click option_element
            wait_for_update_and_click unsaved_filter_add_button_element
            unsaved_filter_apply_button_element.when_present Utils.short_wait
          end
        end

        # Returns the heading for a given cohort page
        # @param cohort [FilteredCohort]
        # @return [PageObject::Elements::Span]
        def cohort_heading(cohort)
          span_element(xpath: "//h1/span[text()=\"#{cohort.name}\"]")
        end

        # Ensures that cohort filters are visible
        def show_filters
          div_element(class: 'cohort-header-button-links').when_visible Utils.medium_wait
          show_filters_button if show_filters_button?
        end

        # Verifies that a set of cohort search criteria are currently selected
        # @param filter [CohortFilter]
        # @return [boolean]
        def filters_selected?(filter)
          wait_until(Utils.short_wait) { filter_row_type_elements.any? }
          filter.gpa_ranges.each { |g| wait_until(1, "GPA range #{g} is not selected") { existing_filter(g).exists? } } if filter.gpa_ranges
          filter.levels.each { |l| wait_until(1, "Level #{l} is not selected") { existing_filter(l).exists? } } if filter.levels
          filter.units.each { |u| wait_until(1, "Units #{u} is not selected") { existing_filter(u).exists? } } if filter.units
          filter.majors.each { |m| wait_until(1, "Major #{m} is not selected") { existing_filter(m).exists? } } if filter.majors
          filter.squads.each { |s| wait_until(1, "Squad #{s.name} is not selected") { existing_filter(s).exists? } } if filter.squads
          # TODO - remaining filter types
          true
        end

        # Removes all existing filters on a cohort or cohort search
        def remove_all_filters
          filter_count = filter_row_type_elements.length
          logger.info "Removing #{filter_count} existing filters"
          filter_count.times do
            wait_for_update_and_click filter_row_remove_button_element
            wait_until(2) { filter_row_type_elements.length == filter_count - 1 }
            filter_count -= 1
          end
        end

        # Waits for a search to complete and returns the count of results.
        # @return [Integer]
        def wait_for_search_results
          wait_for_spinner
          results_count
        end

        # Executes a custom cohort search using search criteria associated with a cohort and stores the result count
        # @param cohort [FilteredCohort]
        def perform_search(cohort)
          sleep 1
          remove_all_filters

          # The squads and majors lists can change over time. Avoid test failures if the search criteria is out of sync
          # with actual squads or majors. Advisors might also change, but fail if this happens for now.
          if cohort.search_criteria.majors && cohort.search_criteria.majors.any?
            wait_for_update_and_click new_filter_button_element
            wait_for_update_and_click new_filter_option('Major')
            wait_for_update_and_click new_filter_sub_button_element
            sleep Utils.click_wait
            filters_missing = []
            cohort.search_criteria.majors.each { |major| filters_missing << major unless new_filter_option(major).exists? }
            logger.debug "The majors #{filters_missing} are not present, removing from search criteria" if filters_missing.any?
            filters_missing.each { |f| cohort.search_criteria.majors.delete f }
            wait_for_update_and_click unsaved_filter_cancel_button_element
          end
          if cohort.search_criteria.squads && cohort.search_criteria.squads.any?
            wait_for_update_and_click new_filter_button_element
            wait_for_update_and_click new_filter_option('Team')
            wait_for_update_and_click new_filter_sub_button_element
            sleep Utils.click_wait
            filters_missing = []
            cohort.search_criteria.squads.each { |squad| filters_missing << squad unless new_filter_option(squad.name).exists? }
            logger.debug "The squads #{filters_missing} are not present, removing from search criteria" if filters_missing.any?
            filters_missing.each { |f| cohort.search_criteria.squads.delete f }
            wait_for_update_and_click unsaved_filter_cancel_button_element
          end

          # Global
          cohort.search_criteria.gpa_ranges.each { |g| select_filter('GPA', g) } if cohort.search_criteria.gpa_ranges
          cohort.search_criteria.levels.each { |l| select_filter('Level', l) } if cohort.search_criteria.levels
          cohort.search_criteria.units.each { |u| select_filter('Units Completed', u) } if cohort.search_criteria.units
          cohort.search_criteria.majors.each { |m| select_filter('Major', m) } if cohort.search_criteria.majors

          # CoE
          cohort.search_criteria.advisors.each { |a| select_filter('Advisor', a) } if cohort.search_criteria.advisors
          cohort.search_criteria.ethnicities.each { |e| select_filter('Ethnicity', e) } if cohort.search_criteria.ethnicities
          cohort.search_criteria.genders.each { |g| select_filter('Gender', g) } if cohort.search_criteria.genders
          cohort.search_criteria.preps.each { |p| select_filter('PREP', p) } if cohort.search_criteria.preps

          # ASC
          select_filter('Inactive', cohort.search_criteria) if cohort.search_criteria.inactive_asc
          select_filter('Intensive', cohort.search_criteria) if cohort.search_criteria.intensive_asc
          cohort.search_criteria.squads.each { |s| select_filter('Team', s.name) } if cohort.search_criteria.squads

          # If there are any search criteria left, execute search and log time search took to complete
          if cohort.search_criteria.list_filters.flatten.compact.any?
            wait_for_update_and_click unsaved_filter_apply_button_element
            cohort.member_count = wait_for_search_results
            logger.warn "No results found for #{cohort.search_criteria.list_filters}" if cohort.member_count.zero?
          # If no search criteria remain, do not try to search
          else
            logger.warn 'None of the search criteria are available in the UI'
            cohort.member_count = 0
          end
        end

        # Filters an array of user data hashes according to search criteria and returns the users that should be present in the UI after
        # the search completes
        # @param user_data [Array<Hash>]
        # @param search_criteria [CohortFilter]
        # @return [Array<Hash>]
        def expected_search_results(user_data, search_criteria)

          # GPA
          matching_gpa_users = []
          if search_criteria.gpa_ranges && search_criteria.gpa_ranges.any?
            search_criteria.gpa_ranges.each do |range|
              array = range.include?('Below') ? %w(0 2.0) : range.delete(' ').split('-')
              low_end = array[0]
              high_end = array[1]
              matching_gpa_users << user_data.select do |u|
                if u[:gpa]
                  gpa = u[:gpa].to_f
                  (gpa != 0) && (low_end.to_f <= gpa) && ((high_end == '4.00') ? (gpa <= high_end.to_f.round(1)) : (gpa < high_end.to_f.round(1)))
                end
              end
            end
          else
            matching_gpa_users = user_data
          end
          matching_gpa_users.flatten!

          # Level
          matching_level_users = if search_criteria.levels && search_criteria.levels.any?
                                   user_data.select do |u|
                                     search_criteria.levels.find { |search_level| search_level.include? u[:level] } if u[:level]
                                   end
                                 else
                                   user_data
                                 end

          # Units
          matching_units_users = []
          if search_criteria.units
            search_criteria.units.each do |units|
              if units.include?('+')
                matching_units_users << user_data.select { |u| u[:units].to_f >= 120 if u[:units] }
              else
                range = units.split(' - ')
                low_end = range[0].to_f
                high_end = range[1].to_f
                matching_units_users << user_data.select { |u| (u[:units].to_f >= low_end) && (u[:units].to_f < high_end.round(-1)) }
              end
            end
          else
            matching_units_users = user_data
          end
          matching_units_users.flatten!

          # Major
          matching_major_users = []
          (search_criteria.majors && search_criteria.majors.any?) ?
              (matching_major_users << user_data.select { |u| (u[:majors] & search_criteria.majors).any? }) :
              (matching_major_users = user_data)
          matching_major_users = matching_major_users.uniq.flatten.compact

          # Advisor
          matching_advisor_users = (search_criteria.advisors && search_criteria.advisors.any?) ?
              (user_data.select { |u| search_criteria.advisors.include? u[:advisor] }) : user_data

          # Ethnicity
          matching_ethnicity_users = []
          if search_criteria.ethnicities && search_criteria.ethnicities.any?
            search_criteria.ethnicities.each do |ethnicity|
              matching_ethnicity_users << user_data.select { |u| search_criteria.coe_ethnicity(u[:ethnicity]) == ethnicity }
            end
          else
            matching_ethnicity_users = user_data
          end
          matching_ethnicity_users.flatten!

          # Gender
          matching_gender_users = []
          if search_criteria.genders && search_criteria.genders.any?
            search_criteria.genders.each do |gender|
              if gender == 'Male'
                matching_gender_users << user_data.select { |u| u[:gender] == 'm' }
              elsif gender == 'Female'
                matching_gender_users << user_data.select { |u| u[:gender] == 'f' }
              end
            end
          else
            matching_gender_users = user_data
          end
          matching_gender_users.flatten!

          # PREP
          matching_preps_users = []
          if search_criteria.preps && search_criteria.preps.any?
            search_criteria.preps.each do |prep|
              matching_preps_users << user_data.select { |u| u[:prep] } if prep == 'PREP'
              matching_preps_users << user_data.select { |u| u[:prep_elig] } if prep == 'PREP eligible'
              matching_preps_users << user_data.select { |u| u[:t_prep] } if prep == 'T-PREP'
              matching_preps_users << user_data.select { |u| u[:t_prep_elig] } if prep == 'T-PREP eligible'
            end
          else
            matching_preps_users = user_data
          end
          matching_preps_users.flatten!

          # Inactive
          matching_inactive_users = search_criteria.inactive_asc ? (user_data.select { |u| u[:inactive_asc] }) : user_data

          # Intensive
          matching_intensive_users = search_criteria.intensive_asc ? (user_data.select { |u| u[:intensive_asc] }) : user_data

          # Team
          matching_squad_users = (search_criteria.squads && search_criteria.squads.any?) ?
              (user_data.select { |u| (u[:squad_names] & (search_criteria.squads.map { |s| s.name })).any? }) :
              user_data

          matches = [matching_gpa_users, matching_level_users, matching_units_users, matching_major_users, matching_advisor_users, matching_ethnicity_users,
                     matching_gender_users, matching_preps_users, matching_inactive_users, matching_intensive_users, matching_squad_users]
          matches.any?(&:empty?) ? [] : matches.inject(:'&')
        end

        # FILTERED COHORTS - Management

        elements(:cohort_name, :span, xpath: '//span[@data-ng-bind="cohort.name"]')
        button(:rename_cohort_button, id: 'rename-cohort-button')
        text_area(:rename_cohort_input, id: 'rename-cohort-input')
        button(:rename_cohort_confirm_button, id: 'filtered-cohort-rename')
        button(:rename_cohort_cancel_button, id: 'filtered-cohort-rename-cancel')
        button(:delete_cohort_button, id: 'delete-cohort-button')

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
          cohort_on_manage_cohorts(cohort).when_present Utils.short_wait
        end

        # Deletes a cohort unless it is read-only (e.g., CoE default cohorts).
        # @param cohort [FilteredCohort]
        def delete_cohort(cohort)
          logger.info "Deleting a cohort named #{cohort.name}"
          load_cohort cohort
          wait_for_load_and_click delete_cohort_button_element
          wait_for_update_and_click confirm_delete_button_element
          wait_until(Utils.short_wait) { current_url == "#{BOACUtils.base_url}/home" }
          sleep 1
        end

      end
    end
  end
end
