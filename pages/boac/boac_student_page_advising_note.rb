require_relative '../../util/spec_helper'

module BOACStudentPageAdvisingNote

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACPagesCreateNoteModal
  include BOACStudentPageTimeline

  #### E-FORMS ####

  button(:e_forms_button, id: 'timeline-tab-eForm')
  button(:show_hide_e_forms_button, id: 'toggle-expand-all-eForms')
  link(:e_forms_download_link, id: 'download-notes-link')

  def show_e_forms
    logger.info 'Checking eForms tab'
    wait_for_update_and_click e_forms_button_element
    wait_for_update_and_click show_hide_e_forms_button_element if show_hide_e_forms_button? && show_hide_e_forms_button_element.text.include?('Show')
  end

  #### EXISTING NOTES ####

  button(:notes_button, id: 'timeline-tab-note')
  button(:show_hide_notes_button, id: 'timeline-tab-note-previous-messages')
  button(:toggle_all_notes_button, id: 'toggle-expand-all-notes')
  span(:notes_expanded_msg, xpath: '//span[text()="Collapse all notes"]')
  span(:notes_collapsed_msg, xpath: '//span[text()="Expand all notes"]')
  link(:notes_download_link, id: 'download-notes-link')
  elements(:note_msg_row, :div, xpath: '//div[contains(@id,"timeline-tab-note-message")]')
  span(:draft_note_flag, xpath: '//span[text()="Draft"]')

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
    timeline_notes_spinner_element.when_not_visible Utils.short_wait rescue Selenium::WebDriver::Error::StaleElementReferenceError
  end

  def clear_timeline_notes_search
    search_within_timeline_notes ''
  end

  # Returns the expected sort order of a student's notes
  # @param notes [Array<Note>]
  # @return [Array<String>]
  def expected_note_id_sort_order(notes)
    notes.sort_by { |n| [((n.set_date if (n.instance_of?(Note) || n.instance_of?(NoteBatch))) || n.created_date), n.id] }.reverse.map &:id
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

  # Metadata

  # Returns the data visible when a note is collapsed
  # @param note [Note]
  # @return [Hash]
  def visible_collapsed_note_data(note)
    subject_el = span_element(id: "note-#{note.id}-subject")
    category_el = span_element(id: "note-#{note.id}-category-closed")
    date_el = div_element(id: "collapsed-note-#{note.id}-created-at")
    draft_el = span_element(id: "note-#{note.id}-is-draft")
    {
      subject: (subject_el.attribute('innerText') if subject_el.exists?),
      category: (category_el.text if category_el.exists?),
      created_date: (date_el.text.gsub('Last updated on', '').strip if date_el.exists?),
      is_draft: draft_el.exists?
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
    set_date_el = div_element(id: "expanded-note-#{note.id}-set-date")
    permalink_el = link_element(id: "advising-note-permalink-#{note.id}")
    contact_type_el = div_element(id: "note-#{note.id}-contact-type")
    # The body text area contains formatting elements even without text, so account for that when getting the element's text
    body_text = if body_el.exists?
                  text = body_el.text
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
      :attachments => (item_attachment_els(note).map { |el| el.text.strip }).sort,
      :created_date => (created_el.text.gsub('Created on', '').gsub(/\s+/, ' ').strip if created_el.exists?),
      :updated_date => (updated_el.text.gsub('Last updated on', '').gsub(/\s+/, ' ').strip if updated_el.exists?),
      :set_date => (set_date_el.text.gsub(/\s+/, ' ').strip if set_date_el.exists?),
      :permalink_url => (permalink_el.attribute('href') if permalink_el.exists?),
      :contact_type => (contact_type_el.text if contact_type_el.exists?)
    }
  end

  def e_form_data_el(e_form, label)
    div_element(xpath: "//tr[@id='permalink-eForm-#{e_form.id}']//dt[text()='#{label}']/following-sibling::dd")
  end

  def visible_expanded_e_form_data(e_form)
    sleep 1
    created_el = div_element(id: "expanded-eForm-#{e_form.id}-created-at")
    updated_el = div_element(id: "expanded-eForm-#{e_form.id}-updated-at")
    term_el = e_form_data_el(e_form, 'Term')
    course_el = e_form_data_el(e_form, 'Course')
    action_el = e_form_data_el(e_form, 'Action')
    form_id_el = e_form_data_el(e_form, 'Form ID')
    date_init_el = e_form_data_el(e_form, 'Date Initiated')
    status_el = e_form_data_el(e_form, 'Form Status ')
    date_final_el = e_form_data_el(e_form, 'Final Date & Time Stamp')
    {
      created_date: (created_el.text.gsub('Created on', '').gsub(/\s+/, ' ').strip if created_el.exists?),
      updated_date: (updated_el.text.gsub('Last updated on', '').gsub(/\s+/, ' ').strip if updated_el.exists?),
      term: (term_el.text if term_el.exists?),
      course: (course_el.text if course_el.exists?),
      action: (action_el.text if action_el.exists?),
      form_id: (form_id_el.text if form_id_el.exists?),
      date_initiated: (date_init_el.text if date_init_el.exists?),
      status: (status_el.text if status_el.exists?),
      date_finalized: (date_final_el.text if date_final_el.exists?)
    }
  end

  # Verifies the visible content of a note
  # @param note [Note]
  def verify_note(note, viewer)
    logger.debug "Verifying visible data for note ID #{note.id}"

    # Verify data visible when note is collapsed

    collapsed_item_el(note).when_present Utils.medium_wait
    sleep 1
    collapse_item note
    visible_data = visible_collapsed_item_data note
    date = note.set_date || note.updated_date
    expected_short_updated_date = "Last updated on #{expected_item_short_date_format date}"
    wait_until(1, "Expected '#{note.subject}', got #{visible_data[:subject]}") { visible_data[:subject] == note.subject }
    wait_until(1, "Expected '#{expected_short_updated_date}', got #{visible_data[:date]}") { visible_data[:date] == expected_short_updated_date }

    # Verify data visible when note is expanded

    expand_item note
    visible_data.merge!(visible_expanded_note_data note)
    if note.advisor.full_name
      wait_until(1, "Expected '#{note.advisor.full_name.downcase}', got '#{visible_data[:advisor].downcase}'") do
        visible_data[:advisor].downcase == note.advisor.full_name.downcase
      end
    else
      wait_until(1, 'Expected non-blank advisor name') { !visible_data[:advisor].empty? }
    end
    unless note.source == TimelineRecordSource::EOP
      wait_until(1, 'Expected non-blank advisor role') { !visible_data[:advisor_role].empty? }
    end
    wait_until(1) { !visible_data[:advisor_depts].any?(&:empty?) }

    # Topics
    note_topics = (note.topics.map { |t| t.instance_of?(Topic) ? t.name.upcase : t.upcase }).sort
    wait_until(1, "Expected '#{note_topics}', got #{visible_data[:topics]}") { visible_data[:topics] == note_topics }
    wait_until(1, "Expected no remove-topic buttons, got #{visible_data[:remove_topics_btns].length}") { visible_data[:remove_topics_btns].length.zero? }

    # Contact Type
    wait_until(1, "Expected '#{note.type}', got #{visible_data[:contact_type]}") do
      note.type ? (visible_data[:contact_type] == note.type) : !visible_data[:contact_type]
    end

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
    expected_set_date = note.set_date ? "#{expected_item_short_date_format note.set_date}" : nil
    wait_until(1, "Expected set date '#{expected_set_date}', got #{visible_data[:set_date]}") do
      visible_data[:set_date] == expected_set_date
    end

    # Body and attachments - private versus non-private

    if note.is_private && !viewer.is_admin && !viewer.depts.include?(BOACDepartments::ZCEEE)
      # Body should be hidden
      wait_until(1, "Expected no body, got '#{visible_data[:body]}'") { visible_data[:body].empty? }
      # Attachments should be hidden
      wait_until(1, "Expected no attachments, got #{visible_data[:attachments].sort}") do
        visible_data[:attachments].empty?
      end
    else
      # Body should be visible
      wait_until(1, "Expected '#{note.body}', got '#{visible_data[:body]}'") do
        visible_data[:body] == "#{note.body}"
      end
      # Attachments should be visible
      non_deleted_attachments = note.attachments.reject &:deleted_at
      expected_file_names = non_deleted_attachments.map &:file_name
      wait_until(1, "Expected '#{expected_file_names.sort}', got #{visible_data[:attachments].sort}") do
        visible_data[:attachments].sort == expected_file_names.sort
      end
    end
  end

  #### EDIT / DELETE ####

  div(:draft_note_warning, xpath: '//div[text()=" You are editing a draft note. "]')

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
    button_element(id: "delete-note-button-#{note.id}")
  end

  # Clicks the edit button for a given note
  # @param note [Note]
  def click_edit_note_button(note)
    logger.debug 'Clicking the Edit Note button'
    wait_for_update_and_click edit_note_button(note)
  end

  def save_note_edit(note)
    click_save_note_edit
    edit_note_save_button_element.when_not_present Utils.short_wait
    collapsed_item_el(note).when_visible Utils.short_wait
    note.updated_date = Time.now
  end

  # Edits an existing note's subject and updated date
  # @param note [Note]
  def edit_note_subject_and_save(note)
    logger.info "Changing note ID #{note.id} subject to '#{note.subject}'"
    expand_item note
    click_edit_note_button note
    enter_edit_note_subject note
    save_note_edit note
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
    set_note_privacy note
    enter_set_date note if note.set_date
    select_contact_type note if note.type
    click_save_new_note
    set_new_note_id note
  end

  def notes_export_zip_file_name(student)
    "advising_notes_#{student.first_name.downcase}_#{student.last_name.downcase}_#{Time.now.strftime('%Y%m%d')}.zip"
  end

  def e_forms_export_zip_file_name(student)
    "advising_eForms_#{student.first_name.downcase}_#{student.last_name.downcase}_#{Time.now.strftime('%Y%m%d')}.zip"
  end

  def notes_export_csv_file_name(student)
    notes_export_zip_file_name(student).gsub('zip', 'csv')
  end

  def e_forms_export_csv_file_name(student)
    e_forms_export_zip_file_name(student).gsub('zip', 'csv')
  end

  def download_notes(student)
    logger.info "Downloading notes for UID #{student.uid}"
    Utils.prepare_download_dir
    sleep Utils.click_wait
    wait_for_update_and_click notes_download_link_element
    wait_until(Utils.medium_wait) { Dir["#{Utils.download_dir}/#{notes_export_zip_file_name student}"].any? }
  end

  def download_e_forms(student)
    logger.info "Downloading eForms for UID #{student.uid}"
    Utils.prepare_download_dir
    sleep Utils.click_wait
    wait_for_update_and_click notes_download_link_element
    wait_until(Utils.medium_wait) { Dir["#{Utils.download_dir}/#{e_forms_export_zip_file_name student}"].any? }
  end

  def note_export_file_names(student)
    file_names = []
    Zip::File.open("#{Utils.download_dir}/#{notes_export_zip_file_name student}") do |zip_file|
      zip_file.each { |entry| file_names << entry.name }
    end
    file_names
  end

  def e_form_export_file_names(student)
    file_names = []
    Zip::File.open("#{Utils.download_dir}/#{e_forms_export_zip_file_name student}") do |zip_file|
      zip_file.each { |entry| file_names << entry.name }
    end
    file_names
  end

  def expected_note_export_file_names(student, notes, downloader)
    names = []
    names << notes_export_csv_file_name(student)
    attachments = []
    notes.map do |n|
      unless n.instance_of?(TimelineEForm) || (n.is_private && !downloader.is_admin && !downloader.depts.include?(BOACDepartments::ZCEEE))
        n.attachments.delete_if &:deleted_at
        attachments += n.attachments
      end
    end
    attachments.flatten!
    attachments.group_by(&:file_name).each_value do |dupe_names|
      dupe_names.each_with_index do |a, i|
        parts = [a.file_name.rpartition('.').first, a.file_name.rpartition('.').last]
        names << "#{parts.first}#{ +' (' + i.to_s + ')' unless i.zero?}.#{parts.last}"
      end
    end
    names
  end

  def expected_e_form_export_file_names(student)
    [e_forms_export_csv_file_name(student)]
  end

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

  def parse_e_forms_export_csv_to_table(student)
    Zip::File.open("#{Utils.download_dir}/#{e_forms_export_zip_file_name student}") do |zip_file|
      zipped_csv = zip_file.find_entry e_forms_export_csv_file_name(student)
      file = File.join(Utils.download_dir, e_forms_export_csv_file_name(student))
      CSV.open(file, 'wb') do |csv|
        CSV.parse(zipped_csv.get_input_stream.read).each { |row| csv << row }
      end
      CSV.table file
    end
  end

  def verify_note_in_export_csv(student, note, csv_table, downloader)
    wait_until(1, "Couldn't find note ID #{note.id}") do
      begin
        csv_table.find do |r|
          r[:date_created] == note.created_date.strftime('%Y-%m-%d')
          r[:student_sid] == student.sis_id.to_i
          r[:student_name] == student.full_name
          if note.advisor
            (r[:author_uid] == note.advisor.uid.to_i) unless (note.advisor.uid == 'UCBCONVERSION')
          end

          r[:subject] == note.subject if note.subject

          if !note.body || (note.is_private && !downloader.is_admin && !downloader.depts.include?(BOACDepartments::ZCEEE.code))
            !r[:body]
          end

          if note.topics&.any?
            expected_topics = note.topics.map { |t| t.instance_of?(Topic) ? t.name.downcase : t.downcase }.sort
            ((r[:topics].split(';').map(&:strip).map(&:downcase).sort if r[:topics]) == expected_topics)
          else
            !r[:topics]
          end

          if note.attachments&.empty? || (note.is_private && !downloader.is_admin && !downloader.depts.include?(BOACDepartments::ZCEEE.code))
            !r[:attachments]
          else
            ((r[:attachments].split(';').map(&:strip).sort if r[:attachments]) == note.attachments.map(&:file_name).sort)
          end
        end
      rescue => e
        logger.error "#{e.message}\n#{e.backtrace}"
        fail
      end
    end
  end

  def verify_e_form_in_export_csv(student, e_form, csv_table)
    wait_until(1, "Couldn't find eForm ID #{e_form.id}") do
      begin
        csv_table.find do |r|
          r[:date_created] == e_form.created_date.strftime('%Y-%m-%d')
          r[:student_sid] == student.sis_id.to_i
          r[:student_name] == student.full_name
          r[:eform_id] == e_form.form_id
          r[:late_change_request_action] == e_form.action if e_form.action
          r[:grading_basis] == e_form.grading_basis if e_form.grading_basis
          r[:requested_grading_basis] == e_form.requested_grading_basis
          r[:units_taken] == e_form.units_taken if e_form.units_taken
          r[:requested_units_taken] == e_form.requested_units_taken if e_form.requested_units_taken
          r[:late_change_request_status] == e_form.status if e_form.status
          r[:late_change_request_term] == e_form.term if e_form.term
          r[:late_change_request_course] == e_form.course
        end
      rescue => e
        logger.error "#{e.message}\n#{e.backtrace}"
        fail
      end
    end
  end
end
