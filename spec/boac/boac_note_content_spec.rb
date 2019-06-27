require_relative '../../util/spec_helper'

include Logging

describe 'BOAC' do

  begin
    all_students = NessieUtils.get_all_students
    test = BOACTestConfig.new
    test.legacy_notes all_students
    students_with_asc_notes = []
    students_with_boa_notes = []
    students_with_sis_notes = []
    downloadable_attachments = []
    advisor_link_tested = false
    dept_uids = test.dept_students.map &:uid

    notes_data_heading = %w(UID SID NoteId Created Updated CreatedBy Advisor AdvisorRole AdvisorDepts HasBody Topics Attachments)
    notes_data = Utils.create_test_output_csv('boac-legacy-notes.csv', notes_data_heading)

    @driver = Utils.launch_browser
    @homepage = BOACHomePage.new @driver
    @student_page = BOACStudentPage.new @driver
    @search_results_page = BOACSearchResultsPage.new @driver
    @api_notes_attachment_page = BOACApiNotesAttachmentPage.new @driver

    @homepage.dev_auth test.advisor
    test.max_cohort_members.each do |student|

      begin
        @student_page.load_page student
        expected_asc_notes = NessieUtils.get_asc_notes student
        expected_boa_notes = BOACUtils.get_student_notes(student).delete_if &:deleted_date
        expected_sis_notes = NessieUtils.get_sis_notes student

        expected_notes = expected_sis_notes + expected_boa_notes + expected_asc_notes
        logger.warn "UID #{student.uid} has #{expected_sis_notes.length} Nessie notes and #{expected_boa_notes.length} BOA notes and #{expected_asc_notes.length.to_s} ASC notes"

        students_with_asc_notes << student if expected_asc_notes.any?
        students_with_boa_notes << student if expected_boa_notes.any?
        students_with_sis_notes << student if expected_sis_notes.any?

        if expected_notes.any?

          @student_page.show_notes

          visible_note_count = @student_page.note_msg_row_elements.length
          it("shows the right number of notes for UID #{student.uid}") { expect(visible_note_count).to eql((expected_notes).length) }

          expected_sort_order = @student_page.expected_note_id_sort_order(expected_notes)
          visible_sort_order = @student_page.visible_collapsed_note_ids
          it("shows the notes in the right order for UID #{student.uid}") { expect(visible_sort_order).to eql(expected_sort_order) }

          expected_notes.each do |note|

            begin
              test_case = "note ID #{note.id} for UID #{student.uid}"
              logger.info "Checking #{test_case}"

              # COLLAPSED NOTE

              visible_collapsed_note_data = @student_page.visible_collapsed_note_data note

              # Note updated date

              updated_date_expected = note.updated_date && note.updated_date != note.created_date && note.advisor.uid != 'UCBCONVERSION'
              expected_date = updated_date_expected ? note.updated_date : note.created_date
              expected_date_text = "Last updated on #{@student_page.expected_note_short_date_format expected_date}"
              visible_date = @student_page.visible_collapsed_note_data(note)[:date]
              it("shows '#{expected_date_text}' on collapsed #{test_case}") { expect(visible_date).to eql(expected_date_text) }

              # EXPANDED NOTE

              @student_page.expand_note note
              visible_expanded_note_data = @student_page.visible_expanded_note_data note

              # Note subject and body (NB: migrated SIS notes have no subject, so the body is shown as the subject; migrated ASC notes have no subject
              # or body, so the general topic is shown as the subject)

              if note.subject
                it("shows the subject on #{test_case}") { expect(visible_collapsed_note_data[:subject] == note.subject).to be true }
                it("shows the body on #{test_case}") { expect(visible_expanded_note_data[:body].strip == note.body).to be true }
              elsif expected_sis_notes.include? note
                it("shows the body as the subject on #{test_case}") { expect(visible_collapsed_note_data[:subject].gsub(/\W/, '') == note.body.gsub(/\W/, '')).to be true }
                it("shows no body on #{test_case}") { expect(visible_expanded_note_data[:body].strip.empty?).to be true }
              else
                expected_subj = "AthleticStudyCenteradvisor#{note.advisor.first_name}#{note.advisor.last_name}#{note.topics.first.capitalize if note.topics.any?}"
                it("shows the advisor and topic as the subject on #{test_case}") { expect(visible_collapsed_note_data[:subject].gsub(/\W/, '') == expected_subj).to be true }
                it("shows no body on #{test_case}") { expect(visible_expanded_note_data[:body].strip.empty?).to be true }
              end

              # Note advisor

              if note.advisor.uid
                logger.warn "No advisor shown for UID #{note.advisor.uid} on #{test_case}" unless visible_expanded_note_data[:advisor]

                if visible_expanded_note_data[:advisor] && !advisor_link_tested
                  advisor_link_works = @student_page.external_link_valid?(@driver, @student_page.note_advisor_el(note), 'Campus Directory | University of California, Berkeley')
                  advisor_link_tested = true
                  it("offers a link to the Berkeley directory for advisor #{note.advisor.uid} on #{test_case}") { expect(advisor_link_works).to be true }
                end

              else
                it("shows no advisor on #{test_case}") { expect(visible_expanded_note_data[:advisor]).to be_nil }
              end

              # Note topics

              if note.topics.any?
                topics = note.topics.map(&:upcase).uniq
                topics.sort! if expected_boa_notes.include? note
                (it("shows the right topics on #{test_case}") { expect(visible_expanded_note_data[:topics]).to eql(topics) })
              else
                (it("shows no topics on #{test_case}") { expect(visible_expanded_note_data[:topics]).to be_empty })
              end

              # Note dates

              if updated_date_expected
                expected_update_date_text = @student_page.expected_note_long_date_format note.updated_date
                it("shows update date #{expected_update_date_text} on expanded #{test_case}") { expect(visible_expanded_note_data[:updated_date]).to eql(expected_update_date_text) }
              else
                it("shows no updated date #{note.updated_date} on expanded #{test_case}") { expect(visible_expanded_note_data[:updated_date]).to be_nil }
              end

              expected_create_date_text = (note.advisor.uid == 'UCBCONVERSION') ?
                  @student_page.expected_note_short_date_format(note.created_date) :
                  @student_page.expected_note_long_date_format(note.created_date)
              it("shows creation date #{expected_create_date_text} on expanded #{test_case}") { expect(visible_expanded_note_data[:created_date]).to eql(expected_create_date_text) }

              # Note attachments

              if note.attachments.any?
                non_deleted_attachments = note.attachments.reject &:deleted_at
                attachment_file_names = non_deleted_attachments.map &:file_name
                it("shows the right attachment file names on #{test_case}") { expect(visible_expanded_note_data[:attachments].sort).to eql(attachment_file_names.sort) }

                non_deleted_attachments.each do |attach|
                  if attach.sis_file_name
                    has_delete_button = @student_page.delete_note_button(note).exists?
                    it("shows no delete button for imported #{test_case}") { expect(has_delete_button).to be false }
                  end

                  # TODO - get downloads working on Firefox, since the profile prefs aren't having the desired effect
                  if @student_page.note_attachment_el(note, attach.file_name).tag_name == 'a' && "#{@driver.browser}" != 'firefox'
                    begin
                      file_size = @student_page.download_attachment(note, attach, student)
                      if file_size
                        attachment_downloads = file_size > 0
                        downloadable_attachments << attach
                        it("allows attachment ID #{attach.id} to be downloaded from #{test_case}") { expect(attachment_downloads).to be true }
                      end
                    rescue => e
                      Utils.log_error e
                      it("encountered an error downloading attachment ID #{attach.id} from #{test_case}") { fail }

                      # If the note download fails, the browser might no longer be on the student page so reload it.
                      @student_page.load_page student
                      @student_page.show_notes
                    end

                  else
                    logger.warn "Skipping download test for note ID #{note.id} attachment ID #{attach.id} since it cannot be downloaded"
                  end
                end

              else
                it("shows no attachment file names on #{test_case}") { expect(visible_expanded_note_data[:attachments]).to be_empty }
              end

              # Permalink

              logger.info "Checking permalink: '#{visible_expanded_note_data[:permalink_url]}'"
              @homepage.load_page
              @student_page.navigate_to visible_expanded_note_data[:permalink_url]
              permalink_works = @student_page.verify_block do
                @student_page.wait_until(Utils.short_wait) { @student_page.note_expanded? note }
              end

              it("offers a permalink on #{test_case}") { expect(permalink_works).to be true }

            rescue => e
              Utils.log_error e
              it("hit an error with #{test_case}") { fail }
            ensure
              row = [student.uid, student.sis_id, note.id, note.created_date, note.updated_date, note.advisor.uid, (visible_expanded_note_data[:advisor] if visible_expanded_note_data),
                     (visible_expanded_note_data[:advisor_role] if visible_expanded_note_data), (visible_expanded_note_data[:advisor_depts] if visible_expanded_note_data),
                     !note.body.nil?, note.topics.length, note.attachments.length]
              Utils.add_csv_row(notes_data, row)
            end
          end

        else
          logger.warn "Ain't got no notes for UID #{student.uid}"

          button_disabled = @student_page.notes_button_element.attribute('disabled')
          it("shows a disabled notes button for UID #{student.uid}") { expect(button_disabled).to be_truthy }
        end

      rescue => e
        Utils.log_error e
        it("hit an error with UID #{student.uid}") { fail }
      ensure
        # Make sure no attachment is left on the test machine
        Utils.prepare_download_dir
      end
    end

    it('has at least one test student with an ASC note') { expect(students_with_asc_notes.any?).to be true }
    it('has at least one test student with a BOA note') { expect(students_with_boa_notes.any?).to be true }
    it('has at least one test student with a SIS note') { expect(students_with_sis_notes.any?).to be true }

    if downloadable_attachments.any?
      other_depts = BOACDepartments::DEPARTMENTS.reject { |d| [test.dept, BOACDepartments::ADMIN, (BOACDepartments::L_AND_S unless NessieUtils.include_l_and_s?)].include? d }

      other_depts.each do |dept|

        test.dept = dept
        test.set_advisor
        test.set_dept_students all_students
        test_dept_sids = test.dept_students.map &:sis_id
        @homepage.load_page
        @homepage.log_out
        @homepage.dev_auth test.advisor

        downloadable_attachments.each do |attach|

          if attach.sis_file_name
            sid = attach.sis_file_name.split('_').first
            if test_dept_sids.include? sid
              logger.info "Skipping non-auth download test for SID #{sid} since it belongs to the advisor's department"

            else
              identifier = attach.sis_file_name || attach.id
              Utils.prepare_download_dir
              @api_notes_attachment_page.load_page identifier
              no_access = @api_notes_attachment_page.verify_block { @api_notes_attachment_page.not_found_msg_element.when_visible Utils.short_wait }
              it("blocks #{test.dept.name} advisor UID #{test.advisor.uid} from hitting the attachment download endpoint for #{identifier}") { expect(no_access).to be true }

              no_file = Utils.downloads_empty?
              it("delivers no file to #{test.dept.name} advisor UID #{test.advisor.uid} when hitting the attachment download endpoint for #{identifier}") { expect(no_file).to be true }
            end
          else
            logger.warn "Skipping download test for note attachment ID #{attach.id} since it is not a legacy note"
          end
        end
      end

      @homepage.load_page
      @homepage.log_out

      downloadable_attachments.each do |attach|

        identifier = attach.sis_file_name || attach.id
        Utils.prepare_download_dir
        @api_notes_attachment_page.load_page identifier
        no_access = @api_notes_attachment_page.verify_block { @api_notes_attachment_page.unauth_msg_element.when_visible Utils.short_wait }
        it("blocks an anonymous user from hitting the attachment download endpoint for #{identifier}") { expect(no_access).to be true }

        no_file = Utils.downloads_empty?
        it("delivers no file to an anonymous user when hitting the attachment download endpoint for #{identifier}") { expect(no_file).to be true }
      end
    else
      it('found no downloadable attachments') { fail }
    end

  rescue => e
    Utils.log_error e
    it('hit an error initializing') { fail }
  ensure
    Utils.quit_browser @driver
  end
end
