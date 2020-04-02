require_relative '../../util/spec_helper'

class BOACSearchResultsPage

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACUserListPages
  include BOACGroupModalPages
  include BOACAddGroupSelectorPages
  include BOACAdmitListPages

  span(:results_loaded_msg, xpath: '//span[contains(text(), "Search results have loaded.")]')

  # The result count displayed following a search
  # @param element [PageObject::Elements::Element]
  # @return [Integer]
  def results_count(element)
    sleep Utils.click_wait
    wait_until(Utils.short_wait) do
      h1_element(xpath: '//*[contains(@id, "results") and contains(@class, "header")]').exists? || no_results_msg.exists?
    end
    if no_results_msg.visible?
      logger.info 'No results found'
      0
    elsif results_loaded_msg? && !element.exists?
      logger.info 'There are some results, but not the right category of results'
      0
    else
      count = element.text.include?('One') ? 1 : element.text.split(' ').first.delete('+').to_i
      logger.debug "Results count: #{count}"
      count
    end
  end

  # Returns the element containing the 'no results' message for a search
  # @return [Element]
  def no_results_msg
    h1_element(id: 'page-header-no-results')
  end

  # ADMIT SEARCH

  h1(:admit_results_count, xpath: '//h1[@id="admit-results-page-header"]')

  # Returns the result count for an admit search
  # @return [Integer]
  def admit_search_results_count
    results_count student_results_count_element
  end

  # Checks if a given admit is among search results. If more than 50 results exist, the admit could be among them
  # but not displayed. In that case, returns true without further tests.
  # @param admit [BOACUser]
  # @return [boolean]
  def admit_in_search_result?(admit)
    wait_for_spinner
    count = results_count admit_results_count_element
    verify_block do
      if count > 50
        wait_until(2) { search_result_all_row_cs_ids.length == 50 }
        logger.warn "Skipping a test with CS ID #{admit.sis_id} because there are more than 50 results"
        sleep 1
      else
        wait_until(Utils.short_wait) do
          search_result_all_row_cs_ids.length == count
          search_result_all_row_cs_ids.include? admit.sis_id.to_s
        end
      end
    end
  end

  # Clicks the search results link for a given admit
  # @param admit [User]
  def click_admit_result(admit)
    wait_for_update_and_click link_element(id: "link-to-admit--#{admit.sis_id}")
    wait_for_spinner
  end

  # STUDENT SEARCH

  h1(:student_results_count, xpath: '//h1[contains(text(),"student")]')

  # Returns the result count for a student search
  # @return [Integer]
  def student_search_results_count
    results_count student_results_count_element
  end

  # Checks if a given student is among search results. If more than 50 results exist, the student could be among them
  # but not displayed. In that case, returns true without further tests.
  # @param driver [Selenium::WebDriver]
  # @param student [BOACUser]
  # @return [boolean]
  def student_in_search_result?(driver, student)
    wait_for_spinner
    count = results_count student_results_count_element
    verify_block do
      if count > 50
        wait_until(2) { all_row_sids.length == 50 }
        logger.warn "Skipping a test with UID #{student.uid} because there are more than 50 results"
        sleep 1
      else
        wait_until(Utils.short_wait) do
          all_row_sids.length == count
          all_row_sids.include? student.sis_id.to_s
        end
        visible_row_data = user_row_data student.sis_id
        wait_until(2, "Expecting name #{student.last_name}, #{student.first_name}, got #{visible_row_data[:name]}") { visible_row_data[:name] == "#{student.last_name}, #{student.first_name}" }
        wait_until(2) { ![visible_row_data[:major], visible_row_data[:term_units], visible_row_data[:cumulative_units], visible_row_data[:gpa], visible_row_data[:alert_count]].any?(&:empty?) }
      end
    end
  end

  # Clicks the search results row for a given student
  # @param student [User]
  def click_student_result(student)
    wait_for_update_and_click link_element(id: "link-to-student-#{student.uid}")
    wait_for_spinner
  end

  # CLASS SEARCH

  element(:class_results_count, xpath: '//*[contains(@id, "course-results-page-h")]')
  elements(:class_row, :row, xpath: '//*[contains(@id, "course-results-page-h")]/../following-sibling::table/tr')

  # Checks if a given class is among search results. If more than 50 results exist, the class could be among them
  # but not displayed. In that case, returns true without further tests.
  # @param course_code [String]
  # @param section_number [String]
  # @return [boolean]
  def class_in_search_result?(course_code, section_number)
    count = results_count class_results_count_element
    verify_block do
      if count > 50
        wait_until(2) { class_row_elements.length == 51 }
        logger.warn "Skipping a test with #{course_code} because there are more than 50 results"
        sleep 1
      else
        wait_until(Utils.medium_wait) do
          class_row_elements.length == count + 1
          class_link(course_code, section_number).when_visible 3
        end
      end
    end
  end

  # Returns the link to a class page
  # @param course_code [String]
  # @param section_number [String]
  # @@return [PageObject::Elements::Link]
  def class_link(course_code, section_number)
    link_element(xpath: "//a[contains(.,\"#{course_code}\")][contains(.,\"#{section_number}\")]")
  end

  # Clicks the link to a class page
  # @param course_code [String]
  # @param section_number [String]
  def click_class_result(course_code, section_number)
    wait_for_update_and_click class_link(course_code, section_number)
    wait_for_spinner
  end

  # NOTES

  h2(:note_results_count_heading, id: 'search-results-category-header-notes')
  elements(:note_search_result, :link, xpath: '//div[@class="advising-note-search-result"]//a')

  # Awaits and returns the number of note results returned from a search
  # @return [Integer]
  def note_results_count
    wait_for_spinner
    results_count note_results_count_heading_element
  end

  # Waits for note results to be present
  def wait_for_note_search_result_rows
    wait_until(Utils.short_wait) { note_search_result_elements.any? }
  end

  # Checks if a given note is among search results.
  # @param note [Note]
  # @return [boolean]
  def note_in_search_result?(note)
    count = note_results_count
    if count.zero?
      false
    else
      verify_block do
        wait_for_note_search_result_rows
        note_link(note).when_present 2
      end
    end
  end

  # Returns the data present for a given note
  # @param student [BOACUser]
  # @param note [Note]
  # @return [Hash]
  def note_result(student, note)
    note_link(note).when_visible Utils.short_wait
    sid_el = h3_element(xpath: "//div[@id='advising-note-search-result-#{note.id}']/h3")
    snippet_el = div_element(id: "advising-note-search-result-snippet-#{note.id}")
    advisor_el = span_element(id: "advising-note-search-result-advisor-#{note.id}")
    footer_el = div_element(xpath: "//div[@id='advising-note-search-result-#{note.id}']/div[@class='advising-note-search-result-footer']")
    {
      :student_name => (note_link( note).text.strip if note_link(note).exists?),
      :student_sid => (sid_el.text.gsub("#{student.full_name}", '').delete('()').strip if sid_el.exists?),
      :snippet => (snippet_el.text if snippet_el.exists?),
      :advisor_name => (advisor_el.text.delete('-').strip if advisor_el.exists?),
      :date => (footer_el.text.split('-').last.strip if footer_el.exists?)
    }
  end

  # Returns the UIDs associated with visible note search results
  # @return [Array<String>]
  def note_result_uids
    note_search_result_elements.map { |el| el.attribute('href').split('/').last.split('#').first }
  end

  # Returns the link element for a given note
  # @param note [Note]
  # @return [Element]
  def note_link(note)
    link_element(xpath: "//a[contains(@href, '#note-#{note.id}')]")
  end

  # Clicks the link element for a given note
  # @param note [Note]
  def click_note_link(note)
    wait_for_update_and_click note_link(note)
  end

  # APPOINTMENTS

  h2(:appt_results_count_heading, id: 'search-results-category-header-appointments')
  elements(:appt_search_result, :link, xpath: '//div[contains(@id, "appointment-search-result-")]//a')

  # Awaits and returns the number of appointment results returned from a search
  # @return [Integer]
  def appt_results_count
    wait_for_spinner
    results_count appt_results_count_heading_element
  end

  # Waits for appointment results to be present
  def wait_for_appt_search_result_rows
    wait_until(Utils.short_wait) { appt_search_result_elements.any? }
  end

  # Checks if a given appointment is among search results.
  # @param appt [Appointment]
  # @return [Boolean]
  def appt_in_search_result?(appt)
    count = appt_results_count
    if count.zero?
      false
    else
      verify_block do
        wait_for_appt_search_result_rows
        appt_link(appt).when_present 2
      end
    end
  end

  # Returns the data present for a given appointment
  # @param student [BOACUser]
  # @param appt [Appointment]
  # @return [Hash]
  def appt_result(student, appt)
    appt_link(appt).when_visible Utils.short_wait
    sid_el = h3_element(xpath: "//div[@id='appointment-search-result-#{appt.id}']/h3")
    snippet_el = div_element(id: "appointment-search-result-snippet-#{appt.id}")
    advisor_el = span_element(id: "appointment-search-result-advisor-#{appt.id}")
    footer_el = div_element(xpath: "//div[@id='appointment-search-result-#{appt.id}']/div[@class='advising-note-search-result-footer']")
    {
        :student_name => (appt_link(appt).text.strip if appt_link(appt).exists?),
        :student_sid => (sid_el.text.gsub("#{student.full_name}", '').delete('()').strip if sid_el.exists?),
        :snippet => (snippet_el.text if snippet_el.exists?),
        :advisor_name => (advisor_el.text.delete('-').strip if advisor_el.exists?),
        :date => (footer_el.text.split('-').last.strip if footer_el.exists?)
    }
  end

  # Returns the UIDs associated with visible appointment search results
  # @return [Array<String>]
  def appt_result_uids
    appt_search_result_elements.map { |el| el.attribute('href').split('/').last.split('#').first }
  end

  # Returns the link element for a given appointment
  # @param appt [Appointment]
  # @return [Element]
  def appt_link(appt)
    link_element(xpath: "//a[contains(@href, '#appointment-#{appt.id}')]")
  end

  # Clicks the link element for a given appointment
  # @param appt [Appointment]
  def click_appt_link(appt)
    wait_for_update_and_click appt_link(appt)
  end

  # GROUPS

  # Selects the add-to-group checkboxes for a given set of students
  # @param students [Array<User>]
  def select_students_to_add(students)
    logger.info "Adding student UIDs: #{students.map &:sis_id}"
    students.each { |s| wait_for_update_and_click checkbox_element(id: "student-#{s.sis_id}-curated-group-checkbox") }
  end

  # Adds a given set of students to an existing group
  # @param students [Array<User>]
  # @param group [CuratedGroup]
  def select_and_add_students_to_grp(students, group)
    select_students_to_add students
    add_students_to_grp(students, group)
  end

  # Adds a given set of students to a new group, which is created as part of the process
  # @param students [Array<User>]
  # @param group [CuratedGroup]
  def select_and_add_students_to_new_grp(students, group)
    select_students_to_add students
    add_students_to_new_grp(students, group)
  end

  # Adds all the students on a page to a group
  # @param group [CuratedGroup]
  def select_and_add_all_students_to_grp(all_students, group)
    wait_until(Utils.short_wait) { add_individual_to_grp_checkbox_elements.any? &:visible? }
    wait_for_update_and_click add_all_to_grp_checkbox_element
    logger.debug "There are #{add_individual_to_grp_checkbox_elements.length} individual checkboxes"
    visible_sids = add_individual_to_grp_checkbox_elements.map { |el| el.attribute('id').split('-')[1] }
    students = all_students.select { |student| visible_sids.include? student.sis_id }
    add_students_to_grp(students, group)
  end

end
