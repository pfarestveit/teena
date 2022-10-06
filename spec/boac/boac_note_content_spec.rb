require_relative '../../util/spec_helper'

if (ENV['DEPS'] || ENV['DEPS'].nil?) && !ENV['NO_DEPS']

  include Logging

  describe 'BOAC' do

    begin
      test = BOACTestConfig.new
      test.note_content
      downloadable_attachments = []
      advisor_link_tested = false
      max_note_count_per_src = BOACUtils.notes_max_notes - 1

      @driver = Utils.launch_browser
      @homepage = BOACHomePage.new @driver
      @student_page = BOACStudentPage.new @driver
      @search_results_page = BOACSearchResultsPage.new @driver
      @api_notes_page = BOACApiNotesPage.new @driver

      @homepage.dev_auth test.advisor
      test.test_students.each do |student|

        begin
          @student_page.load_page student
          expected_asc_notes = NessieTimelineUtils.get_asc_notes student
          expected_boa_notes = BOACUtils.get_student_notes student
          expected_data_notes = NessieTimelineUtils.get_data_sci_notes student
          expected_e_forms = NessieTimelineUtils.get_e_form_notes student
          expected_ei_notes = NessieTimelineUtils.get_e_and_i_notes student
          expected_history_notes = NessieTimelineUtils.get_history_notes student
          expected_sis_notes = NessieTimelineUtils.get_sis_notes student
          logger.warn "UID #{student.uid} has #{expected_sis_notes.length} SIS notes, #{expected_asc_notes.length} ASC notes,
                              #{expected_ei_notes.length} E&I notes, #{expected_boa_notes.length} BOA notes,
                              #{expected_e_forms.length} eForms, #{expected_data_notes.length} Data Science notes,
                              and #{expected_history_notes.length} History notes."

          expected_notes = expected_sis_notes +
            expected_boa_notes +
            expected_asc_notes +
            expected_e_forms +
            expected_ei_notes +
            expected_data_notes +
            expected_history_notes

          @student_page.show_notes

          visible_note_count = @student_page.note_msg_row_elements.length
          it("shows the right number of notes for UID #{student.uid}") { expect(visible_note_count).to eql((expected_notes).length) }

          expected_sort_order = @student_page.expected_note_id_sort_order(expected_notes)
          visible_sort_order = @student_page.visible_collapsed_note_ids
          it("shows the notes in the right order for UID #{student.uid}") { expect(visible_sort_order).to eql(expected_sort_order) }

          @student_page.expand_all_notes
          expected_notes.each do |note|
            note_expanded = @student_page.item_expanded? note
            it("expand-all-notes button expands note ID #{note.id} for UID #{student.uid}") { expect(note_expanded).to be true }
          end

          @student_page.collapse_all_notes
          expected_notes.each do |note|
            note_expanded = @student_page.item_expanded? note
            it("collapse-all-notes-button collapses note ID #{note.id} for UID #{student.uid}") { expect(note_expanded).to be false }
          end

          # Test a representative subset of the total notes
          test_notes = expected_sis_notes.shuffle[0..max_note_count_per_src] +
            expected_asc_notes.shuffle[0..max_note_count_per_src] +
            expected_boa_notes.shuffle[0..max_note_count_per_src] +
            expected_data_notes.shuffle[0..max_note_count_per_src] +
            expected_e_forms.shuffle[0..max_note_count_per_src] +
            expected_ei_notes.shuffle[0..max_note_count_per_src] +
            expected_history_notes.shuffle[0..max_note_count_per_src]

          logger.info "Test notes are #{test_notes.map { |n| n.id + ' of source ' +  (n.source ? n.source.name : 'BOA') }}"

          test_notes.each do |note|

            begin
              test_case = "note ID #{note.id} for UID #{student.uid}"
              logger.info "Checking #{test_case}"

              if note.subject && note.subject.include?('QA Test')
                logger.warn "Skipping note ID #{note.id} for UID #{student.uid} because it is a testing artifact"

              else

                # COLLAPSED NOTE

                @student_page.show_notes
                visible_collapsed_note_data = @student_page.visible_collapsed_note_data note

                # Note updated date

                updated_date_expected = note.updated_date &&
                  note.updated_date.strftime('%b %-d, %Y %l:%M%P') != note.created_date.strftime('%b %-d, %Y %l:%M%P') &&
                  (!note.instance_of?(TimelineEForm) && note.advisor&.uid != 'UCBCONVERSION')
                expected_date = updated_date_expected ? note.updated_date : note.created_date
                expected_date_text = "Last updated on #{@student_page.expected_item_short_date_format expected_date}"
                visible_date = @student_page.visible_collapsed_item_data(note)[:date]
                it("shows '#{expected_date_text}' on collapsed #{test_case}") { expect(visible_date).to eql(expected_date_text) }

                # EXPANDED NOTE

                @student_page.expand_item note

                if note.source == TimelineRecordSource::E_FORM
                  visible_e_form_data = @student_page.visible_expanded_e_form_data note
                  expected_subj = "eForm: L&S Late Change of Schedule Request — #{note.status}"
                  expected_created_date = @student_page.expected_item_short_date_format note.created_date
                  expected_updated_date = @student_page.expected_item_long_date_format note.updated_date
                  expected_initiated_date = note.created_date.strftime('%m/%d/%Y')
                  expected_final_date = note.updated_date.strftime('%m/%d/%Y %-l:%M:%S%P')
                  it("shows the subject on #{test_case}") { expect(visible_collapsed_note_data[:subject]).to eql(expected_subj) }
                  it("shows the created date on #{test_case}") { expect(visible_e_form_data[:created_date]).to eql(expected_created_date) }
                  it("shows the updated date on #{test_case}") { expect(visible_e_form_data[:updated_date]).to eql(expected_updated_date) }
                  it("shows the term on #{test_case}") { expect(visible_e_form_data[:term]).to eql(note.term) }
                  it("shows the course on #{test_case}") { expect(visible_e_form_data[:course]).to eql(note.course) }
                  it("shows the form ID on #{test_case}") { expect(visible_e_form_data[:form_id]).to eql(note.form_id) }
                  it("shows the date initiated on #{test_case}") { expect(visible_e_form_data[:date_initiated]).to eql(expected_initiated_date) }
                  it("shows the form status on #{test_case}") { expect(visible_e_form_data[:status]).to eql(note.status) }
                  it("shows the final date on #{test_case}") { expect(visible_e_form_data[:date_finalized]).to eql(expected_final_date) }

                else
                  visible_expanded_note_data = @student_page.visible_expanded_note_data note

                  # Note subject and body (NB: migrated SIS notes and History notes have no subject, so the body is shown as the subject;
                  # older migrated ASC notes have no subject or body, so the general topic is shown as the subject)

                  if note.subject
                    it("shows the subject on #{test_case}") { expect(visible_collapsed_note_data[:subject] == note.subject.strip).to be true }
                    it("shows the body on #{test_case}") { expect(visible_expanded_note_data[:body].strip.gsub(/\W/, '')).to eql(note.body.strip.gsub(/\W/, '')) }
                  elsif expected_sis_notes.include?(note) || expected_history_notes.include?(note)
                    it("shows the body as the subject on #{test_case}") { expect(visible_collapsed_note_data[:subject].gsub(/\W/, '')).to eql(note.body.gsub(/\W/, '')) }
                    it("shows no body on #{test_case}") { expect(visible_expanded_note_data[:body].strip.empty?).to be true }
                  elsif expected_data_notes.include?(note)
                    if note.body && !note.body.empty?
                      it("shows the body as the subject on #{test_case}") { expect(visible_collapsed_note_data[:subject].gsub(/\W/, '')).to eql(note.body.gsub(/\W/, '')) }
                    end
                  elsif expected_asc_notes.include?(note) && note.body
                    it("shows the body as the subject on #{test_case}") { expect(visible_collapsed_note_data[:subject].gsub(/\W/, '')).to eql(note.body.gsub(/\W/, '')) }
                  else
                    it("shows the department as part of the subject on #{test_case}") { expect(visible_collapsed_note_data[:category]).to include('Athletic Study Center advisor') }
                    it("shows the advisor first name as part of the subject on #{test_case}") do
                      expect(expect(visible_collapsed_note_data[:category].downcase).to include(note.advisor.first_name.downcase))
                    end
                    it("shows the advisor last name as part of the subject on #{test_case}") do
                      expect(expect(visible_collapsed_note_data[:category].downcase).to include(note.advisor.last_name.downcase))
                    end
                    it("shows no body on #{test_case}") { expect(visible_expanded_note_data[:body].strip.empty?).to be true }
                  end

                  if expected_ei_notes.include? note
                    it("shows no body on #{test_case}") { expect(visible_expanded_note_data[:body].strip.empty?).to be true }
                  end

                  # Note advisor

                  if note.advisor
                    if note.advisor.uid
                      logger.warn "No advisor shown for UID #{note.advisor.uid} on #{test_case}" unless visible_expanded_note_data[:advisor]

                      if visible_expanded_note_data[:advisor] && !advisor_link_tested
                        if visible_expanded_note_data[:advisor].include? 'Graduate Intern'
                          has_link = (@student_page.note_advisor_el(note).tag_name == 'a')
                          it("offers no link to the Berkeley directory for advisor 'Graduate Intern' on #{test_case}") { expect(has_link).to be false }
                        else
                          advisor_link_works = @student_page.external_link_valid?(@student_page.note_advisor_el(note), 'Campus Directory | University of California, Berkeley')
                          advisor_link_tested = true
                          it("offers a link to the Berkeley directory for advisor #{note.advisor.uid} on #{test_case}") { expect(advisor_link_works).to be true }
                        end
                      end

                    else
                      if note.advisor.last_name && !note.advisor.last_name.empty?
                        it("shows an advisor on #{test_case}") { expect(visible_expanded_note_data[:advisor]).not_to be_nil }
                      else
                        it("shows Graduate Intern or Peer Advisor on #{test_case}") { expect(['Graduate Intern', 'Peer Advisor']).to include(visible_expanded_note_data[:advisor]) }
                      end
                    end
                  elsif expected_data_notes.include? note
                    it("shows an advisor on #{test_case}") { expect(visible_expanded_note_data[:advisor]).not_to be_nil }
                  end

                  # Note source

                  if note.source
                    shows_src = visible_expanded_note_data[:note_src] == "(note imported from #{note.source.name})"
                    it("shows the note source '#{note.source.name}' on #{test_case}") { expect(shows_src).to be true }
                  else
                    it("shows no note source for BOA #{test_case}") { expect(visible_expanded_note_data[:note_src]).to be_nil }
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
                    expected_update_date_text = @student_page.expected_item_long_date_format note.updated_date
                    it "shows update date #{expected_update_date_text} on expanded #{test_case}" do
                      expect(visible_expanded_note_data[:updated_date]).to eql(expected_update_date_text)
                    end
                  end

                  expected_create_date_text = (note.advisor&.uid == 'UCBCONVERSION') ?
                                                @student_page.expected_item_short_date_format(note.created_date) :
                                                @student_page.expected_item_long_date_format(note.created_date)
                  it("shows creation date #{expected_create_date_text} on expanded #{test_case}") { expect(visible_expanded_note_data[:created_date]).to eql(expected_create_date_text) }

                  # Note attachments

                  if note.attachments.any?
                    non_deleted_attachments = note.attachments.reject &:deleted_at
                    attachment_file_names = non_deleted_attachments.map { |f| f.file_name.gsub(/\s+/, ' ') }
                    it("shows the right attachment file names on #{test_case}") { expect(visible_expanded_note_data[:attachments].sort).to eql(attachment_file_names.sort) }

                    non_deleted_attachments.each do |attach|
                      if attach.sis_file_name
                        has_delete_button = @student_page.delete_note_button(note).exists?
                        it("shows no delete button for imported #{test_case}") { expect(has_delete_button).to be false }
                      end

                      # TODO - get downloads working on Firefox, since the profile prefs aren't having the desired effect
                      if @student_page.item_attachment_el(note, attach.file_name)&.tag_name == 'a' && "#{@driver.browser}" != 'firefox'
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

                  # Note search

                  if (query = BOACUtils.generate_note_search_query(student, note))
                    @student_page.show_notes
                    initial_msg_count = @student_page.visible_message_ids.length
                    @student_page.search_within_timeline_notes(query[:string])
                    message_ids = @student_page.visible_message_ids

                    it("searches within academic timeline for #{query[:test_case]}") do
                      expect(message_ids.length).to be < (initial_msg_count) unless initial_msg_count == 1
                      expect(message_ids).to include(query[:note].id)
                    end

                    @student_page.clear_timeline_notes_search
                  end

                  # Permalink

                  logger.info "Checking permalink: '#{visible_expanded_note_data[:permalink_url]}'"
                  @homepage.load_page
                  @student_page.navigate_to visible_expanded_note_data[:permalink_url]
                  permalink_works = @student_page.verify_block do
                    @student_page.wait_until(Utils.short_wait) { @student_page.item_expanded? note }
                  end

                  it("offers a permalink on #{test_case}") { expect(permalink_works).to be true }

                end
              end
            rescue => e
              Utils.log_error e
              it("hit an error with #{test_case}") { fail }
            end
          end

        rescue => e
          Utils.log_error e
          it("hit an error with UID #{student.uid}") { fail }
        ensure
          # Make sure no attachment is left on the test machine
          Utils.prepare_download_dir
        end
      end

      if downloadable_attachments.any?

        @homepage.load_page
        @homepage.log_out

        downloadable_attachments.each do |attach|

          identifier = attach.sis_file_name || attach.id
          Utils.prepare_download_dir
          @api_notes_page.load_attachment_page identifier
          no_access = @api_notes_page.verify_block { @api_notes_page.unauth_msg_element.when_visible Utils.short_wait }
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
end
