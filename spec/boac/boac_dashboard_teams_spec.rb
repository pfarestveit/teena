require_relative '../../util/spec_helper'

include Logging

describe 'BOAC' do

  begin

    # Create file for test output
    user_profile_data = File.join(Utils.initialize_test_output_dir, 'boac-profiles.csv')
    user_profile_data_heading = %w(UID Sport Name Email Phone Units GPA Plan Level Writing History Institutions Cultures Language)
    CSV.open(user_profile_data, 'wb') { |csv| csv << user_profile_data_heading }

    user_course_data = File.join(Utils.initialize_test_output_dir, 'boac-courses.csv')
    user_course_data_heading = %w(UID Sport CourseCode CourseName SectionCcn, SectionNumber Grade GradingBasis Units EnrollmentStatus PageViews Assignments Participations)
    CSV.open(user_course_data, 'wb') { |csv| csv << user_course_data_heading }

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

          @boac_homepage.click_home
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

                # COURSES

                visible_course_sites = @boac_student_page.course_site_code_elements.map &:text
                expected_course_sites = user_analytics_data.courses.map { |c| user_analytics_data.course_site_code c }

                it "shows all the course site codes for #{team.name} UID #{team_member.uid}" do
                  expect(visible_course_sites).to eql(expected_course_sites)
                  expect(visible_course_sites.all? &:empty?).to be false
                end

                user_analytics_data.courses.each do |course|

                  course_site_code = user_analytics_data.course_site_code course

                  # SECTIONS

                  sections = user_analytics_data.course_site_sis_sections course
                  sections.each do |section|
                    begin

                      index = sections.index section
                      visible_section_data = @boac_student_page.visible_site_sis_data(course_site_code, index)
                      visible_section_status = visible_section_data[:status]
                      visible_section_number = visible_section_data[:number]
                      visible_section_units = visible_section_data[:units]
                      visible_section_grading_basis = visible_section_data[:grading_basis]

                      it "shows the section enrollment status for #{team.name} UID #{team_member.uid} course #{course_site_code} at index #{index}" do
                        expect(visible_section_status.empty?).to be false
                        case section[:status]
                          when 'E'
                            expect(visible_section_status).to eql('Enrolled in')
                          when 'W'
                            expect(visible_section_status).to eql('Waitlisted in')
                          when 'D'
                            expect(visible_section_status).to eql('Dropped')
                          else
                            logger.error "Invalid section status #{section[:enrollment_status]} for #{team.name} UID #{team_member.uid} course #{course_site_code} at index #{index}"
                            fail
                        end
                      end

                      it "shows the section number for #{team.name} UID #{team_member.uid} course #{course_site_code} at index #{index}" do
                        expect(visible_section_number).to eql(section[:number])
                        expect(visible_section_number.empty?).to be false
                      end

                      it "shows the section units for #{team.name} UID #{team_member.uid} course #{course_site_code} at index #{index}" do
                        expect(visible_section_units).to eql(section[:units])
                        expect(visible_section_units.empty?).to be false
                      end

                      it "shows the section grading basis for #{team.name} UID #{team_member.uid} course #{course_site_code} at index #{index}" do
                        expect(visible_section_grading_basis).to eql(section[:grading_basis])
                        expect(visible_section_grading_basis.empty?).to be false
                      end

                      # ANALYTICS - page view

                      page_views_analytics = user_analytics_data.site_page_views(course)
                      site_page_view_analytics = user_analytics_data.site_statistics page_views_analytics

                      if user_analytics_data.student_percentile(page_views_analytics)
                        no_data = @boac_student_page.no_page_view_data? course_site_code
                        it "shows no page view data for #{team.name} UID #{team_member.uid} course #{course_site_code} at index #{index}" do
                          expect(no_data).to be true
                        end
                      else
                        visible_page_view_analytics = @boac_student_page.visible_page_view_analytics(@driver, course_site_code)
                        it "shows the page view analytics for #{team.name} UID #{team_member.uid} course #{course_site_code} at index #{index}" do
                          expect(visible_page_view_analytics).to eql(site_page_view_analytics)
                        end
                      end

                      # ANALYTICS - assignments on time

                      assignments_on_time_analytics = user_analytics_data.site_assignments_on_time(course)
                      site_assignment_analytics = user_analytics_data.site_statistics assignments_on_time_analytics

                      if user_analytics_data.student_percentile(assignments_on_time_analytics)
                        no_data = @boac_student_page.no_assignment_data? course_site_code
                        it "shows no assignments on time data for #{team.name} UID #{team_member.uid} course #{course_site_code} at index #{index}" do
                          expect(no_data).to be true
                        end
                      else
                        visible_assignment_analytics = @boac_student_page.visible_assignment_analytics(@driver, course_site_code)
                        it "shows the assignments on time analytics for #{team.name} UID #{team_member.uid} course #{course_site_code} at index #{index}" do
                          expect(visible_assignment_analytics).to eql(site_assignment_analytics)
                        end
                      end

                      # ANALYTICS - participations

                      participation_analytics = user_analytics_data.site_participations(course)
                      site_participation_analytics = user_analytics_data.site_statistics participation_analytics

                      if user_analytics_data.student_percentile(participation_analytics)
                        no_data = @boac_student_page.no_participations_data? course_site_code
                        it "shows no participations data for #{team.name} UID #{team_member.uid} course #{course_site_code} at index #{index}" do
                          expect(no_data).to be true
                        end
                      else
                        visible_participation_analytics = @boac_student_page.visible_participation_analytics(@driver, course_site_code)
                        it "shows the participations analytics for #{team.name} UID #{team_member.uid} course #{course_site_code} at index #{index}" do
                          expect(visible_participation_analytics).to eql(site_participation_analytics)
                        end
                      end

                    rescue => e
                      Utils.log_error e
                      it("encountered an error for #{team.name} UID #{team_member.uid} course #{course_site_code}") { fail }
                    ensure
                      row = [team_member.uid, team.name, course_site_code, user_analytics_data.course_site_name(course),
                            section[:ccn], section[:number], section[:grade], section[:grading_basis], section[:units], section[:enrollment_status],
                            site_page_view_analytics, site_assignment_analytics, site_participation_analytics]
                      Utils.add_csv_row(user_course_data, row)
                    end
                  end
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
