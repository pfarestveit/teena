require_relative '../../util/spec_helper'

unless ENV['NO_DEPS']

  describe 'A BOA advisor' do

    include Logging

    before(:all) do
      @test = BOACTestConfig.new
      @test.user_role_advisor
      @test.students.shuffle!

      @test_asc = BOACTestConfig.new
      @test_asc.user_role_asc @test

      @test_coe = BOACTestConfig.new
      @test_coe.user_role_coe @test

      @admin_cohorts = BOACUtils.get_everyone_filtered_cohorts({default: true}, BOACDepartments::ADMIN)
      @admin_groups = BOACUtils.get_everyone_curated_groups BOACDepartments::ADMIN

      @driver = Utils.launch_browser @test.chrome_profile
      @admit_page = BOACAdmitPage.new @driver
      @api_admin_page = BOACApiAdminPage.new @driver
      @api_notes_page = BOACApiNotesPage.new @driver
      @api_student_page = BOACApiStudentPage.new @driver
      @cohort_page = BOACFilteredStudentsPage.new(@driver, @test_asc.advisor)
      @group_page = BOACGroupStudentsPage.new @driver
      @homepage = BOACHomePage.new @driver
      @pax_manifest_page = BOACPaxManifestPage.new @driver
      @search_results_page = BOACSearchResultsPage.new @driver
      @settings_page = BOACFlightDeckPage.new @driver
      @student_page = BOACStudentPage.new @driver

      # Get ASC test data
      BOACUtils.hard_delete_auth_user @test_asc.advisor
      filter = CohortFilter.new
      filter.set_custom_filters asc_inactive: true
      asc_inactive_sids = NessieFilterUtils.get_cohort_result(@test_asc, filter)
      @asc_inactive_test_student = @test.students.find { |s| s.sis_id == asc_inactive_sids.first }
      filter = CohortFilter.new
      filter.set_custom_filters asc_inactive: false, asc_team: [Squad::MTE]
      asc_active_sids = NessieFilterUtils.get_cohort_result(@test_asc, filter)
      @asc_active_test_student = @test.students.find { |s| s.sis_id == asc_active_sids.first }
      @homepage.dev_auth
      @pax_manifest_page.load_page
      @pax_manifest_page.add_user @test_asc.advisor
      @pax_manifest_page.log_out
      @homepage.dev_auth @test_asc.advisor
      api_page_active = BOACApiStudentPage.new @driver
      api_page_active.get_data @asc_active_test_student
      @asc_test_active_student_sports = api_page_active.asc_teams
      api_page_inactive = BOACApiStudentPage.new @driver
      api_page_inactive.get_data @asc_inactive_test_student
      @asc_test_inactive_student_sports = api_page_inactive.asc_teams
      @homepage.load_page
      @homepage.log_out

      # Get CoE test data
      filter = CohortFilter.new
      filter.set_custom_filters coe_inactive: true
      coe_sids = NessieFilterUtils.get_cohort_result(@test_coe, filter)
      @coe_test_student = @test.students.find { |s| s.sis_id == coe_sids.first }

      # Get L&S test data
      @test_l_and_s = BOACTestConfig.new
      @test_l_and_s.user_role_l_and_s @test
      @l_and_s_cohorts = BOACUtils.get_everyone_filtered_cohorts({default: true}, BOACDepartments::L_AND_S)
      @l_and_s_groups = BOACUtils.get_everyone_curated_groups BOACDepartments::L_AND_S

      # Get admit data
      admits = NessieUtils.get_admits
      no_sir = admits.select { |a| !a.is_sir }
      @admit = if no_sir.any?
                 no_sir.last
               else
                 admits.last
               end
      logger.debug "The test admit's SID is #{@admit.sis_id}"
      @ce3_advisor = BOACUtils.get_dept_advisors(BOACDepartments::ZCEEE, DeptMembership.new(advisor_role: AdvisorRole::ADVISOR)).find do |a|
        a.uid.length == 7
      end
      logger.info "CE3 Advisor: #{@ce3_advisor.inspect}"
      ce3_cohort_search = CohortAdmitFilter.new
      ce3_cohort_search.set_custom_filters urem: true
      @ce3_cohort = FilteredCohort.new search_criteria: ce3_cohort_search, name: "CE3 #{@test.id}"
      @homepage.dev_auth @ce3_advisor
      @cohort_page.search_and_create_new_cohort(@ce3_cohort, admits: true)
      @cohort_page.log_out
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
          expected = BOACUtils.get_everyone_filtered_cohorts({default: true}, BOACDepartments::ASC).map(&:id).sort
          visible = (@cohort_page.visible_everyone_cohorts.map &:id).sort
          @cohort_page.wait_until(1, "Missing: #{expected - visible}. Unexpected: #{visible - expected}") { visible == expected }
        end

        it 'cannot hit an admin filtered cohort URL' do
          @admin_cohorts.any? ?
              @cohort_page.hit_non_auth_cohort(@admin_cohorts.first) :
              logger.warn('Skipping test for ASC access to admin cohorts because admins have no cohorts.')
        end

        it 'cannot hit a non-ASC filtered cohort URL' do
          coe_everyone_cohorts = BOACUtils.get_everyone_filtered_cohorts({default: true}, BOACDepartments::COE)
          coe_everyone_cohorts.any? ?
              @cohort_page.hit_non_auth_cohort(coe_everyone_cohorts.first) :
              logger.warn('Skipping test for ASC access to CoE cohorts because CoE has no cohorts.')
        end

        it('cannot hit a filtered admit cohort URL') { @cohort_page.hit_non_auth_cohort @ce3_cohort }
      end

      context 'visiting Everyone\'s Groups' do

        it 'sees only curated groups created by ASC advisors' do
          expected = BOACUtils.get_everyone_curated_groups(BOACDepartments::ASC).map(&:id).sort
          visible = (@group_page.visible_everyone_groups.map &:id).sort
          @group_page.wait_until(1, "Missing: #{expected - visible}. Unexpected: #{visible - expected}") { visible == expected }
        end

        it 'cannot hit an admin curated group URL' do
          @admin_groups.any? ?
              @group_page.hit_non_auth_group(@admin_groups.first) :
              logger.warn('Skipping test for ASC access to admin curated groups because admins have no groups.')
        end

        it 'cannot hit a non-ASC curated group URL' do
          coe_everyone_groups = BOACUtils.get_everyone_curated_groups BOACDepartments::COE
          coe_everyone_groups.any? ?
              @group_page.hit_non_auth_group(coe_everyone_groups.first) :
              logger.warn('Skipping test for ASC access to CoE curated groups because CoE has no groups.')
        end
      end

      context 'visiting a student page' do

        it 'sees no COE Inactive information' do
          @student_page.load_page @coe_test_student
          expect(@student_page.inactive_coe_flag?).to be false
        end
      end

      context 'visiting an inactive ASC student page' do

        before(:all) { @student_page.load_page @asc_inactive_test_student }

        it('sees team information') { expect(@student_page.sports).to eql(@asc_test_inactive_student_sports.sort) }
        it('sees ASC Inactive information') { expect(@student_page.inactive_asc_flag?).to be true }
      end

      context 'visiting an active ASC student page' do

        before(:all) { @student_page.load_page @asc_active_test_student }

        it('sees team information') { expect(@student_page.sports.sort).to eql(@asc_test_active_student_sports.sort) }
        it('sees no ASC Inactive information') { expect(@student_page.inactive_asc_flag?).to be false }
      end

      context 'visiting a student API page' do

        it 'cannot see COE profile data' do
          api_page = BOACApiStudentPage.new @driver
          api_page.get_data @coe_test_student
          api_page.coe_profile.each_value { |v| expect(v).to be_nil }
        end
      end

      context 'hitting an admit page' do

        it 'sees a 404' do
          @admit_page.hit_page_url @admit.sis_id
          @admit_page.wait_for_404
        end
      end

      context 'hitting an admit endpoint' do

        it 'sees no data' do
          if @admit
            api_page = BOACApiAdmitPage.new @driver
            api_page.hit_endpoint @admit
            api_page.unauth_msg_element.when_visible Utils.short_wait
          else
            skip
          end
        end
      end

      context 'visiting a cohort page' do

        before(:all) do
          @inactive_search = CohortFilter.new
          @inactive_search.set_custom_filters({:asc_inactive => true})
          @inactive_cohort = FilteredCohort.new({:search_criteria => @inactive_search})

          @homepage.load_page
          @homepage.click_sidebar_create_filtered
          @opts = @cohort_page.filter_options
        end

        it('sees a College filter') { expect(@opts).to include('College') }
        it('sees an Entering Term filter') { expect(@opts).to include('Entering Term') }
        it('sees an EPN Grading Option filter') { expect(@opts).to include('EPN/CPN Grading Option') }
        it('sees an Expected Graduation Term filter') { expect(@opts).to include('Expected Graduation Term') }
        it('sees a GPA (Cumulative) filter') { expect(@opts).to include('GPA (Cumulative)') }
        it('sees a GPA (Last Term) filter') { expect(@opts).to include('GPA (Last Term)') }
        it('sees a Level filter') { expect(@opts).to include('Level') }
        it('sees a Major filter') { expect(@opts).to include('Major') }
        it('sees a Midpoint Deficient Grade filter') { expect(@opts).to include('Midpoint Deficient Grade') }
        it('sees a Transfer Student filter') { expect(@opts).to include 'Transfer Student' }
        it('sees a Units Completed filter') { expect(@opts).to include 'Units Completed' }

        it('sees an Ethnicity filter') { expect(@opts).to include('Ethnicity') }
        it('sees a Gender filter') { expect(@opts).to include('Gender') }
        it('sees an Underrepresented Minority filter') { expect(@opts).to include('Underrepresented Minority') }
        it('sees a Visa Type filter') { expect(@opts).to include('Visa Type') }

        it('sees an Inactive (ASC) filter') { expect(@opts).to include('Inactive (ASC)') }
        it('sees an Intensive (ASC) filter') { expect(@opts).to include('Intensive (ASC)') }
        it('sees a Team (ASC) filter') { expect(@opts).to include('Team (ASC)') }

        it('sees no Advisor (COE) filter') { expect(@opts).not_to include('Advisor (COE)') }
        it('sees no Ethnicity (COE) filter') { expect(@opts).not_to include('Ethnicity (COE)') }
        it('sees no Gender (COE) filter') { expect(@opts).not_to include('Gender (COE)') }
        it('sees no Inactive (COE) filter') { expect(@opts).not_to include('Inactive (COE)') }
        it('sees a Last Name filter') { expect(@opts).to include('Last Name') }
        it('sees a My Curated Groups filter') { expect(@opts).to include('My Curated Groups') }
        it('sees a My Students filter') { expect(@opts).to include('My Students') }
        it('sees no PREP (COE) filter') { expect(@opts).not_to include('PREP (COE)') }
        it('sees no Probation (COE) filter') { expect(@opts).not_to include('Probation (COE)') }
        it('sees no Underrepresented Minority (COE) filter') { expect(@opts).not_to include('Underrepresented Minority (COE)') }

        context 'with results' do

          before(:all) do
            @homepage.load_page
            @homepage.click_sidebar_create_filtered
            @cohort_page.perform_student_search @inactive_cohort
          end

          it('sees team information') do
            visible_sports = @cohort_page.student_sports(@asc_inactive_test_student).sort
            expect(visible_sports).to eql(@asc_test_inactive_student_sports.sort)
          end
          it('sees ASC Inactive information') { expect(@cohort_page.student_inactive_asc_flag? @asc_inactive_test_student).to be true }
        end
      end

      context 'performing a search' do

        it 'sees no Admits option' do
          @homepage.open_adv_search
          expect(@homepage.include_admits_cbx?).to be false
        end

        it 'sees no admit results' do
          @homepage.click_adv_search_cxl_button
          if @admit.is_sir
            logger.warn 'Skipping admit search test since all admits have SIR'
          else
            @homepage.enter_simple_search_and_hit_enter @admit.sis_id
            @search_results_page.no_results_msg.when_visible Utils.short_wait
          end
        end
      end

      context 'looking for admin functions' do

        before(:all) do
          @homepage.load_page
          @homepage.click_header_dropdown
        end

        it('can access the settings page') { expect(@homepage.settings_link?).to be true }
        it('cannot access the degree check page') { expect(@homepage.degree_checks_link?).to be false }
        it('cannot access the flight deck page') { expect(@homepage.flight_deck_link?).to be false }
        it('cannot access the passenger manifest page') { expect(@homepage.pax_manifest_link?).to be false }

        it 'can toggle demo mode' do
          @settings_page.load_advisor_page
          @settings_page.my_profile_heading_element.when_visible Utils.short_wait
          expect(@settings_page.demo_mode_toggle?).to be true
        end

        it('cannot post status alerts') { expect(@settings_page.status_heading?).to be false }

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
          expected = BOACUtils.get_everyone_filtered_cohorts({default: true}, BOACDepartments::COE).map(&:id).sort
          visible = (@cohort_page.visible_everyone_cohorts.map &:id).sort
          @cohort_page.wait_until(1, "Missing: #{expected - visible}. Unexpected: #{visible - expected}") { visible == expected }
        end

        it 'cannot hit an admin filtered cohort URL' do
          @admin_cohorts.any? ?
              @cohort_page.hit_non_auth_cohort(@admin_cohorts.first) :
              logger.warn('Skipping test for ASC access to admin cohorts because admins have no cohorts.')
        end

        it 'cannot hit a non-COE filtered cohort URL' do
          asc_cohorts = BOACUtils.get_everyone_filtered_cohorts({default: true}, BOACDepartments::ASC)
          asc_cohorts.any? ?
              @cohort_page.hit_non_auth_cohort(asc_cohorts.first) :
              logger.warn('Skipping test for COE access to ASC cohorts because ASC has no cohorts.')
        end

        it('cannot hit a filtered admit cohort URL') { @cohort_page.hit_non_auth_cohort @ce3_cohort }

      end

      context 'visiting Everyone\'s Groups' do

        it 'sees only curated groups created by CoE advisors' do
          expected = BOACUtils.get_everyone_curated_groups(BOACDepartments::COE).map(&:id).sort
          visible = (@group_page.visible_everyone_groups.map &:id).sort
          @group_page.wait_until(1, "Missing: #{expected - visible}. Unexpected: #{visible - expected}") { visible == expected }
        end

        it 'cannot hit an admin curated group URL' do
          @admin_groups.any? ?
              @group_page.hit_non_auth_group(@admin_groups.first) :
              logger.warn('Skipping test for ASC access to admin curated groups because admins have no groups.')
        end

        it 'cannot hit a non-COE curated group URL' do
          asc_groups = BOACUtils.get_everyone_curated_groups BOACDepartments::ASC
          asc_groups.any? ?
              @group_page.hit_non_auth_group(asc_groups.first) :
              logger.warn('Skipping test for COE access to ASC curated groups because ASC has no groups.')
        end
      end

      context 'visiting a COE student page' do

        before(:all) { @student_page.load_page @coe_test_student }

        it('sees COE Inactive information') { expect(@student_page.inactive_coe_flag?).to be true }
      end

      context 'visiting an inactive ASC student page' do

        before(:all) { @student_page.load_page @asc_inactive_test_student }

        it('sees no team information') { expect(@student_page.sports).to be_empty }
        it('sees no ASC Inactive information') { expect(@student_page.inactive_asc_flag?).to be false }
      end

      context 'visiting an active ASC student page' do

        before(:all) { @student_page.load_page @asc_active_test_student }

        it('sees team information') { expect(@student_page.sports.sort).to eql(@asc_test_active_student_sports.sort) }
        it('sees no ASC Inactive information') { expect(@student_page.inactive_asc_flag?).to be false }
      end

      context 'hitting an admit page' do

        it 'sees a 404' do
          @admit_page.hit_page_url @admit.sis_id
          @admit_page.wait_for_404
        end
      end

      context 'hitting an admit endpoint' do

        it 'sees no data' do
          if @admit
            api_page = BOACApiAdmitPage.new @driver
            api_page.hit_endpoint @admit
            api_page.unauth_msg_element.when_visible Utils.short_wait
          else
            skip
          end
        end
      end

      context 'visiting a cohort page' do

        before(:all) do
          @inactive_search = CohortFilter.new
          @inactive_search.set_custom_filters({:asc_inactive => true})
          @inactive_cohort = FilteredCohort.new({:search_criteria => @inactive_search})

          @homepage.load_page
          @homepage.click_sidebar_create_filtered
          @opts = @cohort_page.filter_options
        end

        it('sees a College filter') { expect(@opts).to include('College') }
        it('sees an Entering Term filter') { expect(@opts).to include('Entering Term') }
        it('sees an EPN Grading Option filter') { expect(@opts).to include('EPN/CPN Grading Option') }
        it('sees an Expected Graduation Term filter') { expect(@opts).to include('Expected Graduation Term') }
        it('sees a GPA (Cumulative) filter') { expect(@opts).to include('GPA (Cumulative)') }
        it('sees a GPA (Last Term) filter') { expect(@opts).to include('GPA (Last Term)') }
        it('sees a Level filter') { expect(@opts).to include('Level') }
        it('sees a Major filter') { expect(@opts).to include('Major') }
        it('sees a Midpoint Deficient Grade filter') { expect(@opts).to include('Midpoint Deficient Grade') }
        it('sees a Transfer Student filter') { expect(@opts).to include 'Transfer Student' }
        it('sees a Units Completed filter') { expect(@opts).to include 'Units Completed' }

        it('sees an Ethnicity filter') { expect(@opts).to include('Ethnicity') }
        it('sees a Gender filter') { expect(@opts).to include('Gender') }
        it('sees an Underrepresented Minority filter') { expect(@opts).to include('Underrepresented Minority') }
        it('sees a Visa Type filter') { expect(@opts).to include('Visa Type') }

        it('sees no Inactive ASC filter') { expect(@opts).not_to include('Inactive (ASC)') }
        it('sees no Intensive (ASC) filter') { expect(@opts).not_to include('Intensive (ASC)') }
        it('sees no Team (ASC) filter') { expect(@opts).not_to include('Team (ASC)') }

        it('sees an Advisor (COE) filter') { expect(@opts).to include('Advisor (COE)') }
        it('sees an Ethnicity (COE) filter') { expect(@opts).to include('Ethnicity (COE)') }
        it('sees a Gender (COE) filter') { expect(@opts).to include('Gender (COE)') }
        it('sees an Inactive (COE) filter') { expect(@opts).to include('Inactive (COE)') }
        it('sees a Last Name filter') { expect(@opts).to include('Last Name') }
        it('sees a My Curated Groups filter') { expect(@opts).to include('My Curated Groups') }
        it('sees a My Students filter') { expect(@opts).to include('My Students') }
        it('sees a PREP (COE) filter') { expect(@opts).to include('PREP (COE)') }
        it('sees a Probation (COE) filter') { expect(@opts).to include('Probation (COE)') }
        it('sees an Underrepresented Minority (COE) filter') { expect(@opts).to include('Underrepresented Minority (COE)') }

      end

      context 'performing a search' do

        it 'sees no Admits option' do
          @homepage.open_adv_search
          expect(@homepage.include_admits_cbx?).to be false
        end

        it 'sees no admit results' do
          @homepage.click_adv_search_cxl_button
          if @admit.is_sir
            logger.warn 'Skipping admit search test since all admits have SIR'
          else
            @homepage.enter_simple_search_and_hit_enter @admit.sis_id
            @search_results_page.no_results_msg.when_visible Utils.short_wait
          end
        end
      end

      context 'looking for admin functions' do

        before(:all) do
          @homepage.load_page
          @homepage.click_header_dropdown
        end

        it('can access the settings page') { expect(@homepage.settings_link?).to be true }
        it('can access the degree check page') { expect(@homepage.degree_checks_link?).to be true }
        it('cannot access the flight deck page') { expect(@homepage.flight_deck_link?).to be false }
        it('cannot access the passenger manifest page') { expect(@homepage.pax_manifest_link?).to be false }

        it 'can toggle demo mode' do
          @settings_page.load_advisor_page
          @settings_page.my_profile_heading_element.when_visible Utils.short_wait
          expect(@settings_page.demo_mode_toggle?).to be true
        end

        it('cannot post status alerts') { expect(@settings_page.status_heading?).to be false }

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
          expected = @l_and_s_cohorts.map(&:id).sort
          visible = (@cohort_page.visible_everyone_cohorts.map &:id).sort
          @cohort_page.wait_until(1, "Missing: #{expected - visible}. Unexpected: #{visible - expected}") { visible == expected }
        end

        it 'cannot hit an admin filtered cohort URL' do
          @admin_cohorts.any? ?
              @cohort_page.hit_non_auth_cohort(@admin_cohorts.first) :
              logger.warn('Skipping test for ASC access to admin cohorts because admins have no cohorts.')
        end

        it('cannot hit a filtered admit cohort URL') { @cohort_page.hit_non_auth_cohort @ce3_cohort }
      end

      context 'visiting another user\'s cohort' do

        before(:all) { @cohort_page.load_cohort @l_and_s_cohorts.find { |c| ![@test_l_and_s.advisor.uid, '70143'].include? c.owner_uid } }

        it('can view the filters') { @cohort_page.show_filters }
        it('cannot edit the filters') { expect(@cohort_page.cohort_edit_button_elements).to be_empty }
        it('can export the student list') { expect(@cohort_page.export_list_button?).to be true }
        it('cannot rename the cohort') { expect(@cohort_page.rename_cohort_button?).to be false }
        it('cannot delete the cohort') { expect(@cohort_page.delete_cohort_button?).to be false }
      end

      context 'visiting Everyone\'s Groups' do

        it 'sees only curated groups created by advisors in its own department' do
          expected = @l_and_s_groups.map(&:id).sort
          visible = (@group_page.visible_everyone_groups.map &:id).sort
          @group_page.wait_until(1, "Missing: #{expected - visible}. Unexpected: #{visible - expected}") { visible == expected }
        end

        it 'cannot hit an admin curated group URL' do
          @admin_groups.any? ?
              @group_page.hit_non_auth_group(@admin_groups.first) :
              logger.warn('Skipping test for ASC access to admin curated groups because admins have no groups.')
        end
      end

      context 'visiting another user\'s curated group' do

        before(:all) { @group_page.load_page @l_and_s_groups.find { |g| g.owner_uid != @test_l_and_s.advisor.uid } }

        it('can export the student list') { expect(@group_page.export_list_button?).to be true }
        it('cannot add students') { expect(@group_page.add_students_button?).to be false }
        it('cannot rename the cohort') { expect(@group_page.rename_cohort_button?).to be false }
        it('cannot delete the cohort') { expect(@group_page.delete_cohort_button?).to be false }
      end

      context 'visiting an inactive ASC student page' do

        before(:all) { @student_page.load_page @asc_inactive_test_student }

        it('sees no team information') { expect(@student_page.sports).to be_empty }
        it('sees no ASC Inactive information') { expect(@student_page.inactive_asc_flag?).to be false }
      end

      context 'visiting an active ASC student page' do

        before(:all) { @student_page.load_page @asc_active_test_student }

        it('sees team information') { expect(@student_page.sports.sort).to eql(@asc_test_active_student_sports.sort) }
        it('sees no ASC Inactive information') { expect(@student_page.inactive_asc_flag?).to be false }
      end

      context 'visiting a COE student page' do

        before(:all) { @student_page.load_page @coe_test_student }

        it('sees no COE Inactive information') { expect(@student_page.inactive_coe_flag?).to be false }
      end

      context 'visiting a student API page' do

        it 'cannot see COE profile data on the student API page' do
          api_page = BOACApiStudentPage.new @driver
          api_page.get_data @coe_test_student
          api_page.coe_profile.each_value { |v| expect(v).to be_nil }
        end
      end

      context 'hitting an admit page' do

        it 'sees a 404' do
          @admit_page.hit_page_url @admit.sis_id
          @admit_page.wait_for_404
        end
      end

      context 'hitting an admit endpoint' do

        it 'sees no data' do
          if @admit
            api_page = BOACApiAdmitPage.new @driver
            api_page.hit_endpoint @admit
            api_page.unauth_msg_element.when_visible Utils.short_wait
          else
            skip
          end
        end
      end

      context 'performing a filtered cohort search' do

        before(:all) do
          @homepage.load_page
          @homepage.click_sidebar_create_filtered
          @opts = @cohort_page.filter_options
        end

        it('sees a College filter') { expect(@opts).to include('College') }
        it('sees an Entering Term filter') { expect(@opts).to include('Entering Term') }
        it('sees an EPN/CPN Grading Option filter') { expect(@opts).to include('EPN/CPN Grading Option') }
        it('sees an Expected Graduation Term filter') { expect(@opts).to include('Expected Graduation Term') }
        it('sees a GPA (Cumulative) filter') { expect(@opts).to include('GPA (Cumulative)') }
        it('sees a GPA (Last Term) filter') { expect(@opts).to include('GPA (Last Term)') }
        it('sees a Level filter') { expect(@opts).to include('Level') }
        it('sees a Major filter') { expect(@opts).to include('Major') }
        it('sees a Midpoint Deficient Grade filter') { expect(@opts).to include('Midpoint Deficient Grade') }
        it('sees a Transfer Student filter') { expect(@opts).to include 'Transfer Student' }
        it('sees a Units Completed filter') { expect(@opts).to include 'Units Completed' }

        it('sees an Ethnicity filter') { expect(@opts).to include('Ethnicity') }
        it('sees a Gender filter') { expect(@opts).to include('Gender') }
        it('sees an Underrepresented Minority filter') { expect(@opts).to include('Underrepresented Minority') }
        it('sees a Visa Type filter') { expect(@opts).to include('Visa Type') }

        it('sees no Inactive (ASC) filter') { expect(@opts).not_to include('Inactive (ASC)') }
        it('sees no Intensive (ASC) filter') { expect(@opts).not_to include('Intensive (ASC)') }
        it('sees no Team filter (ASC)') { expect(@opts).not_to include('Team (ASC)') }

        it('sees no Advisor (COE) filter') { expect(@opts).not_to include('Advisor (COE)') }
        it('sees no Ethnicity (COE) filter') { expect(@opts).not_to include('Ethnicity (COE)') }
        it('sees no Gender (COE) filter') { expect(@opts).not_to include('Gender (COE)') }
        it('sees no Inactive (COE) filter') { expect(@opts).not_to include('Inactive (COE)') }
        it('sees a Last Name filter') { expect(@opts).to include('Last Name') }
        it('sees a My Curated Groups filter') { expect(@opts).to include('My Curated Groups') }
        it('sees a My Students filter') { expect(@opts).to include('My Students') }
        it('sees no PREP (COE) filter') { expect(@opts).not_to include('PREP (COE)') }
        it('sees no Probation (COE) filter') { expect(@opts).not_to include('Probation (COE)') }
        it('sees no Underrepresented Minority (COE) filter') { expect(@opts).not_to include('Underrepresented Minority (COE)') }

      end

      context 'performing a search' do

        it 'sees no Admits option' do
          @homepage.open_adv_search
          expect(@homepage.include_admits_cbx?).to be false
        end

        it 'sees no admit results' do
          @homepage.click_adv_search_cxl_button
          if @admit.is_sir
            logger.warn 'Skipping admit search test since all admits have SIR'
          else
            @homepage.enter_simple_search_and_hit_enter @admit.sis_id
            @search_results_page.no_results_msg.when_visible Utils.short_wait
          end
        end
      end

      context 'looking for admin functions' do

        before(:all) do
          @homepage.load_page
          @homepage.click_header_dropdown
        end

        it('can access the settings page') { expect(@homepage.settings_link?).to be true }
        it('cannot access the degree check page') { expect(@homepage.degree_checks_link?).to be false }
        it('cannot access the flight deck page') { expect(@homepage.flight_deck_link?).to be false }
        it('cannot access the passenger manifest page') { expect(@homepage.pax_manifest_link?).to be false }

        it 'can toggle demo mode' do
          @settings_page.load_advisor_page
          @settings_page.my_profile_heading_element.when_visible Utils.short_wait
          expect(@settings_page.demo_mode_toggle?).to be true
        end

        it('cannot post status alerts') do
          @settings_page.load_advisor_page
          @settings_page.my_profile_heading_element.when_visible Utils.short_wait
          expect(@settings_page.status_heading?).to be false
        end

        it 'cannot hit the cachejob page' do
          @api_admin_page.load_cachejob
          @api_admin_page.unauth_msg_element.when_visible Utils.medium_wait
        end
      end
    end

    context 'with assigned students' do

      before(:all) do
        plan = '25000U'
        @test.advisor = NessieUtils.get_my_students_test_advisor plan
        my_students_filter = CohortFilter.new
        my_students_filter.set_custom_filters cohort_owner_academic_plans: [plan]
        @my_students_cohort = FilteredCohort.new(search_criteria: my_students_filter, name: "My Students cohort #{@test.id}")

        @homepage.dev_auth @test.advisor
      end

      it 'can perform a cohort search for My Students' do
        @homepage.click_sidebar_create_filtered
        @cohort_page.perform_student_search @my_students_cohort
        @cohort_page.set_cohort_members(@my_students_cohort, @test)
        expected = @my_students_cohort.members.map &:sis_id
        visible = @cohort_page.visible_sids
        @cohort_page.wait_until(1, "Missing: #{expected - visible}. Unexpected: #{visible - expected}") do
          visible.sort == expected.sort
        end
      end

      it 'can export a My Students cohort with default columns' do
        parsed_csv = @cohort_page.export_student_list @my_students_cohort
        @cohort_page.verify_student_list_default_export(@my_students_cohort.members, parsed_csv)
      end

      it 'can export a My Students cohort with custom columns' do
        parsed_csv = @cohort_page.export_custom_student_list @my_students_cohort
        @cohort_page.verify_student_list_custom_export(@my_students_cohort.members, parsed_csv)
      end

      it 'has a My Students cohort visible to others' do
        @cohort_page.create_new_cohort @my_students_cohort
        @cohort_page.log_out
        @homepage.dev_auth
        @cohort_page.load_cohort @my_students_cohort
        expected = @my_students_cohort.members.map &:sis_id
        visible = @cohort_page.visible_sids
        @cohort_page.wait_until(1, "Missing: #{expected - visible}. Unexpected: #{visible - expected}") do
          visible.sort == expected.sort
        end
      end

      it 'has a My Students cohort that can be exported with default columns by another user' do
        parsed_csv = @cohort_page.export_student_list @my_students_cohort
        @cohort_page.verify_student_list_default_export(@my_students_cohort.members, parsed_csv)
      end

      it 'has a My Students cohort that can be exported with custom columns by another user' do
        parsed_csv = @cohort_page.export_custom_student_list @my_students_cohort
        @cohort_page.verify_student_list_custom_export(@my_students_cohort.members, parsed_csv)
      end
    end

    context 'note' do

      before(:all) do
        @student = @test.students.last
        @topics = [Topic::COURSE_ADD, Topic::COURSE_DROP]
        @attachments = @test.attachments[0..1]

        @note_1 = Note.new student: @student,
                           advisor: @ce3_advisor,
                           subject: "Note 1 #{@test.id}",
                           body: "Note 1 body #{@test.id}"

        @note_2 = Note.new student: @student,
                           advisor: @ce3_advisor,
                           subject: "Note 2 #{@test.id}",
                           body: "Note 2 body #{@test.id}"

        @note_3 = Note.new student: @student,
                           advisor: @test_l_and_s.advisor,
                           subject: "Note 3 #{@test.id}",
                           body: "Note 3 body #{@test.id}"

        eop_sids = NessieTimelineUtils.get_sids_with_notes_of_src(TimelineRecordSource::EOP, eop_private=true)
        @eop_student = @test.students.select { |s| eop_sids.include? s.sis_id }.first
        @eop_note = NessieTimelineUtils.get_eop_notes(@eop_student).find { |n| n.is_private && n.attachments.any? }
        logger.info "EOP UID #{@eop_student.uid}, note id #{@eop_note.id}"
      end

      context 'when an imported private EOP note' do

        context 'and viewed by a CE3 advisor' do

          before(:all) do
            @homepage.log_out
            @homepage.dev_auth @ce3_advisor
            @student_page.load_page @eop_student
            @student_page.show_notes
          end

          it('shows the complete note including private data') { @student_page.verify_note(@eop_note, @ce3_advisor) }

          it 'allows the advisor to download the note attachments' do
            @eop_note.attachments.each { |attach| @student_page.download_attachment(@eop_note, attach, @eop_student) }
          end
        end

        context 'and viewed by a non-CE3 advisor' do

          before(:all) do
            @homepage.log_out
            @homepage.dev_auth @test_l_and_s.advisor
            @student_page.load_page @eop_student
            @student_page.show_notes
          end

          it('shows the partial note excluding private data') { @student_page.verify_note(@eop_note, @test_l_and_s.advisor) }

          it 'blocks API access to note body and attachment file names' do
            @api_student_page.get_data @eop_student
            note = @api_student_page.notes.find { |n| n.id == @eop_note.id }
            expect(note.body).to be_empty
            expect(note.attachments).to be_empty
          end

          it 'blocks API access to note attachment downloads' do
            Utils.prepare_download_dir
            @api_notes_page.load_attachment_page @eop_note.id
            @api_notes_page.attach_not_found_msg_element.when_visible Utils.short_wait
            expect(Utils.downloads_empty?).to be true
          end
        end

        context 'and searched' do

          before(:all) do
            @homepage.load_page
            @homepage.log_out
            @homepage.dev_auth @ce3_advisor
          end

          it 'cannot be searched by body' do
            @homepage.reopen_and_reset_adv_search
            @homepage.set_notes_student @eop_student
            @homepage.enter_adv_search_and_hit_enter @eop_note.body
            expect(@search_results_page.note_results_count).to be_zero
          end
        end
      end

      context 'when created by a CE3 advisor' do

        before(:all) do
          @student_page.load_page @student
        end

        it 'can be set to private' do
          @note_1.is_private = true
          @student_page.create_note(@note_1, @topics, [@attachments.first])
          expect(BOACUtils.is_note_private? @note_1).to be true
        end

        it 'can be set to non-private' do
          @note_2.is_private = false
          @student_page.create_note(@note_2, @topics, [])
          expect(BOACUtils.is_note_private? @note_2).to be false
        end

        context 'as part of a batch' do

          before(:all) do
            @batch_1 = NoteBatch.new advisor: @ce3_advisor,
                                     subject: "Batch 1 #{@test.id}",
                                     is_private: true

            @batch_2 = NoteBatch.new advisor: @ce3_advisor,
                                     subject: "Batch 2 #{@test.id}",
                                     is_private: false
          end

          it 'can be set to private' do
            @homepage.create_batch_of_notes(@batch_1, [], [], @test.students[0..1], [], [])
            @test.students[0..1].each do |student|
              id = @student_page.set_new_note_id(@batch_1, student)
              note = Note.new id: id
              expect(BOACUtils.is_note_private? note).to be true
            end
          end

          it 'can be set to non-private' do
            @homepage.create_batch_of_notes(@batch_2, [], [], @test.students[2..3], [], [])
            @test.students[2..3].each do |student|
              id = @student_page.set_new_note_id(@batch_2, student)
              note = Note.new id: id
              expect(BOACUtils.is_note_private? note).to be false
            end
          end
        end

        context 'from a template' do

          before(:all) do
            @ce3_template = NoteTemplate.new title: "CE3 template #{@test.id}"
          end

          context 'that is private' do

            before(:all) do
              note = Note.new subject: "CE3 template subject #{@test.id}",
                              advisor: @ce3_advisor,
                              is_private: true
              @student_page.load_page @test.students[0]
              @student_page.click_create_new_note
              @student_page.enter_new_note_subject note
              @student_page.set_note_privacy note
              @student_page.create_template(@ce3_template, note)
            end

            it 'can be set to private' do
              note = Note.new subject: @ce3_template.subject
              @student_page.load_page @test.students[0]
              @student_page.click_create_new_note
              @student_page.select_and_apply_template(@ce3_template, note)
              @student_page.click_save_new_note
              @student_page.set_new_note_id(note, @test.students[0])
              expect(BOACUtils.is_note_private? note).to be true
            end

            it 'can be set to non-private' do
              note = Note.new subject: @ce3_template.subject
              @student_page.load_page @test.students[1]
              @student_page.click_create_new_note
              @student_page.select_and_apply_template(@ce3_template, note)
              note.is_private = false
              @student_page.set_note_privacy note
              @student_page.click_save_new_note
              @student_page.set_new_note_id(note, @test.students[1])
              expect(BOACUtils.is_note_private? note).to be false
            end
          end

          context 'that is not private' do

            before(:all) do
              @student_page.load_page @test.students[2]
              @student_page.click_create_new_note
              @student_page.click_edit_template @ce3_template
              @ce3_template.is_private = false
              @student_page.set_note_privacy @ce3_template
              @student_page.click_update_template
            end

            it 'can be set to private' do
              note = Note.new subject: @ce3_template.subject
              @student_page.click_create_new_note
              @student_page.select_and_apply_template(@ce3_template, note)
              note.is_private = true
              @student_page.set_note_privacy note
              @student_page.click_save_new_note
              @student_page.set_new_note_id(note, @test.students[2])
              expect(BOACUtils.is_note_private? note).to be true
            end

            it 'can be set to non-private' do
              note = Note.new subject: @ce3_template.subject
              @student_page.load_page @test.students[3]
              @student_page.click_create_new_note
              @student_page.select_and_apply_template(@ce3_template, note)
              note.is_private = false
              @student_page.set_note_privacy note
              @student_page.click_save_new_note
              @student_page.set_new_note_id(note, @test.students[3])
              expect(BOACUtils.is_note_private? note).to be false
            end
          end
        end
      end

      context 'when created by a non-CE3 advisor' do

        before(:all) do
          @homepage.log_out
          @homepage.dev_auth @test_l_and_s.advisor
          @student_page.load_page @test.students[4]
        end

        it 'is automatically non-private' do
          @student_page.create_note(@note_3, @topics, [])
          expect(BOACUtils.is_note_private? @note_3).to be false
        end

        context 'from a template' do

          before(:all) do
            @non_ce3_template = NoteTemplate.new title: "Non-CE3 template #{@test.id}"
            @non_ce3_note = Note.new subject: "Non-CE3 template subject #{@test.id}",
                            advisor: @test_l_and_s.advisor
            @student_page.load_page @test.students[5]
            @student_page.click_create_new_note
            @student_page.enter_new_note_subject @non_ce3_note
            @student_page.create_template(@non_ce3_template, @non_ce3_note)
          end

          it 'does not offer a private option' do
            @student_page.click_create_new_note
            @student_page.select_and_apply_template(@non_ce3_template, @non_ce3_note)
            @student_page.new_note_save_button_element.when_visible 2
            expect(@student_page.private_radio?).to be false
          end

          it 'is automatically non-private' do
            @student_page.click_save_new_note
            @student_page.set_new_note_id(@non_ce3_note, @test.students[5])
            expect(BOACUtils.is_note_private? @non_ce3_note).to be false
          end
        end
      end

      context 'when private' do

        context 'and viewed by a CE3 advisor' do

          before(:all) do
            @homepage.log_out
            @homepage.dev_auth @ce3_advisor
            @student_page.load_page @student
          end

          it('shows the complete note including private data') { @student_page.verify_note(@note_1, @ce3_advisor) }

          it 'allows the advisor to download the note attachments' do
            @note_1.attachments.each { |attach| @student_page.download_attachment(@note_1, attach) }
          end
        end

        context 'and viewed by a non-CE3 advisor' do

          before(:all) do
            @homepage.log_out
            @homepage.dev_auth @test_l_and_s.advisor
            @student_page.load_page @student
          end

          it('shows the partial note excluding private data') { @student_page.verify_note(@note_1, @test_l_and_s.advisor) }

          it 'blocks API access to note body and attachment file names' do
            @api_student_page.get_data @student
            note = @api_student_page.notes.find { |n| n.id == @note_1.id }
            expect(note.body).to be_empty
            expect(note.attachments).to be_empty
          end

          it 'blocks API access to note attachment downloads' do
            notes = BOACUtils.get_student_notes @student
            note = notes.find { |n| n.attachments&.any? && n.is_private && (n.advisor.uid != @test_l_and_s.advisor.uid) && !n.deleted_date && !n.is_draft }
            Utils.prepare_download_dir
            @api_notes_page.load_attachment_page note.attachments.find { |a| !a.deleted_at }.id
            @api_notes_page.attach_not_found_msg_element.when_visible Utils.short_wait
            expect(Utils.downloads_empty?).to be true
          end
        end

        context 'and searched' do

          before(:all) do
            @homepage.log_out
            @homepage.dev_auth
            @api_admin_page.reindex_notes
            @homepage.load_page
            @homepage.log_out
            @homepage.dev_auth @ce3_advisor
          end

          it 'cannot be searched by body' do
            @homepage.enter_simple_search_and_hit_enter @note_1.body
            expect(@search_results_page.note_results_count).to be_zero
          end

          it 'cannot be searched by subject' do
            @homepage.enter_simple_search_and_hit_enter @note_1.subject
            expect(@search_results_page.note_results_count).to be_zero
          end

          it 'cannot be searched by date' do
            @homepage.open_adv_search
            @homepage.set_notes_student @student
            @homepage.set_notes_date_from Date.today
            @homepage.click_adv_search_button
            expect(@search_results_page.note_in_search_result? @note_1).to be false
          end
        end

        context 'and downloaded by a non-CE3 director' do

          before(:all) do
            @homepage.log_out
            @homepage.dev_auth
            @test_l_and_s.advisor.dept_memberships = [
              (DeptMembership.new dept: BOACDepartments::L_AND_S,
                                  advisor_role: AdvisorRole::DIRECTOR,
                                  is_automated: true)
            ]
            @pax_manifest_page.load_page
            @pax_manifest_page.search_for_advisor @test_l_and_s.advisor
            @pax_manifest_page.edit_user @test_l_and_s.advisor
            @homepage.log_out

            @homepage.dev_auth @test_l_and_s.advisor
            @student_page.load_page @student
            @student_page.show_notes
            @student_page.download_notes @student
          end

          it 'does not include the note body' do
            csv = @student_page.parse_note_export_csv_to_table @student
            @student_page.verify_note_in_export_csv(@student, @note_1, csv, @test_l_and_s.advisor)
          end

          it 'does not include the note attachment files' do
            private_file_names = @note_2.attachments.map &:file_name
            downloaded_file_names = @student_page.note_export_file_names(@student).sort
            expect(downloaded_file_names & private_file_names).to be_empty
          end
        end
      end

      context 'when edited' do

        before(:all) do
          @homepage.log_out
          @homepage.dev_auth @ce3_advisor
          @student_page.load_page @student
        end

        it 'can be set to private' do
          @note_2.is_private = true
          @student_page.expand_item @note_2
          @student_page.click_edit_note_button @note_2
          @student_page.set_note_privacy @note_2
          @student_page.save_note_edit @note_2
          expect(BOACUtils.is_note_private? @note_2).to be true
        end

        it 'can be set to non-private' do
          @note_1.is_private = false
          @student_page.expand_item @note_1
          @student_page.click_edit_note_button @note_1
          @student_page.set_note_privacy @note_1
          @student_page.save_note_edit @note_1
          expect(BOACUtils.is_note_private? @note_1).to be false
        end

        context 'and converted to private' do

          before(:all) do
            @student_page.log_out
            @homepage.dev_auth
            @api_admin_page.reindex_notes
            @homepage.load_page
            @homepage.log_out
            @homepage.dev_auth @ce3_advisor
          end

          it 'cannot be searched by body' do
            @homepage.enter_simple_search_and_hit_enter @note_2.body
            expect(@search_results_page.note_results_count).to be_zero
          end

          it 'cannot be searched by subject' do
            @homepage.enter_simple_search_and_hit_enter @note_2.subject
            expect(@search_results_page.note_results_count).to be_zero
          end

          it 'cannot be searched by date' do
            @homepage.reopen_and_reset_adv_search
            @homepage.set_notes_student @student
            @homepage.set_notes_date_from Date.today
            @homepage.click_adv_search_button
            expect(@search_results_page.note_in_search_result? @note_2).to be false
          end
        end
      end

      context 'and the advisor loses access to private notes' do

        before(:all) do
          @homepage.log_out
          @homepage.dev_auth
          @ce3_advisor.dept_memberships = [
            (DeptMembership.new dept: BOACDepartments::L_AND_S,
                                advisor_role: AdvisorRole::ADVISOR,
                                is_automated: true)
          ]
          @pax_manifest_page.load_page
          @pax_manifest_page.search_for_advisor @ce3_advisor
          @pax_manifest_page.edit_user @ce3_advisor
          @homepage.log_out

          @homepage.dev_auth @ce3_advisor
          @student_page.load_page @student
        end

        after(:all) do
          @homepage.log_out
          @homepage.dev_auth
          @ce3_advisor.dept_memberships = [
            (DeptMembership.new dept: BOACDepartments::ZCEEE,
                                advisor_role: AdvisorRole::ADVISOR,
                                is_automated: true)
          ]
          @pax_manifest_page.load_page
          @pax_manifest_page.search_for_advisor @ce3_advisor
          @pax_manifest_page.edit_user @ce3_advisor
        end

        it 'does not allow the advisor to edit their private notes' do
          @student_page.show_notes
          @student_page.expand_item @note_2
          expect(@student_page.edit_note_button(@note_2).exists?).to be false
        end
      end
    end
  end
end
