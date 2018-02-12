require_relative '../../util/spec_helper'

include Logging

describe 'BOAC' do

  begin

    # Optionally, specify a string of comma separated of team codes to test; otherwise, all teams will be tested
    teams_to_test = ENV['TEAMS']

    # Create files for test output
    user_profile_sis_data = File.join(Utils.initialize_test_output_dir, 'boac-sis-profiles.csv')
    user_profile_data_heading = %w(UID Sport Name PreferredName Email Phone Units GPA Level Majors Colleges Terms Writing History Institutions Cultures)
    CSV.open(user_profile_sis_data, 'wb') { |csv| csv << user_profile_data_heading }

    user_course_sis_data = File.join(Utils.initialize_test_output_dir, 'boac-sis-courses.csv')
    user_course_data_heading = %w(UID Sport Term CourseCode CourseName SectionCcn SectionNumber Midpoint Grade GradingBasis Units EnrollmentStatus)
    CSV.open(user_course_sis_data, 'wb') { |csv| csv << user_course_data_heading }

    user_course_canvas_data = File.join(Utils.initialize_test_output_dir, 'boac-canvas-courses.csv')
    user_canvas_data_heading = %w(UID Sport Term CourseCode SiteCode Assignments Grades PageViews Participations)
    CSV.open(user_course_canvas_data, 'wb') { |csv| csv << user_canvas_data_heading }

    # Get all teams and athletes
    teams = BOACUtils.get_teams

    @driver = Utils.launch_browser
    @boac_homepage = Page::BOACPages::HomePage.new @driver
    @boac_cohort_page = Page::BOACPages::CohortListViewPage.new @driver
    @boac_student_page = Page::BOACPages::StudentPage.new @driver

    @boac_homepage.dev_auth

    expected_team_names = teams.map &:name
    visible_team_names = @boac_homepage.teams
    it('shows all the expected teams') { expect(visible_team_names.sort).to eql(expected_team_names.sort) }

    teams.select! { |t| teams_to_test.split(',').include? t.code } if teams_to_test

    teams.each do |team|
      if visible_team_names.include? team.name
        begin

          all_team_members = BOACUtils.get_team_members(team).sort_by! &:full_name
          active_team_members = all_team_members.delete_if { |u| u.status == 'inactive' }
          logger.debug "There are #{active_team_members.length} active athletes out of #{all_team_members.length} total athletes"

          @boac_homepage.load_page
          @boac_homepage.click_team_link team
          team_url = @boac_cohort_page.current_url
          @boac_cohort_page.wait_for_page_load active_team_members.length

          expected_team_member_names = (active_team_members.map &:full_name).sort
          visible_team_member_names = (@boac_cohort_page.list_view_names).sort
          it("shows all the expected players for #{team.name}") do
            logger.debug "Expecting #{expected_team_member_names} and got #{visible_team_member_names}"
            expect(visible_team_member_names).to eql(expected_team_member_names)
          end
          it("shows no blank player names for #{team.name}") { expect(visible_team_member_names.any? &:empty?).to be false }

          expected_team_member_sids = (active_team_members.map &:sis_id).sort
          visible_team_member_sids = (@boac_cohort_page.list_view_sids).sort
          it("shows all the expected player SIDs for #{team.name}") do
            logger.debug "Expecting #{expected_team_member_sids} and got #{visible_team_member_sids}"
            expect(visible_team_member_sids).to eql(expected_team_member_sids)
          end
          it("shows no blank player SIDs for #{team.name}") { expect(visible_team_member_sids.any? &:empty?).to be false }

          active_team_members.each do |team_member|
            if visible_team_member_sids.include? team_member.sis_id
              begin

                user_analytics_data = ApiUserAnalyticsPage.new @driver
                user_analytics_data.get_data(@driver, team_member)
                analytics_api_sis_data = user_analytics_data.user_sis_data

                # COHORT PAGE SIS DATA

                @boac_cohort_page.navigate_to team_url
                cohort_page_sis_data = @boac_cohort_page.visible_sis_data(@driver, team_member)

                it "shows the level for UID #{team_member.uid} on the #{team.name} page" do
                  expect(cohort_page_sis_data[:level]).to eql(analytics_api_sis_data[:level])
                  expect(cohort_page_sis_data[:level]).not_to be_empty
                end

                it "shows the majors for UID #{team_member.uid} on the #{team.name} page" do
                  expect(cohort_page_sis_data[:majors]).to eql(analytics_api_sis_data[:majors].sort)
                  expect(cohort_page_sis_data[:majors]).not_to be_empty
                end

                it "shows the cumulative GPA for UID #{team_member.uid} on the #{team.name} page" do
                  expect(cohort_page_sis_data[:gpa]).to eql(analytics_api_sis_data[:cumulative_gpa])
                  expect(cohort_page_sis_data[:gpa]).not_to be_empty
                end

                it "shows the units in progress for UID #{team_member.uid} on the #{team.name} page" do
                  expect(cohort_page_sis_data[:units_in_progress]).to eql(analytics_api_sis_data[:units_in_progress])
                  expect(cohort_page_sis_data[:units_in_progress]).not_to be_empty
                end

                it "shows the total units for UID #{team_member.uid} on the #{team.name} page" do
                  expect(cohort_page_sis_data[:units_cumulative]).to eql(analytics_api_sis_data[:cumulative_units])
                  expect(cohort_page_sis_data[:units_cumulative]).not_to be_empty
                end

                it("shows the current term course codes for UID #{team_member.uid} on the #{team.name} page") { expect(cohort_page_sis_data[:classes]).to eql(user_analytics_data.current_enrolled_course_codes) }

                # TODO - site analytics on cohort page

                # STUDENT PAGE SIS DATA

                @boac_cohort_page.click_player_link team_member

                # Pause a moment to let the boxplots do their fancy slidey thing
                sleep 1

                student_page_sis_data = @boac_student_page.visible_sis_data

                it("shows the name for UID #{team_member.uid} on the student page") { expect(student_page_sis_data[:name]).to eql(team_member.full_name.split(',').reverse.join(' ').strip) }

                it "shows the email for UID #{team_member.uid} on the student page" do
                  expect(student_page_sis_data[:email]).to eql(analytics_api_sis_data[:email])
                  expect(student_page_sis_data[:email]).not_to be_empty
                end

                it "shows the phone for UID #{team_member.uid} on the student page" do
                  expect(student_page_sis_data[:phone]).to eql(analytics_api_sis_data[:phone])
                end

                it "shows the total units for UID #{team_member.uid} on the student page" do
                  expect(student_page_sis_data[:cumulative_units]).to eql(analytics_api_sis_data[:cumulative_units])
                  expect(student_page_sis_data[:cumulative_units]).not_to be_empty
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

                analytics_api_sis_data[:terms_in_attendance] ?
                    (it("shows the terms in attendance for UID #{team_member.uid} on the student page") { expect(student_page_sis_data[:terms_in_attendance]).to include(analytics_api_sis_data[:terms_in_attendance]) }) :
                    (it("shows no terms in attendance for UID #{team_member.uid} on the student page") { expect(student_page_sis_data[:terms_in_attendance]).to be_nil })

                it("shows the Entry Level Writing Requirement for UID #{team_member.uid} on the student page") { expect(student_page_sis_data[:reqt_writing]).to eql(analytics_api_sis_data[:reqt_writing]) }
                it("shows the American History Requirement for UID #{team_member.uid} on the student page") { expect(student_page_sis_data[:reqt_history]).to eql(analytics_api_sis_data[:reqt_history]) }
                it("shows the American Institutions Requirement for UID #{team_member.uid} on the student page") { expect(student_page_sis_data[:reqt_institutions]).to eql(analytics_api_sis_data[:reqt_institutions]) }
                it("shows the American Cultures Requirement for UID #{team_member.uid} on the student page") { expect(student_page_sis_data[:reqt_cultures]).to eql(analytics_api_sis_data[:reqt_cultures]) }

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

                      # Collect unmatched Canvas sites in the term as hashes with null course code
                      term_sites = []
                      term_sites << user_analytics_data.unmatched_sites(term).map { |s| {:course_code => nil, :data => s} }

                      courses = user_analytics_data.courses term

                      # COURSES

                      term_section_ccns = []

                      if courses.any?
                        courses.each do |course|
                          begin

                            course_sis_data = user_analytics_data.course_sis_data course
                            course_code = course_sis_data[:code]
                            course_sites = user_analytics_data.course_sites course

                            # Collect matched Canvas sites in the term as hashes with course codes
                            term_sites << course_sites.map { |s| {:course_code => course_code, :data => s, :index => course_sites.index(s)} }

                            logger.info "Checking course #{course_code}"

                            visible_course_sis_data = @boac_student_page.visible_course_sis_data(term_name, course_code)
                            visible_course_title = visible_course_sis_data[:title]
                            visible_units = visible_course_sis_data[:units]
                            visible_grading_basis = visible_course_sis_data[:grading_basis]
                            visible_midpoint = visible_course_sis_data[:mid_point_grade]
                            visible_grade = visible_course_sis_data[:grade]

                            it "shows the course title for UID #{team_member.uid} term #{term_name} course #{course_code}" do
                              expect(visible_course_title).not_to be_empty
                              expect(visible_course_title).to eql(course_sis_data[:title])
                            end

                            if course_sis_data[:units].to_f > 0
                              it "shows the units for UID #{team_member.uid} term #{term_name} course #{course_code}" do
                                expect(visible_units).not_to be_empty
                                expect(visible_units).to eql(course_sis_data[:units])
                              end
                            else
                              it "shows no units for UID #{team_member.uid} term #{term_name} course #{course_code}" do
                                expect(visible_units).to be_empty
                              end
                            end

                            if course_sis_data[:grading_basis] == 'NON' || course_sis_data[:grade]
                              it "shows no grading basis for UID #{team_member.uid} term #{term_name} course #{course_code}" do
                                expect(visible_grading_basis).to be_nil
                              end
                            else
                              it "shows the grading basis for UID #{team_member.uid} term #{term_name} course #{course_code}" do
                                expect(visible_grading_basis).not_to be_empty
                                expect(visible_grading_basis).to eql(course_sis_data[:grading_basis])
                              end
                            end

                            if course_sis_data[:grade]
                              it "shows the grade for UID #{team_member.uid} term #{term_name} course #{course_code}" do
                                expect(visible_grade).not_to be_empty
                                expect(visible_grade).to eql(course_sis_data[:grade])
                              end
                            else
                              it "shows no grade for UID #{team_member.uid} term #{term_name} course #{course_code}" do
                                expect(visible_grade).to be_nil
                              end
                            end

                            if course_sis_data[:midpoint]
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
                                visible_enrollment_status = visible_section_sis_data[:status]
                                visible_section_number = visible_section_sis_data[:number]

                                it "shows the section enrollment status for UID #{team_member.uid} term #{term_name} course #{course_code}" do
                                  case (section_sis_data[:status])
                                    when 'E'
                                      expect(visible_enrollment_status).to be_nil
                                    when 'W'
                                      expect(visible_enrollment_status).to eql('Waitlisted in')
                                    when 'D'
                                      expect(visible_enrollment_status).to eql('Dropped')
                                    else
                                      logger.error "Invalid course status #{section_sis_data[:status]} for UID #{team_member.uid} term #{term_name} course #{course_code} section #{component}"
                                      fail
                                  end
                                end

                                it "shows the section number for UID #{team_member.uid} term #{term_name} course #{course_code} section #{component}" do
                                  expect(visible_section_number).not_to be_empty
                                  expect(visible_section_number).to eql(section_sis_data[:number])
                                end

                              rescue => e
                                Utils.log_error e
                                it("encountered an error for UID #{team_member.uid} term #{term_name} course #{course_code} section #{section_sis_data[:ccn]}") { fail }
                              ensure
                                row = [team_member.uid, team.name, term_name, course_code, course_sis_data[:title], section_sis_data[:ccn], section_sis_data[:number],
                                       course_sis_data[:midpoint], course_sis_data[:grade], course_sis_data[:grading_basis], course_sis_data[:units], section_sis_data[:status]]
                                Utils.add_csv_row(user_course_sis_data, row)
                              end
                            end

                          rescue => e
                            Utils.log_error e
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
                          it("shows dropped section #{drop[:title]} #{drop[:component]} #{drop[:number]} for UID #{team_member.uid} in #{term_name}") { expect(visible_drop).to be_truthy }

                          row = [team_member.uid, team.name, term_name, drop[:title], nil, nil, drop[:number], nil, nil, nil, 'D']
                          Utils.add_csv_row(user_course_sis_data, row)
                        end
                      end

                      # CANVAS SITE ANALYTICS

                      term_sites.flatten.each do |site|

                        begin

                          site_data = site[:data]
                          site_assignment_analytics, site_grades_analytics, site_page_view_analytics = nil
                          site_code = user_analytics_data.site_metadata(site_data)[:code]

                          # Find the site in the UI differently if it's matched versus unmatched
                          site[:course_code] ?
                              (analytics_xpath = @boac_student_page.course_site_xpath(term_name, site[:course_code], site[:index])) :
                              (analytics_xpath = @boac_student_page.unmatched_site_xpath(term_name, site_code))
                          logger.info "Checking course site #{site_code}"

                          # Gather the expected analytics data
                          site_assignment_analytics = user_analytics_data.site_assignments_on_time(site_data)
                          site_grades_analytics = user_analytics_data.site_grades(site_data)
                          site_page_view_analytics = user_analytics_data.site_page_views(site_data)

                          # Compare to what's shown in the UI
                          [site_assignment_analytics, site_grades_analytics, site_page_view_analytics].each do |api_analytics|

                            if api_analytics[:user_percentile].nil?
                              no_data = @boac_student_page.no_data?(analytics_xpath, api_analytics[:type])
                              it "shows no '#{api_analytics[:type]}' data for UID #{team_member.uid} term #{term_name} course site #{site_code}" do
                                expect(no_data).to be true
                              end
                            else
                              visible_analytics = case api_analytics[:type]
                                                    when 'Assignments on Time'
                                                      @boac_student_page.visible_assignment_analytics(@driver, analytics_xpath, api_analytics)
                                                    when 'Assignment Grades'
                                                      @boac_student_page.visible_grades_analytics(@driver, analytics_xpath, api_analytics)
                                                    when 'Page Views'
                                                      @boac_student_page.visible_page_view_analytics(@driver, analytics_xpath, api_analytics)
                                                    else
                                                      logger.error "Unsupported analytics type '#{api_analytics[:type]}'"
                                                  end

                              it "shows the '#{api_analytics[:type]}' user percentile for UID #{team_member.uid} term #{term_name} course site #{site_code}" do
                                expect(visible_analytics[:user_percentile]).to eql(api_analytics[:user_percentile])
                              end
                              it "shows the '#{api_analytics[:type]}' user score for UID #{team_member.uid} term #{term_name} course site #{site_code}" do
                                expect(visible_analytics[:user_score]).to eql(api_analytics[:user_score])
                              end
                              it "shows the '#{api_analytics[:type]}' course maximum for UID #{team_member.uid} term #{term_name} course site #{site_code}" do
                                expect(visible_analytics[:maximum]).to eql(api_analytics[:maximum])
                              end

                              if api_analytics[:graphable]
                                it "shows the '#{api_analytics[:type]}' course 70th percentile for UID #{team_member.uid} term #{term_name} course site #{site_code}" do
                                  expect(visible_analytics[:percentile_70]).to eql(api_analytics[:percentile_70])
                                end
                                it "shows the '#{api_analytics[:type]}' course 50th percentile for UID #{team_member.uid} term #{term_name} course site #{site_code}" do
                                  expect(visible_analytics[:percentile_50]).to eql(api_analytics[:percentile_50])
                                end
                                it "shows the '#{api_analytics[:type]}' course 30th percentile for UID #{team_member.uid} term #{term_name} course site #{site_code}" do
                                  expect(visible_analytics[:percentile_30]).to eql(api_analytics[:percentile_30])
                                end
                                it "shows the '#{api_analytics[:type]}' course minimum for UID #{team_member.uid} term #{term_name} course site #{site_code}" do
                                  expect(visible_analytics[:minimum]).to eql(api_analytics[:minimum])
                                end
                              else
                                it "shows no '#{api_analytics[:type]}' course 70th percentile for UID #{team_member.uid} term #{term_name} course site #{site_code}" do
                                  expect(visible_analytics[:percentile_70]).to be_nil
                                end
                                it "shows no '#{api_analytics[:type]}' course 50th percentile for UID #{team_member.uid} term #{term_name} course site #{site_code}" do
                                  expect(visible_analytics[:percentile_50]).to be_nil
                                end
                                it "shows no '#{api_analytics[:type]}' course 30th percentile for UID #{team_member.uid} term #{term_name} course site #{site_code}" do
                                  expect(visible_analytics[:percentile_30]).to be_nil
                                end
                                it "shows no '#{api_analytics[:type]}' course minimum for UID #{team_member.uid} term #{term_name} course site #{site_code}" do
                                  expect(visible_analytics[:minimum]).to be_nil
                                end
                              end
                            end
                          end

                        rescue => e
                          Utils.log_error e
                          it("encountered an error for UID #{team_member.uid} term #{term_name} site #{site_code}") { fail }
                        ensure
                          row = [team_member.uid, team.name, term_name, site[:course_code], site_code,
                                 site_assignment_analytics, site_grades_analytics, site_page_view_analytics]
                          Utils.add_csv_row(user_course_canvas_data, row)
                        end
                      end
                    rescue => e
                      Utils.log_error e
                      it("encountered an error for UID #{team_member.uid} term #{term_name}") { fail }
                    end
                  end

                else
                  logger.warn "UID #{team_member.uid} has no term data"
                end

              rescue => e
                Utils.log_error e
                it("encountered an error for UID #{team_member.uid}") { fail }
              ensure
                if analytics_api_sis_data
                  row = [team_member.uid, team.name, student_page_sis_data[:name], student_page_sis_data[:preferred_name], student_page_sis_data[:email],
                         student_page_sis_data[:phone], student_page_sis_data[:cumulative_units], student_page_sis_data[:cumulative_gpa], student_page_sis_data[:level],
                         student_page_sis_data[:colleges] && student_page_sis_data[:colleges] * '; ', student_page_sis_data[:majors] && student_page_sis_data[:majors] * '; ',
                         student_page_sis_data[:terms_in_attendance], student_page_sis_data[:reqt_writing], student_page_sis_data[:reqt_history],
                         student_page_sis_data[:reqt_institutions], student_page_sis_data[:reqt_cultures]]
                  Utils.add_csv_row(user_profile_sis_data, row)
                end
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
