require_relative '../../util/spec_helper'

module BOACPagesCreateNoteModal

  include PageObject
  include Logging
  include Page
  include BOACPages


  #### CREATE NOTE, SHARED ELEMENTS ####

  text_area(:new_note_subject_input, id: 'create-note-subject')

  # Enters the subject text for a new note
  # @param note [NoteTemplate]
  def enter_new_note_subject(note)
    logger.debug "Entering new note subject '#{note.subject}'"
    wait_for_element_and_type(new_note_subject_input_element, note.subject)
  end

  # Body

  elements(:note_body_text_area, :text_area, xpath: '//div[@role="textbox"]')

  # Enters the body text for a new note
  # @param note [NoteTemplate]
  def enter_note_body(note)
    logger.debug "Entering note body '#{note.body}'"
    wait_for_textbox_and_type(note_body_text_area_elements[1], note.body)
  end


  # Topics

  text_area(:topic_input, id: 'add-note-topic')
  select_list(:add_topic_select, id: 'add-topic-select-list')
  elements(:topic_option, :option, xpath: '//select[@id="add-topic-select-list"]/option')
  elements(:topic_remove_btn, :button, xpath: '//li[contains(@id, "remove-note-")]')

  # Returns all the canned note topic options shown on the new or edit note UI
  # @return [Array<String>]
  def topic_options
    wait_for_update_and_click add_topic_select_element
    wait_until(1) { add_topic_select_element.options.any? }
    sleep Utils.click_wait
    (topic_option_elements.map { |el| el.attribute 'value' }).delete_if &:empty?
  end

  # Returns the XPath to a topic pill on an unsaved note or on any template
  # @param topic [Topic]
  # @return [String]
  def topic_xpath_unsaved_note(topic)
    "//li[contains(@id, \"note-topic\")][contains(., \"#{topic.name}\")]"
  end

  # Returns the XPath to a topic pill on a saved note
  # @param note [Note]
  # @param topic [Topic]
  # @return [String]
  def topic_xpath_saved_note(note, topic)
    "//li[contains(@id, \"note-#{note.id}-topic\")][contains(., \"#{topic.name}\")]"
  end

  # Returns a topic pill on an unsaved note or on any template
  # @param topic [Topic]
  # @return [Element]
  def new_note_unsaved_topic_pill(topic)
    list_item_element(xpath: topic_xpath_unsaved_note(topic))
  end

  # Returns a topic pill on a saved note
  # @param note [Note]
  # @param topic [Topic]
  # @return [Element]
  def topic_pill(note, topic)
    list_item_element(xpath: topic_xpath_saved_note(note, topic))
  end

  # Returns a topic remove button on an unsaved note or on any template
  # @param topic [Topic]
  # @return [Element]
  def new_note_unsaved_topic_remove_btn(topic)
    button_element(xpath: "#{topic_xpath_unsaved_note(topic)}//button")
  end

  # Returns a topic remove button for a saved note
  # @param note [Note]
  # @param topic [Topic]
  # @return [Element]
  def topic_remove_button(note, topic)
    button_element(xpath: "#{topic_xpath_saved_note(note, topic)}//button")
  end

  # Adds topics to a new or existing note or template
  # @param note [NoteTemplate]
  # @param topics [Array<Topic>]
  def add_topics(note, topics)
    logger.info "Adding topics #{topics.map &:name} to note ID '#{note.id}'"
    topics.each do |topic|
      logger.debug "Adding topic '#{topic.name}'"
      wait_for_element_and_select_js(add_topic_select_element, topic.name)
      if (note.instance_of?(Note) || note.instance_of?(NoteBatch)) && note.id
        topic_pill(note, topic).when_visible Utils.short_wait
      else
        new_note_unsaved_topic_pill(topic).when_visible Utils.short_wait
      end
      note.topics << topic
    end
  end

  # Removes topics from a new or existing note or template
  # @param note [NoteTemplate]
  # @param topics [Array<Topic>]
  def remove_topics(note, topics)
    logger.info "Removing topics #{topics.map &:name} from note ID '#{note.id}'"
    topics.each do |topic|
      logger.debug "Removing topic '#{topic.name}'"
      if (note.instance_of?(Note) || note.instance_of?(NoteBatch)) && note.id
        wait_for_update_and_click topic_remove_button(note, topic)
        topic_pill(note, topic).when_not_visible Utils.short_wait
      else
        wait_for_update_and_click new_note_unsaved_topic_remove_btn(topic)
        new_note_unsaved_topic_pill(topic).when_not_visible Utils.short_wait
      end
      note.topics.delete topic
    end
  end


  # Attachments

  text_area(:new_note_attach_input, xpath: '//div[@id="new-note-modal-container"]//input[@type="file"]')
  span(:note_attachment_size_msg, xpath: '//span[contains(text(),"Attachments are limited to 20 MB in size.")]')
  span(:note_dupe_attachment_msg, xpath: '//span[contains(text(),"Another attachment has the name")]')

  # Returns the delete button for an attachment on an unsaved note
  # @param attachment [Attachment]
  def new_note_attachment_delete_button(attachment)
    list_item_element(xpath: "//li[contains(@id, \"new-note-attachment-\")][contains(., \"#{attachment.file_name}\")]//button")
  end

  # Adds attachments to an unsaved note
  # @param note [NoteTemplate]
  # @param attachments [Array<Attachment>]
  def add_attachments_to_new_note(note, attachments)
    files = attachments.map { |file| Utils.asset_file_path file.file_name }.join("\n")
    logger.debug "Adding attachments '#{files}' to an unsaved note"
    new_note_attach_input_element.send_keys files
    new_note_attachment_delete_button(attachments.last).when_present Utils.short_wait
    sleep Utils.click_wait
    note.attachments << attachments
    note.attachments.flatten!
  end

  # Removes attachments from an unsaved note
  # @param note [NoteTemplate]
  # @param attachments [Array<Attachment>]
  def remove_attachments_from_new_note(note, attachments)
    attachments.each do |attach|
      logger.info "Removing attachment '#{attach.file_name}' from an unsaved note"
      wait_for_update_and_click new_note_attachment_delete_button(attach)
      new_note_attachment_delete_button(attach).when_not_visible Utils.short_wait
      note.attachments.delete attach
      note.updated_date = Time.now
    end
  end

  # Save

  button(:new_note_save_button, id: 'create-note-button')

  # Clicks the save new note button
  def click_save_new_note
    logger.debug 'Clicking the new note Save button'
    wait_for_update_and_click new_note_save_button_element
  end


  # Cancel

  button(:new_note_modal_cancel_button, id: 'cancel-new-note-modal')
  button(:new_note_cancel_button, id: 'create-note-cancel')
  button(:cancel_delete_or_discard_button, id: 'are-you-sure-cancel')

  # Clicks the cancel new note button when the new note modal is in reduced size
  def click_cancel_new_note_modal
    logger.debug 'Clicking the new note Cancel button'
    wait_for_update_and_click new_note_modal_cancel_button_element
  end

  # Clicks the cancel new note button when the new note modal is in expanded size
  def click_cancel_new_note
    wait_for_update_and_click new_note_cancel_button_element
  end

  # Hits the confirm delete/discard button for an uncreated note or removed attachment, unless the browser is Firefox
  def confirm_delete_or_discard
    wait_for_update_and_click confirm_delete_or_discard_button_element unless "#{browser.browser}" == 'firefox'
  end

  def cancel_delete_or_discard
    wait_for_update_and_click cancel_delete_or_discard_button_element
  end


  #### CREATE NOTE, BATCH ####

  text_area(:batch_note_add_student_input, id: 'create-note-add-student-input')
  span(:batch_note_alert_no_students_per_cohorts, id: 'no-students-per-cohorts-alert')
  span(:batch_note_no_students_per_curated_groups, id: 'no-students-per-curated-groups-alert')
  span(:batch_note_no_students, id: 'no-students-alert')
  span(:batch_note_student_count_alert, id: 'target-student-count-alert')
  button(:batch_note_add_cohort_button, xpath: '//button[starts-with(@id, \'batch-note-cohort\')]')
  button(:batch_note_add_curated_group_button, xpath: '//button[starts-with(@id, \'batch-note-curated\')]')

  def added_student_element(student)
    span_element(xpath: "//span[text()=\"#{student.full_name} (#{student.sis_id})\"]")
  end

  def student_remove_button(student)
    button_element(xpath: "//span[text()=\"#{student.full_name} (#{student.sis_id})\"]/following-sibling::button")
  end

  def cohort_dropdown_element(cohort)
    link_element(id: "batch-note-cohort-option-#{cohort.id}")
  end

  def added_cohort_element(cohort)
    span_element(xpath: "//span[contains(@id, \"batch-note-cohort\")][text()=\"#{cohort.name}\"]")
  end

  def cohort_remove_button(cohort)
    button_element(xpath: "//button[@aria-label=\"Remove cohort #{cohort.name}\"]")
  end

  def curated_group_dropdown_element(group)
    link_element(id: "batch-note-curated-option-#{group.id}")
  end

  def added_curated_group_element(group)
    span_element(xpath: "//span[contains(@id, \"batch-note-curated\")][text()=\"#{group.name}\"]")
  end

  def curated_group_remove_button(group)
    button_element(xpath: "//button[@aria-label=\"Remove curated #{group.name}\"]")
  end

  # Adds a given set of students to a batch note
  # @param note_batch [NoteBatch]
  # @param students [Array<BOACUser>]
  def add_students_to_batch(note_batch, students)
    students.each do |student|
      logger.debug "Find student SID '#{student.sis_id}' then add to batch note '#{note_batch.subject}'."
      wait_for_element_and_type(batch_note_add_student_input_element, "#{student.first_name} #{student.last_name} #{student.sis_id}")
      sleep Utils.click_wait
      wait_until(3) { auto_suggest_option_elements.any? }
      student_link_element = auto_suggest_option_elements.find { |el| el.attribute('innerText') == "#{student.full_name} (#{student.sis_id})" }
      wait_for_update_and_click student_link_element
      added_student_element(student).when_present 1
      note_batch.students << student
    end
  end

  # Removes a given set of students from a batch note
  # @param note_batch [NoteBatch]
  # @param students [Array<BOACUser>]
  def remove_students_from_batch(note_batch, students)
    students.each do |student|
      logger.info "Removing SID #{student.sis_id} from batch note"
      wait_for_update_and_click student_remove_button(student)
      added_student_element(student).when_not_visible 2
      note_batch.students.delete student
    end
  end

  # Adds a given set of cohorts to a batch note
  # @param note_batch [NoteBatch]
  # @param [Array<FilteredCohort>]
  def add_cohorts_to_batch(note_batch, cohorts)
    cohorts.each do |cohort|
      logger.debug "Cohort '#{cohort.name}' will be used in creation of batch note '#{note_batch.subject}'."
      wait_for_update_and_click batch_note_add_cohort_button_element
      wait_for_update_and_click cohort_dropdown_element(cohort)
      wait_for_element(added_cohort_element(cohort), Utils.short_wait)
      note_batch.cohorts << cohort
    end
  end

  # Removes a given set of cohorts from a batch note
  # @param note_batch [NoteBatch]
  # @param [Array<FilteredCohort>]
  def remove_cohorts_from_batch(note_batch, cohorts)
    cohorts.each do |cohort|
      logger.info "Removing cohort '#{cohort.name}' from batch note"
      wait_for_update_and_click cohort_remove_button(cohort)
      added_cohort_element(cohort).when_not_visible 1
      note_batch.cohorts.delete cohort
    end
  end

  # Adds a given set of groups to a batch note
  # @param note_batch [NoteBatch]
  # @param [Array<CuratedGroup>]
  def add_curated_groups_to_batch(note_batch, curated_groups)
    curated_groups.each do |curated_group|
      logger.debug "Curated group '#{curated_group.name}' will be used in creation of batch note '#{note_batch.subject}'."
      wait_for_update_and_click batch_note_add_curated_group_button_element
      wait_for_update_and_click curated_group_dropdown_element(curated_group)
      wait_for_element(added_curated_group_element(curated_group), Utils.short_wait)
      note_batch.curated_groups << curated_group
    end
  end

  # Removes a given set of groups from a batch note
  # @param note_batch [NoteBatch]
  # @param [Array<CuratedGroup>]
  def remove_groups_from_batch(note_batch, curated_groups)
    curated_groups.each do |curated_group|
      logger.info "Removing group '#{curated_group.name}' from batch note"
      wait_for_update_and_click curated_group_remove_button (curated_group)
      added_curated_group_element(curated_group).when_not_visible 1
      note_batch.curated_groups.delete curated_group
    end
  end


  #### CREATE NOTE ####

  # Verifies the batch note student count alert
  # @param students [Array<BOACUser>]
  # @param cohorts [Array<FilteredCohort>]
  # @param curated_groups [Array<CuratedGroup>]
  def verify_batch_note_alert(students, cohorts, curated_groups)
    unique_students = unique_students_in_batch(students, cohorts, curated_groups)
    student_count = unique_students.length
    expected_alert = "Note will be added to student #{student_count} record#{student_count == 1 ? '' : 's'}"
    alert_text = batch_note_student_count_alert_element.text
    wait_until(1, "Expected alert '#{expected_alert}', got '#{alert_text}'") { alert_text && alert_text.include?(expected_alert) }
    wait_until(1) { alert_text.include? 'Are you sure?' } if student_count >= 500
  end

  # Combines methods to create a batch of notes, each with the same subject, body, etc. We expect one note per SID, as
  # represented in the cohorts, curated groups and students provided.
  # @param note_batch [NoteBatch]
  # @param topics [Array<Topic>]
  # @param attachments [Array<Attachment>]
  # @param curated_groups [Array<CuratedGroup>]
  # @param cohorts [Array<Cohort>]
  # @param students [Array<Student>]
  def create_batch_of_notes(note_batch, topics, attachments, students, cohorts, curated_groups)
    logger.debug "Create a batch of notes with #{students.length} students, #{cohorts.length} cohorts and #{curated_groups.length} curated_groups"
    click_create_note_batch
    add_students_to_batch(note_batch, students)
    add_cohorts_to_batch(note_batch, cohorts)
    add_curated_groups_to_batch(note_batch, curated_groups)
    enter_new_note_subject note_batch
    enter_note_body note_batch
    add_attachments_to_new_note(note_batch, attachments) if attachments&.any?
    add_topics(note_batch, topics) if topics
    click_save_new_note
    # Give a moment
    sleep Utils.click_wait
    unique_students_in_batch(students, cohorts, curated_groups)
  end

  # Returns the unique students contained in combined arrays of students, cohorts, and curated groups
  # @param students [Array<BOACUser>]
  # @param cohorts [Array<FilteredCohort>]
  # @param curated_groups [Array<CuratedGroup>]
  # @return [Array<BOACUser>]
  def unique_students_in_batch(students, cohorts, curated_groups)
    # Get unique students
    students_by_sid = {}
    students.each { |student| students_by_sid[student.sis_id] = student }
    cohorts.each do |cohort|
      cohort.members.each { |student| students_by_sid[student.sis_id] = student }
    end
    curated_groups.each do |curated_group|
      curated_group.members.each { |student| students_by_sid[student.sis_id] = student }
    end
    students_by_sid.values
  end

  #### TEMPLATES ####

  button(:templates_button, id: 'my-templates-button__BV_toggle_')
  elements(:template_select_option, :link, xpath: '//a[contains(@id, "load-note-template-")]')
  span(:no_templates_msg, xpath: '//div[contains(text(), "You have no saved templates.")]')
  div(:dupe_template_title_msg, xpath: '//div[contains(text(), "You have an existing template with this name. Please choose a different name.")]')

  # Creation

  button(:create_template_button, xpath: '//button[contains(text(), "Save as template")]')
  text_area(:template_title_input, id: 'template-title-input')
  button(:cancel_template_button, id: 'cancel-template-create')
  button(:create_template_confirm_button, id: 'create-template-confirm')

  # Clicks the Create New Template button
  def click_create_template
    logger.info 'Clicking create template button'
    wait_for_update_and_click create_template_button_element
    template_title_input_element.when_present 1
  end

  # Clicks the Save button on the name-your-template modal
  def click_save_template
    logger.info 'Saving the template'
    wait_for_update_and_click create_template_confirm_button_element
  end

  # Clicks the Cancel button on the name-your-template modal
  def click_cancel_template
    logger.info 'Canceling the template'
    wait_for_update_and_click cancel_template_button_element
  end

  # Enters a template title on the name-your-template modal
  def enter_template_title(template)
    logger.info "Entering template title '#{template.title}'"
    wait_for_element_and_type(template_title_input_element, template.title)
  end

  # Creates a template from a note
  # @param template [NoteTemplate]
  # @param note [Note]
  def create_template(template, note)
    click_create_template
    enter_template_title template
    click_save_template
    get_new_template_id template
    template.subject = note.subject
    template.body = note.body
    template.topics = note.topics
    template.attachments = note.attachments
  end

  # Waits for a template record to be created and sets its ID
  # @param template [NoteTemplate]
  def get_new_template_id(template)
    start = Time.now
    wait_until(Utils.long_wait) { template.id = template.get_note_template_id }
    logger.warn "Note template #{template.id} was created in #{Time.now - start} seconds"
  rescue
    logger.debug 'Timed out waiting for note template to be created'
    fail
  end

  # Clicks the Templates button
  def click_templates_button
    logger.info 'Clicking the Templates button'
    wait_for_update_and_click templates_button_element
  end

  # Returns the titles of the user's templates
  # @return [Array<String>]
  def template_options
    template_select_option_elements.map &:text
  end

  # Returns the element for selecting a given template
  # @param template [NoteTemplate]
  # @return [Element]
  def template_option(template)
    link_element(xpath: "//a[@id=\"load-note-template-#{template.id}\"][@title=\"#{template.title}\"]")
  end

  # @param template [NoteTemplate]
  # @param note [Note]
  def apply_template(template, note)
    logger.info "Applying template ID #{template.id}"
    note.subject = template.subject
    note.body = template.body
    note.topics = template.topics
    note.attachments = template.attachments
  end

  # Edit

  span(:edit_template_heading, xpath: '//span[text()="Edit Template"]')
  button(:update_template_button, id: 'btn-update-template')

  # Clicks the edit button for a given template
  # @param template [NoteTemplate]
  def click_edit_template(template)
    logger.info "Editing template ID #{template.id}"
    click_templates_button unless template_select_option_elements.any?(&:visible?)
    sleep Utils.click_wait
    wait_for_update_and_click button_element(id: "btn-edit-note-template-#{template.id}")
  end

  def click_update_template
    logger.info 'Clicking the Update Template button'
    wait_for_update_and_click update_template_button_element
  end

  # Rename

  text_area(:rename_template_input, id: 'rename-template-input')
  button(:save_template_rename_button, id: 'rename-template-confirm')
  button(:cancel_template_rename_button, id: 'cancel-rename-template')

  def click_rename_template(template)
    logger.info "Renaming template ID #{template.id} to #{template.title}"
    click_templates_button unless template_select_option_elements.any?(&:visible?)
    wait_for_update_and_click button_element(id: "btn-rename-note-template-#{template.id}")
  end

  def rename_template(template)
    click_rename_template template
    wait_for_element_and_type(rename_template_input_element, template.title)
    wait_for_update_and_click save_template_rename_button_element
    rename_template_input_element.when_not_present 1
  end

  def click_cancel_template_rename
    wait_for_update_and_click cancel_template_rename_button_element
  end

  # Delete

  # Clicks the delete button for a given template
  # @param template [NoteTemplate]
  def click_delete_template(template)
    click_templates_button unless template_select_option_elements.any?(&:visible?)
    wait_for_update_and_click button_element(id: "btn-delete-note-template-#{template.id}")
  end

  # Deletes a given template
  # @para template [NoteTemplate]
  def delete_template(template)
    logger.info "Deleting template ID #{template.id}"
    click_delete_template template
    wait_for_update_and_click confirm_delete_or_discard_button_element unless "#{browser.browser}" == 'firefox'
  end

end
