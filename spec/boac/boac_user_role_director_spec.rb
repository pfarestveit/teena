require_relative '../../util/spec_helper'

unless ENV['NO_DEPS']

  test = BOACTestConfig.new
  test.user_role_director

  test_cases = test.test_students.map do |student|
    asc_notes = NessieTimelineUtils.get_asc_notes student
    boa_notes = BOACUtils.get_student_notes student
    data_sci_notes = NessieTimelineUtils.get_data_sci_notes student
    e_form_notes = NessieTimelineUtils.get_e_form_notes student
    ei_notes = NessieTimelineUtils.get_e_and_i_notes student
    history_notes = NessieTimelineUtils.get_history_notes student
    sis_notes = NessieTimelineUtils.get_sis_notes student
    {
      student: student,
      notes: (asc_notes + boa_notes + data_sci_notes + ei_notes + history_notes + sis_notes),
      e_forms: e_form_notes
    }
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

    test_cases.each do |test_case|

      if test_case[:notes]&.any?
        it "can download a notes zip file for UID #{test_case[:student].uid}" do
          @student_page.load_page test_case[:student]
          @student_page.show_notes
          @student_page.download_notes test_case[:student]
        end

        it "receives the right note export files for UID #{test_case[:student].uid}" do
          expected_files = @student_page.expected_note_export_file_names(test_case[:student], test_case[:notes], test.advisor).sort
          actual_files = @student_page.note_export_file_names(test_case[:student]).sort
          @student_page.wait_until(1, "Expected #{expected_files}, got #{actual_files}") { actual_files == expected_files }
        end

        it "receives a CSV containing the right number of notes for UID #{test_case[:student].uid}" do
          csv = @student_page.parse_note_export_csv_to_table test_case[:student]
          test_case.merge!({csv: csv})
          expect(csv.entries.length).to eql(test_case[:notes].length)
        end

        test_case[:notes].each do |note|
          it "receives a CSV containing the right data for UID #{test_case[:student].uid} note ID #{note.id}" do
            @student_page.verify_note_in_export_csv(test_case[:student], note, test_case[:csv], test.advisor)
          end
        end
      end

      if test_case[:e_forms]&.any?
        it "can download an eForms zip file for UID #{test_case[:student].uid}" do
          @student_page.load_page test_case[:student]
          @student_page.show_e_forms
          @student_page.download_e_forms test_case[:student]
        end

        it "receives the right eForm export files for UID #{test_case[:student].uid}" do
          expected_files = @student_page.expected_e_form_export_file_names(test_case[:student])
          actual_files = @student_page.e_form_export_file_names(test_case[:student])
          @student_page.wait_until(1, "Expected #{expected_files}, got #{actual_files}") { actual_files == expected_files }
        end

        it "receives a CSV containing the right number of eForms for UID #{test_case[:student].uid}" do
          csv = @student_page.parse_e_forms_export_csv_to_table test_case[:student]
          test_case.merge!({csv: csv})
          expect(csv.entries.length).to eql(test_case[:e_forms].length)
        end

        test_case[:e_forms].each do |e|
          it "receives a CSV containing the right data for UID #{test_case[:student].uid} eForm ID #{e.id}" do
            @student_page.verify_e_form_in_export_csv(test_case[:student], e, test_case[:csv])
          end
        end
      end
    end
  end
end
