require_relative '../../util/spec_helper'

describe 'BOAC' do

  include Logging

  begin

    # This script is team-driven, so only an ASC advisor can be used
    advisor = BOACUtils.get_dept_advisors(BOACDepartments::ASC).first
    team = BOACUtils.class_page_team

    pages_tested = []
    all_students = BOACUtils.get_all_athletes
    team_members = BOACUtils.get_team_members(team, all_students)

    courses_csv = Utils.create_test_output_csv('boac-class-page-courses.csv', %w(Term Course Title Format Units))
    meetings_csv =Utils.create_test_output_csv('boac-class-page-meetings.csv', %w(Term Course Instructors Days Time Location))
    students_sis_csv = Utils.create_test_output_csv('boac-class-page-student-sis.csv', %w(Term Course SID Level Majors Sports MidPoint Basis Grade))
    students_canvas_csv = Utils.create_test_output_csv('boac-class-page-student-canvas.csv', %w(Term Course SID SiteId SiteCode SubmittedUser SubmittedMax ScoreUser ScoreMax))

    @driver = Utils.launch_browser
    @homepage = Page::BOACPages::HomePage.new @driver
    @student_page = Page::BOACPages::StudentPage.new @driver
    @class_page = Page::BOACPages::ClassPage.new @driver

    @homepage.dev_auth advisor

    BOACUtils.constrained_users(team_members).each do |athlete|
      begin

        api_user_page = ApiUserAnalyticsPage.new @driver
        api_user_page.get_data(@driver, athlete)

        terms = api_user_page.terms
        if terms.any?
          @student_page.load_page athlete
          @student_page.click_view_previous_semesters if terms.length > 1

          terms.each do |term|
            begin

              term_name = api_user_page.term_name term
              term_id = api_user_page.term_id term
              logger.info "Checking term #{term_name}"

              courses = api_user_page.courses term
              courses.each do |course|
                begin

                  course_sis_data = api_user_page.course_sis_data course
                  unless course_sis_data[:code].include? 'PHYS ED'
                    logger.info "Checking course #{course_sis_data[:code]}"

                    sections = api_user_page.sections course
                    sections.each do |section|
                      begin

                        section_data = api_user_page.section_sis_data section
                        api_section_page = ApiSectionPage.new @driver
                        api_section_page.get_data(@driver, term_id, section_data[:ccn])
                        class_test_case = "term #{term_name} course #{course_sis_data[:code]} section #{section_data[:component]} #{section_data[:number]} #{section_data[:ccn]}"
                        logger.info "Checking #{class_test_case}"

                        # Check that a class page link is present if the section is primary
                        @student_page.load_page athlete
                        @student_page.click_view_previous_semesters if terms.length > 1
                        class_page_link_present = @student_page.verify_block { @student_page.class_page_link(term_id, section_data[:ccn]).when_present 1 }
                        section_data[:primary] ?
                            it("shows a class page link for #{class_test_case}") { expect(class_page_link_present).to be true } :
                            it("shows no class page link for #{class_test_case}") { expect(class_page_link_present).to be false }

                        # Check the class page only if it has not already been checked during a previous loop
                        if class_page_link_present && !pages_tested.include?("#{term_id} #{section_data[:ccn]}")
                          @student_page.click_class_page_link(term_id, section_data[:ccn])
                          pages_tested << "#{term_id} #{section_data[:ccn]}"

                          # COURSE AND MEETING DATA

                          # Check that the course + section info is presented as expected
                          visible_course_data = @class_page.visible_course_data
                          section_course_code = course_sis_data[:code].gsub("#{section_data[:component]} #{section_data[:number]}", '').strip
                          it("shows the right term for #{class_test_case}") { expect(visible_course_data[:term]).to eql(term_name) }
                          it("shows the right course code for #{class_test_case}") { expect(visible_course_data[:code]).to eql(section_course_code) }
                          it("shows the right course title for #{class_test_case}") { expect(visible_course_data[:title]).to eql(course_sis_data[:title]) }
                          it("shows the right section units for #{class_test_case}") { expect(visible_course_data[:units]).to eql(section_data[:units]) }
                          it("shows the right section format for #{class_test_case}") { expect(visible_course_data[:format]).to eql(section_data[:component]) }
                          it("shows the right section number for #{class_test_case}") { expect(visible_course_data[:number]).to eql(section_data[:number]) }
                          it("shows no empty course data for #{class_test_case}") do
                            expect(visible_course_data.values.all?).to be true
                            expect(visible_course_data.values.any? &:empty?).to be false
                          end

                          Utils.add_csv_row(courses_csv, [term_name, section_course_code, course_sis_data[:title], "#{section_data[:component]} #{section_data[:number]}", section_data[:units]])

                          # Check that the section schedules are presented as expected
                          api_section_page.meetings.each do |meet|
                            node = api_section_page.meetings.index(meet) + 1
                            visible_meeting_data = @class_page.visible_meeting_data(@driver, node)
                            it("shows the right instructors for meeting #{node} for #{class_test_case}") { expect(visible_meeting_data[:instructors]).to eql(meet[:instructors]) }
                            it("shows the right days for meeting #{node} for #{class_test_case}") { expect(visible_meeting_data[:days]).to eql(meet[:days]) }
                            it("shows the right time for meeting #{node} for #{class_test_case}") { expect(visible_meeting_data[:time]).to eql(meet[:time]) }
                            it("shows the right location for meeting #{node} for #{class_test_case}") { expect(visible_meeting_data[:location]).to eql(meet[:location]) }
                            # Some meeting data is expected to be empty, but report missing data anyway for further inspection
                            it("shows no empty meeting data for meeting #{node} for #{class_test_case}") do
                              expect(visible_meeting_data.values.all?).to be true
                              expect(visible_meeting_data.values.any? &:empty?).to be false
                            end

                            Utils.add_csv_row(meetings_csv, [term_name, section_course_code, meet[:instructors], meet[:days], meet[:time], meet[:location]])
                          end

                          # STUDENT DATA

                          # Check that all student who should appear actually do
                          visible_sids = @class_page.visible_sids.sort
                          logger.error "Expecting #{api_section_page.student_sids.sort} but got #{visible_sids}" unless visible_sids == api_section_page.student_sids.sort
                          it("shows the right students for #{class_test_case}") { expect(visible_sids.sort).to eql(api_section_page.student_sids.sort) }

                          # Perform further tests on the students who do appear
                          students = all_students.select { |s| visible_sids.include? s.sis_id }
                          expected_student_names = (students.map { |u| "#{u.last_name}, #{u.first_name}" }).sort
                          visible_student_names = (@class_page.list_view_names).sort
                          logger.error "Expecting #{expected_student_names} and got #{visible_student_names}" unless visible_student_names == expected_student_names
                          it("shows all the expected students for #{class_test_case}") { expect(visible_student_names).to eql(expected_student_names) }
                          it("shows no blank student names for #{class_test_case}") { expect(visible_student_names.any? &:empty?).to be false }

                          # Collect all the expected class page data for each student in the class
                          all_student_data = []
                          students.each do |student|

                            # Load the student's data and find the matching course
                            student_api = ApiUserAnalyticsPage.new @driver
                            student_api.get_data(@driver, student)
                            term = student_api.terms.find { |t| student_api.term_name(t) == term_name }
                            course = student_api.courses(term).find { |c| student_api.course_display_name(c) == course_sis_data[:code] }
                            student_squad_names = student.sports.map do |squad_code|
                              squad = Squad::SQUADS.find { |s| s.code == squad_code }
                              squad.name
                            end

                            # Collect the student data relevant to the class page
                            student_class_page_data = {
                              :sid => student.sis_id,
                              :level => student_api.user_sis_data[:level],
                              :majors => student_api.user_sis_data[:majors],
                              :sports => student_squad_names,
                              :grading_basis => student_api.course_sis_data(course)[:grading_basis],
                              :final_grade => student_api.course_sis_data(course)[:grade],
                              :midpoint_grade => student_api.course_sis_data(course)[:midpoint],
                              :sites => (student_api.course_sites(course).map do |site|
                                {
                                  :site_id => student_api.site_metadata(site)[:site_id],
                                  :site_code => student_api.site_metadata(site)[:code],
                                  :nessie_assigns_submitted => student_api.nessie_assigns_submitted(site),
                                  :nessie_grades => student_api.nessie_grades(site)
                                }
                              end)
                            }
                            all_student_data << student_class_page_data
                          end

                          @class_page.load_page(term_id, section_data[:ccn])
                          students.each do |student|
                            logger.info "Checking UID #{student.uid}"
                            student_test_case = "UID #{student.uid} #{class_test_case}"
                            student_data = all_student_data.find { |d| d[:sid] == student.sis_id }

                            # Check the student's SIS and ASC data
                            visible_student_sis_data = @class_page.visible_student_sis_data(@driver, student)
                            it("shows the right level for #{student_test_case}") do
                              expect(visible_student_sis_data[:level]).to eql(student_data[:level])
                              expect(visible_student_sis_data[:level]).not_to be_empty
                            end

                            it("shows the right majors for #{student_test_case}") do
                              expect(visible_student_sis_data[:majors]).to eql(student_data[:majors].sort)
                              expect(visible_student_sis_data[:majors]).not_to be_empty
                            end

                            it("shows the right sports for #{student_test_case}") { expect(visible_student_sis_data[:sports]).to eql(student_data[:sports].sort) }

                            if student_data[:grading_basis] == 'NON' || !student_data[:final_grade].empty?
                              it("shows no grading basis for #{student_test_case}") { expect(visible_student_sis_data[:grading_basis]).to be_nil }
                            else
                              it "shows the grading basis for #{student_test_case}" do
                                expect(visible_student_sis_data[:grading_basis]).not_to be_empty
                                expect(visible_student_sis_data[:grading_basis]).to eql(student_data[:grading_basis])
                              end
                            end

                            if student_data[:final_grade] && !student_data[:final_grade].empty?
                              it "shows the grade for #{student_test_case}" do
                                expect(visible_student_sis_data[:final_grade]).not_to be_empty
                                expect(visible_student_sis_data[:final_grade]).to eql(student_data[:final_grade])
                              end
                            else
                              it("shows no grade for #{student_test_case}") { expect(visible_student_sis_data[:final_grade]).to be_nil }
                            end

                            if student_data[:midpoint_grade]
                              it "shows the midpoint grade for #{student_test_case}" do
                                expect(visible_student_sis_data[:mid_point_grade]).not_to be_empty
                                expect(visible_student_sis_data[:mid_point_grade]).to eql(student_data[:midpoint_grade])
                              end
                            else
                              it("shows no midpoint grade for #{student_test_case}") { expect(visible_student_sis_data[:midpoint_grade]).to be_nil }
                            end

                            Utils.add_csv_row(students_sis_csv, [term_name, section_course_code, student_data[:sid], student_data[:level], student_data[:majors], student_data[:sports], student_data[:mid_point_grade], student_data[:grading_basis], student_data[:final_grade]])

                            # Check the student's course site data
                            student_data[:sites].each do |site|
                              site_test_case = "#{student_test_case} site ID #{site[:site_id]}"
                              index = student_data[:sites].index site
                              visible_site_data = @class_page.visible_assigns_data(@driver, student, index)
                              logger.debug "Checking #{site_test_case} at node #{index + 1}, code #{site[:site_code]}"

                              if site[:nessie_assigns_submitted][:score].empty?
                                it("shows a 'No Data' assignments submitted count for #{site_test_case}") { expect(visible_site_data[:assigns_submit_no_data]).to be_truthy }
                              else
                                it("shows the assignments submitted count for #{site_test_case}") { expect(visible_site_data[:assigns_submitted]).to eql(site[:nessie_assigns_submitted][:score]) }
                                it("shows the assignments submitted max for #{site_test_case}") { expect(visible_site_data[:assigns_submitted_max]).to eql(site[:nessie_assigns_submitted][:max]) }
                              end

                              # Currently no grades data is shown unless it can produce a boxplot
                              site[:nessie_grades][:score].empty? ?
                                  (it("shows a 'No Data' assignments score for #{site_test_case}") { expect(visible_site_data[:assigns_grade_no_data]).to be_truthy }) :
                                  (it("shows the assignments score for #{site_test_case}") { expect(visible_site_data[:assigns_grade]).to eql(site[:nessie_grades][:score]) })

                              Utils.add_csv_row(students_canvas_csv, [term_name, section_course_code, student_data[:sid], site[:site_id], site[:site_code], site[:nessie_assigns_submitted][:score], site[:nessie_assigns_submitted][:max], site[:nessie_grades][:score], site[:nessie_grades][:max]])

                            end

                            # TODO - the 'max' values are the same for all users

                          end
                        end

                      rescue => e
                        Utils.log_error e
                        it("test hit an error with UID #{athlete.uid} term #{term_name} course #{course_sis_data[:code]}") { fail }
                      end
                    end
                  end

                rescue => e
                  Utils.log_error e
                  it("test hit an error with UID #{athlete.uid} term #{term_name} course #{course_sis_data[:code]}") { fail }
                end
              end

            rescue => e
              Utils.log_error e
              it("test hit an error with UID #{athlete.uid} term #{term_name}") { fail }
            end
          end
        end

      rescue => e
        Utils.log_error e
        it("test hit an error with UID #{athlete.uid}") { fail }
      end
    end

  rescue => e
    Utils.log_error e
    it('test hit an error') { fail }
  ensure
    Utils.quit_browser @driver
  end
end
