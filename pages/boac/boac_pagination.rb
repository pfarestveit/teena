require_relative '../../util/spec_helper'

module BOACPagination

  include PageObject
  include Logging
  include Page
  include BOACPages

  link(:page_one_link, xpath: '//button[@aria-label="Go to page 1"]')
  link(:go_to_first_page_link, xpath: '//button[@aria-label="Go to first page"]')
  link(:go_to_next_page_link, xpath: '//button[@aria-label="Go to next page"]')
  link(:go_to_last_page_link, xpath: '//button[@aria-label="Go to last page"]')
  elements(:go_to_page_link, :link, xpath: '//button[contains(@aria-label,"Go to page")]')

  # Clicks the go-to-first-page link and waits till page one is loaded
  def go_to_first_page
    wait_for_update_and_click go_to_first_page_link_element if go_to_first_page_link?
    page_one_link_element.when_visible Utils.short_wait
    wait_until(Utils.short_wait) { page_one_link_element.attribute('aria-checked') }
  end

  # Returns the number of list view pages shown
  # @return [Integer]
  def list_view_page_count
    if go_to_last_page_link?
      wait_for_update_and_click go_to_last_page_link_element
      sleep 1
      wait_until(Utils.short_wait) { go_to_page_link_elements.any? }
      count = go_to_page_link_elements.last.text.to_i
      go_to_first_page
      count
    elsif go_to_page_link_elements.any?
      go_to_page_link_elements.length
    else
      1
    end
  end

end
