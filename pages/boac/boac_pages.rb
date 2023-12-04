require_relative '../../util/spec_helper'

module BOACPages

  include PageObject
  include Logging
  include Page
  include BOACSearchForm

  ### PAGE LOADS ###

  div(:spinner, id: 'spinner-when-loading')
  div(:div_lock, xpath: '//div[@data-lock]')
  image(:not_found, xpath: '//img[@alt="A silly boarding pass with the text, \'Error 404: Flight not found\'"]')
  div(:copyright_year_footer, xpath: '//div[contains(text(),"The Regents of the University of California")]')
  elements(:auto_suggest_option, :link, xpath: '//a[contains(@id, "suggestion")]')

  # Waits for an expected page title
  # @param page_title [String]
  def wait_for_title(page_title)
    start = Time.now
    wait_until(Utils.medium_wait, "Expected '#{page_title} | BOA', got '#{title}'") { title == "#{page_title} | BOA" }
    logger.debug "Page title updated in #{Time.now - start} seconds"
  end

  def wait_for_404
    not_found_element.when_visible Utils.short_wait
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

  div(:banner, xpath: '//div[@role="banner"]')
  link(:home_link, xpath: '//a[contains(.,"Online Advising")]')
  button(:header_dropdown, id: 'header-dropdown-under-name__BV_toggle_')
  link(:flight_data_recorder_link, text: 'Flight Data Recorder')
  link(:flight_deck_link, text: 'Flight Deck')
  link(:pax_manifest_link, text: 'Passenger Manifest')
  link(:degree_checks_link, text: 'Degree Checks')
  link(:settings_link, text: 'Profile')
  link(:log_out_link, text: 'Log Out')
  link(:feedback_link, text: 'Feedback/Help')
  div(:modal, class: 'modal-content')
  h1(:student_name_heading, id: 'student-name-header')
  button(:confirm_delete_or_discard_button, id: 'are-you-sure-confirm')
  button(:cancel_delete_or_discard_button, id: 'are-you-sure-cancel')

  # Clicks the 'Home' link in the header
  def click_home
    wait_for_load_and_click home_link_element
  end

  # Clicks the header name button to reveal additional links
  def click_header_dropdown
    tries ||= 3
    logger.info 'Expanding header dropdown'
    refresh_page
    sleep 2
    wait_for_update_and_click header_dropdown_element
    log_out_link_element.when_present Utils.short_wait
  rescue => e
    logger.error e.message
    (tries -= 1).zero? ? fail(Utils.error e) : retry
  end

  # Clicks the 'Log out' link in the header
  def log_out
    logger.info 'Logging out'
    navigate_to BOACUtils.base_url unless header_dropdown?
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

  def click_degree_checks_link
    click_header_dropdown
    wait_for_update_and_click degree_checks_link_element
    wait_for_title 'Manage Degree Checks'
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
    wait_until(Utils.medium_wait) { title.include? 'Profile | BOA' }
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

  ### SIDEBAR - GROUPS ###

  link(:create_curated_group_link, id: 'create-curated-group-from-sidebar')
  link(:create_admit_group_link, id: 'create-admissions-group-from-sidebar')
  link(:view_everyone_groups_link, id: 'groups-all')
  elements(:sidebar_group_link, :link, xpath: '//a[contains(@id, "sidebar-curated-group")]')
  elements(:sidebar_admit_group_link, :link, xpath: '//a[contains(@id, "sidebar-admissions-group")]')

  # Clicks link to create new curated group
  def click_sidebar_create_student_group
    logger.debug 'Clicking sidebar button to create a curated group'
    wait_for_load_and_click create_curated_group_link_element
    sleep 2
  end

  def click_sidebar_create_admit_group
    logger.info 'Clicking sidebar button to create an admit group'
    wait_for_load_and_click create_admit_group_link_element
    sleep 2
  end

  # Returns the names of all the groups in the sidebar
  # @return [Array<String>]
  def sidebar_student_groups
    sleep Utils.click_wait
    sidebar_group_link_elements.map &:text
  end

  def sidebar_admit_groups
    sleep Utils.click_wait
    sidebar_admit_group_link_elements.map &:text
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
    els = group.ce3 ? sidebar_admit_group_link_elements : sidebar_group_link_elements
    link = els.find { |el| el.text == group.name }
    wait_for_update_and_click link
  end

  # Waits for a group's member count in the sidebar to match expectations
  # @param group [CuratedGroup]
  def wait_for_sidebar_group_member_count(group)
    logger.debug "Waiting for group #{group.name} member count of #{group.members.length}"
    wait_until(Utils.medium_wait) do
      el = span_element(xpath: "//div[contains(@class, \"sidebar-row-link\")][contains(.,\"#{group.name}\")]//span[@class=\"sr-only\"]")
      el.exists? && el.text.delete(' students').chomp == group.members.length.to_s
    end
  end

  # Waits for a group to appear in the sidebar with the right member count and obtains the group's ID
  # @param group [CuratedGroup]
  def wait_for_sidebar_group(group)
    if group.ce3
      wait_until(Utils.short_wait) { sidebar_admit_groups.include? group.name }
    else
      wait_until(Utils.medium_wait) do
        sidebar_student_groups.include? group.name
      end
      navigate_to current_url
      wait_for_sidebar_group_member_count group
    end
    BOACUtils.set_curated_group_id group unless group.id
  end

  ### SIDEBAR - FILTERED COHORTS ###

  link(:create_filtered_cohort_link, id: 'cohort-create')
  link(:view_everyone_cohorts_link, id: 'cohorts-all')
  link(:team_list_link, id: 'sidebar-teams-link')
  elements(:filtered_cohort_link, :link, xpath: '//div[contains(@class,"sidebar-row-link")]//a[contains(@id,"sidebar-filtered-cohort")][contains(@href,"/cohort/")]')
  div(:dupe_filtered_name_msg, xpath: '//div[contains(text(), "You have an existing cohort with this name. Please choose a different name.")]')

  # Clicks the button to create a new custom cohort
  def click_sidebar_create_filtered
    logger.debug 'Clicking sidebar button to create a filtered cohort'
    wait_for_load_and_click create_filtered_cohort_link_element
    wait_for_title 'Create Cohort'
    sleep Utils.click_wait
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
    logger.debug "Waiting for cohort #{cohort.name} member count of #{cohort.members.length}"
    wait_until(Utils.medium_wait) do
      navigate_to current_url
      el = span_element(xpath: "//div[contains(@class, \"sidebar-row-link\")][contains(.,\"#{cohort.name}\")]//span[@class=\"sr-only\"]")
      el.when_present Utils.short_wait
      el.text.delete(' admitted').delete(' students').chomp == cohort.members.length.to_s
    end
  end

  ### SIDEBAR - CE3 COHORTS ###

  link(:create_ce3_filtered_link, id: 'admitted-students-cohort-create')
  link(:all_admits_link, id: 'admitted-students-all')

  def click_sidebar_all_admits
    logger.info 'Clicking sidebar link to view all CE3 admits'
    wait_for_load_and_click all_admits_link_element
    wait_for_spinner
    h1_element(xpath: '//h1[contains(text(), "CE3 Admissions")]').when_visible Utils.short_wait
  end

  def click_sidebar_create_ce3_filtered
    logger.debug 'Clicking sidebar button to create a CE3 cohort'
    wait_for_load_and_click create_ce3_filtered_link_element
    h1_element(xpath: '//h1[text()=" Create an admissions cohort "]').when_visible Utils.short_wait
    sleep 3
  end

  ### SIDEBAR - DRAFT NOTES ###

  link(:draft_notes_link, id: 'link-to-draft-notes')

  def draft_note_count
    span_element(id: 'draft-note-count').text
  end

  def click_draft_notes
    logger.info 'Clicking link to Draft Notes page'
    wait_for_update_and_click draft_notes_link_element
  end

  def wait_for_draft_note(note, manual_update=false)
    hit_tab
    begin
      tries ||= (manual_update ? 1 : 3)
      note.id ||= BOACUtils.get_note_ids_by_subject(note.subject).first
      wait_until(1) { note.id }
      saved = BOACUtils.get_notes_by_ids([note.id]).first
      note.created_date = saved.created_date
      saved
    rescue => e
      tries -= 1
      if tries.zero?
        logger.error e.message
        fail
      else
        sleep 5
        retry
      end
    end
  end

  def wait_for_draft_note_update(note, manual_update=false)
    tries ||= (manual_update ? 2 : 8)
    saved_note = BOACUtils.get_notes_by_ids([note.id]).first
    note.subject ||= ''
    wait_until(1, "Tries #{tries}, expected subject #{note.subject}, got #{saved_note.subject}.") { saved_note.subject == note.subject }
    wait_until(1, "Tries #{tries}, expected body #{note.body}, got #{saved_note.body}.") { saved_note.body.to_s == note.body.to_s }
    wait_until(1, "Tries #{tries}, expected UID #{note.advisor.uid}, got #{saved_note.advisor.uid}") { saved_note.advisor.uid == note.advisor.uid }
    wait_until(1, "Tries #{tries}, expected draft #{note.is_draft}, got #{saved_note.is_draft}") { saved_note.is_draft == note.is_draft }
    wait_until(1, "Tries #{tries}, expected private #{note.is_private}, got #{saved_note.is_private}") { saved_note.is_private == note.is_private }
    wait_until(1, "Tries #{tries}, expected created #{note.created_date&.strftime('%Y/%m/%d')}, got #{saved_note.created_date&.strftime('%Y/%m/%d')}") do
      saved_note.created_date&.strftime('%Y/%m/%d') == note.created_date&.strftime('%Y/%m/%d')
    end
    wait_until(1, "Tries #{tries}, expected set #{note.set_date&.strftime('%Y/%m/%d')}, got #{saved_note.set_date&.strftime('%Y/%m/%d')}") do
      saved_note.set_date&.strftime('%Y/%m/%d') == note.set_date&.strftime('%Y/%m/%d')
    end
    wait_until(1, "Tries #{tries}, expected attachments #{note.attachments.map(&:file_name).sort}, got #{saved_note.attachments.map(&:file_name).sort}") do
      saved_note.attachments.map(&:file_name).sort == note.attachments.map(&:file_name).sort
    end
    wait_until(1, "Tries #{tries}, expected topics #{note.topics.map(&:name).sort}, got #{saved_note.topics.sort}") do
      saved_note.topics.sort == note.topics.map(&:name).sort
    end
    if note.instance_of? NoteBatch
      wait_until(1, "Tries #{tries}, expected SID #{note.students.first&.sis_id}, got #{saved_note.student&.sis_id}") do
        saved_note.student&.sis_id == note.students.first&.sis_id
      end
    end
  rescue => e
    tries -= 1
    if tries.zero?
      logger.error e.message
      fail e.message
    else
      sleep 5
      retry
    end
  end

  def expected_draft_note_subject(note)
    note.subject == '' ? '[DRAFT NOTE]' : note.subject.strip
  end

  ### STUDENT ###

  # BOA route (URI, relative path) to student profile page
  # @param uid [String]
  # @return [String]
  def path_to_student_view(uid)
    # If user is in demo-mode this method should return: /student/#{Base64.encode64(uid)}
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
    wait_until(Utils.short_wait) { note.id = BOACUtils.get_note_ids_by_subject(note.subject, student).first }
    logger.debug "Note ID is #{note.id}"
    logger.warn "Note was created in #{Time.now - start_time} seconds"
    start_time = Time.now
    new_note_subject_input_element.when_not_visible Utils.short_wait rescue Selenium::WebDriver::Error::StaleElementReferenceError
    logger.warn "Note input form took #{Time.now - start_time} seconds to go away"
    note.created_date = note.updated_date = Time.now
    note.id
  rescue
    logger.debug 'Timed out waiting for note ID'
    fail
  end

  def set_new_degree_id(degree, student)
    start_time = Time.now
    wait_until(Utils.medium_wait) { sleep Utils.click_wait; degree.id = BOACUtils.get_degree_id_by_name(degree, student).first }
    logger.warn "Degree #{degree.id} was created within #{Time.now - start_time} seconds"
    degree.id
  rescue
    fail "Timed out waiting for SID #{student.sis_id} degree '#{degree.name}'"
  end

  elements(:everyone_group_link, :link, xpath: '//h1[text()="Everyone\'s Groups"]/../..//a')

  # Returns all the curated groups displayed on the Everyone's Groups page
  # @return [Array<CuratedGroup>]
  def visible_everyone_groups
    click_view_everyone_groups
    wait_for_spinner
    begin
      wait_until(Utils.short_wait) { everyone_group_link_elements.any? }
      groups = everyone_group_link_elements.map do |link|
        CuratedGroup.new id: link.attribute('href').gsub("#{BOACUtils.base_url}/curated/", ''),
                         name: link.text
      end
    rescue
      groups = []
    end
    groups.flatten!
    logger.info "Visible Everyone's Groups are #{groups.map &:name}"
    groups
  end

  # SID LIST ENTRY

  def enter_sid_list(el, sids)
    logger.info "Entering SIDs: '#{sids}'"
    wait_for_element_and_type(el, sids)
  end

  def enter_comma_sep_sids(el, students)
    enter_sid_list(el, students.map(&:sis_id).join(', '))
  end

  def enter_line_sep_sids(el, students)
    enter_sid_list(el, students.map(&:sis_id).join("\n"))
  end

  def enter_space_sep_sids(el, students)
    enter_sid_list(el, students.map(&:sis_id).join(' '))
  end

  div(:unauth_class_page_msg, xpath: '//div[text()="Unauthorized to view course data"]')

end
