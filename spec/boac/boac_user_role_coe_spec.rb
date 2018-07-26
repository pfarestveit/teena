require_relative '../../util/spec_helper'

describe 'A CoE advisor using BOAC' do

  include Logging

  asc_students = NessieUtils.get_all_asc_students
  coe_students = NessieUtils.get_all_coe_students asc_students

  overlap_students = asc_students & coe_students
  asc_only_students = asc_students - overlap_students
  all_students = (asc_students + coe_students).uniq

  coe_advisor = BOACUtils.get_dept_advisors(BOACDepartments::COE).first
  coe_advisor_students = NessieUtils.get_coe_advisor_students(coe_advisor, coe_students)

  coe_everyone_filters = BOACUtils.get_everyone_filtered_cohorts BOACDepartments::COE
  coe_other_advisor_filter = coe_everyone_filters.find { |f| f.read_only && f.owner_uid != coe_advisor.uid }

  coe_other_advisor = BOACUtils.get_dept_advisors(BOACDepartments::COE).find { |a| a.uid == coe_other_advisor_filter.owner_uid }
  coe_other_advisor_students = NessieUtils.get_coe_advisor_students(coe_other_advisor, coe_students)

  search_criteria = BOACUtils.get_test_search_criteria.each { |c| c.squads = nil }
  search_criteria.keep_if { |c| [c.levels, c.majors, c.gpa_ranges, c.units].compact.any? }

  before(:all) do
    @driver = Utils.launch_browser
    @admin_page = Page::BOACPages::AdminPage.new @driver
    @api_admin_page = ApiAdminPage.new @driver
    @api_section_page = ApiSectionPage.new @driver
    @class_page = Page::BOACPages::ClassPage.new @driver
    @filtered_cohort_page = Page::BOACPages::CohortPages::FilteredCohortListViewPage.new @driver
    @homepage = Page::BOACPages::HomePage.new @driver
    @search_page = Page::BOACPages::SearchResultsPage.new @driver
    @student_page = Page::BOACPages::StudentPage.new @driver
    @teams_page = Page::BOACPages::TeamsListPage.new @driver

    @homepage.dev_auth
    @all_student_search_data = @api_user_analytics_page.collect_users_searchable_data(@driver, all_students)

    @coe_student_sids = coe_students.map &:sis_id
    @coe_student_search_data = @all_student_search_data.select { |d| @coe_student_sids.include? d[:sid] }

    @my_students_sids = coe_advisor_students.map &:sis_id
    @my_students_search_data = @all_student_search_data.select { |d| @my_students_sids.include? d[:sid] }

    @your_students_sids = coe_other_advisor_students.map &:sis_id
    @your_students_search_data = @all_student_search_data.select { |d| @your_students_sids.include? d[:sid] }

    @homepage.load_page
    @homepage.log_out
    @homepage.dev_auth coe_advisor
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when visiting Everyone\'s Cohorts' do

    it 'sees only filtered cohorts created by CoE advisors' do
      expected_cohort_names = BOACUtils.get_everyone_filtered_cohorts(BOACDepartments::COE).map(&:id).sort
      visible_cohort_names = (@filtered_cohort_page.visible_everyone_cohorts.map &:id).sort
      @filtered_cohort_page.wait_until(1, "Expected #{expected_cohort_names}, but got #{visible_cohort_names}") { visible_cohort_names == expected_cohort_names }
    end

    it 'cannot hit a non-CoE filtered cohort URL' do
      asc_everyone_cohorts = BOACUtils.get_everyone_filtered_cohorts BOACDepartments::ASC
      asc_everyone_cohorts.any? ?
          @filtered_cohort_page.hit_non_auth_cohort(asc_everyone_cohorts.first) :
          logger.warn('Skipping test for CoE access to ASC cohorts because ASC has no cohorts.')
    end
  end

  context 'when performing a user search' do

    it('sees no non-CoE students in search results') { expect(@search_page.search asc_only_students.first.sis_id).to be_zero }
    it('sees overlapping CoE and ASC students in search results') { expect(@search_page.search overlap_students.first.sis_id).to eql(1) }
  end

  context 'when performing a filtered cohort search' do

    # Verification that only CoE students are returned in cohort searches and that Team filters are hidden is part of the filtered cohort test script

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
      api_section_page.wait_until(1, "Expected #{coe_students.map(&:sis_id) & api_section_page.student_sids}, but got #{api_section_page.student_sids}") expect(coe_students.map(&:sis_id) & api_section_page.student_sids).to eql(api_section_page.student_sids)
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

  context 'when visiting My Students' do

    before(:all) do
      @homepage.load_page
      @homepage.click_my_students
      @visible_my_students = @filtered_cohort_page.visible_sids
    end

    it 'sees all My Students' do
      expected_results = @filtered_cohort_page.expected_sids_by_last_name(@coe_student_search_data, CohortSearchCriteria.new({})).sort
      @filtered_cohort_page.wait_until(1, "Expected #{expected_results}, but got #{@visible_my_students.sort}") { @visible_my_students.sort == expected_results }
    end

    it('sees at least one student') { expect(@visible_my_students.any?).to be true }

    it 'can filter for My Students in a search' do
      cohort = FilteredCohort.new({:search_criteria => search_criteria[0]})
      expect(@filtered_cohort_page.my_students_cbx_element.attribute('checked')).to eql('true')
      @filtered_cohort_page.perform_search cohort
      expected_results = @filtered_cohort_page.expected_sids_by_last_name(@my_students_search_data, cohor.search_criteria).sort
      visible_results = @filtered_cohort_page.visible_sids
      @filtered_cohort_page.wait_until(1, "Expected but not present: #{expected_results - visible_results}. Present but not expected: #{visible_results - expected_results}") { visible_results.sort == expected_results.sort }
    end

    it 'can remove the filter for My Students in a search' do
      cohort = FilteredCohort.new({:search_criteria => search_criteria[1]})
      expect(@filtered_cohort_page.my_students_cbx_element.attribute('checked')).to eql('true')
      @filtered_cohort_page.click_my_students
      @filtered_cohort_page.perform_search cohort
      expected_results = @filtered_cohort_page.expected_sids_by_last_name(@my_students_search_data, cohort.search_criteria).sort
      visible_results = @filtered_cohort_page.visible_sids
      @filtered_cohort_page.wait_until(1, "Expected but not present: #{expected_results - visible_results}. Present but not expected: #{visible_results - expected_results}") { visible_results.sort == expected_results.sort }
    end

    it('can no longer see the filter for My Students if it was removed in a previous search') { expect(@filtered_cohort_page.my_students_cbx_element.visible?).to be false }
  end

  context 'when visiting another CoE advisor\'s My Students' do

    before(:all) do
      @filtered_cohort_page.load_cohort coe_other_advisor_filter
      @visible_your_students = @filtered_cohort_page.visible_sids
    end

    it 'sees all Your Students' do
      expected_results = @filtered_cohort_page.expected_sids_by_last_name(@your_students_search_data, CohortSearchCriteria.new({})).sort
      @filtered_cohort_page.wait_until(1, "Expected #{expected_results}, but got #{@visible_your_students.sort}")  { @visible_your_students.sort == expected_results }
    end

    it('sees at least one student') { expect(@visible_your_students.any?).to be true }

    it 'can filter for Your Students in a search' do
      cohort = FilteredCohort.new({:search_criteria => search_criteria[0]})
      expect(@filtered_cohort_page.my_students_cbx_element.attribute('checked')).to eql('true')
      @filtered_cohort_page.perform_search cohort
      expected_results = @filtered_cohort_page.expected_sids_by_last_name(@your_students_search_data, cohort.search_criteria).sort
      visible_results = @filtered_cohort_page.visible_sids
      @filtered_cohort_page.wait_until(1, "Expected but not present: #{expected_results - visible_results}. Present but not expected: #{visible_results - expected_results}") { visible_results.sort == expected_results.sort }
    end

    it 'can remove the filter for Your Students in a search' do
      cohort = FilteredCohort.new({:search_criteria => search_criteria[1]})
      expect(@filtered_cohort_page.my_students_cbx_element.attribute('checked')).to eql('true')
      @filtered_cohort_page.click_my_students
      @filtered_cohort_page.perform_search cohort
      expected_results = @filtered_cohort_page.expected_sids_by_last_name(@your_students_search_data, cohort.search_criteria).sort
      visible_results = @filtered_cohort_page.visible_sids
      @filtered_cohort_page.wait_until(1, "Expected but not present: #{expected_results - visible_results}. Present but not expected: #{visible_results - expected_results}") { visible_results.sort == expected_results.sort }
    end

    it('can no longer see the filter for Your Students if it was removed in a previous search') { expect(@filtered_cohort_page.my_students_cbx_element.visible?).to be false }
  end

  context 'when looking for inactive students' do

    it('sees no link to Inactive Students') { expect(@homepage.inactive_cohort_link?).to be false }

    it 'cannot hit the Inactive Students page' do
      @filtered_cohort_page.load_inactive_students_page
      @filtered_cohort_page.no_access_msg_element.when_visible Utils.short_wait
    end
  end

  context 'when looking for intensive students' do

    it('sees no link to Intensive Students') { expect(@homepage.intensive_cohort_link?).to be false }

    it 'cannot hit the Intensive Students page' do
      @filtered_cohort_page.load_intensive_students_page
      @filtered_cohort_page.no_access_msg_element.when_visible Utils.short_wait
    end
  end

  context 'when looking for teams' do

    it 'cannot see the teams list link' do
      @homepage.load_page
      expect(@homepage.team_list_link?).to be false
    end

    # TODO - it 'cannot reach the Teams page'

    it 'cannot hit a team cohort directly' do
      @filtered_cohort_page.load_team_page Team::FBM
      @filtered_cohort_page.wait_for_spinner
      expect(@filtered_cohort_page.list_view_sids).to be_empty
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
