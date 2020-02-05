require_relative '../../util/spec_helper'

test = BOACTestConfig.new
test.user_role_director

test_cases = test.test_students.map do |student|
  boa_notes = BOACUtils.get_student_notes student
  sis_notes = NessieUtils.get_sis_notes student
  ei_notes = NessieUtils.get_e_and_i_notes student
  asc_notes = NessieUtils.get_asc_notes student
  {student: student, notes: (boa_notes + sis_notes + ei_notes + asc_notes)}
end

describe 'A BOA director' do

  include Logging

  before(:all) do

    @driver = Utils.launch_browser
    @homepage = BOACHomePage.new @driver
    @student_page = BOACStudentPage.new @driver
    @settings_page = BOACFlightDeckPage.new @driver
    @api_admin_page = BOACApiAdminPage.new @driver

    @homepage.dev_auth test.advisor
  end

  after(:all) { Utils.quit_browser @driver }

  it 'can enable a drop-in advising role' do
    @settings_page.load_page
    @settings_page.enable_drop_in_advising_role(test.advisor.dept_memberships.first)
    @homepage.load_page
    @homepage.new_appt_button_element.when_visible Utils.short_wait
  end

  test_cases.each do |test_case|
    it "can download a notes zip file for UID #{test_case[:student].uid}" do
      @student_page.load_page test_case[:student]
      @student_page.show_notes
      @student_page.download_notes test_case[:student]
    end

    it "receives the right note export files for UID #{test_case[:student].uid}" do
      expected_files = @student_page.expected_note_export_file_names(test_case[:student], test_case[:notes]).sort
      actual_files = @student_page.note_export_file_names(test_case[:student]).sort
      expect(actual_files).to eql(expected_files)
    end

    it "receives a CSV containing the right number of notes for UID #{test_case[:student].uid}" do
      csv = @student_page.parse_note_export_csv_to_table test_case[:student]
      test_case.merge!({csv: csv})
      expect(csv.entries.length).to eql(test_case[:notes].length)
    end

    test_case[:notes].each do |note|
      it "receives a CSV containing the right data for UID #{test_case[:student].uid} note ID #{note.id}" do
        @student_page.verify_note_in_export_csv(test_case[:student], note, test_case[:csv])
      end
    end
  end
end
