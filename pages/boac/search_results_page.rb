require_relative '../../util/spec_helper'

module Page

  module BOACPages

    class SearchResultsPage

      include PageObject
      include Logging
      include Page
      include BOACPages

      span(:results_count, xpath: '//span[@count="search.totalStudentCount"]')
      elements(:student_row, :div, xpath: '//div[contains(@data-ng-repeat,"student in students")]')
      elements(:student_row_sid, :div, xpath: '//div[contains(@data-ng-repeat,"student in students")]//span[@data-ng-bind="student.sid"]')

      # Performs a search and returns the number of results
      # @param string [String]
      # @return [Integer]
      def search(string)
        enter_search_string string
        wait_for_spinner
        results_count_element.when_visible Utils.short_wait
        count = results_count.include?('One') ? 1 : results_count.split(' ').first.to_i
        logger.debug "Results count: #{count}"
        count
      end

      # Returns all the SIDs displayed on the page
      # @return [Array<String>]
      def student_row_sids
        student_row_sid_elements.map &:text
      end

      # Checks if a given student is among search results. If more than 50 results exist, the student could be among them
      # but not displayed. In that case, returns true without further tests.
      # @param driver [Selenium::WebDriver]
      # @param student [User]
      # @param result_count [Integer]
      # @return [boolean]
      def student_in_search_result?(driver, student, result_count)
        verify_block do
          if result_count > 50
            wait_until(2) { student_row_elements.length == 50 }
            logger.warn "Skipping a test with UID #{student.uid} because there are more than 50 results"
            sleep 1
          else
            wait_until(Utils.medium_wait) do
              student_row_elements.length == result_count
              student_row_sids.include? student.sis_id.to_s
            end
            visible_row_data = user_row_data(driver, student)
            wait_until(2, "Expecting name #{student.last_name}, #{student.first_name}, got #{visible_row_data[:name]}") { visible_row_data[:name] == "#{student.last_name}, #{student.first_name}" }
            wait_until(2) { ![visible_row_data[:major], visible_row_data[:units_in_progress], visible_row_data[:cumulative_units], visible_row_data[:gpa], visible_row_data[:alert_count]].any?(&:empty?) }
          end
        end
      end

      # Clicks the search results row for a given student
      # @param student [User]
      def click_student_result(student)
        wait_for_update_and_click div_element(xpath: "//div[contains(@class,'group-summary-row')][contains(.,'#{student.sis_id}')]//a")
        wait_for_spinner
      end

    end
  end
end
