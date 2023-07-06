require_relative '../../util/spec_helper'

unless ENV['NO_DEPS']

  include Logging

  test = BOACTestConfig.new
  test.note_management
  test.advisor.depts = [test.dept.name]

  director = BOACUtils.get_authorized_users.find do |a|
    a.dept_memberships.find { |m| m.advisor_role == AdvisorRole::DIRECTOR }
  end
  other_advisor = BOACUtils.get_dept_advisors(test.dept).reverse.find do |a|
    a.can_access_advising_data && a.uid != test.advisor.uid
  end

  if test.dept == BOACDepartments::ADMIN

    logger.error 'Tests cannot be run for the Admin dept'

  elsif !other_advisor

    logger.error "This script will fail because #{test.dept.name} has only one advisor"

  else

    logger.info "Advisor UID #{test.advisor.uid}, director UID #{director&.uid}, other advisor UID #{other_advisor.uid}"
    test_student = test.students.shuffle.first
    notes = []
    notes << (note_1 = Note.new({:advisor => test.advisor}))
    notes << (note_2 = Note.new({:advisor => test.advisor}))
    notes << (note_3 = Note.new({:advisor => test.advisor}))
    notes << (note_4 = Note.new({:advisor => test.advisor}))
    notes << (note_5 = Note.new({:advisor => test.advisor}))
    notes << (note_6 = Note.new({:advisor => test.advisor}))
    notes << (note_7 = Note.new({:advisor => test.advisor}))
    notes << (note_8 = Note.new({:advisor => test.advisor}))

    # Get the largest attachments for testing max attachments uploads
    attachments_by_size = test.attachments.sort_by(&:file_size).delete_if { |a| a.file_size > 20000000 }
    big_attachments = attachments_by_size.first 10

    deleted_attachments = []

    describe 'A BOAC', order: :defined do

      include Logging

      before(:all) do
        @driver = Utils.launch_browser
        @homepage = BOACHomePage.new @driver
        @student_page = BOACStudentPage.new @driver
        @search_results_page = BOACSearchResultsPage.new @driver
        @api_admin_page = BOACApiAdminPage.new @driver
        @api_notes_page = BOACApiNotesPage.new @driver
      end

      after(:all) { Utils.quit_browser @driver }

      describe 'advisor' do

        before(:all) do
          @homepage.dev_auth test.advisor
          @student_page.load_page test_student
        end

        after(:all) do
          @homepage.load_page
          @homepage.log_out
        end

        context 'creating a new note' do

          it 'cannot create a note without a subject' do
            note_1.subject = ''
            @student_page.click_create_new_note
            @student_page.new_note_save_button_element.when_present 2
            @student_page.enter_new_note_subject note_1
            expect(@student_page.new_note_save_button_element.disabled?).to be true
          end

          it 'can cancel an unsaved new note' do
            @student_page.click_cancel_new_note
            @student_page.click_create_new_note
            @student_page.wait_for_note_body_editor
            Utils.save_screenshot(@driver, 'Modal-click-interception')
            @student_page.wait_for_textbox_and_type(@student_page.note_body_text_area_elements[1], 'An edit to forget')
            @student_page.click_cancel_new_note
            @student_page.confirm_delete_or_discard
            @student_page.wait_until(Utils.short_wait) { @student_page.note_body_text_area_elements.empty? }
          end

          it 'can create a note with a subject' do
            note_1.subject = "Note 1 subject #{Utils.get_test_id}"
            @student_page.create_note(note_1, [], [])
            @student_page.verify_note(note_1, test.advisor)
          end

          it 'can create a note with a subject and a body' do
            note_2.subject = "Note 2 subject #{Utils.get_test_id}"
            note_2.body = "Note 2 body #{test.id}" unless "#{@driver.browser}" == 'firefox'
            @student_page.create_note(note_2, [], [])
            @student_page.verify_note(note_2, test.advisor)
          end

          it 'can create a note with contact type and set date' do
            note_3.subject = "Σημείωση θέμα 3 #{Utils.get_test_id}"
            note_3.body = 'ノート本体4' * 100 unless "#{@driver.browser}" == 'firefox'
            note_3.type = 'In-person same day'
            note_3.set_date = Time.now - 86400
            @student_page.create_note(note_3, [], [])
            @student_page.verify_note(note_3, test.advisor)
          end

          it 'can add and remove attachments before saving' do
            note_4.subject = "Note 4 subject #{Utils.get_test_id}"
            @student_page.click_create_new_note
            @student_page.enter_new_note_subject note_4
            @student_page.add_attachments_to_new_note(note_4, test.attachments[0..1])
            @student_page.remove_attachments_from_new_note(note_4, test.attachments[0..1])
            @student_page.click_save_new_note
            @student_page.set_new_note_id note_4
            @student_page.verify_note(note_4, test.advisor)
          end

          it 'can create a note with attachments' do
            note_5.subject = "Note 5 subject #{Utils.get_test_id}"
            @student_page.create_note(note_5, [], test.attachments[0..1])
            @student_page.verify_note(note_5, test.advisor)
          end

          it 'can create a note with a maximum of 10 attachments' do
            note_6.subject = "Note 6 subject #{Utils.get_test_id}"
            @student_page.click_create_new_note
            @student_page.enter_new_note_subject note_6
            @student_page.add_attachments_to_new_note(note_6, big_attachments)
            @student_page.existing_note_attachment_input(note_6).when_not_visible 1
            @student_page.click_save_new_note
            @student_page.set_new_note_id note_6
            @student_page.collapsed_item_el(note_6).when_visible Utils.short_wait
            @student_page.verify_note(note_6, test.advisor)
          end

          it 'cannot create a note with an individual attachment larger than 20MB' do
            too_big_attachment = test.attachments.find { |a| a.file_size > 20000000 }
            @student_page.click_create_new_note
            @student_page.new_note_attach_input_element.when_present Utils.short_wait
            @student_page.new_note_attach_input_element.send_keys Utils.asset_file_path(too_big_attachment.file_name)
            @student_page.note_attachment_size_msg_element.when_visible Utils.short_wait
          end

          it 'can add and remove topics before saving' do
            note_7.subject = "Note 7 subject #{Utils.get_test_id}"
            note_topics = [Topic::COURSE_ADD, Topic::COURSE_DROP]
            @student_page.click_cancel_new_note
            @student_page.confirm_delete_or_discard
            @student_page.load_page test_student
            @student_page.click_create_new_note
            @student_page.enter_new_note_subject note_7
            @student_page.add_topics(note_7, note_topics)
            @student_page.remove_topics(note_7, note_topics)
            @student_page.click_save_new_note
            @student_page.set_new_note_id note_7
            @student_page.verify_note(note_7, test.advisor)
          end

          it 'can create a note with topics' do
            note_8.subject = "Note 8 subject #{Utils.get_test_id}"
            @student_page.load_page test_student
            @student_page.create_note(note_8, [Topic::EAP, Topic::SAT_ACAD_PROGRESS_APPEAL, Topic::PASS_NO_PASS, Topic::PROBATION], [])
            @student_page.verify_note(note_8, test.advisor)
          end
        end

        context 'searching for a newly created note' do

          before(:all) do
            @student_page.log_out
            @homepage.dev_auth
            @api_admin_page.reindex_notes
            @homepage.load_page
            @homepage.log_out
            @homepage.dev_auth test.advisor
          end

          shared_examples 'searching for your own note' do
            it 'can find a note by subject' do
              @student_page.enter_adv_search_and_hit_enter note_1.subject
              @search_results_page.wait_for_note_search_result_rows
              expect(@search_results_page.note_link(note_1).exists?).to be true
            end

            it 'can find a note by body' do
              @search_results_page.click_edit_search
              @student_page.enter_adv_search_and_hit_enter note_2.body
              @search_results_page.wait_for_note_search_result_rows
              expect(@search_results_page.note_link(note_2).exists?).to be true
            end

            it 'can find a note with special characters' do
              @search_results_page.click_edit_search
              @student_page.enter_adv_search_and_hit_enter note_3.subject
              @search_results_page.wait_for_note_search_result_rows
              expect(@search_results_page.note_link(note_3).exists?).to be true
            end
          end

          describe 'when searching for "anyone"' do
            before(:all) do
              @student_page.reopen_and_reset_adv_search
              @student_page.exclude_students
              @student_page.exclude_classes
              @student_page.select_notes_posted_by_anyone
            end
            include_examples 'searching for your own note'
          end

          describe 'when searching for "only you"' do
            before(:all) do
              @student_page.reopen_and_reset_adv_search
              @student_page.exclude_students
              @student_page.exclude_classes
              @student_page.select_notes_posted_by_you
            end
            include_examples 'searching for your own note'
          end
        end

        context 'viewing a newly created note' do

          before(:all) do
            @student_page.load_page test_student
            @student_page.show_notes
            @student_page.expand_item note_5
          end

          it 'can download note attachments' do
            note_5.attachments.each { |attach| @student_page.download_attachment(note_5, attach) }
          end

          it 'can visit the note permalink' do
            @student_page.navigate_to @student_page.visible_expanded_note_data(note_5)[:permalink_url]
            @student_page.wait_until(Utils.short_wait) { @student_page.item_expanded? note_5 }
          end
        end

        context 'viewing newly created notes' do

          it 'shows the notes in the right order' do
            @student_page.load_page test_student
            @student_page.show_notes
            new_note_ids = notes.map &:id
            visible_new_note_ids = @student_page.visible_collapsed_note_ids
            visible_new_note_ids.keep_if { |id| new_note_ids.include? id }
            expect(visible_new_note_ids).to eql(@student_page.expected_note_id_sort_order notes)
          end

          it('sees no download link') { expect(@student_page.notes_download_link?).to be false }

          it 'cannot hit the download endpoint' do
            Utils.prepare_download_dir
            @api_notes_page.load_download_page test_student
            @api_notes_page.not_found_msg_element.when_present Utils.short_wait
            expect(Utils.downloads_empty?).to be true
          end
        end

        context 'viewing all of a student\'s notes' do

          before(:all) do
            @student_notes = []
            @student_notes << NessieTimelineUtils.get_asc_notes(test_student)
            expected_boa_notes = BOACUtils.get_student_notes test_student
            expected_boa_notes.delete_if { |n| n.is_draft && n.advisor.uid != test.advisor.uid }
            @student_notes << expected_boa_notes
            @student_notes << NessieTimelineUtils.get_data_sci_notes(test_student)
            @student_notes << NessieTimelineUtils.get_e_form_notes(test_student)
            @student_notes << NessieTimelineUtils.get_e_and_i_notes(test_student)
            @student_notes << NessieTimelineUtils.get_eop_notes(test_student)
            @student_notes << NessieTimelineUtils.get_history_notes(test_student)
            @student_notes << NessieTimelineUtils.get_sis_notes(test_student)
            @student_page.load_page test_student
            @student_page.show_notes
          end

          it 'allows the advisor to view all notes' do
            expect(@student_page.visible_collapsed_note_ids.sort).to eql(@student_notes.map(&:id).sort)
          end

          it 'allows the advisor to filter for those authored by the advisor' do
            @student_page.toggle_my_notes
            advisor_notes = @student_notes.select { |n| n.advisor&.uid == test.advisor.uid }
            expect(@student_page.visible_collapsed_note_ids.sort).to eql(advisor_notes.map(&:id).sort)
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
            @student_page.expand_item note_1
            @student_page.click_edit_note_button note_1
            @student_page.enter_edit_note_subject note_1
            @student_page.click_cancel_note_edit
            @student_page.confirm_delete_or_discard
            @student_page.wait_until(1) { @student_page.note_body_text_area_elements.empty? }
            note_1.subject = original_subject
            @student_page.verify_note(note_1, test.advisor)
          end

          it 'can change the subject' do
            note_1.subject = "#{note_1.subject} - EDITED"
            @student_page.edit_note_subject_and_save note_1
            @student_page.verify_note(note_1, test.advisor)
          end

          it 'can add attachments' do
            @student_page.expand_item note_4
            @student_page.add_attachments_to_existing_note(note_4, test.attachments[5..6])
            @student_page.verify_note(note_4, test.advisor)
          end

          it 'can edit contact type' do
            note_4.type = 'Phone'
            @student_page.expand_item note_4
            @student_page.click_edit_note_button note_4
            @student_page.select_contact_type note_4
            @student_page.save_note_edit note_4
            @student_page.verify_note(note_4, test.advisor)
          end

          it 'can remove contact type' do
            note_4.type = nil
            @student_page.expand_item note_4
            @student_page.click_edit_note_button note_4
            @student_page.select_contact_type note_4
            @student_page.save_note_edit note_4
            @student_page.verify_note(note_4, test.advisor)
          end

          it 'can edit set date' do
            note_4.set_date = Date.today.to_time
            @student_page.expand_item note_4
            @student_page.click_edit_note_button note_4
            @student_page.enter_set_date note_4
            @student_page.save_note_edit note_4
            @student_page.verify_note(note_4, test.advisor)
          end

          it 'can view edited set date sorted correctly' do
            @student_page.load_page test_student
            @student_page.show_notes
            visible_ids = @student_page.visible_collapsed_note_ids.keep_if { |i| notes.map(&:id).include? i }
            expect(visible_ids).to eql(@student_page.expected_note_id_sort_order notes)
          end

          it 'can remove set date' do
            note_4.set_date = nil
            @student_page.expand_item note_4
            @student_page.click_edit_note_button note_4
            @student_page.enter_set_date note_4
            @student_page.save_note_edit note_4
            @student_page.verify_note(note_4, test.advisor)
          end

          it 'can add up to a maximum of 10 attachments' do
            @student_page.expand_item note_6
            expect(@student_page.existing_note_attachment_input(note_6).exists?).to be false
          end

          it 'can remove an existing attachment' do
            @student_page.expand_item note_5
            attach_to_delete = note_5.attachments.first
            attach_to_delete.id = BOACUtils.get_attachment_id_by_file_name(note_5, attach_to_delete)
            deleted_attachments << attach_to_delete
            @student_page.remove_attachments_from_existing_note(note_5, [note_5.attachments.first])
            @student_page.verify_note(note_5, test.advisor)
          end

          it 'can add topics' do
            @student_page.expand_item note_7
            @student_page.click_edit_note_button note_7
            @student_page.add_topics(note_7, [Topic::LATE_ENROLLMENT, Topic::RETROACTIVE_ADD])
            @student_page.click_save_note_edit
            @student_page.edit_note_save_button_element.when_not_present Utils.short_wait
            note_7.updated_date = Time.now
            @student_page.verify_note(note_7, test.advisor)
          end

          it 'can remove topics' do
            @student_page.expand_item note_8
            @student_page.click_edit_note_button note_8
            @student_page.remove_topics(note_8, [Topic::EAP, Topic::PASS_NO_PASS])
            @student_page.click_save_note_edit
            @student_page.edit_note_save_button_element.when_not_present Utils.short_wait
            note_8.updated_date = Time.now
            @student_page.verify_note(note_8, test.advisor)
          end

          it 'can only create or edit one note at a time' do
            @student_page.expand_item note_1
            @student_page.edit_note_button(note_1).when_visible 1
            @student_page.expand_item note_2
            @student_page.edit_note_button(note_2).when_visible 1
            @student_page.click_edit_note_button note_1
            expect(@student_page.edit_note_button(note_2).exists?).to be false
            @student_page.wait_until(1) { @student_page.new_note_button_element.disabled? }
          end

          it 'can cancel the edit' do
            @student_page.expand_item note_2
            @student_page.click_edit_note_button note_2
            @student_page.wait_for_element_and_type(@student_page.note_body_text_area_elements[1], 'An edit to forget')
            @student_page.click_cancel_note_edit
            @student_page.confirm_delete_or_discard
            @student_page.verify_note(note_2, test.advisor)
          end

          it 'cannot remove the subject' do
            @student_page.expand_item note_2
            @student_page.click_edit_note_button note_2
            @student_page.wait_for_element_and_type(@student_page.edit_note_subject_input_element, ' ')
            @student_page.click_save_note_edit
            @student_page.subj_required_msg_element.when_visible 1
            @student_page.click_cancel_note_edit
            @student_page.wait_for_update_and_click @student_page.confirm_delete_or_discard_button_element
          end

          it 'cannot add an attachment with the same file name as an existing attachment' do
            @student_page.expand_item note_4
            @student_page.existing_note_attachment_input(note_4).when_present 1
            @student_page.existing_note_attachment_input(note_4).send_keys Utils.asset_file_path(test.attachments[5].file_name)
            @student_page.note_dupe_attachment_msg_element.when_present Utils.short_wait
          end

          it 'cannot add an individual attachment larger than 20MB' do
            too_big_attachment = test.attachments.find { |a| a.file_size > 20000000 }
            @student_page.expand_item note_2
            @student_page.existing_note_attachment_input(note_2).when_present 1
            @student_page.existing_note_attachment_input(note_2).send_keys Utils.asset_file_path(too_big_attachment.file_name)
            @student_page.note_attachment_size_msg_element.when_visible Utils.short_wait
          end
        end

        context 'viewing edited notes' do

          it 'shows the notes in the right order' do
            @student_page.load_page test_student
            @student_page.show_notes
            note_ids = notes.map &:id
            visible_new_note_ids = @student_page.visible_collapsed_note_ids.keep_if { |id| note_ids.include? id }
            expect(visible_new_note_ids).to eql(@student_page.expected_note_id_sort_order notes)
          end
        end

        context 'attempting to delete a note' do

          it 'cannot do so' do
            @student_page.expand_item note_1
            expect(@student_page.delete_note_button(note_1).visible?).to be false
          end
        end

        context 'searching for an edited note' do

          before(:all) do
            @student_page.log_out
            @homepage.dev_auth
            @api_admin_page.reindex_notes
            @homepage.load_page
            @homepage.log_out
            @homepage.dev_auth test.advisor
          end

          it 'can find a note by edited content' do
            @student_page.enter_simple_search_and_hit_enter note_1.subject
            @search_results_page.wait_for_note_search_result_rows
            expect(@search_results_page.note_link(note_1).exists?).to be true
          end

          it 'cannot download a deleted attachment' do
            Utils.prepare_download_dir
            @api_notes_page.load_attachment_page deleted_attachments.first.id
            @api_notes_page.note_not_found_msg_element.when_present Utils.short_wait
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
          @homepage.load_page
          @homepage.log_out
        end

        it 'cannot edit the other user\'s note' do
          @student_page.expand_item note_5
          expect(@student_page.edit_note_button(note_5).exists?).to be false
        end

        it 'cannot delete attachments on the other user\'s note' do
          @student_page.expand_item note_5
          note_5.attachments.reject(&:deleted_at).each { |attach| expect(@student_page.existing_note_attachment_delete_button(note_5, attach).exists?).to be false }
        end

        it 'can download non-deleted attachments' do
          note_5.attachments.reject(&:deleted_at).each { |attach| @student_page.download_attachment(note_5, attach) }
        end

        describe 'when searching for "anyone"' do
          before do
            @homepage.reopen_and_reset_adv_search
            @student_page.select_notes_posted_by_anyone
          end
          it 'can find the other user\'s note' do
            @student_page.enter_adv_search_and_hit_enter note_1.subject
            @search_results_page.wait_for_note_search_result_rows
            expect(@search_results_page.note_link(note_1).exists?).to be true
          end
        end

        describe 'when searching for "only you"' do
          before do
            @search_results_page.reopen_and_reset_adv_search
            @student_page.select_notes_posted_by_you
          end
          it 'cannot find the other user\'s note' do
            @student_page.enter_adv_search_and_hit_enter note_1.subject
            expect(@search_results_page.note_results_count).to be_zero
          end
        end

        context 'viewing all of a student\'s notes' do

          before(:all) do
            @student_notes = []
            @student_notes << NessieTimelineUtils.get_asc_notes(test_student)
            expected_boa_notes = BOACUtils.get_student_notes test_student
            expected_boa_notes.delete_if { |n| n.is_draft && n.advisor.uid != other_advisor.uid }
            @student_notes << expected_boa_notes
            @student_notes << NessieTimelineUtils.get_data_sci_notes(test_student)
            @student_notes << NessieTimelineUtils.get_e_form_notes(test_student)
            @student_notes << NessieTimelineUtils.get_e_and_i_notes(test_student)
            @student_notes << NessieTimelineUtils.get_eop_notes(test_student)
            @student_notes << NessieTimelineUtils.get_history_notes(test_student)
            @student_notes << NessieTimelineUtils.get_sis_notes(test_student)
            @student_page.load_page test_student
            @student_page.show_notes
          end

          it 'allows the advisor to view all notes' do
            expect(@student_page.visible_collapsed_note_ids.sort).to eql(@student_notes.map(&:id).sort)
          end

          it 'allows the advisor to filter for those authored by the advisor' do
            @student_page.toggle_my_notes
            advisor_notes = @student_notes.select { |n| n.advisor&.uid == other_advisor.uid }
            expect(@student_page.visible_collapsed_note_ids.sort).to eql(advisor_notes.map(&:id).sort)
          end
        end
      end

      describe 'director' do

        before do
          @homepage.dev_auth director
          @student_page.load_page test_student
          @student_page.show_notes
        end

        after do
          @homepage.load_page
          @homepage.log_out
        end

        it('can download notes') { @student_page.notes_download_link_element.when_visible Utils.short_wait }
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

        it('cannot create a batch note') { expect(@student_page.batch_note_button?).to be false }

        it('can download notes') { @student_page.notes_download_link_element.when_visible Utils.short_wait }

        it 'cannot edit a note' do
          @student_page.expand_item note_5
          expect(@student_page.edit_note_button(note_5).exists?).to be false
        end

        it 'can delete a note' do
          @student_page.delete_note note_5
          @student_page.collapsed_item_el(note_5).when_not_visible Utils.short_wait
          deleted = BOACUtils.get_note_delete_status note_5
          expect(deleted).to_not be_nil
        end
      end

      describe 'advisor' do

        before(:all) do
          @homepage.dev_auth
          @api_admin_page.reindex_notes
          @homepage.load_page
          @homepage.log_out

          @homepage.dev_auth test.advisor
          @student_page.open_adv_search
          @student_page.exclude_students
          @student_page.exclude_classes
        end

        it 'cannot find a deleted note' do
          logger.info "Searching for deleted note ID #{note_5.id} by subject '#{note_5.subject}'"
          @student_page.enter_adv_search_and_hit_enter note_5.subject
          expect(@search_results_page.note_results_count).to be_zero
        end

        it 'cannot download a deleted note\'s attachments' do
          note_5.attachments.each do |attach|
            Utils.prepare_download_dir
            @homepage.load_page
            id = BOACUtils.get_attachment_id_by_file_name(note_5, attach)
            @api_notes_page.load_attachment_page id
            @api_notes_page.note_not_found_msg_element.when_present Utils.short_wait
            expect(Utils.downloads_empty?).to be true
          end
        end
      end
    end
  end
end
