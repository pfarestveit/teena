module BOACSearchForm

  include PageObject
  include Logging
  include Page

  element(:fill_in_field_msg, xpath: '//span[contains(text(), "Search input is required")]')

  def clear_input(element)
    wait_for_update_and_click element
    sleep 1
    clear_input_value element
  end

  # SIMPLE SEARCH

  text_field(:search_input, id: 'search-students-input')
  button(:search_button, id: 'go-search')

  def clear_simple_search_input
    clear_input search_input_element
    sleep Utils.click_wait
  end

  def enter_simple_search(string)
    logger.debug "Searching for '#{string}'"
    sleep 1
    clear_input search_input_element
    (self.search_input = string) if string
  end

  def enter_simple_search_and_hit_enter(string)
    enter_simple_search string
    hit_enter
    wait_for_spinner
  end

  def click_simple_search_button
    logger.info 'Clicking search button'
    wait_for_update_and_click search_button_element
  end

  # Search history

  elements(:search_history_item, :link, xpath: '//li[@class="autocomplete-result"]')

  def visible_search_history
    sleep 1
    search_history_item_elements.map { |el| el.text.strip }
  end

  def select_history_item(search_string)
    sleep 1
    search_history_item_elements.find { |el| el.text.strip == search_string }.click
    wait_for_spinner
  end

  # ADVANCED SEARCH

  button(:open_adv_search_button, id: 'search-options-panel-toggle')

  def open_adv_search
    logger.info 'Opening advanced search'
    wait_for_update_and_click open_adv_search_button_element
    adv_search_student_input_element.when_visible 2
  end

  text_field(:adv_search_student_input, id: 'advanced-search-students-input')

  def clear_adv_search_input
    clear_input adv_search_student_input_element
    sleep Utils.click_wait
  end

  def enter_adv_search(string)
    logger.debug "Searching for '#{string}'"
    sleep 1
    clear_input adv_search_student_input_element
    (self.adv_search_student_input = string) if string
  end

  def enter_adv_search_and_hit_enter(string)
    enter_adv_search string
    hit_enter
    wait_for_spinner
  end

  # Search types

  checkbox(:include_admits_cbx, id: 'search-include-admits-checkbox')
  checkbox(:include_students_cbx, id: 'search-include-students-checkbox')
  checkbox(:include_classes_cbx, id: 'search-include-courses-checkbox')
  checkbox(:include_notes_cbx, id: 'search-include-notes-checkbox')

  def include_students
    js_click include_students_cbx_element unless include_students_cbx_checked?
  end

  def exclude_students
    js_click include_students_cbx_element if include_students_cbx_checked?
  end

  def include_admits
    js_click include_admits_cbx_element unless include_admits_cbx_checked?
  end

  def exclude_admits
    js_click include_admits_cbx_element if include_admits_cbx_checked?
  end

  def include_classes
    js_click include_classes_cbx_element unless include_classes_cbx_checked?
  end

  def exclude_classes
    js_click include_classes_cbx_element if include_classes_cbx_checked?
  end

  # Topic

  select_list(:note_topics_select, id: 'search-option-note-filters-topic')

  def select_note_topic(topic)
    topic_name = topic ? topic.name : 'Any topic'
    logger.debug "Selecting note topic '#{topic_name}'"
    wait_for_element_and_select(note_topics_select_element, topic_name)
  end

  # Author radio

  radio_button(:notes_by_anyone_radio, id: 'search-options-note-filters-posted-by-anyone')
  div(:notes_by_anyone_div, xpath: '//input[@id="search-options-note-filters-posted-by-anyone"]/..')
  radio_button(:notes_by_you_radio, id: 'search-options-note-filters-posted-by-you')
  div(:notes_by_you_div, xpath: '//input[@id="search-options-note-filters-posted-by-you"]/..')

  def select_notes_posted_by_anyone
    notes_by_anyone_div_element.click unless notes_by_anyone_div_element.attribute('ischecked') == 'true'
  end

  def select_notes_posted_by_you
    notes_by_you_div_element.click unless notes_by_you_div_element.attribute('ischecked') == 'true'
  end

  # Author / Student

  text_area(:note_author, id: 'search-options-note-filters-author-input')
  text_area(:note_student, id: 'search-options-note-filters-student-input')
  elements(:author_suggest, :link, :xpath => "//a[contains(@id,'search-options-note-filters-author-suggestion')]")

  def set_auto_suggest(element, name, alt_names=[])
    wait_for_element_and_type(element, name)
    sleep Utils.click_wait
    wait_until(Utils.short_wait) do
      auto_suggest_option_elements.any?
      auto_suggest_option_elements.find do |el|
        text = el.attribute('innerText').downcase
        text.include?(name.downcase) || (alt_names.find { |n| text.include? n.downcase } if alt_names.any?)
      end
    end
    el = auto_suggest_option_elements.find do |el|
      text = el.attribute('innerText').downcase
      text.include?(name.downcase) || (alt_names.find { |n| text.include? n.downcase } if alt_names.any?)
    end
    el.click
  end

  def set_notes_author(name, alt_names=[])
    logger.info "Entering notes author name '#{name}'"
    set_auto_suggest(note_author_element, name, alt_names)
  end

  def set_notes_student(student)
    logger.info "Entering notes student '#{student.full_name} (#{student.sis_id})'"
    set_auto_suggest(note_student_element, "#{student.full_name} (#{student.sis_id})")
  end

  # Dates

  text_area(:note_date_from, id: 'search-options-note-filters-last-updated-from')
  text_area(:note_date_to, id: 'search-options-note-filters-last-updated-to')

  def set_notes_date_from(date)
    from_date = date ? date.strftime('%m/%d/%Y') : ''
    logger.debug "Entering note date from '#{from_date}'"
    wait_for_update_and_click note_date_from_element
    50.times { hit_backspace; hit_delete }
    note_date_from_element.send_keys from_date
    4.times { hit_tab }
  end

  def set_notes_date_to(date)
    to_date = date ? date.strftime('%m/%d/%Y') : ''
    logger.debug "Entering note date to '#{to_date}'"
    wait_for_update_and_click note_date_to_element
    50.times { hit_backspace; hit_delete }
    note_date_to_element.send_keys to_date
    4.times { hit_tab }
  end

  def set_notes_date_range(from, to)
    set_notes_date_to to
    set_notes_date_from from
  end

  # Reset, Search, Cancel

  button(:reset_adv_search_button, id: 'reset-advanced-search-form-btn')
  button(:adv_search_button, id: 'advanced-search')
  button(:adv_search_cxl_button, id: 'advanced-search-cancel')

  def reset_adv_search
    logger.info 'Resetting advanced search form'
    wait_for_update_and_click reset_adv_search_button_element
  end

  def click_adv_search_button
    logger.info 'Submitting advanced search'
    wait_for_update_and_click adv_search_button_element
  end

  def click_adv_search_cxl_button
    logger.info 'Canceling advanced search'
    wait_for_update_and_click adv_search_cxl_button_element
  end

  def close_adv_search_if_open
    click_adv_search_cxl_button if adv_search_cxl_button?
  end

  def reopen_and_reset_adv_search
    click_adv_search_cxl_button if adv_search_cxl_button?
    open_adv_search
    reset_adv_search if reset_adv_search_button?
  end
end
