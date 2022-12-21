require_relative '../../util/spec_helper'

unless ENV['NO_DEPS']

  describe 'An admin using BOAC' do

    include Logging

    test = BOACTestConfig.new
    test.user_role_admin

    everyone_cohorts = BOACUtils.get_everyone_filtered_cohorts
    everyone_groups = BOACUtils.get_everyone_curated_groups
    ce3_cohorts = BOACUtils.get_everyone_filtered_cohorts({admits: true}, BOACDepartments::ZCEEE)

    before(:all) do
      @service_announcement = "#{BOACUtils.config['service_announcement']} " * 15
      @driver = Utils.launch_browser test.chrome_profile
      @admin_page = BOACFlightDeckPage.new @driver
      @api_admin_page = BOACApiAdminPage.new @driver
      @api_section_page = BOACApiSectionPage.new @driver
      @api_student_page = BOACApiStudentPage.new @driver
      @class_page = BOACClassListViewPage.new @driver
      @curated_group_page = BOACGroupStudentsPage.new @driver
      @filtered_cohort_page = BOACFilteredStudentsPage.new(@driver, test.advisor)
      @homepage = BOACHomePage.new @driver
      @search_page = BOACSearchResultsPage.new @driver
      @student_page = BOACStudentPage.new @driver
      @filtered_admit_page = BOACFilteredAdmitsPage.new @driver
      @admit_page = BOACAdmitPage.new @driver

      @homepage.dev_auth test.advisor
    end

    after(:all) { Utils.quit_browser @driver }

    context 'visiting the header Profile' do

      it 'sees a Degree Checks link' do
        @homepage.click_header_dropdown
        @homepage.degree_checks_link_element.when_visible(1)
      end
    end

    context 'visiting Everyone\'s Cohorts' do

      before(:all) { @homepage.load_page }

      it 'sees all default filtered cohorts' do
        expected_cohort_names = everyone_cohorts.map(&:name).sort
        visible_cohort_names = (@filtered_cohort_page.visible_everyone_cohorts.map &:name).sort
        @filtered_cohort_page.wait_until(1, "Expected #{expected_cohort_names}, but got #{visible_cohort_names}") do
          visible_cohort_names == expected_cohort_names
        end
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
        @student_opts = @filtered_cohort_page.filter_options
      end

      it('sees a College filter') { expect(@student_opts).to include('College') }
      it('sees an Entering Term filter') { expect(@student_opts).to include('Entering Term') }
      it('sees an EPN Grading Option filter') { expect(@student_opts).to include('EPN/CPN Grading Option') }
      it('sees an Expected Graduation Term filter') { expect(@student_opts).to include('Expected Graduation Term') }
      it('sees a GPA (Cumulative) filter') { expect(@student_opts).to include('GPA (Cumulative)') }
      it('sees a GPA (Last Term) filter') { expect(@student_opts).to include('GPA (Last Term)') }
      it('sees a Level filter') { expect(@student_opts).to include('Level') }
      it('sees a Major filter') { expect(@student_opts).to include('Major') }
      it('sees a Midpoint Deficient Grade filter') { expect(@student_opts).to include('Midpoint Deficient Grade') }
      it('sees a Transfer Student filter') { expect(@student_opts).to include 'Transfer Student' }
      it('sees a Units Completed filter') { expect(@student_opts).to include 'Units Completed' }

      it('sees an Ethnicity filter') { expect(@student_opts).to include('Ethnicity') }
      it('sees a Gender filter') { expect(@student_opts).to include('Gender') }
      it('sees an Underrepresented Minority filter') { expect(@student_opts).to include('Underrepresented Minority') }
      it('sees a Visa Type filter') { expect(@student_opts).to include('Visa Type') }

      it('sees an Inactive (ASC) filter') { expect(@student_opts).to include('Inactive (ASC)') }
      it('sees an Intensive (ASC) filter') { expect(@student_opts).to include('Intensive (ASC)') }
      it('sees a Team (ASC) filter') { expect(@student_opts).to include('Team (ASC)') }

      it('sees an Advisor (COE) filter') { expect(@student_opts).to include('Advisor (COE)') }
      it('sees an Ethnicity (COE) filter') { expect(@student_opts).to include('Ethnicity (COE)') }
      it('sees a Gender (COE) filter') { expect(@student_opts).to include('Gender (COE)') }
      it('sees an Inactive (COE) filter') { expect(@student_opts).to include('Inactive (COE)') }
      it('sees a Last Name filter') { expect(@student_opts).to include('Last Name') }
      it('sees a My Curated Groups filter') { expect(@student_opts).to include('My Curated Groups') }
      it('sees a My Students filter') { expect(@student_opts).to include('My Students') }
      it('sees a PREP (COE) filter') { expect(@student_opts).to include('PREP (COE)') }
      it('sees a Probation (COE) filter') { expect(@student_opts).to include('Probation (COE)') }
      it('sees an Underrepresented Minority (COE) filter') { expect(@student_opts).to include('Underrepresented Minority (COE)') }
    end

    context 'performing a filtered admit search' do

      before(:all) do
        @homepage.hit_escape
        @homepage.click_sidebar_create_ce3_filtered
        @admit_opts = @filtered_admit_page.filter_options
      end

      it('sees a Freshman or Transfer filter') { expect(@admit_opts).to include('Freshman or Transfer') }
      it('sees a Current SIR filter') { expect(@admit_opts).to include('Current SIR') }
      it('sees a College filter') { expect(@admit_opts).to include('College') }
      it('sees an XEthnic filter') { expect(@admit_opts).to include('XEthnic') }
      it('sees a Hispanic filter') { expect(@admit_opts).to include('Hispanic') }
      it('sees a UREM filter') { expect(@admit_opts).to include('UREM') }
      it('sees a First Generation College filter') { expect(@admit_opts).to include('First Generation College') }
      it('sees an Application Fee Waiver filter') { expect(@admit_opts).to include('Application Fee Waiver') }
      it('sees a Foster Care filter') { expect(@admit_opts).to include('Foster Care') }
      it('sees a Family Is Single Parent filter') { expect(@admit_opts).to include('Family Is Single Parent') }
      it('sees a Student Is Single Parent filter') { expect(@admit_opts).to include('Student Is Single Parent') }
      it('sees a Family Dependents filter') { expect(@admit_opts).to include('Family Dependents') }
      it('sees a Student Dependents filter') { expect(@admit_opts).to include('Student Dependents') }
      it('sees a Re-entry Status filter') { expect(@admit_opts).to include('Re-entry Status') }
      it('sees a Last School LCFF+ filter') { expect(@admit_opts).to include('Last School LCFF+') }
      it('sees a Special Program CEP filter') { expect(@admit_opts).to include('Special Program CEP') }
    end

    context 'visiting student API pages' do

      it 'can see the ASC profile data for an ASC student on the student API page' do
        filter = CohortFilter.new
        filter.set_custom_filters asc_team: [Squad::WSF]
        asc_sids = NessieFilterUtils.get_cohort_result(test, filter)
        asc_student = test.students.find { |s| s.sis_id == asc_sids.first }
        @api_student_page.get_data(@driver, asc_student)
        expect(@api_student_page.asc_profile).not_to be_nil
      end

      it 'can see the CoE profile data for a CoE student on the student API page' do
        filter = CohortFilter.new
        filter.set_custom_filters coe_gender: ['F']
        coe_sids = NessieFilterUtils.get_cohort_result(test, filter)
        coe_student = test.students.find { |s| s.sis_id == coe_sids.first }
        @api_student_page.get_data(@driver, coe_student)
        expect(@api_student_page.coe_profile).not_to be_nil
      end
    end

    context 'navigating directly to a CE3 cohort' do

      it("can reach cohort ID #{ce3_cohorts.first.id}") { @filtered_admit_page.load_cohort ce3_cohorts.first }
    end

    context 'visiting the admin page' do

      it 'sees a link to the admin page' do
        @homepage.load_page
        @homepage.click_flight_deck_link
      end

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

      it('can dismiss a service alert') { @admin_page.dismiss_announcement }

      context 'and exporting alerts' do

        before(:all) do
          @from_date = Date.today - 30
          @to_date = Date.today
          @csv = @admin_page.export_alerts(@from_date, @to_date)
        end

        it 'receives the right number of alerts' do
          expected = BOACUtils.get_alert_count_per_range(@from_date, @to_date)
          actual = @csv.length
          expect(actual).to eql(expected)
        end

        it 'receives the right alert data' do
          expect(@csv.headers).to eql(%i(sid term key type is_active active_duration_hours created_at deleted_at))
        end
      end
    end
  end
end
