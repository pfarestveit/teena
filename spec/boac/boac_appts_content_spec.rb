require_relative '../../util/spec_helper'

if (ENV['NO_DEPS'] || ENV['NO_DEPS'].nil?) && !ENV['DEPS']

  include Logging

  describe 'BOAC' do

    begin
      test = BOACTestConfig.new
      test.appts_content
      downloadable_attachments = []
      advisor_link_tested = false
      max_appt_count_per_src = BOACUtils.notes_max_notes - 1

      appts_data_heading = %w(UID SID NoteId Created Updated CreatedBy Advisor AdvisorRole AdvisorDepts HasBody Topics Attachments)
      appts_data = Utils.create_test_output_csv('boac-appts.csv', appts_data_heading)

      @driver = Utils.launch_browser
      @homepage = BOACHomePage.new @driver
      @student_page = BOACStudentPage.new @driver
      @search_results_page = BOACSearchResultsPage.new @driver
      @api_notes_page = BOACApiNotesPage.new @driver

      @homepage.dev_auth test.advisor
      test.test_students.each do |student|

        begin
          @student_page.load_page student
          expected_boa_appts = BOACUtils.get_student_appts(student, test.students).delete_if &:deleted_date
          expected_sis_appts = NessieUtils.get_sis_appts student
          logger.warn "UID #{student.uid} has #{expected_sis_appts.length} SIS appointments and #{expected_boa_appts.length} BOA appointments"

          expected_appts = expected_sis_appts + expected_boa_appts

          @student_page.show_appts

          visible_appt_count = @student_page.appt_msg_row_elements.length
          it("shows the right number of appointments for UID #{student.uid}") { expect(visible_appt_count).to eql((expected_appts).length) }

          expected_sort_order = (expected_appts.sort_by { |a| [a.created_date, a.id] }).reverse.map &:id
          visible_sort_order = @student_page.visible_collapsed_appt_ids
          it("shows the appointments in the right order for UID #{student.uid}") { expect(visible_sort_order).to eql(expected_sort_order) }

          @student_page.expand_all_appts
          expected_sis_appts.each do |appt|
            appt_expanded = @student_page.item_expanded? appt
            it("expand-all-appointments button expands appointment ID #{appt.id} for UID #{student.uid}") { expect(appt_expanded).to be true }
          end

          @student_page.collapse_all_appts
          expected_sis_appts.each do |appt|
            appt_expanded = @student_page.item_expanded? appt
            it("collapse-all-appointments-button collapses appointment ID #{appt.id} for UID #{student.uid}") { expect(appt_expanded).to be false }
          end

          # Test a representative subset of the total appts
          test_appts = expected_sis_appts.shuffle[0..max_appt_count_per_src]

          test_appts.each do |appt|

            begin
              test_case = "appointment ID #{appt.id} for UID #{student.uid}"
              logger.info "Checking #{test_case}"

              # COLLAPSED APPOINTMENT

              @student_page.show_appts
              visible_collapsed_appt_data = @student_page.visible_collapsed_appt_data appt

              # Appointment date

              expected_date_text = "Appointment date #{@student_page.expected_item_short_date_format appt.created_date}"
              visible_date = @student_page.visible_collapsed_item_data(appt)[:date]
              it("shows '#{expected_date_text}' on collapsed #{test_case}") { expect(visible_date).to eql(expected_date_text) }

              # EXPANDED APPOINTMENT

              @student_page.expand_item appt
              visible_expanded_appt_data = @student_page.visible_expanded_appt_data appt
              it("shows the detail on #{test_case}") { expect(visible_expanded_appt_data[:detail].gsub(/\W/, '')).to eql(appt.detail.gsub(/\W/, '')) }

              # Appointment advisor

              if appt.advisor.uid
                logger.warn "No advisor shown for UID #{appt.advisor.uid} on #{test_case}" unless visible_expanded_appt_data[:advisor]

                if visible_expanded_appt_data[:advisor] && !advisor_link_tested
                  advisor_link_works = @student_page.external_link_valid?(@student_page.appt_advisor_el(appt), 'Campus Directory | University of California, Berkeley')
                  advisor_link_tested = true
                  it("offers a link to the Berkeley directory for advisor #{appt.advisor.uid} on #{test_case}") { expect(advisor_link_works).to be true }
                end

              else
                if appt.advisor.last_name && !appt.advisor.last_name.empty?
                  it("shows an advisor on #{test_case}") { expect(visible_expanded_appt_data[:advisor]).not_to be_nil }
                end
              end

              # Appointment topics

              if appt.topics.any?
                topics = appt.topics.map(&:upcase).uniq
                topics.sort!
                it("shows the right topics on #{test_case}") { expect(visible_expanded_appt_data[:topics]).to eql(topics) }
              else
                it("shows no topics on #{test_case}") { expect(visible_expanded_appt_data[:topics]).to be_empty }
              end

              # Appointment dates

              expected_create_date_text = @student_page.expected_item_short_date_format(appt.created_date)
              it("shows creation date #{expected_create_date_text} on expanded #{test_case}") { expect(visible_expanded_appt_data[:created_date]).to eql(expected_create_date_text) }

              # Appointment attachments

              if appt.attachments.any?
                non_deleted_attachments = appt.attachments.reject &:deleted_at
                attachment_file_names = non_deleted_attachments.map &:file_name
                it("shows the right attachment file names on #{test_case}") { expect(visible_expanded_appt_data[:attachments].sort).to eql(attachment_file_names.sort) }

                non_deleted_attachments.each do |attach|
                  if attach.sis_file_name
                    has_delete_button = @student_page.delete_note_button(appt).exists?
                    it("shows no delete button for imported #{test_case}") { expect(has_delete_button).to be false }
                  end

                  if @student_page.item_attachment_el(appt, attach.file_name).tag_name == 'a' && "#{@driver.browser}" != 'firefox' && !Utils.headless?
                    begin
                      file_size = @student_page.download_attachment(appt, attach, student)
                      if file_size
                        attachment_downloads = file_size > 0
                        downloadable_attachments << attach
                        it("allows attachment ID #{attach.id} to be downloaded from #{test_case}") { expect(attachment_downloads).to be true }
                      end
                    rescue => e
                      Utils.log_error e
                      it("encountered an error downloading attachment ID #{attach.id} from #{test_case}") { fail }

                      # If the download fails, the browser might no longer be on the student page so reload it.
                      @student_page.load_page student
                      @student_page.show_appts
                    end

                  else
                    logger.warn "Skipping download test for appointment ID #{appt.id} attachment ID #{attach.id} since it cannot be downloaded"
                  end
                end

              else
                it("shows no attachment file names on #{test_case}") { expect(visible_expanded_appt_data[:attachments]).to be_empty }
              end

              # Appointment search

              query = BOACUtils.generate_appt_search_query(student, appt)

              if query
                @student_page.show_appts
                initial_msg_count = @student_page.visible_message_ids.length
                @student_page.search_within_timeline_appts(query[:string])
                message_ids = @student_page.visible_message_ids

                it("searches within academic timeline for #{query[:test_case]}") do
                  expect(message_ids.length).to be < (initial_msg_count) unless initial_msg_count == 1
                  expect(message_ids).to include(query[:appt].id)
                end

                @student_page.clear_timeline_appts_search
              end
            rescue => e
              Utils.log_error e
              it("hit an error with #{test_case}") { fail }
            ensure
              row = [student.uid, student.sis_id, appt.id, appt.created_date, appt.updated_date, appt.advisor.uid,
                     (visible_expanded_appt_data[:advisor] if visible_expanded_appt_data),
                     (visible_expanded_appt_data[:advisor_role] if visible_expanded_appt_data),
                     (visible_expanded_appt_data[:advisor_depts] if visible_expanded_appt_data),
                     !appt.body.nil?, appt.topics.length, appt.attachments.length]
              Utils.add_csv_row(appts_data, row)
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
        it('found no downloadable attachments') { fail } unless test.test_students.empty?
      end

    rescue => e
      Utils.log_error e
      it('hit an error initializing') { fail }
    ensure
      Utils.quit_browser @driver
    end
  end
end
