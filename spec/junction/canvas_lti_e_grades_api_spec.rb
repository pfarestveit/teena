require_relative '../../util/spec_helper'

include Logging

describe 'bCourses E-Grades Export' do

  begin

    test_courses_data = JunctionUtils.load_junction_test_course_data.select { |course| course['tests']['e_grades_api'] }
    courses = test_courses_data.map { |c| Course.new c }
    letter_grades = %w(A+ A A- B+ B B- C+ C C- D+ D D- F)

    # If using Chrome, use a new Chrome profile
    Utils.config['webdriver']['chrome_profile'] = false

    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasGradesPage.new @driver
    @splash_page = Page::JunctionPages::SplashPage.new @driver
    @e_grades_export_page = Page::JunctionPages::CanvasEGradesExportPage.new @driver
    @rosters_api = ApiAcademicsRosterPage.new @driver

    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)

    courses.each_with_index do |course, i|

      begin

        # Get SIS roster
        instructor = User.new course.teachers.first
        primary_section = Section.new course.sections.first
        @splash_page.load_page
        @splash_page.basic_auth(instructor.uid, @cal_net)
        rosters_api = ApiAcademicsRosterPage.new @driver
        rosters_api.get_feed(@driver, course)

        # Disable existing grading scheme in case it is not default, then set default scheme
        @canvas.masquerade_as(instructor, course)

        %w(letter letter-only pnp sus).each do |scheme|

          @canvas.enable_grading_scheme course
          @canvas.set_grading_scheme({scheme: scheme})

          # Get grades in Canvas
          students = @canvas.get_students(course, primary_section)
          @canvas.load_gradebook course
          grades_are_final = @canvas.grades_final?
          logger.info "Grades are final is #{grades_are_final}"
          @canvas.hit_escape
          gradebook_grades = students.map do |user|
            user.sis_id = rosters_api.sid_from_uid user.uid
            @canvas.student_score user unless user.sis_id.nil?
          end
          gradebook_grades.compact!
          logger.debug "Gradebook grades: #{gradebook_grades}"

          ### WITH A P/NP CUTOFF ###

          # Get grades in export CSV
          cutoff = i.even? ? 'C-' : 'A'
          e_grades = grades_are_final ?
                         @e_grades_export_page.download_final_grades(@driver, course, primary_section, cutoff) :
                         @e_grades_export_page.download_current_grades(@driver, course, primary_section, cutoff)

          if gradebook_grades.any?
            # Match the grade for each student
            gradebook_grades.each do |gradebook_row|
              begin

                # If an error occurred fetching a grade, then the row might cause an error in the test
                e_grades_row = e_grades.find { |e_grade| e_grade[:id] == gradebook_row[:sis_id] if gradebook_row.instance_of? Hash }
                if e_grades_row && gradebook_row[:grade]

                  expected_grade = if %w(letter letter-only).include? scheme
                                     if e_grades_row[:grading_basis] == 'GRD'
                                       gradebook_row[:grade]
                                     else
                                       pass = letter_grades.index(gradebook_row[:grade]) <= letter_grades.index(cutoff)
                                       if %w(ESU SUS).include? e_grades_row[:grading_basis]
                                         pass ? 'S' : 'U'
                                       else
                                         pass ? 'P' : 'NP'
                                       end
                                     end
                                   else
                                     gradebook_row[:grade]
                                   end


                  it "shows the grade '#{expected_grade}' for UID #{gradebook_row[:uid]} in #{course.term} #{course.code}
                      site #{course.site_id} with grading scheme #{scheme} and a P/NP cutoff of #{cutoff}" do
                    expect(e_grades_row[:grade]).to eql(expected_grade)
                  end

                  expected_comment = case e_grades_row[:grading_basis]
                                     when 'GRD'
                                       'Opted for letter grade'
                                     when 'ESU', 'SUS'
                                       'S/U grade'
                                     when 'CNC'
                                       'C/NC grade'
                                     else
                                       ''
                                     end
                  it "shows the comment '#{expected_comment}' for UID #{gradebook_row[:uid]} in #{course.term} #{course.code}
                      site #{course.site_id} with grading scheme #{scheme} and a P/NP cutoff of #{cutoff}" do
                    expect(e_grades_row[:comments]).to eql(expected_comment)
                  end
                end

              rescue => e
                # Catch and report errors related to the user
                Utils.log_error e
                it("encountered an unexpected error with #{course.code} #{gradebook_row}") { fail }
              end
            end

          else
            it("found no Canvas grades for #{course.code}") { fail }
          end

          ### WITH NO P/NP CUTOFF

          # Get grades in export CSV
          cutoff = nil
          e_grades = grades_are_final ?
                         @e_grades_export_page.download_final_grades(@driver, course, primary_section, cutoff) :
                         @e_grades_export_page.download_current_grades(@driver, course, primary_section, cutoff)

          if gradebook_grades.any?
            # Match the grade for each student
            gradebook_grades.each do |gradebook_row|
              begin

                # If an error occurred fetching a grade, then the row might cause an error in the test
                e_grades_row = e_grades.find { |e_grade| e_grade[:id] == gradebook_row[:sis_id] if gradebook_row.instance_of? Hash }
                if e_grades_row && gradebook_row[:grade]

                  expected_grade = gradebook_row[:grade]

                  it "shows the grade '#{expected_grade}' for UID #{gradebook_row[:uid]} in #{course.term} #{course.code}
                      site #{course.site_id} with grading scheme #{scheme} and no P/NP cutoff" do
                    expect(e_grades_row[:grade]).to eql(expected_grade)
                  end

                  expected_comment = case e_grades_row[:grading_basis]
                                     when 'GRD'
                                       'Opted for letter grade'
                                     when 'ESU', 'SUS'
                                       'S/U grade'
                                     when 'CNC'
                                       'C/NC grade'
                                     else
                                       ''
                                     end
                  it "shows the comment '#{expected_comment}' for UID #{gradebook_row[:uid]} in #{course.term} #{course.code}
                      site #{course.site_id} with grading scheme #{scheme} and no P/NP cutoff" do
                    expect(e_grades_row[:comments]).to eql(expected_comment)
                  end
                end

              rescue => e
                # Catch and report errors related to the user
                Utils.log_error e
                it("encountered an unexpected error with #{course.code} #{gradebook_row}") { fail }
              end
            end
          end
        end
      rescue => e
        # Catch and report errors related to the course
        Utils.log_error e
        it("encountered an unexpected error with #{course.code}") { fail }
      end
    end
  rescue => e
    # Catch and report errors related to the whole test
    Utils.log_error e
    it('encountered an unexpected error') { fail }
  ensure
    @driver.quit
  end
end
