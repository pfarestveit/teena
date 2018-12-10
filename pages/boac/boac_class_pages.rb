require_relative '../../util/spec_helper'

module BOACClassPages

  include PageObject
  include Logging
  include Page
  include BOACPages

  # COURSE DATA

  # Loads a class page in default list view
  # @param term_id [String]
  # @param ccn [String]
  def load_page(term_id, ccn)
    logger.info "Loading class page for term #{term_id} section #{ccn}"
    navigate_to "#{BOACUtils.base_url}/course/#{term_id}/#{ccn}"
    wait_for_spinner
    div_element(class: 'course-column-schedule').when_visible Utils.medium_wait
  end

  h1(:course_code, xpath: '//h1')
  span(:section_format, xpath: '//span[@data-ng-bind="section.instructionFormat"]')
  span(:section_number, xpath: '//span[@data-ng-bind="section.sectionNum"]')
  span(:section_units, xpath: '//span[@count="section.units"]')
  span(:course_title, xpath: '//span[@data-ng-bind="section.title"]')
  div(:term_name, xpath: '//div[@data-ng-bind="section.termName"]')

  # Returns the course data shown in the left header pane plus term
  # @return [Hash]
  def visible_course_data
    {
      :code => (course_code if course_code?),
      :format => (section_format if section_format?),
      :number => (section_number if section_number?),
      :units_completed => (section_units.split.first if section_units?),
      :title => (course_title if course_title?),
      :term => (term_name if term_name?)
    }
  end

  # COURSE MEETING DATA

  # Returns the XPath of the course meeting element at a given node
  # @param node [Integer]
  # @return [String]
  def meeting_xpath(node)
    "//div[@data-ng-repeat=\"meeting in section.meetings\"][#{node}]"
  end

  # Returns the instructor names shown for a course meeting at a given node
  # @param node [Integer]
  # @return [Array<String>]
  def meeting_instructors(driver, node)
    els = driver.find_elements(xpath: "#{meeting_xpath node}//span[@data-ng-repeat=\"instructor in meeting.instructors\"]")
    els.map { |el| el.text.delete(',') }
  end

  # Returns the days shown for a course meeting at a given node
  # @param node [Integer]
  # @return [Array<String>]
  def meeting_days(node)
    el = div_element(xpath: "#{meeting_xpath node}//div[@data-ng-bind=\"meeting.days\"]")
    el.text if el.exists? && !el.text.empty?
  end

  # Returns the time shown for a course meeting at given node
  # @param node [Integer]
  # @return [Array<String>]
  def meeting_time(node)
    el = div_element(xpath: "#{meeting_xpath node}//div[@data-ng-bind=\"meeting.time\"]")
    el.text if el.exists? && !el.text.empty?
  end

  # Returns the location shown for a course meeting at a given node
  # @param node [Integer]
  # @return [Array<String>]
  def meeting_location(node)
    el = div_element(xpath: "#{meeting_xpath node}//div[@data-ng-bind=\"meeting.location\"]")
    el.text if el.exists? && !el.text.empty?
  end

  # Returns the meeting data shown for a course meeting at a given node
  # @param driver [Selenium::WebDriver]
  # @param node [Integer]
  # @return [Hash]
  def visible_meeting_data(driver, node)
    {
      :instructors => meeting_instructors(driver, node),
      :days => meeting_days(node),
      :time => meeting_time(node),
      :location => meeting_location(node)
    }
  end

  # LIST VIEW / MATRIX VIEW

  button(:list_view_button, xpath: '//button[contains(.,"List")]')
  button(:matrix_view_button, xpath: '//button[contains(.,"Matrix")]')

  # Clicks the list view button
  def click_list_view
    logger.info 'Switching to list view'
    wait_for_load_and_click list_view_button_element
  end

  # Clicks the matrix view button
  def click_matrix_view
    logger.info 'Switching to matrix view'
    wait_for_load_and_click matrix_view_button_element
  end

end
