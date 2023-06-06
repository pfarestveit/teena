require_relative '../../util/spec_helper'

unless ENV['DEPS']

  describe 'BOAC' do

    include Logging

    begin

      test_config = BOACTestConfig.new
      test_config.search_students

      @driver = Utils.launch_browser test_config.chrome_profile
      @homepage = BOACHomePage.new @driver
      @search_results_page = BOACSearchResultsPage.new @driver
      @homepage.dev_auth test_config.advisor
      @homepage.load_page

      test_config.test_students.each do |student|

        logger.info "Beginning student search tests for UID #{student.uid}"

        begin
          @homepage.enter_simple_search_and_hit_enter student.first_name
          complete_first_results = @search_results_page.student_in_search_result?(@driver, student)
          it("finds UID #{student.uid} with the complete first name") { expect(complete_first_results).to be true }

          unless student.first_name[0..2] == student.first_name
            @homepage.enter_simple_search_and_hit_enter student.first_name[0..2]
            partial_first_results = @search_results_page.student_in_search_result?(@driver, student)
            it("finds UID #{student.uid} with a partial first name") { expect(partial_first_results).to be true }
          end

          @homepage.enter_simple_search_and_hit_enter student.last_name
          complete_last_results = @search_results_page.student_in_search_result?(@driver, student)
          it("finds UID #{student.uid} with the complete last name") { expect(complete_last_results).to be true }

          unless student.last_name[0..2] == student.last_name
            @homepage.enter_simple_search_and_hit_enter student.last_name[0..2]
            partial_last_results = @search_results_page.student_in_search_result?(@driver, student)
            it("finds UID #{student.uid} with a partial last name") { expect(partial_last_results).to be true }
          end

          @homepage.enter_simple_search_and_hit_enter "#{student.first_name} #{student.last_name}"
          complete_first_last_results = @search_results_page.student_in_search_result?(@driver, student)
          it("finds UID #{student.uid} with the complete first and last name") { expect(complete_first_last_results).to be true }

          @homepage.enter_simple_search_and_hit_enter "#{student.last_name}, #{student.first_name}"
          complete_last_first_results = @search_results_page.student_in_search_result?(@driver, student)
          it("finds UID #{student.uid} with the complete last and first name") { expect(complete_last_first_results).to be true }

          @homepage.enter_simple_search_and_hit_enter "#{student.first_name[0..2]} #{student.last_name[0..2]}"
          partial_first_last_results = @search_results_page.student_in_search_result?(@driver, student)
          it("finds UID #{student.uid} with a partial first and last name") { expect(partial_first_last_results).to be true }

          @homepage.enter_simple_search_and_hit_enter "#{student.last_name[0..2]}, #{student.first_name[0..2]}"
          partial_last_first_results = @search_results_page.student_in_search_result?(@driver, student)
          it("finds UID #{student.uid} with a partial last and first name") { expect(partial_last_first_results).to be true }

          @homepage.enter_simple_search_and_hit_enter student.sis_id.to_s
          complete_sid_results = @search_results_page.student_in_search_result?(@driver, student)
          it("finds UID #{student.uid} with the complete SID") { expect(complete_sid_results).to be true }

          @homepage.enter_simple_search_and_hit_enter student.sis_id.to_s[0..4]
          partial_sid_results = @search_results_page.student_in_search_result?(@driver, student)
          it("finds UID #{student.uid} with a partial SID") { expect(partial_sid_results).to be true }

          @homepage.enter_simple_search_and_hit_enter student.email
          complete_email_results = @search_results_page.student_in_search_result?(@driver, student)
          it("finds UID #{student.uid} with the complete email address") { expect(complete_email_results).to be true }

          @homepage.enter_simple_search_and_hit_enter student.email[0..4]
          partial_email_results = @search_results_page.student_in_search_result?(@driver, student)
          it("finds UID #{student.uid} with a partial email address") { expect(partial_email_results).to be true }

          @homepage.clear_simple_search_input
          expected_search_history = [student.email[0..4], student.email, student.sis_id.to_s[0..4], student.sis_id.to_s,
                                     "#{student.last_name[0..2]}, #{student.first_name[0..2]}"]
          visible_search_history = @homepage.visible_search_history
          it("shows the right search history for advisor UID #{test_config.advisor.uid}") { expect(visible_search_history).to eql(expected_search_history) }

          @homepage.select_history_item @homepage.visible_search_history[4]
          history_results = @search_results_page.student_in_search_result?(@driver, student)
          it("allows the advisor to select the fifth tem from search history to execute the search #{expected_search_history[4]}") { expect(history_results).to be true }

        rescue => e
          Utils.log_error e
          it("hit an error performing user searches for UID #{student.uid}") { fail e.message }
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
