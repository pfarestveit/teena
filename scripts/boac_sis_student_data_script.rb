require_relative '../util/spec_helper'

include Logging

begin
  test = BOACTestConfig.new
  test.sis_student_data

  profile_data_heading = %w(UID MajorsIntend NonActive)
  profile_csv = Utils.create_test_output_csv('boac-sis-profiles.csv', profile_data_heading)

  standing_heading = %w(UID Term Standing)
  standing_csv = Utils.create_test_output_csv('boac-standing.csv', standing_heading)

  course_data_heading = %w(UID Term SectionCcn SectionCode Primary? Midpoint Grade GradingBasis Units EnrollmentStatus DropDate)
  courses_csv = Utils.create_test_output_csv('boac-sis-courses.csv', course_data_heading)

  @driver = Utils.launch_browser test.chrome_profile
  @boac_homepage = BOACHomePage.new @driver
  if BOACUtils.base_url.include? 'boa-'
    @homepage.dev_auth test.advisor
  else
    @cal_net = CalNetPage.new @driver
    @homepage.log_in(Utils.super_admin_username, Utils.super_admin_password, @cal_net)
  end

  test.test_students.sort_by! &:uid
  test.test_students.each do |student|

    begin
      api_student_data = BOACApiStudentPage.new @driver
      api_student_data.get_data(@driver, student)
      api_sis_profile_data = api_student_data.sis_profile_data
      academic_standing = api_student_data.academic_standing
      non_active = %w(Completed Inactive).include?(api_sis_profile_data[:academic_career_status]) || api_sis_profile_data[:withdrawal]

      student_terms = api_student_data.terms
      if student_terms.any?
        student_terms.each do |term|
          begin
            term_name = api_student_data.term_name term
            term_id = api_student_data.term_id term
            term_section_ccns = []
            logger.info "Checking #{term_name}"

            if academic_standing&.any?
              term_standing = academic_standing.find { |s| s.term_id.to_s == term_id.to_s }
              if term_standing
                row = [
                  student.uid,
                  term_standing.term_name,
                  term_standing.descrip
                ]
                Utils.add_csv_row(standing_csv, row)
              end
            end

            courses = api_student_data.courses term
            if courses.any?
              courses.each do |course|
                begin
                  course_sis_data = api_student_data.sis_course_data course
                  course_code = course_sis_data[:code]
                  logger.info "Checking course #{course_code}"

                  section_statuses = []
                  api_student_data.sections(course).each do |section|
                    begin
                      section_sis_data = api_student_data.sis_section_data section
                      term_section_ccns << section_sis_data[:ccn]
                      section_statuses << section_sis_data[:status]

                    rescue => e
                      BOACUtils.log_error e
                      it("encountered an error for UID #{student.uid} term #{term_name} course #{course_code} section #{section_sis_data[:ccn]}") { fail }
                    ensure
                      unless ['Fall 2021', 'Summer 2021', 'Spring 2021'].include? term_name
                        row = [student.uid,
                               term_name,
                               section_sis_data[:ccn],
                               "#{section_sis_data[:component]} #{section_sis_data[:number]}",
                               section_sis_data[:primary],
                               course_sis_data[:midpoint],
                               course_sis_data[:grade],
                               course_sis_data[:grading_basis],
                               course_sis_data[:units_completed],
                               section_sis_data[:status]]
                        Utils.add_csv_row(courses_csv, row)
                      end
                    end
                  end

                rescue => e
                  BOACUtils.log_error e
                  it("encountered an error for UID #{student.uid} term #{term_name} course #{course_code}") { fail }
                end
              end

            else
              logger.warn "No course data in #{term_name}"
            end

            drops = api_student_data.dropped_sections term
            if drops
              drops.each do |drop|
                row = [student.uid,
                       term_name,
                       nil,
                       "#{drop[:component]} #{drop[:number]}",
                       nil,
                       nil,
                       nil,
                       nil,
                       nil,
                       'D',
                       drop[:date]
                ]
                Utils.add_csv_row(courses_csv, row)
              end
            end

          rescue => e
            BOACUtils.log_error e
            it("encountered an error for UID #{student.uid} term #{term_name}") { fail "#{e.message + "\n"} #{e.backtrace.join("\n ")}" }
          end
        end

      else
        logger.warn "UID #{student.uid} has no term data"
      end

    rescue => e
      BOACUtils.log_error e
      it("encountered an error for UID #{student.uid}") { fail "#{e.message + "\n"} #{e.backtrace.join("\n ")}" }
    ensure
      row = [
        student.uid,
        api_sis_profile_data[:intended_majors],
        non_active
      ]
      Utils.add_csv_row(profile_csv, row)
    end
  end

rescue => e
  Utils.log_error e
  it('encountered an error') { fail "#{e.message + "\n"} #{e.backtrace.join("\n ")}" }
ensure
  Utils.quit_browser @driver
end
