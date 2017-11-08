require_relative '../../util/spec_helper'

include Logging

describe 'BOAC' do

  begin

    # Create file for test output
    user_profile_data = File.join(Utils.initialize_test_output_dir, 'boac-profiles.csv')
    user_profile_data_heading = %w(UID Sport Name Email Phone Units GPA Plan Level Writing History Institutions Cultures Language)
    CSV.open(user_profile_data, 'wb') { |heading| heading << user_profile_data_heading }

    # Get all teams and athletes
    athletes = BOACUtils.get_athletes
    teams = BOACUtils.get_teams athletes

    @driver = Utils.launch_browser
    @boac_homepage = Page::BOACPages::HomePage.new @driver
    @boac_cohort_page = Page::BOACPages::CohortPage.new @driver
    @boac_student_page = Page::BOACPages::StudentPage.new @driver

    @boac_homepage.dev_auth(Utils.super_admin_uid)

    expected_team_names = teams.map &:name
    visible_team_names = @boac_homepage.teams
    it('shows all the expected teams') { expect(visible_team_names.sort).to eql(expected_team_names.sort) }

   teams.each do |team|
      if visible_team_names.include? team.name
        begin

          expected_team_members = BOACUtils.get_team_members(team, athletes).sort_by! &:full_name

          @boac_homepage.click_boac
          @boac_homepage.click_team_link team
          team_url = @boac_cohort_page.current_url

          expected_team_member_names = expected_team_members.map &:full_name
          expected_team_member_uids = expected_team_members.map &:uid

          visible_team_member_names = @boac_cohort_page.team_player_names
          visible_team_member_uids = @boac_cohort_page.team_player_uids

          it("shows all the expected players for #{team.name}") { expect(visible_team_member_names).to eql(expected_team_member_names) }
          it("shows no blank player names for #{team.name}") { expect(visible_team_member_names.any? &:empty?).to be false }
          it("shows all the expected player UIDs for #{team.name}") { expect(visible_team_member_uids).to eql(expected_team_member_uids) }
          it("shows no blank player UIDs for #{team.name}") { expect(visible_team_member_uids.any? &:empty?).to be false }

          expected_team_members.each do |team_member|
            if visible_team_member_uids.include? team_member.uid
              begin

                user_analytics_data = ApiUserAnalyticsPage.new @driver
                user_analytics_data.get_data(@driver, team_member)

                @boac_cohort_page.navigate_to team_url
                @boac_cohort_page.click_player_link team_member

                visible_name = @boac_student_page.name
                visible_email = @boac_student_page.email_element.text
                visible_phone = @boac_student_page.phone
                visible_cumulative_units = @boac_student_page.cumulative_units
                visible_cumulative_gpa = @boac_student_page.cumulative_gpa
                visible_plan = @boac_student_page.plan
                visible_level = @boac_student_page.level
                visible_writing_reqt = @boac_student_page.writing_reqt.strip
                visible_history_reqt = @boac_student_page.history_reqt.strip
                visible_institutions_reqt = @boac_student_page.institutions_reqt.strip
                visible_cultures_reqt = @boac_student_page.cultures_reqt.strip
                visible_language_reqt = @boac_student_page.language_reqt.strip

                it("shows the name for #{team.name} UID #{team_member.uid}") { expect(visible_name).to eql(team_member.full_name.split(',').reverse.join(' ').strip) }

                it "shows the email for #{team.name} UID #{team_member.uid}" do
                  expect(visible_email).to eql(user_analytics_data.email)
                  expect(visible_email.empty?).to be false
                end

                it "shows the phone for #{team.name} UID #{team_member.uid}" do
                  expect(visible_phone).to eql(user_analytics_data.phone)
                end

                it "shows the total units for #{team.name} UID #{team_member.uid}" do
                  expect(visible_cumulative_units).to eql(user_analytics_data.cumulative_units)
                  expect(visible_cumulative_units.empty?).to be false
                end

                it "shows the cumulative GPA for #{team.name} UID #{team_member.uid}" do
                  expect(visible_cumulative_gpa).to eql(user_analytics_data.cumulative_gpa)
                  expect(visible_cumulative_gpa.empty?).to be false
                end

                # TODO - 'from' date
                if user_analytics_data.plan
                  it "shows the academic plan for #{team.name} UID #{team_member.uid}" do
                    expect(visible_plan).to eql(user_analytics_data.plan)
                  end
                else
                  it "shows no academic plan for #{team.name} UID #{team_member.uid}" do
                    expect(visible_plan.empty?).to be true
                  end
                end

                it "shows the academic level for #{team.name} UID #{team_member.uid}" do
                  expect(visible_level).to eql(user_analytics_data.level)
                  expect(visible_level.empty?).to be false
                end

                it "shows the Entry Level Writing Requirement for #{team.name} UID #{team_member.uid}" do
                  user_analytics_data.writing_reqt ?
                      (expect(visible_writing_reqt).to eql('Satisfied')) :
                      (expect(visible_writing_reqt).to eql('Not Satisfied'))
                end

                it "shows the American History Requirement for #{team.name} UID #{team_member.uid}" do
                  user_analytics_data.history_reqt ?
                      (expect(visible_history_reqt).to eql('Satisfied')) :
                      (expect(visible_history_reqt).to eql('Not Satisfied'))
                end

                it "shows the American Institutions Requirement for #{team.name} UID #{team_member.uid}" do
                  user_analytics_data.institutions_reqt ?
                      (expect(visible_institutions_reqt).to eql('Satisfied')) :
                      (expect(visible_institutions_reqt).to eql('Not Satisfied'))
                end

                it "shows the American Cultures Requirement for #{team.name} UID #{team_member.uid}" do
                  user_analytics_data.cultures_reqt ?
                      (expect(visible_cultures_reqt).to eql('Satisfied')) :
                      (expect(visible_cultures_reqt).to eql('Not Satisfied'))
                end

                # TODO - account for non-L & S
                it "shows the Foreign Languages Requirement for #{team.name} UID #{team_member.uid}" do
                  user_analytics_data.language_reqt ?
                      (expect(visible_language_reqt).to eql('Satisfied')) :
                      (expect(visible_language_reqt).to eql('Not Satisfied'))
                end

              rescue => e
                Utils.log_error e
                it("encountered an error for #{team.name} UID #{team_member.uid}") { fail }
              ensure
                row = [team_member.uid, team.name, visible_name, visible_email, visible_phone, visible_cumulative_units, visible_cumulative_gpa,
                      visible_plan, visible_level, visible_writing_reqt, visible_history_reqt, visible_institutions_reqt, visible_cultures_reqt,
                      visible_language_reqt]
                Utils.add_csv_row(user_profile_data, row)
              end

            else
              logger.warn "Skipping #{team.name} UID #{team_member.uid} because it is not present in the UI"
            end
          end
        rescue => e
          Utils.log_error e
          it("encountered an error for #{team.name}") { fail }
        end

      else
        logger.warn "Skipping #{team.name} because there is no link for it"
      end
    end

  rescue => e
    Utils.log_error e
    it('encountered an error') { fail }
  ensure
    Utils.quit_browser @driver
  end
end
