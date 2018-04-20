require_relative '../../util/spec_helper'

module Page

  module BOACPages

    module CohortPages

      include PageObject
      include Logging
      include Page
      include BOACPages

      button(:list_view_button, xpath: '//button[contains(.,"List")]')
      button(:matrix_view_button, xpath: '//button[contains(.,"Matrix")]')
      h1(:results, xpath: '//h1')

      # Clicks the list view button
      def click_list_view
        logger.info 'Switching to list view'
        wait_for_load_and_click list_view_button_element
      end

      # Clicks the matrix view button
      def click_matrix_view
        logger.info 'Switching to matrix view'
        wait_for_load_and_click matrix_view_button_element
        div_element(id: 'scatterplot').when_present Utils.medium_wait
      end

      # Returns the search results count in the page heading
      # @return [Integer]
      def results_count
        sleep 1
        results.split(' ')[0].to_i
      end

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

    end
  end
end
