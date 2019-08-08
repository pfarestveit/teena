require_relative '../../util/spec_helper'

describe 'A BOA advisor' do

  include Logging

  before(:all) do
    @test = BOACTestConfig.new
    @test.user_role_advisor

    # Get ASC test data
    @test_asc = BOACTestConfig.new
    @test_asc.user_role_asc @test
    @asc_inactive_students = @test_asc.dept_students.reject &:active_asc
    @asc_test_student = (@asc_inactive_students.sort_by { |s| s.last_name }).first
    @asc_test_student_sports = @asc_test_student.sports.map { |squad_code| (Squad::SQUADS.find { |s| s.code == squad_code }).name }

    # Get CoE test data
    @test_coe = BOACTestConfig.new
    @test_coe.user_role_coe @test
    coe_inactive_student_data = @test.searchable_data.select { |s| s[:coe_inactive] }
    sorted = coe_inactive_student_data.sort_by { |s| s[:last_name_sortable_cohort] }
    @coe_test_student = @test_coe.dept_students.find { |s| s.sis_id == sorted.first[:sid] }

    # Get L&S test data
    @test_l_and_s = BOACTestConfig.new
    @test_l_and_s.user_role_l_and_s @test

    @driver = Utils.launch_browser @test.chrome_profile
    @homepage = BOACHomePage.new @driver
    @student_page = BOACStudentPage.new @driver
    @api_student_page = BOACApiStudentPage.new @driver
    @cohort_page = BOACFilteredCohortPage.new(@driver, @test_asc.advisor)
    @admin_page = BOACAdminPage.new @driver
    @api_admin_page = BOACApiAdminPage.new @driver
  end

  after(:all) { Utils.quit_browser @driver }

  context 'with ASC' do

    before(:all) { @homepage.dev_auth @test_asc.advisor }

    after(:all) do
      @homepage.load_page
      @homepage.log_out
    end

    context 'visiting Everyone\'s Cohorts' do

      it 'sees only filtered cohorts created by ASC advisors' do
        expected = BOACUtils.get_everyone_filtered_cohorts(BOACDepartments::ASC).map(&:id).sort
        visible = (@cohort_page.visible_everyone_cohorts.map &:id).sort
        @cohort_page.wait_until(1, "Missing: #{expected - visible}. Unexpected: #{visible - expected}") { visible == expected }
      end

      it 'cannot hit a non-ASC filtered cohort URL' do
        coe_everyone_cohorts = BOACUtils.get_everyone_filtered_cohorts BOACDepartments::COE
        coe_everyone_cohorts.any? ?
            @cohort_page.hit_non_auth_cohort(coe_everyone_cohorts.first) :
            logger.warn('Skipping test for ASC access to CoE cohorts because CoE has no cohorts.')
      end
    end

    context 'visiting a student page' do

      it 'sees team information' do
        @student_page.load_page @asc_test_student
        expect(@student_page.sports.sort).to eql(@asc_test_student_sports.sort)
      end

      it('sees ASC Inactive information') { expect(@student_page.inactive_flag?).to be true }

      it 'sees no COE Inactive information' do
        @student_page.load_page @coe_test_student
        expect(@student_page.inactive_flag?).to be false
      end
    end

    context 'visiting a student API page' do

      it 'cannot see COE profile data' do
        api_page = BOACApiStudentPage.new @driver
        api_page.get_data(@driver, @coe_test_student)
        api_page.coe_profile.each_value { |v| expect(v).to be_nil }
      end
    end

    context 'visiting a cohort page' do

      before(:all) do
        @inactive_search = CohortFilter.new
        @inactive_search.set_custom_filters({:asc_inactive => true})
        @inactive_cohort = FilteredCohort.new({:search_criteria => @inactive_search})

        @homepage.load_page
        @homepage.click_sidebar_create_filtered
        @cohort_page.click_new_filter_button
        @cohort_page.wait_until(1) { @cohort_page.new_filter_option_elements.any? &:visible? }
      end

      it('sees an Expected Graduation Term filter') { expect(@cohort_page.new_filter_option('expectedGradTerms').visible?).to be true }
      it('sees a GPA filter') { expect(@cohort_page.new_filter_option('gpaRanges').visible?).to be true }
      it('sees a Level filter') { expect(@cohort_page.new_filter_option('levels').visible?).to be true }
      it('sees a Major filter') { expect(@cohort_page.new_filter_option('majors').visible?).to be true }
      it('sees a Transfer Student filter') { expect(@cohort_page.new_filter_option('transfer').visible?).to be true }
      it('sees a Units Completed filter') { expect(@cohort_page.new_filter_option('unitRanges').visible?).to be true }

      it('sees an Ethnicity filter') { expect(@cohort_page.new_filter_option('ethnicities').visible?).to be true }
      it('sees a Gender filter') { expect(@cohort_page.new_filter_option('genders').visible?).to be true }
      it('sees an Underrepresented Minority filter') { expect(@cohort_page.new_filter_option('underrepresented')) }

      it('sees an Inactive filter') { expect(@cohort_page.new_filter_option('isInactiveAsc').visible?).to be true }
      it('sees an Intensive filter') { expect(@cohort_page.new_filter_option('inIntensiveCohort').visible?).to be true }
      it('sees a Team filter') { expect(@cohort_page.new_filter_option('groupCodes').visible?).to be true }

      it('sees a Last Name filter') { expect(@cohort_page.new_filter_option('lastNameRange').visible?).to be true }
      it('sees a My Students filter') { expect(@cohort_page.new_filter_option('cohortOwnerAcademicPlans').visible?).to be true }

      it('sees no Advisor filter') { expect(@cohort_page.new_filter_option('coeAdvisorLdapUids').exists?).to be false }
      it('sees no Ethnicity (COE) filter') { expect(@cohort_page.new_filter_option('coeEthnicities').exists?).to be false }
      it('sees no Gender (COE) filter') { expect(@cohort_page.new_filter_option('coeGenders').exists?).to be false }
      it('sees no Inactive (COE) filter') { expect(@cohort_page.new_filter_option('isInactiveCoe').exists?).to be false }
      it('sees no PREP filter') { expect(@cohort_page.new_filter_option('coePrepStatuses').exists?).to be false }
      it('sees no Probation filter') { expect(@cohort_page.new_filter_option('coeProbation').exists?).to be false }

      context 'with results' do

        before(:all) do
          @homepage.load_page
          @homepage.click_sidebar_create_filtered
          @cohort_page.perform_search @inactive_cohort
        end

        it('sees team information') { expect(@cohort_page.student_sports(@asc_test_student).sort).to eql(@asc_test_student_sports.sort) }
        it('sees ASC Inactive information') { expect(@cohort_page.student_inactive_flag? @asc_test_student).to be true }
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

      it('cannot download BOA user lists') { expect(@admin_page.download_users_button?).to be false }
      it('cannot see department advisor lists') { BOACDepartments::DEPARTMENTS.each { |d| expect(@admin_page.dept_tab_link_element(d).exists?).to be false } }
      it('cannot post status alerts') { expect(@admin_page.status_heading?).to be false }

      it 'cannot hit the cachejob page' do
        @api_admin_page.load_cachejob
        @api_admin_page.unauth_msg_element.when_visible Utils.medium_wait
      end
    end
  end

  context 'with CoE' do

    before(:all) { @homepage.dev_auth @test_coe.advisor }

    after(:all) do
      @homepage.load_page
      @homepage.log_out
    end

    context 'visiting Everyone\'s Cohorts' do

      it 'sees only filtered cohorts created by CoE advisors' do
        expected = BOACUtils.get_everyone_filtered_cohorts(BOACDepartments::COE).map(&:id).sort
        visible = (@cohort_page.visible_everyone_cohorts.map &:id).sort
        @cohort_page.wait_until(1, "Missing: #{expected - visible}. Unexpected: #{visible - expected}") { visible == expected }
      end

      it 'cannot hit a non-COE filtered cohort URL' do
        asc_cohorts = BOACUtils.get_everyone_filtered_cohorts BOACDepartments::ASC
        asc_cohorts.any? ?
            @cohort_page.hit_non_auth_cohort(asc_cohorts.first) :
            logger.warn('Skipping test for COE access to ASC cohorts because ASC has no cohorts.')
      end
    end

    context 'visiting a COE student page' do

      before(:all) { @student_page.load_page @coe_test_student }

      it('sees COE Inactive information') { expect(@student_page.inactive_flag?).to be true }
    end

    context 'visiting an ASC student page' do

      before(:all) { @student_page.load_page @asc_test_student }

      it('sees no team information') { expect(@student_page.sports).to be_empty }
      it('sees no ASC Inactive information') { expect(@student_page.inactive_flag?).to be false }
    end

    context 'visiting a student API page' do

      it 'cannot see ASC profile data on the student API page' do
        api_page = BOACApiStudentPage.new @driver
        api_page.get_data(@driver, @asc_test_student)
        expect(api_page.asc_profile).to be_nil
      end
    end

    context 'visiting a cohort page' do

      before(:all) do
        @inactive_search = CohortFilter.new
        @inactive_search.set_custom_filters({:asc_inactive => true})
        @inactive_cohort = FilteredCohort.new({:search_criteria => @inactive_search})

        @homepage.load_page
        @homepage.click_sidebar_create_filtered
        @cohort_page.click_new_filter_button
        @cohort_page.wait_until(1) { @cohort_page.new_filter_option_elements.any? &:visible? }
      end

      it('sees an Expected Graduation Term filter') { expect(@cohort_page.new_filter_option('expectedGradTerms').visible?).to be true }
      it('sees a GPA filter') { expect(@cohort_page.new_filter_option('gpaRanges').visible?).to be true }
      it('sees a Level filter') { expect(@cohort_page.new_filter_option('levels').visible?).to be true }
      it('sees a Major filter') { expect(@cohort_page.new_filter_option('majors').visible?).to be true }
      it('sees a Transfer Student filter') { expect(@cohort_page.new_filter_option('transfer').visible?).to be true }
      it('sees a Units filter') { expect(@cohort_page.new_filter_option('unitRanges').visible?).to be true }

      it('sees an Ethnicity filter') { expect(@cohort_page.new_filter_option('ethnicities').visible?).to be true }
      it('sees a Gender filter') { expect(@cohort_page.new_filter_option('genders').visible?).to be true }
      it('sees an Underrepresented Minority filter') { expect(@cohort_page.new_filter_option('underrepresented')) }

      it('sees no Inactive (ASC) filter') { expect(@cohort_page.new_filter_option('isInactiveAsc').visible?).to be false }
      it('sees no Intensive filter') { expect(@cohort_page.new_filter_option('inIntensiveCohort').visible?).to be false }
      it('sees no Team filter') { expect(@cohort_page.new_filter_option('groupCodes').visible?).to be false }

      it('sees a Last Name filter') { expect(@cohort_page.new_filter_option('lastNameRange').visible?).to be true }
      it('sees a My Students filter') { expect(@cohort_page.new_filter_option('cohortOwnerAcademicPlans').visible?).to be true }

      it('sees an Advisor filter') { expect(@cohort_page.new_filter_option('coeAdvisorLdapUids').visible?).to be true }
      it('sees an Ethnicity (COE) filter') { expect(@cohort_page.new_filter_option('coeEthnicities').visible?).to be true }
      it('sees a Gender (COE) filter') { expect(@cohort_page.new_filter_option('coeGenders').visible?).to be true }
      it('sees an Inactive COE filter') { expect(@cohort_page.new_filter_option('isInactiveCoe').exists?).to be true }
      it('sees a PREP filter') { expect(@cohort_page.new_filter_option('coePrepStatuses').visible?).to be true }
      it('sees a Probation filter') { expect(@cohort_page.new_filter_option('coeProbation').exists?).to be true }
      it('sees an Underrepresented Minority (COE) filter') { expect(@cohort_page.new_filter_option('coeUnderrepresented').exists?).to be true }
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

      it('cannot download BOA user lists') { expect(@admin_page.download_users_button?).to be false }
      it('cannot see department advisor lists') { BOACDepartments::DEPARTMENTS.each { |dept| expect(@admin_page.dept_tab_link_element(dept).exists?).to be false } }
      it('cannot post status alerts') { expect(@admin_page.status_heading?).to be false }

      it 'cannot hit the cachejob page' do
        @api_admin_page.load_cachejob
        @api_admin_page.unauth_msg_element.when_visible Utils.medium_wait
      end
    end
  end

  context 'with a department other than ASC or COE' do

    before(:all) { @homepage.dev_auth @test_l_and_s.advisor }

    after(:all) do
      @homepage.load_page
      @homepage.log_out
    end

    context 'visiting Everyone\'s Cohorts' do

      it 'sees only filtered cohorts created by advisors in its own department' do
        expected = BOACUtils.get_everyone_filtered_cohorts(BOACDepartments::L_AND_S).map(&:id).sort
        visible = (@cohort_page.visible_everyone_cohorts.map &:id).sort
        @cohort_page.wait_until(1, "Missing: #{expected - visible}. Unexpected: #{visible - expected}") { visible == expected }
      end
    end

    context 'visiting an ASC student page' do

      before(:all) { @student_page.load_page @asc_test_student }

      it('sees no team information') { expect(@student_page.sports).to be_empty }
      it('sees no ASC Inactive information') { expect(@student_page.inactive_flag?).to be false }
    end

    context 'visiting a COE student page' do

      before(:all) { @student_page.load_page @coe_test_student }

      it('sees no COE Inactive information') { expect(@student_page.inactive_flag?).to be false }
    end

    context 'visiting a student API page' do

      it 'cannot see ASC profile data on the student API page' do
        api_page = BOACApiStudentPage.new @driver
        api_page.get_data(@driver, @asc_test_student)
        expect(api_page.asc_profile).to be_nil
      end

      it 'cannot see COE profile data on the student API page' do
        api_page = BOACApiStudentPage.new @driver
        api_page.get_data(@driver, @coe_test_student)
        api_page.coe_profile.each_value { |v| expect(v).to be_nil }
      end
    end

    context 'performing a filtered cohort search' do

      before(:all) do
        @homepage.load_page
        @homepage.click_sidebar_create_filtered
        @cohort_page.wait_for_update_and_click @cohort_page.new_filter_button_element
        @cohort_page.wait_until(1) { @cohort_page.new_filter_option_elements.any? &:visible? }
      end

      it('sees an Expected Graduation Term filter') { expect(@cohort_page.new_filter_option('expectedGradTerms').visible?).to be true }
      it('sees a GPA filter') { expect(@cohort_page.new_filter_option('gpaRanges').visible?).to be true }
      it('sees a Level filter') { expect(@cohort_page.new_filter_option('levels').visible?).to be true }
      it('sees a Major filter') { expect(@cohort_page.new_filter_option('majors').visible?).to be true }
      it('sees a Transfer Student filter') { expect(@cohort_page.new_filter_option('transfer').visible?).to be true }
      it('sees a Units Completed filter') { expect(@cohort_page.new_filter_option('unitRanges').visible?).to be true }

      it('sees an Ethnicity filter') { expect(@cohort_page.new_filter_option('ethnicities').visible?).to be true }
      it('sees a Gender filter') { expect(@cohort_page.new_filter_option('genders').visible?).to be true }
      it('sees an Underrepresented Minority filter') { expect(@cohort_page.new_filter_option('underrepresented')) }

      it('sees no Inactive (ASC) filter') { expect(@cohort_page.new_filter_option('isInactiveAsc').visible?).to be false }
      it('sees no Intensive filter') { expect(@cohort_page.new_filter_option('inIntensiveCohort').visible?).to be false }
      it('sees no Team filter') { expect(@cohort_page.new_filter_option('groupCodes').visible?).to be false }

      it('sees a Last Name filter') { expect(@cohort_page.new_filter_option('lastNameRange').visible?).to be true }
      it('sees a My Students filter') { expect(@cohort_page.new_filter_option('cohortOwnerAcademicPlans').visible?).to be true }

      it('sees no Advisor filter') { expect(@cohort_page.new_filter_option('coeAdvisorLdapUids').exists?).to be false }
      it('sees no Ethnicity (COE) filter') { expect(@cohort_page.new_filter_option('coeEthnicities').exists?).to be false }
      it('sees no Gender (COE) filter') { expect(@cohort_page.new_filter_option('coeGenders').exists?).to be false }
      it('sees no Inactive (COE) filter') { expect(@cohort_page.new_filter_option('isInactiveCoe').exists?).to be false }
      it('sees no PREP filter') { expect(@cohort_page.new_filter_option('coePrepStatuses').exists?).to be false }
      it('sees no Probation filter') { expect(@cohort_page.new_filter_option('coeProbation').exists?).to be false }
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

      it('cannot download BOA user lists') { expect(@admin_page.download_users_button?).to be false }
      it('cannot see department advisor lists') { BOACDepartments::DEPARTMENTS.each { |dept| expect(@admin_page.dept_tab_link_element(dept).exists?).to be false } }
      it('cannot post status alerts') { expect(@admin_page.status_heading?).to be false }

      it 'cannot hit the cachejob page' do
        @api_admin_page.load_cachejob
        @api_admin_page.unauth_msg_element.when_visible Utils.medium_wait
      end
    end
  end
end