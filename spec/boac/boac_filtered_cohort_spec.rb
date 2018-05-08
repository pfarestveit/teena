require_relative '../../util/spec_helper'

describe 'BOAC', order: :defined do

  include Logging

  test_id = Utils.get_test_id
  dept_code = ENV['DEPT']
  all_students = BOACUtils.get_all_athletes

  # Filtered cohort UX differs for admins vs ASC advisors vs non-ASC advisors
  admin = User.new({:uid => Utils.super_admin_uid})
  asc_advisor = BOACUtils.get_dept_advisors(BOACDepartments::ASC).first
  non_asc_advisor = BOACUtils.get_dept_advisors(BOACDepartments::COE).first

  # The DEPT env variable determines which advisor will execute the search tests. If it's nil, then admin will execute them.
  advisor = if dept_code
              dept = BOACDepartments::DEPARTMENTS.find { |d| d.code == dept_code }
              (dept == BOACDepartments::ASC) ? asc_advisor : non_asc_advisor
            else
              admin
            end

  # Get all the advisor's existing cohorts
  advisor_cohorts_pre_existing = BOACUtils.get_user_filtered_cohorts advisor

  # Get cohorts to be created during tests. If the advisor is not with ASC, then no team filters will exist. So remove sports-related search criteria
  # from searches. If there are no other criteria in the search, then toss it out.
  test_search_criteria = BOACUtils.get_test_search_criteria
  unless advisor == asc_advisor
    test_search_criteria.each { |c| c.squads = nil }
    test_search_criteria.keep_if { |c| [c.levels, c.majors, c.gpa_ranges, c.units].compact.any? }
  end
  cohorts = test_search_criteria.map { |criteria| FilteredCohort.new({:name => "Test Cohort #{test_search_criteria.index criteria} #{test_id}", :search_criteria => criteria}) }

  before(:all) do
    @driver = Utils.launch_browser
    @analytics_page = ApiUserAnalyticsPage.new @driver
    @homepage = Page::BOACPages::HomePage.new @driver
    @cohort_page = Page::BOACPages::CohortPages::FilteredCohortListViewPage.new @driver
    @student_page = Page::BOACPages::StudentPage.new @driver
    @homepage.dev_auth advisor

    # Get the student data relevant to all search filters
    @all_student_search_data = @analytics_page.collect_users_searchable_data @driver

    active_students = all_students.select { |u| u.status == 'active' }
    active_student_sids = active_students.map &:sis_id
    @active_student_search_data = @all_student_search_data.select { |d| active_student_sids.include? d[:sid] }
    logger.debug "There are #{@active_student_search_data.length} active students"

    inactive_students = all_students.select { |u| u.status == 'inactive' }
    inactive_student_sids = inactive_students.map &:sis_id
    @inactive_student_search_data = @all_student_search_data.select { |d| inactive_student_sids.include? d[:sid] }
    logger.debug "There are #{@inactive_student_search_data.length} inactive students"

    intensive_students = BOACUtils.get_intensive_athletes
    intensive_student_sids = intensive_students.map &:sis_id
    @intensive_student_search_data = @all_student_search_data.select { |d| intensive_student_sids.include? d[:sid] }
    @intensive_student_search_data.delete_if { |d| inactive_student_sids.include? d[:sid] }
    logger.debug "There are #{@intensive_student_search_data.length} active intensive students"

    # If the advisor is from ASC, then only active students should appear in search results. If from another dept or an admin user,
    # then all students should appear.
    @searchable_students = (advisor == asc_advisor) ? @active_student_search_data : @all_student_search_data
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when an advisor has no filtered cohorts' do

    before(:all) do
      @homepage.load_page
      advisor_cohorts_pre_existing.each { |c| @cohort_page.delete_cohort c }
    end

    it('shows a No Filtered Cohorts message on the homepage') do
      @homepage.load_page
      expect(@homepage.no_filtered_cohorts_msg?).to be true
    end
  end

  context 'filtered cohort search' do

    before(:each) { @cohort_page.cancel_cohort if @cohort_page.cancel_cohort_button? }

    cohorts.each do |cohort|
      it "shows all the students who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        @homepage.load_page
        @cohort_page.click_sidebar_create_filtered
        @cohort_page.perform_search cohort
        expected_results = @cohort_page.expected_search_results(@searchable_students, cohort.search_criteria).map { |u| u[:sid] }
        visible_results = cohort.member_count.zero? ? [] : @cohort_page.visible_sids
        @cohort_page.wait_until(1, "Expected #{expected_results.sort} but got #{visible_results.sort}") { visible_results.sort == expected_results.sort }
      end

      it "sorts by Last Name all the students who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        expected_results = @cohort_page.expected_sids_by_last_name(@searchable_students, cohort.search_criteria)
        visible_results = @cohort_page.visible_sids
        @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
      end

      it "shows by First Name all the students who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        expected_results = @cohort_page.expected_sids_by_first_name(@searchable_students, cohort.search_criteria)
        @cohort_page.sort_by_first_name if expected_results.any?
        visible_results = @cohort_page.visible_sids
        @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
      end

      it "sorts by Team all the students who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        if advisor == asc_advisor
          expected_results = @cohort_page.expected_sids_by_team(@searchable_students, cohort.search_criteria)
          @cohort_page.sort_by_team if expected_results.any?
          visible_results = @cohort_page.visible_sids
          @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
        else
          logger.warn 'Skipping sort-by-team since the user is not with ASC'
        end
      end

      it "sorts by GPA all the students who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        expected_results = @cohort_page.expected_sids_by_gpa(@searchable_students, cohort.search_criteria)
        @cohort_page.sort_by_gpa if expected_results.any?
        visible_results = @cohort_page.visible_sids
        @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
      end

      it "sorts by Level all the students who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        expected_results = @cohort_page.expected_sids_by_level(@searchable_students, cohort.search_criteria)
        @cohort_page.sort_by_level if expected_results.any?
        visible_results = @cohort_page.visible_sids
        @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
      end

      it "sorts by Major all the students who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        expected_results = @cohort_page.expected_sids_by_major(@searchable_students, cohort.search_criteria)
        @cohort_page.sort_by_major if expected_results.any?
        visible_results = @cohort_page.visible_sids
        @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
      end

      it "sorts by Units all the students who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        expected_results = @cohort_page.expected_sids_by_units(@searchable_students, cohort.search_criteria)
        @cohort_page.sort_by_units if expected_results.any?
        visible_results = @cohort_page.visible_sids
        @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
      end
    end

    cohorts.each do |cohort|
      it "allows the advisor to create a cohort using '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        @cohort_page.click_sidebar_create_filtered
        @cohort_page.perform_search cohort
        @cohort_page.create_new_cohort cohort
      end

      it 'shows the filtered cohort on the homepage' do
        @homepage.load_page
        @homepage.wait_until(Utils.medium_wait) { @homepage.filtered_cohorts.include? cohort.name }
      end

      it 'shows the filtered cohort members who have alerts on the homepage' do
        member_sids = @cohort_page.expected_sids_by_last_name(@searchable_students, cohort.search_criteria)
        @homepage.wait_until(Utils.short_wait) { @homepage.filtered_cohort_member_count(cohort) == member_sids.length }
        members = all_students.select { |u| member_sids.include? u.sis_id }
        @homepage.verify_cohort_alert_rows(@driver, cohort, members, advisor)
      end

      it 'offers a link to the filtered cohort' do
        @homepage.click_filtered_cohort cohort
        @cohort_page.cohort_heading(cohort).when_visible Utils.medium_wait
      end
    end

    it 'requires a title' do
      @homepage.click_sidebar_create_filtered
      @cohort_page.perform_search cohorts.first
      @cohort_page.click_save_cohort_button_one
      expect(@cohort_page.save_cohort_button_two_element.disabled?).to be true
    end

    it 'truncates a title over 255 characters' do
      cohort = FilteredCohort.new({name: "#{'A loooooong title ' * 15}?"})
      @homepage.click_sidebar_create_filtered
      @cohort_page.perform_search cohorts.first
      @cohort_page.save_and_name_cohort cohort
      cohort.name = cohort.name[0..254]
      @cohort_page.wait_for_filtered_cohort cohort
      cohorts << cohort
    end

    it 'requires that a title be unique among the user\'s existing cohorts' do
      cohort = FilteredCohort.new({name: cohorts.first.name})
      @cohort_page.save_and_name_cohort cohort
      @cohort_page.dupe_filtered_name_msg_element.when_visible Utils.short_wait
    end
  end

  context 'when the advisor views its cohorts' do

    it('shows only the advisor\'s cohorts on the homepage') do
      @homepage.load_page
      @homepage.wait_until(Utils.short_wait) { @homepage.filtered_cohorts.any? }
      expect(@homepage.filtered_cohorts.sort).to eql((cohorts.map &:name).sort)
    end
  end

  context 'when the advisor edits a cohort\'s search filters' do

    it 'creates a new cohort' do
      existing_cohort = cohorts.first
      new_cohort = FilteredCohort.new({name: "Edited Search #{test_id}", search_criteria: test_search_criteria.last})
      @cohort_page.load_cohort existing_cohort
      @cohort_page.search_and_create_edited_cohort(existing_cohort, new_cohort)
      expect(new_cohort.id).not_to eql(existing_cohort.id)
    end
  end

  context 'when the advisor edits a cohort\'s name' do

    it 'renames the existing cohort' do
      cohort = cohorts.first
      id = cohort.id
      @cohort_page.rename_cohort(cohort, "#{cohort.name} - Renamed")
      expect(cohort.id).to eql(id)
    end
  end

  context 'when the advisor deletes a cohort and tries to navigate to the deleted cohort' do

    before(:all) { @cohort_page.delete_cohort cohorts.last }

    it 'shows a Not Found page' do
      @cohort_page.navigate_to "#{BOACUtils.base_url}/cohort?c=#{cohorts.last.id}"
      @cohort_page.cohort_not_found_msg_element.when_visible Utils.medium_wait
    end
  end

  describe 'filtered cohorts' do

    context 'when an advisor is with ASC' do

      before(:all) do
        @homepage.log_out
        @homepage.dev_auth asc_advisor
      end

      it 'offers Teams filters' do
        @homepage.click_sidebar_create_filtered
        @cohort_page.wait_until(Utils.short_wait) { @cohort_page.squad_option_elements.any? }
      end
    end

    context 'when an advisor is not with ASC' do

      before(:all) do
        @homepage.log_out
        @homepage.dev_auth non_asc_advisor
      end

      it 'offers no Teams filters' do
        @homepage.click_sidebar_create_filtered
        @cohort_page.wait_until(Utils.short_wait) { @cohort_page.level_option_elements.any? }
        expect(@cohort_page.squad_option_elements.any?).to be false
      end
    end

    context 'when an admin' do

      before(:all) do
        @homepage.log_out
        @homepage.dev_auth admin
      end

      it 'offers no Teams filters' do
        @homepage.click_sidebar_create_filtered
        @cohort_page.wait_until(Utils.short_wait) { @cohort_page.level_option_elements.any? }
        expect(@cohort_page.squad_option_elements.any?).to be false
      end
    end
  end

  describe 'Everyone\'s Cohorts' do

    before(:all) do
      @everyone_cohorts_pre_existing = BOACUtils.get_everyone_filtered_cohorts
      logger.debug "Everyone has #{@everyone_cohorts_pre_existing.length} total cohorts"
    end

    context 'when an advisor is with ASC' do

      before(:all) do
        @homepage.log_out
        @homepage.dev_auth asc_advisor
      end

      it 'shows the user Everyone\'s Cohorts' do
        expected_cohort_names = (@everyone_cohorts_pre_existing.map &:name).sort
        visible_cohort_names = (@cohort_page.visible_everyone_cohorts.map &:name).sort
        @cohort_page.wait_until(1, "Expected #{expected_cohort_names}, but got #{visible_cohort_names}") { visible_cohort_names == expected_cohort_names }
      end
    end

    context 'when an advisor is not with ASC' do

      before(:all) do
        @homepage.log_out
        @homepage.dev_auth non_asc_advisor
      end

      it('shows no link to Everyone\'s Cohorts') { expect(@homepage.view_everyone_cohorts_link?).to be false }

      it 'prevents the advisor reaching the Everyone\'s Cohorts page' do
        @cohort_page.load_everyone_cohorts_page
        expect(@cohort_page.everyone_cohort_link_elements.any?).to be false
      end
    end

    context 'when an admin' do

      before(:all) do
        @homepage.log_out
        @homepage.dev_auth admin
      end

      it('shows no link to Everyone\'s Cohorts') { expect(@homepage.view_everyone_cohorts_link?).to be false }

      it 'allows the admin to reach the Everyone\'s Cohorts page' do
        @cohort_page.load_everyone_cohorts_page
        @cohort_page.wait_until(Utils.medium_wait) { @cohort_page.everyone_cohort_link_elements.any? }
      end
    end
  end

  describe 'Inactive cohort students' do

    context 'when an advisor is with ASC' do

      before(:all) do
        @homepage.log_out
        @homepage.dev_auth asc_advisor
        @homepage.click_inactive_cohort
        @visible_inactive_students = @cohort_page.visible_sids
        @student = User.new({})
      end

      it 'all appear on the cohort page with an INACTIVE indicator' do
        expected_results = @cohort_page.expected_sids_by_last_name(@inactive_student_search_data, CohortSearchCriteria.new({}))
        expect(@visible_inactive_students).to eql(expected_results)
      end

      it('include at least one inactive student') { expect(@visible_inactive_students.empty?).to be false }

      it 'have an inactive indicator on the student page' do
        @student.uid = @cohort_page.list_view_uids.first
        @cohort_page.click_player_link @student
        @student_page.wait_for_spinner
        @student_page.inactive_flag_element.when_visible Utils.short_wait
      end

      cohorts.each do |cohort|
        it "shows all the students who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
          @homepage.load_page
          @cohort_page.click_inactive_cohort
          @cohort_page.perform_search cohort
          expected_results = @cohort_page.expected_search_results(@inactive_student_search_data, cohort.search_criteria).map { |u| u[:sid] }
          visible_results = cohort.member_count.zero? ? [] : @cohort_page.visible_sids
          @cohort_page.wait_until(1, "Expected #{expected_results.sort} but got #{visible_results.sort}") { visible_results.sort == expected_results.sort }
        end
      end
    end

    context 'when an advisor is not with ASC' do

      before(:all) do
        @homepage.log_out
        @homepage.dev_auth non_asc_advisor
      end

      it('shows no link to Inactive Students') { expect(@homepage.inactive_cohort_link?).to be false }

      it 'prevents the advisor reaching the Inactive Students page' do
        @cohort_page.load_inactive_students_page
        @cohort_page.no_access_msg_element.when_visible Utils.short_wait
      end
    end

    context 'when an admin' do

      before(:all) do
        @homepage.log_out
        @homepage.dev_auth admin
      end

      it('shows no link to Inactive Students') { expect(@homepage.inactive_cohort_link?).to be false }

      it 'allows the admin to reach the Inactive Students page' do
        @cohort_page.load_inactive_students_page
        @cohort_page.wait_until(Utils.medium_wait) { @cohort_page.list_view_uids.any? }
      end
    end
  end

  describe 'Intensive cohort students' do

    context 'when an advisor is with ASC' do

      before(:all) do
        @homepage.log_out
        @homepage.dev_auth asc_advisor
        @homepage.click_intensive_cohort
        @visible_intensive_students = @cohort_page.visible_sids
      end

      it 'all appear on the cohort page' do
        expected_results = @cohort_page.expected_sids_by_last_name(@intensive_student_search_data, CohortSearchCriteria.new({}))
        expect(@visible_intensive_students).to eql(expected_results)
      end

      it('include at least one intensive student') { expect(@visible_intensive_students.empty?).to be false }

      cohorts.each do |cohort|
        it "shows all the users who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
          @homepage.load_page
          @cohort_page.click_intensive_cohort
          @cohort_page.perform_search cohort
          expected_results = @cohort_page.expected_search_results(@intensive_student_search_data, cohort.search_criteria).map { |u| u[:sid] }
          visible_results = cohort.member_count.zero? ? [] : @cohort_page.visible_sids
          @cohort_page.wait_until(1, "Expected #{expected_results.sort} but got #{visible_results.sort}") { visible_results.sort == expected_results.sort }
        end
      end
    end

    context 'when an advisor is not with ASC' do

      before(:all) do
        @homepage.log_out
        @homepage.dev_auth non_asc_advisor
      end

      it('shows no link to Intensive Students') { expect(@homepage.intensive_cohort_link?).to be false }

      it 'prevents the advisor reaching the Intensive Students page' do
        @cohort_page.load_intensive_students_page
        @cohort_page.no_access_msg_element.when_visible Utils.short_wait
      end
    end

    context 'when an admin' do

      before(:all) do
        @homepage.log_out
        @homepage.dev_auth admin
      end

      it('shows no link to Intensive Students') { expect(@homepage.intensive_cohort_link?).to be false }

      it 'allows the admin to reach the Intensive Students page' do
        @cohort_page.load_intensive_students_page
        @cohort_page.wait_until(Utils.medium_wait) { @cohort_page.list_view_uids.any? }
      end
    end

  end
end
