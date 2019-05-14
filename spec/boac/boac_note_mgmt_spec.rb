require_relative '../../util/spec_helper'

include Logging

test = BOACTestConfig.new
test.note_management NessieUtils.get_all_students

# TODO - get real array of advisor dept mappings when we have them
test.advisor.depts = [test.dept.name]

other_advisor = BOACUtils.get_dept_advisors(test.dept).find { |a| a.uid != test.advisor.uid }

if test.dept == BOACDepartments::ADMIN

  logger.error 'Tests cannot be run for the Admin dept'

elsif !other_advisor

  logger.error "This script will fail because #{test.dept.name} has only one advisor"

else

  test_student = test.dept_students.first
  notes = []
  notes << (note_1 = Note.new({:advisor => test.advisor}))
  notes << (note_2 = Note.new({:advisor => test.advisor}))
  notes << (note_3 = Note.new({:advisor => test.advisor}))
  notes << (note_4 = Note.new({:advisor => test.advisor}))
  notes << (note_6 = Note.new({:advisor => test.advisor}))
  notes << (note_5 = Note.new({:advisor => test.advisor}))
  deleted_attachments = []

  describe 'A BOAC', order: :defined do

    include Logging

    before(:all) do
      @driver = Utils.launch_browser
      @homepage = BOACHomePage.new @driver
      @student_page = BOACStudentPage.new @driver
      @search_results_page = BOACSearchResultsPage.new @driver
      @api_notes_attachment_page = BOACApiNotesAttachmentPage.new @driver
    end

    after(:all) {Utils.quit_browser @driver}

    describe 'advisor' do

      before(:all) do
        @homepage.dev_auth test.advisor
        @student_page.load_page test_student
        @student_page.show_notes
      end

      after(:all) do
        @homepage.load_page
        @homepage.log_out
      end

      context 'creating a new note' do

        it 'cannot create a note without a subject' do
          @student_page.click_create_new_note
          @student_page.click_save_new_note
          @student_page.subj_required_msg_element.when_visible 1
          @student_page.click_cancel_new_note_modal
        end

        it 'can cancel an unsaved new note' do
          @student_page.click_create_new_note
          @student_page.wait_for_element_and_type(@student_page.note_body_text_area_elements[0], 'An edit to forget')
          @student_page.click_cancel_new_note_modal
          @student_page.confirm_delete
          @student_page.note_body_text_area_elements[0].when_not_visible 1
        end

        it 'can create a note with a subject' do
          note_1.subject = "Note 1 subject #{Utils.get_test_id}"
          @student_page.create_note note_1
          @student_page.verify_note note_1
        end

        it 'can create a note with a subject and a body' do
          note_2.subject = "Note 2 subject #{Utils.get_test_id}"
          note_2.body = "Note 2 body #{test.id}" unless "#{@driver.browser}" == 'firefox'
          @student_page.create_note note_2
          @student_page.verify_note note_2
        end

        it 'can create a long note with special characters' do
          note_3.subject = "Σημείωση θέμα 3 #{Utils.get_test_id}"
          note_3.body = 'ノート本体4' * 100 unless "#{@driver.browser}" == 'firefox'
          @student_page.create_note note_3
          @student_page.verify_note note_3
        end

        it 'can add and remove attachments before saving' do
          note_4.subject = "Note 4 subject #{Utils.get_test_id}"
          @student_page.click_create_new_note
          @student_page.enter_new_note_subject note_4
          @student_page.add_attachments_to_new_note(note_4, test.attachments[0..1])
          @student_page.remove_attachments_from_new_note(note_4, test.attachments[0..1])
          @student_page.click_save_new_note
          @student_page.set_new_note_id note_4
          @student_page.verify_note note_4
        end

        it 'can create a note with attachments' do
          note_5.subject = "Note 5 subject #{Utils.get_test_id}"
          @student_page.create_note(note_5, test.attachments[0..1])
          @student_page.verify_note note_5
        end

        it 'can create a note with a maximum of 5 attachments' do
          note_6.subject = "Note 6 subject #{Utils.get_test_id}"
          @student_page.click_create_new_note
          @student_page.enter_new_note_subject note_6
          @student_page.add_attachments_to_new_note(note_6, test.attachments[0..4])
          @student_page.existing_note_attachment_input(note_6).when_not_visible 1
          @student_page.click_save_new_note
          @student_page.set_new_note_id note_6
          @student_page.collapsed_note_el(note_6).when_visible Utils.short_wait
          note_6.updated_date = Time.now
          @student_page.verify_note note_6
        end

        it 'cannot create a note with an individual attachment larger than 20MB' do
          big_attachment = test.attachments.find { |a| a.file_size > 20000000 }
          @student_page.click_create_new_note
          @student_page.wait_for_update_and_click @student_page.adv_note_options_button_element
          @student_page.new_note_attach_input_element.when_present 1
          @student_page.new_note_attach_input_element.send_keys Utils.asset_file_path(big_attachment.file_name)
          @student_page.note_attachment_size_msg_element.when_visible Utils.short_wait
        end
      end

      context 'searching for a newly created note' do

        before(:all) do
          @student_page.click_cancel_new_note
          @student_page.expand_search_options
          @student_page.uncheck_include_students_cbx
          @student_page.uncheck_include_classes_cbx
        end

        shared_examples 'searching for your own note' do
          it 'can find a note by subject' do
            @student_page.search note_1.subject
            @search_results_page.wait_for_note_search_result_rows
            expect(@search_results_page.note_link(note_1).exists?).to be true
          end

          it 'can find a note by body' do
            unless "#{@driver.browser}" == 'firefox'
              @student_page.search note_2.body
              @search_results_page.wait_for_note_search_result_rows
              expect(@search_results_page.note_link(note_2).exists?).to be true
            end
          end

          it 'can find a note with special characters' do
            @student_page.search note_3.subject
            @search_results_page.wait_for_note_search_result_rows
            expect(@search_results_page.note_link(note_3).exists?).to be true
          end
        end

        describe 'when searching for "anyone"' do
          before { @student_page.select_notes_posted_by_anyone }
          include_examples 'searching for your own note'
        end

        describe 'when searching for "only you"' do
          before { @student_page.select_notes_posted_by_you }
          after { @student_page.select_notes_posted_by_anyone }
          include_examples 'searching for your own note'
        end
      end

      context 'viewing a newly created note' do

        before(:all) do
          @student_page.load_page test_student
          @student_page.show_notes
          @student_page.expand_note note_5
        end

        it 'can download note attachments' do
          if Utils.headless?
            logger.warn 'Skipping attachment download tests in headless mode'
            skip
          else
            note_5.attachments.each { |attach| @student_page.download_attachment(note_5, attach) }
          end
        end

        it 'can visit the note permalink' do
          @student_page.navigate_to @student_page.visible_expanded_note_data(note_5)[:permalink_url]
          @student_page.wait_until(Utils.short_wait) { @student_page.note_expanded? note_5 }
        end
      end

      context 'editing an existing note' do

        before(:each) do
          @student_page.load_page test_student
          @student_page.show_notes
        end

        it 'can cancel the edit' do
          original_subject = note_1.subject
          note_1.subject = 'An edit to forget'
          @student_page.expand_note note_1
          @student_page.click_edit_note_button note_1
          @student_page.enter_edit_note_subject note_1
          @student_page.click_cancel_note_edit
          @student_page.confirm_delete
          @student_page.note_body_text_area_elements[0].when_not_visible 1
          note_1.subject = original_subject
          @student_page.verify_note note_1
        end

        it 'can change the subject' do
          note_1.subject = "#{note_1.subject} - EDITED"
          @student_page.edit_note_subject_and_save note_1
          @student_page.verify_note note_1
        end

        it 'can add attachments' do
          @student_page.expand_note note_4
          @student_page.add_attachments_to_existing_note(note_4, test.attachments[5..6])
          @student_page.verify_note note_4
        end

        it 'can add up to a maximum of 5 attachments' do
          @student_page.expand_note note_6
          expect(@student_page.existing_note_attachment_input(note_6).exists?).to be false
        end

        it 'can remove an existing attachment' do
          @student_page.expand_note note_5
          attach_to_delete = note_5.attachments.first
          attach_to_delete.id = BOACUtils.get_attachment_id_by_file_name(note_5, attach_to_delete)
          deleted_attachments << attach_to_delete
          @student_page.remove_attachments_from_existing_note(note_5, [note_5.attachments.first])
          @student_page.verify_note note_5
        end

        it 'can only create or edit one note at a time' do
          @student_page.expand_note note_1
          @student_page.edit_note_button(note_1).when_visible 1
          @student_page.expand_note note_2
          @student_page.edit_note_button(note_2).when_visible 1
          @student_page.click_edit_note_button note_1
          expect(@student_page.edit_note_button(note_2).exists?).to be false
          expect(@student_page.new_note_button_element.disabled?).to be true
        end

        it 'can cancel the edit' do
          @student_page.expand_note note_2
          @student_page.click_edit_note_button note_2
          @student_page.wait_for_element_and_type(@student_page.note_body_text_area_elements[1], 'An edit to forget')
          @student_page.click_cancel_note_edit
          @student_page.confirm_delete
          @student_page.verify_note note_2
        end

        it 'cannot remove the subject' do
          @student_page.expand_note note_2
          @student_page.click_edit_note_button note_2
          @student_page.wait_for_element_and_type(@student_page.edit_note_subject_input_element, ' ')
          @student_page.click_save_note_edit
          @student_page.subj_required_msg_element.when_visible 1
          @student_page.click_cancel_note_edit
          @student_page.wait_for_update_and_click @student_page.confirm_delete_button_element
        end

        it 'cannot add an attachment with the same file name as an existing attachment' do
          @student_page.expand_note note_4
          @student_page.existing_note_attachment_input(note_4).when_present 1
          @student_page.existing_note_attachment_input(note_4).send_keys Utils.asset_file_path(test.attachments[5].file_name)
          @student_page.note_dupe_attachment_msg_element.when_present Utils.short_wait
        end

        it 'cannot add an individual attachment larger than 20MB' do
          big_attachment = test.attachments.find { |a| a.file_size > 20000000 }
          @student_page.expand_note note_2
          @student_page.existing_note_attachment_input(note_2).when_present 1
          @student_page.existing_note_attachment_input(note_2).send_keys Utils.asset_file_path(big_attachment.file_name)
          @student_page.note_attachment_size_msg_element.when_visible Utils.short_wait
        end
      end

      context 'attempting to delete a note' do

        it 'cannot do so' do
          @student_page.expand_note note_1
          expect(@student_page.delete_note_button(note_1).visible?).to be false
        end
      end

      context 'searching for an edited note' do

        it 'can find a note by edited content' do
          @student_page.search note_1.subject
          @search_results_page.wait_for_note_search_result_rows
          expect(@search_results_page.note_link(note_1).exists?).to be true
        end

        it 'cannot download a deleted attachment' do
          @api_notes_attachment_page.load_page deleted_attachments.first.id
          @api_notes_attachment_page.not_found_msg_element.when_visible Utils.short_wait
          expect(Utils.downloads_empty?).to be true
        end
      end
    end

    describe 'advisor other than the note creator but in the same department' do

      before(:all) do
        @homepage.dev_auth other_advisor
        @student_page.load_page test_student
      end

      after(:all) do
        @student_page.select_notes_posted_by_anyone
        @homepage.load_page
        @homepage.log_out
      end

      describe 'when searching for "anyone"' do
        before { @student_page.select_notes_posted_by_anyone }
        it 'can find the other user\'s note' do
          @student_page.search note_1.subject
          @search_results_page.wait_for_note_search_result_rows
          expect(@search_results_page.note_link(note_1).exists?).to be true
        end
      end

      describe 'when searching for "only you"' do
        before { @student_page.select_notes_posted_by_you }
        after { @student_page.select_notes_posted_by_anyone }
        it 'cannot find the other user\'s note' do
          @student_page.search note_1.subject
          expect(@search_results_page.note_results_count).to be_zero
        end
      end

      it 'cannot edit the other user\'s note' do
        @student_page.expand_note note_5
        expect(@student_page.edit_note_button(note_5).exists?).to be false
      end

      it 'cannot delete attachments on the other user\'s note' do
        @student_page.expand_note note_5
        note_5.attachments.reject(&:deleted_at).each { |attach| expect(@student_page.existing_note_attachment_delete_button(note_5, attach).exists?).to be false }
      end

      it 'can download non-deleted attachments' do
        if Utils.headless?
          logger.warn 'Skipping attachment download tests in headless mode'
          skip
        else
          note_5.attachments.reject(&:deleted_at).each { |attach| @student_page.download_attachment(note_5, attach) }
        end
      end
    end

    describe 'admin' do

      before(:all) do
        @homepage.dev_auth
        @student_page.load_page test_student
        @student_page.show_notes
      end

      after(:all) do
        @homepage.load_page
        @homepage.log_out
      end

      it('cannot create a note') { expect(@student_page.new_note_button?).to be false }

      notes.each do |note|
        it 'cannot edit a note' do
          @student_page.expand_note note
          expect(@student_page.edit_note_button(note).exists?).to be false
        end

        it 'can delete a note' do
          @student_page.delete_note note
          @student_page.collapsed_note_el(note).when_not_visible Utils.short_wait
          deleted = BOACUtils.get_note_delete_status note
          expect(deleted).to_not be_nil
        end
      end
    end

    describe 'advisor' do

      before(:all) do
        @homepage.dev_auth test.advisor
        @student_page.expand_search_options
        @student_page.uncheck_include_students_cbx
        @student_page.uncheck_include_classes_cbx
      end

      notes.each do |note|
        it 'cannot find a deleted note' do
          logger.info "Searching for deleted note ID #{note.id} by subject '#{note.subject}'"
          @homepage.load_page
          @student_page.search note.subject
          expect(@search_results_page.note_results_count).to be_zero
        end

        it 'cannot download a deleted note\'s attachments' do
          if note.attachments.any?
            note.attachments.each do |attach|
              @homepage.load_page
              id = BOACUtils.get_attachment_id_by_file_name(note, attach)
              @api_notes_attachment_page.load_page id
              @api_notes_attachment_page.not_found_msg_element.when_visible Utils.short_wait
              expect(Utils.downloads_empty?).to be true
            end
          end
        end
      end
    end
  end
end
