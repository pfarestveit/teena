require_relative '../../util/spec_helper'

include Logging

describe 'BOAC' do

  include Logging

  test = BOACTestConfig.new
  test.note_management NessieUtils.get_all_students
  test_student = test.dept_students.first

  before(:all) do
    @driver = Utils.launch_browser test.chrome_profile
    @homepage = BOACHomePage.new @driver
    @student_page = BOACStudentPage.new @driver
    timestamp = Time.now.iso8601
    @note = Note.new({
                         subject: "Square Biz at #{timestamp}",
                         body: "I'm talkin' square biz to you, baby (#{timestamp})",
                         advisor_uid: test.advisor.uid,
                         topics: [],
                         attachments: []
                     })
  end

  describe 'notes management' do

    context 'Dept advisor' do

      before(:all) do
        @homepage.dev_auth test.advisor
        @student_page.load_page test_student
      end

      it 'can create new note' do
        @student_page.create_new_note(@note)
        latest_note = BOACUtils.get_student_notes(test_student).last
        expect(latest_note.subject).to eql @note.subject
        @note.id = latest_note.id
      end

      it 'can edit note' do
        new_note_subject = "Lady Tee at #{Time.now.iso8601}"
        @student_page.update_note_subject(@note, new_note_subject)
        latest_note = BOACUtils.get_student_notes(test_student).last
        expect(latest_note.subject).to eql new_note_subject
        @note.subject = new_note_subject
      end

      it 'must confirm if discarding unsaved changes' do
        # TODO
      end

      after(:all) do
        @homepage.log_out
      end
    end

    context 'admin user' do

      before(:all) do
        admin = BOACUser.new({:uid => Utils.super_admin_uid})
        @homepage.dev_auth admin
        @student_page.load_page test_student
      end

      it 'can delete note' do
        note_subject = @note.subject
        @student_page.delete_note(@note)
        sleep 2
        notes = BOACUtils.get_student_notes(test_student)
        if notes.any?
          expect(notes.last.subject).to_not eql note_subject
        end
      end

      it 'does not offer \'new note\' button to admin' do
        @student_page.load_page test_student
        expect(@student_page.new_note_button_element.exists?).to be false
      end

      it 'does not offer \'edit note\' button to admin' do
        # TODO
      end

      after(:all) do
        @homepage.log_out
      end
    end

  end


  after(:all) {Utils.quit_browser @driver}


end
