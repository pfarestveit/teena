require_relative '../../util/spec_helper'

module BOACPagesCreateNoteModal

  include PageObject
  include Logging
  include Page


  #### CREATE NOTE, SHARED ELEMENTS ####

  text_area(:new_note_subject_input, id: 'create-note-subject')

  # Enters the subject text for a new note
  # @param note [Note]
  def enter_new_note_subject(note)
    logger.debug "Entering new note subject '#{note.subject}'"
    wait_for_element_and_type(new_note_subject_input_element, note.subject)
  end


  # Body

  elements(:note_body_text_area, :text_area, xpath: '//div[@role="textbox"]')

  # Enters the body text for a new note
  # @param note [Note]
  def enter_note_body(note)
    logger.debug "Entering note body '#{note.body}'"
    wait_for_element_and_type(note_body_text_area_elements[0], note.body)
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

  # Clicks the cancel new note button when the new note modal is in reduced size
  def click_cancel_new_note_modal
    logger.debug 'Clicking the new note Cancel button'
    wait_for_update_and_click new_note_modal_cancel_button_element
  end

  # Clicks the cancel new note button when the new note modal is in expanded size
  def click_cancel_new_note
    wait_for_update_and_click new_note_cancel_button_element
  end


  #### CREATE NOTE, BATCH ####

  button(:batch_note_button, id: 'batch-note-button')
  text_area(:batch_note_add_student_input, id: 'create-note-add-student-input')
  span(:batch_note_alert_no_students_per_cohorts, id: 'no-students-per-cohorts-alert')
  span(:batch_note_no_students_per_curated_groups, id: 'no-students-per-curated-groups-alert')
  span(:batch_note_no_students, id: 'no-students-alert')
  button(:batch_note_add_cohort_button, xpath: '//button[starts-with(@id, \'batch-note-cohort\')]')
  button(:batch_note_add_curated_group_button, xpath: '//button[starts-with(@id, \'batch-note-curated\')]')


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
    add_attachments_to_new_note(note, attachments)
    add_topics(note, topics)
    click_save_new_note
    set_new_note_id note
  end

end
