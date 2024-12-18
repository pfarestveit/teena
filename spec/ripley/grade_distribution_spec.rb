require_relative '../../util/spec_helper'

describe 'The Grade Distribution tool' do

  include Logging

  test = RipleyTestConfig.new
  test.grade_distribution
  terms = RipleyUtils.get_terms_since_code_red

  begin
    logger.info "Test course sites: #{test.course_sites.map &:site_id}"
    non_auth_users = [
      test.manual_teacher,
      test.lead_ta,
      test.ta,
      test.designer,
      test.reader,
      test.observer,
      test.students.first,
      test.wait_list_student
    ]

    @driver = Utils.launch_browser chrome_3rd_party_cookies: true
    @add_user = RipleyAddUserPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasPage.new @driver
    @canvas_api = CanvasAPIPage.new @driver
    @newt = RipleyGradeDistributionPage.new @driver

    @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
    @canvas.set_canvas_ids non_auth_users
    @canvas_api.get_support_admin_canvas_id test.canvas_admin

    test.course_sites.each do |site|

      begin
        @canvas.stop_masquerading

        section_ids = @canvas_api.get_course_site_sis_section_ids site.site_id
        test.get_existing_site_data(site, section_ids, newt = true)
        test_case = "#{site.course.term.name} #{site.course.code} site #{site.site_id}"

        @canvas.add_ripley_tools([RipleyTool::ADD_USER, RipleyTool::NEWT])

        instructors = RipleyUtils.get_primary_instructors site
        instructor = instructors.first || site.course.teachers.first
        aprx = RipleyUtils.course_instructor_of_role_code(site.course, 'APRX')
        icnt = RipleyUtils.course_instructor_of_role_code(site.course, 'ICNT')
        tnic = RipleyUtils.course_instructor_of_role_code(site.course, 'TNIC')
        site_primaries = RipleyUtils.get_instructor_primaries(site.sections, instructor)
        site_enrolls = site_primaries.map(&:enrollments).flatten
        site_grades_ct = site_enrolls.map(&:grade).length
        site_ltr_grade_enrolls = site_enrolls.select { |e| %w(A+ A A- B+ B B- C+ C C- D+ D D- F).include? e.grade }

        logger.info "Grade count for site primary sections taught by UID #{instructor.uid} is #{site_grades_ct}"

        @canvas.set_canvas_ids [instructor]
        @canvas.masquerade_as(instructor, site)
        @canvas.publish_course_site(site, set_template=false) if @canvas.publish_status?
        @newt.load_embedded_tool site
        @newt.wait_until(Utils.medium_wait) { @newt.demographics_table_toggle? || @newt.no_grade_dist_msg? || @newt.no_grades_msg_elements.any? }

        begin
          if site_ltr_grade_enrolls.length >= RipleyUtils.newt_min_grade_count
            shows_demographics = @newt.demographics_table_toggle?
            shows_prior_enrollment = @newt.prior_enrollment_table_toggle?
            no_grades = @newt.no_grades_msg_elements.any?
            no_nothin = @newt.no_grade_dist_msg?

            cs_course_id = site.course.sections.find(&:primary).cs_course_id
            all_term_courses = RipleyUtils.get_all_instr_courses_per_cs_id(terms, instructor, cs_course_id)
            all_term_courses_terms = all_term_courses.map { |c| c.term.name }
            all_term_courses.keep_if { |c| c.term.sis_id.to_i <= site.course.term.sis_id.to_i }

            if site_grades_ct.zero?
              if all_term_courses.empty?
                it("shows a No Grade Distribution message on #{test_case}") { expect(no_nothin).to be true }
                it("offers no demographics default data and table on #{test_case}") { expect(shows_demographics).to be false }
                it("offers no prior enrollment default data and table on #{test_case}") { expect(shows_prior_enrollment).to be false }
              else
                it("shows a No Grades Yet message on #{test_case}") { expect(no_grades).to be true }
                it("offers demographics default data and table on #{test_case}") { expect(shows_demographics).to be true }
                it("offers prior enrollment default data and table on #{test_case}") { expect(shows_prior_enrollment).to be true }
              end
            else
              it("shows no No Grades Yet message on #{test_case}") { expect(no_grades).to be false }
              it("offers demographics default data and table on #{test_case}") { expect(shows_demographics).to be true }
              it("offers prior enrollment default data and table on #{test_case}") { expect(shows_prior_enrollment).to be true }
            end

            logger.info "Checking all terms where UID #{instructor.uid} taught this course"
            demographics_terms = []
            prior_enrollment_terms = []
            @newt.expand_demographics_table if shows_demographics

            all_term_courses.each do |course|
              if site_grades_ct.zero?
                logger.info "Skipping term #{course.term.name} with no grades"
              else
                begin
                  logger.info "Checking term #{course.term.name}"

                  term_course_primaries = RipleyUtils.get_instructor_primaries(course.sections, instructor)
                  term_all_grade_enrolls = term_course_primaries.map(&:enrollments).flatten

                  # DEMOGRAPHICS

                  term_ltr_grade_enrolls = term_all_grade_enrolls.select { |e| %w(A+ A A- B+ B B- C+ C C- D+ D D- F).include? e.grade }
                  term_mean = @newt.expected_mean_grade_points term_ltr_grade_enrolls
                  @newt.select_demographic 'Select Demographic'
                  @newt.select_statistic 'Mean Grade Values'
                  visible_mean_term_data = @newt.visible_demographics_term_data course.term

                  if term_ltr_grade_enrolls.length < RipleyUtils.newt_min_grade_count
                    it "shows no mean grade points for #{test_case} term #{course.term.name}" do
                      expect(visible_mean_term_data[:ttl_stat]).to be_empty
                    end
                    it "shows no student count for #{test_case} term #{course.term.name}" do
                      expect(visible_mean_term_data[:ttl_ct]).to be_empty
                    end

                  else
                    demographics_terms << course.term.name
                    it "shows the mean grade points for #{test_case} term #{course.term.name}" do
                      expect(visible_mean_term_data[:ttl_stat]).to eql(term_mean)
                    end
                    it "shows the student count for #{test_case} term #{course.term.name}" do
                      expect(visible_mean_term_data[:ttl_ct]).to eql(term_ltr_grade_enrolls.length.to_s)
                    end
                    it "shows no demographic mean grade points for #{test_case} term #{course.term.name}" do
                      expect(visible_mean_term_data[:sub_stat]).to be_empty
                    end
                    it "shows no demographic student count for #{test_case} term #{course.term.name}" do
                      expect(visible_mean_term_data[:sub_ttl]).to be_nil
                    end
                    @newt.select_statistic 'Median Grade Values'
                    term_median = @newt.expected_median_grade_points term_ltr_grade_enrolls
                    visible_median_term_data = @newt.visible_demographics_term_data course.term
                    it "shows the median grade points for #{test_case} term #{course.term.name}" do
                      expect(visible_median_term_data[:ttl_stat]).to eql(term_median)
                    end
                    it "shows the student count for #{test_case} term #{course.term.name}" do
                      expect(visible_median_term_data[:ttl_ct]).to eql(term_ltr_grade_enrolls.length.to_s)
                    end

                    # Female

                    logger.info "Checking female view of #{course.term.name} #{course.code}"
                    female_ltr_grade_enrolls = term_ltr_grade_enrolls.select { |e| e.user.demographics[:gender] == 'Female' }
                    @newt.select_demographic 'Female Students'
                    @newt.select_statistic 'Mean Grade Values'
                    female_ct = @newt.expected_demographic_count female_ltr_grade_enrolls
                    female_mean = @newt.expected_mean_grade_points female_ltr_grade_enrolls
                    visible_female_mean_data = @newt.visible_demographics_term_data course.term
                    it "shows the mean grade points for #{test_case} term #{course.term.name}" do
                      expect(visible_female_mean_data[:ttl_stat]).to eql(term_mean)
                    end
                    it "shows the student count for #{test_case} term #{course.term.name}" do
                      expect(visible_female_mean_data[:ttl_ct]).to eql(term_ltr_grade_enrolls.length.to_s)
                    end
                    it "shows the female mean grade points for #{test_case} term #{course.term.name}" do
                      expect(visible_female_mean_data[:sub_stat]).to eql(female_mean)
                    end
                    it "shows the female student count for #{test_case} term #{course.term.name}" do
                      expect(visible_female_mean_data[:sub_ct]).to eql(female_ct)
                    end
                    @newt.select_statistic 'Median Grade Values'
                    female_median = @newt.expected_median_grade_points female_ltr_grade_enrolls
                    visible_female_median_data = @newt.visible_demographics_term_data course.term
                    it "shows the female median grade points for #{test_case} term #{course.term.name}" do
                      expect(visible_female_median_data[:sub_stat]).to eql(female_median)
                    end
                    it "shows the female student count for #{test_case} term #{course.term.name}" do
                      expect(visible_female_median_data[:sub_ct]).to eql(female_ct)
                    end

                    # Male

                    logger.info "Checking male view of #{course.term.name} #{course.code}"
                    male_ltr_grade_enrolls = term_ltr_grade_enrolls.select { |e| e.user.demographics[:gender] == 'Male' }
                    @newt.select_demographic 'Male Students'
                    @newt.select_statistic 'Mean Grade Values'
                    male_ct = @newt.expected_demographic_count male_ltr_grade_enrolls
                    male_mean = @newt.expected_mean_grade_points male_ltr_grade_enrolls
                    visible_male_mean_data = @newt.visible_demographics_term_data course.term
                    it "shows the male mean grade points for #{test_case} term #{course.term.name}" do
                      expect(visible_male_mean_data[:sub_stat]).to eql(male_mean)
                    end
                    it "shows the male student count for #{test_case} term #{course.term.name}" do
                      expect(visible_male_mean_data[:sub_ct]).to eql(male_ct)
                    end
                    @newt.select_statistic 'Median Grade Values'
                    male_median = @newt.expected_median_grade_points male_ltr_grade_enrolls
                    visible_male_median_data = @newt.visible_demographics_term_data course.term
                    it "shows the male median grade points for #{test_case} term #{course.term.name}" do
                      expect(visible_male_median_data[:sub_stat]).to eql(male_median)
                    end
                    it "shows the male student count for #{test_case} term #{course.term.name}" do
                      expect(visible_male_median_data[:sub_ct]).to eql(male_ct)
                    end

                    # Underrepresented Minority

                    logger.info "Checking minority view of #{course.term.name} #{course.code}"
                    minority_ltr_grade_enrolls = term_ltr_grade_enrolls.select { |e| e.user.demographics[:minority] }
                    @newt.select_demographic 'Underrepresented Minority Students'
                    @newt.select_statistic 'Mean Grade Values'
                    minority_ct = @newt.expected_demographic_count minority_ltr_grade_enrolls
                    minority_mean = @newt.expected_mean_grade_points minority_ltr_grade_enrolls
                    visible_minority_term_data = @newt.visible_demographics_term_data course.term
                    it "shows the underrepresented minority mean grade points for #{test_case} term #{course.term.name}" do
                      expect(visible_minority_term_data[:sub_stat]).to eql(minority_mean)
                    end
                    it "shows the underrepresented minority student count for #{test_case} term #{course.term.name}" do
                      expect(visible_minority_term_data[:sub_ct]).to eql(minority_ct)
                    end
                    @newt.select_statistic 'Median Grade Values'
                    minority_median = @newt.expected_median_grade_points minority_ltr_grade_enrolls
                    visible_minority_median_data = @newt.visible_demographics_term_data course.term
                    it "shows the underrepresented minority median grade points for #{test_case} term #{course.term.name}" do
                      expect(visible_minority_median_data[:sub_stat]).to eql(minority_median)
                    end
                    it "shows the underrepresented minority student count for #{test_case} term #{course.term.name}" do
                      expect(visible_minority_median_data[:sub_ct]).to eql(minority_ct)
                    end

                    # International Students

                    logger.info "Checking international student view of #{course.term.name} #{course.code}"
                    intl_ltr_grade_enrolls = term_ltr_grade_enrolls.select { |e| e.user.demographics[:intl] }
                    @newt.select_demographic 'International Students'
                    @newt.select_statistic 'Mean Grade Values'
                    intl_ct = @newt.expected_demographic_count intl_ltr_grade_enrolls
                    intl_mean = @newt.expected_mean_grade_points intl_ltr_grade_enrolls
                    visible_intl_term_data = @newt.visible_demographics_term_data course.term
                    it "shows the international student mean grade points for #{test_case} term #{course.term.name}" do
                      expect(visible_intl_term_data[:sub_stat]).to eql(intl_mean)
                    end
                    it "shows the international student count for #{test_case} term #{course.term.name}" do
                      expect(visible_intl_term_data[:sub_ct]).to eql(intl_ct)
                    end
                    @newt.select_statistic 'Median Grade Values'
                    intl_median = @newt.expected_median_grade_points intl_ltr_grade_enrolls
                    visible_intl_median_data = @newt.visible_demographics_term_data course.term
                    it "shows the international student median grade points for #{test_case} term #{course.term.name}" do
                      expect(visible_intl_median_data[:sub_stat]).to eql(intl_median)
                    end
                    it "shows the international student count for #{test_case} term #{course.term.name}" do
                      expect(visible_intl_median_data[:sub_ct]).to eql(intl_ct)
                    end

                    # Transfer Students

                    logger.info "Checking transfer student view of #{course.term.name} #{course.code}"
                    transfer_ltr_grade_enrolls = term_ltr_grade_enrolls.select { |e| e.user.demographics[:transfer] }
                    @newt.select_demographic 'Transfer Students'
                    @newt.select_statistic 'Mean Grade Values'
                    transfer_ct = @newt.expected_demographic_count transfer_ltr_grade_enrolls
                    transfer_mean = @newt.expected_mean_grade_points transfer_ltr_grade_enrolls
                    visible_transfer_term_data = @newt.visible_demographics_term_data course.term
                    it "shows the transfer student mean grade points for #{test_case} term #{course.term.name}" do
                      expect(visible_transfer_term_data[:sub_stat]).to eql(transfer_mean)
                    end
                    it "shows the transfer student count for #{test_case} term #{course.term.name}" do
                      expect(visible_transfer_term_data[:sub_ct]).to eql(transfer_ct)
                    end
                    @newt.select_statistic 'Median Grade Values'
                    transfer_median = @newt.expected_median_grade_points transfer_ltr_grade_enrolls
                    visible_transfer_median_data = @newt.visible_demographics_term_data course.term
                    it "shows the transfer median grade points for #{test_case} term #{course.term.name}" do
                      expect(visible_transfer_median_data[:sub_stat]).to eql(transfer_median)
                    end
                    it "shows the transfer student count for #{test_case} term #{course.term.name}" do
                      expect(visible_transfer_median_data[:sub_ct]).to eql(transfer_ct)
                    end

                    # Student Athletes

                    logger.info "Checking student athlete view of #{course.term.name} #{course.code}"
                    athlete_ltr_grade_enrolls = term_ltr_grade_enrolls.select { |e| e.user.demographics[:athlete] }
                    @newt.select_demographic 'Student Athletes'
                    @newt.select_statistic 'Mean Grade Values'
                    athlete_ct = @newt.expected_demographic_count athlete_ltr_grade_enrolls
                    athlete_mean = @newt.expected_mean_grade_points athlete_ltr_grade_enrolls
                    visible_athlete_term_data = @newt.visible_demographics_term_data course.term
                    it "shows the athlete student mean grade points for #{test_case} term #{course.term.name}" do
                      expect(visible_athlete_term_data[:sub_stat]).to eql(athlete_mean)
                    end
                    it "shows the athlete student count for #{test_case} term #{course.term.name}" do
                      expect(visible_athlete_term_data[:sub_ct]).to eql(athlete_ct)
                    end
                    @newt.select_statistic 'Median Grade Values'
                    athlete_median = @newt.expected_median_grade_points athlete_ltr_grade_enrolls
                    visible_athlete_median_data = @newt.visible_demographics_term_data course.term
                    it "shows the athlete student median grade points for #{test_case} term #{course.term.name}" do
                      expect(visible_athlete_median_data[:sub_stat]).to eql(athlete_median)
                    end
                    it "shows the athlete student count for #{test_case} term #{course.term.name}" do
                      expect(visible_athlete_median_data[:sub_ct]).to eql(athlete_ct)
                    end
                  end
                rescue => e
                  Utils.log_error e
                  it "hit an error checking the highcharts graphs with #{test_case} #{course.term.name} #{course.code}" do
                    fail Utils.error(e)
                  end
                end
              end
            end

            # PRIOR ENROLLMENT

            prior_course_code = 'ECON 1'
            @newt.choose_prior_enrollment_course prior_course_code
            all_term_courses.each do |course|
              if site_grades_ct.zero?
                logger.info "Skipping term #{course.term.name} with no grades"
              else
                begin
                  logger.info "Checking term #{course.term.name}"
                  term_course_primaries = RipleyUtils.get_instructor_primaries(course.sections, instructor)
                  term_all_grade_enrolls = term_course_primaries.map(&:enrollments).flatten
                  term_ltr_plus_grade_enrolls = term_all_grade_enrolls.select { |e| %w(A+ A A- B+ B B- C+ C C- D+ D D- F I NP P).include? e.grade }
                  if term_ltr_plus_grade_enrolls.length >= RipleyUtils.newt_min_grade_count

                    @newt.select_prior_enrollment_term course.term
                    @newt.wait_until(Utils.medium_wait) do
                      @newt.no_prior_enrollments_msg(course, prior_course_code).exists? ||
                        @newt.prior_enrollment_data_heading(course, prior_course_code).exists?
                    end
                    @newt.expand_prior_enrollment_table if shows_prior_enrollment
                    prior_enrollment_terms << course.term.name

                    all_uids = term_ltr_plus_grade_enrolls.map { |e| e.user.uid }
                    prior_enroll_uids = RipleyUtils.get_newt_prior_enrollment_uids(all_uids, course.term, prior_course_code)
                    if prior_enroll_uids.empty?
                      no_priors = @newt.no_prior_enrollments_msg(course, prior_course_code).exists?
                      it "shows no prior enrollments for #{test_case} course code #{prior_course_code} in term #{course.term.name}" do
                        expect(no_priors).to be true
                      end

                    else
                      prior_enroll_enrolls = term_ltr_plus_grade_enrolls.select { |e| prior_enroll_uids.include? e.user.uid }

                      all_uids_per_all_grades = RipleyUtils.newt_enrollments_per_grade term_ltr_plus_grade_enrolls
                      prior_enroll_uids_per_all_grades = RipleyUtils.newt_enrollments_per_grade prior_enroll_enrolls

                      grades = all_uids_per_all_grades.map { |g| g[:grade] }
                      grades.each do |grade|

                        overall_grade_hash = all_uids_per_all_grades.find { |g| g[:grade] == grade }
                        overall_grade_uids = overall_grade_hash[:uids]
                        overall_grade_pct = @newt.expected_grade_pct(overall_grade_uids.length, all_uids.length)

                        prior_enroll_grade_hash = prior_enroll_uids_per_all_grades.find { |g| g[:grade] == grade }
                        prior_enroll_grade_uids = prior_enroll_grade_hash ? prior_enroll_grade_hash[:uids].uniq : []
                        prior_enroll_grade_pct = @newt.expected_grade_pct(prior_enroll_grade_uids.length, prior_enroll_uids.length)

                        visible_grade_data = @newt.visible_prior_enroll_grade_data grade
                        it "shows the #{grade} overall % for #{test_case} term #{course.term.name}" do
                          expect(visible_grade_data[:ttl_pct]).to eql(overall_grade_pct)
                        end
                        it "shows the #{grade} overall count for #{test_case} term #{course.term.name}" do
                          expect(visible_grade_data[:ttl_ct]).to eql(overall_grade_uids.length.to_s)
                        end
                        it "shows the #{grade} % with #{prior_course_code} for #{test_case} term #{course.term.name}" do
                          expect(visible_grade_data[:sub_pct]).to eql(prior_enroll_grade_pct)
                        end
                        it "shows the #{grade} count with #{prior_course_code} for #{test_case} term #{course.term.name}" do
                          expect(visible_grade_data[:sub_ct]).to eql(prior_enroll_grade_uids.length.to_s)
                        end
                      end
                    end

                  else
                    opts = @newt.prior_enrollment_select_options
                    it "shows no term option for low enrollment #{test_case} term #{course.term.name}" do
                      expect(opts).not_to include(course.term.name)
                    end
                  end

                rescue => e
                  Utils.log_error e
                  it "hit an error checking the highcharts graphs with #{test_case} #{course.term.name} #{course.code}" do
                    fail Utils.error(e)
                  end
                end
              end
            end

            it "shows only instructor terms for #{test_case} demographics" do
              expect(demographics_terms - all_term_courses_terms).to be_empty
            end
            it "shows only instructor terms for #{test_case} prior enrollment" do
              expect(prior_enrollment_terms - all_term_courses_terms).to be_empty
            end

            [aprx, icnt, tnic].each do |user_role|
              if user_role
                logger.info "Checking user role #{user_role.role_code} tool access"
                @canvas.stop_masquerading
                @canvas.set_canvas_ids [user_role.user]
                @canvas.masquerade_as(user_role.user, site)
                @newt.load_embedded_tool site
                user_role_respected = @canvas.verify_block do
                  if user_role == tnic
                    @newt.unauthorized_msg_element.when_visible Utils.short_wait
                  elsif site_grades_ct.zero? && all_term_courses.empty?
                    @newt.no_grade_dist_msg_element.when_visible Utils.short_wait
                  else
                    @newt.demographics_table_toggle_element.when_visible Utils.short_wait
                  end
                end
                it "permits #{user_role.role_code} #{user_role.user.uid} access to #{test_case} if permitted" do
                  expect(user_role_respected).to be true
                end
              end
            end

          else
            blocks_tool = @newt.no_grade_dist_msg?
            it("will not load grade data on #{test_case}") { expect(blocks_tool).to be true }
          end

        rescue => e
          Utils.log_error e
          it("hit an error loading Newt for #{test_case}") { fail Utils.error(e) }
        end

        if site == test.course_sites.last
          non_auth_users << test.canvas_admin
          primary_sec = site.sections.find &:primary
          @canvas.stop_masquerading
          @canvas.add_ripley_tools [RipleyTool::ADD_USER]
          non_auth_users.each do |user|
            @canvas.stop_masquerading
            @add_user.load_embedded_tool site
            unless user == test.canvas_admin
              @add_user.search(user.uid, 'CalNet UID')
              @add_user.add_user_by_uid(user, primary_sec)
            end
            user_blocked = @canvas.verify_block do
              @canvas.masquerade_as(user, site)
              @newt.load_embedded_tool site
              if user.role == 'Teacher'
                @newt.sorry_not_auth_msg_element.when_visible Utils.short_wait
              else
                @newt.unauthorized_msg_element.when_visible Utils.short_wait
              end
            end
            it("denies #{user.role} #{user.uid} access to the tool") { expect(user_blocked).to be true }
          end
          non_auth_users.delete test.canvas_admin
          @canvas.load_users_page site
          @canvas.wait_until(Utils.short_wait) { @canvas.user_row_elements.any? }
          non_auth_users.each do |user|
            @canvas.search_user_by_canvas_id user
            @canvas.remove_user_from_course(site, user)
          end
        end

      rescue => e
        Utils.log_error e
        it("hit an error with #{test_case}") { fail Utils.error(e) }
      end
    end
  rescue => e
    Utils.log_error e
    it('hit an error initializing') { fail Utils.error(e) }
  ensure
    Utils.quit_browser @driver
  end
end
