require_relative '../util/spec_helper'

module Page

  include PageObject
  include Logging

  # Switches browser focus into the Canvas LTI tool iframe
  # @param driver [Selenium::WebDriver]
  def switch_to_canvas_iframe(driver)
    wait_until { driver.find_element(id: 'tool_content') }
    driver.switch_to.frame driver.find_element(id: 'tool_content')
  end

  # Waits for an element to exist and to become visible
  # @param element [PageObject::Elements::Element]
  # @param timeout [Fixnum]
  def wait_for_element(element, timeout)
    element.when_present timeout
    element.when_visible timeout
  end

  # Waits for an element to appear then clicks it
  # @param element [PageObject::Elements::Element]
  # @param timeout [Fixnum]
  def click_element(element, timeout)
    wait_for_element(element, timeout)
    element.click
  end

  # Awaits an element for a short time then clicks it. Intended for DOM updates rather than page loads.
  # @param element [PageObject::Elements::Element]
  def wait_for_page_update_and_click(element)
    click_element(element, Utils.short_wait)
  end

  # Awaits an element for a moderate time then clicks it. Intended for page loads rather than DOM updates.
  # @param element [PageObject::Elements::Element]
  def wait_for_page_load_and_click(element)
    click_element(element, Utils.medium_wait)
  end

  # Awaits an element for a short time then clicks it using JavaScript rather than WebDriver. This is a workaround for a
  # WebDriver bug impacting certain buttons.
  # @param element [PageObject::Elements::Element]
  def click_element_js(element)
    wait_for_element(element, Utils.short_wait)
    execute_script('arguments[0].click();', element)
  end

  # Awaits an element for a short time, clicks it, removes existing text, and sends new text. Intended for placing text
  # in input or textarea elements.
  # @param element [PageObject::Elements::Element]
  # @param text [String]
  def wait_for_element_and_type(element, text)
    wait_for_page_update_and_click element
    element.clear
    element.send_keys text
  end

  # Awaits a select element for a short time, clicks it, waits for a certain option to appear, and selects that option.
  # @param select_element [PageObject::Elements::SelectList]
  # @param option [String]
  def wait_for_element_and_select(select_element, option)
    wait_for_element(select_element, Utils.medium_wait)
    wait = Selenium::WebDriver::Wait.new timeout: Utils.short_wait
    wait.until { select_element.include? option }
    select_element.select option
  end

  # Returns true if a code block completes without error.
  # @return [boolean]
  def verify_block(&blk)
    begin
      return true if yield
    rescue
      false
    end
  end

  # Clicks a link that should open in a new browser window and verifies that the expected page title loads on the new window.
  # @param driver [Selenium::WebDriver]
  # @param link [PageObject::Elements::Element]
  # @param expected_page_title [String]
  # @return [boolean]
  def external_link_valid?(driver, link, expected_page_title)
    begin
      original_window = driver.window_handle
      link.click
      if driver.window_handles.length > 1
        driver.switch_to.window driver.window_handles.last
        wait_until { driver.find_element(xpath: "//title[contains(.,'#{expected_page_title}')]") }
        true
      else
        logger.error 'Link did not open in a new window'
        logger.debug "Expecting page title #{expected_page_title}, but visible page title is #{driver.title}"
        false
      end
    rescue
      false
    ensure
      if driver.window_handles.length > 1
        # Handle any alert that might appear when opening the new window
        driver.switch_to.alert.accept rescue Selenium::WebDriver::Error::NoAlertPresentError
        driver.close
        # Handle any alert that might appear when closing the new window
        driver.switch_to.alert.accept rescue Selenium::WebDriver::Error::NoAlertPresentError
      end
      driver.switch_to.window original_window
    end
  end

  # Uses JavaScript to scroll to the bottom of a page. This is a workaround for a WebDriver bug where certain elements
  # are not scrolled into focus prior to an interaction.
  def scroll_to_bottom
    execute_script 'window.scrollTo(0, document.body.scrollHeight);'
  end

end
