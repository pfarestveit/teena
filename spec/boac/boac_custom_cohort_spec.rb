require_relative '../../util/spec_helper'

describe 'BOAC custom cohorts', order: :defined do

  include Logging

  test_id = Utils.get_test_id
  test_user = User.new({:uid => Utils.super_admin_uid, :username => Utils.super_admin_username})

  # Get cohorts the test user already owns
  cohorts_pre_existing = BOACUtils.get_user_custom_cohorts test_user

  # Get cohorts to be created during tests
  test_search_criteria = BOACUtils.get_test_search_criteria
  cohorts_to_create = test_search_criteria.map { |criteria| Cohort.new({:name => "Test Cohort #{test_search_criteria.index criteria} #{test_id}", :search_criteria => criteria}) }
  cohorts_created = []

  before(:all) do
    @driver = Utils.launch_browser
    @homepage = Page::BOACPages::HomePage.new @driver
    @cohort_page = Page::BOACPages::CohortPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @homepage.dev_auth Utils.super_admin_uid
  end

  it('shows the user Everyone\'s Cohorts') { expect(@cohort_page.visible_everyone_cohorts @driver).to eql(BOACUtils.get_everyone_custom_cohorts) }

  it 'offers a link to the Intensive cohort' do
    intensive = Cohort.new({name: 'Intensive'})
    @homepage.click_intensive_cohort
    @cohort_page.cohort_heading(intensive).when_visible Utils.medium_wait
    expect(@cohort_page.player_link_elements.any?).to be true
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when a user has no cohorts' do

    before(:all) do
      cohorts_pre_existing.each { |c| @cohort_page.delete_cohort c }
      @homepage.click_cohorts
    end

    it('shows a No Saved Cohorts message in the header') { @homepage.no_cohorts_msg_element.when_visible Utils.short_wait }
    it('shows a No Saved Cohorts message on the homepage') { expect(@homepage.no_cohorts_msg?).to be true }
  end

  context 'when the user creates a cohort' do

    before(:each) do
      @homepage.click_create_new_cohort
      @cohort_page.teams_filter_button_element.when_visible Utils.short_wait
    end

    it('requires at least one search criterion') { expect(@cohort_page.search_button_element.attribute 'disabled').to eql('true') }

    test_search_criteria.each do |criteria|
      it "allows the user to search using '#{criteria.squads.map &:name}', levels '#{criteria.levels}', terms '#{criteria.terms}', GPA '#{criteria.gpa}', and units '#{criteria.units}'" do
        @cohort_page.perform_search criteria
        @cohort_page.verify_search_results(@driver, criteria)
      end
    end

    it 'requires a title' do
      @cohort_page.create_and_name_cohort Cohort.new({})
      @cohort_page.title_required_msg_element.when_visible Utils.short_wait
    end

    it('allows the user to cancel the cohort creation') { @cohort_page.cancel_cohort }

    it 'truncates a title over 255 characters' do
      cohort = Cohort.new({name: "#{'A loooooong title' * 15}?"})
      @cohort_page.create_and_name_cohort cohort
      cohort.name = cohort.name[0..254]
      @cohort_page.cohort_heading(cohort).when_visible Utils.short_wait
    end

    cohorts_to_create.each do |cohort|
      it "allows the user to create a cohort using '#{cohort.squads.map &:name}', levels '#{cohort.levels}', terms '#{cohort.terms}', GPA '#{cohort.gpa}', and units '#{cohort.units}'" do
        @cohort_page.create_new_cohort cohort
        cohorts_created << cohort
      end
    end

    it 'requires that a title be unique among the user\'s existing cohorts' do
      @cohort_page.create_and_name_cohort cohorts_to_create.first
      @cohort_page.title_dupe_msg_element.when_visible Utils.short_wait
    end
  end

  context 'when the user views its cohorts' do

    before(:each) { @homepage.load_page }

    it('shows my cohorts on the homepage') { expect(@homepage.my_saved_cohorts).to eql(cohorts_created.map &:name) }

    cohorts_created.each do |c|
      it "offers a link to the user's custom cohort '#{c.name}'" do
        @homepage.click_my_cohort c
        @cohort_page.cohort_heading(c).when_visible Utils.medium_wait
      end
    end
  end

  context 'when the user edits a cohort\'s search filters' do

    it 'creates a new cohort' do
      existing_cohort = cohorts_created.first
      new_cohort = Cohort.new({name: "Edited Search #{test_id}", search_criteria: cohorts_created.last.search_criteria})
      @cohort_page.create_edited_cohort(existing_cohort, new_cohort)
      expect(new_cohort.id).not_to eql(existing_cohort.id)
    end
  end

  context 'when the user edits a cohort\'s name' do

    it 'renames the existing cohort' do
      cohort = cohorts_created.first
      id = cohort.id
      cohort.name = "#{cohort.name} - Renamed"
      @cohort_page.rename_cohort cohort
      expect(cohort.id).to eql(id)
    end
  end

  context 'when the user deletes a cohort and tries to navigate to the deleted cohort' do

    before(:all) { @cohort_page.delete_cohort cohorts_created.first }

    it 'shows a Not Found page'do
      @cohort_page.load_cohort cohorts_created.first
      @cohort_page.cohort_not_found_msg_element.when_visible Utils.short_wait
    end
  end
end
