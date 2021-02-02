require_relative '../../util/spec_helper'

if (ENV['NO_DEPS'] || ENV['NO_DEPS'].nil?) && !ENV['DEPS']

  describe 'BOAC' do

    include Logging

    begin

      test = BOACTestConfig.new
      test.class_pages
      pages_tested = []

      courses_csv = Utils.create_test_output_csv('boac-class-page-courses.csv', %w(Term Course Title Format Units))
      meetings_csv = Utils.create_test_output_csv('boac-class-page-meetings.csv', %w(Term Course Instructors Days Time Location))
      students_sis_csv = Utils.create_test_output_csv('boac-class-page-student-sis.csv', %w(Term Course SID Level Majors Sports MidPoint Basis Grade))
      students_canvas_csv = Utils.create_test_output_csv('boac-class-page-student-canvas.csv', %w(Term Course SID SiteId SiteCode SubmittedUser SubmittedMax ScoreUser ScoreMax))

      @driver = Utils.launch_browser test.chrome_profile
      @homepage = BOACHomePage.new @driver
      @filtered_cohort_page = BOACFilteredCohortPage.new(@driver, test.advisor)
      @student_page = BOACStudentPage.new @driver
      @class_page = BOACClassListViewPage.new @driver
      @search_page = BOACSearchResultsPage.new @driver

      @homepage.dev_auth test.advisor
      test.test_students.each do |student|
        begin

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

                    course_sis_data = api_user_page.sis_course_data course
                    unless course_sis_data[:code].include? 'PHYS ED'
                      logger.info "Checking course #{course_sis_data[:code]}"

                      sections = api_user_page.sections course
                      sections.each do |section|
                        begin

                          section_data = api_user_page.sis_section_data section
                          api_section_page = BOACApiSectionPage.new @driver
                          api_section_page.get_data(@driver, term_id, section_data[:ccn])
                          class_test_case = "term #{term_name} course #{course_sis_data[:code]} section #{section_data[:component]} #{section_data[:number]} #{section_data[:ccn]}"
                          logger.info "Checking #{class_test_case}"

                          # Check that a class page link is present if the section is primary
                          @student_page.load_page student
                          @student_page.expand_academic_year term_name

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
                            it("shows the right section format for #{class_test_case}") { expect(visible_course_data[:format]).to eql(section_data[:component]) }
                            it("shows the right section number for #{class_test_case}") { expect(visible_course_data[:number]).to eql(section_data[:number]) }
                            it("shows no empty course data for #{class_test_case}") do
                              expect(visible_course_data.values.all?).to be true
                              expect(visible_course_data.values.any? &:empty?).to be false
                            end

                            Utils.add_csv_row(courses_csv, [term_name, section_course_code, course_sis_data[:title], "#{section_data[:component]} #{section_data[:number]}", section_data[:units_completed]])

                            # Check that the section schedules are presented as expected
                            api_section_page.meetings.each do |meet|
                              index = api_section_page.meetings.index meet
                              visible_meeting_data = @class_page.visible_meeting_data index
                              expected_location = "#{meet[:location]}#{' — ' if meet[:location] && meet[:mode]}#{meet[:mode]}"
                              it("shows the right instructors for meeting #{index} for #{class_test_case}") { expect(visible_meeting_data[:instructors]).to eql(meet[:instructors]) }
                              it("shows the right days for meeting #{index} for #{class_test_case}") { expect(visible_meeting_data[:days]).to eql(meet[:days]) }
                              it("shows the right time for meeting #{index} for #{class_test_case}") { expect(visible_meeting_data[:time]).to eql(meet[:time]) }
                              it("shows the right location for meeting #{index} for #{class_test_case}") { expect(visible_meeting_data[:location]).to eql(expected_location) }

                              Utils.add_csv_row(meetings_csv, [term_name, section_course_code, meet[:instructors], meet[:days], meet[:time], expected_location])
                            end

                            # STUDENT DATA

                            # Check that all students who should appear actually do
                            visible_sids = @class_page.visible_sids.sort.uniq
                            logger.info "Visible student count is #{visible_sids.length}"
                            logger.error "Expecting #{api_section_page.student_sids.sort} but got #{visible_sids}" unless visible_sids == api_section_page.student_sids.sort
                            it("shows the right students for #{class_test_case}") { expect(visible_sids.sort).to eql(api_section_page.student_sids.sort) }

                            # Perform further tests on the students who appear on the first page
                            @class_page.load_page(term_id, section_data[:ccn], student)
                            visible_students = @class_page.class_list_view_sids
                            expected_students = test.students.select { |s| visible_students.include? s.sis_id }
                            expected_student_names = (expected_students.map { |u| "#{u.last_name}, #{u.first_name}" }).sort
                            visible_student_names = (@class_page.list_view_names).sort
                            logger.error "Expecting #{expected_student_names} and got #{visible_student_names}" unless visible_student_names == expected_student_names
                            it("shows all the expected students for #{class_test_case}") { expect(visible_student_names).to eql(expected_student_names) }
                            it("shows no blank student names for #{class_test_case}") { expect(visible_student_names.any? &:empty?).to be false }

                            # Collect all the expected class page data for each student in the class
                            all_student_data = []

                            # Limit the detailed tests to a configurable number of students in the class
                            expected_students = expected_students[0..BOACUtils.config['class_page_max_classmates']]
                            expected_students.each do |student|

                              # Load the student's data and find the matching course
                              student_api = BOACApiStudentPage.new @driver
                              student_api.get_data(@driver, student)
                              term = student_api.terms.find { |t| student_api.term_name(t) == term_name }
                              course = student_api.courses(term).find { |c| student_api.course_display_name(c) == course_sis_data[:code] }
                              unless course
                                logger.warn "No matching student course for UID #{student.uid} #{course_sis_data[:code]}"
                              end

                              # Collect the student data relevant to the class page
                              student_class_page_data = {
                                  :sid => student.sis_id,
                                  :level => (student_api.sis_profile_data[:level].nil? ? '' : student_api.sis_profile_data[:level]),
                                  :majors => student_api.sis_profile_data[:majors],
                                  :graduation => student_api.sis_profile_data[:graduation],
                                  :academic_career_status => student_api.sis_profile_data[:academic_career_status],
                                  :sports => student_api.asc_teams,
                                  :grading_basis => student_api.sis_course_data(course)[:grading_basis],
                                  :final_grade => student_api.sis_course_data(course)[:grade],
                                  :midpoint_grade => student_api.sis_course_data(course)[:midpoint],
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

                            expected_students.each do |classmate|
                              @class_page.load_page(term_id, section_data[:ccn], student)
                              logger.info "Checking SIS data for UID #{classmate.uid}"
                              student_test_case = "UID #{classmate.uid} #{class_test_case}"
                              student_data = all_student_data.find { |d| d[:sid] == classmate.sis_id }

                              # Check the student's SIS and ASC data
                              visible_student_sis_data = @class_page.visible_student_sis_data classmate

                              if student_data[:academic_career_status] == 'Inactive'
                                it "shows #{student_test_case} as inactive" do
                                  expect(visible_student_sis_data[:inactive]).to be true
                                end
                              else
                                it "does not show #{student_test_case} as inactive" do
                                  expect(visible_student_sis_data[:inactive]).to be false
                                end
                              end

                              active_majors = student_data[:majors].map { |m| m[:major] if m[:active] }.compact.sort
                              if active_majors.any?
                                it("shows the right majors for #{student_test_case}") do
                                  expect(visible_student_sis_data[:majors]).to eql(active_majors)
                                  expect(visible_student_sis_data[:majors]).not_to be_empty
                                end
                              else
                                it("shows no majors for #{student_test_case}") do
                                  expect(visible_student_sis_data[:majors]).to be_nil
                                end
                              end

                              if student_data[:academic_career_status] == 'Completed'
                                it("shows the right graduation date for #{student_test_case}") do
                                  expect(visible_student_sis_data[:graduation_date]).not_to be_nil
                                  expect(visible_student_sis_data[:graduation_date]).to eql('Graduated ' + Date.parse(student_data[:graduation][:date]).strftime('%b %e, %Y'))
                                end
                                it("shows the right graduation colleges for #{student_test_case}") do
                                  expect(visible_student_sis_data[:graduation_colleges]).not_to be_empty
                                  expect(visible_student_sis_data[:graduation_colleges]).to eql(student_data[:graduation][:colleges])
                                end
                              else
                                it("shows the right level for #{student_test_case}") { expect(visible_student_sis_data[:level]).to eql(student_data[:level]) }
                              end

                              if student_data[:sports]&.any? && test.dept == BOACDepartments::ASC
                                sports = student_data[:sports].map { |s| s.gsub(' (AA)', '') }
                                it("shows the right sports for #{student_test_case}") { expect(visible_student_sis_data[:sports]).to eql(sports.sort) }
                              end

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
                                it("shows no grade for #{student_test_case}") { expect(visible_student_sis_data[:final_grade]).to eql(student_data[:grading_basis]) }
                              end

                              # Midpoint grades display for the current term only.
                              if student_data[:midpoint_grade] && term_id == BOACUtils.term_code
                                it "shows the midpoint grade for #{student_test_case}" do
                                  expect(visible_student_sis_data[:mid_point_grade]).not_to be_empty
                                  expect(visible_student_sis_data[:mid_point_grade]).to eql(student_data[:midpoint_grade])
                                end
                              else
                                it("shows no midpoint grade for #{student_test_case}") { expect(visible_student_sis_data[:midpoint_grade]).to be_nil }
                              end

                              Utils.add_csv_row(students_sis_csv, [term_name, section_course_code, student_data[:sid], student_data[:level], active_majors, student_data[:sports], student_data[:mid_point_grade], student_data[:grading_basis], student_data[:final_grade]])

                              # Check the student's course site data
                              student_data[:sites].each do |site|
                                site_test_case = "#{student_test_case} site ID #{site[:site_id]}"
                                index = student_data[:sites].index site
                                visible_site_data = @class_page.visible_assigns_data(classmate, index)
                                logger.debug "Checking #{site_test_case} at node #{index + 1}, code #{site[:site_code]}"

                                if site[:nessie_assigns_submitted][:score].empty?
                                  it("shows a 'No Data' assignments submitted count for #{site_test_case}") { expect(visible_site_data[:assigns_submit_no_data]).to be_truthy }
                                else
                                  expected_count = site[:nessie_assigns_submitted][:score]
                                  if expected_count == '0'
                                    it("shows the null or zero assignments submitted count for #{site_test_case}") { expect(%w(0 --)).to include(visible_site_data[:assigns_submitted]) }
                                  else
                                    it("shows the assignments submitted count for #{site_test_case}") { expect(visible_site_data[:assigns_submitted]).to eql(site[:nessie_assigns_submitted][:score]) }
                                  end
                                end

                                # Currently no grades data is shown unless it can produce a boxplot
                                if site[:nessie_grades][:score].empty?
                                  it("shows a 'No Data' assignments score for #{site_test_case}") { expect(visible_site_data[:assigns_grade_no_data]).to be_truthy }
                                else
                                  # TODO - BOAC-2754
                                  expected_score = site[:nessie_grades][:score]
                                  if expected_score == '0'
                                    it("shows the null or zero assignments score for #{site_test_case}") { expect(%w(0 --)).to include(visible_site_data[:assigns_grade]) }
                                  else
                                    it("shows the assignments score for #{site_test_case}") { expect(visible_site_data[:assigns_grade]).to eql(expected_score) }
                                  end
                                end

                                Utils.add_csv_row(students_canvas_csv, [term_name, section_course_code, student_data[:sid], site[:site_id], site[:site_code], site[:nessie_assigns_submitted][:score], site[:nessie_assigns_submitted][:max], site[:nessie_grades][:score], site[:nessie_grades][:max]])

                              end

                              # TODO - the 'max' values are the same for all users

                            end
                          end

                        rescue => e
                          BOACUtils.log_error_and_screenshot(@driver, e, "#{student.uid}-#{term_name}-#{course_sis_data[:code]}")
                          it("test hit an error with UID #{student.uid} term #{term_name} course #{course_sis_data[:code]}") { fail }
                        end
                      end
                    end

                  rescue => e
                    BOACUtils.log_error_and_screenshot(@driver, e, "#{student.uid}-#{term_name}-#{course_sis_data[:code]}")
                    it("test hit an error with UID #{student.uid} term #{term_name} course #{course_sis_data[:code]}") { fail }
                  end
                end

              rescue => e
                BOACUtils.log_error_and_screenshot(@driver, e, "#{student.uid}-#{term_name}")
                it("test hit an error with UID #{student.uid} term #{term_name}") { fail }
              end
            end
          end

        rescue => e
          BOACUtils.log_error_and_screenshot(@driver, e, "#{student.uid}")
          it("test hit an error with UID #{student.uid}") { fail }
        end
      end

    rescue => e
      Utils.log_error e
      it('test hit an error') { fail }
    ensure
      Utils.quit_browser @driver
    end
  end
end
