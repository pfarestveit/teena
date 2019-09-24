require_relative '../../util/spec_helper'

include Logging

describe 'BOAC' do

  begin
    test = BOACTestConfig.new
    test.sis_data
    alert_students = []
    hold_students = []

    # Create files for test output
    user_profile_data_heading = %w(UID Sport Name PreferredName Email Phone Units GPA Level Transfer Colleges Majors Terms Writing History Institutions Cultures Graduation Alerts Holds)
    user_profile_sis_data = Utils.create_test_output_csv('boac-sis-profiles.csv', user_profile_data_heading)

    user_course_data_heading = %w(UID Sport Term UnitsMin UnitsMax CourseCode CourseName SectionCcn SectionCode Primary? Midpoint Grade GradingBasis Units EnrollmentStatus)
    user_course_sis_data = Utils.create_test_output_csv('boac-sis-courses.csv', user_course_data_heading)

    @driver = Utils.launch_browser test.chrome_profile
    @boac_homepage = BOACHomePage.new @driver
    @boac_cohort_page = BOACUtils.shuffle_max_users ? BOACGroupPage.new(@driver) : BOACFilteredCohortPage.new(@driver, test.advisor)
    @boac_student_page = BOACStudentPage.new @driver
    @boac_admin_page = BOACAdminPage.new @driver
    @boac_search_page = BOACSearchResultsPage.new @driver

    @boac_homepage.dev_auth test.advisor

    if @boac_cohort_page.instance_of? BOACFilteredCohortPage
      @boac_cohort_page.search_and_create_new_cohort(test.default_cohort, test)
    else
      test.default_cohort = CuratedGroup.new(:name => "Group #{test.id}")
      @boac_homepage.click_sidebar_create_curated_group
      @boac_cohort_page.create_group_with_bulk_sids(test.max_cohort_members, test.default_cohort)
    end

    visible_sids = @boac_cohort_page.list_view_sids
    test.max_cohort_members.keep_if { |m| visible_sids.include? m.sis_id }
    test.max_cohort_members.each do |student|

      begin
        api_student_data = BOACApiStudentPage.new @driver
        api_student_data.get_data(@driver, student)
        api_sis_profile_data = api_student_data.sis_profile_data

        # COHORT PAGE SIS DATA

        BOACUtils.shuffle_max_users ? @boac_cohort_page.load_page(test.default_cohort) : @boac_cohort_page.load_cohort(test.default_cohort)
        cohort_page_sis_data = @boac_cohort_page.visible_sis_data(@driver, student)

        if api_sis_profile_data[:academic_career_status] == 'Completed'
          it("shows no level for UID #{student.uid} on the #{test.default_cohort.name} page") { expect(cohort_page_sis_data[:level]).to be_nil }
        elsif api_sis_profile_data[:level]
          it "shows the level for UID #{student.uid} on the #{test.default_cohort.name} page" do
            expect(cohort_page_sis_data[:level]).to eql(api_sis_profile_data[:level])
            expect(cohort_page_sis_data[:level]).not_to be_empty
          end
        else
          it("shows no level for UID #{student.uid} on the #{test.default_cohort.name} page") { expect(cohort_page_sis_data[:level]).to be_empty }
        end

        if api_sis_profile_data[:academic_career_status] == 'Completed'
          it "shows the right graduation date for UID #{student.uid} on the #{test.default_cohort.name} page" do
            expect(cohort_page_sis_data[:graduation_date]).to eql('Graduated ' + Date.parse(api_sis_profile_data[:graduation][:date]).strftime('%b %e, %Y'))
          end
          it "shows the right graduation colleges for UID #{student.uid} on the #{test.default_cohort.name} page" do
            expect(cohort_page_sis_data[:graduation_colleges]).to eql(api_sis_profile_data[:graduation][:colleges])
          end
        else
          it "shows no graduation date for UID #{student.uid} on the #{test.default_cohort.name} page" do
            expect(cohort_page_sis_data[:graduation_date]).to be_nil
          end
          it "shows no graduation colleges for UID #{student.uid} on the #{test.default_cohort.name} page" do
            expect(cohort_page_sis_data[:graduation_colleges]).to be_nil
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

        # TODO - shows withdrawal indicator if withdrawn

        active_majors = api_sis_profile_data[:majors].map { |m| m[:major] if m[:active] }.compact.sort
        if active_majors.any?
          it "shows the majors for UID #{student.uid} on the #{test.default_cohort.name} page" do
            expect(cohort_page_sis_data[:majors]).to eql(active_majors)
          end
        else
          it("shows no majors for UID #{student.uid} on the #{test.default_cohort.name} page") { expect(cohort_page_sis_data[:majors]).to be_nil }
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

        if api_sis_profile_data[:term_units]
          it "shows the units in progress for UID #{student.uid} on the #{test.default_cohort.name} page" do
            expect(cohort_page_sis_data[:term_units]).to eql(api_sis_profile_data[:term_units])
            expect(cohort_page_sis_data[:term_units]).not_to be_empty
          end
        else
          it("shows no units in progress for UID #{student.uid} on the #{test.default_cohort.name} page") { expect(cohort_page_sis_data[:term_units]).to eql('0') }
        end

        if api_sis_profile_data[:cumulative_units]
          it "shows the total units for UID #{student.uid} on the #{test.default_cohort.name} page" do
            expect(cohort_page_sis_data[:units_cumulative]).to eql(api_sis_profile_data[:cumulative_units])
            expect(cohort_page_sis_data[:units_cumulative]).not_to be_empty
          end
        else
          it("shows no total units for UID #{student.uid} on the #{test.default_cohort.name} page") { expect(cohort_page_sis_data[:units_cumulative]).to eql('0') }
        end

        it("shows the current term course codes for UID #{student.uid} on the #{test.default_cohort.name} page") { expect(cohort_page_sis_data[:classes]).to eql(api_student_data.current_non_dropped_course_codes) }

        it("shows waitlisted indicators, if any, for UID #{student.uid} on the #{test.default_cohort.name} page") { expect(cohort_page_sis_data[:waitlisted_classes]).to eql(api_student_data.current_waitlisted_course_codes) }

        # STUDENT PAGE SIS DATA

        @boac_cohort_page.click_student_link student
        @boac_student_page.wait_for_title student.full_name

        student_page_sis_data = @boac_student_page.visible_sis_data

        it("shows the name for UID #{student.uid} on the student page") { expect(student_page_sis_data[:name]).to eql(student.full_name.split(',').reverse.join(' ').strip) }

        it "shows the email for UID #{student.uid} on the student page" do
          expect(student_page_sis_data[:email]).to eql(api_sis_profile_data[:email])
          expect(student_page_sis_data[:email]).not_to be_empty
        end

        if api_sis_profile_data[:cumulative_units]
          it "shows the total units for UID #{student.uid} on the student page" do
            expect(student_page_sis_data[:cumulative_units]).to eql(api_sis_profile_data[:cumulative_units])
            expect(student_page_sis_data[:cumulative_units]).not_to be_empty
          end
        else
          it("shows no total units for UID #{student.uid} on the student page") { expect(student_page_sis_data[:cumulative_units]).to eql('--') }
        end

        it "shows the phone for UID #{student.uid} on the student page" do
          expect(student_page_sis_data[:phone]).to eql(api_sis_profile_data[:phone])
        end

        it "shows the cumulative GPA for UID #{student.uid} on the student page" do
          expect(student_page_sis_data[:cumulative_gpa]).to eql(api_sis_profile_data[:cumulative_gpa])
          expect(student_page_sis_data[:cumulative_gpa]).not_to be_empty
        end

        if api_sis_profile_data[:academic_career_status] != 'Completed' && api_sis_profile_data[:majors].any?
          it "shows the majors for UID #{student.uid} on the student page" do
            expect(student_page_sis_data[:majors]).to eql(api_sis_profile_data[:majors].map { |m| m[:major] }.compact)
            expect(student_page_sis_data[:colleges]).to eql(api_sis_profile_data[:majors].map { |m| m[:college] }.compact)
          end
        else
          it("shows no majors for UID #{student.uid} on the student page") { expect(student_page_sis_data[:majors]).to be_empty }
          it("shows no colleges for UID #{student.uid} on the student page") { expect(student_page_sis_data[:colleges].all?(&:empty?)).to be true }
        end

        if api_sis_profile_data[:academic_career_status] == 'Completed'
          it("shows no academic level for UID #{student.uid} on the student page") { expect(student_page_sis_data[:level]).to be_nil }
        elsif api_sis_profile_data[:level]
          it "shows the academic level for UID #{student.uid} on the student page" do
            expect(student_page_sis_data[:level]).to eql(api_sis_profile_data[:level])
            expect(student_page_sis_data[:level]).not_to be_empty
          end
        else
          it("shows no academic level for UID #{student.uid} on the student page") { expect(student_page_sis_data[:level]).to be_empty }
        end

        if api_sis_profile_data[:academic_career_status] == 'Completed'
          it "shows the right degree for UID #{student.uid} on the student page" do
            expect(student_page_sis_data[:graduation_degree]).to eql(api_sis_profile_data[:graduation][:degree] + ' in ' + api_sis_profile_data[:graduation][:majors].join(', '))
          end
          it "shows the right graduation date for UID #{student.uid} on the student page" do
            expect(student_page_sis_data[:graduation_date]).to eql('Awarded ' + Date.parse(api_sis_profile_data[:graduation][:date]).strftime('%b %e, %Y'))
          end
          it "shows the right graduation colleges for UID #{student.uid} on the student page" do
            expect(student_page_sis_data[:graduation_colleges]).to eql(api_sis_profile_data[:graduation][:colleges])
          end
        else
          it "shows no graduation degree for UID #{student.uid} on the student page" do
            expect(student_page_sis_data[:graduation_date]).to be_nil
          end
          it "shows no graduation date for UID #{student.uid} on the student page" do
            expect(student_page_sis_data[:graduation_date]).to be_nil
          end
          it "shows no graduation colleges for UID #{student.uid} on the student page" do
            expect(student_page_sis_data[:graduation_colleges]).to be_nil
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

        if (api_sis_profile_data[:academic_career_status] != 'Completed' && api_sis_profile_data[:terms_in_attendance] &&
            !api_sis_profile_data[:terms_in_attendance].empty? && api_sis_profile_data[:level] != 'Graduate')
          it "shows the terms in attendance for UID #{student.uid} on the student page" do
            expect(student_page_sis_data[:terms_in_attendance]).to include(api_sis_profile_data[:terms_in_attendance])
          end
        else
          it "shows no terms in attendance for UID #{student.uid} on the student page" do
            expect(student_page_sis_data[:terms_in_attendance]).to be_nil
          end
        end

        (api_sis_profile_data[:academic_career_status] != 'Completed' && api_sis_profile_data[:transfer]) ?
            (it("shows Transfer for UID #{student.uid} on the student page") { expect(student_page_sis_data[:transfer]).to eql('Transfer') }) :
            (it("shows no Transfer for UID #{student.uid} on the student page") { expect(student_page_sis_data[:transfer]).to be_nil })

        (api_sis_profile_data[:academic_career_status] == 'Completed' || api_sis_profile_data[:level] == 'Graduate') ?
            (it("shows no expected graduation date for UID #{student.uid} on the #{test.default_cohort.name} page") { expect(student_page_sis_data[:expected_graduation]).to be nil }) :
            (it("shows the expected graduation date for UID #{student.uid} on the #{test.default_cohort.name} page") { expect(student_page_sis_data[:expected_graduation]).to eql(api_sis_profile_data[:expected_grad_term_name]) })

        has_calcentral_link = @boac_student_page.calcentral_link(student).exists?
        it("shows a link to the student overview page in CalCentral on the student page for UID #{student.uid}") { expect(has_calcentral_link).to be true }

        # TIMELINE

        # Requirements

        student_page_reqts = @boac_student_page.visible_requirements
        it("shows the Entry Level Writing Requirement for UID #{student.uid} on the student page") { expect(student_page_reqts[:reqt_writing]).to eql(api_sis_profile_data[:reqt_writing]) }
        it("shows the American History Requirement for UID #{student.uid} on the student page") { expect(student_page_reqts[:reqt_history]).to eql(api_sis_profile_data[:reqt_history]) }
        it("shows the American Institutions Requirement for UID #{student.uid} on the student page") { expect(student_page_reqts[:reqt_institutions]).to eql(api_sis_profile_data[:reqt_institutions]) }
        it("shows the American Cultures Requirement for UID #{student.uid} on the student page") { expect(student_page_reqts[:reqt_cultures]).to eql(api_sis_profile_data[:reqt_cultures]) }

        # Alerts

        alerts = BOACUtils.get_students_alerts [student]
        alert_msgs = (alerts.map &:message).sort
        dismissed = BOACUtils.get_dismissed_alerts(alerts).map &:message
        logger.info "UID #{student.uid} alert count is #{alert_msgs.length}, with #{dismissed.length} dismissed"

        if alerts.any?
          alert_students << student
          visible_alerts = @boac_student_page.visible_alerts.sort
          logger.debug "UID #{student.uid} alerts are #{alert_msgs}, and visible alerts are #{visible_alerts}"
          it("has the alert messages for UID #{student.uid} on the student page") { expect(visible_alerts).to eql(alert_msgs) }
        end

        # Holds

        holds = NessieUtils.get_student_holds student
        hold_msgs = (holds.map { |h| h.message.gsub(/\W/, '') }).sort
        logger.info "UID #{student.uid} hold count is #{hold_msgs.length}"

        if holds.any?
          hold_students << student
          visible_holds = @boac_student_page.visible_holds.sort
          logger.debug "UID #{student.uid} holds are #{hold_msgs}, and visible holds are #{visible_holds}"
          it("has the hold messages for UID #{student.uid} on the student page") { expect(visible_holds).to eql(hold_msgs) }
        end

        if (withdrawal = api_sis_profile_data[:withdrawal])
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

        terms = api_student_data.terms
        if terms.any?
          if terms.length > 1
            @boac_student_page.click_view_previous_semesters
          else
            has_view_more_button = @boac_student_page.view_more_button_element.visible?
            it("shows no View Previous Semesters button for UID #{student.uid} on the student page") { expect(has_view_more_button).to be false }
          end

          terms.each do |term|

            begin
              term_id = api_student_data.term_id term
              term_name = api_student_data.term_name term
              logger.info "Checking #{term_name}"

              # TERM UNITS

              visible_term_units_data = @boac_student_page.visible_term_data(term_id, term_name)

              if api_student_data.term_units(term) && api_student_data.term_units(term).to_i.zero?
                it("shows no term units total for UID #{student.uid} term #{term_name}") { expect(visible_term_units_data[:term_units]).to be_nil }
              else
                it("shows the term units total for UID #{student.uid} term #{term_name}") { expect(visible_term_units_data[:term_units]).to eql(api_student_data.term_units term) }
              end

              if api_sis_profile_data[:term_units_min]
                if api_sis_profile_data[:term_units_min].zero? || term != api_student_data.current_term
                  it("shows no term units minimum for UID #{student.uid} term #{term_name}") { expect(visible_term_units_data[:term_units_min]).to be_nil }
                else
                  it("shows the term units minimum for UID #{student.uid} term #{term_name}") { expect(visible_term_units_data[:term_units_min]).to eql(api_sis_profile_data[:term_units_min].to_s) }
                end
              else
                it("shows no term units minimum for UID #{student.uid} term #{term_name}") { expect(visible_term_units_data[:term_units_min]).to be_nil }
              end

              if api_sis_profile_data[:term_units_max]
                if api_sis_profile_data[:term_units_max].zero? || term != api_student_data.current_term
                  it("shows no term units maximum for UID #{student.uid} term #{term_name}") { expect(visible_term_units_data[:term_units_max]).to be_nil }
                else
                  it("shows the term units maximum for UID #{student.uid} term #{term_name}") { expect(visible_term_units_data[:term_units_max]).to eql(api_sis_profile_data[:term_units_max].to_s) }
                end
              else
                it("shows no term units maximum for UID #{student.uid} term #{term_name}") { expect(visible_term_units_data[:term_units_max]).to be_nil }
              end

              # COURSES

              term_section_ccns = []

              if api_student_data.courses(term).any?
                api_student_data.courses(term).each do |course|

                  begin
                    course_sis_data = api_student_data.sis_course_data course
                    course_code = course_sis_data[:code]

                    logger.info "Checking course #{course_code}"

                    @boac_student_page.expand_course_data(term_name, course_code)

                    visible_course_sis_data = @boac_student_page.visible_course_sis_data(term_name, course_code)
                    visible_course_title = visible_course_sis_data[:title]
                    visible_units = visible_course_sis_data[:units_completed]
                    visible_grading_basis = visible_course_sis_data[:grading_basis]
                    visible_midpoint = visible_course_sis_data[:mid_point_grade]
                    visible_grade = visible_course_sis_data[:grade]

                    it "shows the course title for UID #{student.uid} term #{term_name} course #{course_code}" do
                      expect(visible_course_title).not_to be_empty
                      expect(visible_course_title).to eql(course_sis_data[:title])
                    end

                    it "shows the units for UID #{student.uid} term #{term_name} course #{course_code}" do
                      expect(visible_units).not_to be_empty
                      expect(visible_units).to eql(course_sis_data[:units_completed])
                    end

                    if course_sis_data[:grade].empty?
                      if course_sis_data[:grading_basis] == 'NON'
                        it "shows no grade and no grading basis for UID #{student.uid} term #{term_name} course #{course_code}" do
                          expect(visible_grade).to be_empty
                          expect(visible_grading_basis).to be_nil
                        end
                      else
                        it("shows the grading basis for UID #{student.uid} term #{term_name} course #{course_code}") { expect(visible_grading_basis).to eql(course_sis_data[:grading_basis]) }
                      end
                    else
                      it("shows the grade for UID #{student.uid} term #{term_name} course #{course_code}") { expect(visible_grade).to eql(course_sis_data[:grade]) }
                    end

                    if term_name == BOACUtils.term
                      if course_sis_data[:midpoint]
                        it "shows the midpoint grade for UID #{student.uid} term #{term_name} course #{course_code}" do
                          expect(visible_midpoint).not_to be_empty
                          expect(visible_midpoint).to eql(course_sis_data[:midpoint])
                        end
                      else
                        it("shows no midpoint grade for UID #{student.uid} term #{term_name} course #{course_code}") { expect(visible_midpoint).to include('No data') }
                      end
                    else
                      it("shows no midpoint grade for UID #{student.uid} term #{term_name} course #{course_code}") { expect(visible_midpoint).to be_nil }
                    end

                    # SECTIONS

                    api_student_data.sections(course).each do |section|

                      begin
                        index = api_student_data.sections(course).index section
                        section_sis_data = api_student_data.sis_section_data section
                        term_section_ccns << section_sis_data[:ccn]
                        component = section_sis_data[:component]

                        visible_section_sis_data = @boac_student_page.visible_section_sis_data(term_name, course_code, index)
                        visible_section = visible_section_sis_data[:section]
                        visible_wait_list_status = visible_course_sis_data[:wait_list]

                        it "shows the section number for UID #{student.uid} term #{term_name} course #{course_code} section #{component}" do
                          expect(visible_section).not_to be_empty
                          expect(visible_section).to eql("#{section_sis_data[:component]} #{section_sis_data[:number]}")
                        end

                        (section_sis_data[:status] == 'W') ?
                            (it("shows the wait list status for UID #{student.uid} term #{term_name} course #{course_code}") { expect(visible_wait_list_status).to be true }) :
                            (it("shows no enrollment status for UID #{student.uid} term #{term_name} course #{course_code}") { expect(visible_wait_list_status).to be false })

                      rescue => e
                        BOACUtils.log_error_and_screenshot(@driver, e, "#{student.uid}-#{term_name}-#{course_code}-#{section_sis_data[:ccn]}")
                        it("encountered an error for UID #{student.uid} term #{term_name} course #{course_code} section #{section_sis_data[:ccn]}") { fail }
                      ensure
                        row = [student.uid, student.sports, term_name, api_sis_profile_data[:term_units_min], api_sis_profile_data[:term_units_max], course_code, course_sis_data[:title],
                               section_sis_data[:ccn], "#{section_sis_data[:component]} #{section_sis_data[:number]}", section_sis_data[:primary], course_sis_data[:midpoint],
                               course_sis_data[:grade], course_sis_data[:grading_basis], course_sis_data[:units_completed], section_sis_data[:status]]
                        Utils.add_csv_row(user_course_sis_data, row)
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
                  visible_drop = @boac_student_page.visible_dropped_section_data(term_name, drop[:title], drop[:component], drop[:number])
                  (term_name == BOACUtils.term) ?
                      (it("shows dropped section #{drop[:title]} #{drop[:component]} #{drop[:number]} for UID #{student.uid} in #{term_name}") { expect(visible_drop).to be_truthy }) :
                      (it("shows no dropped section #{drop[:title]} #{drop[:component]} #{drop[:number]} for UID #{student.uid} in past term #{term_name}") { expect(visible_drop).to be_falsey })

                  row = [student.uid, student.sports, term_name, nil, nil, drop[:title], nil, nil, drop[:number], nil, nil, nil, 'D']
                  Utils.add_csv_row(user_course_sis_data, row)
                end
              end

            rescue => e
              BOACUtils.log_error_and_screenshot(@driver, e, "#{student.uid}-#{term_name}")
              it("encountered an error for UID #{student.uid} term #{term_name}") { fail }
            end
          end

        else
          logger.warn "UID #{student.uid} has no term data"
        end

      rescue => e
        BOACUtils.log_error_and_screenshot(@driver, e, "#{student.uid}")
        it("encountered an error for UID #{student.uid}") { fail }
      ensure
        if student_page_sis_data
          row = [student.uid, student.sports, student_page_sis_data[:name], student_page_sis_data[:preferred_name], student_page_sis_data[:email],
                 student_page_sis_data[:phone], student_page_sis_data[:cumulative_units], student_page_sis_data[:cumulative_gpa], student_page_sis_data[:level], student_page_sis_data[:transfer],
                 student_page_sis_data[:colleges] && student_page_sis_data[:colleges] * '; ', student_page_sis_data[:majors] && student_page_sis_data[:majors] * '; ',
                 student_page_sis_data[:terms_in_attendance], student_page_reqts[:reqt_writing], student_page_reqts[:reqt_history],
                 student_page_reqts[:reqt_institutions], student_page_reqts[:reqt_cultures], student_page_sis_data[:expected_graduation], alert_msgs, hold_msgs]
          Utils.add_csv_row(user_profile_sis_data, row)
        end
      end
    end

  it('has at least one student with an alert') { expect(alert_students).not_to be_empty }
  it('has at least one student with a hold') { expect(hold_students).not_to be_empty }

  rescue => e
    Utils.log_error e
    it('encountered an error') { fail }
  ensure
    Utils.quit_browser @driver
  end
end
