require_relative '../../util/spec_helper'

describe 'BOAC' do

  include Logging

  begin

    if Utils.headless?

      logger.warn 'This script requires admin Canvas access and cannot be run headless. Terminating.'

    else

      test = BOACTestConfig.new
      test.last_activity NessieUtils.get_all_students
      pages_tested = []

      # Test Last Activity using the current term rather than past term
      test.term = BOACUtils.term
      testable_users = []
      logger.info "Checking term #{test.term}"

      last_activity_csv = Utils.create_test_output_csv('boac-last-activity.csv', %w(Term CCN UID Canvas ClassPageActivity StudentPageActivity StudentPageContext))

      @driver = Utils.launch_browser
      @homepage = Page::BOACPages::HomePage.new @driver
      @cal_net_page = Page::CalNetPage.new @driver
      @canvas_page = Page::CanvasPage.new @driver
      @class_page = Page::BOACPages::ClassPages::ClassListViewPage.new @driver
      @curated_page = Page::BOACPages::CohortPages::CuratedCohortPage.new @driver
      @student_page = Page::BOACPages::StudentPage.new @driver

      @canvas_page.log_in(@cal_net_page, Utils.super_admin_username, Utils.super_admin_password, 'https://bcourses.berkeley.edu')
      @homepage.dev_auth test.advisor

      test.max_cohort_members.each do |student|

        begin

          # Get the user API data for the athlete to determine which courses to check
          api_athlete_page = ApiUserAnalyticsPage.new @driver
          api_athlete_page.get_data(@driver, student)

          term = api_athlete_page.terms.find { |t| api_athlete_page.term_name(t) == test.term }

          if term
            term_id = api_athlete_page.term_id term

            api_athlete_page.courses(term).each do |course|

              course_sis_data = api_athlete_page.course_sis_data course

              # Skip PHYS ED sites for now, since the rosters are large and they rarely have active course sites
              unless course_sis_data[:code].include? 'PHYS ED'
                logger.info "Checking course #{course_sis_data[:code]}"

                  api_athlete_page.sections(course).each do |section|

                  # If the section is primary and hasn't been checked already, collect all the student data for the section
                  begin
                    section_data = api_athlete_page.section_sis_data section
                    if api_athlete_page.section_sis_data(section)[:primary] && !pages_tested.include?("#{term_id} #{section_data[:ccn]}")
                      pages_tested << "#{term_id} #{section_data[:ccn]}"

                      api_section_page = ApiSectionPage.new @driver
                      api_section_page.get_data(@driver, term_id, section_data[:ccn])

                      all_student_data = []
                      section_students = test.dept_students.select { |s| api_section_page.student_uids.include? s.uid }
                      section_students.each do |section_student|

                        # Collect all the Canvas sites associated with that student in that course and the last activity data in BOAC's API data
                        begin
                          api_student_page = ApiUserAnalyticsPage.new @driver
                          api_student_page.get_data(@driver, section_student)
                          term = api_student_page.terms.find { |t| api_student_page.term_name(t) == test.term }
                          student_course = api_student_page.courses(term).find { |c| api_student_page.course_display_name(c) == course_sis_data[:code] }
                          sites = api_student_page.course_sites student_course

                          # Load the student page for the student, and collect all the last activity info shown for each relevant site
                          @student_page.load_page section_student
                          @student_page.click_view_previous_semesters if test.term != BOACUtils.term
                          sleep 2
                          @student_page.expand_course_data(test.term, course_sis_data[:code])

                          student_data = {
                            :student => section_student,
                            :sites => (sites.map do |site|
                              {
                                :site_id => api_student_page.site_metadata(site)[:site_id],
                                :site_code => api_student_page.site_metadata(site)[:code],
                                :last_activity_student_page => @student_page.visible_last_activity(test.term, course_sis_data[:code], sites.index(site))
                              }
                            end)
                          }
                          all_student_data << student_data
                        end
                      end

                      # Load the class page for the section, and collect all the last activity info shown for each student + site
                      @class_page.load_page(term_id, section_data[:ccn])
                      all_student_data.each do |d|
                        d[:sites].each do |s|
                          index = d[:sites].index s
                          last_activity = @class_page.visible_last_activity(d[:student], index)[:last_activity]
                          s.merge!(:last_activity_class_page => last_activity)
                        end
                      end

                      all_sites_ids = all_student_data.map do |d|
                        d[:sites].map { |s| s[:site_id] }
                      end
                      unique_site_ids = all_sites_ids.flatten.uniq
                      logger.info "Canvas course site IDs associated with this course are #{unique_site_ids}"

                      testable_users << student if unique_site_ids.any?

                      # For each student in each site, compare the last activity date shown in the Canvas UI with the date shown on BOAC pages
                      unique_site_ids.each do |site_id|

                        begin
                          logger.debug "Checking site ID #{site_id}"
                          total_students = @canvas_page.load_all_students(Course.new({:site_id => site_id}), 'https://bcourses.berkeley.edu')

                          all_student_data.each do |d|

                            begin
                              test_case = "UID #{d[:student].uid} in Canvas site ID #{site_id}"
                              logger.debug "Checking last activity in Canvas for #{test_case}"
                              d[:sites].each do |s|

                                if s[:site_id] == site_id
                                  canvas_last_activity = @canvas_page.roster_user_last_activity d[:student].uid
                                  Utils.add_csv_row(last_activity_csv, [test.term, site_id, d[:student].uid, canvas_last_activity, s[:last_activity_class_page], s[:last_activity_student_page][:last_activity], s[:last_activity_student_page][:activity_context]])

                                  if canvas_last_activity.empty?
                                    it("shows 'Never' Last Activity in the BOAC class page for #{test_case}") { expect(s[:last_activity_class_page]).to eql('Never') }
                                    it("shows 'never' Last Activity in the BOAC student page for #{test_case}") { expect(s[:last_activity_student_page][:last_activity]).to include('never') }

                                  else

                                    day_count = (Date.today - Date.parse(canvas_last_activity)).to_i

                                    if day_count < BOACUtils.canvas_data_lag_days
                                      logger.warn "Skipping last activity check for #{test_case}, since the user visited the site within day count #{day_count}, and BOAC will not know that."

                                    else

                                      if day_count == 1
                                        it("shows 'Yesterday' Last Activity on the class page for #{test_case}") { expect(s[:last_activity_class_page]).to eql('Yesterday') }
                                        it("shows 'yesterday' Last Activity on the student page for #{test_case}") { expect(s[:last_activity_student_page][:last_activity]).to eql('yesterday') }
                                      else
                                        it("shows '#{day_count} days ago' Last Activity on the class page for #{test_case}") { expect(s[:last_activity_class_page]).to eql("#{day_count} days ago") }
                                        it("shows '#{day_count} days ago' Last Activity on the student page for #{test_case}") { expect(s[:last_activity_student_page][:last_activity]).to eql("#{day_count} days ago") }
                                      end

                                      it("shows #{total_students} total students for #{test_case}") { expect(s[:last_activity_student_page][:activity_context]).to include("out of #{total_students} enrolled students") }
                                    end
                                  end
                                else
                                  logger.debug "UID #{d[:student].uid} is not associated with site ID #{site_id}"
                                end
                              end
                            rescue => e
                              Utils.log_error e
                              it("hit an error with #{test_case}") { fail }
                            end
                          end

                        rescue => e
                          Utils.log_error e
                          it("hit an error with site #{site_id}") { fail }
                        end
                      end
                    end

                  rescue => e
                    Utils.log_error e
                    it("hit an error with term #{test.term} CCN #{section_data[:ccn]}") { fail }
                  end
                end
              end
            end
          else
            logger.warn "UID #{student.uid} has no enrollments in #{test.term}"
          end

        rescue => e
          Utils.log_error e
          it("hit an error with #{test.default_cohort.name} UID #{student.uid}") { fail }
        end
      end

      if testable_users.empty?
        it("has nothing with which to test Last Activity for #{test.default_cohort.name}") { fail }
      end
    end
  rescue => e
    Utils.log_error e
    it('hit an error') { fail }
  ensure
    Utils.quit_browser @driver
  end
end
