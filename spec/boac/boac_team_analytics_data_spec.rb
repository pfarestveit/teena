require_relative '../../util/spec_helper'

describe 'BOAC analytics' do

  include Logging

  begin

    # Specify the team to test
    team_code = ENV['TEAM']
    term_to_test = BOACUtils.analytics_term

    user_course_analytics_data = File.join(Utils.initialize_test_output_dir, 'boac-canvas-courses.csv')
    user_analytics_data_heading = %w(UID Sport Term CourseCode SiteCode SiteId
                                      AssignMin AssignMax AssignUser AssignPerc AssignRound
                                      GradesMin GradesMax GradesUser GradesPerc GradesRound)
    CSV.open(user_course_analytics_data, 'wb') { |csv| csv << user_analytics_data_heading }

    user_course_assigns = File.join(Utils.initialize_test_output_dir, 'boac-assignments.csv')
    user_course_assigns_heading = %w(UID CanvasID Site AssignmentID URL DueDate Submission SubmitDate Type OnTime)
    CSV.open(user_course_assigns, 'wb') { |csv| csv << user_course_assigns_heading }

    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @canvas_assignments_page = Page::CanvasAssignmentsPage.new @driver
    @canvas_discussions_page = Page::CanvasAnnounceDiscussPage.new @driver
    @canvas_grades_page = Page::CanvasGradesPage.new @driver
    @e_grades_page = Page::JunctionPages::CanvasEGradesExportPage.new @driver
    @boac_homepage = Page::BOACPages::HomePage.new @driver
    @boac_student_page = Page::BOACPages::StudentPage.new @driver
    @boac_homepage.log_in(Utils.super_admin_username, Utils.super_admin_password, @cal_net)

    team = BOACUtils.get_teams.find { |t| t.code == team_code }
    BOACUtils.get_team_members(team).each do |student|

      boac_api_page = ApiUserAnalyticsPage.new @driver
      boac_api_page.get_data(@driver, student)
      boac_api_page.set_canvas_id student
      term = boac_api_page.terms.find { |t| boac_api_page.term_name(t) == term_to_test }

      if term
        begin

          # Collect all the Canvas sites in the term, matched and unmatched
          term_sites = []
          term_sites << boac_api_page.unmatched_sites(term).map { |s| {:data => s} }

          courses = boac_api_page.courses term
          if courses.any?
            courses.each do |course|
              course_sites = boac_api_page.course_sites course
              term_sites << course_sites.map { |s| {:data => s} }
            end
          end

          term_sites.flatten.each do |site|
            begin

              site_data = site[:data]
              site_code = boac_api_page.site_metadata(site_data)[:code]
              site_id = boac_api_page.site_metadata(site_data)[:site_id]
              course = Course.new({:site_id => site_id})

              logger.info "Checking site #{site_id}, #{site_code}"

              # Gather the analytics data obtained from Nessie
              nessie_assigns_submitted = boac_api_page.nessie_assigns_submitted site_data
              nessie_grades = boac_api_page.nessie_grades site_data

              if BOACUtils.nessie_assignments

                logger.warn "Checking assignment submissions for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}"

                # Un-mute all assignments so that scores are visible to the student
                @canvas_assignments_page.load_course_site(@driver, course)
                @canvas_assignments_page.stop_masquerading(@driver) if @canvas_assignments_page.stop_masquerading_link?
                @e_grades_page.resolve_all_issues(@driver, course)
                @canvas_assignments_page.masquerade_as(@driver, student)
                assignments = @canvas_assignments_page.get_assignments(@driver, course, student, @canvas_discussions_page)

                if assignments.any?
                  assignments.each { |a| Utils.add_csv_row(user_course_assigns, [student.uid, student.canvas_id, site_id, a.id, a.url, a.due_date, a.submitted, a.submission_date, a.type, a.on_time]) }

                  # Get all submitted assignments
                  submitted = assignments.select &:submitted
                  it "has the right Nessie assignments-submitted count for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                    expect(nessie_assigns_submitted[:score].to_i).to eql(submitted.length)
                  end
                end

              else
                logger.warn 'Skipping comparison of assignment submissions in Nessie versus Canvas UI'
              end

              if BOACUtils.nessie_scores

                if nessie_grades[:score].empty?

                  logger.warn "Skipping current score tests for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}"

                else

                  logger.warn "Checking current score for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}"

                  @canvas_grades_page.stop_masquerading(@driver) if @canvas_grades_page.stop_masquerading_link?
                  @canvas_grades_page.load_gradebook course
                  scores = @canvas_grades_page.export_grades course

                  gradebook_min = scores.first
                  logger.debug "Gradebook minimum current score: #{gradebook_min}"
                  gradebook_min = gradebook_min[:score]
                  it "has the same Canvas Gradebook and Nessie grades minimum for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                    expect((gradebook_min.to_i - 1)..(gradebook_min.to_i + 1)).to include(nessie_grades[:min].to_i)
                  end

                  gradebook_max = scores.last
                  logger.debug "Gradebook maximum current score: #{gradebook_max}"
                  gradebook_max = gradebook_max[:score]
                  it "has the same Canvas Gradebook and Nessie grades maximum for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                    expect((gradebook_max.to_i - 1)..(gradebook_max.to_i + 1)).to include(nessie_grades[:max].to_i)
                  end

                  gradebook_user_score = (scores.find { |s| s[:uid] == student.uid })[:score]
                  it "has the same Canvas Gradebook and Nessie grades user score for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                    expect((gradebook_user_score.to_i - 1)..(gradebook_user_score.to_i + 1)).to include(nessie_grades[:score].to_i)
                  end
                end

              else
                logger.warn 'Skipping comparison of current scores in Nessie versus Canvas UI'
              end

              if BOACUtils.tooltips

                @boac_student_page.load_page student
                @boac_student_page.click_view_previous_semesters if boac_api_page.terms.length > 1

                # Find the site in the UI differently if it's matched versus unmatched
                site[:course_code] ?
                    (analytics_xpath = @boac_student_page.course_site_xpath(term_to_test, site[:course_code], site[:index])) :
                    (analytics_xpath = @boac_student_page.unmatched_site_xpath(term_to_test, site_code))

                [nessie_assigns_submitted, nessie_grades].each do |analytics|

                  if analytics[:perc_round].nil?
                    no_data = @boac_student_page.no_data?(analytics_xpath, analytics[:type])
                    it "shows no '#{analytics[:type]}' data for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                      expect(no_data).to be true
                    end
                  else
                    visible_analytics = case analytics[:type]
                                          when 'Assignments Submitted'
                                            @boac_student_page.visible_assignment_analytics(@driver, analytics_xpath, analytics)
                                          when 'Assignment Grades'
                                            @boac_student_page.visible_grades_analytics(@driver, analytics_xpath, analytics)
                                          else
                                            logger.error "Unsupported analytics type '#{analytics[:type]}'"
                                        end

                    it "shows the '#{analytics[:type]}' user percentile for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                      expect(visible_analytics[:perc_round]).to eql(analytics[:perc_round])
                    end
                    it "shows the '#{analytics[:type]}' user score for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                      expect(visible_analytics[:score]).to eql(analytics[:score])
                    end
                    it "shows the '#{analytics[:type]}' course maximum for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                      expect(visible_analytics[:max]).to eql(analytics[:max])
                    end

                    if analytics[:graphable]
                      it "shows the '#{analytics[:type]}' course 70th percentile for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                        expect(visible_analytics[:perc_70]).to eql(analytics[:perc_70])
                      end
                      it "shows the '#{analytics[:type]}' course 50th percentile for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                        expect(visible_analytics[:perc_50]).to eql(analytics[:perc_50])
                      end
                      it "shows the '#{analytics[:type]}' course 30th percentile for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                        expect(visible_analytics[:perc_30]).to eql(analytics[:perc_30])
                      end
                      it "shows the '#{analytics[:type]}' course minimum for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                        expect(visible_analytics[:minimum]).to eql(analytics[:minimum])
                      end
                    else
                      it "shows no '#{analytics[:type]}' course 70th percentile for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                        expect(visible_analytics[:perc_70]).to be_nil
                      end
                      it "shows no '#{analytics[:type]}' course 50th percentile for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                        expect(visible_analytics[:perc_50]).to be_nil
                      end
                      it "shows no '#{analytics[:type]}' course 30th percentile for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                        expect(visible_analytics[:perc_30]).to be_nil
                      end
                      it "shows no '#{analytics[:type]}' course minimum for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                        expect(visible_analytics[:minimum]).to be_nil
                      end
                    end
                  end
                end
              end

            rescue => e
              Utils.log_error e
              it("encountered an error with UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}") { fail }
            ensure
              row = [student.uid, team.name, term_to_test, site[:course_code], site_code, site[:site_id],
                     nessie_assigns_submitted[:min], nessie_assigns_submitted[:max], nessie_assigns_submitted[:score], nessie_assigns_submitted[:perc], nessie_assigns_submitted[:perc_round],
                     nessie_grades[:min], nessie_grades[:max], nessie_grades[:score], nessie_grades[:perc], nessie_grades[:perc_round]
              ]
              Utils.add_csv_row(user_course_analytics_data, row)
            end
          end
        rescue => e
          Utils.log_error e
          it("encountered an error with UID #{student.uid} term #{term_to_test}") { fail }
        end
      end
    end
  rescue => e
    Utils.log_error e
    it('encountered an unexpected error') { fail }
  ensure
    Utils.quit_browser @driver
  end
end
