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
  # @param student [BOACUser]
  def load_page(term_id, ccn, student=nil)
    logger.info "Loading class page for term #{term_id} section #{ccn}"
    navigate_to "#{BOACUtils.base_url}/course/#{term_id}/#{ccn}#{'?u=' + student.uid if student}"
    wait_for_spinner
    div_element(id: 'meetings-0').when_visible Utils.medium_wait
  end

  h1(:course_code, id: 'course-header')
  div(:course_details, class: 'course-details-section')
  div(:course_title, class: 'course-section-title')
  div(:term_name, class: 'course-term-name')

  # Returns the course data shown in the left header pane plus term
  # @return [Hash]
  def visible_course_data
    {
      :code => (course_code if course_code?),
      :format => (course_details.split(' ')[1] if course_details?),
      :number => (course_details.split(' ')[2] if course_details?),
      :units_completed => (course_details.split(' ')[4] if course_details?),
      :title => (course_title.strip if course_title?),
      :term => (term_name if term_name?)
    }
  end

  # COURSE MEETING DATA

  # Returns the instructor names shown for a course meeting at a given node
  # @param index [Integer]
  # @return [Array<String>]
  def meeting_instructors(index)
    el = span_element(:class => 'course-details-instructors')
    (el.exists? && !el.text.empty?) ? (el.text.gsub('Instructor:', '').gsub('Instructors:', '').strip.split(', ')) : []
  end

  def meeting_schedule_xpath(index)
    "//div[@id=\"meetings-#{index}\"]"
  end

  # Returns the days shown for a course meeting at a given node
  # @param index [Integer]
  # @return [Array<String>]
  def meeting_days(index)
    el = div_element(xpath: "#{meeting_schedule_xpath index}//div[1]")
    el.text if el.exists? && !el.text.empty?
  end

  # Returns the time shown for a course meeting at given node
  # @param index [Integer]
  # @return [Array<String>]
  def meeting_time(index)
    el = div_element(xpath: "#{meeting_schedule_xpath index}//div[2]")
    el.text if el.exists? && !el.text.empty?
  end

  # Returns the location shown for a course meeting at a given node
  # @param index [Integer]
  # @return [Array<String>]
  def meeting_location(index)
    el = div_element(xpath: "#{meeting_schedule_xpath index}//div[3]")
    el.text if el.exists? && !el.text.empty?
  end

  # Returns the meeting data shown for a course meeting at a given node
  # @param index [Integer]
  # @return [Hash]
  def visible_meeting_data(index)
    {
      :instructors => meeting_instructors(index),
      :days => meeting_days(index),
      :time => meeting_time(index),
      :location => meeting_location(index)
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
