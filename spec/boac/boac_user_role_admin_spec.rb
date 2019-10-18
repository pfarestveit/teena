require_relative '../../util/spec_helper'

describe 'An admin using BOAC' do

  include Logging

  test = BOACTestConfig.new
  test.user_role_admin

  non_admin_depts = BOACDepartments::DEPARTMENTS.reject { |d| d == BOACDepartments::ADMIN }

  everyone_cohorts = BOACUtils.get_everyone_filtered_cohorts
  everyone_groups = BOACUtils.get_everyone_curated_groups

  before(:all) do
    @service_announcement = "#{BOACUtils.config['service_announcement']} " * 15
    @driver = Utils.launch_browser test.chrome_profile
    @admin_page = BOACFlightDeckPage.new @driver
    @api_admin_page = BOACApiAdminPage.new @driver
    @api_section_page = BOACApiSectionPage.new @driver
    @api_student_page = BOACApiStudentPage.new @driver
    @class_page = BOACClassListViewPage.new @driver
    @curated_group_page = BOACGroupPage.new @driver
    @filtered_cohort_page = BOACFilteredCohortPage.new(@driver, test.advisor)
    @homepage = BOACHomePage.new @driver
    @search_page = BOACSearchResultsPage.new @driver
    @student_page = BOACStudentPage.new @driver

    @homepage.dev_auth test.advisor
  end

  after(:all) { Utils.quit_browser @driver }

  context 'visiting Everyone\'s Cohorts' do

    before(:all) do
      @homepage.load_page
      @homepage.click_view_everyone_cohorts
    end

    it 'sees all filtered cohorts' do
      expected_cohort_names = everyone_cohorts.map(&:name).sort
      visible_cohort_names = (@filtered_cohort_page.visible_everyone_cohorts.map &:name).sort
      @filtered_cohort_page.wait_until(1, "Expected #{expected_cohort_names}, but got #{visible_cohort_names}") { visible_cohort_names == expected_cohort_names }
    end
  end

  context 'visiting Everyone\'s Groups' do

    before(:all) do
      @homepage.load_page
      @homepage.click_view_everyone_groups
    end

    it 'sees all curated groups' do
      expected_group_names = everyone_groups.map(&:name).sort
      visible_group_names = (@curated_group_page.visible_everyone_groups.map &:name).sort
      @curated_group_page.wait_until(1, "Expected #{expected_group_names}, but got #{visible_group_names}") { visible_group_names == expected_group_names }
    end
  end

  context 'performing a filtered cohort search' do

    before(:all) do
      @homepage.click_sidebar_create_filtered
      @filtered_cohort_page.wait_for_update_and_click @filtered_cohort_page.new_filter_button_element
      @filtered_cohort_page.wait_until(1) { @filtered_cohort_page.new_filter_option_elements.any? &:visible? }
    end

    it('sees a Level filter') { expect(@filtered_cohort_page.new_filter_option('levels').visible?).to be true }
    it('sees a Major filter') { expect(@filtered_cohort_page.new_filter_option('majors').visible?).to be true }
    it('sees a Units filter') { expect(@filtered_cohort_page.new_filter_option('unitRanges').visible?).to be true }
    it('sees a Last Name filter') { expect(@filtered_cohort_page.new_filter_option('lastNameRanges').visible?).to be true }
    it('sees a Transfer Student filter') { expect(@filtered_cohort_page.new_filter_option('transfer').visible?).to be true }
    it('sees an Entering Term filter') { expect(@filtered_cohort_page.new_filter_option('enteringTerms').visible?).to be true }
    it('sees an Expected Graduation Term filter') { expect(@filtered_cohort_page.new_filter_option('expectedGradTerms').visible?).to be true }
    it('sees a Gender filter') { expect(@filtered_cohort_page.new_filter_option('genders').visible?).to be true }
    it('sees a Advisor filter') { expect(@filtered_cohort_page.new_filter_option('coeAdvisorLdapUids').visible?).to be true }
    it('sees a \'Ethnicity (COE)\' filter') { expect(@filtered_cohort_page.new_filter_option('coeEthnicities').visible?).to be true }
    it('sees a \'Gender (COE)\' filter') { expect(@filtered_cohort_page.new_filter_option('coeGenders').visible?).to be true }
    it('sees a PREP filter') { expect(@filtered_cohort_page.new_filter_option('coePrepStatuses').visible?).to be true }
    it('sees an Inactive COE filter') { expect(@filtered_cohort_page.new_filter_option('isInactiveCoe').visible?).to be true }
    it('sees a Probation filter') { expect(@filtered_cohort_page.new_filter_option('coeProbation').visible?).to be true }
    it('sees an Inactive ASC filter') { expect(@filtered_cohort_page.new_filter_option('isInactiveAsc').visible?).to be true }
    it('sees an Intensive filter') { expect(@filtered_cohort_page.new_filter_option('inIntensiveCohort').visible?).to be true }
    it('sees a Team filter') { expect(@filtered_cohort_page.new_filter_option('groupCodes').visible?).to be true }
  end

  context 'visiting student API pages' do

    it 'can see the ASC profile data for an ASC student on the student API page' do
      asc_student_data = test.searchable_data.find { |s| s[:asc_sports].any? }
      asc_student = test.students.find { |s| s.sis_id == asc_student_data[:sid] }
      @api_student_page.get_data(@driver, asc_student)
      expect(@api_student_page.asc_profile).not_to be_nil
    end

    it 'can see the CoE profile data for a CoE student on the student API page' do
      coe_student_data = test.searchable_data.find { |s| s[:coe_gender] == 'F' }
      coe_student = test.students.find { |s| s.sis_id == coe_student_data[:sid] }
      @api_student_page.get_data(@driver, coe_student)
      expect(@api_student_page.coe_profile).not_to be_nil
    end
  end

  context 'visiting the admin page' do

    it 'sees a link to the admin page' do
      @homepage.load_page
      @homepage.click_flight_deck_link
    end

    # TODO - it('can authenticate as one of the authorized users')

    it 'can un-post a service alert' do
      @admin_page.unpost_service_announcement
      expect(@admin_page.service_announcement_banner?).to be false
    end

    it 'can post a service alert' do
      @admin_page.update_service_announcement @service_announcement
      @admin_page.post_service_announcement
      expect(@admin_page.service_announcement_banner).to eql @service_announcement
    end

    it 'can update a posted service alert' do
      @service_announcement = "UPDATE - #{@service_announcement}"
      @admin_page.update_service_announcement @service_announcement
      @admin_page.wait_until(Utils.short_wait) { @admin_page.service_announcement_banner == @service_announcement }
    end
  end

end
