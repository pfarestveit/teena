require_relative '../util/spec_helper'

include Logging

begin

  test = BOACTestConfig.new
  if BOACUtils.base_url.include? 'boa-'
    test.sis_student_data
  else
    test.test_students = ENV['UIDS'].split.map { |u| BOACUser.new uid: u }
  end

  courses_heading = %w(Term Course Title Format Units)
  courses_csv = Utils.create_test_output_csv('boac-class-page-courses.csv', courses_heading)

  meetings_heading = %w(Term Instructors Days Time Location)
  meetings_csv = Utils.create_test_output_csv('boac-class-page-meetings.csv', meetings_heading)

  students_sis_heading = %w(Term Course UID MidPoint Basis Grade)
  students_sis_csv = Utils.create_test_output_csv('boac-class-page-student-sis.csv', students_sis_heading)

  students_canvas_heading = %w(Term SID SiteId SiteCode SubmittedUser SubmittedMax ScoreUser ScoreMax)
  students_canvas_csv = Utils.create_test_output_csv('boac-class-page-student-canvas.csv', students_canvas_heading)

  missing_heading = %w(Term Course UID)
  missing_students_csv = Utils.create_test_output_csv('boac-class-page-missing_students.csv', missing_heading)

  @driver = Utils.launch_browser test.chrome_profile
  @homepage = BOACHomePage.new @driver
  if BOACUtils.base_url.include? 'boa-'
    @homepage.dev_auth test.advisor
  else
    @cal_net = Page::CalNetPage.new @driver
    @homepage.log_in(Utils.super_admin_username, Utils.super_admin_password, @cal_net)
  end
  test.test_students.each do |student|
    begin

      sleep 3 unless BOACUtils.base_url.include? 'boa-'
      api_user_page = BOACApiStudentPage.new @driver
      api_user_page.get_data(@driver, student)

      terms = api_user_page.terms
      if terms.any?
        terms.each do |term|
          begin

            term_name = api_user_page.term_name term
            term_id = api_user_page.term_id term
            logger.info "Checking term #{term_name}"

            courses = api_user_page.courses term
            courses.each do |course|
              begin

                api_course = api_user_page.sis_course_data course
                unless api_course[:code].include? 'PHYS ED'
                  logger.info "Checking course #{api_course[:code]}"

                  sections = api_user_page.sections course
                  sections.each do |section|
                    begin

                      api_section = api_user_page.sis_section_data section

                      api_section_page = BOACApiSectionPage.new @driver
                      sleep 3 unless BOACUtils.base_url.include? 'boa-'
                      api_section_page.get_data(@driver, term_id, api_section[:ccn])
                      test_case = "term #{term_name} course #{api_course[:code]} section #{api_section[:component]} #{api_section[:number]} #{api_section[:ccn]}"
                      logger.info "Checking #{test_case}"

                      # COURSE AND MEETING DATA

                      row = [
                        term_name,
                        api_course[:title],
                        "#{api_section[:component]} #{api_section[:number]}",
                        api_section[:units_completed]
                      ]
                      Utils.add_csv_row(courses_csv, row)

                      api_section_page.meetings.each do |meet|
                        expected_location = "#{meet[:location]}#{' — ' if meet[:location] && meet[:mode]}#{meet[:mode]}"
                        row = [
                          term_name,
                          meet[:instructors],
                          meet[:days],
                          meet[:time],
                          expected_location
                        ]
                        Utils.add_csv_row(meetings_csv, row)
                      end

                      # STUDENT DATA

                      unless api_section_page.student_sids.length > BOACUtils.config['class_page_max_size']
                        expected_students = test.students.select { |s| api_section_page.student_sids.include? s.sis_id }
                        all_student_data = []

                        # Limit the detailed tests to a configurable number of students in the class
                        expected_students.sort_by! &:uid
                        expected_students.each do |student|

                          # Load the student's data and find the matching course
                          sleep 3 unless BOACUtils.base_url.include? 'boa-'
                          student_api = BOACApiStudentPage.new @driver
                          student_api.get_data(@driver, student)
                          term = student_api.terms.find { |t| student_api.term_name(t) == term_name }
                          course = student_api.courses(term).find { |c| student_api.course_display_name(c) == api_course[:code] }
                          if course
                            # Collect the student data relevant to the class page
                            student_class_page_data = {
                              uid: student.uid,
                              grading_basis: student_api.sis_course_data(course)[:grading_basis],
                              final_grade: student_api.sis_course_data(course)[:grade],
                              midpoint_grade: student_api.sis_course_data(course)[:midpoint],
                              sites: (student_api.course_sites(course).map do |site|
                                {
                                  site_id: student_api.site_metadata(site)[:site_id],
                                  site_code: student_api.site_metadata(site)[:code],
                                  nessie_assigns_submitted: student_api.nessie_assigns_submitted(site),
                                  nessie_grades: student_api.nessie_grades(site)
                                }
                              end)
                            }
                            all_student_data << student_class_page_data
                          else
                            logger.warn "No matching student course for UID #{student.uid} #{api_course[:code]}"
                            row = [
                              term_name,
                              api_course[:code],
                              student.uid
                            ]
                            Utils.add_csv_row(missing_students_csv, row)
                          end
                        end

                        expected_students.each do |classmate|
                          student_data = all_student_data.find { |d| d[:uid] == classmate.uid }
                          row = [
                            term_name,
                            api_course[:title],
                            classmate.uid,
                            (student_data && student_data[:mid_point_grade]),
                            (student_data && student_data[:grading_basis]),
                            (student_data && student_data[:final_grade])
                          ]
                          Utils.add_csv_row(students_sis_csv, row)

                          # Check the student's course site data
                          student_data && student_data[:sites].each do |site|
                            row = [
                              term_name,
                              student_data[:uid],
                              site[:site_id],
                              site[:site_code],
                              site[:nessie_assigns_submitted][:score],
                              site[:nessie_assigns_submitted][:max],
                              site[:nessie_grades][:score],
                              site[:nessie_grades][:max]
                            ]
                            Utils.add_csv_row(students_canvas_csv, row)
                          end
                        end
                      end

                    rescue => e
                      BOACUtils.log_error_and_screenshot(@driver, e, "#{student.uid}-#{term_name}-#{api_course[:code]}")
                      logger.error "test hit an error with UID #{student.uid} term #{term_name} course #{api_course[:code]}"
                    end
                  end
                end

              rescue => e
                BOACUtils.log_error_and_screenshot(@driver, e, "#{student.uid}-#{term_name}-#{api_course[:code]}")
                logger.error "test hit an error with UID #{student.uid} term #{term_name} course #{api_course[:code]}"
              end
            end

          rescue => e
            BOACUtils.log_error_and_screenshot(@driver, e, "#{student.uid}-#{term_name}")
            logger.error "test hit an error with UID #{student.uid} term #{term_name}"
          end
        end
      end

    rescue => e
      BOACUtils.log_error_and_screenshot(@driver, e, "#{student.uid}")
      logger.error "test hit an error with UID #{student.uid}"
    end
  end

rescue => e
  Utils.log_error e
  logger.error 'test hit an error'
ensure
  Utils.quit_browser @driver
end
