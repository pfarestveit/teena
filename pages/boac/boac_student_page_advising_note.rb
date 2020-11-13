require_relative '../../util/spec_helper'

module BOACStudentPageAdvisingNote

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACPagesCreateNoteModal
  include BOACStudentPageTimeline
  include BOACApptIntakeDesk

  #### EXISTING NOTES ####

  button(:notes_button, id: 'timeline-tab-note')
  button(:show_hide_notes_button, id: 'timeline-tab-note-previous-messages')
  button(:toggle_all_notes_button, id: 'toggle-expand-all-notes')
  span(:notes_expanded_msg, xpath: '//span[text()="Collapse all notes"]')
  span(:notes_collapsed_msg, xpath: '//span[text()="Expand all notes"]')
  link(:notes_download_link, id: 'download-notes-link')
  elements(:note_msg_row, :div, xpath: '//div[contains(@id,"timeline-tab-note-message")]')

  # Clicks the Notes tab and expands the list of notes
  def show_notes
    logger.info 'Checking notes tab'
    wait_for_update_and_click notes_button_element
    wait_for_update_and_click show_hide_notes_button_element if show_hide_notes_button? && show_hide_notes_button_element.text.include?('Show')
  end

  def expand_all_notes
    logger.info 'Expanding all notes'
    wait_for_update_and_click toggle_all_notes_button_element
    notes_expanded_msg_element.when_visible 2
  end

  def collapse_all_notes
    logger.info 'Collapsing all notes'
    wait_for_update_and_click toggle_all_notes_button_element
    notes_collapsed_msg_element.when_visible 2
  end

  text_field(:timeline_notes_query_input, id: 'timeline-notes-query-input')
  div(:timeline_notes_spinner, id: 'timeline-notes-spinner')

  def search_within_timeline_notes(query)
    wait_for_element_and_type(timeline_notes_query_input_element, query)
    hit_enter
    sleep 1
    timeline_notes_spinner_element.when_not_visible Utils.medium_wait rescue Selenium::WebDriver::Error::StaleElementReferenceError
  end

  def clear_timeline_notes_search
    search_within_timeline_notes ''
  end

  # Returns the expected sort order of a student's notes
  # @param notes [Array<Note>]
  # @return [Array<String>]
  def expected_note_id_sort_order(notes)
    (notes.sort_by {|n| [n.updated_date, n.created_date, n.id] }).reverse.map &:id
  end

  # Returns the visible sequence of note ids
  # @return [Array<String>]
  def visible_collapsed_note_ids
    visible_collapsed_item_ids 'note'
  end

  # Expands a note unless it's already expanded
  # @param note_subject [String]
  def expand_note_by_subject(note_subject)
    note_el = span_element(xpath: "//span[text()=\"#{note_subject}\"]/..")
    wait_for_update_and_click note_el
  end

  # Returns the element containing the note's advisor name
  # @param note [Note]
  # @return [Element]
  def note_advisor_el(note)
    link_element(id: "note-#{note.id}-author-name")
  end

  # Attachments

  element(:sorry_no_attachment_msg, xpath: '//body[text()="Sorry, attachment not available."]')

  # Returns the file input for adding an an attachment to an existing note
  # @param note [Note]
  # @return [Element]
  def existing_note_attachment_input(note)
    text_area_element(xpath: "//div[@id='note-#{note.id}-attachment-dropzone']/input")
  end

  # Returns the delete button for an attachment on an existing note
  # @param note [Note]
  # @param attachment [Attachment]
  # @return [Element]
  def existing_note_attachment_delete_button(note, attachment)
    list_item_element(xpath: "//div[@id=\"note-#{note.id}-outer\"]//li[contains(., \"#{attachment.file_name}\")]//button")
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
      note.updated_date = Time.now
      note.attachments << attach
    end
  end

  # Removes attachments from an existing note
  # @param note [Note]
  # @param attachments [Array<Attachment>]
  def remove_attachments_from_existing_note(note, attachments)
    attachments.each do |attach|
      logger.info "Removing attachment '#{attach.file_name}' from note ID #{note.id}"
      wait_for_update_and_click existing_note_attachment_delete_button(note, attach)
      confirm_delete_or_discard
      existing_note_attachment_delete_button(note, attach).when_not_visible Utils.short_wait
      note.attachments.delete attach
      attach.deleted_at = Time.now
      note.updated_date = Time.now
    end
  end

  # Metadata

  # Returns the data visible when a note is collapsed
  # @param note [Note]
  # @return [Hash]
  def visible_collapsed_note_data(note)
    subject_el = span_element(id: "note-#{note.id}-subject")
    category_el = span_element(id: "note-#{note.id}-category-closed")
    date_el = div_element(id: "collapsed-note-#{note.id}-created-at")
    {
      subject: (subject_el.attribute('innerText') if subject_el.exists?),
      category: (category_el.text if category_el.exists?),
      created_date: (date_el.attribute('innerText').gsub('Last updated on', '').strip if date_el.exists?)
    }
  end

  # Returns the data visible when the note is expanded
  # @param note [Note]
  # @return [Hash]
  def visible_expanded_note_data(note)
    sleep 2
    body_el = span_element(id: "note-#{note.id}-message-open")
    advisor_role_el = span_element(id: "note-#{note.id}-author-role")
    advisor_dept_els = span_elements(xpath: "//span[contains(@id, 'note-#{note.id}-author-dept-')]")
    note_src_el = span_element(xpath: "//tr[@id='permalink-note-#{note.id}']//span[contains(text(), 'note imported from')]")
    topic_els = topic_elements.select { |el| el.attribute('id').include? "note-#{note.id}-topic-" }
    topic_remove_btn_els = topic_remove_btn_elements.select { |el| el.attribute('id').include? "remove-note-#{note.id}-topic" }
    created_el = div_element(id: "expanded-note-#{note.id}-created-at")
    updated_el = div_element(id: "expanded-note-#{note.id}-updated-at")
    permalink_el = link_element(id: "advising-note-permalink-#{note.id}")
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
      :note_src => (note_src_el.text if note_src_el.exists?),
      :topics => topic_els.map(&:text).sort,
      :remove_topics_btns => topic_remove_btn_els,
      :attachments => (item_attachment_els(note).map { |el| el.attribute('innerText').strip }).sort,
      :created_date => (created_el.text.gsub('Created on', '').gsub(/\s+/, ' ').strip if created_el.exists?),
      :updated_date => (updated_el.text.gsub('Last updated on', '').gsub(/\s+/, ' ').strip if updated_el.exists?),
      :permalink_url => (permalink_el.attribute('href') if permalink_el.exists?)
    }
  end

  # Verifies the visible content of a note
  # @param note [Note]
  def verify_note(note)
    logger.debug "Verifying visible data for note ID #{note.id}"

    # Verify data visible when note is collapsed

    collapsed_item_el(note).when_present Utils.medium_wait
    collapse_item note
    visible_data = visible_collapsed_item_data note
    expected_short_updated_date = "Last updated on #{expected_item_short_date_format note.updated_date}"
    wait_until(1, "Expected '#{note.subject}', got #{visible_data[:subject]}") { visible_data[:subject] == note.subject }
    wait_until(1, "Expected '#{expected_short_updated_date}', got #{visible_data[:date]}") { visible_data[:date] == expected_short_updated_date }

    # Verify data visible when note is expanded
    expand_item note
    visible_data.merge!(visible_expanded_note_data note)
    wait_until(1, "Expected '#{note.body}', got '#{visible_data[:body]}'") { visible_data[:body] == "#{note.body}" }
    wait_until(1, "Expected '#{note.advisor.full_name.downcase}', got '#{visible_data[:advisor].downcase}'") do
      visible_data[:advisor].downcase == note.advisor.full_name.downcase
    end
    wait_until(1, 'Expected non-blank advisor role') { !visible_data[:advisor_role].empty? }
    wait_until(1) { !visible_data[:advisor_depts].any?(&:empty?) }

    # Topics
    note_topics = (note.topics.map { |t| t.name.upcase }).sort
    wait_until(1, "Expected '#{note_topics}', got #{visible_data[:topics]}") { visible_data[:topics] == note_topics }
    wait_until(1, "Expected no remove-topic buttons, got #{visible_data[:remove_topics_btns].length}") { visible_data[:remove_topics_btns].length.zero? }

    # Attachments
    non_deleted_attachments = note.attachments.reject &:deleted_at
    expected_file_names = non_deleted_attachments.map &:file_name
    wait_until(1, "Expected '#{expected_file_names.sort}', got #{visible_data[:attachments].sort}") { visible_data[:attachments].sort == expected_file_names.sort }

    # Check visible timestamps within 1 minute to avoid failures caused by a 1 second diff
    expected_long_created_date = "Created on #{expected_item_long_date_format note.created_date}"
    wait_until(1, "Expected '#{expected_long_created_date}', got #{visible_data[:created_date]}") do
      Time.parse(visible_data[:created_date]) <= Time.parse(expected_long_created_date) + 60
      Time.parse(visible_data[:created_date]) >= Time.parse(expected_long_created_date) - 60
    end
    unless note.instance_of?(NoteBatch) || (note.updated_date == note.created_date) || !note.updated_date
      expected_long_updated_date = "Last updated on #{expected_item_long_date_format note.updated_date}"
      wait_until(1, "Expected '#{expected_long_updated_date}', got #{visible_data[:updated_date]}") do
        Time.parse(visible_data[:updated_date]) <= Time.parse(expected_long_updated_date) + 60
        Time.parse(visible_data[:updated_date]) >= Time.parse(expected_long_updated_date) - 60
      end
    end
  end

  #### EDIT / DELETE ####

  # Returns the edit note button element for a given note
  # @param note [Note]
  # @return [Element]
  def edit_note_button(note)
    button_element(id: "edit-note-#{note.id}-button")
  end

  # Returns the delete note button element for a given note
  # @param note [Note]
  # @return [Element]
  def delete_note_button(note)
    button_element(xpath: "//tr[descendant::div/@id=\"note-#{note.id}-is-open\"]//button[@id=\"delete-note-button\"]")
  end

  # Clicks the edit button for a given note
  # @param note [Note]
  def click_edit_note_button(note)
    logger.debug 'Clicking the Edit Note button'
    wait_for_update_and_click edit_note_button(note)
  end

  # Edits an existing note's subject and updated date
  # @param note [Note]
  def edit_note_subject_and_save(note)
    logger.info "Changing note ID #{note.id} subject to '#{note.subject}'"
    expand_item note
    click_edit_note_button note
    enter_edit_note_subject note
    click_save_note_edit
    edit_note_save_button_element.when_not_present Utils.short_wait
    collapsed_item_el(note).when_visible Utils.short_wait
    note.updated_date = Time.now
  end

  # Deletes a note and sets the deleted date
  # @param note [Note]
  def delete_note(note)
    logger.info "Deleting note '#{note.id}'"
    expand_item note
    wait_for_update_and_click delete_note_button(note)
    confirm_delete_or_discard
    note.deleted_date = Time.now
  end

  # Subject

  text_area(:edit_note_subject_input, id: 'edit-note-subject')
  span(:subj_required_msg, xpath: '//span[text()="Subject is required"]')

  # Enters the subject text for an edit to an existing note
  # @param note [Note]
  def enter_edit_note_subject(note)
    logger.debug "Entering edited note subject '#{note.subject}'"
    wait_for_element_and_type(edit_note_subject_input_element, note.subject)
  end

  # Save

  button(:edit_note_save_button, id: 'save-note-button')

  # Clicks the save note edit button
  def click_save_note_edit
    logger.debug 'Clicking the edit note Save button'
    wait_for_update_and_click edit_note_save_button_element
  end

  # Cancel

  button(:edit_note_cancel_button, id: 'cancel-edit-note-button')

  # Clicks the cancel note edit button
  def click_cancel_note_edit
    logger.debug 'Clicking the edit note Cancel button'
    wait_for_update_and_click edit_note_cancel_button_element
  end

  #### CREATE NOTE, STUDENT PROFILE ####

  button(:new_note_button, id: 'new-note-button')
  button(:new_note_minimize_button, id: 'minimize-new-note-modal')

  # Clicks the new note button
  def click_create_new_note
    logger.debug 'Clicking the New Note button'
    wait_for_update_and_click new_note_button_element
  end

  # Combines methods to create a note with subject, body, attachments, topics, ID, and created/updated dates
  # @param note [Note]
  # @param topics [Array<Topic>]
  # @param attachments [Array<Attachment>]
  def create_note(note, topics, attachments)
    click_create_new_note
    enter_new_note_subject note
    enter_note_body note
    add_attachments_to_new_note(note, attachments) if attachments&.any?
    add_topics(note, topics)
    click_save_new_note
    set_new_note_id note
  end

  # Returns the expected file name of a note export zip
  # @param student [BOACUser]
  # @return [String]
  def notes_export_zip_file_name(student)
    "advising_notes_#{student.first_name.downcase}_#{student.last_name.downcase}_#{Time.now.strftime('%Y%m%d')}.zip"
  end

  # Returns the expected file name of a note export csv
  # @param student [BOACUser]
  # @return [String]
  def notes_export_csv_file_name(student)
    notes_export_zip_file_name(student).gsub('zip', 'csv')
  end

  # Clicks the notes download link and waits for the expected zip file to appear in the configured download dir
  # @param student [BOACUser]
  def download_notes(student)
    logger.info "Downloading notes for UID #{student.uid}"
    Utils.prepare_download_dir
    sleep Utils.click_wait
    wait_for_update_and_click notes_download_link_element
    wait_until(Utils.medium_wait) { Dir["#{Utils.download_dir}/#{notes_export_zip_file_name student}"].any? }
  end

  # Returns all the file names within a given zip file
  # @param student [BOACUser]
  # @return [Array<String>]
  def note_export_file_names(student)
    file_names = []
    Zip::File.open("#{Utils.download_dir}/#{notes_export_zip_file_name student}") do |zip_file|
      zip_file.each { |entry| file_names << entry.name }
    end
    file_names
  end

  # Returns the file names that should be present in a note export zip file
  # @param student [BOACUser]
  # @param notes [Array<Notes>]
  # @return [Array<String>]
  def expected_note_export_file_names(student, notes)
    names = []
    names << notes_export_csv_file_name(student)
    notes.map(&:attachments).flatten.group_by(&:file_name).each_value do |dupe_names|
      dupe_names.each_with_index do |a, i|
        parts = [a.file_name.rpartition('.').first, a.file_name.rpartition('.').last]
        names << "#{parts.first}#{ +' (' + i.to_s + ')' unless i.zero?}.#{parts.last}"
      end
    end
    names
  end

  # Converts a note export CSV file to a CSV table
  # @param student [BOACUser]
  def parse_note_export_csv_to_table(student)
    Zip::File.open("#{Utils.download_dir}/#{notes_export_zip_file_name student}") do |zip_file|
      zipped_csv = zip_file.find_entry notes_export_csv_file_name(student)
      file = File.join(Utils.download_dir, notes_export_csv_file_name(student))
      CSV.open(file, 'wb') do |csv|
        CSV.parse(zipped_csv.get_input_stream.read).each { |row| csv << row }
      end
      CSV.table file
    end
  end

  # Returns true if a parsed CSV contains a row with data matching a given note
  # @param student [BOACUser]
  # @param note [Note]
  # @param csv_table [CSV::Table]
  def verify_note_in_export_csv(student, note, csv_table)
    wait_until(1, "Couldn't find note ID #{note.id}") do
      csv_table.find do |r|
        r[:date_created] == note.created_date.strftime('%Y-%m-%d')
        r[:student_sid] == student.sis_id.to_i
        r[:student_name] == student.full_name
        if note.advisor
          (r[:author_uid] == note.advisor.uid.to_i) unless (note.advisor.uid == 'UCBCONVERSION')
        end
        r[:subject] == note.subject
        Nokogiri::HTML(r[:body]).text == "#{note.body}"
        if note.topics.any?
          ((r[:topics].split(';').map(&:strip).map(&:downcase).sort if r[:topics]) == note.topics.map(&:downcase).sort)
        else
          !r[:topics]
        end
        if note.attachments.any?
          ((r[:attachments].split(';').map(&:strip).sort if r[:attachments]) == note.attachments.map(&:file_name).sort)
        else
          !r[:attachments]
        end
      end
    end
  end

end
