require_relative '../../util/spec_helper'

describe 'A notes-only BOA user' do

  include Logging

  before(:all) do
    @test = BOACTestConfig.new
    @test.user_role_notes_only

    @driver = Utils.launch_browser @test.chrome_profile
    @homepage = BOACHomePage.new @driver
    @homepage.dev_auth @test.advisor
  end

  after(:all) do
    Utils.quit_browser @driver
  end

  context 'visiting a student page' do
    before(:all) do
      @test_student = @test.students.sample
      @api_student_page = BOACApiStudentPage.new(@driver)
      @api_student_page.get_data(@driver, @test_student)

      @student_page = BOACStudentPage.new @driver
      @student_page.load_page @test_student
      @student_page.click_view_previous_semesters if @api_student_page.terms.length > 1
    end

    it 'cannot expand courses' do
      @api_student_page.terms.each do |term|
        term['enrollments'].each do |course|
          course['sections'].each do |section|
            expect(@student_page.course_expand_toggle(term['termId'], section['ccn'])).not_to be_visible
          end
        end
      end
    end

    it 'sees no links to course pages' do
      @api_student_page.terms.each do |term|
        term['enrollments'].each do |course|
          course['sections'].each do |section|
            expect(@student_page.class_page_link(term['termId'], section['ccn'])).not_to be_visible
          end
        end
      end
    end
  end

  context 'visiting a student API page' do
    before(:all) do
      @test_student = @test.students.sample

      @api_student_page = BOACApiStudentPage.new @driver
      @api_student_page.get_data(@driver, @test_student)
    end

    it 'sees no bCourses data' do
      @api_student_page.terms.each do |term|
        term['enrollments'].each do |course|
          expect(course['canvasSites']).to be_empty
        end
      end
    end
  end

  context 'visiting a class page' do
    before(:all) { @api_section_page = BOACApiSectionPage.new @driver }

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
      @cohort_page.click_new_filter_button
      @cohort_page.wait_until(1) { @cohort_page.new_filter_option_elements.any? &:visible? }
    end

    it('sees an Expected Graduation Term filter') { expect(@cohort_page.new_filter_option('expectedGradTerms').visible?).to be true }
    it('sees a GPA filter') { expect(@cohort_page.new_filter_option('gpaRanges').visible?).to be true }
    it('sees a Level filter') { expect(@cohort_page.new_filter_option('levels').visible?).to be true }
    it('sees a Major filter') { expect(@cohort_page.new_filter_option('majors').visible?).to be true }
    it('sees a Transfer Student filter') { expect(@cohort_page.new_filter_option('transfer').visible?).to be true }
    it('sees a Units Completed filter') { expect(@cohort_page.new_filter_option('unitRanges').visible?).to be true }

    it('sees an Ethnicity filter') { expect(@cohort_page.new_filter_option('ethnicities').visible?).to be true }
    it('sees a Gender filter') { expect(@cohort_page.new_filter_option('genders').visible?).to be true }
    it('sees an Underrepresented Minority filter') { expect(@cohort_page.new_filter_option('underrepresented')) }

    it('sees no Inactive (ASC) filter') { expect(@cohort_page.new_filter_option('isInactiveAsc').visible?).to be false }
    it('sees no Intensive filter') { expect(@cohort_page.new_filter_option('inIntensiveCohort').visible?).to be false }
    it('sees no Team filter') { expect(@cohort_page.new_filter_option('groupCodes').visible?).to be false }

    it('sees a Last Name filter') { expect(@cohort_page.new_filter_option('lastNameRanges').visible?).to be true }
    it('sees a My Students filter') { expect(@cohort_page.new_filter_option('cohortOwnerAcademicPlans').visible?).to be true }

    it('sees no Advisor filter') { expect(@cohort_page.new_filter_option('coeAdvisorLdapUids').exists?).to be false }
    it('sees no Ethnicity (COE) filter') { expect(@cohort_page.new_filter_option('coeEthnicities').exists?).to be false }
    it('sees no Gender (COE) filter') { expect(@cohort_page.new_filter_option('coeGenders').exists?).to be false }
    it('sees no Inactive (COE) filter') { expect(@cohort_page.new_filter_option('isInactiveCoe').exists?).to be false }
    it('sees no PREP filter') { expect(@cohort_page.new_filter_option('coePrepStatuses').exists?).to be false }
    it('sees no Probation filter') { expect(@cohort_page.new_filter_option('coeProbation').exists?).to be false }

    context 'with results' do

      before(:all) do
        @homepage.load_page
        @homepage.click_sidebar_create_filtered
        @cohort_search = CohortFilter.new
        @cohort_search.set_custom_filters({:major => ['Art BA']})
        @cohort = FilteredCohort.new({:search_criteria => @cohort_search})

        @cohort_page.perform_search @cohort
        @cohort_page.wait_until(Utils.short_wait) { @cohort_page.results_count > 0 }
      end

      it('sees no bCourses data') do
        expect(@driver.find_elements(:xpath => "//th[text()='BCOURSES ACTIVITY']")).to be_empty
      end
    end
  end

  context 'performing a search' do
    before(:all) { @homepage.load_page }

    it('sees no courses search option') do
      @homepage.expand_search_options
      expect(@homepage.include_students_cbx_element).to be_visible
      expect(@homepage.include_notes_cbx_element).to be_visible
      expect(@homepage.include_classes_cbx_element).not_to be_visible
    end

    context('with results') do
      before(:all) do
        @search_results_page = BOACSearchResultsPage.new @driver
      end

      it('sees no courses') do
        @homepage.search_non_note 'Math'
        expect(@search_results_page.student_search_results_count).to be_nonzero
        expect(@search_results_page.note_results_count).to be_nonzero
        expect(@search_results_page.class_results_count_element).not_to be_visible
      end
    end
  end

  context 'looking for admin functions' do
    before(:all) do
      @settings_page = BOACFlightDeckPage.new @driver
      @api_admin_page = BOACApiAdminPage.new @driver
      @homepage.load_page
      @homepage.click_header_dropdown
    end

    it('can access the settings page') { expect(@homepage.settings_link?).to be true }
    it('cannot access the flight deck page') { expect(@homepage.flight_deck_link?).to be false }
    it('cannot access the passenger manifest page') { expect(@homepage.pax_manifest_link?).to be false }

    it 'can toggle demo mode' do
      @settings_page.load_page
      @settings_page.demo_mode_toggle_element.when_present Utils.short_wait
    end

    it('cannot post status alerts') { expect(@settings_page.status_heading?).to be false }

    it 'cannot hit the cachejob page' do
      @api_admin_page.load_cachejob
      @api_admin_page.unauth_msg_element.when_visible Utils.medium_wait
    end
  end
end