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
      button(:confirm_delete_button, id: 'confirm-delete-btn')
      button(:cancel_delete_button, id: 'cancel-delete-btn')

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

    end
  end
end
