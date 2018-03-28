require_relative '../../util/spec_helper'

describe 'BOAC analytics' do

  include Logging

  begin

    team_code = ENV['TEAM']
    term_to_test = BOACUtils.current_scores_term

    user_course_analytics_data = File.join(Utils.initialize_test_output_dir, 'boac-canvas-courses.csv')
    user_analytics_data_heading = %w(UID Sport Term CourseCode SiteCode SiteId
                                      AssignMinCanvas AssignMinLoch AssignMaxCanvas AssignMaxLoch AssignUserCanvas AssignUserLoch AssignPercCanvas AssignPercLoch AssignRoundCanvas AssignRoundLoch
                                      GradesMinCanvas GradesMinLoch GradesMaxCanvas GradesMaxLoch GradesUserCanvas GradesUserLoch GradesPercCanvas GradesPercLoch GradesRoundCanvas GradesRoundLoch
                                      PageMinCanvas PageMinLoch PageMaxCanvas PageMaxLoch PageUserCanvas PageUserLoch PagePercCanvas PagePercLoch PageRoundCanvas PageRoundLoch)
    CSV.open(user_course_analytics_data, 'wb') { |csv| csv << user_analytics_data_heading }

    user_course_assigns = File.join(Utils.initialize_test_output_dir, 'boac-assignments.csv')
    user_course_assigns_heading = %w(UID CanvasID Site AssignmentID URL DueDate Submission SubmitDate Type OnTime)
    CSV.open(user_course_assigns, 'wb') { |csv| csv << user_course_assigns_heading }

    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasActivitiesPage.new @driver
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

          @canvas.masquerade_as(@driver, student)

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
              canvas_assigns = boac_api_page.canvas_api_assigns_on_time site_data
              canvas_grades = boac_api_page.canvas_api_grades site_data
              canvas_pages = boac_api_page.canvas_api_page_views site_data

              # Gather the expected analytics data from the Data Loch
              loch_assigns = boac_api_page.loch_assigns_on_time site_data
              loch_grades = boac_api_page.loch_grades site_data
              loch_pages = boac_api_page.loch_page_views site_data

              if BOACUtils.loch_assignments

                logger.warn "Checking assignments-on-time for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}"

                assignments = @canvas.get_assignments(@driver, course, student)
                assignments.each { |a| Utils.add_csv_row(user_course_assigns, [student.uid, student.canvas_id, site_id, a.id, a.url, a.due_date, a.submitted, a.submission_date, a.type, a.on_time]) }

                # Get all submitted assignments
                submitted = assignments.select &:submitted
                # If due date and submission date are known, exclude submissions that were late
                submitted.delete_if { |a| !a.on_time if a.due_date && a.submission_date }
                it "has the right Data Loch assignments-submitted count for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                  expect(loch_assigns[:score].to_i).to eql(submitted.length)
                end

              else
                logger.warn 'Skipping comparison of assignments-on-time in Data Loch versus Canvas UI'
              end

              if BOACUtils.loch_page_views

                # Page views - compare Data Loch with Canvas API

                logger.warn "Checking page views for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}"

                it "has the same Canvas API and Data Loch page views minimum for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                  expect(loch_pages[:min]).to eql(canvas_pages[:min])
                end
                it "has the same Canvas API and Data Loch page views maximum for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                  expect(loch_pages[:max]).to eql(canvas_pages[:max])
                end
                it "has the same Canvas API and Data Loch page views user score for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                  expect(loch_pages[:score]).to eql(canvas_pages[:score])
                end
                it "has the same Canvas API and Data Loch page views user percentile for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                  expect(loch_pages[:perc]).to eql(canvas_pages[:perc])
                end
                it "has the same Canvas API and Data Loch page views user rounded percentile for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                  expect(loch_pages[:perc_round]).to eql(canvas_pages[:perc_round])
                end

              else
                logger.warn 'Skipping comparison of page views in Data Loch versus Canvas API'
              end

              if BOACUtils.loch_scores

                # Scores - compare Data Loch with Canvas API

                logger.warn "Checking current score for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}"

                if loch_grades[:score].empty?

                  logger.warn "Skipping current score tests for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}"

                  it "has neither Canvas nor Data Loch grades user score for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                    expect(canvas_grades[:score]).to be_empty
                  end

                else

                  it "has the same Canvas API and Data Loch grades minimum for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                    expect((canvas_grades[:min].to_i - 1)..(canvas_grades[:min].to_i + 1)).to include(loch_grades[:min].to_i)
                  end
                  it "has the same Canvas API and Data Loch grades maximum for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                    expect((canvas_grades[:max].to_i - 1)..(canvas_grades[:max].to_i + 1)).to include(loch_grades[:max].to_i)
                  end
                  it "has the same Canvas API and Data Loch grades user score for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                    expect((canvas_grades[:score].to_i - 1)..(canvas_grades[:score].to_i + 1)).to include(loch_grades[:score].to_i)
                  end
                  it "has the same Canvas API and Data Loch grades user percentile for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                    expect(loch_grades[:perc]).to eql(canvas_grades[:perc])
                  end
                  it "has the same Canvas API and Data Loch grades user rounded percentile for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                    expect(loch_grades[:perc_round]).to eql(canvas_grades[:perc_round])
                  end

                  # Scores - compare with Canvas Gradebook export, using a range of +/- 1 to account for rounding differences

                  @canvas.stop_masquerading @driver
                  @canvas.load_gradebook course
                  scores = @canvas.export_grades course

                  gradebook_min = scores.first
                  logger.debug "Gradebook minimum current score: #{gradebook_min}"
                  gradebook_min = gradebook_min[:score]
                  it "has the same Canvas Gradebook and Data Loch grades minimum for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                    expect((gradebook_min.to_i - 1)..(gradebook_min.to_i + 1)).to include(loch_grades[:min].to_i)
                  end

                  gradebook_max = scores.last
                  logger.debug "Gradebook maximum current score: #{gradebook_max}"
                  gradebook_max = gradebook_max[:score]
                  it "has the same Canvas Gradebook and Data Loch grades maximum for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                    expect((gradebook_max.to_i - 1)..(gradebook_max.to_i + 1)).to include(loch_grades[:max].to_i)
                  end

                  gradebook_user_score = (scores.find { |s| s[:uid] == student.uid })[:score]
                  it "has the same Canvas Gradebook and Data Loch grades user score for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                    expect((gradebook_user_score.to_i - 1)..(gradebook_user_score.to_i + 1)).to include(loch_grades[:score].to_i)
                  end
                end

              else
                logger.warn 'Skipping comparison of current scores in Data Loch versus Canvas API'
              end

              # Optionally, verify the analytics displayed in BOAC

              if BOACUtils.tooltips

                @boac_student_page.load_page student
                @boac_student_page.click_view_previous_semesters if boac_api_page.terms.length > 1

                # Find the site in the UI differently if it's matched versus unmatched
                site[:course_code] ?
                    (analytics_xpath = @boac_student_page.course_site_xpath(term_to_test, site[:course_code], site[:index])) :
                    (analytics_xpath = @boac_student_page.unmatched_site_xpath(term_to_test, site_code))

                [canvas_assigns, canvas_grades, canvas_pages].each do |api_analytics|

                  if api_analytics[:perc_round].nil?
                    no_data = @boac_student_page.no_data?(analytics_xpath, api_analytics[:type])
                    it "shows no '#{api_analytics[:type]}' data for UID #{student.uid} term #{term_to_test} course site #{site_code}" do
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

                    it "shows the '#{api_analytics[:type]}' user percentile for UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                      expect(visible_analytics[:perc_round]).to eql(api_analytics[:perc_round])
                    end
                    it "shows the '#{api_analytics[:type]}' user score for UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                      expect(visible_analytics[:score]).to eql(api_analytics[:score])
                    end
                    it "shows the '#{api_analytics[:type]}' course maximum for UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                      expect(visible_analytics[:max]).to eql(api_analytics[:max])
                    end

                    if api_analytics[:graphable]
                      it "shows the '#{api_analytics[:type]}' course 70th percentile for UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                        expect(visible_analytics[:perc_70]).to eql(api_analytics[:perc_70])
                      end
                      it "shows the '#{api_analytics[:type]}' course 50th percentile for UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                        expect(visible_analytics[:perc_50]).to eql(api_analytics[:perc_50])
                      end
                      it "shows the '#{api_analytics[:type]}' course 30th percentile for UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                        expect(visible_analytics[:perc_30]).to eql(api_analytics[:perc_30])
                      end
                      it "shows the '#{api_analytics[:type]}' course minimum for UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                        expect(visible_analytics[:minimum]).to eql(api_analytics[:minimum])
                      end
                    else
                      it "shows no '#{api_analytics[:type]}' course 70th percentile for UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                        expect(visible_analytics[:perc_70]).to be_nil
                      end
                      it "shows no '#{api_analytics[:type]}' course 50th percentile for UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                        expect(visible_analytics[:perc_50]).to be_nil
                      end
                      it "shows no '#{api_analytics[:type]}' course 30th percentile for UID #{student.uid} term #{term_to_test} course site #{site_code}" do
                        expect(visible_analytics[:perc_30]).to be_nil
                      end
                      it "shows no '#{api_analytics[:type]}' course minimum for UID #{student.uid} term #{term_to_test} course site #{site_code}" do
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
                     canvas_assigns[:min], loch_assigns[:min], canvas_assigns[:max], loch_assigns[:max], canvas_assigns[:score], loch_assigns[:score],
                     canvas_assigns[:perc], loch_assigns[:perc], canvas_assigns[:perc_round], loch_assigns[:perc_round],
                     canvas_grades[:min], loch_grades[:min], canvas_grades[:max], loch_grades[:max], canvas_grades[:score], loch_grades[:score],
                     canvas_grades[:perc], loch_grades[:perc],canvas_grades[:perc_round], loch_grades[:perc_round],
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
