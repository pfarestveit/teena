require_relative '../../util/spec_helper'

describe 'An admin using BOAC' do

  include Logging

  test = BOACTestConfig.new
  test.user_role_admin

  coe_only_students = test.students.select { |s| s.depts == [BOACDepartments::COE] }
  asc_only_students = test.students.select { |s| s.depts == [BOACDepartments::ASC] }

  non_admin_depts = BOACDepartments::DEPARTMENTS.reject { |d| d == BOACDepartments::ADMIN }
  dept_advisors = non_admin_depts.map { |dept| {:dept => dept, :advisors => BOACUtils.get_dept_advisors(dept)} }

  everyone_cohorts = BOACUtils.get_everyone_filtered_cohorts
  everyone_groups = BOACUtils.get_everyone_curated_groups

  before(:all) do
    @service_announcement = BOACUtils.config['service_announcement']
    @driver = Utils.launch_browser test.chrome_profile
    @admin_page = BOACAdminPage.new @driver
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
    it('sees a Last Name filter') { expect(@filtered_cohort_page.new_filter_option('lastNameRange').visible?).to be true }
    it('sees a Transfer Student filter') { expect(@filtered_cohort_page.new_filter_option('transfer').visible?).to be true }
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

  context 'visiting a class page' do

    it 'sees all students in a section endpoint' do
      @api_section_page.get_data(@driver, '2178', '13826')
      expect(asc_only_students.map(&:sis_id) & @api_section_page.student_sids).not_to be_empty
      expect(coe_only_students.map(&:sis_id) & @api_section_page.student_sids).not_to be_empty
    end
  end

  context 'visiting student API pages' do

    it 'can see the ASC profile data for an ASC student on the student API page' do
      @api_student_page.get_data(@driver, asc_only_students.first)
      expect(@api_student_page.asc_profile).not_to be_nil
    end

    it 'can see the CoE profile data for a CoE student on the student API page' do
      @api_student_page.get_data(@driver, coe_only_students.first)
      expect(@api_student_page.coe_profile).not_to be_nil
    end
  end

  context 'visiting the admin page' do

    it 'sees a link to the admin page' do
      @homepage.load_page
      @homepage.click_admin_link
    end

    it 'sees all departments in \'Users\' section' do
      @admin_page.load_page
      @admin_page.dept_users_section_element.when_present Utils.medium_wait
      dept_advisors.each do |dept|
        expect(@admin_page.dept_tab_link_element(dept[:dept]).exists?).to be true
        dept[:advisors].each { |advisor| expect(@admin_page.become_user_link_element(advisor).exists?).to be true }
      end
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

  context 'exporting all BOA users' do

    before(:all) { @csv = @admin_page.download_boa_users }

    dept_advisors.each do |dept|
      it "can export all #{dept[:dept].name} users" do
        dept_user_uids = dept[:advisors].map &:uid
        csv_dept_user_uids = @csv.map do |r|
          if r[:dept_code] == dept[:dept].code && r[:dept_name] == dept[:dept].name
            r[:uid].to_s
          end
        end
        logger.debug "Unexpected advisors: #{csv_dept_user_uids.compact - dept_user_uids}"
        logger.debug "Missing advisors: #{dept_user_uids - csv_dept_user_uids.compact}"
        expect(csv_dept_user_uids.compact.sort).to eql(dept_user_uids.sort)
      end
    end

    it 'can generate valid data' do
      @csv.each do |r|
        unless r[:dept_code] == 'NOTESONLY'
          expect(r[:last_name]).not_to be_empty
          expect(r[:first_name]).not_to be_empty
          expect(r[:email].downcase).to include('berkeley.edu')
        end
      end
    end

  end
end
