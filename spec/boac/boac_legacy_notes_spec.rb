require_relative '../../util/spec_helper'

include Logging

describe 'BOAC' do

  begin
    test = BOACTestConfig.new
    test.legacy_notes NessieUtils.get_all_students
    students_with_notes = []

    legacy_notes_data_heading = %w(UID SID NoteId Created Updated CreatedBy Body Category SubCategory Topics Attachments)
    legacy_notes_data = Utils.create_test_output_csv('boac-legacy-notes.csv', legacy_notes_data_heading)

    @driver = Utils.launch_browser
    @homepage = BOACHomePage.new @driver
    @student_page = BOACStudentPage.new @driver

    @homepage.dev_auth test.advisor
    test.max_cohort_members.each do |student|

      begin
        @student_page.load_page student
        expected_notes = NessieUtils.get_legacy_notes student

        if expected_notes.any?
          students_with_notes << student
          @student_page.show_notes

          visible_note_count = @student_page.note_msg_row_elements.length
          it("shows the right number of notes for UID #{student.uid}") { expect(visible_note_count).to eql(expected_notes.length) }

          expected_sort_order = @student_page.expected_note_id_sort_order expected_notes
          visible_sort_order = @student_page.visible_collapsed_note_ids
          it("shows the notes in the right order for UID #{student.uid}") { expect(visible_sort_order).to eql(expected_sort_order) }

          expected_notes.each do |note|

            begin
              test_case = "note ID #{note.id} for UID #{student.uid}"
              logger.info "Checking #{test_case}"

              # COLLAPSED NOTE

              updated_date_expected = note.updated_date && note.updated_date != note.created_date && note.advisor_uid != 'UCBCONVERSION'
              expected_date = updated_date_expected ? note.updated_date : note.created_date
              expected_date_text = "Last updated on #{@student_page.expected_note_short_date_format expected_date}"
              visible_date = @student_page.visible_collapsed_note_date note
              it("shows '#{expected_date_text}' on collapsed #{test_case}") { expect(visible_date).to eql(expected_date_text) }

              # EXPANDED NOTE

              @student_page.expand_note note
              visible_note_data = @student_page.visible_expanded_note_data note

              # Note body

              note_missing = note.body.nil? || note.body.strip.empty?
              note_missing ?
                  (it("shows the category and subcategory as the body on #{test_case}") { expect(visible_note_data[:body]).to eql("#{note.category}#{+', ' if note.subcategory}#{note.subcategory}") }) :
                  (it("shows the body on #{test_case}") { expect(visible_note_data[:body].gsub(/\s+/, '')).to eql(note.body.gsub(/\s+/, '')) })

              # Note advisor

              if note.advisor_uid
                it("shows an advisor #{note.advisor_uid} on #{test_case}") { expect(visible_note_data[:advisor]).to_not be_nil }

                if visible_note_data[:advisor]
                  advisor_link_works = @student_page.external_link_valid?(@driver, @student_page.note_advisor_el(note), 'Campus Directory | University of California, Berkeley')
                  it("offers a link to the Berkeley directory for advisor #{note.advisor_uid} on #{test_case}") { expect(advisor_link_works).to be true }
                end

              else
                it("shows no advisor on #{test_case}") { expect(visible_note_data[:advisor]).to be_nil }
              end

              # Note topics

              note.topics.any? ?
                  (it("shows topics #{note.topics} on #{test_case}") { expect(visible_note_data[:topics]).to eql(note.topics) }) :
                  (it("shows no topics on #{test_case}") { expect(visible_note_data[:topics]).to be_empty })

              # Note attachments

              if note.attachment_files.any?
                it("shows attachment file names #{note.attachment_files} on #{test_case}") { expect(visible_note_data[:attachments]).to eql (note.attachment_files) }

                # TODO
                note.attachment_files.each do |file|
                  it "allows attachment file #{file} to be downloaded from #{test_case}"
                end

              else
                it("shows no attachment file names on #{test_case}") { expect(visible_note_data[:attachments]).to be_empty }
              end

              # Note dates

              if updated_date_expected
                expected_update_date_text = "Updated: Last updated on #{@student_page.expected_note_long_date_format note.updated_date}"
                it("shows #{expected_update_date_text} on expanded #{test_case}") { expect(visible_note_data[:updated_date]).to eql(expected_update_date_text) }
              else
                it("shows no updated date #{note.updated_date} on expanded #{test_case}") { expect(visible_note_data[:updated_date]).to be_nil }
              end

              expected_create_date_text = "Created: Last updated on #{@student_page.expected_note_long_date_format note.created_date}"
              it("shows #{expected_create_date_text} on expanded #{test_case}") { expect(visible_note_data[:updated_date]).to eql(expected_create_date_text) }

            rescue => e
              Utils.log_error e
              it("hit an error with #{test_case}") { fail }
            ensure
              row = [student.uid, student.sis_id, note.id, note.created_date, note.updated_date, note.advisor_uid,
                     !note_missing, !note.category.nil?, !note.subcategory.nil?, note.topics.length,
                     note.attachment_files.length]
              Utils.add_csv_row(legacy_notes_data, row)
            end
          end

        else
          logger.warn "Ain't got no notes for UID #{student.uid}"
          button_disabled = @student_page.notes_button_element.attribute('disabled')
          it("shows a disabled notes button for UID #{student.uid}") { expect(button_disabled).to eql('true') }

        end

      rescue => e
        Utils.log_error e
        it("hit an error with UID #{student.uid}") { fail }
      end
    end

    it('has at least one test student with a note') { expect(students_with_notes.any?).to be true }

  rescue => e
    Utils.log_error e
    it('hit an error initializing') { fail }
  end
end
