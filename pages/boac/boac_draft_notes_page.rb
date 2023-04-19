class BOACDraftNotesPage

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACPagesCreateNoteModal

  div(:no_drafts_msg, xpath: '//div[text()=" You have no saved drafts. "]')
  elements(:draft_note_row, :row, xpath: '//tbody/tr')

  def visible_draft_note_ids
    wait_until(Utils.short_wait) { draft_note_row_elements.any? } unless no_drafts_msg?
    draft_note_row_elements.map { |el| el.attribute('id').split('-').last }
  end

  def draft_note_row_xpath(note)
    "//tr[@id='draft-note-#{note.id}']"
  end

  def draft_note_row(note)
    row_element(xpath: draft_note_row_xpath(note))
  end

  def wait_for_draft_note_row(note)
    draft_note_row(note).when_visible Utils.short_wait
  end

  def draft_note_row_data(note)
    xpath = draft_note_row_xpath note
    student_el = cell_element(xpath: "#{xpath}/td[@data-label='Student']")
    sid_el = cell_element(xpath: "#{xpath}/td[@data-label='SID']")
    subject_el = cell_element(xpath: "#{xpath}/td[@data-label='Subject']")
    author_el = cell_element(xpath: "#{xpath}/td[@data-label='Author']")
    saved_el = cell_element(xpath: "#{xpath}/td[@data-label='Date']")
    {
      student: (student_el.text.strip if student_el.exists?),
      sid: (sid_el.text.strip if sid_el.exists?),
      subject: (subject_el.text.strip if subject_el.exists?),
      author: (author_el.text.strip if author_el.exists?),
      date: (saved_el.text.strip if saved_el.exists?)
    }
  end

  def click_student_link(note)
    logger.info "Clicking student page link for draft note #{note.id}"
    wait_for_update_and_click link_element(xpath: "#{draft_note_row_xpath note}//a")
  end

  def subject_button(note)
    button_element(xpath: "#{draft_note_row_xpath note}/td[@data-label='Subject']//button")
  end

  def click_subject(note)
    logger.info "Opening note edit modal for draft note #{note.id}"
    wait_for_update_and_click subject_button(note)
  end

  # Delete

  def draft_note_delete_button(note)
    button_element(xpath: "#{draft_note_row_xpath note}/td[@data-label='Delete']//button")
  end

  def click_delete_draft(note)
    logger.info "Clicking delete button for draft note #{note.id}"
    wait_for_update_and_click draft_note_delete_button(note)
  end

  def confirm_delete_draft
    wait_for_update_and_click confirm_delete_or_discard_button_element
    sleep 2
  end

  def cancel_delete_draft
    wait_for_update_and_click cancel_delete_or_discard_button_element
  end

  def delete_all_drafts
    drafts = visible_draft_note_ids.map { |id| Note.new id: id }
    drafts.each do |draft|
      click_delete_draft draft
      confirm_delete_draft
      logger.debug "Waiting for #{draft_note_row(draft).locator} to go away"
      wait_until(Utils.short_wait) { !draft_note_row(draft).exists? }
    end
  end
end
