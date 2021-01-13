require_relative '../../util/spec_helper'

if (ENV['NO_DEPS'] || ENV['NO_DEPS'].nil?) && !ENV['DEPS']

  describe 'A restricted BOA user' do

    include Logging

    before(:all) do
      @test = BOACTestConfig.new
      @test.user_role_notes_only
      @test_student = @test.test_students.sample

      @driver = Utils.launch_browser @test.chrome_profile

      @homepage = BOACHomePage.new @driver
      @class_page = BOACClassListViewPage.new @driver
      @flight_data_recorder = BOACFlightDataRecorderPage.new @driver
      @flight_deck_page = BOACFlightDeckPage.new @driver
      @group_page = BOACGroupPage.new @driver
      @pax_manifest_page = BOACPaxManifestPage.new @driver
      @search_results_page = BOACSearchResultsPage.new @driver
      @settings_page = BOACFlightDeckPage.new @driver
      @student_page = BOACStudentPage.new @driver

      @api_admin_page = BOACApiAdminPage.new @driver
      @api_notes_page = BOACApiNotesPage.new @driver
      @api_section_page = BOACApiSectionPage.new @driver
      @api_student_page = BOACApiStudentPage.new @driver
    end

    after(:all) { Utils.quit_browser @driver }

    describe 'with no-Canvas-data BOA access' do

      before(:all) do
        @test.set_advisor { |advisor| !advisor.can_access_canvas_data && advisor.can_access_advising_data && advisor.depts.length == 1 }
        @cohort_page = BOACFilteredCohortPage.new(@driver, @test.advisor)
        @homepage.dev_auth @test.advisor
      end

      after(:all) { @homepage.log_out }

      context 'visiting a student page' do

        before(:all) do
          @api_student_page.get_data(@driver, @test_student)
          @student_page.load_page @test_student
        end

        it('sees a New Note button') { expect(@student_page.new_note_button_element).to be_visible }
        it('sees a Notes tab') { expect(@student_page.notes_button_element).to be_visible }
        it('sees an Appointments tab') { expect(@student_page.appts_button_element).to be_visible }

        it 'sees notes' do
          @student_page.show_notes
          expect(@student_page.note_msg_row_elements.any?).to be true
        end

        it 'cannot expand courses' do
          @api_student_page.terms.each do |term|
            term['enrollments'].each do |course|
              term_name = @api_student_page.term_name term
              @student_page.expand_academic_year term_name unless @student_page.term_data_heading(term_name).visible?
              course['sections'].each do |section|
                expect(@student_page.course_expand_toggle(term['termId'], section['ccn'])).not_to be_visible
              end
            end
          end
        end

        it 'sees no links to course pages' do
          @api_student_page.terms.each do |term|
            term['enrollments'].each do |course|
              term_name = @api_student_page.term_name term
              @student_page.expand_academic_year term_name unless @student_page.term_data_heading(term_name).visible?
              course['sections'].each do |section|
                expect(@student_page.class_page_link(term['termId'], section['ccn'])).not_to be_visible
              end
            end
          end
        end

        it 'cannot see bCourses data in the API response' do
          @api_student_page.get_data(@driver, @test_student)
          @api_student_page.terms.each do |term|
            term['enrollments'].each do |course|
              expect(course['canvasSites']).to be_empty
            end
          end
        end
      end

      context 'visiting a class page' do

        it 'sees an infinite spinner' do
          @class_page.hit_class_page_url('2178', '13826')
          expected_error = 'Failed to load resource: the server responded with a status of 403 ()'
          @class_page.wait_until(Utils.short_wait) { Utils.console_error_present?(@driver, expected_error) }
        end

        it 'is forbidden' do
          @api_section_page.get_data(@driver, '2178', '13826')
          expect(@api_section_page).to be_unauthorized
        end
      end

      context 'visiting a cohort page' do
        before(:all) do
          @cohort_page = BOACFilteredCohortPage.new(@driver, @test.advisor)

          @homepage.load_page
          @homepage.click_sidebar_create_filtered
          @opts = @cohort_page.filter_options
        end

        it('sees a College filter') { expect(@opts).to include('College') }
        it('sees an Entering Term filter') { expect(@opts).to include('Entering Term') }
        it('sees an Expected Graduation Term filter') { expect(@opts).to include('Expected Graduation Term') }
        it('sees a GPA (Cumulative) filter') { expect(@opts).to include('GPA (Cumulative)') }
        it('sees a GPA (Last Term) filter') { expect(@opts).to include('GPA (Last Term)') }
        it('sees a Level filter') { expect(@opts).to include('Level') }
        it('sees a Major filter') { expect(@opts).to include('Major') }
        it('sees a Midpoint Deficient Grade filter') { expect(@opts).to include('Midpoint Deficient Grade') }
        it('sees a Transfer Student filter') { expect(@opts).to include 'Transfer Student' }
        it('sees a Units Completed filter') { expect(@opts).to include 'Units Completed' }

        it('sees an Ethnicity filter') { expect(@opts).to include('Ethnicity') }
        it('sees a Gender filter') { expect(@opts).to include('Gender') }
        it('sees an Underrepresented Minority filter') { expect(@opts).to include('Underrepresented Minority') }
        it('sees a Visa Type filter') { expect(@opts).to include('Visa Type') }

        it('sees no Inactive (ASC) filter') { expect(@opts).not_to include('Inactive (ASC)') }
        it('sees no Intensive (ASC) filter') { expect(@opts).not_to include('Intensive (ASC)') }
        it('sees no Team (ASC) filter') { expect(@opts).not_to include('Team (ASC)') }

        it('sees no Advisor (COE) filter') { expect(@opts).not_to include('Advisor (COE)') }
        it('sees no Ethnicity (COE) filter') { expect(@opts).not_to include('Ethnicity (COE)') }
        it('sees no Gender (COE) filter') { expect(@opts).not_to include('Gender (COE)') }
        it('sees no Grading Basis EPN (COE) filter') { expect(@opts).not_to include('Grading Basis EPN (COE)') }
        it('sees no Inactive (COE) filter') { expect(@opts).not_to include('Inactive (COE)') }
        it('sees a Last Name filter') { expect(@opts).to include('Last Name') }
        it('sees a My Curated Groups filter') { expect(@opts).to include('My Curated Groups') }
        it('sees a My Students filter') { expect(@opts).to include('My Students') }
        it('sees no PREP (COE) filter') { expect(@opts).not_to include('PREP (COE)') }
        it('sees no Probation (COE) filter') { expect(@opts).not_to include('Probation (COE)') }
        it('sees no Underrepresented Minority (COE) filter') { expect(@opts).not_to include('Underrepresented Minority (COE)') }

        context 'with results' do

          before(:all) do
            @homepage.load_page
            @homepage.click_sidebar_create_filtered
            @cohort_search = CohortFilter.new
            @cohort_search.set_custom_filters({major: ['Art BA']})
            @cohort = FilteredCohort.new({search_criteria: @cohort_search})

            @cohort_page.perform_student_search @cohort
            @cohort_page.wait_until(Utils.short_wait) { @cohort_page.results_count > 0 }
          end

          it('sees no bCourses data') { expect(@cohort_page.site_activity_header_elements).to be_empty }
        end
      end

      context 'visiting a group page' do

        before(:all) do
          @group_no_canvas = CuratedGroup.new(name: "Group #{@test.id}")
          @homepage.click_sidebar_create_curated_group
          @group_page.create_group_with_bulk_sids(@test.test_students, @group_no_canvas)
        end

        it('sees no bCourses data') { expect(@group_page.site_activity_header_elements).to be_empty }
      end

      context 'visiting the sidebar' do

        it('sees no admitted students link') { expect(@homepage.all_admits_link?).to be false }
        it('sees no link to create a CE3 cohort') { expect(@homepage.create_ce3_filtered_link?).to be false }
        it('sees a batch note button') { expect(@homepage.batch_note_button_element).to be_visible }
      end

      context 'performing a search' do

        before(:all) do
          @homepage.load_page
          @homepage.expand_search_options
        end

        it('sees a students search option') { expect(@homepage.include_students_cbx_element).to be_visible }
        it('sees no admits search option') { expect(@homepage.include_admits_cbx_element).not_to be_visible }
        it('sees no courses search option') { expect(@homepage.include_classes_cbx_element).not_to be_visible }
        it('sees a notes/appointments search option') { expect(@homepage.include_notes_cbx_element).to be_visible }

        context 'with results' do

          before(:all) do
            @homepage.type_non_note_string_and_enter 'Math'
          end

          it('sees student results') { expect(@search_results_page.student_search_results_count).to be_nonzero }
          it('sees no course results') { expect(@search_results_page.class_results_count_element).not_to be_visible }
          it('sees note results') { expect(@search_results_page.note_results_count).to be_nonzero }
        end
      end

      context 'looking for admin functions' do
        before(:all) do
          @homepage.load_page
          @homepage.click_header_dropdown
        end

        it('can see a Settings link') { expect(@homepage.settings_link?).to be true }
        it('cannot see a Flight Deck link') { expect(@homepage.flight_deck_link?).to be false }
        it('cannot see a Flight Data Recorder link') { expect(@homepage.flight_data_recorder_link?).to be false }
        it('cannot see a Passenger Manifest link') { expect(@homepage.pax_manifest_link?).to be false }

        it 'cannot post status alerts' do
          @homepage.wait_for_update_and_click @homepage.settings_link_element
          expect(@settings_page.status_heading?).to be false
        end

        it 'cannot reach the Passenger Manifest' do
          @pax_manifest_page.hit_page_url
          @pax_manifest_page.wait_for_title 'Page not found'
        end

        it 'cannot hit the cachejob page' do
          @api_admin_page.load_cachejob
          @api_admin_page.unauth_msg_element.when_visible Utils.medium_wait
        end
      end
    end

    describe 'with no-Canvas-data, no-notes, and no-appointments BOA access' do

      before(:all) do
        @test.set_advisor do |advisor|
          advisor.depts.include?(BOACDepartments::OTHER.code) &&
              advisor.depts.length == 1 &&
              !advisor.can_access_canvas_data &&
              !advisor.can_access_advising_data
        end
        @cohort_page = BOACFilteredCohortPage.new(@driver, @test.advisor)
        @homepage.dev_auth @test.advisor
      end

      after(:all) { @homepage.log_out }

      context 'visiting a student page' do

        before(:all) do
          @api_student_page.get_data(@driver, @test_student)
          @student_page.load_page @test_student
        end

        it('sees no New Note button') { expect(@student_page.new_note_button?).to be false }
        it('sees no Notes tab') { expect(@student_page.notes_button?).to be false }
        it('sees no Appointments tab') { expect(@student_page.appts_button?).to be false }
        it('cannot see notes data in the API response') { expect(@api_student_page.notes).to be_nil }
        it('cannot see appointments data in the API response') { expect(@api_student_page.appointments).to be_nil }

        it 'cannot expand courses' do
          @api_student_page.terms.each do |term|
            term['enrollments'].each do |course|
              term_name = @api_student_page.term_name term
              @student_page.expand_academic_year term_name unless @student_page.term_data_heading(term_name).visible?
              course['sections'].each do |section|
                expect(@student_page.course_expand_toggle(term['termId'], section['ccn'])).not_to be_visible
              end
            end
          end
        end

        it 'sees no links to course pages' do
          @api_student_page.terms.each do |term|
            term['enrollments'].each do |course|
              term_name = @api_student_page.term_name term
              @student_page.expand_academic_year term_name unless @student_page.term_data_heading(term_name).visible?
              course['sections'].each do |section|
                expect(@student_page.class_page_link(term['termId'], section['ccn'])).not_to be_visible
              end
            end
          end
        end

        it 'cannot see bCourses data in the API response' do
          @api_student_page.get_data(@driver, @test_student)
          @api_student_page.terms.each do |term|
            term['enrollments'].each do |course|
              expect(course['canvasSites']).to be_empty
            end
          end
        end
      end

      it 'cannot download a note attachment' do
        Utils.prepare_download_dir
        attachment = BOACUtils.get_note_attachments.sample
        @api_notes_page.load_attachment_page attachment.id
        @api_notes_page.unauth_msg_element.when_visible Utils.short_wait
        expect(Utils.downloads_empty?).to be true
      end

      context 'visiting a class page' do

        it 'sees an infinite spinner' do
          @class_page.hit_class_page_url('2178', '13826')
          expected_error = 'Failed to load resource: the server responded with a status of 403 ()'
          @class_page.wait_until(Utils.short_wait) { Utils.console_error_present?(@driver, expected_error) }
        end

        it 'is forbidden' do
          @api_section_page.get_data(@driver, '2178', '13826')
          expect(@api_section_page).to be_unauthorized
        end
      end

      context 'visiting a cohort page' do
        before(:all) do
          @cohort_page = BOACFilteredCohortPage.new(@driver, @test.advisor)

          @homepage.load_page
          @homepage.click_sidebar_create_filtered
          @opts = @cohort_page.filter_options
        end

        it('sees a College filter') { expect(@opts).to include('College') }
        it('sees an Entering Term filter') { expect(@opts).to include('Entering Term') }
        it('sees an Expected Graduation Term filter') { expect(@opts).to include('Expected Graduation Term') }
        it('sees a GPA (Cumulative) filter') { expect(@opts).to include('GPA (Cumulative)') }
        it('sees a GPA (Last Term) filter') { expect(@opts).to include('GPA (Last Term)') }
        it('sees a Level filter') { expect(@opts).to include('Level') }
        it('sees a Major filter') { expect(@opts).to include('Major') }
        it('sees a Midpoint Deficient Grade filter') { expect(@opts).to include('Midpoint Deficient Grade') }
        it('sees a Transfer Student filter') { expect(@opts).to include 'Transfer Student' }
        it('sees a Units Completed filter') { expect(@opts).to include 'Units Completed' }

        it('sees an Ethnicity filter') { expect(@opts).to include('Ethnicity') }
        it('sees a Gender filter') { expect(@opts).to include('Gender') }
        it('sees an Underrepresented Minority filter') { expect(@opts).to include('Underrepresented Minority') }
        it('sees a Visa Type filter') { expect(@opts).to include('Visa Type') }

        it('sees no Inactive (ASC) filter') { expect(@opts).not_to include('Inactive (ASC)') }
        it('sees no Intensive (ASC) filter') { expect(@opts).not_to include('Intensive (ASC)') }
        it('sees no Team (ASC) filter') { expect(@opts).not_to include('Team (ASC)') }

        it('sees no Advisor (COE) filter') { expect(@opts).not_to include('Advisor (COE)') }
        it('sees no Ethnicity (COE) filter') { expect(@opts).not_to include('Ethnicity (COE)') }
        it('sees no Gender (COE) filter') { expect(@opts).not_to include('Gender (COE)') }
        it('sees no Grading Basis EPN (COE) filter') { expect(@opts).not_to include('Grading Basis EPN (COE)') }
        it('sees no Inactive (COE) filter') { expect(@opts).not_to include('Inactive (COE)') }
        it('sees a Last Name filter') { expect(@opts).to include('Last Name') }
        it('sees a My Curated Groups filter') { expect(@opts).to include('My Curated Groups') }
        it('sees a My Students filter') { expect(@opts).to include('My Students') }
        it('sees no PREP (COE) filter') { expect(@opts).not_to include('PREP (COE)') }
        it('sees no Probation (COE) filter') { expect(@opts).not_to include('Probation (COE)') }
        it('sees no Underrepresented Minority (COE) filter') { expect(@opts).not_to include('Underrepresented Minority (COE)') }

        context 'with results' do

          before(:all) do
            @homepage.load_page
            @homepage.click_sidebar_create_filtered
            @cohort_search = CohortFilter.new
            @cohort_search.set_custom_filters({major: ['Art BA']})
            @cohort = FilteredCohort.new({search_criteria: @cohort_search})

            @cohort_page.perform_student_search @cohort
            @cohort_page.wait_until(Utils.short_wait) { @cohort_page.results_count > 0 }
          end

          it('sees no bCourses data') { expect(@cohort_page.site_activity_header_elements).to be_empty }
        end
      end

      context 'visiting a group page' do

        before(:all) do
          @group_no_canvas = CuratedGroup.new(name: "Group #{@test.id}")
          @homepage.click_sidebar_create_curated_group
          @group_page.create_group_with_bulk_sids(@test.test_students, @group_no_canvas)
        end

        it('sees no bCourses data') { expect(@group_page.site_activity_header_elements).to be_empty }
      end

      context 'visiting the sidebar' do

        it('sees no admitted students link') { expect(@homepage.all_admits_link?).to be false }
        it('sees no link to create a CE3 cohort') { expect(@homepage.create_ce3_filtered_link?).to be false }
        it('sees no batch note button') { expect(@homepage.batch_note_button_element).not_to be_visible }
      end

      context 'performing a search' do

        before(:all) do
          @homepage.load_page
          @homepage.expand_search_options
        end

        it('sees a students search option') { expect(@homepage.include_students_cbx_element).to be_visible }
        it('sees no admits search option') { expect(@homepage.include_admits_cbx_element).not_to be_visible }
        it('sees no courses search option') { expect(@homepage.include_classes_cbx_element).not_to be_visible }
        it('sees no notes/appointments search option') { expect(@homepage.include_notes_cbx_element).not_to be_visible }

        context 'with results' do

          before(:all) do
            @homepage.type_non_note_string_and_enter 'Math'
          end

          it('sees student results') { expect(@search_results_page.student_search_results_count).to be_nonzero }
          it('sees no course results') { expect(@search_results_page.class_results_count?).to be false }
          it('sees no note results') { expect(@search_results_page.note_results_count_heading?).to be false }
        end
      end

      context 'looking for admin functions' do
        before(:all) do
          @homepage.load_page
          @homepage.click_header_dropdown
        end

        it('can see a Settings link') { expect(@homepage.settings_link?).to be true }
        it('cannot see a Flight Deck link') { expect(@homepage.flight_deck_link?).to be false }
        it('cannot see a Flight Data Recorder link') { expect(@homepage.flight_data_recorder_link?).to be false }
        it('cannot see a Passenger Manifest link') { expect(@homepage.pax_manifest_link?).to be false }

        it 'cannot post status alerts' do
          @homepage.wait_for_update_and_click @homepage.settings_link_element
          expect(@settings_page.status_heading?).to be false
        end

        it('cannot toggle drop-in advising') do
          dept = BOACDepartments::DEPARTMENTS.find { |d| d.code == @test.advisor.depts.first }
          expect(@settings_page.drop_in_advising_toggle_el(dept).exists?).to be false
        end

        it('cannot manage drop-in schedulers') { expect(@settings_page.add_scheduler_input?).to be false }

        it 'cannot reach the Passenger Manifest' do
          @pax_manifest_page.hit_page_url
          @pax_manifest_page.wait_for_title 'Page not found'
        end

        it 'cannot hit the cachejob page' do
          @api_admin_page.load_cachejob
          @api_admin_page.unauth_msg_element.when_visible Utils.medium_wait
        end
      end
    end
  end
end
