require_relative '../../util/spec_helper'

class BOACSearchResultsPage

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACUserListPages
  include BOACGroupModalPages
  include BOACGroupAddSelectorPages
  include BOACListViewAdmitPages

  span(:results_loaded_msg, xpath: '//h1[text()="Search Results"]')
  button(:edit_search_button, id: 'edit-search-btn')

  def results_count(element)
    sleep Utils.click_wait
    wait_until(Utils.short_wait) do
      results_loaded_msg? || no_results_msg.exists?
    end
    sleep 1
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

  def no_results_msg
    div_element(id: 'page-header-no-results')
  end

  def wait_for_no_results
    no_results_msg.when_visible Utils.short_wait
  end

  def click_edit_search
    logger.info 'Clicking edit search button'
    hit_escape
    wait_for_update_and_click edit_search_button_element
  end

  # ADMIT SEARCH

  h2(:admit_results_count, id: 'admit-results-page-header')

  def admit_search_results_count
    results_count admit_results_count_element
  end

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

  def click_admit_result(admit)
    wait_for_update_and_click link_element(id: "link-to-admit--#{admit.sis_id}")
    wait_for_spinner
  end

  # STUDENT SEARCH

  h2(:student_results_count, id: 'student-results-page-header')

  def student_search_results_count
    results_count student_results_count_element
  end

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

  def click_student_result(student)
    wait_for_update_and_click link_element(id: "link-to-student-#{student.uid}")
    wait_for_spinner
  end

  # CLASS SEARCH

  element(:class_results_count, xpath: '//*[contains(@id, "course-results-page-h")]')
  elements(:class_row, :row, xpath: '//*[contains(@id, "course-results-page-h")]/../following-sibling::table/tr')
  div(:partial_results_msg, xpath: '//div[text()=" Showing the first 50 classes. "]')

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

  def class_link(course_code, section_number)
    link_element(xpath: "//a[contains(.,\"#{course_code}\")][contains(.,\"#{section_number}\")]")
  end

  def click_class_result(course_code, section_number)
    wait_for_update_and_click class_link(course_code, section_number)
    wait_for_spinner
  end

  # NOTES

  h2(:note_results_count_heading, id: 'note-results-page-header')
  elements(:note_search_result, :link, xpath: '//div[@class="advising-note-search-result"]//a')

  def note_results_count
    wait_for_spinner
    results_count note_results_count_heading_element
  end

  def wait_for_note_search_result_rows
    wait_until(Utils.short_wait) { note_search_result_elements.any? }
  end

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

  def note_result_uids
    note_search_result_elements.map { |el| el.attribute('href').split('/').last.split('#').first }
  end

  def note_link(note)
    link_element(xpath: "//a[contains(@href, '#note-#{note.id}')]")
  end

  def click_note_link(note)
    wait_for_update_and_click note_link(note)
  end

  # APPOINTMENTS

  h2(:appt_results_count_heading, id: 'appointment-results-page-header')
  elements(:appt_search_result, :link, xpath: '//div[contains(@id, "appointment-search-result-")]//a')

  def appt_results_count
    wait_for_spinner
    results_count appt_results_count_heading_element
  end

  def wait_for_appt_search_result_rows
    wait_until(Utils.short_wait) { appt_search_result_elements.any? }
  end

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
        :advisor_name => (advisor_el.text.strip if advisor_el.exists?),
        :date => (footer_el.text.split('-').last.strip if footer_el.exists?)
    }
  end

  def appt_result_uids
    appt_search_result_elements.map { |el| el.attribute('href').split('/').last.split('#').first }
  end

  def appt_link(appt)
    link_element(xpath: "//a[contains(@href, '#appointment-#{appt.id}')]")
  end

  def click_appt_link(appt)
    wait_for_update_and_click appt_link(appt)
  end

  # GROUPS

  def select_students_to_add(students)
    logger.info "Adding student UIDs: #{students.map &:sis_id}"
    students.each { |s| wait_for_update_and_click checkbox_element(xpath: "//input[@id='student-#{s.sis_id}-curated-group-checkbox']/..") }
  end

  def select_and_add_students_to_grp(students, group)
    select_students_to_add students
    add_students_to_grp(students, group)
  end

  def select_and_add_students_to_new_grp(students, group)
    select_students_to_add students
    add_students_to_new_grp(students, group)
  end

  def select_and_add_all_students_to_grp(all_students, group)
    wait_until(Utils.short_wait) { add_individual_to_grp_checkbox_elements.any? }
    wait_for_update_and_click add_all_to_grp_checkbox_element
    logger.debug "There are #{add_individual_to_grp_checkbox_elements.length} individual checkboxes"
    visible_sids = add_individual_to_grp_input_elements.map { |el| el.attribute('id').split('-')[1] }
    students = all_students.select { |student| visible_sids.include? student.sis_id }
    add_students_to_grp(students, group)
  end

end
