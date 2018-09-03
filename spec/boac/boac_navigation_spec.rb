require_relative '../../util/spec_helper'

describe 'BOAC' do

  include Logging

  begin

    test = BOACTestConfig.new
    test.navigation NessieUtils.get_all_students

    @driver = Utils.launch_browser
    @homepage = Page::BOACPages::HomePage.new @driver
    @cohort_page = Page::BOACPages::CohortPages::FilteredCohortListViewPage.new @driver
    @matrix_page = Page::BOACPages::CohortPages::FilteredCohortMatrixPage.new @driver
    @student_page = Page::BOACPages::StudentPage.new @driver
    @homepage.dev_auth test.advisor
    @cohort_page.search_and_create_new_cohort(test.default_cohort) unless test.default_cohort.id

    # Navigate the various cohort/student views using each of the test search criteria
    test.searches.each do |cohort|

      begin
        search = cohort.search_criteria.list_filters

        # Make sure a list view button is present from the previous loop. If not, load a team cohort to obtain an initial list view.
        @cohort_page.load_cohort test.default_cohort unless @cohort_page.list_view_button?
        @cohort_page.click_list_view
        @cohort_page.show_filters
        @cohort_page.perform_search cohort

        if cohort.member_count.zero?

          rows_visible = @cohort_page.player_link_elements.any?
          it("shows no results on list view cohort search for #{search}") { expect(rows_visible).to be false }

          logger.warn 'No results, skipping further tests'

        else

          # Page through results

          list_results_length = @cohort_page.visible_sids.length
          list_results_page = @cohort_page.list_view_current_page

          logger.info "Got #{list_results_length} list view results"

          it("shows the right list view cohort search results count for #{search}") { expect(cohort.member_count).to eql(list_results_length) }

          # Navigate to student page and back.

          student = BOACUser.new({:sis_id => @cohort_page.list_view_sids.last, :uid => @cohort_page.player_link_elements.last.attribute('id')})
          @cohort_page.click_player_link student
          @driver.navigate.back

          list_search_preserved = @cohort_page.filters_selected? cohort.search_criteria
          list_results_count_preserved = @cohort_page.verify_block { @cohort_page.wait_until { @cohort_page.results_count == cohort.member_count } }
          list_results_page_preserved = @cohort_page.list_view_page_selected? list_results_page
          # TODO - it("preserves cohort search criteria #{search} when returning to list view from the student #{student.sis_id} page") { expect(list_search_preserved).to be true }
          it("preserves the cohort search criteria #{search} results count when returning to list view from the student #{student.sis_id} page") { expect(list_results_count_preserved).to be true }
          it("preserves the cohort search criteria #{search} results page when returning to list view from the student #{student.sis_id} page") { expect(list_results_page_preserved).to be true }

          # Switch to matrix view

          if cohort.member_count > 800

            button_disabled = @cohort_page.matrix_view_button_element.attribute 'disabled'
            it("disables the matrix button for #{search} with result count #{cohort.member_count}") { expect(button_disabled).to eql('true') }

          else

            @cohort_page.click_matrix_view
            @matrix_page.wait_for_matrix
            scatterplot_uids = @matrix_page.visible_matrix_uids @driver
            no_data_uids = @matrix_page.visible_no_data_uids

            logger.info "Got #{scatterplot_uids.length + no_data_uids.length} matrix view UIDs"

            matrix_results_right = (scatterplot_uids.length + no_data_uids.length == cohort.member_count)
            it("preserves the cohort search criteria #{search} results count when switching to matrix view") { expect(matrix_results_right).to be true }

            # Navigate to student page and back. Click a bubble if there are any; otherwise a 'no data' row.

            scatterplot_uids.any? ? @matrix_page.click_last_student_bubble(@driver) : @matrix_page.click_last_no_data_student
            @driver.navigate.back
            @matrix_page.wait_for_matrix
            scatterplot_uids = @matrix_page.visible_matrix_uids @driver
            no_data_uids = @matrix_page.visible_no_data_uids

            matrix_results_count_preserved = (scatterplot_uids.length + no_data_uids.length == cohort.member_count)
            it("preserves the cohort search criteria #{search} results count when returning to matrix view from the student page") { expect(matrix_results_count_preserved).to be true }

            @driver.navigate.back
          end
        end

      rescue => e
        BOACUtils.log_error_and_screenshot(@driver, e, "cohort-#{test.searches.index cohort}")
        it("threw an error with #{search}") { fail }
      end
    end

  rescue => e
    Utils.log_error e
    it('threw an error') { fail }
  ensure
    Utils.quit_browser @driver
  end
end
