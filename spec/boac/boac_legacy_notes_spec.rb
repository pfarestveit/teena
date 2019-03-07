require_relative '../../util/spec_helper'

include Logging

describe 'BOAC' do

  begin
    all_students = NessieUtils.get_all_students
    test = BOACTestConfig.new
    test.legacy_notes all_students
    students_with_notes = []
    downloadable_attachments = []
    advisor_link_tested = false
    dept_sids = test.dept_students.map &:sis_id

    legacy_notes_data_heading = %w(UID SID NoteId Created Updated CreatedBy HasBody Topics Attachments)
    legacy_notes_data = Utils.create_test_output_csv('boac-legacy-notes.csv', legacy_notes_data_heading)

    @driver = Utils.launch_browser
    @homepage = BOACHomePage.new @driver
    @student_page = BOACStudentPage.new @driver
    @search_results_page = BOACSearchResultsPage.new @driver
    @api_notes_page = BOACApiNotesAttachmentPage.new @driver

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

              it("shows the body on #{test_case}") { expect(visible_note_data[:body].gsub(/\W/, '')).to eql(note.body.gsub(/\W/, '')) }

              # Note advisor

              if note.advisor_uid
                # TODO - it("shows an advisor #{note.advisor_uid} on #{test_case}") { expect(visible_note_data[:advisor]).to_not be_nil }

                if visible_note_data[:advisor] && !advisor_link_tested
                  advisor_link_works = @student_page.external_link_valid?(@driver, @student_page.note_advisor_el(note), 'Campus Directory | University of California, Berkeley')
                  advisor_link_tested = true
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
                note.attachment_files.each do |file_name|
                  if @student_page.note_attachment_el(file_name).tag_name == 'a'
                    file_size = @student_page.download_attachment(note, file_name)
                    attachment_downloads = file_size > 0
                    downloadable_attachments << file_name
                    it("allows attachment file #{file_name} to be downloaded from #{test_case}") { expect(attachment_downloads).to be true }

                  else
                    logger.warn "Skipping download test for note ID #{note.id} attachment #{file_name} since it cannot be downloaded"
                  end
                end

              else
                it("shows no attachment file names on #{test_case}") { expect(visible_note_data[:attachments]).to be_empty }
              end

              # Note dates

              if updated_date_expected
                expected_update_date_text = "Last updated on #{@student_page.expected_note_long_date_format note.updated_date}"
                it("shows update date #{expected_update_date_text} on expanded #{test_case}") { expect(visible_note_data[:updated_date]).to eql(expected_update_date_text) }
              else
                it("shows no updated date #{note.updated_date} on expanded #{test_case}") { expect(visible_note_data[:updated_date]).to be_nil }
              end

              expected_create_date_text = (note.advisor_uid == 'UCBCONVERSION') ?
                  "Last updated on #{@student_page.expected_note_short_date_format note.created_date}" :
                  "Last updated on #{@student_page.expected_note_long_date_format note.created_date}"
              it("shows creation date #{expected_create_date_text} on expanded #{test_case}") { expect(visible_note_data[:created_date]).to eql(expected_create_date_text) }

            rescue => e
              Utils.log_error e
              it("hit an error with #{test_case}") { fail }
            ensure
              row = [student.uid, student.sis_id, note.id, note.created_date, note.updated_date, note.advisor_uid,
                     !note.body.nil?, note.topics.length, note.attachment_files.length]
              Utils.add_csv_row(legacy_notes_data, row)
            end
          end

          search_string_word_count = BOACUtils.config['notes_search_word_count']

          expected_notes.each do |note|
            if note.source_body_empty
              logger.warn "Skipping search test for UID #{student.uid} note ID #{note.id} because the source note body was empty and too many results will be returned."

            else
              body_words = note.body.split(' ')
              body_words = (body_words.map { |w| w.split("\n") }).flatten
              search_string = body_words[0..(search_string_word_count-1)].join(' ')

              unless search_string.include? '/'
                @student_page.search search_string

                results_count = @search_results_page.note_results_count
                it("returns results for search string #{search_string}") { expect(results_count).to be > 0 }

                unless results_count.zero?

                  it("shows no more than 20 results when searching for note #{note.id} with search string '#{search_string}'") { expect(results_count).to be <= 20 }

                  @search_results_page.wait_for_note_search_result_rows
                  visible_student_sids = @search_results_page.note_result_sids
                  it("returns only results for students in the advisor's department with search string '#{search_string}'") { expect(visible_student_sids - dept_sids).to be_empty }

                  student_result_returned = @search_results_page.note_link(note).exists?
                  it("returns a result for UID #{student.uid} for search string '#{search_string}'") { expect(student_result_returned).to be true }

                  if student_result_returned
                    result = @search_results_page.note_result(student, note)
                    updated_date_expected = note.updated_date && note.updated_date != note.created_date && note.advisor_uid != 'UCBCONVERSION'
                    expected_date = updated_date_expected ? note.updated_date : note.created_date
                    expected_date_text = "#{@student_page.expected_note_short_date_format expected_date}"
                    it("note search shows the student name for note #{note.id}") { expect(result[:student_name]).to eql(student.full_name) }
                    it("note search shows the student SID for note #{note.id}") { expect(result[:student_sid]).to eql(student.sis_id) }
                    it("note search shows a snippet of note #{note.id}") { expect(result[:snippet]).to include(search_string) }
                    # TODO - it("note search shows the advisor name on note #{note.id}") { expect(result[:advisor_name]).not_to be_nil } unless note.advisor_uid == 'UCBCONVERSION'
                    # TODO - it("note search shows the most recent updated date on note #{note.id}") { expect(result[:date]).to eql(expected_date_text) }
                  end
                end
              end
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
      ensure
        # Make sure no attachment is left on the test machine
        Utils.prepare_download_dir
      end
    end

    it('has at least one test student with a note') { expect(students_with_notes.any?).to be true }

    if students_with_notes.any?
      other_depts = BOACDepartments::DEPARTMENTS.reject { |d| [test.dept, BOACDepartments::ADMIN].include? d }

      other_depts.each do |dept|

        test.dept = dept
        test.set_advisor
        test.set_dept_students all_students
        test_dept_sids = test.dept_students.map &:sis_id
        @homepage.load_page
        @homepage.log_out
        @homepage.dev_auth test.advisor

        downloadable_attachments.each do |attach|

          sid = attach.split('_').first
          if test_dept_sids.include? sid
            logger.info "Skipping non-auth download test for SID #{sid} since it belongs to the advisor's department"

          else
            @api_notes_page.load_page attach
            no_access = @api_notes_page.verify_block { @api_notes_page.not_found_msg_element.when_visible Utils.short_wait }
            it("blocks #{test.dept.name} advisor UID #{test.advisor.uid} from hitting the attachment download endpoint for #{attach}") { expect(no_access).to be true }

            no_file = Dir["#{Utils.download_dir}/#{attach}"].empty?
            it("delivers no file to #{test.dept.name} advisor UID #{test.advisor.uid} when hitting the attachment download endpoint for #{attach}") { expect(no_file).to be true }

          end
        end
      end

      @homepage.load_page
      @homepage.log_out

      downloadable_attachments.each do |attach|

        @api_notes_page.load_page attach
        no_access = @api_notes_page.verify_block { @api_notes_page.unauth_msg_element.when_visible Utils.short_wait }
        it("blocks an anonymous user from hitting the attachment download endpoint for #{attach}") { expect(no_access).to be true }

        no_file = Dir["#{Utils.download_dir}/#{attach}"].empty?
        it("delivers no file to an anonymous user when hitting the attachment download endpoint for #{attach}") { expect(no_file).to be true }

      end
    end

  rescue => e
    Utils.log_error e
    it('hit an error initializing') { fail }
  end
end
