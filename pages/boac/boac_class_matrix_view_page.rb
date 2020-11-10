require_relative '../../util/spec_helper'

class BOACClassMatrixViewPage

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACClassPages

  # Loads a class page in matrix view
  # @param term_id [String]
  # @param ccn [String]
  def load_matrix_view(term_id, ccn)
    logger.info "Loading matrix view of term #{term_id} section #{ccn}"
    navigate_to "#{BOACUtils.base_url}/course/#{term_id}/#{ccn}?tab=matrix"
    wait_for_matrix
  end

  div(:matrix, id: 'scatterplot')
  elements(:missing_data_link, :link, xpath: '//table[@class="missing-student-data-table"]//a[contains(@href,"/student/")]')
  elements(:missing_data_row, :image, xpath: '//table[@class="missing-student-data-table"]//tr[contains(@class,"cohort-missing-student-data-row")]')

  # Waits for the matrix graphic to appear and pauses briefly to allow bubbles to start forming
  def wait_for_matrix
    wait_for_spinner
    start = Time.now
    matrix_element.when_visible Utils.medium_wait
    logger.debug "Matrix scatterplot took #{Time.now - start} seconds to appear"
    sleep 2
  end

  # Returns the bubble elements in the matrix graphic
  # @return [Array<Element>]
  def matrix_bubbles
    bubbles = div_elements(xpath: '//*[name()="svg"][@class="matrix-svg"]/*[name()="svg"]//*[name()="circle"]')
    # Don't count the 'average student' bubble
    bubbles.delete_if { |b| b.attribute('style').include? 'avatar_undefined' }
    bubbles
  end

  # Returns the number of matrix bubbles, subtracting the 'average' bubble
  # @return [Integer]
  def matrix_bubble_count
    matrix_bubbles.length
  end

  # Whether or not a given student's bubble is expanded
  # @param student [BOACUser]
  # @return [Boolean]
  def bubble_expanded?(student)
    sleep 1
    h4_element(xpath: "//h4[text()='#{student.full_name}']").visible?
  end

  # Returns the UIDs of the users in the 'no data' list
  # @return [Array<String>]
  def visible_no_data_uids
    missing_data_row_elements.any? ? (missing_data_row_elements.map { |el| el.attribute('id') }) : []
  end

  # Checks whether or not all the list view students are appearing on the matrix view
  # @param expected_count [Integer]
  # @return [boolean]
  def verify_all_students_present(expected_count)
    verify_block do
      wait_until(Utils.short_wait, "Got #{matrix_bubble_count} bubbles and #{visible_no_data_uids.length} rows but expected #{expected_count} total") do
        matrix_bubble_count + visible_no_data_uids.length == expected_count
      end
    end
  end

  # Clicks the last user bubble in the matrix graphic
  def click_last_student_bubble
    mouseover(matrix_bubbles.last)
    uid = div_elements(xpath: '//*[name()="svg"][@class="matrix-svg"]/*[name()="defs"]/*[name()="pattern"]').last.attribute('id').gsub('avatar_', '')
    logger.info "Clicking student bubble for UID #{uid}"
    matrix_bubbles.last.click
    student_name_heading_element.when_visible Utils.medium_wait
  end

  # Clicks the last user in the 'no data' list
  def click_last_no_data_student
    logger.info 'Clicking missing data student'
    missing_data_link_elements.last.click
    student_name_heading_element.when_visible Utils.medium_wait
  end

end
