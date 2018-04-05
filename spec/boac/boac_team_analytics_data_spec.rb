require_relative '../../util/spec_helper'

describe 'BOAC analytics' do

  include Logging

  begin

    team_code = ENV['TEAM']
    term_to_test = BOACUtils.current_scores_term

    user_course_analytics_data = File.join(Utils.initialize_test_output_dir, 'boac-canvas-courses.csv')
    user_analytics_data_heading = %w(UID Sport Term CourseCode SiteCode SiteId
                                      AssignMinCanvas AssignMinLoch AssignMaxCanvas AssignMaxLoch AssignUserCanvas AssignUserLoch AssignPercCanvas AssignPercLoch AssignRoundCanvas AssignRoundLoch
                                      GradesMinLoch GradesMaxLoch GradesUserLoch GradesPercLoch GradesRoundLoch
                                      PageMinCanvas PageMinLoch PageMaxCanvas PageMaxLoch PageUserCanvas PageUserLoch PagePercCanvas PagePercLoch PageRoundCanvas PageRoundLoch)
    CSV.open(user_course_analytics_data, 'wb') { |csv| csv << user_analytics_data_heading }

    user_course_assigns = File.join(Utils.initialize_test_output_dir, 'boac-assignments.csv')
    user_course_assigns_heading = %w(UID CanvasID Site AssignmentID URL DueDate Submission SubmitDate Type OnTime)
    CSV.open(user_course_assigns, 'wb') { |csv| csv << user_course_assigns_heading }

    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @canvas_assignments_page = Page::CanvasAssignmentsPage.new @driver
    @canvas_discussions_page = Page::CanvasAnnounceDiscussPage.new @driver
    @canvas_grades_page = Page::CanvasGradesPage.new @driver
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

          @canvas_assignments_page.masquerade_as(@driver, student) if BOACUtils.loch_assignments

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

              # Gather the expected analytics data from Canvas
              canvas_assigns_on_time = boac_api_page.canvas_api_assigns_on_time site_data
              canvas_pages = boac_api_page.canvas_api_page_views site_data

              # Gather the expected analytics data from the Data Loch
              loch_assigns_on_time = boac_api_page.loch_assigns_on_time site_data
              loch_assigns_submitted = boac_api_page.loch_assigns_submitted site_data
              loch_grades = boac_api_page.loch_grades site_data
              loch_pages = boac_api_page.loch_page_views site_data

              if BOACUtils.loch_assignments

                logger.warn "Checking assignments-on-time for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}"

                assignments = @canvas_assignments_page.get_assignments(@driver, course, student, @canvas_discussions_page)

                if assignments.any?
                  assignments.each { |a| Utils.add_csv_row(user_course_assigns, [student.uid, student.canvas_id, site_id, a.id, a.url, a.due_date, a.submitted, a.submission_date, a.type, a.on_time]) }

                  # Get all submitted assignments
                  submitted = assignments.select &:submitted
                  it "has the right Data Loch assignments-submitted count for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                    expect(loch_assigns_submitted[:score].to_i).to eql(submitted.length)
                  end

                  # Get all assignments submitted on-time. Some submission dates are available to the loch but not in the UI, so expect the loch to report as many or more on-time
                  # submissions as the UI.
                  on_time = submitted.select &:on_time
                  it "has the right Data Loch assignments-on-time count for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                    expect(loch_assigns_on_time[:score].to_i).to be >= on_time.length
                  end
                end

              else
                logger.warn 'Skipping comparison of assignments-on-time in Data Loch versus Canvas UI'
              end

              if BOACUtils.loch_page_views

                # Page views - compare Data Loch with Canvas API

                logger.warn "Checking page views for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}"

                it "has the same Canvas API and Data Loch page views minimum for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                  expect(loch_pages[:min]).to eql(canvas_pages[:min])
                end
                it "has the same Canvas API and Data Loch page views maximum for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                  expect(loch_pages[:max]).to eql(canvas_pages[:max])
                end
                it "has the same Canvas API and Data Loch page views user score for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                  expect(loch_pages[:score]).to eql(canvas_pages[:score])
                end
                it "has the same Canvas API and Data Loch page views user percentile for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                  expect(loch_pages[:perc]).to eql(canvas_pages[:perc])
                end
                it "has the same Canvas API and Data Loch page views user rounded percentile for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                  expect(loch_pages[:perc_round]).to eql(canvas_pages[:perc_round])
                end

              else
                logger.warn 'Skipping comparison of page views in Data Loch versus Canvas API'
              end

              if BOACUtils.loch_scores

                if loch_grades[:score].empty?

                  logger.warn "Skipping current score tests for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}"

                else

                  logger.warn "Checking current score for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}"

                  @canvas_grades_page.stop_masquerading @driver if BOACUtils.loch_assignments
                  @canvas_grades_page.load_gradebook course
                  scores = @canvas_grades_page.export_grades course

                  gradebook_min = scores.first
                  logger.debug "Gradebook minimum current score: #{gradebook_min}"
                  gradebook_min = gradebook_min[:score]
                  it "has the same Canvas Gradebook and Data Loch grades minimum for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                    expect((gradebook_min.to_i - 1)..(gradebook_min.to_i + 1)).to include(loch_grades[:min].to_i)
                  end

                  gradebook_max = scores.last
                  logger.debug "Gradebook maximum current score: #{gradebook_max}"
                  gradebook_max = gradebook_max[:score]
                  it "has the same Canvas Gradebook and Data Loch grades maximum for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                    expect((gradebook_max.to_i - 1)..(gradebook_max.to_i + 1)).to include(loch_grades[:max].to_i)
                  end

                  gradebook_user_score = (scores.find { |s| s[:uid] == student.uid })[:score]
                  it "has the same Canvas Gradebook and Data Loch grades user score for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                    expect((gradebook_user_score.to_i - 1)..(gradebook_user_score.to_i + 1)).to include(loch_grades[:score].to_i)
                  end
                end

              else
                logger.warn 'Skipping comparison of current scores in Data Loch versus Canvas API'
              end

              if BOACUtils.tooltips

                @boac_student_page.load_page student
                @boac_student_page.click_view_previous_semesters if boac_api_page.terms.length > 1

                # Find the site in the UI differently if it's matched versus unmatched
                site[:course_code] ?
                    (analytics_xpath = @boac_student_page.course_site_xpath(term_to_test, site[:course_code], site[:index])) :
                    (analytics_xpath = @boac_student_page.unmatched_site_xpath(term_to_test, site_code))

                [canvas_assigns_on_time, canvas_grades, canvas_pages].each do |api_analytics|

                  if api_analytics[:perc_round].nil?
                    no_data = @boac_student_page.no_data?(analytics_xpath, api_analytics[:type])
                    it "shows no '#{api_analytics[:type]}' data for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
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

                    it "shows the '#{api_analytics[:type]}' user percentile for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                      expect(visible_analytics[:perc_round]).to eql(api_analytics[:perc_round])
                    end
                    it "shows the '#{api_analytics[:type]}' user score for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                      expect(visible_analytics[:score]).to eql(api_analytics[:score])
                    end
                    it "shows the '#{api_analytics[:type]}' course maximum for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                      expect(visible_analytics[:max]).to eql(api_analytics[:max])
                    end

                    if api_analytics[:graphable]
                      it "shows the '#{api_analytics[:type]}' course 70th percentile for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                        expect(visible_analytics[:perc_70]).to eql(api_analytics[:perc_70])
                      end
                      it "shows the '#{api_analytics[:type]}' course 50th percentile for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                        expect(visible_analytics[:perc_50]).to eql(api_analytics[:perc_50])
                      end
                      it "shows the '#{api_analytics[:type]}' course 30th percentile for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                        expect(visible_analytics[:perc_30]).to eql(api_analytics[:perc_30])
                      end
                      it "shows the '#{api_analytics[:type]}' course minimum for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                        expect(visible_analytics[:minimum]).to eql(api_analytics[:minimum])
                      end
                    else
                      it "shows no '#{api_analytics[:type]}' course 70th percentile for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                        expect(visible_analytics[:perc_70]).to be_nil
                      end
                      it "shows no '#{api_analytics[:type]}' course 50th percentile for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                        expect(visible_analytics[:perc_50]).to be_nil
                      end
                      it "shows no '#{api_analytics[:type]}' course 30th percentile for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                        expect(visible_analytics[:perc_30]).to be_nil
                      end
                      it "shows no '#{api_analytics[:type]}' course minimum for Canvas ID #{student.canvas_id} UID #{student.uid} term #{term_to_test} course site #{site_code}" do
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
                     canvas_assigns_on_time[:min], loch_assigns_on_time[:min], canvas_assigns_on_time[:max], loch_assigns_on_time[:max], canvas_assigns_on_time[:score], loch_assigns_on_time[:score],
                     canvas_assigns_on_time[:perc], loch_assigns_on_time[:perc], canvas_assigns_on_time[:perc_round], loch_assigns_on_time[:perc_round],
                     loch_grades[:min], loch_grades[:max], loch_grades[:score], loch_grades[:perc], loch_grades[:perc_round],
                     canvas_pages[:min], loch_pages[:min], canvas_pages[:max], loch_pages[:max], canvas_pages[:score], loch_pages[:score],
                     canvas_pages[:perc], loch_pages[:perc],canvas_pages[:perc_round], loch_pages[:perc_round]
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
  end
end
