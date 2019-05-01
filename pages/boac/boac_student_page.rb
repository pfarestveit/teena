require_relative '../../util/spec_helper'

class BOACStudentPage

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACAddGroupSelectorPages
  include BOACGroupModalPages

  # Loads a student page directly
  # @param user [User]
  def load_page(user)
    logger.info "Loading student page for UID #{user.uid}"
    navigate_to "#{BOACUtils.base_url}/student/#{user.uid}"
    wait_for_title "#{user.full_name}"
    wait_for_spinner
  end

  # SIS PROFILE DATA

  h1(:not_found_msg, xpath: '//h1[text()="Not Found"]')

  div(:preferred_name, :id => 'student-preferred-name')
  span(:sid, id: 'student-bio-sid')
  span(:phone, id: 'student-phone-number')
  link(:email, id: 'student-mailto')
  div(:cumulative_units, xpath: '//div[@id="cumulative-units"]/div')
  div(:cumulative_gpa, id: 'cumulative-gpa')
  div(:inactive_flag, id: 'student-bio-inactive')
  elements(:major, :div, xpath: '//div[@id="student-bio-majors"]//div[@class="bio-header"]')
  elements(:college, :div, xpath: '//div[@id="student-bio-majors"]//div[@class="bio-details"]')
  div(:level, xpath: '//div[@id="student-bio-level"]/div')
  div(:terms_in_attendance, id: 'student-bio-terms-in-attendance')
  div(:expected_graduation, id: 'student-bio-expected-graduation')

  # Returns a user's SIS data visible on the student page
  # @return [Hash]
  def visible_sis_data
    {
      :name => (student_name_heading if student_name_heading?),
      :preferred_name => (preferred_name if preferred_name?),
      :email => (email_element.text if email?),
      :phone => (phone if phone?),
      :cumulative_units => (cumulative_units.gsub("UNITS COMPLETED\n",'').gsub("\nNo data", '') if cumulative_units?),
      :cumulative_gpa => (cumulative_gpa.gsub("CUMULATIVE GPA\n",'').gsub("\nNo data", '').strip if cumulative_gpa?),
      :majors => (major_elements.map { |m| m.text.gsub('Major', '').strip }),
      :colleges => (college_elements.map { |c| c.text.strip }).reject(&:empty?),
      :level => (level.gsub("Level\n",'') if level?),
      :terms_in_attendance => (terms_in_attendance if terms_in_attendance?),
      :expected_graduation => (expected_graduation.gsub('Expected graduation','').strip if expected_graduation?)
    }
  end

  # Returns the link to the student overview page in CalCentral
  # @param student [BOACUser]
  # @return [PageObject::Elements::Link]
  def calcentral_link(student)
    link_element(xpath: "//a[@href='https://calcentral.berkeley.edu/user/overview/#{student.uid}']")
  end

  # TIMELINE

  div(:timeline_loaded_msg, xpath: '//div[text()="Academic Timeline has loaded"]')
  button(:show_hide_all_button, id: 'timeline-tab-all-previous-messages')

  def wait_for_timeline
    timeline_loaded_msg_element.when_present Utils.short_wait
  end

  # Requirements

  button(:reqts_button, id: 'timeline-tab-requirement')
  button(:show_hide_reqts_button, id: 'timeline-tab-requirement-previous-messages')
  div(:writing_reqt, xpath: '//span[contains(text(),"Entry Level Writing")]')
  div(:history_reqt, xpath: '//span[contains(text(),"American History")]')
  div(:institutions_reqt, xpath: '//span[contains(text(),"American Institutions")]')
  div(:cultures_reqt, xpath: '//span[contains(text(),"American Cultures")]')

  # Returns requirements statuses
  # @return [Hash]
  def visible_requirements
    logger.info 'Checking requirements tab'
    wait_for_update_and_click reqts_button_element if reqts_button? && !reqts_button_element.disabled?
    wait_for_update_and_click show_hide_reqts_button_element if show_hide_reqts_button? && show_hide_reqts_button_element.text.include?('Show')
    {
      :reqt_writing => (writing_reqt.gsub('Entry Level Writing', '').strip if writing_reqt_element.exists?),
      :reqt_history => (history_reqt.gsub('American History', '').strip if history_reqt_element.exists?),
      :reqt_institutions => (institutions_reqt.gsub('American Institutions', '').strip if institutions_reqt_element.exists?),
      :reqt_cultures => (cultures_reqt.gsub('American Cultures', '').strip if cultures_reqt_element.exists?)
    }
  end

  # Holds

  button(:holds_button, id: 'timeline-tab-hold')
  button(:show_hide_holds_button, id: 'timeline-tab-hold-previous-messages')
  elements(:hold, :div, xpath: '//div[contains(@id,"timeline-tab-hold-message")]/span[2]')

  # Returns an array of visible hold messages with all whitespace removed
  # @return [Array<String>]
  def visible_holds
    logger.info 'Checking holds tab'
    wait_for_update_and_click holds_button_element if holds_button? && !holds_button_element.disabled?
    wait_for_update_and_click show_hide_holds_button_element if show_hide_holds_button? && show_hide_holds_button_element.text.include?('Show')
    hold_elements.map { |h| h.text.gsub(/\W+/, '') }
  end

  # Alerts

  button(:alerts_button, id: 'timeline-tab-alert')
  button(:show_hide_alerts_button, id: 'timeline-tab-alert-previous-messages')
  elements(:alert, :div, xpath: '//div[contains(@id,"timeline-tab-alert-message")]/span[2]')

  # Returns an array of visible alert messages
  # @return [Array<String>]
  def visible_alerts
    logger.info 'Checking alerts tab'
    wait_for_update_and_click alerts_button_element if alerts_button? && !alerts_button_element.disabled?
    wait_for_update_and_click show_hide_alerts_button_element if show_hide_alerts_button? && show_hide_alerts_button_element.text.include?('Show')
    alert_elements.map { |a| a.text.strip }
  end

  # NOTES - existing

  button(:notes_button, id: 'timeline-tab-note')
  button(:show_hide_notes_button, id: 'timeline-tab-note-previous-messages')
  elements(:note_msg_row, :div, xpath: '//div[contains(@id,"timeline-tab-note-message")]')
  elements(:topic, :list_item, xpath: '//li[contains(@id, "topic")]')

  # Clicks the Notes tab and expands the list of notes
  def show_notes
    logger.info 'Checking notes tab'
    wait_for_update_and_click notes_button_element
    wait_for_update_and_click show_hide_notes_button_element if show_hide_notes_button? && show_hide_notes_button_element.text.include?('Show')
  end

  # Returns the expected sort order of a student's notes
  # @param notes [Array<Note>]
  # @return [Array<String>]
  def expected_note_id_sort_order(notes)
    (notes.sort_by {|n| [n.updated_date, n.created_date] }).reverse.map &:id
  end

  def expected_note_short_date_format(date)
    (Time.now.strftime('%Y') == date.strftime('%Y')) ? date.strftime('%b %-d') : date.strftime('%b %-d, %Y')
  end

  # Returns the expected format for an expanded note date
  def expected_note_long_date_format(date)
    format = (Time.now.strftime('%Y') == date.strftime('%Y')) ? date.strftime('%b %-d %l:%M%P') : date.strftime('%b %-d, %Y %l:%M%P')
    format.gsub(/\s+/, ' ')
  end

  # Returns the visible sequence of note ids
  # @return [Array<String>]
  def visible_collapsed_note_ids
    els = browser.find_elements(xpath: '//div[contains(@id, "note-")][contains(@id, "-is-closed")]')
    els.map do |el|
      parts = el.attribute('id').split('-')
      (parts[2] == 'is') ? parts[1] : parts[1..2].join('-')
    end
  end

  # Returns the note element visible when the note is collapsed
  # @param note [Note]
  # @return [PageObject::Elements::Div]
  def collapsed_note_el(note)
    div_element(id: "note-#{note.id}-is-closed")
  end

  # Returns the button element for collapsing a given note
  # @param note [Note]
  # @return [PageObject::Elements::Button]
  def close_msg_button(note)
    button_element(xpath: "//div[@id='note-#{note.id}-is-closed']/../following-sibling::div/button")
  end

  # Returns the visible note date when the note is collapsed
  # @param note [Note]
  # @return [Hash]
  def visible_collapsed_note_data(note)
    subject_el = div_element(id: "note-#{note.id}-is-closed")
    date_el = div_element(id: "collapsed-note-#{note.id}-created-at")
    {
      :subject => (subject_el.attribute('innerText').gsub("\n", '') if subject_el.exists?),
      :date => (date_el.text.gsub(/\s+/, ' ') if date_el.exists?)
    }
  end

  # Whether or not a given note is expanded
  # @param note [Note]
  # @return [boolean]
  def note_expanded?(note)
    div_element(id: "note-#{note.id}-is-open").exists?
  end

  # Expands a note unless it's already expanded
  # @param note [Note]
  def expand_note(note)
    if note_expanded? note
      logger.debug "Note ID #{note.id} is already expanded"
    else
      logger.debug "Expanding note ID #{note.id}"
      wait_for_update_and_click_js collapsed_note_el(note)
    end
  end

  # Collapses a note unless it's already collapsed
  # @param note [Note]
  def collapse_note(note)
    if note_expanded? note
      logger.debug "Collapsing note ID #{note.id}"
      wait_for_update_and_click close_msg_button(note)
    else
      logger.debug "Note ID #{note.id} is already collapsed"
    end
  end

  # Returns the element containing the note's advisor name
  # @param note [Note]
  # @return [PageObject::Elements::Link]
  def note_advisor_el(note)
    link_element(id: "note-#{note.id}-author-name")
  end

  # Returns the elements containing both downloadable and non-downloadable note attachments
  # @param note [Note]
  # @return [Array<Selenium::WebDriver::Element>]
  def note_attachment_els(note)
    spans = browser.find_elements(xpath: "//li[contains(@id, 'note-#{note.id}-attachment')]//span[contains(@id, '-attachment-')]")
    links = browser.find_elements(xpath: "//li[contains(@id, 'note-#{note.id}-attachment')]//a[contains(@id, '-attachment-')]")
    spans + links
  end

  # Returns the data visible when the note is expanded
  # @params note [Note]
  # @return [Hash]
  def visible_expanded_note_data(note)
    sleep 2
    body_el = span_element(id: "note-#{note.id}-message-open")
    advisor_role_el = span_element(id: "note-#{note.id}-author-role")
    advisor_dept_els = span_elements(xpath: "//span[contains(@id, 'note-#{note.id}-author-dept-')]")
    topic_els = topic_elements.select { |el| el.attribute('id').include? "note-#{note.id}-topic-" }
    created_el = div_element(id: "expanded-note-#{note.id}-created-at")
    updated_el = div_element(id: "expanded-note-#{note.id}-updated-at")
    # The body text area contains formatting elements even without text, so account for that when getting the element's text
    body_text = if body_el.exists?
                  text = body_el.attribute('innerText')
                  text.gsub(/\W/, '').gsub('&nbsp;', '').empty? ? '' : text
                else
                  ''
                end
    {
      :body => body_text.gsub("\n", '').strip,
      :advisor => (note_advisor_el(note).text if note_advisor_el(note).exists?),
      :advisor_role => (advisor_role_el.text if advisor_role_el.exists?),
      :advisor_depts => advisor_dept_els.map(&:text).sort,
      :topics => topic_els.map(&:text).sort,
      :attachments => (note_attachment_els(note).map { |el| el.attribute('innerText').strip }).sort,
      :created_date => (created_el.text.strip.gsub(/\s+/, ' ') if created_el.exists?),
      :updated_date => (updated_el.text.strip.gsub(/\s+/, ' ') if updated_el.exists?)
    }
  end

  # Returns the element containing a given attachment name
  # @param attachment_name [String]
  # @return [Array<PageObject::Elements::Element>]
  def note_attachment_el(note, attachment_name)
    note_attachment_els(note).find { |el| el.text.strip == attachment_name }
  end

  # Downloads an attachment and returns the file size, deleting the file once downloaded
  # @param note [Note]
  # @param attachment [Attachment]
  # @return [File]
  def download_attachment(note, attachment)
    logger.info "Downloading attachment '#{attachment.file_name}' from note ID #{note.id}"
    Utils.prepare_download_dir
    wait_until(Utils.short_wait) { note_attachment_els(note).any? }
    note_attachment_el(note, attachment.file_name).click
    file_path = "#{Utils.download_dir}/#{attachment.file_name}"
    wait_until(Utils.medium_wait) { Dir[file_path].any? }
    file = File.new file_path
    wait_until(Utils.medium_wait) do
      logger.debug "File size is currently #{file.size}, waiting until it reaches #{attachment.file_size}"
      file.size == attachment.file_size
    end
    size = file.size
    Utils.prepare_download_dir
    size
  end

  # Verifies the visible content of a note
  # @param note [Note]
  def verify_note(note)
    logger.debug "Verifying visible data for note ID #{note.id}"

    # Verify data visible when note is collapsed
    collapsed_note_el(note).when_present Utils.medium_wait
    collapse_note note
    visible_data = visible_collapsed_note_data note
    expected_short_updated_date = "Last updated on #{expected_note_short_date_format note.updated_date}"
    wait_until(1, "Expected '#{note.subject}', got #{visible_data[:subject]}") { visible_data[:subject] == note.subject }
    wait_until(1, "Expected '#{expected_short_updated_date}', got #{visible_data[:date]}") { visible_data[:date] == expected_short_updated_date }

    # Verify data visible when note is expanded
    expand_note note
    visible_data.merge!(visible_expanded_note_data note)
    wait_until(1, "Expected '#{note.body}', got '#{visible_data[:body]}'") { visible_data[:body] == "#{note.body}" }
    wait_until(1, 'Expected non-blank advisor name') { !visible_data[:advisor].empty? }
    wait_until(1, 'Expected non-blank advisor role') { !visible_data[:advisor_role].empty? }
    wait_until(1, "Expected '#{note.advisor.depts}', got #{visible_data[:advisor_depts]}") { visible_data[:advisor_depts] == note.advisor.depts }
    # TODO - wait_until(1, "Expected '#{note.topics}', got #{visible_data[:topics]}") { visible_data[:topics] == note.topics }

    # Attachments
    non_deleted_attachments = note.attachments.reject &:deleted_at
    expected_file_names = non_deleted_attachments.map &:file_name
    wait_until(1, "Expected '#{expected_file_names.sort}', got #{visible_data[:attachments].sort}") { visible_data[:attachments].sort == expected_file_names.sort }

    # Check visible timestamps within 1 minute to avoid failures caused by a 1 second diff
    expected_long_created_date = "Created on #{expected_note_long_date_format note.created_date}"
    wait_until(1, "Expected '#{expected_long_created_date}', got #{visible_data[:created_date]}") do
      Time.parse(visible_data[:created_date]) <= Time.parse(expected_long_created_date) + 60
      Time.parse(visible_data[:created_date]) >= Time.parse(expected_long_created_date) - 60
    end
    expected_long_updated_date = "Last updated on #{expected_note_long_date_format note.updated_date}"
    wait_until(1, "Expected '#{expected_long_updated_date}', got #{visible_data[:updated_date]}") do
      Time.parse(visible_data[:updated_date]) <= Time.parse(expected_long_updated_date) + 60
      Time.parse(visible_data[:updated_date]) >= Time.parse(expected_long_updated_date) - 60
    end
  end

  # NOTES - CREATE / EDIT / DELETE

  button(:new_note_button, id: 'new-note-button')
  button(:new_note_minimize_button, id: 'minimize-new-note-modal')

  # Returns the edit note button element for a given note
  # @param note [Note]
  # @return [PageObject::Elements::Button]
  def edit_note_button(note)
    button_element(id: "edit-note-#{note.id}-button")
  end

  # Returns the delete note button element for a given note
  # @param note [Note]
  # @return [PageObject::Elements::Button]
  def delete_note_button(note)
    button_element(xpath: "//tr[descendant::div/@id=\"note-#{note.id}-is-open\"]//button[@id=\"delete-note-button\"]")
  end

  # Clicks the new note button
  def click_create_new_note
    logger.debug 'Clicking the New Note button'
    wait_for_update_and_click new_note_button_element
  end

  # Clicks the edit button for a given note
  # @param note [Note]
  def click_edit_note_button(note)
    logger.debug 'Clicking the Edit Note button'
    wait_for_update_and_click edit_note_button(note)
  end

  # Obtains the ID of a new note and sets current created and updated dates. Fails if the note ID is not available within a defined
  # timeout
  # @param note [Note]
  # @return [Integer]
  def set_new_note_id(note)
    new_note_subject_input_element.when_not_visible Utils.short_wait
    id = ''
    wait_until(Utils.short_wait) { (id = BOACUtils.get_note_id_by_subject note) }
    logger.debug "Note ID is #{id}"
    note.created_date = note.updated_date = Time.now
    id
  rescue
    logger.debug 'Timed out waiting for note ID'
    fail
  end

  # Combines methods to create a note with subject, body, attachments, ID, and created/updated dates
  # @param note [Note]
  # @param attachments [Array<Attachment>]
  def create_note(note, attachments=nil)
    click_create_new_note
    enter_new_note_subject note
    enter_note_body note
    add_attachments_to_new_note(note, attachments) if attachments
    click_save_new_note
    set_new_note_id note
  end

  # Edits an existing note's subject and updated date
  # @param note [Note]
  def edit_note_subject_and_save(note)
    logger.info "Changing note ID #{note.id} subject to '#{note.subject}'"
    expand_note note
    click_edit_note_button note
    enter_edit_note_subject note
    click_save_note_edit
    collapsed_note_el(note).when_visible Utils.short_wait
    note.updated_date = Time.now
  end

  # Deletes a note and sets the deleted date
  # @param note [Note]
  def delete_note(note)
    logger.info "Deleting note '#{note.id}'"
    expand_note note
    wait_for_update_and_click delete_note_button(note)
    wait_for_update_and_click confirm_delete_button_element
    note.deleted_date = Time.now
  end

  # Notes - subject

  text_area(:new_note_subject_input, id: 'create-note-subject')
  text_area(:edit_note_subject_input, id: 'edit-note-subject')
  span(:subj_required_msg, xpath: '//span[text()="Subject is required"]')

  # Enters the subject text for a new note
  # @param note [Note]
  def enter_new_note_subject(note)
    logger.debug "Entering new note subject '#{note.subject}'"
    wait_for_element_and_type(new_note_subject_input_element, note.subject)
  end

  # Enters the subject text for an edit to an existing note
  # @param note [Note]
  def enter_edit_note_subject(note)
    logger.debug "Entering edited note subject '#{note.subject}'"
    wait_for_element_and_type(edit_note_subject_input_element, note.subject)
  end

  # Notes - body

  elements(:note_body_text_area, :text_area, xpath: '//div[@role="textbox"]')

  # Enters the body text for a new note
  # @param note [Note]
  def enter_note_body(note)
    logger.debug "Entering note body '#{note.body}'"
    wait_for_element_and_type(note_body_text_area_elements[0], note.body)
  end

  # Notes - attachments

  button(:adv_note_options_button, id: 'btn-to-advanced-note-options')
  text_area(:new_note_attach_input, xpath: '//div[@class="modal-full-screen"]//input[@type="file"]')
  span(:note_attachment_size_msg, xpath: '//span[contains(text(),"Attachments are limited to 20 MB in size.")]')
  span(:note_dupe_attachment_msg, xpath: '//span[contains(text(),"Another attachment has the name")]')

  # Returns the file input for adding an an attachment to an existing note
  # @param note [Note]
  # @return [PageObject::Elements::TextArea]
  def existing_note_attachment_input(note)
    text_area_element(xpath: "//div[@id='note-#{note.id}-attachment-dropzone']/input")
  end

  # Returns the delete button for an attachment on an unsaved note
  # @param attachment [Attachment]
  def new_note_attachment_delete_button(attachment)
    list_item_element(xpath: "//li[contains(@id, \"new-note-attachment-\")][contains(., \"#{attachment.file_name}\")]//button")
  end

  # Returns the delete button for an attachment on an existing note
  # @param note [Note]
  # @param attachment [Attachment]
  # @return [PageObject::Elements::Button]
  def existing_note_attachment_delete_button(note, attachment)
    list_item_element(xpath: "//div[@id=\"note-#{note.id}-outer\"]//li[contains(., \"#{attachment.file_name}\")]//button")
  end

  # Adds attachments to an unsaved note
  # @param note [Note]
  # @param attachments [Array<Attachment>]
  def add_attachments_to_new_note(note, attachments)
    attachments.each do |attach|
      logger.debug "Adding attachment '#{attach.file_name}' to an unsaved note"
      wait_for_update_and_click adv_note_options_button_element unless new_note_attach_input?
      new_note_attach_input_element.send_keys Utils.asset_file_path(attach.file_name)
      new_note_attachment_delete_button(attach).when_present Utils.short_wait
      sleep Utils.click_wait
      note.attachments << attach
    end
  end

  # Adds a attachments to an existing note
  # @param note [Note]
  # @param attachments [Array<Attachment>]
  def add_attachments_to_existing_note(note, attachments)
    attachments.each do |attach|
      logger.debug "Adding attachment '#{attach.file_name}' to note ID #{note.id}"
      existing_note_attachment_input(note).when_present 1
      existing_note_attachment_input(note).send_keys Utils.asset_file_path(attach.file_name)
      existing_note_attachment_delete_button(note, attach).when_present Utils.short_wait
      sleep Utils.click_wait
      note.attachments << attach
    end
  end

  # Removes attachments from an unsaved note
  # @param note [Note]
  # @param attachments [Array<Attachment>]
  def remove_attachments_from_new_note(note, attachments)
    attachments.each do |attach|
      logger.info "Removing attachment '#{attach.file_name}' from an unsaved note"
      wait_for_update_and_click new_note_attachment_delete_button(attach)
      new_note_attachment_delete_button(attach).when_not_visible Utils.short_wait
      note.attachments.delete attach
    end
  end

  # Removes attachments from an existing note
  # @param note [Note]
  # @param attachments [Array<Attachment>]
  def remove_attachments_from_existing_note(note, attachments)
    attachments.each do |attach|
      logger.info "Removing attachment '#{attach.file_name}' from note ID #{note.id}"
      wait_for_update_and_click existing_note_attachment_delete_button(note, attach)
      confirm_delete
      existing_note_attachment_delete_button(note, attach).when_not_visible Utils.short_wait
      note.attachments.delete attach
      attach.deleted_at = Time.now
    end
  end

  # Notes - save

  button(:new_note_save_button, id: 'create-note-button')
  button(:edit_note_save_button, id: 'save-note-button')

  # Clicks the save new note button
  def click_save_new_note
    logger.debug 'Clicking the new note Save button'
    wait_for_update_and_click new_note_save_button_element
  end

  # Clicks the save note edit button
  def click_save_note_edit
    logger.debug 'Clicking the edit note Save button'
    wait_for_update_and_click edit_note_save_button_element
  end

  # Notes - cancel

  button(:new_note_modal_cancel_button, id: 'cancel-new-note-modal')
  button(:new_note_cancel_button, id: 'create-note-cancel')
  button(:edit_note_cancel_button, id: 'cancel-edit-note-button')
  button(:confirm_delete_button, id: 'are-you-sure-confirm')

  # Clicks the cancel new note button when the new note modal is in reduced size
  def click_cancel_new_note_modal
    logger.debug 'Clicking the new note Cancel button'
    wait_for_update_and_click new_note_modal_cancel_button_element
  end

  # Clicks the cancel new note button when the new note modal is in expanded size
  def click_cancel_new_note
    wait_for_update_and_click new_note_cancel_button_element
  end

  # Clicks the cancel note edit button
  def click_cancel_note_edit
    logger.debug 'Clicking the edit note Cancel button'
    wait_for_update_and_click edit_note_cancel_button_element
  end

  # Hits the confirm delete button for an uncreated note or removed attachment, unless the browser is Firefox
  def confirm_delete
    wait_for_update_and_click confirm_delete_button_element unless "#{browser.browser}" == 'firefox'
  end

  # COURSES

  span(:withdrawal_msg, class: 'red-flag-small')
  button(:view_more_button, :xpath => '//button[contains(.,"Show Previous Semesters")]')

  # Clicks the button to expand previous semester data
  def click_view_previous_semesters
    logger.debug 'Expanding previous semesters'
    scroll_to_bottom
    wait_for_load_and_click view_more_button_element
  end

  # Returns the XPath to a semester's courses
  # @param [String] term_name
  # @return [String]
  def term_data_xpath(term_name)
    "//h3[text()=\"#{term_name}\"]"
  end

  # Returns the total term units and min/max override units shown for a given term
  # @param term_id [Integer]
  # @param term_name [String]
  # @return [Hash]
  def visible_term_data(term_id, term_name)
    term_units_el = span_element(xpath: "#{term_data_xpath term_name}/following-sibling::div[@class=\"student-course-heading student-course\"]//div[@class=\"student-course-heading-units-total\"]/span")
    term_units_min_el = span_element(id: "term-#{term_id}-min-units")
    term_units_max_el = span_element(id: "term-#{term_id}-max-units")
    {
      :term_units => (term_units_el.text.split[1] if term_units_el.exists?),
      :term_units_min => (term_units_min_el.text if term_units_min_el.exists?),
      :term_units_max => (term_units_max_el.text if term_units_max_el.exists?)
    }
  end

  # Returns the XPath to the SIS data shown for a given course in a term
  # @param term_name [String]
  # @param course_code [String]
  # @return [String]
  def course_data_xpath(term_name, course_code)
    "#{term_data_xpath term_name}/following-sibling::div[contains(., \"#{course_code}\")]"
  end

  # Returns the link to a class page
  # @param term_code [String]
  # @param ccn [Integer]
  # @return [PageObject::Elements::Link]
  def class_page_link(term_code, ccn)
    link_element(id: "term-#{term_code}-section-#{ccn}")
  end

  # Clicks the class page link for a given section
  # @param term_code [String]
  # @param ccn [Integer]
  def click_class_page_link(term_code, ccn)
    logger.info "Clicking link for term #{term_code} section #{ccn}"
    start = Time.now
    wait_for_load_and_click class_page_link(term_code, ccn)
    wait_for_spinner
    div_element(:class => 'course-column-schedule').when_visible Utils.short_wait
    logger.warn "Took #{Time.now - start} seconds for the term #{term_code} section #{ccn} page to load"
  end

  # Returns the SIS data shown for a course with a given course code
  # @param term_name [String]
  # @param course_code [String]
  # @return [Hash]
  def visible_course_sis_data(term_name, course_code)
    course_xpath = course_data_xpath(term_name, course_code)
    title_xpath = "#{course_xpath}//div[@class='student-course-name']"
    units_xpath = "#{course_xpath}//div[@class='student-course-heading-units']"
    grading_basis_xpath = "#{course_xpath}//span[@class='student-course-grading-basis']"
    mid_point_grade_xpath = "#{course_xpath}//div[contains(text(),'Mid:')]/span"
    grade_xpath = "#{course_xpath}//div[contains(text(),'Final:')]/span"
    wait_list_xpath = "#{course_xpath}//span[contains(@class,'student-waitlisted')]"
    {
      :title => (h4_element(:xpath => title_xpath).text if h4_element(:xpath => title_xpath).exists?),
      :units_completed => (div_element(:xpath => units_xpath).text.delete('Units').strip if div_element(:xpath => units_xpath).exists?),
      :grading_basis => (span_element(:xpath => grading_basis_xpath).text if span_element(:xpath => grading_basis_xpath).exists?),
      :mid_point_grade => (span_element(:xpath => mid_point_grade_xpath).text.gsub("\n", '') if span_element(:xpath => mid_point_grade_xpath).exists?),
      :grade => (span_element(:xpath => grade_xpath).text if span_element(:xpath => grade_xpath).exists?),
      :wait_list => (span_element(:xpath => wait_list_xpath).exists?)
    }
  end

  # Returns the SIS data shown for a given section in a course at a specific index
  # @param term_name [String]
  # @param course_code [String]
  # @param index [Integer]
  # @return [Hash]
  def visible_section_sis_data(term_name, course_code, index)
    section_xpath = "#{course_data_xpath(term_name, course_code)}//div[@class='student-course-sections']/span[#{index + 1}]"
    {
     :section => (span_element(:xpath => section_xpath).text.delete('(|)').strip if span_element(:xpath => section_xpath).exists?)
    }
  end

  # Returns the element containing a dropped section
  # @param term_name [String]
  # @param course_code [String]
  # @param component [String]
  # @param number [String]
  # @return [PageObject::Elements::Div]
  def visible_dropped_section_data(term_name, course_code, component, number)
    div_element(:xpath => "#{term_data_xpath term_name}//div[@class='student-course student-course-dropped'][contains(.,\"#{course_code} - #{component} #{number}\")]")
  end

  # COURSE SITES

  # Expands course data
  # @param term_name [String]
  # @param course_code [String]
  def expand_course_data(term_name, course_code)
    toggle = button_element(:xpath => "#{course_data_xpath(term_name, course_code)}//button")
    wait_for_update_and_click toggle
  end

  # Returns the XPath to a course site associated with a course in a term
  # @param term_name [String]
  # @param course_code [String]
  # @param index [Integer]
  # @return [String]
  def course_site_xpath(term_name, course_code, index)
    "#{course_data_xpath(term_name, course_code)}//div[@class='student-bcourses-wrapper'][#{index + 1}]"
  end

  # Returns the XPath to a course site in a term not matched to a SIS enrollment
  # @param term_name [String]
  # @param site_code [String]
  # @return [String]
  def unmatched_site_xpath(term_name, site_code)
    "#{term_data_xpath term_name}//h4[text()=\"#{site_code}\"]/ancestor::div[@class='student-course']//div[@class='student-bcourses-wrapper']"
  end

  # Returns the XPath to the user percentile analytics data for a given category, for example 'page views'
  # @param site_xpath [String]
  # @param label [String]
  # @return [String]
  def site_analytics_percentile_xpath(site_xpath, label)
    "#{site_xpath}//th[contains(text(),'#{label}')]/following-sibling::td[1]"
  end

  # Returns the XPath to the detailed score and percentile analytics data for a given category, for example 'page views'
  # @param site_xpath [String]
  # @param label [String]
  # @return [String]
  def site_analytics_score_xpath(site_xpath, label)
    "#{site_xpath}//th[contains(text(),'#{label}')]/following-sibling::td[2]"
  end

  # Returns the XPath to the boxplot graph for a particular set of analytics data for a given site, for example 'page views'
  # @param site_xpath [String]
  # @param label [String]
  # @return [String]
  def site_boxplot_xpath(site_xpath, label)
    "#{site_analytics_score_xpath(site_xpath, label)}#{boxplot_xpath}"
  end

  # Returns the element that triggers the analytics tooltip for a particular set of analytics data for a given site, for example 'page views'
  # @param driver [Selenium::WebDriver]
  # @param site_xpath [String]
  # @param label [String]
  # @return [Selenium::WebDriver::Element]
  def analytics_trigger_element(driver, site_xpath, label)
    driver.find_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}#{boxplot_trigger_xpath}")
  end

  # Checks the existence of a 'no data' message for a particular set of analytics for a given site, for example 'page views'
  # @param site_xpath [String]
  # @param label [String]
  # @return [boolean]
  def no_data?(site_xpath, label)
    cell_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}[contains(.,'No Data')]").exists?
  end

  # Returns the user's percentile displayed for a particular set of analytics data for a given site
  # @param site_xpath [String]
  # @param label [String]
  # @return [String]
  def perc_round(site_xpath, label)
    logger.debug "Hitting XPath: #{site_analytics_percentile_xpath(site_xpath, label)}"
    cell_element(:xpath => "#{site_analytics_percentile_xpath(site_xpath, label)}//strong").text
  end

  # When a boxplot is shown for a set of analytics, returns the user score shown on the tooltip
  # @param site_xpath [String]
  # @param label [String]
  # @return [String]
  def graphable_user_score(site_xpath, label)
    el = div_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}//div[@class='student-chart-tooltip-header']/div[2]")
    el.text if el.exists?
  end

  # When no boxplot is shown for a set of analytics, returns the user score shown
  # @param site_xpath [String]
  # @param label [String]
  # @return [String]
  def non_graphable_user_score(site_xpath, label)
    el = cell_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}/strong")
    el.text if el.exists?
  end

  # When no boxplot is shown for a set of analytics, returns the maximum score shown
  # @param site_xpath [String]
  # @param label [String]
  # @return [String]
  def non_graphable_maximum(site_xpath, label)
    el = cell_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}/span/span")
    el.text if el.exists?
  end

  # Returns all the analytics data shown for a given category, whether with boxplot or without
  # @param driver [Selenium::WebDriver]
  # @param site_xpath [String]
  # @param label [String]
  # @param api_analytics [Hash]
  # @return [Hash]
  def visible_analytics(driver, site_xpath, label, api_analytics)
    # If a boxplot should be present, hover over it to reveal the tooltip detail
    if api_analytics[:graphable]
      wait_until(Utils.short_wait) { analytics_trigger_element(driver, site_xpath, label) }
      mouseover(driver, analytics_trigger_element(driver, site_xpath, label))
      logger.debug "Looking for tooltip header at '#{site_analytics_score_xpath(site_xpath, label)}//div[@class='student-chart-tooltip-header']'"
      div_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}//div[@class='student-chart-tooltip-header']").when_present Utils.short_wait
    end
    tool_tip_detail_elements = driver.find_elements(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}//div[@class='student-chart-tooltip-value']")
    tool_tip_detail = []
    tool_tip_detail = tool_tip_detail_elements.map &:text if tool_tip_detail_elements.any?
    {
      :perc_round => perc_round(site_xpath, label),
      :score => (api_analytics[:graphable] ? graphable_user_score(site_xpath, label) : non_graphable_user_score(site_xpath, label)),
      :max => (api_analytics[:graphable] ? tool_tip_detail[0] : non_graphable_maximum(site_xpath, label)),
      :perc_70 => tool_tip_detail[1],
      :perc_50 => tool_tip_detail[2],
      :perc_30 => tool_tip_detail[3],
      :minimum => tool_tip_detail[4]
    }
  end

  # Returns the assignments-submitted analytics data shown for a given site
  # @param driver [Selenium::WebDriver]
  # @param site_xpath [String]
  # @param api_analytics [Hash]
  # @return [Hash]
  def visible_assignment_analytics(driver, site_xpath, api_analytics)
    visible_analytics(driver, site_xpath, 'Assignments Submitted', api_analytics)
  end

  # Returns the assignments-grades analytics data shown for a given site
  # @param driver [Selenium::WebDriver]
  # @param site_xpath [String]
  # @param api_analytics [Hash]
  # @return [Hash]
  def visible_grades_analytics(driver, site_xpath, api_analytics)
    visible_analytics(driver, site_xpath, 'Assignment Grades', api_analytics)
  end

  # Returns the last activity data shown for a given site
  # @param term_name [String]
  # @param course_code [String]
  # @param index [Integer]
  # @return [String]
  def visible_last_activity(term_name, course_code, index)
    xpath = "#{course_site_xpath(term_name, course_code, index)}//th[contains(.,\"Last bCourses Activity\")]/following-sibling::td/div"
    div_element(:xpath => xpath).when_visible(Utils.click_wait)
    text = div_element(:xpath => xpath).text.strip
    {
      :days => text.split('.')[0],
      :context => text.split('.')[1]
    }
  end

end
