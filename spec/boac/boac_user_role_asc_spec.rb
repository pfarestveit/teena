require_relative '../../util/spec_helper'

describe 'An ASC advisor' do

  include Logging

  all_students = NessieUtils.get_all_students

  test_asc = BOACTestConfig.new
  test_asc.user_role_asc all_students

  test_coe = BOACTestConfig.new
  test_coe.user_role_coe all_students

  asc_inactive_students = test_asc.dept_students.reject &:active_asc
  asc_intensive_students = test_asc.dept_students.select &:intensive_asc

  overlap_students = test_asc.dept_students & test_coe.dept_students
  coe_only_students = test_coe.dept_students - overlap_students

  before(:all) do
    @driver = Utils.launch_browser
    @admin_page = Page::BOACPages::AdminPage.new @driver
    @api_admin_page = ApiAdminPage.new @driver
    @api_section_page = ApiSectionPage.new @driver
    @api_user_analytics_page = ApiUserAnalyticsPage.new @driver
    @class_page = Page::BOACPages::ClassPage.new @driver
    @curated_cohort_page = Page::BOACPages::CohortPages::CuratedCohortListViewPage.new @driver
    @filtered_cohort_page = Page::BOACPages::CohortPages::FilteredCohortListViewPage.new @driver
    @homepage = Page::BOACPages::HomePage.new @driver
    @search_page = Page::BOACPages::SearchResultsPage.new @driver
    @student_page = Page::BOACPages::StudentPage.new @driver
    @teams_page = Page::BOACPages::TeamsListPage.new @driver

    # Collect searchable user data relevant to an ASC advisor
    @homepage.dev_auth
    @all_student_search_data = @api_user_analytics_page.collect_users_searchable_data(@driver, all_students)

    @asc_student_sids = test_asc.dept_students.map &:sis_id
    @asc_student_search_data = @all_student_search_data.select { |d| @asc_student_sids.include? d[:sid] }

    @inactive_student_sids = asc_inactive_students.map &:sis_id
    @inactive_student_search_data = @asc_student_search_data.select { |d| @inactive_student_sids.include? d[:sid] }
    logger.debug "There are #{@inactive_student_search_data.length} inactive students"

    @intensive_student_sids = asc_intensive_students.map &:sis_id
    @intensive_student_search_data = @asc_student_search_data.select { |d| @intensive_student_sids.include? d[:sid] }
    @intensive_student_search_data.delete_if { |d| @inactive_student_sids.include? d[:sid] }
    logger.debug "There are #{@intensive_student_search_data.length} active intensive students"

    @homepage.load_page
    @homepage.log_out
    @homepage.dev_auth test_asc.advisor
  end

  after(:all) { Utils.quit_browser @driver }

  context 'visiting Everyone\'s Cohorts' do

    it 'sees only filtered cohorts created by ASC advisors' do
      expected_cohort_names = BOACUtils.get_everyone_filtered_cohorts(BOACDepartments::ASC).map(&:id).sort
      visible_cohort_names = (@filtered_cohort_page.visible_everyone_cohorts.map &:id).sort
      @filtered_cohort_page.wait_until(1, "Expected #{expected_cohort_names}, but got #{visible_cohort_names}") { visible_cohort_names == expected_cohort_names }
    end

    it 'cannot hit a non-ASC filtered cohort URL' do
      coe_everyone_cohorts = BOACUtils.get_everyone_filtered_cohorts BOACDepartments::COE
      coe_everyone_cohorts.any? ?
          @filtered_cohort_page.hit_non_auth_cohort(coe_everyone_cohorts.first) :
          logger.warn('Skipping test for ASC access to CoE cohorts because CoE has no cohorts.')
    end
  end

  context 'performing a user search' do

    it('sees no non-ASC students in search results') { expect(@search_page.search coe_only_students.first.sis_id).to be_zero }
    it('sees no inactive ASC students in search results') { expect(@search_page.search @inactive_student_sids.first).to be_zero }
    it('sees overlapping ASC and CoE students in search results') { expect(@search_page.search overlap_students.first.sis_id).to eql(1) }
  end

  context 'visiting a class page' do

    # Verification that only ASC students are visible is part of the class page test script

    it 'sees only ASC student data in a section endpoint' do
      api_section_page = ApiSectionPage.new @driver
      api_section_page.get_data(@driver, '2178', '13826')
      expect(test_asc.dept_students.map(&:sis_id).sort & api_section_page.student_sids).to eql(api_section_page.student_sids.sort)
    end
  end

  context 'visiting a student page' do

    it 'cannot hit a non-ASC student page' do
      @student_page.load_page coe_only_students.first
      @student_page.not_found_msg_element.when_visible Utils.medium_wait
      expect(@student_page.visible_sis_data[:name]).to be_nil
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
      @homepage.load_page
      @homepage.click_inactive_cohort
      @visible_inactive_students = @filtered_cohort_page.visible_sids
    end

    it 'sees all inactive students with an INACTIVE indicator' do
      expected_results = @filtered_cohort_page.expected_sids_by_last_name(@inactive_student_search_data, CohortFilter.new).sort
      @filtered_cohort_page.wait_until(1, "Expected #{expected_results}, but got #{@visible_inactive_students.sort}") { @visible_inactive_students.sort == expected_results }
      # TODO - inactive indicator
    end

    it('sees at least one inactive student') { expect(@visible_inactive_students.any?).to be true }

    it 'sees an inactive indicator on the student page' do
      @filtered_cohort_page.click_player_link User.new({:uid => @filtered_cohort_page.list_view_uids.first })
      @student_page.wait_for_spinner
      @student_page.inactive_flag_element.when_visible Utils.short_wait
    end

    it 'can filter for inactive students in a search' do
      @filtered_cohort_page.click_inactive_cohort
      expect(@filtered_cohort_page.inactive_cbx_element.attribute('checked')).to eql('true')
      @filtered_cohort_page.perform_search test_asc.searches[0]
      expected_results = @filtered_cohort_page.expected_sids_by_last_name(@inactive_student_search_data, test_asc.searches[0].search_criteria).sort
      visible_results = @filtered_cohort_page.visible_sids
      @filtered_cohort_page.wait_until(1, "Expected but not present: #{expected_results - visible_results}. Present but not expected: #{visible_results - expected_results}") { visible_results.sort == expected_results.sort }
    end

    it 'can remove the filter for inactive students in a search' do
      expect(@filtered_cohort_page.inactive_cbx_element.attribute('checked')).to eql('true')
      @filtered_cohort_page.click_inactive
      @filtered_cohort_page.perform_search test_asc.searches[1]
      expected_results = @filtered_cohort_page.expected_sids_by_last_name((@asc_student_search_data - @inactive_student_search_data), test_asc.searches[1].search_criteria).sort
      visible_results = @filtered_cohort_page.visible_sids
      @filtered_cohort_page.wait_until(1, "Expected but not present: #{expected_results - visible_results}. Present but not expected: #{visible_results - expected_results}") { visible_results.sort == expected_results.sort }
    end

    it('can no longer see the filter for inactive students if it was removed in a previous search') { expect(@filtered_cohort_page.inactive_cbx_element.visible?).to be false }
  end

  context 'visiting the intensive cohort' do

    before(:all) do
      @homepage.click_intensive_cohort
      @visible_intensive_students = @filtered_cohort_page.visible_sids
    end

    it 'sees all intensive students' do
      expected_results = @filtered_cohort_page.expected_sids_by_last_name(@intensive_student_search_data, CohortFilter.new).sort
      @filtered_cohort_page.wait_until(1, "Expected #{expected_results}, but got #{@visible_intensive_students.sort}")  { @visible_intensive_students.sort == expected_results }
    end

    it('sees at least one intensive student') { expect(@visible_intensive_students.any?).to be true }

    it 'can filter for intensive students in a search' do
      expect(@filtered_cohort_page.intensive_cbx_element.attribute('checked')).to eql('true')
      @filtered_cohort_page.perform_search test_asc.searches[0]
      expected_results = @filtered_cohort_page.expected_sids_by_last_name(@intensive_student_search_data, test_asc.searches[0].search_criteria).sort
      visible_results = @filtered_cohort_page.visible_sids
      @filtered_cohort_page.wait_until(1, "Expected but not present: #{expected_results - visible_results}. Present but not expected: #{visible_results - expected_results}") { visible_results.sort == expected_results.sort }
    end

    it 'can remove the filter for intensive students in a search' do
      expect(@filtered_cohort_page.intensive_cbx_element.attribute('checked')).to eql('true')
      @filtered_cohort_page.click_intensive
      @filtered_cohort_page.perform_search test_asc.searches[1]
      expected_results = @filtered_cohort_page.expected_sids_by_last_name((@asc_student_search_data - @inactive_student_search_data), test_asc.searches[1].search_criteria).sort
      visible_results = @filtered_cohort_page.visible_sids
      @filtered_cohort_page.wait_until(1, "Expected but not present: #{expected_results - visible_results}. Present but not expected: #{visible_results - expected_results}") { visible_results.sort == expected_results.sort }
    end

    it('can no longer see the filter for intensive students if it was removed in a previous search') { expect(@filtered_cohort_page.intensive_cbx?).to be false }
  end

  context 'looking for admin functions' do

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
