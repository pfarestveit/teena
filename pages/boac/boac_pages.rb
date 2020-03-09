require_relative '../../util/spec_helper'

module BOACPages

  include PageObject
  include Logging
  include Page

  ### PAGE LOADS ###

  div(:spinner, id: 'spinner-when-loading')
  div(:copyright_year_footer, xpath: '//div[contains(text(),"The Regents of the University of California")]')
  elements(:auto_suggest_option, :link, xpath: '//a[contains(@id, "suggestion")]')

  # Waits for an expected page title
  # @param page_title [String]
  def wait_for_title(page_title)
    start = Time.now
    wait_until(Utils.medium_wait) { title == "#{page_title} | BOA" }
    logger.debug "Page title updated in #{Time.now - start} seconds"
  end

  # Waits for the spinner to vanish following a page load and returns the number of seconds it took the spinner to vanish if greater than 1
  # @return [Float]
  def wait_for_spinner
    start = Time.now
    sleep 1
    if spinner?
      spinner_element.when_not_visible Utils.medium_wait rescue Selenium::WebDriver::Error::StaleElementReferenceError
      wait = Time.now - start
      logger.debug "Spinner lasted for #{wait} seconds"
      wait
    else
      logger.debug 'Spinner lasted less than 1 second'
    end
  end

  ### HEADER ###

  link(:home_link, xpath: '//a[contains(.,"Home")]')
  button(:header_dropdown, xpath: '//button[contains(@id,"header-dropdown-under-name")]')
  link(:flight_data_recorder_link, text: 'Flight Data Recorder')
  link(:flight_deck_link, text: 'Flight Deck')
  link(:pax_manifest_link, text: 'Passenger Manifest')
  link(:settings_link, text: 'Settings')
  link(:log_out_link, text: 'Log Out')
  link(:feedback_link, text: 'Feedback/Help')
  div(:modal, class: 'modal-content')
  h1(:student_name_heading, id: 'student-name-header')

  # Clicks the 'Home' link in the header
  def click_home
    wait_for_load_and_click home_link_element
  end

  # Clicks the header name button to reveal additional links
  def click_header_dropdown
    sleep 2
    wait_for_update_and_click header_dropdown_element
  end

  # Clicks the 'Log out' link in the header
  def log_out
    logger.info 'Logging out'
    click_header_dropdown
    wait_for_update_and_click log_out_link_element
    wait_for_title 'Welcome'
  end

  def click_flight_data_recorder_link
    click_header_dropdown
    wait_for_update_and_click flight_data_recorder_link_element
    wait_for_title 'Flight Data Recorder'
  end

  # Clicks the 'Flight Deck' link in the header
  def click_flight_deck_link
    click_header_dropdown
    wait_for_update_and_click flight_deck_link_element
    wait_for_title 'Flight Deck'
  end

  # Clicks the 'Passenger Manifest' link in the header
  def click_pax_manifest_link
    click_header_dropdown
    wait_for_update_and_click pax_manifest_link_element
    wait_for_title 'Passenger Manifest'
  end

  # Clicks the 'Settings' link in the header
  def click_settings_link
    click_header_dropdown
    wait_for_update_and_click settings_link_element
    wait_for_title 'Flight Deck'
  end

  ### USER LIST SORTING ###

  # Sorts a user list by a given option. If a cohort is given, then sorts the user list under the cohort.
  # @param option [String]
  # @param cohort [Cohort]
  def sort_by_option(option, cohort = nil)
    logger.info "Sorting by #{option}"
    xpath = filtered_cohort_xpath cohort if cohort && cohort.instance_of?(FilteredCohort)
    wait_for_update_and_click row_element(xpath: "#{xpath}//th[contains(.,\"#{option}\")]")
  end

  ### SIDEBAR - GROUPS ###

  link(:create_curated_group_link, id: 'create-curated-group-from-sidebar')
  link(:view_everyone_groups_link, id: 'groups-all')
  elements(:sidebar_group_link, :link, xpath: '//a[contains(@id,"sidebar-curated-group")]')

  # Clicks link to create new curated group
  def click_sidebar_create_curated_group
    logger.debug 'Clicking sidebar button to create a curated group'
    wait_for_load_and_click create_curated_group_link_element
    wait_for_title 'Create Curated Group'
    sleep 3
  end

  # Returns the names of all the groups in the sidebar
  # @return [Array<String>]
  def sidebar_groups
    sleep Utils.click_wait
    sidebar_group_link_elements.map &:text
  end

  # Clicks the sidebar link to view all curated groups
  def click_view_everyone_groups
    sleep 2
    wait_for_load_and_click view_everyone_groups_link_element
    wait_for_title 'All Groups'
  end

  # Clicks the sidebar link for a curated group
  # @param group [CuratedGroup]
  def click_sidebar_group_link(group)
    link = sidebar_group_link_elements.find { |el| el.text == group.name }
    wait_for_update_and_click link
  end

  # Waits for a group's member count in the sidebar to match expectations
  # @param group [CuratedGroup]
  def wait_for_sidebar_group_member_count(group)
    logger.debug "Waiting for group #{group.name} member count of #{group.members.length}"
    wait_until(Utils.short_wait) do
      el = span_element(xpath: "//div[contains(@class, \"sidebar-row-link\")][contains(.,\"#{group.name}\")]//span[@class=\"sr-only\"]")
      el.exists? && el.text.delete(' students').chomp == group.members.length.to_s
    end
  end

  # Waits for a group to appear in the sidebar with the right member count and obtains the group's ID
  # @param group [CuratedGroup]
  def wait_for_sidebar_group(group)
    wait_until(Utils.short_wait) { sidebar_groups.include? group.name }
    wait_for_sidebar_group_member_count group
    BOACUtils.set_curated_group_id group unless group.id
  end

  ### SIDEBAR - FILTERED COHORTS ###

  link(:create_filtered_cohort_link, id: 'cohort-create')
  link(:view_everyone_cohorts_link, id: 'cohorts-all')
  link(:team_list_link, id: 'sidebar-teams-link')
  link(:intensive_cohort_link, text: 'Intensive Students')
  link(:inactive_cohort_link, text: 'Inactive Students')
  elements(:filtered_cohort_link, :link, xpath: '//div[contains(@class,"sidebar-row-link")]//a[contains(@id,"sidebar-filtered-cohort")][contains(@href,"/cohort/")]')
  div(:dupe_filtered_name_msg, xpath: '//div[contains(text(), "You have an existing cohort with this name. Please choose a different name.")]')

  # Clicks the button to create a new custom cohort
  def click_sidebar_create_filtered
    logger.debug 'Clicking sidebar button to create a filtered cohort'
    wait_for_load_and_click create_filtered_cohort_link_element
    wait_for_title 'Create Cohort'
    sleep 3
  end

  # Clicks the button to view all custom cohorts
  def click_view_everyone_cohorts
    sleep 2
    wait_for_load_and_click view_everyone_cohorts_link_element
    wait_for_title 'All Cohorts'
  end

  # Clicks the sidebar link to a filtered cohort
  # @param cohort [FilteredCohort]
  def click_sidebar_filtered_link(cohort)
    link = filtered_cohort_link_elements.find { |el| el.text == cohort.name }
    wait_for_update_and_click link
  end

  # Waits for a cohort's member count in the sidebar to match expectations
  # @param cohort [FilteredCohort]
  def wait_for_sidebar_cohort_member_count(cohort)
    logger.debug "Waiting for cohort #{cohort.name} member count of #{cohort.member_data.length}"
    wait_until(Utils.medium_wait) do
      el = span_element(xpath: "//div[contains(@class, \"sidebar-row-link\")][contains(.,\"#{cohort.name}\")]//span[@class=\"sr-only\"]")
      el.exists? && el.text.delete(' admitted').delete(' students').chomp == cohort.member_data.length.to_s
    end
  end

  ### SIDEBAR - CE3 COHORTS ###

  link(:create_ce3_filtered_link, id: 'admitted-students-cohort-create')

  def click_sidebar_create_ce3_filtered
    logger.debug 'Clicking sidebar button to create a CE3 cohort'
    wait_for_load_and_click create_ce3_filtered_link_element
    h1_element(xpath: '//h1[text()=" Create an admissions cohort "]').when_visible Utils.short_wait
    sleep 3
  end

  ### SIDEBAR - SEARCH ###

  button(:search_options_toggle_button, id: 'search-options-panel-toggle')
  button(:search_options_note_filters_toggle_button, id: 'search-options-note-filters-toggle')
  checkbox(:include_admits_cbx, id: 'search-include-admits-checkbox')
  checkbox(:include_students_cbx, id: 'search-include-students-checkbox')
  checkbox(:include_classes_cbx, id: 'search-include-courses-checkbox')
  checkbox(:include_notes_cbx, id: 'search-include-notes-checkbox')
  div(:search_options_note_filters_subpanel, id: 'search-options-note-filters-subpanel')
  select_list(:note_topics_select, id: 'search-option-note-filters-topic')
  radio_button(:notes_by_anyone_radio, id: 'search-options-note-filters-posted-by-anyone')
  div(:notes_by_anyone_div, xpath: '//input[@id="search-options-note-filters-posted-by-anyone"]/..')
  radio_button(:notes_by_you_radio, id: 'search-options-note-filters-posted-by-you')
  div(:notes_by_you_div, xpath: '//input[@id="search-options-note-filters-posted-by-you"]/..')
  text_area(:note_author, id: 'search-options-note-filters-author-input')
  text_area(:note_student, id: 'search-options-note-filters-student-input')
  elements(:author_suggest, :link, :xpath => "//a[contains(@id,'search-options-note-filters-author-suggestion')]")
  text_area(:note_date_from, id: 'search-options-note-filters-last-updated-from')
  text_area(:note_date_to, id: 'search-options-note-filters-last-updated-to')
  text_area(:search_input, id: 'search-students-input')
  elements(:search_history_item, xpath: '//a[contains(@id, "search-students-suggestion-")]')
  element(:fill_in_field_msg, xpath: '//*[contains(text(), "Please fill out this field.")]')
  button(:search_button, xpath: '//button[contains(text(), "Search")]')

  # Clears the search input such that the full search history will appear
  def clear_search_input
    search_input_element.clear
    click_home
    wait_for_update_and_click search_input_element
    sleep Utils.click_wait
  end

  # Returns the strings in the visible search history list
  # @return [Array<String>]
  def visible_search_history
    search_history_item_elements.map { |el| el.attribute('innerText') }
  end

  # Clicks an item in the search history list and waits for the resulting search to complete
  # @param search_string [String]
  def select_history_item(search_string)
    wait_for_update_and_click search_history_item_elements.find { |el| el.attribute('innerText') == search_string }
    wait_for_spinner
  end

  # Expands the sidebar advanced search
  def expand_search_options
    wait_for_update_and_click search_options_toggle_button_element unless include_students_cbx_element.visible?
    include_students_cbx_element.when_visible 1
  end

  # Makes sure the Admitted Students checkbox is selected
  def include_admits
    wait_for_update_and_click include_admits_cbx_element unless include_admits_cbx_checked?
  end

  # Makes sure the Admitted Students checkbox is not selected
  def exclude_admits
    wait_for_update_and_click include_admits_cbx_element if include_admits_cbx_checked?
  end

  # Expands the sidebar advanced search notes subpanel
  def expand_search_options_notes_subpanel
    expand_search_options
    wait_for_update_and_click search_options_note_filters_toggle_button_element unless search_options_note_filters_subpanel_element.visible?
    search_options_note_filters_subpanel_element.when_visible 1
  end

  # Collapses the sidebar advanced search notes subpanel
  def collapse_search_options_notes_subpanel
    expand_search_options
    hit_escape
    wait_for_update_and_click search_options_note_filters_toggle_button_element if search_options_note_filters_subpanel_element.visible?
    sleep Utils.click_wait
  end

  # Collapses and expands the options sub-panel in order to clear previous input
  def reset_search_options_notes_subpanel
    collapse_search_options_notes_subpanel
    expand_search_options_notes_subpanel
  end

  # Selects the sidebar posted by "anyone" radio button
  def select_notes_posted_by_anyone
    expand_search_options_notes_subpanel
    js_click notes_by_anyone_radio_element unless notes_by_anyone_div_element.attribute('ischecked') == 'true'
  end

  # Selects the sidebar posted by "you" radio button
  def select_notes_posted_by_you
    expand_search_options_notes_subpanel
    js_click notes_by_you_radio_element unless notes_by_you_div_element.attribute('ischecked') == 'true'
  end

  # Sets text in a given element and waits for and clicks a matching auto-suggest result
  # @param element [PageObject::Element]
  # @param name [String]
  def set_auto_suggest(element, name)
    wait_for_element_and_type(element, name)
    sleep Utils.click_wait
    wait_until(2) { auto_suggest_option_elements.any? }
    link_element = auto_suggest_option_elements.find { |el| el.attribute('innerText').downcase.include? name.downcase }
    wait_for_load_and_click link_element
  end

  # Sets the "Advisor" notes search option
  # @param name [String]
  def set_notes_author(name)
    logger.info "Entering notes author name '#{name}'"
    expand_search_options_notes_subpanel
    set_auto_suggest(note_author_element, name)
  end

  # Sets the "Student" notes search option
  # @param student [BOACUser]
  def set_notes_student(student)
    logger.info "Entering notes student '#{student.full_name} (#{student.sis_id})'"
    expand_search_options_notes_subpanel
    set_auto_suggest(note_student_element, "#{student.full_name} (#{student.sis_id})")
  end

  # Sets the "Last updated > From" notes search option
  # @param date [Date]
  def set_notes_date_from(date)
    expand_search_options_notes_subpanel
    from_date = date ? date.strftime('%m/%d/%Y') : ''
    logger.debug "Entering note date from '#{from_date}'"
    wait_for_element_and_type(note_date_from_element, from_date)
  end

  # Sets the "Last updated > To" notes search option
  # @param date [Date]
  def set_notes_date_to(date)
    expand_search_options_notes_subpanel
    to_date = date ? date.strftime('%m/%d/%Y') : ''
    logger.debug "Entering note date to '#{to_date}'"
    wait_for_element_and_type(note_date_to_element, to_date)
  end

  # Sets both "Last updated" notes search options
  # @param from [Date]
  # @param to [Date]
  def set_notes_date_range(from, to)
    set_notes_date_to to
    set_notes_date_from from
  end

  # Selects a sidebar note topic
  # @param topic [Topic]
  def select_note_topic(topic)
    expand_search_options_notes_subpanel
    topic_name = topic ? topic.name : 'Any topic'
    logger.debug "Selecting note topic '#{topic_name}'"
    wait_for_element_and_select_js(note_topics_select_element, topic_name)
  end

  # Enters a sidebar search string
  # @param string [String]
  def enter_search_string(string)
    sleep 1
    search_input_element.when_visible Utils.short_wait
    search_input_element.clear
    (self.search_input = string) if string
  end

  # Enters a sidebar search string and hits enter to execute the search
  # @param string [String]
  def enter_string_and_hit_enter(string)
    enter_search_string string
    hit_enter
    wait_for_spinner
  end

  # Clicks the sidebar search button
  def click_search_button
    logger.info 'Clicking search button'
    wait_for_update_and_click search_button_element
  end

  # Searches for a string using the sidebar search input and logs the search string. Not to be used for note searches.
  # @param string [String]
  def type_non_note_string_and_enter(string)
    logger.info "Searching for '#{string}'"
    enter_string_and_hit_enter string
  end

  # Searches for a string using the sidebar search input without logging the search string.  To be used for note searches.
  # @param string [String]
  def type_note_appt_string_and_enter(string)
    logger.info 'Searching for a string within a note or appointment'
    enter_string_and_hit_enter string
  end

  ### STUDENT ###

  # BOA route (URI, relative path) to student profile page
  # @param uid [String]
  # @return [String]
  def path_to_student_view(uid)
    # TODO: If user is in demo-mode this method should return: /student/#{Base64.encode64(uid)}
    "/student/#{uid}"
  end

  ### BOXPLOTS ###

  # Returns the XPath to a boxplot nested under another element
  # @return [String]
  def boxplot_xpath
    "//*[name()='svg']/*[name()='g'][@class='highcharts-series-group']"
  end

  # Returns the XPath to a boxplot's tooltip trigger nested under another element
  # @return [String]
  def boxplot_trigger_xpath
    "#{boxplot_xpath}/*[name()='g']/*[name()='g']/*[name()='path'][3]"
  end

  ### BATCH NOTES ###

  button(:batch_note_button, id: 'batch-note-button')

  # Clicks the new (batch) note button
  def click_create_note_batch
    logger.debug 'Clicking the New Note (batch) button'
    wait_for_update_and_click batch_note_button_element
  end

  # Obtains the ID of a new note and sets current created and updated dates. Fails if the note ID is not available within a defined
  # timeout
  # @param note [Note]
  # @return [Integer]
  def set_new_note_id(note, student=nil)
    start_time = Time.now
    wait_until(Utils.long_wait) { note.id = BOACUtils.get_note_ids_by_subject(note.subject, student).first }
    logger.debug "Note ID is #{note.id}"
    logger.warn "Note was created in #{Time.now - start_time} seconds"
    new_note_subject_input_element.when_not_visible Utils.short_wait rescue Selenium::WebDriver::Error::StaleElementReferenceError
    note.created_date = note.updated_date = Time.now
    note.id
  rescue
    logger.debug 'Timed out waiting for note ID'
    fail
  end

end
