require_relative '../../util/spec_helper'

module BOACListViewPages

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACPagination

  elements(:player_link, :a, xpath: '//a[contains(@href, "/student/")]')
  elements(:player_name, :h3, xpath: '//h3[contains(@class, "student-name")]')
  elements(:player_sid, :span, xpath: '//div[contains(@id, "student-sid")]')

  # Waits for list view results to load
  def wait_for_student_list
    begin
      start_time = Time.now
      sleep 1
      wait_until(Utils.medium_wait) { player_link_elements.any? }
      logger.debug "Took #{Time.now - start_time} seconds for users to appear"
    rescue
      logger.warn 'There are no students listed.'
    end
  end

  # Returns all the names shown on list view
  # @return [Array<String>]
  def list_view_names
    wait_until(Utils.medium_wait) { player_link_elements.any? }
    player_name_elements.map &:text
  end

  # Returns all the SIDs shown on list view
  # @return [Array<String>]
  def list_view_sids
    wait_until(Utils.medium_wait) { player_link_elements.any? }
    sleep Utils.click_wait
    player_sid_elements.map { |el| el.text.split(' ').first }
  end

  # Whether or not an 'ASC INACTIVE' flag is shown for a student
  # @param student [BOACUser]
  # @return [boolean]
  def student_inactive_asc_flag?(student)
    div_element(xpath: "//div[@id='student-#{student.uid}']//div[contains(text(), 'ASC INACTIVE')]").exists?
  end

  # Whether or not a 'CoE INACTIVE' flag is shown for a student
  # @return [boolean]
  def student_inactive_coe_flag?(student)
    div_element(xpath: "//div[@id='student-#{student.uid}']//div[contains(text(), 'CoE INACTIVE')]").exists?
  end

  # Returns the visible sports shown for a student
  # @param student [BOACUser]
  # @return [Array<String>]
  def student_sports(student)
    els = span_elements(xpath: "//div[@id='student-#{student.uid}']//span[contains(@id,\"student-team\")]")
    els && els.map(&:text)
  end

  # Returns all the UIDs shown on list view
  # @return [Array<String>]
  def list_view_uids
    player_link_elements.map { |el| el.attribute('id').gsub("link-to-student-", '') }
  end

  # Returns the sequence of SIDs that are actually present following a search and/or sort
  # @param filtered_cohort [FilteredCohort]
  # @return [Array<String>]
  def visible_sids(filtered_cohort = nil)
    wait_for_student_list unless (filtered_cohort && filtered_cohort.member_data.length.zero?)
    visible_sids = []
    sleep 2
    page_count = list_view_page_count
    page = 1
    if page_count == 1
      logger.debug 'There is 1 page'
      visible_sids << list_view_sids
    else
      logger.debug "There are #{page_count} pages"
      visible_sids << list_view_sids
      (page_count - 1).times do
        start_time = Time.now
        page += 1
        wait_for_update_and_click go_to_next_page_link_element
        wait_until(Utils.medium_wait) { player_link_elements.any? }
        logger.warn "Page #{page} took #{Time.now - start_time} seconds to load" unless page == 1
        visible_sids << list_view_sids
      end
    end
    visible_sids.flatten
  end

  # Waits for students to stop loading on a list view page. Useful for pages that load slowly.
  def wait_for_list_to_load
    wait_until(Utils.short_wait) { player_link_elements.any? }
    begin
      tries ||= Utils.canvas_enrollment_retries
      count = player_link_elements.length
      logger.debug "There are now #{count} students visible"
      scroll_to_bottom
      wait_until(Utils.short_wait) { player_link_elements.length > count }
      logger.info "There are #{player_link_elements.length} students displayed"
    rescue
      (tries -= 1).zero? ? fail : retry
    end
  end

  # Clicks the link for a given student
  # @param student [BOACUser]
  def click_student_link(student)
    logger.info "Clicking the link for UID #{student.uid}"
    wait_for_load_and_click_js link_element(id: "link-to-student-#{student.uid}")
    student_name_heading_element.when_visible Utils.medium_wait
  end

  # Verifies that SIDs are present in the expected sequence. If an SID is not at the expected index, then reports
  # what SID was there instead. If there are any mismatches, will throw an error.
  # @param expected_sids [Array<String>]
  # @param visible_sids [Array<String>]
  def verify_list_view_sorting(expected_sids, visible_sids)
    # Only compare sort order for SIDs that are both expected and visible
    unless expected_sids.sort == visible_sids.sort
      expected_sids.keep_if { |e| visible_sids.include? e }
      visible_sids.keep_if { |v| expected_sids.include? v }
    end

    # Collect any mismatches
    sorting_errors = []
    visible_sids.each do |v|
      e = expected_sids[visible_sids.index v]
      sorting_errors << "Expected #{e}, got #{v}" unless v == e
    end
    wait_until(0.5, "Mismatches: #{sorting_errors}") { sorting_errors.empty? }
  end

  # Verifies that the visible sequence of SIDs matches the expected sequence
  # @param expected_sids [Array<String>]
  def compare_visible_sids_to_expected(expected_sids)
    visible_results = visible_sids
    verify_list_view_sorting(expected_sids, visible_results)
    wait_until(1, "Expected #{expected_sids} but got #{visible_results}") { visible_results == expected_sids }
  end

end
