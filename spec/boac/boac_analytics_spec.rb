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

    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasActivitiesPage.new @driver
    @boac_homepage = Page::BOACPages::HomePage.new @driver
    @boac_homepage.log_in(Utils.super_admin_username, Utils.super_admin_password, @cal_net)

    team = BOACUtils.get_teams.find { |t| t.code == team_code }
    BOACUtils.get_team_members(team).each do |student|

      boac_api_page = ApiUserAnalyticsPage.new @driver
      boac_api_page.get_data(@driver, student)
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

              logger.info "Checking site #{site_id}, #{site_code}"

              # Gather the expected analytics data from Canvas
              canvas_assigns = boac_api_page.canvas_api_assigns_on_time site_data
              canvas_grades = boac_api_page.canvas_api_grades site_data
              canvas_pages = boac_api_page.canvas_api_page_views site_data

              # Gather the expected analytics data from the Data Loch
              loch_assigns = boac_api_page.loch_assigns_on_time site_data
              loch_grades = boac_api_page.loch_grades site_data
              loch_pages = boac_api_page.loch_page_views site_data

              # Assignments on time - compare Data Loch with Canvas API

              it "has the same Canvas API and Data Loch assignments-on-time minimum for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                expect(loch_assigns[:min]).to eql(canvas_assigns[:min])
              end
              it "has the same Canvas API and Data Loch assignments-on-time maximum for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                expect(loch_assigns[:max]).to eql(canvas_assigns[:max])
              end
              it "has the same Canvas API and Data Loch assignments-on-time user score for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                expect(loch_assigns[:score]).to eql(canvas_assigns[:score])
              end
              it "has the same Canvas API and Data Loch assignments-on-time user percentile for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                expect(loch_assigns[:perc]).to eql(canvas_assigns[:perc])
              end
              it "has the same Canvas API and Data Loch assignments-on-time user rounded percentile for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                expect(loch_assigns[:perc_round]).to eql(canvas_assigns[:perc_round])
              end

              # Page views - compare Data Loch with Canvas API

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

              # Scores - compare Data Loch with Canvas API

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

                # Scores - compare with Canvas Gradebook export

                course = Course.new({:site_id => site_id})
                @canvas.load_gradebook course
                scores = @canvas.export_grades course
                gradebook_min = (scores.first)[:score]
                gradebook_max = (scores.last)[:score]
                gradebook_user_score = (scores.find { |s| s[:uid] == student.uid })[:score]

                it "has the same Canvas Gradebook and Data Loch grades minimum for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                  expect((gradebook_min.to_i - 1)..(gradebook_min.to_i + 1)).to include(loch_grades[:min].to_i)
                end
                it "has the same Canvas Gradebook and Data Loch grades maximum for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                  expect((gradebook_max.to_i - 1)..(gradebook_max.to_i + 1)).to include(loch_grades[:max].to_i)
                end
                it "has the same Canvas Gradebook and Data Loch grades user score for UID #{student.uid} term #{term_to_test} course site ID #{site_id}, #{site_code}" do
                  expect((gradebook_user_score.to_i - 1)..(gradebook_user_score.to_i + 1)).to include(loch_grades[:score].to_i)
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
        end
      end
    end
  rescue => e
    Utils.log_error e
    it('encountered an unexpected error') { fail }
  end
end
