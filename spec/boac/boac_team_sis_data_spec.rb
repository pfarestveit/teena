require_relative '../../util/spec_helper'

include Logging

describe 'BOAC' do

  begin

    test = BOACTestConfig.new
    all_students = NessieUtils.get_all_students
    test.team_sis_data all_students
    teams = NessieUtils.get_asc_teams
    team = Team::TEAMS.find { |t| t.code == BOACUtils.sis_data_team }
    test.default_cohort.name = team.name

    # Create files for test output
    user_profile_data_heading = %w(UID Sport Name PreferredName Email Phone Units GPA Level Colleges Majors Terms Writing History Institutions Cultures Graduation Alerts)
    user_profile_sis_data = Utils.create_test_output_csv('boac-sis-profiles.csv', user_profile_data_heading)

    user_course_data_heading = %w(UID Sport Term CourseCode CourseName SectionCcn SectionCode Primary? Midpoint Grade GradingBasis Units EnrollmentStatus)
    user_course_sis_data = Utils.create_test_output_csv('boac-sis-courses.csv', user_course_data_heading)

    @driver = Utils.launch_browser
    @boac_homepage = Page::BOACPages::HomePage.new @driver
    @boac_teams_list_page = Page::BOACPages::TeamsListPage.new @driver
    @boac_cohort_page = Page::BOACPages::CohortPages::FilteredCohortPage.new @driver
    @boac_student_page = Page::BOACPages::StudentPage.new @driver

    @boac_homepage.dev_auth test.advisor
    @boac_homepage.click_teams_list

    expected_team_names = teams.map &:name
    visible_team_names = @boac_teams_list_page.teams
    it('shows all the expected teams') { expect(visible_team_names.sort).to eql(expected_team_names.sort) }

    if visible_team_names.include? test.default_cohort.name
      begin

        team_members = test.cohort_members.sort_by! &:full_name
        logger.debug "There are #{team_members.length} total athletes"
        team_members.keep_if &:active_asc
        logger.debug "There are #{team_members.length} active athletes"

        @boac_teams_list_page.load_page
        @boac_teams_list_page.click_team_link test.default_cohort
        team_url = @boac_cohort_page.current_url
        @boac_cohort_page.wait_for_team team_members.length

        expected_team_member_names = (team_members.map { |u| "#{u.last_name}, #{u.first_name}" }).sort
        visible_team_member_names = (@boac_cohort_page.list_view_names).sort
        it("shows all the expected players for #{test.default_cohort.name}") do
          logger.debug "Expecting #{expected_team_member_names} and got #{visible_team_member_names}"
          expect(visible_team_member_names).to eql(expected_team_member_names)
        end
        it("shows no blank player names for #{test.default_cohort.name}") { expect(visible_team_member_names.any? &:empty?).to be false }

        expected_team_member_sids = (team_members.map &:sis_id).sort
        visible_team_member_sids = (@boac_cohort_page.list_view_sids).sort
        it("shows all the expected player SIDs for #{test.default_cohort.name}") do
          logger.debug "Expecting #{expected_team_member_sids} and got #{visible_team_member_sids}"
          expect(visible_team_member_sids).to eql(expected_team_member_sids)
        end
        it("shows no blank player SIDs for #{test.default_cohort.name}") { expect(visible_team_member_sids.any? &:empty?).to be false }

        team_members.each do |team_member|
          if visible_team_member_sids.include? team_member.sis_id
            begin

              user_analytics_data = ApiUserAnalyticsPage.new @driver
              user_analytics_data.get_data(@driver, team_member)
              analytics_api_sis_data = user_analytics_data.user_sis_data

              # COHORT PAGE SIS DATA

              @boac_cohort_page.navigate_to team_url
              cohort_page_sis_data = @boac_cohort_page.visible_sis_data(@driver, team_member)

              it "shows the level for UID #{team_member.uid} on the #{test.default_cohort.name} page" do
                expect(cohort_page_sis_data[:level]).to eql(analytics_api_sis_data[:level])
                expect(cohort_page_sis_data[:level]).not_to be_empty
              end

              it "shows the majors for UID #{team_member.uid} on the #{test.default_cohort.name} page" do
                expect(cohort_page_sis_data[:majors]).to eql(analytics_api_sis_data[:majors].sort)
                expect(cohort_page_sis_data[:majors]).not_to be_empty
              end

              it "shows the cumulative GPA for UID #{team_member.uid} on the #{test.default_cohort.name} page" do
                expect(cohort_page_sis_data[:gpa]).to eql(analytics_api_sis_data[:cumulative_gpa])
                expect(cohort_page_sis_data[:gpa]).not_to be_empty
              end

              it "shows the units in progress for UID #{team_member.uid} on the #{test.default_cohort.name} page" do
                expect(cohort_page_sis_data[:units_in_progress]).to eql(analytics_api_sis_data[:units_in_progress])
                expect(cohort_page_sis_data[:units_in_progress]).not_to be_empty
              end

              it "shows the total units for UID #{team_member.uid} on the #{test.default_cohort.name} page" do
                expect(cohort_page_sis_data[:units_cumulative]).to eql(analytics_api_sis_data[:cumulative_units])
                expect(cohort_page_sis_data[:units_cumulative]).not_to be_empty
              end

              it("shows the current term course codes for UID #{team_member.uid} on the #{test.default_cohort.name} page") { expect(cohort_page_sis_data[:classes]).to eql(user_analytics_data.current_enrolled_course_codes) }

              # STUDENT PAGE SIS DATA

              @boac_cohort_page.click_student_link team_member
              @boac_student_page.wait_for_title(team_member.full_name)

              # Pause a moment to let the boxplots do their fancy slidey thing
              sleep 1

              student_page_sis_data = @boac_student_page.visible_sis_data

              it("shows the name for UID #{team_member.uid} on the student page") { expect(student_page_sis_data[:name]).to eql(team_member.full_name.split(',').reverse.join(' ').strip) }

              it "shows the email for UID #{team_member.uid} on the student page" do
                expect(student_page_sis_data[:email]).to eql(analytics_api_sis_data[:email])
                expect(student_page_sis_data[:email]).not_to be_empty
              end

              it "shows the total units for UID #{team_member.uid} on the student page" do
                expect(student_page_sis_data[:cumulative_units]).to eql(analytics_api_sis_data[:cumulative_units])
                expect(student_page_sis_data[:cumulative_units]).not_to be_empty
              end

              it "shows the phone for UID #{team_member.uid} on the student page" do
                expect(student_page_sis_data[:phone]).to eql(analytics_api_sis_data[:phone])
              end

              it "shows the cumulative GPA for UID #{team_member.uid} on the student page" do
                expect(student_page_sis_data[:cumulative_gpa]).to eql(analytics_api_sis_data[:cumulative_gpa])
                expect(student_page_sis_data[:cumulative_gpa]).not_to be_empty
              end

              it "shows the majors for UID #{team_member.uid} on the student page" do
                expect(student_page_sis_data[:majors]).to eql(analytics_api_sis_data[:majors])
                expect(student_page_sis_data[:majors]).not_to be_empty
              end

              analytics_api_sis_data[:colleges] ?
                  (it("shows the colleges for UID #{team_member.uid} on the student page") { expect(student_page_sis_data[:colleges]).to eql(analytics_api_sis_data[:colleges]) }) :
                  (it("shows no colleges for UID #{team_member.uid} on the student page") { expect(student_page_sis_data[:colleges]).to be_empty })

              it "shows the academic level for UID #{team_member.uid} on the student page" do
                expect(student_page_sis_data[:level]).to eql(analytics_api_sis_data[:level])
                expect(student_page_sis_data[:level]).not_to be_empty
              end

              (analytics_api_sis_data[:terms_in_attendance] && analytics_api_sis_data[:level] != 'Graduate') ?
                  (it("shows the terms in attendance for UID #{team_member.uid} on the student page") { expect(student_page_sis_data[:terms_in_attendance]).to include(analytics_api_sis_data[:terms_in_attendance]) }) :
                  (it("shows no terms in attendance for UID #{team_member.uid} on the student page") { expect(student_page_sis_data[:terms_in_attendance]).to be_nil })

              analytics_api_sis_data[:level] == 'Graduate' ?
                  (it("shows no expected graduation date for UID #{team_member.uid} on the #{test.default_cohort.name} page") { expect(student_page_sis_data[:expected_graduation]).to be nil }) :
                  (it("shows the expected graduation date for UID #{team_member.uid} on the #{test.default_cohort.name} page") { expect(student_page_sis_data[:expected_graduation]).to eql(analytics_api_sis_data[:expected_graduation]) })

              it("shows the Entry Level Writing Requirement for UID #{team_member.uid} on the student page") { expect(student_page_sis_data[:reqt_writing]).to eql(analytics_api_sis_data[:reqt_writing]) }
              it("shows the American History Requirement for UID #{team_member.uid} on the student page") { expect(student_page_sis_data[:reqt_history]).to eql(analytics_api_sis_data[:reqt_history]) }
              it("shows the American Institutions Requirement for UID #{team_member.uid} on the student page") { expect(student_page_sis_data[:reqt_institutions]).to eql(analytics_api_sis_data[:reqt_institutions]) }
              it("shows the American Cultures Requirement for UID #{team_member.uid} on the student page") { expect(student_page_sis_data[:reqt_cultures]).to eql(analytics_api_sis_data[:reqt_cultures]) }

              # ALERTS

              alerts = BOACUtils.get_students_alerts [team_member]
              alert_msgs = (alerts.map &:message).sort

              dismissed = BOACUtils.get_dismissed_alerts(alerts).map &:message
              non_dismissed = alert_msgs - dismissed
              logger.info "UID #{team_member.uid} alert count is #{alert_msgs.length}, with #{dismissed.length} dismissed"

              if non_dismissed.any?
                non_dismissed_visible = @boac_student_page.non_dismissed_alert_msg_elements.all? &:visible?
                non_dismissed_present = @boac_student_page.non_dismissed_alert_msgs.sort
                it("has the non-dismissed alert messages for UID #{team_member.uid} on the student page") { expect(non_dismissed_present).to eql(non_dismissed) }
                it("shows the non-dismissed alert messages for UID #{team_member.uid} on the student page") { expect(non_dismissed_visible).to be true }
              end

              if dismissed.any?
                dismissed_visible = @boac_student_page.dismissed_alert_msg_elements.any? &:visible?
                dismissed_present = @boac_student_page.dismissed_alert_msgs.sort
                it("has the dismissed alert messages for UID #{team_member.uid} on the student page") { expect(dismissed_present).to eql(dismissed) }
                it("hides the dismissed alert messages for UID #{team_member.uid} on the student page") { expect(dismissed_visible).to be false }
              end

              # TERMS

              terms = user_analytics_data.terms
              if terms.any?
                if terms.length > 1
                  @boac_student_page.click_view_previous_semesters
                else
                  has_view_more_button = @boac_student_page.view_more_button_element.visible?
                  it("shows no View Previous Semesters button for UID #{team_member.uid} on the student page") { expect(has_view_more_button).to be false }
                end

                terms.each do |term|
                  begin

                    term_name = user_analytics_data.term_name term
                    logger.info "Checking #{term_name}"

                    courses = user_analytics_data.courses term

                    # COURSES

                    term_section_ccns = []

                    if courses.any?
                      courses.each do |course|
                        begin

                          course_sis_data = user_analytics_data.course_sis_data course
                          course_code = course_sis_data[:code]

                          logger.info "Checking course #{course_code}"

                          @boac_student_page.expand_course_data(term_name, course_code)

                          visible_course_sis_data = @boac_student_page.visible_course_sis_data(term_name, course_code)
                          visible_course_title = visible_course_sis_data[:title]
                          visible_units = visible_course_sis_data[:units_completed]
                          visible_grading_basis = visible_course_sis_data[:grading_basis]
                          visible_midpoint = visible_course_sis_data[:mid_point_grade]
                          visible_grade = visible_course_sis_data[:grade]

                          it "shows the course title for UID #{team_member.uid} term #{term_name} course #{course_code}" do
                            expect(visible_course_title).not_to be_empty
                            expect(visible_course_title).to eql(course_sis_data[:title])
                          end

                          if course_sis_data[:units_completed].to_f > 0
                            it "shows the units for UID #{team_member.uid} term #{term_name} course #{course_code}" do
                              expect(visible_units).not_to be_empty
                              expect(visible_units).to eql(course_sis_data[:units_completed])
                            end
                          else
                            it "shows no units for UID #{team_member.uid} term #{term_name} course #{course_code}" do
                              expect(visible_units).to be_empty
                            end
                          end

                          if course_sis_data[:grading_basis] == 'NON' || !course_sis_data[:grade].empty?
                            it "shows no grading basis for UID #{team_member.uid} term #{term_name} course #{course_code}" do
                              expect(visible_grading_basis).to be_nil
                            end
                          else
                            it "shows the grading basis for UID #{team_member.uid} term #{term_name} course #{course_code}" do
                              expect(visible_grading_basis).not_to be_empty
                              expect(visible_grading_basis).to eql(course_sis_data[:grading_basis])
                            end
                          end

                          if course_sis_data[:grade].empty?
                            it "shows no grade for UID #{team_member.uid} term #{term_name} course #{course_code}" do
                              expect(visible_grade).to be_nil
                            end
                          else
                            it "shows the grade for UID #{team_member.uid} term #{term_name} course #{course_code}" do
                              expect(visible_grade).not_to be_empty
                              expect(visible_grade).to eql(course_sis_data[:grade])
                            end
                          end

                          if course_sis_data[:midpoint] && term_name == BOACUtils.term
                            it "shows the midpoint grade for UID #{team_member.uid} term #{term_name} course #{course_code}" do
                              expect(visible_midpoint).not_to be_empty
                              expect(visible_midpoint).to eql(course_sis_data[:midpoint])
                            end
                          else
                            it "shows no midpoint grade for UID #{team_member.uid} term #{term_name} course #{course_code}" do
                              expect(visible_midpoint).to be_nil
                            end
                          end

                          # SECTIONS

                          sections = user_analytics_data.sections course
                          sections.each do |section|
                            begin

                              index = sections.index section
                              section_sis_data = user_analytics_data.section_sis_data section
                              term_section_ccns << section_sis_data[:ccn]
                              component = section_sis_data[:component]

                              visible_section_sis_data = @boac_student_page.visible_section_sis_data(term_name, course_code, index)
                              visible_section = visible_section_sis_data[:section]
                              visible_wait_list_status = visible_course_sis_data[:wait_list]

                              it "shows the section number for UID #{team_member.uid} term #{term_name} course #{course_code} section #{component}" do
                                expect(visible_section).not_to be_empty
                                expect(visible_section).to eql("#{section_sis_data[:component]} #{section_sis_data[:number]}")
                              end

                              if section_sis_data[:status] == 'W'
                                it "shows the wait list status for UID #{team_member.uid} term #{term_name} course #{course_code}" do
                                  expect(visible_wait_list_status).to be true
                                end
                              else
                                it "shows no enrollment status for UID #{team_member.uid} term #{term_name} course #{course_code}" do
                                  expect(visible_wait_list_status).to be false
                                end
                              end

                            rescue => e
                              BOACUtils.log_error_and_screenshot(@driver, e, "#{team_member.uid}-#{term_name}-#{course_code}-#{section_sis_data[:ccn]}")
                              it("encountered an error for UID #{team_member.uid} term #{term_name} course #{course_code} section #{section_sis_data[:ccn]}") { fail }
                            ensure
                              row = [team_member.uid, test.default_cohort.name, term_name, course_code, course_sis_data[:title], section_sis_data[:ccn], "#{section_sis_data[:component]} #{section_sis_data[:number]}",
                                     section_sis_data[:primary], course_sis_data[:midpoint], course_sis_data[:grade], course_sis_data[:grading_basis], course_sis_data[:units_completed], section_sis_data[:status]]
                              Utils.add_csv_row(user_course_sis_data, row)
                            end
                          end

                        rescue => e
                          BOACUtils.log_error_and_screenshot(@driver, e, "#{team_member.uid}-#{term_name}-#{course_code}")
                          it("encountered an error for UID #{team_member.uid} term #{term_name} course #{course_code}") { fail }
                        end
                      end

                      it("shows no dupe courses for UID #{team_member.uid} in term #{term_name}") { expect(term_section_ccns).to eql(term_section_ccns.uniq) }

                    else
                      logger.warn "No course data in #{term_name}"
                    end

                    # DROPPED SECTIONS

                    drops = user_analytics_data.dropped_sections term
                    if drops
                      drops.each do |drop|
                        visible_drop = @boac_student_page.visible_dropped_section_data(term_name, drop[:title], drop[:component], drop[:number])
                        (term_name == BOACUtils.term) ?
                            (it("shows dropped section #{drop[:title]} #{drop[:component]} #{drop[:number]} for UID #{team_member.uid} in #{term_name}") { expect(visible_drop).to be_truthy }) :
                            (it("shows no dropped section #{drop[:title]} #{drop[:component]} #{drop[:number]} for UID #{team_member.uid} in past term #{term_name}") { expect(visible_drop).to be_falsey })

                        row = [team_member.uid, test.default_cohort.name, term_name, drop[:title], nil, nil, drop[:number], nil, nil, nil, 'D']
                        Utils.add_csv_row(user_course_sis_data, row)
                      end
                    end

                  rescue => e
                    BOACUtils.log_error_and_screenshot(@driver, e, "#{team_member.uid}-#{term_name}")
                    it("encountered an error for UID #{team_member.uid} term #{term_name}") { fail }
                  end
                end

              else
                logger.warn "UID #{team_member.uid} has no term data"
              end

            rescue => e
              BOACUtils.log_error_and_screenshot(@driver, e, "#{team_member.uid}")
              it("encountered an error for UID #{team_member.uid}") { fail }
            ensure
              if analytics_api_sis_data
                row = [team_member.uid, test.default_cohort.name, student_page_sis_data[:name], student_page_sis_data[:preferred_name], student_page_sis_data[:email],
                       student_page_sis_data[:phone], student_page_sis_data[:cumulative_units], student_page_sis_data[:cumulative_gpa], student_page_sis_data[:level],
                       student_page_sis_data[:colleges] && student_page_sis_data[:colleges] * '; ', student_page_sis_data[:majors] && student_page_sis_data[:majors] * '; ',
                       student_page_sis_data[:terms_in_attendance], student_page_sis_data[:reqt_writing], student_page_sis_data[:reqt_history],
                       student_page_sis_data[:reqt_institutions], student_page_sis_data[:reqt_cultures], student_page_sis_data[:expected_graduation], alert_msgs]
                Utils.add_csv_row(user_profile_sis_data, row)
              end
            end

          else
            logger.warn "Skipping #{test.default_cohort.name} UID #{team_member.uid} because it is not present in the UI"
          end
        end

      rescue => e
        BOACUtils.log_error_and_screenshot(@driver, e, test.default_cohort.name)
        it("encountered an error for #{test.default_cohort.name}") { fail }
      end

    else
      logger.warn "Skipping #{test.default_cohort.name} because there is no link for it"
    end

  rescue => e
    Utils.log_error e
    it('encountered an error') { fail }
  ensure
    Utils.quit_browser @driver
  end
end
