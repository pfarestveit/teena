require_relative '../../util/spec_helper'

describe 'A Physics advisor using BOAC' do

  include Logging

  all_students = NessieUtils.get_all_students

  test_asc = BOACTestConfig.new
  test_asc.user_role_asc all_students

  test_coe = BOACTestConfig.new
  test_coe.user_role_coe all_students

  test_physics = BOACTestConfig.new
  test_physics.user_role_physics all_students

  overlap_students = ((test_asc.dept_students & test_physics.dept_students) + (test_coe.dept_students & test_physics.dept_students)).uniq
  coe_only_students = test_coe.dept_students - overlap_students

  before(:all) do
    @driver = Utils.launch_browser test_asc.chrome_profile
    @admin_page = BOACAdminPage.new @driver
    @api_admin_page = BOACApiAdminPage.new @driver
    @api_section_page = BOACApiSectionPage.new @driver
    @api_user_analytics_page = BOACApiStudentPage.new @driver
    @class_page = BOACClassListViewPage.new @driver
    @filtered_cohort_page = BOACFilteredCohortPage.new @driver
    @homepage = BOACHomePage.new @driver
    @search_page = BOACSearchResultsPage.new @driver
    @student_page = BOACStudentPage.new @driver

    @homepage.dev_auth test_physics.advisor
  end

  after(:all) { Utils.quit_browser @driver }

  context 'performing a filtered cohort search' do

    before(:all) do
      @homepage.click_sidebar_create_filtered
      @filtered_cohort_page.wait_for_update_and_click @filtered_cohort_page.new_filter_button_element
      @filtered_cohort_page.wait_until(1) { @filtered_cohort_page.new_filter_option_elements.any? &:visible? }
    end

    it('sees a GPA filter') { expect(@filtered_cohort_page.new_filter_option('GPA').visible?).to be true }
    it('sees a Level filter') { expect(@filtered_cohort_page.new_filter_option('Level').visible?).to be true }
    it('sees a Major filter') { expect(@filtered_cohort_page.new_filter_option('Major').visible?).to be true }
    it('sees a Units filter') { expect(@filtered_cohort_page.new_filter_option('Units Completed').visible?).to be true }
    it('sees a Last Name filter') { expect(@filtered_cohort_page.new_filter_option('Last Name').visible?).to be true }
    it('sees no Advisor filter') { expect(@filtered_cohort_page.new_filter_option('Advisor').exists?).to be false }
    it('sees no Ethnicity filter') { expect(@filtered_cohort_page.new_filter_option('Ethnicity').exists?).to be false }
    it('sees no Gender filter') { expect(@filtered_cohort_page.new_filter_option('Gender').exists?).to be false }
    it('sees no PREP filter') { expect(@filtered_cohort_page.new_filter_option('PREP').exists?).to be false }
    it('sees no Inactive filter') { expect(@filtered_cohort_page.new_filter_option('Inactive').visible?).to be false }
    it('sees no Intensive filter') { expect(@filtered_cohort_page.new_filter_option('Intensive').visible?).to be false }
    it('sees no Team filter') { expect(@filtered_cohort_page.new_filter_option('Team').visible?).to be false }
  end

  context 'visiting Everyone\'s Cohorts' do

    it 'sees only filtered cohorts created by Physics advisors' do
      expected_cohort_names = BOACUtils.get_everyone_filtered_cohorts(BOACDepartments::PHYSICS).map(&:id).sort
      visible_cohort_names = (@filtered_cohort_page.visible_everyone_cohorts.map &:id).sort
      @filtered_cohort_page.wait_until(1, "Expected but not present: #{expected_cohort_names - visible_cohort_names}. Present but not expected: #{visible_cohort_names - expected_cohort_names}") do
        visible_cohort_names == expected_cohort_names
      end
    end

    it 'cannot hit a non-Physics filtered cohort URL' do
      coe_everyone_cohorts = BOACUtils.get_everyone_filtered_cohorts BOACDepartments::COE
      coe_everyone_cohorts.any? ?
          @filtered_cohort_page.hit_non_auth_cohort(coe_everyone_cohorts.first) :
          logger.warn('Skipping test for Physics access to CoE cohorts because CoE has no cohorts.')
    end
  end

  context 'performing a user search' do

    it 'sees no non-Physics students in search results' do
      @search_page.search_non_note coe_only_students.first.sis_id
      @search_page.no_results_msg.when_visible Utils.short_wait
    end

    it 'sees overlapping Physics and ASC / CoE students in search results' do
      if overlap_students.first
        @search_page.search_non_note overlap_students.first.sis_id
        expect(@search_page.student_search_results_count).to eql(1)
      else
        logger.warn 'Skipping search for overlapping students cuz there ain\'t none'
      end
    end
  end

  context 'visiting a class page' do

    it 'sees only Physics student data in a section endpoint' do
      api_section_page = BOACApiSectionPage.new @driver
      api_section_page.get_data(@driver, '2178', '13826')
      expect(test_physics.dept_students.map(&:sis_id).sort & api_section_page.student_sids).to eql(api_section_page.student_sids.sort)
    end
  end

  context 'visiting a student page' do

    it 'cannot hit a non-ASC student page' do
      @student_page.navigate_to "#{BOACUtils.base_url}#{@homepage.path_to_student_view(coe_only_students.first.uid)}"
      @student_page.wait_for_title 'Page not found'
    end

    it 'can hit an overlapping Physics and ASC / CoE student page' do
      @student_page.load_page overlap_students.first
      @student_page.student_name_heading_element.when_visible Utils.medium_wait
      expect(@student_page.visible_sis_data[:name]).to eql(overlap_students.first.full_name.split(',').reverse.join(' ').strip)
    end

    it('cannot hit the user analytics endpoint for a non-ASC student') do
      expect(@api_user_analytics_page.get_data(@driver, coe_only_students.first)).to be_nil
    end
  end

  context 'looking for admin functions' do

    it 'can load the admin page' do
      @homepage.load_page
      @homepage.click_header_dropdown
      expect(@homepage.admin_link?).to be true
    end

    it 'can toggle demo mode' do
      @admin_page.load_page
      @admin_page.demo_mode_toggle_element.when_present Utils.short_wait
    end

    it 'can see no other admin functions' do
      BOACDepartments::DEPARTMENTS.each { |dept| expect(@admin_page.dept_tab_link_element(dept).exists?).to be false }
      expect(@admin_page.status_heading?).to be false
    end

    it 'cannot hit the cachejob page' do
      @api_admin_page.load_cachejob
      @api_admin_page.unauth_msg_element.when_visible Utils.medium_wait
    end
  end
end
