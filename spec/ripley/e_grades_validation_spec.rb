require_relative '../../util/spec_helper'

include Logging

describe 'bCourses E-Grades Export' do

  begin

    test = RipleyTestConfig.new
    test.get_e_grades_test_sites
    letter_grades = %w(A+ A A- B+ B B- C+ C C- D+ D D- F)

    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasGradesPage.new @driver
    @canvas_api = CanvasAPIPage.new @driver
    @splash_page = RipleySplashPage.new @driver
    @e_grades_export_page = RipleyEGradesPage.new @driver

    @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
    @canvas.add_ripley_tools RipleyTool::TOOLS.select(&:account)

    test.course_sites.each_with_index do |site, i|

      begin
        @canvas.stop_masquerading
        section_ids = @canvas_api.get_course_site_sis_section_ids site.site_id
        test.get_existing_site_data(site, section_ids)

        instructors = RipleyUtils.get_primary_instructors site
        instructor = instructors.first
        primary_section = site.sections.find &:primary
        test_case = "#{site.course.term} #{site.course.code} site #{site.site_id}"
        @canvas.set_canvas_ids [instructor]

        # Disable existing grading scheme in case it is not default, then set default scheme
        @canvas.masquerade_as(instructor, site)
        students = @canvas.get_students(site, { enrollments: true, section: primary_section })

        %w(letter letter-only pnp sus).each do |scheme|

          @canvas.enable_grading_scheme site
          @canvas.set_grading_scheme({ scheme: scheme })

          # Get grades in Canvas
          @canvas.load_gradebook site
          grades_are_final = @canvas.grades_final?
          logger.info "Grades are final is #{grades_are_final}"
          @canvas.hit_escape
          gradebook_grades = students.first(RipleyUtils.e_grades_student_count).map do |stud|
            @canvas.student_score stud if stud.sis_id
          end
          gradebook_grades.compact!

          ### WITH A P/NP CUTOFF ###

          # Get grades in export CSV
          cutoff = i.even? ? 'C-' : 'A'
          e_grades = grades_are_final ?
                       @e_grades_export_page.download_final_grades(site, primary_section, cutoff) :
                       @e_grades_export_page.download_current_grades(site, primary_section, cutoff)

          if gradebook_grades.any?
            # Match the grade for each student
            gradebook_grades.each do |gradebook_row|
              begin

                # If an error occurred fetching a grade, then the row might cause an error in the test
                e_grades_row = e_grades.find do |e_grade|
                  e_grade[:id] == gradebook_row[:student].sis_id if gradebook_row.instance_of? Hash
                end
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

                  it "shows the grade '#{expected_grade}' for UID #{gradebook_row[:student].uid} in #{test_case}
                        with grading scheme #{scheme} and a P/NP cutoff of #{cutoff}" do
                    expect(e_grades_row[:grade]).to eql(expected_grade)
                  end

                  expected_comment = case e_grades_row[:grading_basis]
                                     when 'CPN', 'DPN', 'EPN', 'PNP'
                                       'P/NP grade'
                                     when 'ESU', 'SUS'
                                       'S/U grade'
                                     when 'CNC'
                                       'C/NC grade'
                                     else
                                       nil
                                     end
                  it "shows the comment '#{expected_comment}' for UID #{gradebook_row[:student].uid} in #{test_case}
                        with grading scheme #{scheme} and a P/NP cutoff of #{cutoff}" do
                    expect(e_grades_row[:comments]).to eql(expected_comment)
                  end
                end

              rescue => e
                Utils.log_error e
                it("encountered an unexpected error with #{site.course.code} #{gradebook_row}") { fail Utils.error(e) }
              end
            end

          else
            it("found no Canvas grades for #{site.course.code}") { fail }
          end

          ### WITH NO P/NP CUTOFF

          # Get grades in export CSV
          cutoff = nil
          e_grades = grades_are_final ?
                       @e_grades_export_page.download_final_grades(site, primary_section, cutoff) :
                       @e_grades_export_page.download_current_grades(site, primary_section, cutoff)

          if gradebook_grades.any?
            # Match the grade for each student
            gradebook_grades.each do |gradebook_row|
              begin

                # If an error occurred fetching a grade, then the row might cause an error in the test
                e_grades_row = e_grades.find do |e_grade|
                  e_grade[:id] == gradebook_row[:student].sis_id if gradebook_row.instance_of? Hash
                end
                if e_grades_row && gradebook_row[:grade]

                  expected_grade = gradebook_row[:grade]

                  it "shows the grade '#{expected_grade}' for UID #{gradebook_row[:student].uid} in #{test_case}
                        with grading scheme #{scheme} and no P/NP cutoff" do
                    expect(e_grades_row[:grade]).to eql(expected_grade)
                  end

                  expected_comment = case e_grades_row[:grading_basis]
                                     when 'CPN', 'DPN', 'EPN', 'PNP'
                                       'P/NP grade'
                                     when 'ESU', 'SUS'
                                       'S/U grade'
                                     when 'CNC'
                                       'C/NC grade'
                                     else
                                       nil
                                     end
                  it "shows the comment '#{expected_comment}' for UID #{gradebook_row[:student].uid} #{test_case}
                        with grading scheme #{scheme} and no P/NP cutoff" do
                    expect(e_grades_row[:comments]).to eql(expected_comment)
                  end
                end

              rescue => e
                Utils.log_error e
                it("encountered an unexpected error with #{site.course.code} #{gradebook_row}") { fail Utils.error(e) }
              end
            end
          end
        end
      rescue => e
        Utils.log_error e
        it("encountered an unexpected error with #{site.course.code}") { fail Utils.error(e) }
      end
    end
  rescue => e
    Utils.log_error e
    it('encountered an unexpected error') { fail Utils.error(e) }
  ensure
    Utils.quit_browser @driver
  end
end
