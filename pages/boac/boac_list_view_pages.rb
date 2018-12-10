require_relative '../../util/spec_helper'

module BOACListViewPages

  include PageObject
  include Logging
  include Page
  include BOACPages

  ### PAGINATION ###

  elements(:page_list_item, :list_item, xpath: '//li[contains(@ng-repeat,"page in pages")]')
  elements(:page_link, :link, xpath: '//a[contains(@ng-click, "selectPage")]')
  elements(:page_ellipsis_link, :link, xpath: '//a[contains(@ng-click, "selectPage")][text()="..."]')
  elements(:results_page_link, :class => 'pagination-page')

  # Returns the page link element for a given page number
  # @param number [Integer]
  # @return [PageObject::Elements::Link]
  def list_view_page_link(number)
    link_element(xpath: "//a[contains(@ng-click, 'selectPage')][text()='#{number}']")
  end

  # Returns the number of list view pages shown
  # @return [Integer]
  def list_view_page_count
    results_page_link_elements.any? ? results_page_link_elements.last.text.to_i : 1
  end

  # Returns the current page in list view
  # @return [Integer]
  def list_view_current_page
    if page_list_item_elements.any?
      page = page_list_item_elements.find { |el| el.attribute('class').include? 'active' }
      page.text.to_i
    else
      1
    end
  end

  # Checks whether a given page is the one currently shown in list view
  # @param number [Integer]
  # @return [boolean]
  def list_view_page_selected?(number)
    if number > 1
      wait_until(Utils.short_wait) { page_list_item_elements.any? }
      logger.debug "The page numbers visible are #{page_list_item_elements.map &:text}"
      el = page_list_item_elements.find { |el| el.text == number.to_s }
      el.attribute('class').include? 'active'
    else
      page_list_item_elements.empty?
    end
  end

  # Clicks a given page number and waits for student rows to appear
  # @param number [Integer]
  def click_list_view_page(number)
    logger.debug "Clicking page #{number}"
    list_view_page_link(number).exists? ?
        (wait_for_update_and_click list_view_page_link(number)) :
        (wait_for_update_and_click page_ellipsis_link_elements.last)
    sleep 1
    wait_until(Utils.medium_wait) { player_link_elements.any? }
  end

  ### SETS OF USERS ###

  elements(:player_link, :link, xpath: '//a[contains(@href,"/student/")]')
  elements(:player_name, :h3, xpath: '//h3[contains(@class,"student-name")]')
  elements(:player_sid, :div, xpath: '//div[@class="student-sid ng-binding"]')

  # Waits for list view results to load
  def wait_for_student_list
    begin
      start_time = Time.now
      wait_until(Utils.medium_wait) { list_view_sids.any? }
      logger.debug "Took #{Time.now - start_time} seconds for users to appear"
      sleep 1
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
    player_sid_elements.map { |el| el.text.gsub(/(INACTIVE)/, '').gsub(/(WAITLISTED)/, '').strip }
  end

  # Returns all the UIDs shown on list view
  # @return [Array<String>]
  def list_view_uids
    player_link_elements.map { |el| el.attribute 'id' }
  end

  # Returns the sequence of SIDs that are actually present following a search and/or sort
  # @param filtered_cohort [FilteredCohort]
  # @return [Array<String>]
  def visible_sids(filtered_cohort = nil)
    wait_for_student_list unless (filtered_cohort && filtered_cohort.member_count.zero?)
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
        click_list_view_page page
        logger.warn "Page #{page} took #{Time.now - start_time} seconds to load" unless page == 1
        visible_sids << list_view_sids
      end
    end
    visible_sids.flatten
  end

  # Clicks the link for a given student
  # @param student [BOACUser]
  def click_student_link(student)
    logger.info "Clicking the link for UID #{student.uid}"
    wait_for_load_and_click link_element(xpath: "//a[@id=\"#{student.uid}\"]")
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

end
