require_relative '../../util/spec_helper'

if (ENV['DEPS'] || ENV['DEPS'].nil?) && !ENV['NO_DEPS']

  include Logging

  describe 'BOAC' do

    begin
      test = BOACTestConfig.new
      test.sis_student_data
      alert_students = []
      hold_students = []

      # Create files for test output
      user_profile_data_heading = %w(UID Name PreferredName Email EmailAlt Phone Units GPA Level Transfer Colleges Majors
                                   CollegesDisc MajorsDisc Minors MinorsDisc Terms Writing History Institutions Cultures
                                   AdvisorPlans AdvisorNames AdvisorEmails EnteredTerm MajorsIntend Visa GradExpect
                                   GradDegree GradDate GradColleges Inactive Alerts Holds)
      user_profile_sis_data = Utils.create_test_output_csv('boac-sis-profiles.csv', user_profile_data_heading)

      user_course_data_heading = %w(UID Term UnitsMin UnitsMax CourseCode CourseName SectionCcn SectionCode Primary? Midpoint Grade GradingBasis Units EnrollmentStatus)
      user_course_sis_data = Utils.create_test_output_csv('boac-sis-courses.csv', user_course_data_heading)

      @driver = Utils.launch_browser test.chrome_profile
      @boac_homepage = BOACHomePage.new @driver
      @boac_cohort_page = BOACUtils.shuffle_max_users ? BOACGroupPage.new(@driver) : BOACFilteredCohortPage.new(@driver, test.advisor)
      @boac_student_page = BOACStudentPage.new @driver
      @boac_admin_page = BOACFlightDeckPage.new @driver
      @boac_search_page = BOACSearchResultsPage.new @driver

      @boac_homepage.dev_auth test.advisor

      if @boac_cohort_page.instance_of? BOACFilteredCohortPage
        @boac_cohort_page.search_and_create_new_cohort(test.default_cohort, default: true)
      else
        test.default_cohort = CuratedGroup.new(:name => "Group #{test.id}")
        @boac_homepage.click_sidebar_create_curated_group
        @boac_cohort_page.create_group_with_bulk_sids(test.test_students, test.default_cohort)
      end

      visible_sids = @boac_cohort_page.list_view_sids
      test.test_students.keep_if { |m| visible_sids.include? m.sis_id }
      test.test_students.each do |student|

        begin
          api_student_data = BOACApiStudentPage.new @driver
          api_student_data.get_data(@driver, student)
          api_sis_profile_data = api_student_data.sis_profile_data
          academic_standing = api_student_data.academic_standing

          # COHORT PAGE SIS DATA

          BOACUtils.shuffle_max_users ? @boac_cohort_page.load_page(test.default_cohort) : @boac_cohort_page.load_cohort(test.default_cohort)
          cohort_page_sis_data = @boac_cohort_page.visible_sis_data student

          if api_sis_profile_data[:academic_career_status] == 'Completed'
            it "shows no level for UID #{student.uid} on the #{test.default_cohort.name} page" do
              expect(cohort_page_sis_data[:level]).to be_nil
            end
          else
            it "shows the level for UID #{student.uid} on the #{test.default_cohort.name} page" do
              expect(cohort_page_sis_data[:level]).to eql(api_sis_profile_data[:level].to_s)
            end
          end

          if api_sis_profile_data[:entered_term]
            it "shows the matriculation term for UID #{student.uid} on the #{test.default_cohort.name} page" do
              expect(cohort_page_sis_data[:entered_term]).to eql(api_sis_profile_data[:entered_term])
            end
          end

          if api_sis_profile_data[:academic_career_status] == 'Completed' && api_sis_profile_data[:graduations]&.any?
            # Show only the most recent degree data on list view
            grad = api_sis_profile_data[:graduations].max { |a,b| a[:date] <=> b[:date] }
            it "shows the right graduation date for UID #{student.uid} on the #{test.default_cohort.name} page" do
              expect(cohort_page_sis_data[:graduation]).to include(grad[:date].strftime('%b %e, %Y'))
            end
            grad[:majors].each do |maj|
              it "shows the right graduation majors for UID #{student.uid} on the #{test.default_cohort.name} page" do
                expect(cohort_page_sis_data[:graduation]).to include(maj[:plan])
              end
            end
            grad[:minors].each do |min|
              it "shows no graduation minors for UID #{student.uid} on the #{test.default_cohort.name} page" do
                expect(cohort_page_sis_data[:graduation]).not_to include(min[:plan])
              end
            end
          else
            it "shows no graduation data for UID #{student.uid} on the #{test.default_cohort.name} page" do
              expect(cohort_page_sis_data[:graduation]).to be_nil
            end
          end

          if api_sis_profile_data[:academic_career_status] == 'Inactive'
            it "shows UID #{student.uid} as inactive on the #{test.default_cohort.name} page" do
              expect(cohort_page_sis_data[:inactive]).to be true
            end
          else
            it "does not show UID #{student.uid} as inactive on the #{test.default_cohort.name} page" do
              expect(cohort_page_sis_data[:inactive]).to be false
            end
          end

          withdrawal = api_sis_profile_data[:withdrawal]
          if withdrawal
            cohort_page_sis_data[:cxl_msg]
            it "shows withdrawal information for UID #{student.uid} on the #{test.default_cohort.name} page" do
              expect(cohort_page_sis_data[:cxl_msg]).not_to be_nil
            end
            if cohort_page_sis_data[:cxl_msg]
              it "shows the withdrawal type for UID #{student.uid} on the #{test.default_cohort.name} page" do
                expect(cohort_page_sis_data[:cxl_msg]).to include(withdrawal[:desc])
              end
              it "shows the withdrawal date for UID #{student.uid} on the #{test.default_cohort.name} page" do
                expect(cohort_page_sis_data[:cxl_msg]).to include(withdrawal[:date])
              end
            end
          end

          if academic_standing&.any?
            latest_standing = academic_standing.first
            if latest_standing.code == 'GST'
              it "shows no academic standing for UID #{student.uid} on the #{test.default_cohort.name} page" do
                expect(cohort_page_sis_data[:academic_standing]).to be_nil
              end
            else
              it "shows the academic standing '#{latest_standing.descrip}' for UID #{student.uid} on the #{test.default_cohort.name} page" do
                expect(cohort_page_sis_data[:academic_standing]).to eql("#{latest_standing.descrip} (#{latest_standing.term_name})")
              end
            end
          else
            it "shows no academic standing for UID #{student.uid} on the #{test.default_cohort.name} page" do
              expect(cohort_page_sis_data[:academic_standing]).to be_nil
            end
          end

          active_major_feed, inactive_major_feed = api_sis_profile_data[:majors].compact.partition { |m| m[:active] }
          active_majors = active_major_feed.map { |m| m[:major] }
          active_colleges = active_major_feed.map { |m| m[:college] }.compact
          inactive_majors = inactive_major_feed.map { |m| m[:major] }
          inactive_colleges = inactive_major_feed.map { |m| m[:college] }.compact

          active_minor_feed, inactive_minor_feed = api_sis_profile_data[:minors].partition { |m| m[:active] }
          active_minors = active_minor_feed.map { |m| m[:minor] }
          inactive_minors = inactive_minor_feed.map { |m| m[:minor] }

          if active_majors.any?
            it "shows the majors for UID #{student.uid} on the #{test.default_cohort.name} page" do
              expect(cohort_page_sis_data[:majors]).to eql(active_majors.sort)
            end
          else
            it("shows no majors for UID #{student.uid} on the #{test.default_cohort.name} page") { expect(cohort_page_sis_data[:majors]).to be_nil }
          end

          it "shows the sub-plans for UID #{student.uid} on the #{test.default_cohort.name} page" do
            expect(cohort_page_sis_data[:sub_plans]).to eql(api_sis_profile_data[:sub_plans])
          end

          if api_sis_profile_data[:academic_career_status] == 'Completed'
            it "shows no expected graduation term for UID #{student.uid} on the #{test.default_cohort.name} page" do
              expect(cohort_page_sis_data[:grad_term]).to be_nil
            end
          else
            it "shows the expected graduation term for UID #{student.uid} on the #{test.default_cohort.name} page" do
              expect(cohort_page_sis_data[:grad_term]).to eql(api_sis_profile_data[:expected_grad_term_name])
            end
          end

          it "shows the cumulative GPA for UID #{student.uid} on the #{test.default_cohort.name} page" do
            expect(cohort_page_sis_data[:gpa]).to eql(api_sis_profile_data[:cumulative_gpa])
            expect(cohort_page_sis_data[:gpa]).not_to be_empty
          end

          it "shows the most recent term GPA for UID #{student.uid} on the #{test.default_cohort.name} page" do
            # TODO
          end

          # TERM SELECTION

          student_terms = api_student_data.terms

          current_term = BOACUtils.term_code.to_s
          previous_term = Utils.previous_term_code current_term
          past_term = Utils.previous_term_code previous_term
          next_term = Utils.next_term_code current_term
          future_term = Utils.next_term_code next_term

          [current_term, past_term, previous_term, next_term, future_term].each do |term|
            begin
              logger.info "Checking SIS profile data for term #{term}"

              term_name = Utils.sis_code_to_term_name term

              unless term == current_term
                @boac_cohort_page.select_term term
                @boac_cohort_page.wait_for_student_list
              end

              visible_course_data = @boac_cohort_page.visible_courses_data student
              student_term = student_terms.find { |t| api_student_data.term_id(t) == term }

              if student_term

                # Cumulative units

                visible_cumul_units = @boac_cohort_page.visible_cumul_units student
                if student_term == api_student_data.current_term
                  if api_sis_profile_data[:cumulative_units]
                    it "shows the total units for UID #{student.uid} term #{term_name} on the #{test.default_cohort.name} page " do
                      expect(visible_cumul_units).to eql(api_sis_profile_data[:cumulative_units])
                      expect(visible_cumul_units).not_to be_empty
                    end
                  else
                    it "shows no total units for UID #{student.uid} term #{term_name} on the #{test.default_cohort.name} page" do
                      expect(visible_cumul_units).to eql('0')
                    end
                  end
                else
                  it "shows no total units for UID #{student.uid} term #{term_name} on the #{test.default_cohort.name} page" do
                    expect(visible_cumul_units).to be_nil
                  end
                end

                # Term units

                visible_units = @boac_cohort_page.visible_term_units student
                if api_student_data.term_units(student_term)
                  it "shows the units in progress for UID #{student.uid} term #{term_name} on the #{test.default_cohort.name} page" do
                    expect(visible_units).to eql(api_student_data.term_units(student_term))
                    expect(visible_units).not_to be_empty
                  end
                else
                  it("shows no units in progress for UID #{student.uid} term #{term_name} on the #{test.default_cohort.name} page") do
                    expect(visible_units).to eql('0')
                  end
                end

                # Course data

                courses = api_student_data.courses student_term

                logger.debug "Visible: #{visible_course_data}"

                if courses.any?
                  courses.each_with_index do |course, i|

                    begin
                      course_sis_data = api_student_data.sis_course_data course
                      course_code = course_sis_data[:code]

                      logger.info "Checking course #{course_code}"

                      it "shows the list view course code for UID #{student.uid} term #{term_name} course #{course_code}" do
                        expect(visible_course_data[i][:course_code]).to include(course_code)
                      end

                      if course_sis_data[:grade].empty?
                        if course_sis_data[:grading_basis] == 'NON'
                          it "shows no list view grade and no grading basis for UID #{student.uid} term #{term_name} course #{course_code}" do
                            expect(visible_course_data[i][:final_grade]).to include('No data')
                          end
                        else
                          it "shows the list view grading basis for UID #{student.uid} term #{term_name} course #{course_code}" do
                            expect(visible_course_data[i][:final_grade]).to eql(course_sis_data[:grading_basis])
                          end
                        end
                      else
                        it "shows the list view grade for UID #{student.uid} term #{term_name} course #{course_code}" do
                          expect(visible_course_data[i][:final_grade]).to eql(course_sis_data[:grade])
                        end
                        if %w(D+ D D- F NP RD I).include? course_sis_data[:grade]
                          it "shows an alert for the list view grade for UID #{student.uid} term #{term_name} course #{course_code}" do
                            expect(visible_course_data[i][:final_flag]).to be true
                          end
                        else
                          it "shows no alert for the list view grade for UID #{student.uid} term #{term_name} course #{course_code}" do
                            expect(visible_course_data[i][:final_flag]).to be false
                          end
                        end
                      end

                      if course_sis_data[:midpoint]
                        it "shows the list view midpoint grade for UID #{student.uid} term #{term_name} course #{course_code}" do
                          expect(visible_course_data[i][:mid_grade]).to eql(course_sis_data[:midpoint])
                        end
                        if %w(D+ D D- F NP RD I).include? course_sis_data[:midpoint]
                          it "shows an alert for the list view midpoint grade for UID #{student.uid} term #{term_name} course #{course_code}" do
                            expect(visible_course_data[i][:mid_flag]).to be true
                          end
                        else
                          it "shows no alert for the list view midpoint grade for UID #{student.uid} term #{term_name} course #{course_code}" do
                            expect(visible_course_data[i][:mid_flag]).to be false
                          end
                        end
                      else
                        it("shows no list view midpoint grade for UID #{student.uid} term #{term_name} course #{course_code}") do
                          expect(visible_course_data[i][:mid_grade]).to include('No data')
                        end
                      end

                      sites = api_student_data.course_sites(course)
                      if sites.any?
                        site_data = sites.map { |s| api_student_data.last_activity_day s }
                        site_data.each do |d|
                          it "shows the list view bCourses activity #{d} for UID #{student.uid} term #{term_name} course #{course_code}" do
                            expect(visible_course_data[i][:activity]).to include(d)
                          end
                        end
                      else
                        it "shows the list view bCourses activity 'no data' for UID #{student.uid} term #{term_name} course #{course_code}" do
                          expect(visible_course_data[i][:activity]).to include('No data')
                        end
                      end

                    rescue => e
                      BOACUtils.log_error_and_screenshot(@driver, e, "#{student.uid}-#{term_name}-#{course_code}")
                      it("encountered an error for UID #{student.uid} term #{term_name} course #{course_code}") { fail }
                    end
                  end
                else
                  it "shows a no-enrollments message for UID #{student.uid} term #{term_name}" do
                    expect(visible_course_data.first[:course_code]).to include("No #{term_name} enrollments")
                  end
                end
              else
                it "shows a no-enrollments message for UID #{student.uid} term #{term}" do
                  expect(visible_course_data.first[:course_code]).to include("No #{term_name} enrollments")
                end
              end
            end
          end

          # STUDENT PAGE SIS DATA

          @boac_cohort_page.click_student_link student
          @boac_student_page.wait_for_title student.full_name
          @boac_student_page.expand_personal_details

          api_advisors = api_student_data.advisors
          api_demographics = api_student_data.demographics

          student_page_sis_data = @boac_student_page.visible_sis_data

          it "shows the name for UID #{student.uid} on the student page" do
            expect(student_page_sis_data[:name]).to eql(student.full_name.split(',').reverse.join(' ').strip)
          end

          it "shows the email for UID #{student.uid} on the student page" do
            expect(student_page_sis_data[:email]).to eql(api_sis_profile_data[:email])
            expect(student_page_sis_data[:email]).not_to be_empty
          end

          if api_sis_profile_data[:email_alternate]
            it "shows the alternate email for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:email_alternate]).to eq(api_sis_profile_data[:email_alternate])
            end
          else
            it "shows no alternate email for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:email_alternate]).to be_nil
            end
          end

          if api_sis_profile_data[:cumulative_units]
            it "shows the total units for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:cumulative_units]).to eql(api_sis_profile_data[:cumulative_units])
              expect(student_page_sis_data[:cumulative_units]).not_to be_empty
            end
          else
            it "shows no total units for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:cumulative_units]).to eql('--')
            end
          end

          it "shows the phone for UID #{student.uid} on the student page" do
            expect(student_page_sis_data[:phone]).to eql(api_sis_profile_data[:phone])
          end

          it "shows the cumulative GPA for UID #{student.uid} on the student page" do
            expect(student_page_sis_data[:cumulative_gpa]).to eql(api_sis_profile_data[:cumulative_gpa])
            expect(student_page_sis_data[:cumulative_gpa]).not_to be_empty
          end

          if api_sis_profile_data[:academic_career_status] != 'Completed' && active_majors.any?
            it "shows the active majors for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:majors]).to eql(active_majors)
              expect(student_page_sis_data[:colleges]).to eql(active_colleges)
            end
          else
            it "shows no active majors for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:majors]).to be_empty
            end
            it "shows no colleges for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:colleges].all?(&:empty?)).to be true
            end
          end

          if api_sis_profile_data[:academic_career_status] != 'Completed' && inactive_majors.any?
            it "shows the discontinued majors for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:majors_discontinued]).to eql(inactive_majors)
              expect(student_page_sis_data[:colleges_discontinued]).to eql(inactive_colleges)
            end
          else
            it "shows no discontinued majors for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:majors_discontinued]).to be_empty
            end
            it "shows no discontinued colleges for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:colleges_discontinued].all?(&:empty?)).to be true
            end
          end

          if api_sis_profile_data[:academic_career_status] != 'Completed' && active_minors.any?
            it "shows active minors for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:minors]).to eq(active_minors)
            end
          else
            it "shows no active minors for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:minors]).to be_empty
            end
          end

          if api_sis_profile_data[:academic_career_status] != 'Completed' && inactive_minors.any?
            it "shows inactive minors for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:minors_discontinued]).to eq(inactive_minors)
            end
          else
            it "shows no inactive minors for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:minors_discontinued]).to be_empty
            end
          end

          it "shows the academic level for UID #{student.uid} on the student page" do
            expect(student_page_sis_data[:level]).to eql(api_sis_profile_data[:level].to_s)
          end

          if api_advisors.any?
            it "shows assigned advisor plans for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:advisor_plans].sort).to eq(api_advisors.map { |a| a[:plan] }.sort)
            end
            it "shows assigned advisor names for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:advisor_names].sort).to eq(api_advisors.map { |a| a[:name]&.strip }.sort)
            end
            it "shows assigned advisor emails for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:advisor_emails].sort).to eq(api_advisors.map { |a| "#{a[:email]}" }.sort)
            end
          else
            it("shows no assigned advisors for UID #{student.uid} on the student page") do
              expect(student_page_sis_data[:advisor_plans]).to be_empty
              expect(student_page_sis_data[:advisor_names]).to be_empty
              expect(student_page_sis_data[:advisor_emails]).to be_empty
            end
          end

          if api_sis_profile_data[:entered_term]
            it "shows the matriculation date for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:entered_term]).to eql(api_sis_profile_data[:entered_term])
            end
          end

          if api_sis_profile_data[:intended_majors].any?
            it "shows intended majors for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:intended_majors]).to eql(api_sis_profile_data[:intended_majors])
            end
          end

          if api_demographics[:visa] && api_demographics[:visa][:status] == 'G'
            it "shows visa status for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:visa]).to eq case api_demographics[:visa][:type]
                                                         when 'F1' then
                                                           'F-1 International Student'
                                                         when 'J1' then
                                                           'J-1 International Student'
                                                         when 'PR' then
                                                           'PR Verified International Student'
                                                         else
                                                           'Other Verified International Student'
                                                         end
            end
          else
            it "shows no visa status for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:visa]).to be_nil
            end
          end

          if api_sis_profile_data[:academic_career_status] == 'Completed'
            api_sis_profile_data[:graduations].each do |grad|
              grad[:majors].each do |maj|
                visible_degree = @boac_student_page.visible_degree maj[:plan]
                it "shows the degree '#{maj[:plan]}' for UID #{student.uid} on the student page" do
                  expect(visible_degree[:deg_type]).to include(maj[:plan])
                end
                it "shows the date for degree '#{maj[:plan]}' for UID #{student.uid} on the student page" do
                  expect(visible_degree[:deg_date]).to eql('Awarded ' + grad[:date].strftime('%b %e, %Y'))
                end
                it "shows the right college for degree '#{maj[:plan]}' for UID #{student.uid} on the student page" do
                  expect(visible_degree[:deg_college]).to eql(maj[:college])
                end
              end

              grad[:minors].each do |min|
                visible_minor = @boac_student_page.visible_degree_minor min[:plan]
                it "shows the degree minor '#{min[:plan]}' for UID #{student.uid} on the student page" do
                  expect(visible_minor[:min_type]).to include(min[:plan])
                end
                it "shows the date for degree minor '#{min[:plan]}' for UID #{student.uid} on the student page" do
                  expect(visible_minor[:min_date]).to eql('Awarded ' + grad[:date].strftime('%b %e, %Y'))
                end
              end
            end
          end

          if api_sis_profile_data[:academic_career_status] == 'Inactive'
            it "shows UID #{student.uid} as inactive on the student page" do
              expect(student_page_sis_data[:inactive]).to be true
            end
          else
            it "does not show UID #{student.uid} as inactive on the student page" do
              expect(student_page_sis_data[:inactive]).to be false
            end
          end

          if latest_standing
            if latest_standing.code == 'GST'
              it "shows no academic standing for UID #{student.uid} on the student page" do
                expect(student_page_sis_data[:academic_standing].to_s).to be_empty
              end
            else
              it "shows the academic standing '#{latest_standing.descrip}' for UID #{student.uid} on the student page" do
                expect(student_page_sis_data[:academic_standing]).to eql("#{latest_standing.descrip} (#{latest_standing.term_name})")
              end
            end
          else
            it "shows no academic standing for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:academic_standing]).to be_nil
            end
          end

          if api_sis_profile_data[:terms_in_attendance] && !api_sis_profile_data[:terms_in_attendance].empty? && api_sis_profile_data[:level] != 'Graduate'
            it "shows the terms in attendance for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:terms_in_attendance]).to include(api_sis_profile_data[:terms_in_attendance])
            end
          else
            it "shows no terms in attendance for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:terms_in_attendance]).to be_nil
            end
          end

          if api_sis_profile_data[:transfer]
            it "shows Transfer for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:transfer]).to eql('Transfer')
            end
          else
            it "shows no Transfer for UID #{student.uid} on the student page" do
              expect(student_page_sis_data[:transfer]).to be_nil
            end
          end

          if api_sis_profile_data[:level] == 'Graduate'
            it "shows no expected graduation date for UID #{student.uid} on the #{test.default_cohort.name} page" do
              expect(student_page_sis_data[:expected_graduation]).to be nil
            end
          else
            it "shows the expected graduation date for UID #{student.uid} on the #{test.default_cohort.name} page" do
              expect(student_page_sis_data[:expected_graduation]).to eql(api_sis_profile_data[:expected_grad_term_name])
            end
          end

          has_calcentral_link = @boac_student_page.calcentral_link(student).exists?
          it "shows a link to the student overview page in CalCentral on the student page for UID #{student.uid}" do
            expect(has_calcentral_link).to be true
          end

          # TIMELINE

          # Requirements

          student_page_reqts = @boac_student_page.visible_requirements
          it "shows the Entry Level Writing Requirement for UID #{student.uid} on the student page" do
            expect(student_page_reqts[:reqt_writing]).to eql(api_sis_profile_data[:reqt_writing])
          end
          it "shows the American History Requirement for UID #{student.uid} on the student page" do
            expect(student_page_reqts[:reqt_history]).to eql(api_sis_profile_data[:reqt_history])
          end
          it "shows the American Institutions Requirement for UID #{student.uid} on the student page" do
            expect(student_page_reqts[:reqt_institutions]).to eql(api_sis_profile_data[:reqt_institutions])
          end
          it "shows the American Cultures Requirement for UID #{student.uid} on the student page" do
            expect(student_page_reqts[:reqt_cultures]).to eql(api_sis_profile_data[:reqt_cultures])
          end

          # Alerts

          alerts = BOACUtils.get_students_alerts [student]
          alert_data = alerts.map { |a| {text: a.message, date: @boac_student_page.expected_item_short_date_format(a.date)} }
          dismissed = BOACUtils.get_dismissed_alerts(alerts).map &:message
          logger.info "UID #{student.uid} alert count is #{alert_data.length}, with #{dismissed.length} dismissed"
          visible_alerts = @boac_student_page.visible_alerts

          if alerts.any?
            alert_students << student
            logger.debug "UID #{student.uid} alerts are #{alert_data}, and visible alerts are #{visible_alerts}"
            it("has the alert messages for UID #{student.uid} on the student page") { expect(visible_alerts & alert_data).to eql(visible_alerts) }
          end

          visible_alert_text = visible_alerts.map { |a| a[:text] }
          if latest_standing&.term_id == BOACUtils.term_code.to_s
            if latest_standing.code == 'GST'
              it "shows no academic standing alert for UID #{student.uid} on the student page" do
                expect(visible_alert_text).not_to include("Student's academic standing is '#{latest_standing.descrip}'.")
              end
            else
              it "shows an academic standing alert '#{latest_standing.descrip}' for UID #{student.uid} on the student page" do
                expect(visible_alert_text).to include("Student's academic standing is '#{latest_standing.descrip}'.")
              end
            end
          else
            it "shows no academic standing alert for UID #{student.uid} on the student page" do
              visible_alert_text.each do |alert|
                expect(alert).not_to include("Student's academic standing is")
              end
            end
          end

          # Holds

          holds = NessieTimelineUtils.get_student_holds student
          hold_msgs = (holds.map { |h| h.message.gsub(/\W/, '') }).sort
          logger.info "UID #{student.uid} hold count is #{hold_msgs.length}"

          if holds.any?
            hold_students << student
            visible_holds = @boac_student_page.visible_holds.sort
            logger.debug "UID #{student.uid} holds are #{hold_msgs}, and visible holds are #{visible_holds}"
            it("has the hold messages for UID #{student.uid} on the student page") { expect(visible_holds).to eql(hold_msgs) }
          end

          if withdrawal
            withdrawal_msg_present = @boac_student_page.withdrawal_msg?
            it("shows withdrawal information for UID #{student.uid} on the student page") { expect(withdrawal_msg_present).to be true }
            if withdrawal_msg_present
              msg = @boac_student_page.withdrawal_msg
              it("shows the withdrawal type for UID #{student.uid} on the student page") { expect(msg).to include(withdrawal[:desc]) }
              it("shows the withdrawal reason for UID #{student.uid} on the student page") { expect(msg).to include(withdrawal[:reason]) }
              it("shows the withdrawal date for UID #{student.uid} on the student page") { expect(msg).to include(withdrawal[:date]) }
            end
          end

          # TERMS

          if student_terms.any?

            if @boac_student_page.toggle_collapse_all_years?
              @boac_student_page.click_expand_collapse_years_toggle
              terms_visible = @boac_student_page.verify_block do
                student_terms.each { |term| @boac_student_page.term_data_heading(api_student_data.term_name term).when_visible 1 }
              end
              it('allows the user to expand all terms') { expect(terms_visible).to be true }

              @boac_student_page.click_expand_collapse_years_toggle
              terms_hidden = @boac_student_page.verify_block do
                student_terms.each { |term| @boac_student_page.term_data_heading(api_student_data.term_name term).when_not_visible 1 }
              end
              it('allows the user to collapse all terms') { expect(terms_hidden).to be true }
            end

            student_terms.each do |term|

              begin
                term_id = api_student_data.term_id term
                term_name = api_student_data.term_name term
                logger.info "Checking #{term_name}"

                @boac_student_page.expand_academic_year term_name

                visible_term_data = @boac_student_page.visible_term_data term_id

                # TERM UNITS

                if api_student_data.term_units(term) && api_student_data.term_units(term).to_i.zero?
                  it("shows no term units total for UID #{student.uid} term #{term_name}") { expect(visible_term_data[:term_units]).to eql('—') }
                else
                  it("shows the term units total for UID #{student.uid} term #{term_name}") { expect(visible_term_data[:term_units]).to eql(api_student_data.term_units term) }
                end

                # ACADEMIC STANDING

                if academic_standing&.any?
                  term_standing = academic_standing.find { |s| s.term_id.to_s == term_id.to_s }
                  if term_standing
                    if term_standing.code == 'GST'
                      it "shows no academic standing for UID #{student.uid} term #{term_name} on the student page" do
                        expect(visible_term_data[:academic_standing]).to be_nil
                      end
                    else
                      it "shows the academic standing '#{term_standing.descrip}' for UID #{student.uid} term #{term_name} on the student page" do
                        expect(visible_term_data[:academic_standing]).to eql("#{term_standing.descrip} (#{term_standing.term_name})")
                      end
                    end
                  else
                    it "shows no academic standing for UID #{student.uid} term #{term_name} on the student page" do
                      expect(visible_term_data[:academic_standing]).to be_nil
                    end
                  end
                end

                # COURSES

                term_section_ccns = []

                courses = api_student_data.courses term
                if courses.any?
                  courses.each_with_index do |course, i|

                    begin
                      course_sis_data = api_student_data.sis_course_data course
                      course_code = course_sis_data[:code]

                      logger.info "Checking course #{course_code}"

                      collapsed_course_data = @boac_student_page.visible_collapsed_course_data(term_id, i)

                      it "shows the course code for UID #{student.uid} term #{term_name} course #{course_code}" do
                        expect(collapsed_course_data[:code]).not_to be_empty
                        expect(collapsed_course_data[:code]).to eql(course_sis_data[:code])
                      end

                      if course_sis_data[:grade].empty?
                        if course_sis_data[:grading_basis] == 'NON'
                          it "shows no grade and no grading basis for UID #{student.uid} term #{term_name} course #{course_code}" do
                            expect(collapsed_course_data[:final_grade]).to be_empty
                          end
                        else
                          it "shows the grading basis for UID #{student.uid} term #{term_name} course #{course_code}" do
                            expect(collapsed_course_data[:final_grade]).to eql(course_sis_data[:grading_basis])
                          end
                        end
                      else
                        it "shows the grade for UID #{student.uid} term #{term_name} course #{course_code}" do
                          expect(collapsed_course_data[:final_grade]).to eql(course_sis_data[:grade])
                        end
                        # TODO sad grade flag
                      end

                      if course_sis_data[:midpoint]
                        it "shows the midpoint grade for UID #{student.uid} term #{term_name} course #{course_code}" do
                          expect(collapsed_course_data[:mid_point_grade]).not_to be_empty
                          expect(collapsed_course_data[:mid_point_grade]).to eql(course_sis_data[:midpoint])
                        end
                        # TODO sad grade flag
                      else
                        it("shows no midpoint grade for UID #{student.uid} term #{term_name} course #{course_code}") do
                          expect(collapsed_course_data[:mid_point_grade]).to eql("\n—")
                        end
                      end

                      it "shows the units for UID #{student.uid} term #{term_name} course #{course_code}" do
                        expect(collapsed_course_data[:units]).not_to be_empty
                        expect(collapsed_course_data[:units]).to eql(course_sis_data[:units_completed])
                      end

                      @boac_student_page.expand_course_data(term_id, i)
                      expanded_course_data = @boac_student_page.visible_expanded_course_data(term_id, i)

                      it "shows the expanded course code for UID #{student.uid} term #{term_name} course #{course_code}" do
                        expect(expanded_course_data[:code]).not_to be_empty
                        expect(expanded_course_data[:code]).to eql(course_sis_data[:code])
                      end

                      it "shows the expanded course title for UID #{student.uid} term #{term_name} course #{course_code}" do
                        expect(expanded_course_data[:title]).not_to be_empty
                        expect(expanded_course_data[:title]).to eql(course_sis_data[:title])
                      end

                      section_statuses = []
                      api_student_data.sections(course).each do |section|

                        begin
                          section_sis_data = api_student_data.sis_section_data section
                          term_section_ccns << section_sis_data[:ccn]
                          component = section_sis_data[:component]

                          it "shows the section number for UID #{student.uid} term #{term_name} course #{course_code} section #{component}" do
                            expect(expanded_course_data[:sections]).not_to be_empty
                            expect(expanded_course_data[:sections]).to include("#{section_sis_data[:component]} #{section_sis_data[:number]}")
                          end

                          section_statuses << section_sis_data[:status]

                        rescue => e
                          BOACUtils.log_error_and_screenshot(@driver, e, "#{student.uid}-#{term_name}-#{course_code}-#{section_sis_data[:ccn]}")
                          it("encountered an error for UID #{student.uid} term #{term_name} course #{course_code} section #{section_sis_data[:ccn]}") { fail }
                        ensure
                          row = [student.uid, term_name, api_sis_profile_data[:term_units_min], api_sis_profile_data[:term_units_max], course_code, course_sis_data[:title],
                                 section_sis_data[:ccn], "#{section_sis_data[:component]} #{section_sis_data[:number]}", section_sis_data[:primary], course_sis_data[:midpoint],
                                 course_sis_data[:grade], course_sis_data[:grading_basis], course_sis_data[:units_completed], section_sis_data[:status]]
                          Utils.add_csv_row(user_course_sis_data, row)
                        end
                      end

                      if section_statuses.include? 'W'
                        it "shows the wait list status for UID #{student.uid} term #{term_name} course #{course_code}" do
                          expect(collapsed_course_data[:wait_list]).to eql('WAITLISTED')
                        end
                      else
                        it "shows no enrollment status for UID #{student.uid} term #{term_name} course #{course_code}" do
                          expect(collapsed_course_data[:wait_list]).to be_nil
                        end
                      end

                    rescue => e
                      BOACUtils.log_error_and_screenshot(@driver, e, "#{student.uid}-#{term_name}-#{course_code}")
                      it("encountered an error for UID #{student.uid} term #{term_name} course #{course_code}") { fail }
                    end
                  end

                  it("shows no dupe courses for UID #{student.uid} in term #{term_name}") { expect(term_section_ccns).to eql(term_section_ccns.uniq) }

                else
                  logger.warn "No course data in #{term_name}"
                end

                # DROPPED SECTIONS

                drops = api_student_data.dropped_sections term
                if drops
                  drops.each do |drop|
                    visible_drop = @boac_student_page.visible_dropped_section_data(term_id, drop[:title], drop[:component], drop[:number])
                    it "shows dropped section #{drop[:title]} #{drop[:component]} #{drop[:number]} for UID #{student.uid} in #{term_name}" do
                      expect(visible_drop).to include("#{drop[:title]} - #{drop[:component]} #{drop[:number]}")
                    end

                    if drop[:date]
                      it "shows the drop date for section #{drop[:title]} #{drop[:component]} #{drop[:number]} for UID #{student.uid} in #{term_name}" do
                        expect(visible_drop).to include(Date.parse(drop[:date]).strftime('%b %-d, %Y'))
                      end
                    end
                    row = [student.uid, term_name, nil, nil, drop[:title], nil, nil, drop[:number], nil, nil, nil, "D #{drop[:date]}"]
                    Utils.add_csv_row(user_course_sis_data, row)
                  end
                end

              rescue => e
                BOACUtils.log_error_and_screenshot(@driver, e, "#{student.uid}-#{term_name}")
                it("encountered an error for UID #{student.uid} term #{term_name}") { fail "#{e.message + "\n"} #{e.backtrace.join("\n ")}" }
              end
            end

          else
            logger.warn "UID #{student.uid} has no term data"
          end

        rescue => e
          BOACUtils.log_error_and_screenshot(@driver, e, "#{student.uid}")
          it("encountered an error for UID #{student.uid}") { fail "#{e.message + "\n"} #{e.backtrace.join("\n ")}" }
        ensure
          if student_page_sis_data
            row = [student.uid, student_page_sis_data[:name], student_page_sis_data[:preferred_name], student_page_sis_data[:email],
                   student_page_sis_data[:email_alternate], student_page_sis_data[:phone], student_page_sis_data[:cumulative_units],
                   student_page_sis_data[:cumulative_gpa], student_page_sis_data[:level], student_page_sis_data[:transfer],
                   student_page_sis_data[:colleges], student_page_sis_data[:majors],
                   student_page_sis_data[:colleges_discontinued], student_page_sis_data[:majors_discontinued],
                   student_page_sis_data[:minors], student_page_sis_data[:minors_discontinued],
                   student_page_sis_data[:terms_in_attendance],
                   student_page_sis_data[:advisor_plans], student_page_sis_data[:advisor_names],
                   student_page_sis_data[:advisor_emails], student_page_sis_data[:entered_term], student_page_sis_data[:intended_majors],
                   student_page_sis_data[:visa], student_page_sis_data[:expected_graduation], student_page_sis_data[:graduation_degree],
                   student_page_sis_data[:graduation_date], student_page_sis_data[:graduation_colleges], student_page_sis_data[:inactive],
                   alert_data, hold_msgs]
            Utils.add_csv_row(user_profile_sis_data, row)
          end
        end
      end

      it('has at least one student with an alert') { expect(alert_students).not_to be_empty }
      it('has at least one student with a hold') { expect(hold_students).not_to be_empty }

    rescue => e
      Utils.log_error e
      it('encountered an error') { fail "#{e.message + "\n"} #{e.backtrace.join("\n ")}" }
    ensure
      Utils.quit_browser @driver
    end
  end
end