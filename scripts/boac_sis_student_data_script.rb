require_relative '../util/spec_helper'

include Logging

begin
  test = BOACTestConfig.new
  if BOACUtils.base_url.include? 'boa-'
    test.sis_student_data
  else
    test.test_students = ENV['UIDS'].split.map { |u| BOACUser.new uid: u }
  end

  profile_data_heading = %w(UID Name PreferredName Email EmailAlt Phone Units GPA Level Transfer Colleges Majors
                            CollegesDisc MajorsDisc Minors MinorsDisc Terms Writing History Institutions Cultures
                            Advisors EnteredTerm MajorsIntend Visa GradExpect GradDegree GradDate GradColleges Inactive
                            Alerts Holds)
  profile_csv = Utils.create_test_output_csv('boac-sis-profiles.csv', profile_data_heading)

  standing_heading = %w(UID Term Standing)
  standing_csv = Utils.create_test_output_csv('boac-standing.csv', standing_heading)

  course_data_heading = %w(UID Term SectionCcn SectionCode Primary? Midpoint Grade GradingBasis Units EnrollmentStatus DropDate)
  courses_csv = Utils.create_test_output_csv('boac-sis-courses.csv', course_data_heading)

  notes_heading = %w(UID ID AdvisorUID AdvisorName AdvisorEmail AdvisorDepts Subj Body Topics Attach Created Updated)
  notes_csv = Utils.create_test_output_csv('boac-sis-notes.csv', notes_heading)

  appts_heading = %w(UID ID AdvisorUID AdvisorName AdvisorDepts Subj Detail Attach Created Updated)
  appts_csv = Utils.create_test_output_csv('boac-sis-appts.csv', appts_heading)

  @driver = Utils.launch_browser test.chrome_profile
  @boac_homepage = BOACHomePage.new @driver
  if BOACUtils.base_url.include? 'boa-'
    @boac_homepage.dev_auth test.advisor
  else
    @cal_net = Page::CalNetPage.new @driver
    @boac_homepage.log_in(Utils.super_admin_username, Utils.super_admin_password, @cal_net)
  end

  test.test_students.sort_by! &:uid
  test.test_students.each do |student|

    begin
      sleep 3 unless BOACUtils.base_url.include? 'boa-'
      api_student_data = BOACApiStudentPage.new @driver
      api_student_data.get_data(@driver, student)

      api_sis_profile_data = api_student_data.sis_profile_data
      graduation = api_student_data.graduation
      academic_standing = api_student_data.academic_standing
      visa = api_student_data.visa
      advisors = api_student_data.advisors
      non_active = %w(Completed Inactive).include?(api_sis_profile_data[:academic_career_status]) || api_sis_profile_data[:withdrawal]

      active_major_feed, inactive_major_feed = api_sis_profile_data[:majors].compact.partition { |m| m[:active] }
      active_majors = active_major_feed.map { |m| m[:major] }
      active_colleges = active_major_feed.map { |m| m[:college] }.compact
      inactive_majors = inactive_major_feed.map { |m| m[:major] }
      inactive_colleges = inactive_major_feed.map { |m| m[:college] }.compact
      active_minor_feed, inactive_minor_feed = api_sis_profile_data[:minors].partition { |m| m[:active] }
      active_minors = active_minor_feed.map { |m| m[:minor] }
      inactive_minors = inactive_minor_feed.map { |m| m[:minor] }

      notes = api_student_data.notes
      appts = api_student_data.appointments

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
                      logger.error "encountered an error for UID #{student.uid} term #{term_name} course #{course_code} section #{section_sis_data[:ccn]}"
                      logger.error "#{e.message + "\n"} #{e.backtrace.join("\n ")}"
                    ensure
                      unless term_name == BOACUtils.term
                        row = [student.uid,
                               term_name,
                               section_sis_data[:ccn],
                               course_sis_data[:code].delete('&, '),
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
                  logger.error "encountered an error for UID #{student.uid} term #{term_name} course #{course_code}"
                  logger.error "#{e.message + "\n"} #{e.backtrace.join("\n ")}"
                end
              end

            else
              logger.warn "No course data in #{term_name}"
            end

            drops = api_student_data.dropped_sections term
            if drops
              drops.each do |drop|
                unless term_name == BOACUtils.term
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
                         nil
                  ]
                  Utils.add_csv_row(courses_csv, row)
                end
             end
            end

          rescue => e
            BOACUtils.log_error e
            logger.error "encountered an error for UID #{student.uid} term #{term_name}"
            logger.error "#{e.message + "\n"} #{e.backtrace.join("\n ")}"
          end
        end

      else
        logger.warn "UID #{student.uid} has no term data"
      end

    rescue => e
      BOACUtils.log_error e
      logger.error "encountered an error for UID #{student.uid}"
      logger.error "#{e.message + "\n"} #{e.backtrace.join("\n ")}"
    ensure
      row = [
        student.uid,
        api_sis_profile_data[:name],
        api_sis_profile_data[:preferred_name],
        api_sis_profile_data[:email],
        api_sis_profile_data[:email_alternate],
        api_sis_profile_data[:phone],
        api_sis_profile_data[:cumulative_units],
        api_sis_profile_data[:cumulative_gpa],
        api_sis_profile_data[:level],
        api_sis_profile_data[:transfer],
        active_colleges,
        active_majors,
        inactive_colleges,
        inactive_majors,
        active_minors,
        inactive_minors,
        api_sis_profile_data[:terms_in_attendance],
        api_sis_profile_data[:reqt_writing],
        api_sis_profile_data[:reqt_history],
        api_sis_profile_data[:reqt_institutions],
        api_sis_profile_data[:reqt_cultures],
        advisors,
        api_sis_profile_data[:entered_term],
        api_sis_profile_data[:intended_majors],
        visa,
        api_sis_profile_data[:expected_grad_term_id],
        (graduation && graduation[:degree]),
        (graduation && graduation[:date]),
        (graduation && graduation[:colleges]),
        non_active
      ]
      Utils.add_csv_row(profile_csv, row)

      notes&.map do |n|
        if n.id.include?('-') && !n.id.include?('eform')
          row = [
            student.uid,
            n.id,
            n.advisor&.uid,
            n.advisor&.full_name,
            n.advisor&.email,
            n.advisor&.depts,
            n.subject,
            n.body,
            n.topics,
            n.attachments,
            n.created_date,
            n.updated_date
          ]
          Utils.add_csv_row(notes_csv, row)
        end
      end

      appts&.map do |a|
        if a.id.include?('-') && !a.subject.include?('L&S Advising Appt:')
          row = [
            student.uid,
            a.id,
            a.advisor&.uid,
            a.advisor&.full_name,
            a.advisor&.depts,
            a.subject,
            a.detail,
            a.attachments,
            a.created_date,
            a.updated_date
          ]
          Utils.add_csv_row(appts_csv, row)
        end
      end
    end
  end

rescue => e
  Utils.log_error e
  logger.error 'encountered an error'
  logger.error "#{e.message + "\n"} #{e.backtrace.join("\n ")}"
ensure
  Utils.quit_browser @driver
end
