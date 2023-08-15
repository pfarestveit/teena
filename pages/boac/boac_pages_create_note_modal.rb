require_relative '../../util/spec_helper'

module BOACPagesCreateNoteModal

  include PageObject
  include Logging
  include Page
  include BOACPages

  #### DRAFT NOTE ####

  button(:save_as_draft_button, id: 'save-as-draft-button')
  button(:update_draft_button, xpath: '//button[text()=" Update Draft "]')
  h3(:edit_draft_heading, xpath: '//h3[text()=" Edit Draft Note "]')

  def click_save_as_draft
    logger.info 'Clicking the save-as-draft button'
    wait_for_update_and_click save_as_draft_button_element
    save_as_draft_button_element.when_not_present Utils.medium_wait
  end

  def click_update_note_draft
    logger.info 'Clicking the update draft button'
    wait_for_update_and_click update_draft_button_element
  end

  #### CREATE NOTE, SHARED ELEMENTS ####

  text_area(:new_note_subject_input, id: 'create-note-subject')

  def enter_new_note_subject(note)
    logger.debug "Entering new note subject '#{note.subject}'"
    wait_for_textbox_and_type(new_note_subject_input_element, note.subject)
  end

  text_area(:edit_note_subject_input, id: 'edit-note-subject')
  span(:subj_required_msg, xpath: '//span[text()="Subject is required"]')

  # Enters the subject text for an edit to an existing note
  # @param note [Note]
  def enter_edit_note_subject(note)
    logger.debug "Entering edited note subject '#{note.subject}'"
    wait_for_element_and_type(edit_note_subject_input_element, note.subject)
  end

  # Body

  elements(:note_body_text_area, :text_area, xpath: '//div[@role="textbox"]')

  def wait_for_note_body_editor
    wait_until(Utils.short_wait) { note_body_text_area_elements.any? }
  end

  def enter_note_body(note)
    logger.debug "Entering note body '#{note.body}'"
    wait_for_note_body_editor
    wait_for_textbox_and_type(note_body_text_area_elements[1], note.body)
  end


  # Topics

  text_area(:topic_input, id: 'add-note-topic')
  select_list(:add_topic_select, id: 'add-topic-select-list')
  elements(:topic_option, :option, xpath: '//select[@id="add-topic-select-list"]/option')
  elements(:topic_remove_btn, :button, xpath: '//li[contains(@id, "remove-note-")]')

  def topic_options
    wait_for_update_and_click add_topic_select_element
    wait_until(1) { add_topic_select_element.options.any? }
    sleep Utils.click_wait
    (topic_option_elements.map { |el| el.attribute 'value' }).delete_if &:empty?
  end

  def topic_xpath_unsaved_note(topic)
    "//li[contains(@id, \"note-topic\")][contains(., \"#{topic.name}\")]"
  end

  def topic_xpath_saved_note(note, topic)
    "//li[contains(@id, \"note-#{note.id}-topic\")][contains(., \"#{topic.name}\")]"
  end

  def new_note_unsaved_topic_pill(topic)
    list_item_element(xpath: topic_xpath_unsaved_note(topic))
  end

  def topic_pill(note, topic)
    list_item_element(xpath: topic_xpath_saved_note(note, topic))
  end

  def new_note_unsaved_topic_remove_btn(topic)
    button_element(xpath: "#{topic_xpath_unsaved_note(topic)}//button")
  end

  def topic_remove_button(note, topic)
    button_element(xpath: "#{topic_xpath_saved_note(note, topic)}//button")
  end

  def add_topics(note, topics)
    logger.info "Adding topics #{topics.map &:name} to note ID '#{note.id}'"
    topics.each do |topic|
      logger.debug "Adding topic '#{topic.name}'"
      wait_for_element_and_select(add_topic_select_element, topic.name)
      wait_until(Utils.short_wait) do
        new_note_unsaved_topic_pill(topic).visible? || topic_pill(note, topic).visible?
      end
      note.topics << topic
    end
  end

  def remove_topics(note, topics)
    logger.info "Removing topics #{topics.map &:name} from note ID '#{note.id}'"
    topics.each do |topic|
      logger.debug "Removing topic '#{topic.name}'"
      wait_until(Utils.short_wait) { new_note_unsaved_topic_remove_btn(topic).exists? || topic_remove_button(note, topic).exists? }
      if topic_remove_button(note, topic).exists?
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

  def new_note_attachment_delete_button(attachment)
    list_item_element(xpath: "//li[contains(@id, \"new-note-attachment-\")][contains(., \"#{attachment.file_name}\")]//button")
  end

  def add_attachments_to_new_note(note, attachments)
    files = attachments.map { |file| Utils.asset_file_path file.file_name }.join("\n")
    logger.debug "Adding attachments '#{files}' to an unsaved note"
    new_note_attach_input_element.send_keys files
    new_note_attachment_delete_button(attachments.last).when_present Utils.medium_wait
    sleep Utils.click_wait
    note.attachments << attachments
    note.attachments.flatten!
  end

  def remove_attachments_from_new_note(note, attachments)
    attachments.each do |attach|
      logger.info "Removing attachment '#{attach.file_name}' from an unsaved note"
      wait_for_update_and_click new_note_attachment_delete_button(attach)
      new_note_attachment_delete_button(attach).when_not_visible Utils.short_wait
      note.attachments.delete attach
      note.updated_date = Time.now
    end
  end

  element(:sorry_no_attachment_msg, xpath: '//body[text()="Sorry, attachment not available."]')

  def existing_note_attachment_input(note)
    text_area_element(xpath: "//div[@id='note-#{note.id}-attachment-dropzone']/input")
  end

  def existing_note_attachment_delete_button(note, attachment)
    list_item_element(xpath: "//div[@id=\"note-#{note.id}-outer\"]//li[contains(., \"#{attachment.file_name}\")]//button")
  end

  def add_attachments_to_existing_note(note, attachments)
    attachments.each do |attach|
      logger.debug "Adding attachment '#{attach.file_name}' to note ID #{note.id}"
      existing_note_attachment_input(note).when_present Utils.short_wait
      existing_note_attachment_input(note).send_keys Utils.asset_file_path(attach.file_name)
      existing_note_attachment_delete_button(note, attach).when_present Utils.medium_wait
      sleep Utils.click_wait
      note.updated_date = Time.now
      note.attachments << attach
    end
  end

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

  # CE3 Restricted

  radio_button(:universal_radio, xpath: '//input[@id="note-is-not-private-radio-button"]/..')
  radio_button(:private_radio, xpath: '//input[@id="note-is-private-radio-button"]/..')

  def set_note_privacy(note)
    if note.advisor&.dept_memberships&.find { |m| m.dept == BOACDepartments::ZCEEE } || note.advisor&.depts&.include?(BOACDepartments::ZCEEE.name)
      if note.is_private
        logger.info 'Setting note to private'
        wait_for_update_and_click private_radio_element
      else
        logger.info 'Setting note to non-private'
        wait_for_update_and_click universal_radio_element
      end
    else
      logger.info "Note author not with CE3, so privacy defaults to #{note.is_private}"
    end
  end


  # Contact Type

  def contact_type_radio(note)
    if note.type
      radio_button_element(xpath: "//input[@type='radio'][@value='#{note.type}']/..")
    else
      radio_button_element(xpath: '//input[@id="contact-option-none-radio-button"]/..')
    end
  end

  def select_contact_type(note)
    logger.debug "Selecting contact type '#{note.type}'"
    sleep 2
    contact_type_radio(note).click
  end

  # Set Date

  text_field(:set_date_input, id: 'manually-set-date-input')

  def enter_set_date(note)
    logger.debug "Entering edited note set date '#{note.set_date}'"
    wait_for_update_and_click set_date_input_element
    50.times { hit_backspace }
    50.times { hit_delete }
    set_date_input_element.send_keys note.set_date.strftime('%m/%d/%Y') if note.set_date
    2.times { hit_tab }
  end

  # Save

  button(:new_note_save_button, id: 'create-note-button')

  def click_save_new_note
    logger.debug 'Clicking the new note Save button'
    wait_for_update_and_click new_note_save_button_element
  end


  # Cancel

  button(:new_note_modal_cancel_button, xpath: '//button[contains(text(), "Discard")]')
  button(:new_note_cancel_button, xpath: '//button[contains(text(), "Discard")]')
  button(:cancel_delete_or_discard_button, id: 'are-you-sure-cancel')

  def click_cancel_new_note_modal
    logger.debug 'Clicking the new note Cancel button'
    wait_for_update_and_click new_note_modal_cancel_button_element
  end

  def click_cancel_new_note
    wait_for_update_and_click new_note_cancel_button_element
  end

  def confirm_delete_or_discard
    wait_for_update_and_click confirm_delete_or_discard_button_element
    sleep 1
  end

  def cancel_delete_or_discard
    wait_for_update_and_click cancel_delete_or_discard_button_element
  end


  #### CREATE NOTE, BATCH ####

  text_area(:batch_note_add_student_input, id: 'create-note-add-student-input')
  button(:batch_note_add_students_button, id: 'create-note-add-student-add-button')
  span(:batch_note_alert_no_students_per_cohorts, id: 'no-students-per-cohorts-alert')
  span(:batch_note_no_students_per_curated_groups, id: 'no-students-per-curated-groups-alert')
  span(:batch_note_no_students, id: 'no-students-alert')
  span(:batch_note_student_count_alert, id: 'target-student-count-alert')
  button(:batch_note_add_cohort_button, xpath: '//button[starts-with(@id, \'batch-note-cohort\')]')
  button(:batch_note_add_curated_group_button, xpath: '//button[starts-with(@id, \'batch-note-curated\')]')
  span(:batch_note_draft_student_warning, xpath: '//span[contains(text(), "draft will retain the content of your note but not the associated students")]')

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
    button_element(xpath: "//span[contains(@id, 'batch-note-cohort-')][text()='#{cohort.name}']/following-sibling::button[contains(@id, 'remove-cohort-from-batch')]")
  end

  def curated_group_dropdown_element(group)
    link_element(id: "batch-note-curated-option-#{group.id}")
  end

  def added_curated_group_element(group)
    span_element(xpath: "//span[contains(@id, \"batch-note-curated\")][text()=\"#{group.name}\"]")
  end

  def curated_group_remove_button(group)
    button_element(xpath: "//span[contains(@id, 'batch-note-curated-')][text()='#{group.name}']/following-sibling::button[contains(@id, 'remove-curated-from-batch')]")
  end

  def add_comma_sep_sids_to_batch(students)
    enter_comma_sep_sids(batch_note_add_student_input_element, students)
    wait_for_update_and_click batch_note_add_students_button_element
    students.each { |s| added_student_element(s).when_present 2 }
  end

  def add_line_sep_sids_to_batch(students)
    enter_line_sep_sids(batch_note_add_student_input_element, students)
    wait_for_update_and_click batch_note_add_students_button_element
    students.each { |s| added_student_element(s).when_present 2 }
  end

  def add_space_sep_sids_to_batch(students)
    enter_space_sep_sids(batch_note_add_student_input_element, students)
    wait_for_update_and_click batch_note_add_students_button_element
    students.each { |s| added_student_element(s).when_present 2 }
  end

  def add_students_to_batch(note_batch, students)
    students.each do |student|
      logger.debug "Find student SID '#{student.sis_id}' then add to batch note '#{note_batch.subject}'."
      wait_for_element_and_type(batch_note_add_student_input_element, "#{student.sis_id}")
      sleep Utils.click_wait
      wait_until(Utils.medium_wait) { auto_suggest_option_elements.any? }
      student_link_element = auto_suggest_option_elements.find { |el| el.text == "#{student.full_name} (#{student.sis_id})" }
      wait_for_update_and_click student_link_element
      append_student_to_batch(note_batch, student)
    end
  end

  def append_student_to_batch(note_batch, student)
    added_student_element(student).when_present 3
    note_batch.students << student
  end

  def remove_students_from_batch(note_batch, students)
    students.each do |student|
      logger.info "Removing SID #{student.sis_id} from batch note"
      scroll_to_top
      wait_for_update_and_click student_remove_button(student)
      added_student_element(student).when_not_visible Utils.short_wait
      note_batch.students.delete student
    end
  end

  def add_cohorts_to_batch(note_batch, cohorts)
    cohorts.each do |cohort|
      logger.debug "Cohort '#{cohort.name}' will be used in creation of batch note '#{note_batch.subject}'."
      wait_for_update_and_click batch_note_add_cohort_button_element
      wait_for_update_and_click cohort_dropdown_element(cohort)
      wait_for_element(added_cohort_element(cohort), Utils.short_wait)
      note_batch.cohorts << cohort
    end
  end

  def remove_cohorts_from_batch(note_batch, cohorts)
    cohorts.each do |cohort|
      logger.info "Removing cohort '#{cohort.name}' from batch note"
      wait_for_update_and_click cohort_remove_button(cohort)
      added_cohort_element(cohort).when_not_visible 1
      note_batch.cohorts.delete cohort
    end
  end

  def add_curated_groups_to_batch(note_batch, curated_groups)
    curated_groups.each do |curated_group|
      logger.debug "Curated group '#{curated_group.name}' will be used in creation of batch note '#{note_batch.subject}'."
      wait_for_update_and_click batch_note_add_curated_group_button_element
      wait_for_update_and_click curated_group_dropdown_element(curated_group)
      wait_for_element(added_curated_group_element(curated_group), Utils.short_wait)
      note_batch.curated_groups << curated_group
    end
  end

  def remove_groups_from_batch(note_batch, curated_groups)
    curated_groups.each do |curated_group|
      logger.info "Removing group '#{curated_group.name}' from batch note"
      wait_for_update_and_click curated_group_remove_button (curated_group)
      added_curated_group_element(curated_group).when_not_visible 1
      note_batch.curated_groups.delete curated_group
    end
  end


  #### CREATE NOTE ####

  def verify_batch_note_alert(students, cohorts, curated_groups)
    unique_students = unique_students_in_batch(students, cohorts, curated_groups)
    student_count = unique_students.length
    expected_alert = "Note will be added to student #{student_count} record#{student_count == 1 ? '' : 's'}"
    alert_text = batch_note_student_count_alert_element.text
    wait_until(1, "Expected alert '#{expected_alert}', got '#{alert_text}'") { alert_text && alert_text.include?(expected_alert) }
    wait_until(1) { alert_text.include? 'Are you sure?' } if student_count >= 500
  end

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
    set_note_privacy note_batch
    click_save_new_note
    # Give a moment
    sleep Utils.click_wait
    unique_students_in_batch(students, cohorts, curated_groups)
  end

  def unique_students_in_batch(students, cohorts, curated_groups)
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
  span(:no_templates_msg, xpath: '//div[text()=" You have no saved templates. "]')
  div(:dupe_template_title_msg, xpath: '//div[contains(text(), "You have an existing template with this name. Please choose a different name.")]')

  # Creation

  button(:create_template_button, xpath: '//button[contains(text(), "Save as template")]')
  text_area(:template_title_input, id: 'template-title-input')
  button(:cancel_template_button, id: 'cancel-template-create')
  button(:create_template_confirm_button, id: 'create-template-confirm')

  def click_create_template
    logger.info 'Clicking create template button'
    wait_for_update_and_click create_template_button_element
    template_title_input_element.when_present Utils.short_wait
  end

  def click_save_template
    logger.info 'Saving the template'
    wait_for_update_and_click create_template_confirm_button_element
  end

  def click_cancel_template
    logger.info 'Canceling the template'
    wait_for_update_and_click cancel_template_button_element
  end

  def enter_template_title(template)
    logger.info "Entering template title '#{template.title}'"
    wait_for_element_and_type(template_title_input_element, template.title)
  end

  def create_template(template, note)
    click_create_template
    enter_template_title template
    click_save_template
    get_new_template_id template
    template.subject = note.subject
    template.body = note.body
    template.topics = note.topics
    template.attachments = note.attachments
    template.advisor = note.advisor
    template.is_private = note.is_private
    sleep 3
  end

  def get_new_template_id(template)
    start = Time.now
    wait_until(Utils.long_wait) { template.id = template.get_note_template_id }
    logger.warn "Note template #{template.id} was created in #{Time.now - start} seconds"
  rescue
    logger.debug 'Timed out waiting for note template to be created'
    fail
  end

  def click_templates_button
    logger.info 'Clicking the Templates button'
    wait_for_update_and_click templates_button_element
  end

  def template_options
    template_select_option_elements.map &:text
  end

  def template_option(template)
    link_element(xpath: "//a[@id=\"load-note-template-#{template.id}\"][@title=\"#{template.title}\"]")
  end

  def apply_template(template, note)
    logger.info "Applying template ID #{template.id}"
    note.subject = template.subject
    note.body = template.body
    note.topics = template.topics
    note.attachments = template.attachments
    note.is_private = template.is_private
    note.advisor ||= template.advisor
  end

  def select_and_apply_template(template, note)
    click_templates_button
    wait_for_update_and_click template_option(template)
    apply_template(template, note)
    sleep 3
  end

  # Edit

  span(:edit_template_heading, xpath: '//span[text()="Edit Template"]')
  button(:update_template_button, id: 'btn-update-template')

  def click_edit_template(template)
    logger.info "Editing template ID #{template.id}"
    click_templates_button unless template_select_option_elements.any?(&:visible?)
    sleep Utils.click_wait
    wait_for_update_and_click button_element(id: "btn-edit-note-template-#{template.id}")
  end

  def click_update_template
    logger.info 'Clicking the Update Template button'
    wait_for_update_and_click update_template_button_element
    sleep 3
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
    sleep 1
    wait_for_update_and_click save_template_rename_button_element
    rename_template_input_element.when_not_present 3
  end

  def click_cancel_template_rename
    wait_for_update_and_click cancel_template_rename_button_element
  end

  # Delete

  def click_delete_template(template)
    click_templates_button unless template_select_option_elements.any?(&:visible?)
    wait_for_update_and_click button_element(id: "btn-delete-note-template-#{template.id}")
  end

  def delete_template(template)
    logger.info "Deleting template ID #{template.id}"
    click_delete_template template
    wait_for_update_and_click confirm_delete_or_discard_button_element unless "#{browser.browser}" == 'firefox'
  end

end
