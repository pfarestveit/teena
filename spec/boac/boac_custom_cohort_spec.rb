require_relative '../../util/spec_helper'

describe 'BOAC custom cohorts', order: :defined do

  include Logging

  test_id = Utils.get_test_id
  test_user = User.new({:uid => Utils.super_admin_uid, :username => Utils.super_admin_username})

  # Get all existing cohorts
  user_cohorts_pre_existing = BOACUtils.get_user_custom_cohorts test_user
  everyone_cohorts_pre_existing = BOACUtils.get_everyone_custom_cohorts

  # Get cohorts to be created during tests
  test_search_criteria = BOACUtils.get_test_search_criteria
  cohorts_to_create = test_search_criteria.map { |criteria| Cohort.new({:name => "Test Cohort #{test_search_criteria.index criteria} #{test_id}", :search_criteria => criteria}) }
  cohorts_created = []

  before(:all) do
    @driver = Utils.launch_browser
    @analytics_page = ApiUserAnalyticsPage.new @driver
    @homepage = Page::BOACPages::HomePage.new @driver
    @cohort_page = Page::BOACPages::CohortListViewPage.new @driver
    @homepage.dev_auth Utils.super_admin_uid

    # Get the user data relevant to all search filters
    @user_data = @analytics_page.collect_users_searchable_data(@driver)

    # Get the current 'everyone' cohorts
    @homepage.load_page
    @visible_everyone_cohorts = @cohort_page.visible_everyone_cohorts
  end

  after(:all) { Utils.quit_browser @driver }

  it 'shows the user Everyone\'s Cohorts' do
    if @visible_everyone_cohorts.any?
      expected_cohort_names = (everyone_cohorts_pre_existing.map &:name).sort
      visible_cohort_names = (@visible_everyone_cohorts.map &:name).sort
      @cohort_page.wait_until(1, "Expected #{expected_cohort_names}, but got #{visible_cohort_names}") { visible_cohort_names == expected_cohort_names }
    else
      logger.warn 'No cohorts exist, cannot test Everyone\'s Cohorts'
    end
  end

  it 'offers a link to the Intensive cohort' do
    intensive = Cohort.new({name: 'Intensive'})
    @homepage.click_intensive_cohort
    @cohort_page.cohort_heading(intensive).when_visible Utils.medium_wait
    expect(@cohort_page.player_link_elements.any?).to be true
  end

  context 'when a user has no cohorts' do

    before(:all) do
      user_cohorts_pre_existing.each { |c| @cohort_page.delete_cohort c }
      @homepage.load_page
      @homepage.click_cohorts
    end

    it('shows a No Saved Cohorts message in the header') { @homepage.no_cohorts_msg_element.when_visible Utils.short_wait }
    it('shows a No Saved Cohorts message on the homepage') { expect(@homepage.you_have_no_cohorts_msg?).to be true }
  end

  context 'search' do

    before(:each) { @cohort_page.cancel_cohort if @cohort_page.cancel_cohort_button? }

    cohorts_to_create.each do |cohort|
      it "shows all the users who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        @homepage.load_page
        @cohort_page.click_create_new_cohort
        @cohort_page.perform_search cohort
        expected_results = @cohort_page.expected_search_results(@user_data, cohort.search_criteria).map { |u| u[:sid] }
        visible_results = @cohort_page.visible_search_results
        @cohort_page.wait_until(1, "Expected #{expected_results.sort} but got #{visible_results.sort}") { visible_results.sort == expected_results.sort }
      end

      it "shows by First Name all the users who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        expected_results = @cohort_page.expected_results_by_first_name(@user_data, cohort.search_criteria)
        visible_results = @cohort_page.visible_search_results
        @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
      end

      it "sorts by Last Name all the users who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        expected_results = @cohort_page.expected_results_by_last_name(@user_data, cohort.search_criteria)
        @cohort_page.sort_by_last_name if expected_results.any?
        visible_results = @cohort_page.visible_search_results
        @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
      end

      it "sorts by Team all the users who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        expected_results = @cohort_page.expected_results_by_team(@user_data, cohort.search_criteria)
        @cohort_page.sort_by_team if expected_results.any?
        visible_results = @cohort_page.visible_search_results
        @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
      end

      it "sorts by GPA all the users who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        expected_results = @cohort_page.expected_results_by_gpa(@user_data, cohort.search_criteria)
        @cohort_page.sort_by_gpa if expected_results.any?
        visible_results = @cohort_page.visible_search_results
        @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
      end

      it "sorts by Level all the users who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        expected_results = @cohort_page.expected_results_by_level(@user_data, cohort.search_criteria)
        @cohort_page.sort_by_level if expected_results.any?
        visible_results = @cohort_page.visible_search_results
        @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
      end

      it "sorts by Major all the users who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        expected_results = @cohort_page.expected_results_by_major(@user_data, cohort.search_criteria)
        @cohort_page.sort_by_major if expected_results.any?
        visible_results = @cohort_page.visible_search_results
        @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
      end

      it "sorts by Units all the users who match sports '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        expected_results = @cohort_page.expected_results_by_units(@user_data, cohort.search_criteria)
        @cohort_page.sort_by_units if expected_results.any?
        visible_results = @cohort_page.visible_search_results
        @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
      end

    end

    cohorts_to_create.each do |cohort|
      it "allows the user to create a cohort using '#{cohort.search_criteria.squads && (cohort.search_criteria.squads.map &:name)}', levels '#{cohort.search_criteria.levels}', majors '#{cohort.search_criteria.majors}', GPA ranges '#{cohort.search_criteria.gpa_ranges}', units '#{cohort.search_criteria.units}'" do
        @cohort_page.click_create_new_cohort
        @cohort_page.perform_search cohort
        unless cohort.member_count.zero?
          @cohort_page.create_new_cohort cohort
          cohorts_created << cohort
        end
      end
    end

    it 'requires a title' do
      @homepage.click_create_new_cohort
      @cohort_page.perform_search cohorts_created.first
      @cohort_page.click_save_cohort_button_one
      expect(@cohort_page.save_cohort_button_two_element.disabled?).to be true
    end

    it 'truncates a title over 255 characters' do
      cohort = Cohort.new({name: "#{'A loooooong title' * 15}?"})
      @homepage.click_create_new_cohort
      @cohort_page.perform_search cohorts_created.first
      @cohort_page.save_and_name_cohort cohort
      cohort.name = cohort.name[0..254]
      @cohort_page.wait_for_cohort cohort
      cohorts_created << cohort
    end

    it 'requires that a title be unique among the user\'s existing cohorts' do
      cohort = Cohort.new({name: cohorts_created.last.name})
      @cohort_page.save_and_name_cohort cohort
      @cohort_page.title_dupe_msg_element.when_visible Utils.short_wait
    end
  end

  context 'when the user views its cohorts' do

    before(:each) { @homepage.load_page }

    cohorts_created.each do |c|
      it "offers a link to the user's custom cohort '#{c.name}'" do
        @homepage.click_my_cohort c
        @cohort_page.cohort_heading(c).when_visible Utils.medium_wait
      end
    end

    it('shows only my cohorts on the homepage') do
      @homepage.load_page
      @homepage.wait_until(Utils.short_wait) { @homepage.my_saved_cohorts.any? }
      expect(@homepage.my_saved_cohorts.sort).to eql((cohorts_created.map &:name).sort)
    end
  end

  context 'when the user edits a cohort\'s search filters' do

    it 'creates a new cohort' do
      existing_cohort = cohorts_created.first
      new_cohort = Cohort.new({name: "Edited Search #{test_id}", search_criteria: test_search_criteria.last})
      @cohort_page.load_cohort existing_cohort
      @cohort_page.search_and_create_edited_cohort(existing_cohort, new_cohort)
      expect(new_cohort.id).not_to eql(existing_cohort.id)
    end
  end

  context 'when the user edits a cohort\'s name' do

    it 'renames the existing cohort' do
      cohort = cohorts_created.first
      id = cohort.id
      @cohort_page.click_manage_my_cohorts
      @cohort_page.rename_cohort(cohort, "#{cohort.name} - Renamed")
      expect(cohort.id).to eql(id)
    end
  end

  context 'when the user deletes a cohort and tries to navigate to the deleted cohort' do

    before(:all) { @cohort_page.delete_cohort cohorts_created.last }

    it 'shows a Not Found page'do
      @cohort_page.load_cohort cohorts_created.last
      @cohort_page.cohort_not_found_msg_element.when_visible Utils.medium_wait
    end
  end
end
