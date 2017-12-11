require_relative '../../util/spec_helper'

describe 'BOAC custom cohorts' do

  include Logging

  admin = User.new({:uid => Utils.super_admin_uid, :username => Utils.super_admin_username})
  initial_cohort_names = BOACUtils.get_user_custom_cohorts admin
  initial_cohorts = initial_cohort_names.map { |c| Cohort.new({:name => c}) }

  before(:all) do
    @driver = Utils.launch_browser
    @homepage = Page::BOACPages::HomePage.new @driver
    @cohort_page = Page::BOACPages::CohortPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @homepage.log_in(admin.username, Utils.super_admin_password, @cal_net)
  end

  after(:all) { Utils.quit_browser @driver }

  it('shows my cohorts on the homepage') { expect(@homepage.my_saved_cohorts).to eql(initial_cohorts.map &:name) }

  context 'when the user views its existing cohorts' do

    before(:each) { @homepage.click_cohorts }

    initial_cohorts.each do |c|
      it "offers a link to the user's custom cohort '#{c}'" do
        logger.debug "Checking custom cohort '#{c.name}'"
        @homepage.click_my_cohort c
        @cohort_page.cohort_heading(c).when_visible Utils.medium_wait
      end
    end

    it 'offers a link to the Intesive cohort' do
      intensive = Cohort.new({name: 'Intensive'})
      @homepage.wait_for_update_and_click @homepage.intensive_cohort_link_element
      @cohort_page.cohort_heading(intensive).when_visible Utils.medium_wait
      expect(@cohort_page.player_link_elements.any?).to be true
    end
  end

  context 'when the user performs a cohort search' do

    before(:each) do
      @homepage.click_cohorts
      @homepage.click_create_new_cohort
      @cohort_page.teams_filter_button_element.when_visible Utils.short_wait
    end

    it 'requires at least one search criterion' do
      expect(@cohort_page.search_button_element.attribute 'disabled').to eql('true')
    end

    BOACUtils.get_test_search_criteria.each do |search|
      it 'allows the user to search for one or more teams' do
        @cohort_page.perform_search search
        @cohort_page.verify_search_results(@driver, search)
      end
    end

  end
end
