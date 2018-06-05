require_relative '../../util/spec_helper'

module Page

  module BOACPages

    module CohortPages

      class CuratedCohortPage

        include PageObject
        include Logging
        include Page
        include BOACPages
        include CohortPages

        # Loads a curated cohort
        # @param cohort [CuratedCohort]
        def load_page(cohort)
          navigate_to "#{BOACUtils.base_url}/group/#{cohort.id}"
        end

        span(:title_required_msg, xpath: '//span[text()="Required"]')
        span(:cohort_not_found_msg, xpath: '//span[contains(.,"No cohort found with identifier: ")]')

        # Returns the error message element shown when a user attempts to view a curated cohort it does not own
        # @param user [User]
        # @param cohort [CuratedCohort]
        def no_cohort_access_msg(user, cohort)
          span_element(xpath: "//span[text()='Current user, #{user.uid}, does not own cohort #{cohort.id}']")
        end

        # Curated cohort management

        link(:manage_create_first_curated_link, xpath: '//a[contains(.,"Create a new curated cohort")]')
        elements(:curated_name, :link, xpath: '//a[contains(@id,"curated-cohort-name")]')
        elements(:curated_rename_input, :text_area, name: 'label')
        elements(:curated_rename_save_button, :button, xpath: '//button[contains(@id,"curated-cohort-save-btn")]')

        # Creates a curated cohort using the 'Create a new curated cohort' link on the Manage Curated Cohorts page, shown when no curated cohorts exist
        # @param cohort [CuratedCohort]
        def manage_create_first_curated(cohort)
          sleep 1
          wait_for_load_and_click manage_create_first_curated_link_element
          name_and_save_curated_cohort cohort
          wait_for_sidebar_curated cohort
        end

        # Returns the element containing the cohort name on the Manage Cohorts page
        # @param cohort [Cohort]
        # @return [PageObject::Elements::Link]
        def cohort_on_manage_curated(cohort)
          link_element(text: cohort.name)
        end

        # Returns the element containing the cohort rename button on the Manage Curated Cohorts page
        # @param cohort [Cohort]
        # @return [PageObject::Elements::Button]
        def curated_rename_button(cohort)
          button_element(xpath: "//span[text()=\"#{cohort.name}\"]/ancestor::div[contains(@class,\"cohort-manage-name\")]/following-sibling::div//button[contains(text(),\"Rename\")]")
        end

        # Returns the element containing the cohort delete button on the Manage Curated Cohorts page
        # @param cohort [Cohort]
        # @return [PageObject::Elements::Button]
        def curated_delete_button(cohort)
          button_element(xpath: "//span[text()=\"#{cohort.name}\"]/ancestor::div[contains(@class,\"cohort-manage-name\")]/following-sibling::div//button[contains(text(),\"Delete\")]")
        end

        # Renames a curated cohort
        # @param cohort [CuratedCohort]
        # @param new_name [String]
        def rename_curated(cohort, new_name)
          logger.info "Changing the name of curated cohort ID #{cohort.id} to #{new_name}"
          sidebar_click_manage_curated
          wait_until(Utils.short_wait) { curated_name_elements.map(&:text).include? cohort.name }
          wait_for_load_and_click curated_rename_button(cohort)
          cohort.name = new_name
          wait_until(Utils.short_wait) { curated_rename_input_elements.any? }
          wait_for_element_and_type(curated_rename_input_elements.first, new_name)
          wait_for_update_and_click curated_rename_save_button_elements.first
          cohort_on_manage_curated(cohort).when_present Utils.short_wait
        end

        # Deletes a curated cohort
        # @param cohort [CuratedCohort]
        def delete_curated(cohort)
          logger.info "Deleting a curated cohort named #{cohort.name}"
          sleep Utils.click_wait
          sidebar_click_manage_curated
          sleep 3
          wait_for_load_and_click curated_delete_button(cohort)
          wait_for_update_and_click confirm_delete_button_element
          modal_element.when_not_present Utils.short_wait
        end

      end
    end
  end
end
