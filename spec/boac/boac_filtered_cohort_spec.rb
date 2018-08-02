require_relative '../../util/spec_helper'

describe 'BOAC', order: :defined do

  include Logging

  test_id = Utils.get_test_id
  performance_data = File.join(Utils.initialize_test_output_dir, 'boac-search-performance.csv')

  # Filtered cohort UX differs for admins vs ASC advisors vs CoE advisors. The department determines which advisor will
  # execute the search tests. If it's nil, then admin will execute them.
  dept = BOACUtils.test_dept
  asc_advisor = BOACUtils.get_dept_advisors(BOACDepartments::ASC).first
  coe_advisor = BOACUtils.get_dept_advisors(BOACDepartments::COE).first
  advisor = if dept
              (dept == BOACDepartments::ASC) ? asc_advisor : coe_advisor
            else
              User.new({:uid => Utils.super_admin_uid})
            end
  students = NessieUtils.get_all_relevant_students dept
  # If the advisor is from ASC, then inactive students should not appear in default search results
  students.delete_if { |s| s.status == 'inactive' } if advisor == asc_advisor

  # Get cohorts to be created during tests. If the advisor is not with ASC, then no team filters will exist. So remove sports-related search criteria
  # from searches. If there are no other criteria in the search, then toss out the search.
  test_search_criteria = BOACUtils.get_test_search_criteria
  unless advisor == asc_advisor
    test_search_criteria.each { |c| c.squads = nil }
    test_search_criteria.keep_if { |c| [c.levels, c.majors, c.gpa_ranges, c.units].compact.any? }
  end

  # Get a list of the advisor's pre-existing cohorts and the ones to be created during the tests.
  cohorts = test_search_criteria.map { |criteria| FilteredCohort.new({:name => "Test Cohort #{test_search_criteria.index criteria} #{test_id}", :search_criteria => criteria}) }
  pre_existing_cohorts = BOACUtils.get_user_filtered_cohorts advisor

  before(:all) do
    @driver = Utils.launch_browser
    @analytics_page = ApiUserAnalyticsPage.new @driver
    @homepage = Page::BOACPages::HomePage.new @driver
    @cohort_page = Page::BOACPages::CohortPages::FilteredCohortListViewPage.new @driver
    @student_page = Page::BOACPages::StudentPage.new @driver
    @homepage.dev_auth advisor

    # Get the student data relevant to all search filters.
    @searchable_students = @analytics_page.collect_users_searchable_data(@driver, students, dept)
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when an advisor has no filtered cohorts' do

    before(:all) do
      @homepage.load_page
      pre_existing_cohorts.each { |c| @cohort_page.delete_cohort(cohorts, c) }
    end

    it('shows a No Filtered Cohorts message on the homepage') do
      @homepage.load_page
      # CoE advisors will always have a 'my students' filtered cohort that cannot be deleted
      (advisor == coe_advisor) ?
          (expect(@homepage.no_filtered_cohorts_msg?).to be false) :
          (expect(@homepage.no_filtered_cohorts_msg?).to be true)
    end
  end

  context 'filtered cohort search' do

    before(:each) { @cohort_page.cancel_cohort if @cohort_page.cancel_cohort_button? }

    it "shows only filters available to #{dept.name}" do
      @cohort_page.click_sidebar_create_filtered
      @cohort_page.wait_until(Utils.short_wait) { @cohort_page.level_option_elements.any? }
      (dept == BOACDepartments::ASC) ?
          (expect(@cohort_page.squad_filter_button?).to be true) :
          (expect(@cohort_page.squad_filter_button?).to be false)
    end

    cohorts.each do |cohort|
      it "shows all the students sorted by Last Name who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        @cohort_page.click_sidebar_create_filtered
        @cohort_page.perform_search(cohort, performance_data)
        expected_results = @cohort_page.expected_sids_by_last_name(@searchable_students, cohort.search_criteria)
        visible_results = cohort.member_count.zero? ? [] : @cohort_page.visible_sids
        @cohort_page.wait_until(1, "Expected but not present: #{expected_results - visible_results}. Present but not expected: #{visible_results - expected_results}") { visible_results.sort == expected_results.sort }
      end

      it "shows by First Name all the students who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        expected_results = @cohort_page.expected_sids_by_first_name(@searchable_students, cohort.search_criteria)
        if expected_results.length.zero?
          logger.warn 'Skipping sort-by-first-name test since there are no results'
        else
          @cohort_page.sort_by_first_name if expected_results.any?
          visible_results = @cohort_page.visible_sids
          @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
        end
      end

      it "sorts by Team all the students who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        if advisor == asc_advisor
          expected_results = @cohort_page.expected_sids_by_team(@searchable_students, cohort.search_criteria)
          if expected_results.length.zero?
            logger.warn 'Skipping sort-by-team test since there are no results'
          else
            @cohort_page.sort_by_team if expected_results.any?
            visible_results = @cohort_page.visible_sids
            @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
          end
        else
          logger.warn 'Skipping sort-by-team since the user is not with ASC'
        end
      end

      it "sorts by GPA all the students who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        expected_results = @cohort_page.expected_sids_by_gpa(@searchable_students, cohort.search_criteria)
        if expected_results.length.zero?
          logger.warn 'Skipping sort-by-GPA test since there are no results'
        else
          @cohort_page.sort_by_gpa if expected_results.any?
          visible_results = @cohort_page.visible_sids
          @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
        end
      end

      it "sorts by Level all the students who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        expected_results = @cohort_page.expected_sids_by_level(@searchable_students, cohort.search_criteria)
        if expected_results.length.zero?
          logger.warn 'Skipping sort-by-level test since there are no results'
        else
          @cohort_page.sort_by_level if expected_results.any?
          visible_results = @cohort_page.visible_sids
          @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
        end
      end

      it "sorts by Major all the students who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        expected_results = @cohort_page.expected_sids_by_major(@searchable_students, cohort.search_criteria)
        if expected_results.length.zero?
          logger.warn 'Skipping sort-by-major test since there are no results'
        else
          @cohort_page.sort_by_major if expected_results.any?
          visible_results = @cohort_page.visible_sids
          @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
        end
      end

      it "sorts by Units all the students who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        expected_results = @cohort_page.expected_sids_by_units(@searchable_students, cohort.search_criteria)
        if expected_results.length.zero?
          logger.warn 'Skipping sort-by-units test since there are no results'
        else
          @cohort_page.sort_by_units if expected_results.any?
          visible_results = @cohort_page.visible_sids
          @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
        end
      end

      it "allows the advisor to create a cohort using '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        @cohort_page.create_new_cohort cohort
      end

      it "shows the filtered cohort on the homepage with criteria sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        @homepage.load_page
        @homepage.wait_until(Utils.medium_wait) { @homepage.filtered_cohorts.include? cohort.name }
      end

      it "shows the filtered cohort members who have alerts on the homepage with criteria sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        member_sids = @cohort_page.expected_sids_by_last_name(@searchable_students, cohort.search_criteria)
        @homepage.wait_until(Utils.short_wait) { @homepage.filtered_cohort_member_count(cohort) == member_sids.length }
        members = students.select { |u| member_sids.include? u.sis_id }
        @homepage.verify_cohort_alert_rows(@driver, cohort, members, advisor)
      end

      it "offers a link to the filtered cohort with criteria sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
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
      cohort = FilteredCohort.new({name: "#{test_id}#{'A loooooong title ' * 15}?"})
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
      cohorts << pre_existing_cohorts
      cohorts.flatten!
      # Account for My Students if the advisor is CoE
      my_students = cohorts.find &:read_only
      my_students.name = 'My Students' if my_students
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

    before(:all) do
      @cohort_to_delete = cohorts.find { |c| !c.read_only }
      @cohort_page.delete_cohort(cohorts, @cohort_to_delete)
    end

    it 'shows a Not Found page' do
      @cohort_page.navigate_to "#{BOACUtils.base_url}/cohort?c=#{@cohort_to_delete.id}"
      @cohort_page.wait_for_title '404'
    end
  end

end
