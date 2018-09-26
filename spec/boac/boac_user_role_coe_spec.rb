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
    @driver = Utils.launch_browser
    @admin_page = Page::BOACPages::AdminPage.new @driver
    @api_admin_page = ApiAdminPage.new @driver
    @api_section_page = ApiSectionPage.new @driver
    @api_user_analytics_page = ApiUserAnalyticsPage.new @driver
    @class_page = Page::BOACPages::ClassPages::ClassListViewPage.new @driver
    @filtered_cohort_page = Page::BOACPages::CohortPages::FilteredCohortPage.new @driver
    @homepage = Page::BOACPages::HomePage.new @driver
    @search_page = Page::BOACPages::SearchResultsPage.new @driver
    @student_page = Page::BOACPages::StudentPage.new @driver
    @teams_page = Page::BOACPages::TeamsListPage.new @driver

    @homepage.dev_auth
    all_student_search_data = @api_user_analytics_page.collect_users_searchable_data(@driver, all_students)

    @coe_student_sids = test_coe.dept_students.map &:sis_id
    @coe_student_search_data = all_student_search_data.select { |d| @coe_student_sids.include? d[:sid] }

    @homepage.load_page
    @homepage.log_out
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
      @filtered_cohort_page.wait_until(1, "Expected #{expected_cohort_names}, but got #{visible_cohort_names}") { visible_cohort_names == expected_cohort_names }
    end

    it 'cannot hit a non-CoE filtered cohort URL' do
      asc_everyone_cohorts = BOACUtils.get_everyone_filtered_cohorts test_asc.dept
      asc_everyone_cohorts.any? ?
          @filtered_cohort_page.hit_non_auth_cohort(asc_everyone_cohorts.first) :
          logger.warn('Skipping test for CoE access to ASC cohorts because ASC has no cohorts.')
    end
  end

  context 'when performing a user search' do

    it('sees no non-CoE students in search results') { expect(@search_page.search asc_only_students.first.sis_id).to be_zero }
    it('sees overlapping CoE and ASC students in search results') { expect(@search_page.search overlap_students.first.sis_id).to eql(1) }
  end

  context 'performing a filtered cohort search' do

    before(:all) do
      @homepage.click_sidebar_create_filtered
      @filtered_cohort_page.wait_for_update_and_click @filtered_cohort_page.new_filter_button_element
      @filtered_cohort_page.wait_until(1) { @filtered_cohort_page.new_filter_option_elements.any? &:visible? }
    end

    it('sees a Level filter') { expect(@filtered_cohort_page.new_filter_option('Level').visible?).to be true }
    it('sees a Major filter') { expect(@filtered_cohort_page.new_filter_option('Major').visible?).to be true }
    it('sees a Units filter') { expect(@filtered_cohort_page.new_filter_option('Units Completed').visible?).to be true }
    it('sees a Advisor filter') { expect(@filtered_cohort_page.new_filter_option('Advisor').visible?).to be true }
    it('sees a Ethnicity filter') { expect(@filtered_cohort_page.new_filter_option('Ethnicity').visible?).to be true }
    it('sees a Gender filter') { expect(@filtered_cohort_page.new_filter_option('Gender').visible?).to be true }
    it('sees a PREP filter') { expect(@filtered_cohort_page.new_filter_option('PREP').visible?).to be true }
    it('sees a Inactive filter') { expect(@filtered_cohort_page.new_filter_option('Inactive').exists?).to be false }
    it('sees a Intensive filter') { expect(@filtered_cohort_page.new_filter_option('Intensive').exists?).to be false }
    it('sees a Team filter') { expect(@filtered_cohort_page.new_filter_option('Team').exists?).to be false }

    it 'cannot hit team filters directly' do
      @filtered_cohort_page.load_squad Squad::MFB_ST
      @filtered_cohort_page.wait_for_search_results
      expect(@filtered_cohort_page.results_count).to be_zero
    end
  end

  context 'when visiting a class page' do

    # Verification that only CoE students are visible is part of the class page test script

    it 'sees only CoE student data in a section endpoint' do
      api_section_page = ApiSectionPage.new @driver
      api_section_page.get_data(@driver, '2178', '13826')
      api_section_page.wait_until(1, "Expected #{test_coe.dept_students.map(&:sis_id).sort & api_section_page.student_sids}, but got #{api_section_page.student_sids.sort}") { expect(test_coe.dept_students.map(&:sis_id).sort & api_section_page.student_sids).to eql(api_section_page.student_sids.sort) }
    end
  end

  context 'when visiting a student page' do

    it 'cannot hit a non-CoE student page' do
      @student_page.load_page asc_only_students.first
      @student_page.not_found_msg_element.when_visible Utils.medium_wait
      expect(@student_page.visible_sis_data[:name]).to be_nil
    end

    it 'can hit an overlapping CoE and ASC student page with sports information removed' do
      @student_page.load_page overlap_students.first
      @student_page.student_name_heading_element.when_visible Utils.medium_wait
      expect(@student_page.visible_sis_data[:name]).to eql(overlap_students.first.full_name.split(',').reverse.join(' ').strip)
      # TODO - no sport shown
    end

    it 'cannot hit the user analytics endpoint for a non-CoE student' do
      asc_user_analytics = ApiUserAnalyticsPage.new @driver
      expect(asc_user_analytics.get_data(@driver, asc_only_students.first)).to be_nil
    end

    it 'cannot see the ASC profile data for an overlapping CoE and ASC student on the user analytics page' do
      overlap_user_analytics = ApiUserAnalyticsPage.new @driver
      overlap_user_analytics.get_data(@driver, overlap_students.first)
      expect(overlap_user_analytics.asc_profile).to be_nil
    end
  end

  context 'when looking for inactive students' do

    it('sees no link to Inactive Students') { expect(@homepage.inactive_cohort_link?).to be false }

    it 'cannot hit the Inactive Students page' do
      @filtered_cohort_page.load_inactive_students_page
      @filtered_cohort_page.wait_until(Utils.short_wait) { @filtered_cohort_page.results == 'Create a Filtered Cohort' }
    end
  end

  context 'when looking for intensive students' do

    it('sees no link to Intensive Students') { expect(@homepage.intensive_cohort_link?).to be false }

    it 'cannot hit the Intensive Students page' do
      @filtered_cohort_page.load_intensive_students_page
      @filtered_cohort_page.wait_until(Utils.short_wait) { @filtered_cohort_page.results == 'Create a Filtered Cohort' }
    end
  end

  context 'when looking for teams' do

    it 'cannot see the teams list link' do
      @homepage.load_page
      expect(@homepage.team_list_link?).to be false
    end

    # TODO - it 'cannot reach the Teams page'

    it 'cannot hit a team cohort directly' do
      @filtered_cohort_page.hit_team_url Team::FBM
      @filtered_cohort_page.wait_until(Utils.short_wait) { @filtered_cohort_page.results == 'Create a Filtered Cohort' }
    end
  end

  context 'when looking for admin functions' do

    it 'can see no link to the admin page' do
      @homepage.click_header_dropdown
      expect(@homepage.admin_link?).to be false
    end

    it 'cannot hit the admin page' do
      @admin_page.load_page
      @admin_page.wait_for_title '404'
    end

    it 'cannot hit the cachejob page' do
      @api_admin_page.load_cachejob
      @api_admin_page.unauth_msg_element.when_visible Utils.medium_wait
    end
  end
end
