require_relative '../../util/spec_helper'

module Page

  module BOACPages

    class CohortMatrixPage < CohortPage

      include Logging
      include PageObject
      include Page
      include BOACPages

      div(:matrix, id: 'scatterplot')
      elements(:missing_data_link, :link, xpath: '//a[contains(@data-ng-repeat,"student in studentsWithoutData")]')
      elements(:missing_data_image, :image, xpath: '//h4[text()="Missing Student Data"]/following-sibling::ul//img')

      # Waits for the matrix graphic to appear and pauses briefly to allow bubbles to start forming
      def wait_for_matrix
        matrix_element.when_visible Utils.medium_wait
        sleep 1
      end

      # Returns the bubble elements in the matrix graphic
      # @param driver [Selenium::WebDriver]
      # @return [Array<Selenium::WebDriver::Element>]
      def matrix_bubbles(driver)
        wait_for_matrix
        driver.find_elements(xpath: '//*[name()="svg"][@class="matrix-svg"]/*[name()="svg"]//*[name()="circle"]')
      end

      # Returns the UIDs of the users in matrix bubbles
      # @param driver [Selenium::WebDriver]
      # @return [Array<String>]
      def visible_matrix_uids(driver)
        wait_for_matrix
        els = driver.find_elements(xpath: '//*[name()="svg"][@class="matrix-svg"]/*[name()="defs"]/*[name()="pattern"]')
        els.any? ? (els.map { |el| el.attribute('id').delete('avatar_') }) : []
      end

      # Returns the UIDs of the users in the 'no data' list
      # @return [Array<String>]
      def visible_no_data_uids
        wait_for_matrix
        missing_data_image_elements.any? ? (missing_data_image_elements.map { |el| el.attribute('data-ng-src').delete('/apiuserphoto') }) : []
      end

      # Clicks the last user bubble in the matrix graphic
      # @param [Selenium::WebDriver]
      def click_last_student_bubble(driver)
        logger.info 'Clicking student bubble'
        matrix_bubbles(driver).last.click
        student_name_heading_element.when_visible Utils.medium_wait
      end

      # Clicks the last user in the 'no data' list
      def click_last_no_data_student
        logger.info 'Clicking missing data student'
        missing_data_link_elements.last.click
        student_name_heading_element.when_visible Utils.medium_wait
      end

    end
  end
end
