require_relative '../util/spec_helper'

begin

  include Logging

  user_profile_data_heading = %w(UID Name PreferredName Email Phone Units GPA Level Colleges Majors Terms Writing History Institutions Cultures Graduation Alerts)
  user_profile_sis_data = Utils.create_test_output_csv('boac-sis-profiles.csv', user_profile_data_heading)

  user_course_data_heading = %w(UID Term CourseCode CourseName SectionCcn SectionCode Primary? Midpoint Grade GradingBasis Units EnrollmentStatus)
  user_course_sis_data = Utils.create_test_output_csv('boac-sis-courses.csv', user_course_data_heading)

  user_site_data_heading = %w(UID Term SiteCode SiteId AssignMin AssignMax AssignUser AssignPerc AssignRound GradesMin GradesMax GradesUser GradesPerc GradesRound)
  user_course_site_data = Utils.create_test_output_csv('boac-canvas-sites.csv', user_site_data_heading)

  @driver = Utils.launch_browser
  @boac_homepage = Page::BOACPages::BOACUserListPages::BOACHomePage.new @driver
  @boac_homepage.dev_auth

  students = NessieUtils.get_all_students
  logger.info "There are #{students.length} students"
  students.each do |student|
    begin

      logger.info "Checking UID #{student.uid}"
      user_analytics_data = BOACApiStudentPage.new @driver
      user_analytics_data.get_data(@driver, student)
      analytics_api_sis_data = user_analytics_data.sis_profile_data

      alerts = BOACUtils.get_students_alerts [student]
      alert_msgs = alerts.map &:message

      terms = user_analytics_data.terms
      if terms.any?
        begin
          terms.each do |term|
            begin

              term_name = user_analytics_data.term_name term
              courses = user_analytics_data.courses term
              term_section_ccns = []

              if courses.any?
                courses.each do |course|
                  begin

                    course_sis_data = user_analytics_data.sis_course_data course
                    course_code = course_sis_data[:code]
                    sections = user_analytics_data.sections course
                    sections.each do |section|
                      begin

                        section_sis_data = user_analytics_data.sis_section_data section
                        term_section_ccns << section_sis_data[:ccn]

                        row = [student.uid, term_name, course_code, course_sis_data[:title], section_sis_data[:ccn], "#{section_sis_data[:component]} #{section_sis_data[:number]}",
                               section_sis_data[:primary], course_sis_data[:midpoint], course_sis_data[:grade], course_sis_data[:grading_basis], course_sis_data[:units_completed], section_sis_data[:status]]
                        Utils.add_csv_row(user_course_sis_data, row)
                      rescue => e
                        BOACUtils.log_error_and_screenshot(@driver, e, "#{student.uid}-#{term_name}-#{course_code}-#{section_sis_data[:ccn]}")
                      end
                    end

                    drops = user_analytics_data.dropped_sections term
                    if drops
                      drops.each do |drop|
                        row = [student.uid, term_name, drop[:title], nil, nil, drop[:number], nil, nil, nil, nil, nil, 'D']
                        Utils.add_csv_row(user_course_sis_data, row)
                      end
                    end

                    user_analytics_data.course_sites(course).each do |site|
                      begin

                        site_metadata = user_analytics_data.site_metadata site
                        site_assigns = user_analytics_data.nessie_assigns_submitted site
                        site_grades = user_analytics_data.nessie_grades site

                        row = [student.uid, term_name, course_code, site_metadata[:code], site_metadata[:title], site_metadata[:site_id],
                               site_assigns[:min], site_assigns[:score], site_assigns[:max], site_assigns[:perc_round],
                               site_grades[:min], site_grades[:score], site_grades[:max], site_grades[:perc_round]]

                        Utils.add_csv_row(user_course_site_data, row)
                      rescue => e
                        BOACUtils.log_error_and_screenshot(@driver, e, "#{student.uid}-#{term_name}-#{course_code}")
                      end
                    end

                  rescue => e
                    BOACUtils.log_error_and_screenshot(@driver, e, "#{student.uid}-#{term_name}")
                  end
                end

              else
                logger.info "UID #{student.uid} has no courses in term #{term_name}"
              end
            rescue => e
              BOACUtils.log_error_and_screenshot(@driver, e, "#{student.uid}")
            end
          end
        rescue => e
          BOACUtils.log_error_and_screenshot(@driver, e, "#{student.uid}")
        end
      else
        logger.info "UID #{student.uid} has no terms"
      end
    rescue => e
      BOACUtils.log_error_and_screenshot(@driver, e, "#{student.uid}")
    ensure
      if analytics_api_sis_data
        row = [student.uid, student.full_name, analytics_api_sis_data[:preferred_name], analytics_api_sis_data[:email],
               analytics_api_sis_data[:phone], analytics_api_sis_data[:cumulative_units], analytics_api_sis_data[:cumulative_gpa], analytics_api_sis_data[:level],
               analytics_api_sis_data[:majors] && (analytics_api_sis_data[:majors].map {|m| m[:college]}) * '; ',
               analytics_api_sis_data[:majors] && (analytics_api_sis_data[:majors].map {|m| m[:major]) * '; ',
               analytics_api_sis_data[:terms_in_attendance], analytics_api_sis_data[:reqt_writing], analytics_api_sis_data[:reqt_history],
               analytics_api_sis_data[:reqt_institutions], analytics_api_sis_data[:reqt_cultures], analytics_api_sis_data[:expected_grad_term_name], alert_msgs]
        Utils.add_csv_row(user_profile_sis_data, row)
      end
    end
  end

rescue => e
  Utils.log_error e
ensure
  Utils.quit_browser @driver
end
