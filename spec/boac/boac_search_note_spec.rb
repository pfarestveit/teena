require_relative '../../util/spec_helper'

describe 'BOAC' do

  include Logging

  begin

    test_config = BOACTestConfig.new
    test_config.search_notes
    max_note_count_per_src = BOACUtils.notes_max_notes - 1
    search_word_count = BOACUtils.search_word_count

    @driver = Utils.launch_browser test_config.chrome_profile
    @homepage = BOACHomePage.new @driver
    @search_results_page = BOACSearchResultsPage.new @driver
    @homepage.dev_auth test_config.advisor

    # COLLECT DATA TO DRIVE SEARCH TESTS

    student_searches = []
    all_advising_note_authors = NessieUtils.get_all_advising_note_authors

    test_config.test_students.each do |student|

      begin
        note_searches = []
        expected_asc_notes = NessieUtils.get_asc_notes student
        expected_boa_notes = BOACUtils.get_student_notes(student).delete_if &:deleted_date
        expected_ei_notes = NessieUtils.get_e_and_i_notes student
        expected_sis_notes = NessieUtils.get_sis_notes student
        logger.warn "UID #{student.uid} has #{expected_sis_notes.length} SIS notes, #{expected_asc_notes.length} ASC notes,
                              #{expected_ei_notes.length} E&I notes, and #{expected_boa_notes.length} BOA notes"

        expected_boa_notes.delete_if { |note| !note.subject.nil? && (note.subject.include? 'QA Test') }

        # Test a representative subset of the total notes
        test_notes = expected_sis_notes.shuffle[0..max_note_count_per_src] + expected_ei_notes.shuffle[0..max_note_count_per_src] +
            expected_boa_notes.shuffle[0..max_note_count_per_src] + expected_asc_notes.shuffle[0..max_note_count_per_src]

        if test_notes.any?
          test_notes.each do |note|
            begin
              if (query = BOACUtils.generate_note_search_query(student, note, skip_empty_body: true))
                note_searches << query
              end
            rescue => e
              Utils.log_error e
              it("hit an error collecting note search tests for UID #{student.uid} note ID #{note.id}") { fail }
            end
          end
        else
          logger.warn "Bummer, UID #{student.uid} has no notes to search for"
        end

        student_searches << {student: student, note_searches: note_searches}

      rescue => e
        Utils.log_error e
        it("hit an error collecting test searches for UID #{student.uid}") { fail }
      end
    end

    # EXECUTE SEARCHES

    @homepage.load_page

    student_searches.each do |search|

      logger.info "Beginning note search tests for UID #{search[:student].uid}"

      search[:note_searches][0..(BOACUtils.search_max_searches - 1)].each do |note_search|

        logger.info "Beginning note search tests for note ID #{note_search[:note].id}"

        begin
          if note_search[:note].source_body_empty || !note_search[:note].body || note_search[:note].body.empty?
            logger.warn "Skipping search test for #{note_search[:test_case]} because the source note body was empty and too many results will be returned."

          else

            # Search string

            @homepage.set_notes_date_range(nil, nil)
            @homepage.type_note_appt_string_and_enter note_search[:string]

            string_results_count = @search_results_page.note_results_count
            it("returns results when searching with the first #{search_word_count} words in #{note_search[:test_case]}") { expect(string_results_count).to be > 0 }

            it("shows no more than 20 results when searching with the first #{search_word_count} words in #{note_search[:test_case]}") { expect(string_results_count).to be <= 20 }

            if string_results_count > 0 && string_results_count < 20
              @search_results_page.wait_for_note_search_result_rows
              student_result_returned = @search_results_page.note_in_search_result?(note_search[:note])
              it("returns a result when searching with the first #{search_word_count} words in #{note_search[:test_case]}") { expect(student_result_returned).to be true }

              if student_result_returned
                result = @search_results_page.note_result(search[:student], note_search[:note])
                updated_date_expected = note_search[:note].updated_date && note_search[:note].updated_date != note_search[:note].created_date && note_search[:note].advisor.uid != 'UCBCONVERSION'
                expected_date = updated_date_expected ? note_search[:note].updated_date : note_search[:note].created_date
                expected_date_text = "#{expected_date.strftime('%b %-d, %Y')}"
                it("note search shows the student name for #{note_search[:test_case]}") { expect(result[:student_name]).to eql(search[:student].full_name) }
                it("note search shows the student SID for #{note_search[:test_case]}") { expect(result[:student_sid]).to eql(search[:student].sis_id) }
                it("note search shows a snippet of #{note_search[:test_case]}") { expect(result[:snippet].gsub(/\W/, '')).to include(note_search[:string].gsub(/\W/, '')) }
                # TODO it("note search shows the advisor name on #{note_search[:test_case]}") { expect(result[:advisor_name]).not_to be_nil } unless note.advisor_uid == 'UCBCONVERSION'
                it("note search shows the most recent updated date on #{note_search[:test_case]}") { expect(result[:date]).to eql(expected_date_text) }
              end
            else
              logger.warn "Skipping a search string test with note ID #{note_search[:note].id} because there are more than 20 results"
            end

            # Topics

            @homepage.expand_search_options_notes_subpanel

            all_topics = Topic::TOPICS.select(&:for_notes).map &:name
            note_topics = all_topics.select { |topic_name| note_search[:note].topics.include? topic_name.upcase }
            non_note_topics = all_topics - note_topics

            note_topics.each do |note_topic|
              topic = Topic::TOPICS.find { |t| t.name == note_topic }
              @homepage.select_note_topic topic
              @homepage.type_note_appt_string_and_enter note_search[:string]
              topic_results_count = @search_results_page.note_results_count

              if topic_results_count < 20
                topic_match = @search_results_page.note_in_search_result?(note_search[:note])
                it("returns a result when searching with the first #{search_word_count} words in note ID #{note_search[:note].id} and matching topic #{topic.name}") do
                  expect(topic_match).to be true
                end

                non_topic = Topic::TOPICS.find { |t| t.name == non_note_topics.first }
                @homepage.select_note_topic non_topic
                @homepage.type_note_appt_string_and_enter note_search[:string]
                topic_no_match = @search_results_page.note_in_search_result?(note_search[:note])
                it "returns no result when searching with the first #{search_word_count} words in note ID #{note_search[:note].id} and non-matching topic #{topic.name}" do
                  expect(topic_no_match).to be false
                end
              else
                logger.warn "Skipping a search string + topic test with note ID #{note_search[:note].id} because there are more than 20 results"
              end
            end

            # Posted by

            logger.info "Checking filters for #{note_search[:test_case]} posted by UID #{note_search[:note].advisor.uid}"
            @homepage.reset_search_options_notes_subpanel

            if note_search[:note].advisor.uid == test_config.advisor.uid
              logger.info 'Searching for a note posted by the logged in advisor'

              # Posted by you
              @homepage.reset_search_options_notes_subpanel
              @homepage.select_notes_posted_by_you
              @homepage.type_note_appt_string_and_enter note_search[:string]
              you_posted_results_count = @search_results_page.note_results_count

              if you_posted_results_count < 20
                you_posted_match = @search_results_page.note_in_search_result?(note_search[:note])
                it "returns a result when searching with the first #{search_word_count} words in #{note_search[:test_case]} and posted by #{test_config.advisor.uid}" do
                  expect(you_posted_match).to be true
                end
              else
                logger.warn "Skipping a search string + posted-by-you test with note ID #{note_search[:note].id} because there are more than 20 results"
              end

              # Posted by anyone
              @homepage.select_notes_posted_by_anyone
              @homepage.click_search_button
              anyone_posted_results_count = @search_results_page.note_results_count

              if anyone_posted_results_count < 20
                anyone_posted_match = @search_results_page.note_in_search_result?(note_search[:note])
                it "returns a result when searching with the first #{search_word_count} words in #{note_search[:test_case]} and posted by anyone" do
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
                @homepage.select_notes_posted_by_you
                @homepage.type_note_appt_string_and_enter note_search[:string]
                you_posted_results_count = @search_results_page.note_results_count

                if you_posted_results_count < 20
                  you_posted_match = @search_results_page.note_in_search_result?(note_search[:note])
                  it "returns no result when searching with the first #{search_word_count} words in #{note_search[:test_case]} and posted by #{test_config.advisor.uid}" do
                    expect(you_posted_match).to be_falsey
                  end
                else
                  logger.warn "Skipping a search string + posted-by-you test with note ID #{note_search[:note].id} because there are more than 20 results"
                end

                # Posted by anyone
                @homepage.select_notes_posted_by_anyone
                @homepage.click_search_button
                anyone_posted_results_count = @search_results_page.note_results_count

                if anyone_posted_results_count < 20
                  anyone_posted_match = @search_results_page.note_in_search_result?(note_search[:note])
                  it "returns a result when searching with the first #{search_word_count} words in #{note_search[:test_case]} and posted by anyone" do
                    expect(anyone_posted_match).to be true
                  end
                else
                  logger.warn "Skipping a search string + posted-by-anyone test with note ID #{note_search[:note].id} because there are more than 20 results"
                end

                # Posted by advisor name

                if (author = NessieUtils.get_advising_note_author(note_search[:note].advisor.uid))

                  author_name = "#{author[:first_name]} #{author[:last_name]}"
                  @homepage.reset_search_options_notes_subpanel
                  @homepage.set_notes_author author_name
                  @homepage.type_note_appt_string_and_enter note_search[:string]
                  author_results_count = @search_results_page.note_results_count

                  if author_results_count < 20
                    author_match = @search_results_page.note_in_search_result?(note_search[:note])
                    it("returns a result when searching with the first #{search_word_count} words in note ID #{note_search[:note].id} and author name #{author_name}") do
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
                  @homepage.set_notes_author other_author_name
                  @homepage.click_search_button
                  other_author_results_count = @search_results_page.note_results_count

                  if other_author_results_count < 20
                    other_author_match = @search_results_page.note_in_search_result?(note_search[:note])
                    it("returns no result when searching with the first #{search_word_count} words in note ID #{note_search[:note].id} and non-matching author name #{other_author_name}") do
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

            # Date last updated

            note_date = Date.parse(note_search[:note].updated_date.to_s)
            logger.info "Checking date filters for a note last updated on #{note_date}"

            @homepage.reset_search_options_notes_subpanel
            @homepage.set_notes_date_range(note_date, note_date + 1)
            @homepage.type_note_appt_string_and_enter note_search[:string]
            range_start_results_count = @search_results_page.note_results_count

            if range_start_results_count < 20
              range_start_match = @search_results_page.note_in_search_result?(note_search[:note])
              it "returns a result when searching the first #{search_word_count} words in note ID #{note_search[:note].id} in a range starting with last updated date" do
                expect(range_start_match).to be true
              end
            else
              logger.warn "Skipping a search string + date range test with note ID #{note_search[:note].id} because there are more than 20 results"
            end

            @homepage.set_notes_date_range(note_date - 1, note_date)
            @homepage.click_search_button
            range_end_results_count = @search_results_page.note_results_count

            if range_end_results_count < 20
              range_end_match = @search_results_page.note_in_search_result?(note_search[:note])
              it "returns a result when searching the first #{search_word_count} words in note ID #{note_search[:note].id} in a range ending with last updated date" do
                expect(range_end_match).to be true
              end
            else
              logger.warn "Skipping a search string + date range test with note ID #{note_search[:note].id} because there are more than 20 results"
            end

            @homepage.set_notes_date_range(note_date - 30, note_date - 1)
            @homepage.click_search_button
            range_before_results_count = @search_results_page.note_results_count

            if range_before_results_count < 20
              range_before_match = @search_results_page.note_in_search_result?(note_search[:note])
              it "returns no result when searching the first #{search_word_count} words in note ID #{note_search[:note].id} in a range before last updated date" do
                expect(range_before_match).to be false
              end
            else
              logger.warn "Skipping a search string + date range test with note ID #{note_search[:note].id} because there are more than 20 results"
            end

            @homepage.set_notes_date_range(note_date + 1, note_date + 30)
            @homepage.click_search_button
            range_after_results_count = @search_results_page.note_results_count

            if range_after_results_count < 20
              range_after_match = @search_results_page.note_in_search_result?(note_search[:note])
              it "returns no result when searching the first #{search_word_count} words in note ID #{note_search[:note].id} in a range after last updated date" do
                expect(range_after_match).to be false
              end
            else
              logger.warn "Skipping a search string + date range test with note ID #{note_search[:note].id} because there are more than 20 results"
            end
          end

        rescue => e
          Utils.log_error e
          it("hit an error executing a note search test for #{note_search[:test_case]}") { fail }
        end
      end
    end

  rescue => e
    Utils.log_error e
    it('test hit an error initializing') { fail }
  ensure
    Utils.quit_browser @driver
  end
end
