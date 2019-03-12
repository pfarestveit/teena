require_relative '../../util/spec_helper'

describe 'An ASC advisor' do

  include Logging

  all_students = NessieUtils.get_all_students

  test_asc = BOACTestConfig.new
  test_asc.user_role_asc all_students

  test_coe = BOACTestConfig.new
  test_coe.user_role_coe all_students

  asc_inactive_students = test_asc.dept_students.reject &:active_asc

  overlap_students = test_asc.dept_students & test_coe.dept_students
  coe_only_students = test_coe.dept_students - overlap_students

  before(:all) do
    @driver = Utils.launch_browser test_asc.chrome_profile
    @admin_page = BOACAdminPage.new @driver
    @api_admin_page = BOACApiAdminPage.new @driver
    @api_section_page = BOACApiSectionPage.new @driver
    @api_user_analytics_page = BOACApiStudentPage.new @driver
    @class_page = BOACClassListViewPage.new @driver
    @filtered_cohort_page = BOACFilteredCohortPage.new @driver
    @homepage = BOACHomePage.new @driver
    @search_page = BOACSearchResultsPage.new @driver
    @student_page = BOACStudentPage.new @driver

    @inactive_student_sids = asc_inactive_students.map &:sis_id

    @homepage.dev_auth test_asc.advisor
  end

  after(:all) { Utils.quit_browser @driver }

  context 'performing a filtered cohort search' do

    before(:all) do
      @homepage.click_sidebar_create_filtered
      @filtered_cohort_page.wait_for_update_and_click @filtered_cohort_page.new_filter_button_element
      @filtered_cohort_page.wait_until(1) { @filtered_cohort_page.new_filter_option_elements.any? &:visible? }
    end

    it('sees a GPA filter') { expect(@filtered_cohort_page.new_filter_option_by_key('gpaRanges').visible?).to be true }
    it('sees a Level filter') { expect(@filtered_cohort_page.new_filter_option_by_key('levels').visible?).to be true }
    it('sees a Major filter') { expect(@filtered_cohort_page.new_filter_option_by_key('majors').visible?).to be true }
    it('sees a Units filter') { expect(@filtered_cohort_page.new_filter_option_by_key('unitRanges').visible?).to be true }
    it('sees a Last Name filter') { expect(@filtered_cohort_page.new_filter_option_by_key('lastNameRange').visible?).to be true }
    it('sees no Advisor filter') { expect(@filtered_cohort_page.new_filter_option_by_key('advisorLdapUids').exists?).to be false }
    it('sees no Ethnicity filter') { expect(@filtered_cohort_page.new_filter_option_by_key('ethnicities').exists?).to be false }
    it('sees no Gender filter') { expect(@filtered_cohort_page.new_filter_option_by_key('genders').exists?).to be false }
    it('sees no PREP filter') { expect(@filtered_cohort_page.new_filter_option_by_key('coePrepStatuses').exists?).to be false }
    it('sees a Inactive filter') { expect(@filtered_cohort_page.new_filter_option_by_key('isInactiveAsc').visible?).to be true }
    it('sees a Intensive filter') { expect(@filtered_cohort_page.new_filter_option_by_key('inIntensiveCohort').visible?).to be true }
    it('sees a Team filter') { expect(@filtered_cohort_page.new_filter_option_by_key('groupCodes').visible?).to be true }
  end

  context 'visiting Everyone\'s Cohorts' do

    it 'sees only filtered cohorts created by ASC advisors' do
      expected_cohort_names = BOACUtils.get_everyone_filtered_cohorts(BOACDepartments::ASC).map(&:id).sort
      visible_cohort_names = (@filtered_cohort_page.visible_everyone_cohorts.map &:id).sort
      @filtered_cohort_page.wait_until(1, "Expected but not present: #{expected_cohort_names - visible_cohort_names}. Present but not expected: #{visible_cohort_names - expected_cohort_names}") do
        visible_cohort_names == expected_cohort_names
      end
    end

    it 'cannot hit a non-ASC filtered cohort URL' do
      coe_everyone_cohorts = BOACUtils.get_everyone_filtered_cohorts BOACDepartments::COE
      coe_everyone_cohorts.any? ?
          @filtered_cohort_page.hit_non_auth_cohort(coe_everyone_cohorts.first) :
          logger.warn('Skipping test for ASC access to CoE cohorts because CoE has no cohorts.')
    end
  end

  context 'performing a user search' do

    it 'sees no non-ASC students in search results' do
      @search_page.search coe_only_students.first.sis_id
      @search_page.no_results_msg.when_visible Utils.short_wait
    end

    it('sees overlapping ASC and CoE active students in search results') do
      student = overlap_students.find &:active_asc
      if student
        @search_page.search student.sis_id
        expect(@search_page.student_search_results_count).to eql(1)
      else
        logger.warn 'Skipping search for overlapping students since none are active'
      end
    end
  end

  context 'visiting a class page' do

    it 'sees only ASC student data in a section endpoint' do
      api_section_page = BOACApiSectionPage.new @driver
      api_section_page.get_data(@driver, '2178', '13826')
      expect(test_asc.dept_students.map(&:sis_id).sort & api_section_page.student_sids).to eql(api_section_page.student_sids.sort)
    end
  end

  context 'visiting a student page' do

    it 'cannot hit a non-ASC student page' do
      @student_page.navigate_to "#{BOACUtils.base_url}/student/#{coe_only_students.first.uid}"
      @student_page.wait_for_title 'Page not found'
    end

    it 'can hit an overlapping ASC and CoE student page' do
      @student_page.load_page overlap_students.first
      @student_page.student_name_heading_element.when_visible Utils.medium_wait
      expect(@student_page.visible_sis_data[:name]).to eql(overlap_students.first.full_name.split(',').reverse.join(' ').strip)
    end

    it('cannot hit the user analytics endpoint for a non-ASC student') do
      expect(@api_user_analytics_page.get_data(@driver, coe_only_students.first)).to be_nil
    end
  end

  context 'visiting the inactive cohort' do

    before(:all) do
      @inactive_search = CohortFilter.new
      @inactive_search.set_custom_filters({:inactive_asc => true})
      @inactive_cohort = FilteredCohort.new({:search_criteria => @inactive_search})
      @homepage.load_page
      @homepage.click_sidebar_create_filtered
      @filtered_cohort_page.perform_search(@inactive_cohort, test_asc)
    end

    it 'sees all inactive students' do
      expected_results = @inactive_student_sids.sort
      visible_results = @filtered_cohort_page.visible_sids.sort
      @filtered_cohort_page.wait_until(1, "Expected but not present: #{expected_results - visible_results}. Present but not expected: #{visible_results - expected_results}") do
        visible_results == expected_results
      end
    end

    it 'sees an inactive indicator on the cohort page' do
      sids = @filtered_cohort_page.player_sid_elements.map &:text
      inactive_student = asc_inactive_students.find { |s| s.sis_id == sids.first }
      expect(@filtered_cohort_page.student_inactive_flag? inactive_student).to be true
    end

    it 'sees an inactive indicator on the student page' do
      @filtered_cohort_page.click_student_link User.new({:uid => @filtered_cohort_page.list_view_uids.first })
      @student_page.wait_for_spinner
      @student_page.inactive_flag_element.when_visible Utils.short_wait
    end
  end

  context 'looking for admin functions' do

    it 'can load the admin page' do
      @homepage.load_page
      @homepage.click_header_dropdown
      expect(@homepage.admin_link?).to be true
    end

    it 'can toggle demo mode' do
      @admin_page.load_page
      @admin_page.demo_mode_toggle_element.when_present Utils.short_wait
    end

    it 'can see no other admin functions' do
      expect(@admin_page.asc_tab?).to be false
      expect(@admin_page.coe_tab?).to be false
      expect(@admin_page.physics_tab?).to be false
      expect(@admin_page.admins_tab?).to be false
      expect(@admin_page.status_heading?).to be false
    end

    it 'cannot hit the cachejob page' do
      @api_admin_page.load_cachejob
      @api_admin_page.unauth_msg_element.when_visible Utils.medium_wait
    end
  end
end
