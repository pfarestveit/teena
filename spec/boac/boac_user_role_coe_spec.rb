require_relative '../../util/spec_helper'

describe 'A CoE advisor using BOAC' do

  include Logging

  all_students = NessieUtils.get_all_students

  test_asc = BOACTestConfig.new
  test_asc.user_role_asc all_students

  test_coe = BOACTestConfig.new
  test_coe.user_role_coe all_students

  overlap_students = test_asc.dept_students & test_coe.dept_students
  asc_only_students = test_asc.dept_students - overlap_students

  coe_everyone_filters = BOACUtils.get_everyone_filtered_cohorts test_coe.dept

  before(:all) do
    @driver = Utils.launch_browser test_coe.chrome_profile
    @admin_page = BOACAdminPage.new @driver
    @api_admin_page = BOACApiAdminPage.new @driver
    @api_section_page = BOACApiSectionPage.new @driver
    @api_user_analytics_page = BOACApiStudentPage.new @driver
    @class_page = BOACClassListViewPage.new @driver
    @filtered_cohort_page = BOACFilteredCohortPage.new @driver
    @homepage = BOACHomePage.new @driver
    @search_page = BOACSearchResultsPage.new @driver
    @student_page = BOACStudentPage.new @driver

    @coe_student_sids = test_coe.dept_students.map &:sis_id
    @coe_student_search_data = test_coe.searchable_data.select { |d| @coe_student_sids.include? d[:sid] }

    @homepage.dev_auth test_coe.advisor
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when visiting Everyone\'s Cohorts' do

    before(:all) do
      @homepage.load_page
      @homepage.click_view_everyone_cohorts
    end

    it 'sees only filtered cohorts created by CoE advisors' do
      expected_cohort_names = coe_everyone_filters.map(&:id).sort
      visible_cohort_names = (@filtered_cohort_page.visible_everyone_cohorts.map &:id).sort
      @filtered_cohort_page.wait_until(1, "Expected but not present: #{expected_cohort_names - visible_cohort_names}. Present but not expected: #{visible_cohort_names - expected_cohort_names}") do
        visible_cohort_names == expected_cohort_names
      end
    end

    it 'cannot hit a non-CoE filtered cohort URL' do
      asc_everyone_cohorts = BOACUtils.get_everyone_filtered_cohorts test_asc.dept
      asc_everyone_cohorts.any? ?
          @filtered_cohort_page.hit_non_auth_cohort(asc_everyone_cohorts.first) :
          logger.warn('Skipping test for CoE access to ASC cohorts because ASC has no cohorts.')
    end
  end

  context 'when performing a user search' do

    it 'sees no non-CoE students in search results' do
      @search_page.search asc_only_students.first.sis_id
      @search_page.no_results_msg.when_visible Utils.short_wait
    end

    it 'sees overlapping CoE and ASC students in search results' do
      @search_page.search overlap_students.first.sis_id
      expect(@search_page.student_search_results_count).to eql(1)
    end
  end

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
    it('sees a Advisor filter') { expect(@filtered_cohort_page.new_filter_option_by_key('advisorLdapUids').visible?).to be true }
    it('sees a Ethnicity filter') { expect(@filtered_cohort_page.new_filter_option_by_key('ethnicities').visible?).to be true }
    it('sees a Gender filter') { expect(@filtered_cohort_page.new_filter_option_by_key('genders').visible?).to be true }
    it('sees a PREP filter') { expect(@filtered_cohort_page.new_filter_option_by_key('coePrepStatuses').visible?).to be true }
    it('sees an Inactive COE filter') { expect(@filtered_cohort_page.new_filter_option_by_key('isInactiveCoe').exists?).to be true }
    it('sees a Probation filter') { expect(@filtered_cohort_page.new_filter_option_by_key('coeProbation').exists?).to be true }
    it('sees no Inactive ASC filter') { expect(@filtered_cohort_page.new_filter_option_by_key('isInactiveAsc').exists?).to be false }
    it('sees no Intensive filter') { expect(@filtered_cohort_page.new_filter_option_by_key('inIntensiveCohort').exists?).to be false }
    it('sees no Team filter') { expect(@filtered_cohort_page.new_filter_option_by_key('groupCodes').exists?).to be false }

  end

  context 'when visiting a class page' do

    # Verification that only CoE students are visible is part of the class page test script

    it 'sees only CoE student data in a section endpoint' do
      api_section_page = BOACApiSectionPage.new @driver
      api_section_page.get_data(@driver, '2178', '13826')
      expected_sids = test_coe.dept_students.map(&:sis_id).sort & api_section_page.student_sids
      visible_sids = api_section_page.student_sids.sort
      api_section_page.wait_until(1, "Expected but not present: #{expected_sids - visible_sids}. Present but not expected: #{visible_sids - expected_sids}") do
        expect(expected_sids).to eql(visible_sids)
      end
    end
  end

  context 'when visiting a student page' do

    it 'cannot hit a non-CoE student page' do
      @student_page.navigate_to "#{BOACUtils.base_url}/student/#{asc_only_students.first.uid}"
      @student_page.wait_for_title 'Page not found'
    end

    it 'can hit an overlapping CoE and ASC student page with sports information removed' do
      @student_page.load_page overlap_students.first
      @student_page.student_name_heading_element.when_visible Utils.medium_wait
      expect(@student_page.visible_sis_data[:name]).to eql(overlap_students.first.full_name.split(',').reverse.join(' ').strip)
      # TODO - no sport shown
    end

    it 'cannot hit the user analytics endpoint for a non-CoE student' do
      asc_user_analytics = BOACApiStudentPage.new @driver
      expect(asc_user_analytics.get_data(@driver, asc_only_students.first)).to be_nil
    end

    it 'cannot see the ASC profile data for an overlapping CoE and ASC student on the user analytics page' do
      overlap_user_analytics = BOACApiStudentPage.new @driver
      overlap_user_analytics.get_data(@driver, overlap_students.first)
      expect(overlap_user_analytics.asc_profile).to be_nil
    end
  end

  context 'when looking for admin functions' do

    it 'can see no link to the admin page' do
      @homepage.load_page
      @homepage.click_header_dropdown
      expect(@homepage.admin_link?).to be false
    end

    it 'cannot hit the admin page' do
      @admin_page.load_page
      @admin_page.wait_for_title 'Page not found'
    end

    it 'cannot hit the cachejob page' do
      @api_admin_page.load_cachejob
      @api_admin_page.unauth_msg_element.when_visible Utils.medium_wait
    end
  end
end
