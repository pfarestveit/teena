require_relative '../../util/spec_helper'

module BOACPagesCreateNoteModal

  include PageObject
  include Logging
  include Page
  include BOACPages


  #### CREATE NOTE, SHARED ELEMENTS ####

  text_area(:new_note_subject_input, id: 'create-note-subject')

  # Enters the subject text for a new note
  # @param note [Note]
  def enter_new_note_subject(note)
    logger.debug "Entering new note subject '#{note.subject}'"
    wait_for_element_and_type(new_note_subject_input_element, note.subject)
  end

  # Clicks the advanced options button to expose all note features
  def show_adv_note_options
    unless add_topic_button?
      logger.debug 'Clicking the Advanced Note Options button'
      wait_for_update_and_click adv_note_options_button_element
    end
  end

  # Body

  elements(:note_body_text_area, :text_area, xpath: '//div[@role="textbox"]')

  # Enters the body text for a new note
  # @param note [Note]
  def enter_note_body(note)
    logger.debug "Entering note body '#{note.body}'"
    existing_text_length = note_body_text_area_elements[0].attribute('innerText').length
    wait_for_textbox_and_type(note_body_text_area_elements[0], note.body, existing_text_length)
  end


  # Topics

  text_area(:topic_input, id: 'add-note-topic')
  select_list(:add_topic_select, id: 'add-topic-select-list')
  elements(:topic_option, :option, xpath: '//select[@id="add-topic-select-list"]/option')
  button(:add_topic_button, id: 'add-topic-button')
  elements(:topic_remove_btn, :button, xpath: '//li[contains(@id, "remove-note-")]')

  # Returns all the canned note topic options shown on the new or edit note UI
  # @return [Array<String>]
  def topic_options
    wait_for_update_and_click add_topic_select_element
    wait_until(1) { add_topic_select_element.options.any? }
    (topic_option_elements.map { |el| el.attribute 'value' }).delete_if &:empty?
  end

  # Returns the XPath to a topic pill on an unsaved note
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

  # Returns a topic pill for a note, saved or unsaved
  # @param note [Note]
  # @param topic [Topic]
  # @return [PageObject::Element::ListItem]
  def topic_pill(note, topic)
    list_item_element(xpath: (note.id ? topic_xpath_saved_note(note, topic) : topic_xpath_unsaved_note(topic)))
  end

  # Returns a topic remove button for a note, saved or unsaved
  # @param note [Note]
  # @param topic [Topic]
  # @return [PageObject::Element::Button]
  def topic_remove_button(note, topic)
    button_element(xpath: "#{note.id ? topic_xpath_saved_note(note, topic) : topic_xpath_unsaved_note(topic)}//button")
  end

  # Adds topics to a new or existing note.
  # @param note [Note]
  # @param topics [Array<Topic>]
  def add_topics(note, topics)
    logger.info "Adding topics #{topics.map &:name} to note ID '#{note.id}'"
    show_adv_note_options unless topic_input?
    topics.each do |topic|
      logger.debug "Adding topic '#{topic.name}'"
      wait_for_element_and_select_js(add_topic_select_element, topic.name)
      wait_for_update_and_click add_topic_button_element
      topic_pill(note, topic).when_visible Utils.short_wait
      note.topics << topic
    end
  end

  # Removes topics from a new or existing note
  # @param note [Note]
  # @param topics [Array<Topic>]
  def remove_topics(note, topics)
    logger.info "Removing topics #{topics.map &:name} from note ID '#{note.id}'"
    topics.each do |topic|
      logger.debug "Removing topic '#{topic.name}'"
      wait_for_update_and_click topic_remove_button(note, topic)
      topic_pill(note, topic).when_not_visible Utils.short_wait
      note.topics.delete topic
    end
  end


  # Attachments

  button(:adv_note_options_button, id: 'btn-to-advanced-note-options')
  text_area(:new_note_attach_input, xpath: '//div[@class="modal-full-screen"]//input[@type="file"]')
  span(:note_attachment_size_msg, xpath: '//span[contains(text(),"Attachments are limited to 20 MB in size.")]')
  span(:note_dupe_attachment_msg, xpath: '//span[contains(text(),"Another attachment has the name")]')

  # Returns the delete button for an attachment on an unsaved note
  # @param attachment [Attachment]
  def new_note_attachment_delete_button(attachment)
    list_item_element(xpath: "//li[contains(@id, \"new-note-attachment-\")][contains(., \"#{attachment.file_name}\")]//button")
  end

  # Adds attachments to an unsaved note
  # @param note [Note]
  # @param attachments [Array<Attachment>]
  def add_attachments_to_new_note(note, attachments)
    show_adv_note_options
    attachments.each do |attach|
      logger.debug "Adding attachment '#{attach.file_name}' to an unsaved note"
      new_note_attach_input_element.send_keys Utils.asset_file_path(attach.file_name)
      new_note_attachment_delete_button(attach).when_present Utils.short_wait
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
  button(:confirm_delete_or_discard_button, id: 'are-you-sure-confirm')

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
    add_attachments_to_new_note(note_batch, attachments) if attachments
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

end
