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
  # TODO (attachments) - notes << (note_4 = Note.new({:advisor => test.advisor}))
  # TODO (topics) - notes << (note_5 = Note.new({:advisor => test.advisor}))

  describe 'A BOAC', order: :defined do

    include Logging

    before(:all) do
      @driver = Utils.launch_browser
      @homepage = BOACHomePage.new @driver
      @student_page = BOACStudentPage.new @driver
      @search_results_page = BOACSearchResultsPage.new @driver
    end

    after(:all) {Utils.quit_browser @driver}

    describe 'advisor' do

      before(:all) do
        @homepage.dev_auth test.advisor
        @student_page.load_page test_student
        @student_page.show_notes
      end

      after(:all) { @homepage.log_out }

      context 'creating a new note' do

        it 'cannot create a note without a subject' do
          @student_page.click_create_new_note
          @student_page.click_save_new_note
          @student_page.subj_required_msg_element.when_visible 1
          @student_page.click_cancel_note
        end

        it 'can cancel an unsaved new note' do
          @student_page.click_create_new_note
          @student_page.wait_for_element_and_type(@student_page.note_body_text_area_elements[0], 'An edit to forget')
          @student_page.click_cancel_note
          @student_page.confirm_note_discard
          @student_page.note_body_text_area_elements[0].when_not_visible 1
        end

        it 'can create a note with a subject' do
          note_1.subject = "Note 1 subject #{Utils.get_test_id}"
          @student_page.create_new_note note_1
          @student_page.verify_note note_1
        end

        it 'can create a note with a subject and a body' do
          note_2.subject = "Note 2 subject #{Utils.get_test_id}"
          note_2.body = "Note 2 body #{test.id}" unless "#{@driver.browser}" == 'firefox'
          @student_page.create_new_note note_2
          @student_page.verify_note note_2
        end

        it 'can create a long note with special characters' do
          note_3.subject = "Σημείωση θέμα 3 #{Utils.get_test_id}"
          note_3.body = 'ノート本体4' * 100 unless "#{@driver.browser}" == 'firefox'
          @student_page.create_new_note note_3
          @student_page.verify_note note_3
        end

        # TODO it 'can create a note with attachments' note_4
        # TODO it 'can create a note with topics' note_5

      end

      context 'searching for a newly created note' do

        before(:all) do
          @student_page.expand_search_options
          @student_page.uncheck_include_students_cbx
          @student_page.uncheck_include_classes_cbx
        end

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

      context 'editing an existing note' do

        before(:all) do
          @student_page.load_page test_student
          @student_page.show_notes
        end

        it 'can change the subject' do
          note_1.subject = "#{note_1.subject} - EDITED"
          @student_page.edit_note note_1
          @student_page.verify_note note_1
        end

        # TODO it 'can add note attachments' note_4
        # TODO it 'can remove note attachments' note_4
        # TODO it 'can add note topics' note_5
        # TODO it 'can remove note topics' note_5

        it 'can only edit one note at a time' do
          logger.debug 'Verifying only one note can be edited at once'
          @student_page.expand_note note_1
          @student_page.edit_note_button(note_1).when_visible 1
          @student_page.expand_note note_2
          @student_page.edit_note_button(note_2).when_visible 1
          @student_page.click_edit_note_button note_1
          expect(@student_page.edit_note_button(note_2).exists?).to be false
        end

        it('cannot create a new note while editing another') { expect(@student_page.new_note_button_element.disabled?).to be true }

        it 'can cancel the edit' do
          @student_page.click_cancel_note_edit
          @student_page.expand_note note_2
          @student_page.click_edit_note_button note_2
          @student_page.wait_for_element_and_type(@student_page.note_body_text_area_elements[1], 'An edit to forget')
          @student_page.click_cancel_note_edit
          @student_page.confirm_note_discard
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
      end

      context 'attempting to delete a note' do

        it 'cannot do so' do
          @student_page.expand_note note_1
          expect(@student_page.delete_note_button?).to be false
        end
      end

      context 'searching for an edited note' do

        it 'can find a note by edited content' do
          @student_page.search note_1.subject
          @search_results_page.wait_for_note_search_result_rows
          expect(@search_results_page.note_link(note_1).exists?).to be true
        end
      end
    end

    describe 'advisor other than the note creator' do

      before(:all) do
        @homepage.dev_auth other_advisor
        @student_page.load_page test_student
      end

      after(:all) { @homepage.log_out }

      notes.each do |note|
        it 'cannot edit the other user\'s note' do
          @student_page.expand_note note
          expect(@student_page.edit_note_button(note).exists?).to be false
        end
      end
    end

    describe 'admin' do

      before(:all) do
        @homepage.dev_auth
        @student_page.load_page test_student
      end

      after(:all) { @homepage.log_out }

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

      after(:all) { @homepage.log_out }

      notes.each do |note|
        it 'cannot find a deleted note' do
          logger.info "Searching for deleted note ID #{note.id} by subject '#{note.subject}'"
          @student_page.search note.subject
          @search_results_page.wait_for_note_search_result_rows
          expect(@search_results_page.note_link(note).exists?).to be false
        end
      end
    end
  end
end

