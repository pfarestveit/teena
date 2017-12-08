require_relative '../../util/spec_helper'

include Logging

describe 'BOAC' do

  begin

    # Optionally, specify a string of comma separated of team codes to test; otherwise, all teams will be tested
    teams_to_test = ENV['TEAMS']

    # Create files for test output
    user_profile_sis_data = File.join(Utils.initialize_test_output_dir, 'boac-sis-profiles.csv')
    user_profile_data_heading = %w(UID Sport Name Email Phone Units GPA Colleges Majors Level Writing History Institutions Cultures Language)
    CSV.open(user_profile_sis_data, 'wb') { |csv| csv << user_profile_data_heading }

    user_course_sis_data = File.join(Utils.initialize_test_output_dir, 'boac-sis-courses.csv')
    user_course_data_heading = %w(UID Sport Term CourseCode CourseName SectionCcn SectionNumber Grade GradingBasis Units EnrollmentStatus)
    CSV.open(user_course_sis_data, 'wb') { |csv| csv << user_course_data_heading }

    user_course_canvas_data = File.join(Utils.initialize_test_output_dir, 'boac-canvas-courses.csv')
    user_canvas_data_heading = %w(UID Sport Term CourseCode CourseName SiteTitle PageViews Assignments Participations)
    CSV.open(user_course_canvas_data, 'wb') { |csv| csv << user_canvas_data_heading }

    # Get all teams and athletes
    athletes = BOACUtils.get_athletes
    teams = BOACUtils.get_teams

    @driver = Utils.launch_browser
    @boac_homepage = Page::BOACPages::HomePage.new @driver
    @boac_cohort_page = Page::BOACPages::CohortPage.new @driver
    @boac_student_page = Page::BOACPages::StudentPage.new @driver

    @boac_homepage.dev_auth(Utils.super_admin_uid)

    expected_team_names = teams.map &:name
    visible_team_names = @boac_homepage.teams
    it('shows all the expected teams') { expect(visible_team_names.sort).to eql(expected_team_names.sort) }

    teams.select! { |t| teams_to_test.split(',').include? t.code } if teams_to_test

    teams.each do |team|
      if visible_team_names.include? team.name
        begin

          expected_team_members = BOACUtils.get_team_members(team, athletes).sort_by! &:full_name

          @boac_homepage.load_page
          @boac_homepage.click_team_link team
          team_url = @boac_cohort_page.current_url

          expected_team_member_names = expected_team_members.map &:full_name
          expected_team_member_sids = expected_team_members.map &:sis_id

          visible_team_member_names = @boac_cohort_page.team_player_names
          visible_team_member_sids = @boac_cohort_page.team_player_sids

          it("shows all the expected players for #{team.name}") { expect(visible_team_member_names).to eql(expected_team_member_names) }
          it("shows no blank player names for #{team.name}") { expect(visible_team_member_names.any? &:empty?).to be false }
          it("shows all the expected player UIDs for #{team.name}") { expect(visible_team_member_sids).to eql(expected_team_member_sids) }
          it("shows no blank player UIDs for #{team.name}") { expect(visible_team_member_sids.any? &:empty?).to be false }

          expected_team_members.each do |team_member|
            if visible_team_member_sids.include? team_member.sis_id
              begin

                user_analytics_data = ApiUserAnalyticsPage.new @driver
                user_analytics_data.get_data(@driver, team_member)

                @boac_cohort_page.navigate_to team_url
                @boac_cohort_page.click_player_link team_member

                # Pause a moment to let the boxplots do their fancy slidey thing
                sleep 2

                visible_name = @boac_student_page.name
                visible_email = @boac_student_page.email_element.text
                visible_phone = @boac_student_page.phone
                visible_cumulative_units = @boac_student_page.cumulative_units
                visible_cumulative_gpa = @boac_student_page.cumulative_gpa
                visible_majors = @boac_student_page.visible_majors
                visible_colleges = @boac_student_page.visible_colleges
                visible_level = @boac_student_page.level
                visible_writing_reqt = @boac_student_page.writing_reqt.strip
                visible_history_reqt = @boac_student_page.history_reqt.strip
                visible_institutions_reqt = @boac_student_page.institutions_reqt.strip
                visible_cultures_reqt = @boac_student_page.cultures_reqt.strip
                visible_language_reqt = @boac_student_page.language_reqt.strip

                it("shows the name for UID #{team_member.uid}") { expect(visible_name).to eql(team_member.full_name.split(',').reverse.join(' ').strip) }

                it "shows the email for UID #{team_member.uid}" do
                  expect(visible_email).to eql(user_analytics_data.email)
                  expect(visible_email.empty?).to be false
                end

                it "shows the phone for UID #{team_member.uid}" do
                  expect(visible_phone).to eql(user_analytics_data.phone)
                end

                it "shows the total units for UID #{team_member.uid}" do
                  expect(visible_cumulative_units).to eql(user_analytics_data.cumulative_units)
                  expect(visible_cumulative_units.empty?).to be false
                end

                it "shows the cumulative GPA for UID #{team_member.uid}" do
                  expect(visible_cumulative_gpa).to eql(user_analytics_data.cumulative_gpa)
                  expect(visible_cumulative_gpa.empty?).to be false
                end

                user_analytics_data.majors ?
                    (it("shows the majors for UID #{team_member.uid}") { expect(visible_majors).to eql(user_analytics_data.majors) }) :
                    (it("shows no majors for UID #{team_member.uid}") { expect(visible_majors).to be_empty })

                user_analytics_data.colleges ?
                    (it("shows the colleges for UID #{team_member.uid}") { expect(visible_colleges).to eql(user_analytics_data.colleges) }) :
                    (it("shows no colleges for UID #{team_member.uid}") { expect(visible_colleges).to be_empty })

                it "shows the academic level for UID #{team_member.uid}" do
                  expect(visible_level).to eql(user_analytics_data.level)
                  expect(visible_level.empty?).to be false
                end

                it "shows the Entry Level Writing Requirement for UID #{team_member.uid}" do
                  user_analytics_data.writing_reqt ?
                      (expect(visible_writing_reqt).to eql('Satisfied')) :
                      (expect(visible_writing_reqt).to eql('Not Satisfied'))
                end

                it "shows the American History Requirement for UID #{team_member.uid}" do
                  user_analytics_data.history_reqt ?
                      (expect(visible_history_reqt).to eql('Satisfied')) :
                      (expect(visible_history_reqt).to eql('Not Satisfied'))
                end

                it "shows the American Institutions Requirement for UID #{team_member.uid}" do
                  user_analytics_data.institutions_reqt ?
                      (expect(visible_institutions_reqt).to eql('Satisfied')) :
                      (expect(visible_institutions_reqt).to eql('Not Satisfied'))
                end

                it "shows the American Cultures Requirement for UID #{team_member.uid}" do
                  user_analytics_data.cultures_reqt ?
                      (expect(visible_cultures_reqt).to eql('Satisfied')) :
                      (expect(visible_cultures_reqt).to eql('Not Satisfied'))
                end

                # TODO - account for non-L & S
                it "shows the Foreign Languages Requirement for UID #{team_member.uid}" do
                  user_analytics_data.language_reqt ?
                      (expect(visible_language_reqt).to eql('Satisfied')) :
                      (expect(visible_language_reqt).to eql('Not Satisfied'))
                end

                # TERMS

                terms = user_analytics_data.terms

                if terms.any?
                  terms.each do |term|
                    begin

                      term_name = user_analytics_data.term_name term
                      courses = user_analytics_data.courses term

                      logger.info "Checking #{term_name}"

                      if courses.any?

                        term_section_ccns = []

                        # COURSES

                        courses.each do |course|
                          begin

                            site_page_view_analytics, site_assignment_analytics, site_participation_analytics = nil

                            course_sis_data = user_analytics_data.course_sis_data course
                            course_code = course_sis_data[:code]

                            logger.info "Checking course #{course_code}"

                            visible_course_title = @boac_student_page.course_title(term_name, course_code)

                            it "shows the course title for UID #{team_member.uid} term #{term_name} course #{course_code}" do
                              expect(visible_course_title).to eql(course_sis_data[:title])
                              expect(visible_course_title.empty?).to be false
                            end

                            sections = user_analytics_data.sections course
                            if sections.any?

                              # SECTIONS

                              sections.each do |section|

                                begin

                                  section_sis_data = user_analytics_data.section_sis_data section
                                  term_section_ccns << section_sis_data[:ccn]

                                  component = section_sis_data[:component]

                                  visible_section_sis_data = @boac_student_page.visible_section_sis_data(term_name, course_code, component)

                                  visible_enrollment_status = visible_section_sis_data[:status]
                                  visible_section_number = visible_section_sis_data[:number]
                                  visible_section_units = visible_section_sis_data[:units]
                                  visible_section_grading_basis = visible_section_sis_data[:grading_basis]
                                  visible_grade = visible_section_sis_data[:grade]

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
                                    expect(visible_section_number).to eql(section_sis_data[:number])
                                    expect(visible_section_number.empty?).to be false
                                  end

                                  if section_sis_data[:units].to_i > 0
                                    it "shows the section units for UID #{team_member.uid} term #{term_name} course #{course_code} section #{component}" do
                                      expect(visible_section_units).to eql(section_sis_data[:units])
                                      expect(visible_section_units.empty?).to be false
                                    end
                                  else
                                    it "shows no section units for UID #{team_member.uid} term #{term_name} course #{course_code} section #{component}" do
                                      expect(visible_section_units).to be_nil
                                    end
                                  end

                                  if section_sis_data[:grading_basis] == 'NON'
                                    it "shows not section grading basis for UID #{team_member.uid} term #{term_name} course #{course_code} section #{component}" do
                                      expect(visible_section_grading_basis).to be_nil
                                    end
                                  else
                                    it "shows the section grading basis for UID #{team_member.uid} term #{term_name} course #{course_code} section #{component}" do
                                      expect(visible_section_grading_basis).to eql(section_sis_data[:grading_basis])
                                      expect(visible_section_grading_basis.empty?).to be false
                                    end
                                  end

                                  if section_sis_data[:grade]
                                    it "shows the section grade data for UID #{team_member.uid} term #{term_name} course #{course_code} section #{component}" do
                                      expect(visible_grade).to eql(section_sis_data[:grade])
                                      expect(visible_grade.empty?).to be false
                                    end
                                  else
                                    it "shows not section grade data for UID #{team_member.uid} term #{term_name} course #{course_code} section #{component}" do
                                      expect(visible_grade).to be_nil
                                    end
                                  end

                                rescue => e
                                  Utils.log_error e
                                  it("encountered an error for UID #{team_member.uid} term #{term_name} course #{course_code} section #{section_sis_data[:ccn]}") { fail }
                                ensure
                                  row = [team_member.uid, team.name, term_name, course_code, course_sis_data[:title], section_sis_data[:ccn], section_sis_data[:number],
                                         section_sis_data[:grade], section_sis_data[:grading_basis], section_sis_data[:units], section_sis_data[:status]]
                                  Utils.add_csv_row(user_course_sis_data, row)
                                end
                              end
                            end

                            # COURSE SITE ANALYTICS

                            course_sites = user_analytics_data.course_sites course
                            if course_sites.any?

                              logger.warn "The number of sites attached to #{course_code} is #{course_sites.length}"

                              course_sites.each do |site|
                                begin

                                  site_page_view_analytics, site_assignment_analytics, site_participation_analytics = nil
                                  site_title = user_analytics_data.site_metadata(site)[:title]

                                  index = user_analytics_data.course_sites(course).index site
                                  analytics_xpath = @boac_student_page.course_site_xpath(term_name, course_code, index)
                                  logger.info "Checking course site #{site_title} at index #{index}"

                                  # Page views

                                  page_views_analytics = user_analytics_data.site_page_views site
                                  site_page_view_analytics = user_analytics_data.site_statistics page_views_analytics

                                  if user_analytics_data.student_percentile(page_views_analytics) && site_page_view_analytics[:maximum].to_i >= BOACUtils.meaningful_minimum
                                    visible_page_view_analytics = @boac_student_page.visible_page_view_analytics(@driver, analytics_xpath)
                                    it "shows the page view analytics for UID #{team_member.uid} term #{term_name} course site #{site_title}" do
                                      expect(visible_page_view_analytics).to eql(site_page_view_analytics)
                                    end
                                  else
                                    no_data = @boac_student_page.no_page_view_data? analytics_xpath
                                    it "shows no page view data for UID #{team_member.uid} term #{term_name} course site #{site_title}" do
                                      expect(no_data).to be true
                                    end
                                  end

                                  # Assignments on time

                                  assignments_on_time_analytics = user_analytics_data.site_assignments_on_time site
                                  site_assignment_analytics = user_analytics_data.site_statistics assignments_on_time_analytics

                                  if user_analytics_data.student_percentile(assignments_on_time_analytics) && site_assignment_analytics[:maximum].to_i >= BOACUtils.meaningful_minimum
                                    visible_assignment_analytics = @boac_student_page.visible_assignment_analytics(@driver, analytics_xpath)
                                    it "shows the assignments on time analytics for UID #{team_member.uid} term #{term_name} course site #{site_title}" do
                                      expect(visible_assignment_analytics).to eql(site_assignment_analytics)
                                    end
                                  else
                                    no_data = @boac_student_page.no_assignment_data? analytics_xpath
                                    it "shows no assignments on time data for UID #{team_member.uid} term #{term_name} course site #{site_title}" do
                                      expect(no_data).to be true
                                    end
                                  end

                                  # Participations

                                  participation_analytics = user_analytics_data.site_participations site
                                  site_participation_analytics = user_analytics_data.site_statistics participation_analytics

                                  if user_analytics_data.student_percentile(participation_analytics) && site_participation_analytics[:maximum].to_i >= BOACUtils.meaningful_minimum
                                    visible_participation_analytics = @boac_student_page.visible_participation_analytics(@driver, analytics_xpath)
                                    it "shows the participations analytics for UID #{team_member.uid} term #{term_name} course site #{site_title}" do
                                      expect(visible_participation_analytics).to eql(site_participation_analytics)
                                    end
                                  else
                                    no_data = @boac_student_page.no_participations_data? analytics_xpath
                                    it "shows no participations data for UID #{team_member.uid} term #{term_name} course site #{site_title}" do
                                      expect(no_data).to be true
                                    end
                                  end

                                rescue => e
                                  Utils.log_error e
                                  it("encountered an error for UID #{team_member.uid} term #{term_name} course #{course_code} site #{site_title}") { fail }
                                ensure
                                  row = [team_member.uid, team.name, term_name, course_code, course_sis_data[:title], site_title,
                                         site_page_view_analytics, site_assignment_analytics, site_participation_analytics]
                                  Utils.add_csv_row(user_course_canvas_data, row)
                                end
                              end

                            else
                              logger.warn "#{course_code} has no sites"
                              row = [team_member.uid, team.name, term_name, course_code, course_sis_data[:title]]
                              Utils.add_csv_row(user_course_canvas_data, row)
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

                      # UNMATCHED SITE ANALYTICS

                      unmatched_sites = user_analytics_data.unmatched_sites term

                      if unmatched_sites.any?

                        unmatched_sites.each do |site|

                          begin

                            # Initialize SIS and analytics variables
                            site_page_view_analytics, site_assignment_analytics, site_participation_analytics = nil

                            index = user_analytics_data.unmatched_sites(term).index site
                            site_title = user_analytics_data.site_metadata(site)[:title]
                            analytics_xpath = @boac_student_page.unmatched_site_xpath(term_name, site_title, index)

                            logger.info "Checking unmatched site #{site_title} at index #{index}"

                            # Page views

                            page_views_analytics = user_analytics_data.site_page_views site
                            site_page_view_analytics = user_analytics_data.site_statistics page_views_analytics

                            if user_analytics_data.student_percentile(page_views_analytics) && site_page_view_analytics[:maximum].to_i >= BOACUtils.meaningful_minimum
                              visible_page_view_analytics = @boac_student_page.visible_page_view_analytics(@driver, analytics_xpath)
                              it "shows the page view analytics for #{team.name} UID #{team_member.uid} unmatched site #{site_title}" do
                                expect(visible_page_view_analytics).to eql(site_page_view_analytics)
                              end
                            else
                              no_data = @boac_student_page.no_page_view_data? analytics_xpath
                              it "shows no page view data for #{team.name} UID #{team_member.uid} unmatched site #{site_title}" do
                                expect(no_data).to be true
                              end
                            end

                            # Assignments on time

                            assignments_on_time_analytics = user_analytics_data.site_assignments_on_time site
                            site_assignment_analytics = user_analytics_data.site_statistics assignments_on_time_analytics

                            if user_analytics_data.student_percentile(assignments_on_time_analytics) && site_assignment_analytics[:maximum].to_i >= BOACUtils.meaningful_minimum
                              visible_assignment_analytics = @boac_student_page.visible_assignment_analytics(@driver, analytics_xpath)
                              it "shows the assignments on time analytics for #{team.name} UID #{team_member.uid} unmatched site #{site_title}" do
                                expect(visible_assignment_analytics).to eql(site_assignment_analytics)
                              end
                            else
                              no_data = @boac_student_page.no_assignment_data? analytics_xpath
                              it "shows no assignments on time data for #{team.name} UID #{team_member.uid} unmatched site #{site_title}" do
                                expect(no_data).to be true
                              end
                            end

                            # Participations

                            participation_analytics = user_analytics_data.site_participations site
                            site_participation_analytics = user_analytics_data.site_statistics participation_analytics

                            if user_analytics_data.student_percentile(participation_analytics) && site_participation_analytics[:maximum].to_i >= BOACUtils.meaningful_minimum
                              visible_participation_analytics = @boac_student_page.visible_participation_analytics(@driver, analytics_xpath)
                              it "shows the participations analytics for #{team.name} UID #{team_member.uid} unmatched site #{site_title}" do
                                expect(visible_participation_analytics).to eql(site_participation_analytics)
                              end
                            else
                              no_data = @boac_student_page.no_participations_data? analytics_xpath
                              it "shows no participations data for #{team.name} UID #{team_member.uid} unmatched site #{site_title}" do
                                expect(no_data).to be true
                              end
                            end

                          rescue => e
                            Utils.log_error e
                            it("encountered an error for #{team.name} UID #{team_member.uid} unmatched site #{site_title}") { fail }
                          ensure
                            row = [team_member.uid, team.name, term_name, nil, nil, site_title, site_page_view_analytics, site_assignment_analytics, site_participation_analytics]
                            Utils.add_csv_row(user_course_canvas_data, row)
                          end
                        end

                      else
                        logger.warn "No unmatched course sites in #{term_name}"
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
                row = [team_member.uid, team.name, visible_name, visible_email, visible_phone, visible_cumulative_units, visible_cumulative_gpa,
                       visible_colleges && visible_colleges * '; ', visible_majors && visible_majors * '; ', visible_level, visible_writing_reqt,
                       visible_history_reqt, visible_institutions_reqt, visible_cultures_reqt, visible_language_reqt]
                Utils.add_csv_row(user_profile_sis_data, row)
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
