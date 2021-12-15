require_relative '../../util/spec_helper'

class BOACFilteredStudentsHistoryPage

  include PageObject
  include Page
  include BOACPages
  include BOACPagination
  include Logging

  button(:back_to_cohort_button, xpath: '//button[contains(text(), "Back to Cohort")]')
  div(:no_history_msg, id: 'cohort-history-no-events')
  elements(:history_row, :row, xpath: '//table[@id="cohort-history-table"]/tbody/tr')

  # Waits for list view results to load
  def wait_for_history
    start_time = Time.now
    sleep 1
    wait_until(Utils.medium_wait) { history_row_elements.any? }
    logger.debug "Took #{Time.now - start_time} seconds for history rows to appear"
  rescue
    logger.warn 'There are no history rows'
  end

  # Returns an array of hashes containing the visible data on each history row on a single page of results
  # @return [Array<Hash>]
  def visible_row_data
    rows = history_row_elements
    rows.map do |row|
      i = rows.index row
      status_el = div_element(id: "event-#{i}-status")
      date_el = div_element(id: "event-#{i}-date")
      name_el = link_element(id: "event-#{i}-student-name")
      sid_el = div_element(id: "event-#{i}-sid")
      {
        status: (status_el.text.strip if status_el.exists?),
        date: (date_el.text if date_el.exists?),
        name: (name_el.text if name_el.exists?),
        sid: (sid_el.text if sid_el.exists?)
      }
    end
  end

  # Returns an array of hashes containing the visible data on each history row on all pages of results
  # @return [Array<Hash>]
  def visible_history_entries
    wait_for_history
    visible_entries = []
    sleep 1
    page_count = list_view_page_count
    page = 1
    if page_count == 1
      logger.debug 'There is 1 page'
      visible_entries << visible_row_data
    else
      logger.debug "There are #{page_count} pages"
      visible_entries << visible_row_data
      (page_count - 1).times do
        start_time = Time.now
        page += 1
        wait_for_update_and_click go_to_next_page_link_element
        wait_until(Utils.medium_wait) { wait_for_history }
        logger.warn "Page #{page} took #{Time.now - start_time} seconds to load" unless page == 1
        visible_entries << visible_row_data
      end
    end
    visible_entries.flatten.sort_by { |h| [h[:sid], h[:status]] }
  end

  # Returns an array of hashes containing the expected history data for a given set of students with a given status and time
  # @param students [Array<BOACUser>]
  # @param status [String]
  # @param time [Time]
  # @return [Array<Hash>]
  def expected_history_entries(students, status, time)
    hashes = students.map do |student|
      {
        status: status,
        date: time.strftime('%b %-d, %Y'),
        name: "#{student.last_name}, #{student.first_name}",
        sid: "#{student.sis_id}"
      }
    end
    hashes.sort_by { |h| h[:sid] }
  end

  # Clicks the back-to-cohort button
  def click_back_to_cohort
    logger.info 'Clicking back-to-cohort button'
    wait_for_update_and_click back_to_cohort_button_element
  end

end
