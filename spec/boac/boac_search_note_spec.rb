require_relative '../../util/spec_helper'

unless ENV['NO_DEPS']

  describe 'BOAC' do

    include Logging

    begin

      test_config = BOACTestConfig.new
      test_config.search_notes
      max_note_count_per_src = BOACUtils.notes_max_notes - 1
      word_count = BOACUtils.search_word_count

      @driver = Utils.launch_browser test_config.chrome_profile
      @homepage = BOACHomePage.new @driver
      @search_results_page = BOACSearchResultsPage.new @driver
      @api_admin_page = BOACApiAdminPage.new @driver
      @homepage.dev_auth
      @api_admin_page.reindex_notes
      @homepage.load_page
      @homepage.log_out

      @homepage.dev_auth test_config.advisor

      # COLLECT DATA TO DRIVE SEARCH TESTS

      student_searches = []
      all_advising_note_authors = NessieTimelineUtils.get_all_advising_note_authors

      test_config.test_students.each do |student|

        begin
          note_searches = []
          expected_asc_notes = NessieTimelineUtils.get_asc_notes student
          expected_boa_notes = BOACUtils.get_student_notes student
          expected_boa_notes.delete_if do |n|
            (n.is_draft && n.advisor.uid != test_config.advisor.uid) || n.is_private
          end
          expected_data_notes = NessieTimelineUtils.get_data_sci_notes student
          expected_ei_notes = NessieTimelineUtils.get_e_and_i_notes student
          expected_eop_notes = NessieTimelineUtils.get_eop_notes student
          expected_eop_notes.delete_if &:is_private
          expected_history_notes = NessieTimelineUtils.get_history_notes student
          expected_sis_notes = NessieTimelineUtils.get_sis_notes student
          logger.warn "UID #{student.uid} has #{expected_sis_notes.length} SIS notes, #{expected_asc_notes.length} ASC notes,
                              #{expected_ei_notes.length} E&I notes, #{expected_data_notes.length} Data Science notes,
                              #{expected_history_notes.length} History notes, #{expected_eop_notes.length} EOP notes,
                              and #{expected_boa_notes.length} testable BOA notes"

          # Test a representative subset of the total notes
          range = 0..max_note_count_per_src
          test_notes = expected_sis_notes.shuffle[range] +
            expected_asc_notes.shuffle[range] +
            expected_boa_notes.shuffle[range] +
            expected_data_notes.shuffle[range] +
            expected_ei_notes.shuffle[range] +
            expected_eop_notes.shuffle[range] +
            expected_history_notes.shuffle[range]

          logger.info "Test notes are #{test_notes.map { |n| n.id + ' of source ' + (n.source ? n.source.name : 'BOA') }}"

          if test_notes.any?
            test_notes.each do |note|
              begin
                if (query = BOACUtils.generate_note_search_query(student, note, skip_empty_body: true))
                  note_searches << query
                end
              rescue => e
                Utils.log_error e
                it("hit an error collecting note search tests for UID #{student.uid} note ID #{note.id}") { fail e.message }
              end
            end
          else
            logger.warn "Bummer, UID #{student.uid} has no notes to search for"
          end

          student_searches << { student: student, note_searches: note_searches }

        rescue => e
          Utils.log_error e
          it("hit an error collecting test searches for UID #{student.uid}") { fail e.message }
        end
      end

      # EXECUTE SEARCHES

      @homepage.load_page

      student_searches.each do |search|

        logger.info "Beginning note search tests for UID #{search[:student].uid}"
        logger.info "Searchable notes are #{search[:note_searches].map { |s| s[:note].id + ' of source ' + (s[:note].source ? s[:note].source.name : 'BOA') }}"

        search[:note_searches].each do |note_search|

          logger.info "Beginning note search tests for note ID #{note_search[:note].id}"

          begin
            if note_search[:note].source_body_empty || !note_search[:note].body || note_search[:note].body.empty?
              logger.warn "Skipping search test for #{note_search[:test_case]} because the source note body was empty and too many results will be returned."

            elsif !note_search[:string]
              logger.warn "Skipping search test for #{note_search[:test_case]} because Teena couldn't find a legit search string"

            else

              # Search string

              @homepage.close_adv_search_if_open
              @homepage.enter_simple_search_and_hit_enter note_search[:string]

              string_results_count = @search_results_page.note_results_count
              it "returns results when searching with the last #{word_count} words in #{note_search[:test_case]}" do
                expect(string_results_count).to be > 0
              end
              it "shows no more than 20 results when searching with the last #{word_count} words in #{note_search[:test_case]}" do
                expect(string_results_count).to be <= 20
              end

              if string_results_count > 0 && string_results_count < 20
                @search_results_page.wait_for_note_search_result_rows
                student_result_returned = @search_results_page.note_in_search_result?(note_search[:note])
                it "returns a result when searching with the last #{word_count} words in #{note_search[:test_case]}" do
                  expect(student_result_returned).to be true
                end

                if student_result_returned
                  result = @search_results_page.note_result(search[:student], note_search[:note])
                  updated_date_expected = note_search[:note].updated_date &&
                    note_search[:note].updated_date != note_search[:note].created_date &&
                    note_search[:note].advisor.uid != 'UCBCONVERSION'
                  expected_date = updated_date_expected ? note_search[:note].updated_date : note_search[:note].created_date
                  expected_date_text = "#{expected_date.strftime('%b %-d, %Y')}"
                  it "note search shows the student name for #{note_search[:test_case]}" do
                    expect(result[:student_name]).to eql(search[:student].full_name)
                  end
                  it "note search shows the student SID for #{note_search[:test_case]}" do
                    expect(result[:student_sid]).to eql(search[:student].sis_id)
                  end
                  it "note search shows the most recent updated date on #{note_search[:test_case]}" do
                    expect(result[:date]).to eql(expected_date_text)
                  end
                end
              else
                logger.warn "Skipping a search string test with note ID #{note_search[:note].id} because there are more than 20 results"
              end

              # Topics

              @homepage.reopen_and_reset_adv_search

              all_topics = Topic::TOPICS.select(&:for_notes).map &:name
              note_topics = all_topics.select { |topic_name| note_search[:note].topics.include? topic_name.upcase }
              non_note_topics = all_topics - note_topics

              if [TimelineRecordSource::ASC, TimelineRecordSource::DATA].include? note_search[:note].source
                logger.warn 'Skipping search by topic since note source is ASC or Data Science, and they cannot be searched by topic'
              else
                note_topics.each do |note_topic|
                  topic = Topic::TOPICS.find { |t| t.name == note_topic }
                  @homepage.select_note_topic topic
                  @homepage.enter_adv_search_and_hit_enter note_search[:string]
                  topic_results_count = @search_results_page.note_results_count

                  if topic_results_count < 20
                    topic_match = @search_results_page.note_in_search_result?(note_search[:note])
                    it "returns a result when searching with the last #{word_count} words in note ID #{note_search[:note].id} and matching topic #{topic.name}" do
                      expect(topic_match).to be true
                    end

                    non_topic = Topic::TOPICS.find { |t| t.name == non_note_topics.first }
                    @homepage.select_note_topic non_topic
                    @homepage.enter_adv_search note_search[:string]
                    @homepage.click_adv_search_button
                    topic_no_match = @search_results_page.note_in_search_result?(note_search[:note])
                    it "returns no result when searching with the last #{word_count} words in note ID #{note_search[:note].id} and non-matching topic #{topic.name}" do
                      expect(topic_no_match).to be false
                    end
                  else
                    logger.warn "Skipping a search string + topic test with note ID #{note_search[:note].id} because there are more than 20 results"
                  end
                end
              end

              # Posted by

              if note_search[:note].advisor

                @homepage.reopen_and_reset_adv_search
                logger.info "Checking filters for #{note_search[:test_case]} posted by UID #{note_search[:note].advisor.uid}"

                if note_search[:note].advisor.uid == test_config.advisor.uid
                  logger.info 'Searching for a note posted by the logged in advisor'

                  # Posted by you
                  @homepage.select_notes_posted_by_you
                  @homepage.enter_adv_search note_search[:string]
                  @homepage.click_adv_search_button
                  you_posted_results_count = @search_results_page.note_results_count

                  if you_posted_results_count < 20
                    you_posted_match = @search_results_page.note_in_search_result?(note_search[:note])
                    it "returns a result when searching with the last #{word_count} words in #{note_search[:test_case]} and posted by #{test_config.advisor.uid}" do
                      expect(you_posted_match).to be true
                    end
                  else
                    logger.warn "Skipping a search string + posted-by-you test with note ID #{note_search[:note].id} because there are more than 20 results"
                  end

                  # Posted by anyone
                  @homepage.click_edit_search
                  @homepage.select_notes_posted_by_anyone
                  @homepage.click_adv_search_button
                  anyone_posted_results_count = @search_results_page.note_results_count

                  if anyone_posted_results_count < 20
                    anyone_posted_match = @search_results_page.note_in_search_result?(note_search[:note])
                    it "returns a result when searching with the last #{word_count} words in #{note_search[:test_case]} and posted by anyone" do
                      expect(anyone_posted_match).to be true
                    end
                  else
                    logger.warn "Skipping a search string + posted-by-anyone test with note ID #{note_search[:note].id} because there are more than 20 results"
                  end

                else
                  if note_search[:note].advisor.uid == 'UCBCONVERSION'
                    logger.warn 'Skipping test for note-posted-by because the available UID is UCBCONVERSION, which might or might not match the logged in user'

                  else
                    logger.info 'Searching for a note posted by someone other than the logged in advisor'

                    # Posted by you
                    @homepage.reopen_and_reset_adv_search
                    @homepage.enter_adv_search note_search[:string]
                    @homepage.select_notes_posted_by_you
                    @homepage.click_adv_search_button
                    you_posted_results_count = @search_results_page.note_results_count

                    if you_posted_results_count < 20
                      you_posted_match = @search_results_page.note_in_search_result?(note_search[:note])
                      it "returns no result when searching with the last #{word_count} words in #{note_search[:test_case]} and posted by #{test_config.advisor.uid}" do
                        expect(you_posted_match).to be_falsey
                      end
                    else
                      logger.warn "Skipping a search string + posted-by-you test with note ID #{note_search[:note].id} because there are more than 20 results"
                    end

                    # Posted by anyone
                    @search_results_page.click_edit_search
                    @homepage.reset_adv_search
                    @homepage.select_notes_posted_by_anyone
                    search_disabled = @homepage.adv_search_button_element.attribute('disabled') == 'true'
                    if note_search[:string].to_s.empty?
                      it "requires a non-empty search string when searching for #{note_search[:test_case]} and posted by anyone" do
                        expect(search_disabled).to be true
                      end
                    else
                      @homepage.enter_adv_search note_search[:string]
                      @homepage.click_adv_search_button
                      anyone_posted_results_count = @search_results_page.note_results_count

                      if anyone_posted_results_count < 20
                        anyone_posted_match = @search_results_page.note_in_search_result?(note_search[:note])
                        it "returns a result when searching with the last #{word_count} words in #{note_search[:test_case]} and posted by anyone" do
                          expect(anyone_posted_match).to be true
                        end
                      else
                        logger.warn "Skipping a search string + posted-by-anyone test with note ID #{note_search[:note].id} because there are more than 20 results"
                      end
                    end

                    # Posted by advisor name

                    author = NessieTimelineUtils.get_advising_note_author note_search[:note].advisor.uid
                    if author

                      author_name = "#{author[:first_name]} #{author[:last_name]}"
                      @homepage.reopen_and_reset_adv_search
                      @homepage.set_notes_author author_name
                      if note_search[:string].to_s.empty?
                        @homepage.click_adv_search_button
                      else
                        @homepage.enter_adv_search_and_hit_enter note_search[:string]
                      end
                      author_results_count = @search_results_page.note_results_count

                      if author_results_count < 20
                        author_match = @search_results_page.note_in_search_result?(note_search[:note])
                        it "returns a result when searching with the last #{word_count} words in note ID #{note_search[:note].id} and author name #{author_name}" do
                          expect(author_match).to be true
                        end
                      else
                        logger.warn "Skipping a search string + name test with note ID #{note_search[:note].id} because there are more than 20 results"
                      end

                      other_author = loop do
                        a = all_advising_note_authors.sample
                        break a unless a[:uid] == note_search[:note].advisor.uid
                      end
                      other_author_name = "#{other_author[:first_name]} #{other_author[:last_name]}"

                      @search_results_page.click_edit_search
                      @homepage.set_notes_author other_author_name
                      @homepage.click_adv_search_button
                      other_author_results_count = @search_results_page.note_results_count

                      if other_author_results_count < 20
                        other_author_match = @search_results_page.note_in_search_result?(note_search[:note])
                        it "returns no result when searching with the last #{word_count} words in note ID #{note_search[:note].id} and non-matching author name #{other_author_name}" do
                          expect(other_author_match).to be false
                        end
                      else
                        logger.warn "Skipping a search string + name test with note ID #{note_search[:note].id} because there are more than 20 results"
                      end

                    else
                      logger.warn "Bummer, note ID #{note_search[:note].id} has no identifiable author name"
                    end
                  end
                end
              end

              # Student

              @search_results_page.reopen_and_reset_adv_search
              @homepage.set_notes_student search[:student]
              if note_search[:string].to_s.empty?
                @homepage.click_adv_search_button
              else
                @homepage.enter_adv_search_and_hit_enter note_search[:string]
              end
              student_results_count = @search_results_page.note_results_count
              if student_results_count < 20
                student_match = @search_results_page.note_in_search_result?(note_search[:note])
                it("returns a result when searching with the last #{word_count} words in note ID #{note_search[:note].id} and student #{search[:student].sis_id}") do
                  expect(student_match).to be true
                end
              else
                logger.warn "Skipping a search string + student name test with note ID #{note_search[:note].id} because there are more than 20 results"
              end

              # Date last updated

              note_date = Date.parse(note_search[:note].updated_date.to_s)
              logger.info "Checking date filters for a note last updated on #{note_date}"

              @homepage.reopen_and_reset_adv_search
              @homepage.set_notes_date_range(note_date, note_date + 1)
              if note_search[:string].to_s.empty?
                @homepage.click_adv_search_button
              else
                @homepage.enter_adv_search_and_hit_enter note_search[:string]
              end
              range_start_results_count = @search_results_page.note_results_count

              if range_start_results_count < 20
                range_start_match = @search_results_page.note_in_search_result?(note_search[:note])
                it "returns a result when searching the last #{word_count} words in note ID #{note_search[:note].id} in a range starting with last updated date" do
                  expect(range_start_match).to be true
                end
              else
                logger.warn "Skipping a search string + date range test with note ID #{note_search[:note].id} because there are more than 20 results"
              end

              @search_results_page.click_edit_search
              @homepage.set_notes_date_range(note_date - 1, note_date)
              @homepage.click_adv_search_button
              range_end_results_count = @search_results_page.note_results_count

              if range_end_results_count < 20
                range_end_match = @search_results_page.note_in_search_result?(note_search[:note])
                it "returns a result when searching the last #{word_count} words in note ID #{note_search[:note].id} in a range ending with last updated date" do
                  expect(range_end_match).to be true
                end
              else
                logger.warn "Skipping a search string + date range test with note ID #{note_search[:note].id} because there are more than 20 results"
              end

              @search_results_page.click_edit_search
              @homepage.set_notes_date_range(note_date - 30, note_date - 1)
              @homepage.click_adv_search_button
              range_before_results_count = @search_results_page.note_results_count

              if range_before_results_count < 20
                range_before_match = @search_results_page.note_in_search_result?(note_search[:note])
                it "returns no result when searching the last #{word_count} words in note ID #{note_search[:note].id} in a range before last updated date" do
                  expect(range_before_match).to be false
                end
              else
                logger.warn "Skipping a search string + date range test with note ID #{note_search[:note].id} because there are more than 20 results"
              end

              @homepage.reopen_and_reset_adv_search
              @homepage.set_notes_date_range(note_date + 1, note_date + 30)
              @homepage.click_adv_search_button
              range_after_results_count = @search_results_page.note_results_count

              if range_after_results_count < 20
                range_after_match = @search_results_page.note_in_search_result?(note_search[:note])
                it "returns no result when searching the last #{word_count} words in note ID #{note_search[:note].id} in a range after last updated date" do
                  expect(range_after_match).to be false
                end
              else
                logger.warn "Skipping a search string + date range test with note ID #{note_search[:note].id} because there are more than 20 results"
              end
            end

          rescue => e
            Utils.log_error e
            Utils.save_screenshot(@driver, "#{Time.now.to_i.to_s}")
            it("hit an error executing a note search test for #{note_search[:test_case]}") { fail e.message }
          end
        end
      end

    rescue => e
      Utils.log_error e
      it('test hit an error initializing') { fail e.message }
    ensure
      Utils.quit_browser @driver
    end
  end
end
