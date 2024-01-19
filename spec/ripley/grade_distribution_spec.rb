require_relative '../../util/spec_helper'

describe 'The Grade Distribution tool' do

  include Logging

  test = RipleyTestConfig.new
  test.grade_distribution
  terms = RipleyUtils.get_terms_since_code_red

  begin
    logger.info "Test course sites: #{test.course_sites.map &:site_id}"
    non_teachers = [
      test.lead_ta,
      test.ta,
      test.designer,
      test.reader,
      test.observer,
      test.students.first,
      test.wait_list_student
    ]

    @driver = Utils.launch_browser
    @add_user = RipleyAddUserPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasPage.new @driver
    @canvas_api = CanvasAPIPage.new @driver
    @newt = RipleyGradeDistributionPage.new @driver

    @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
    @canvas.set_canvas_ids non_teachers
    @canvas_api.get_support_admin_canvas_id test.canvas_admin

    test.course_sites.each do |site|

      begin
        @canvas.stop_masquerading

        section_ids = @canvas_api.get_course_site_sis_section_ids site.site_id
        test.get_existing_site_data(site, section_ids)
        test_case = "#{site.course.term.name} #{site.course.code} site #{site.site_id}"

        @canvas.add_ripley_tools(RipleyTool::TOOLS.reject(&:account), site)

        instructors = RipleyUtils.get_primary_instructors site
        instructor = instructors.first || site.course.teachers.first
        @canvas.set_canvas_ids [instructor]

        @canvas.masquerade_as(instructor, site)
        @newt.load_embedded_tool site

        begin
          shows_demographics = @newt.verify_block({ screenshot: true, screenshot_name: site.site_id }) do
            @newt.expand_demographics_table
          end
          it("offers demographics default data and table on #{test_case}") { expect(shows_demographics).to be true }

          if shows_demographics
            logger.info "Checking all terms where UID #{instructor.uid} taught this course"
            cs_course_id = site.course.sections.find(&:primary).cs_course_id
            all_term_courses = RipleyUtils.get_all_instr_courses_per_cs_id(terms, instructor, cs_course_id)
            all_term_courses.each do |course|
              begin
                logger.info "Checking #{course.term.name} #{course.code}"

                primaries = course.sections.select do |s|
                  instructor_uids = s.instructors_and_roles.map { |i| i.user.uid }
                  s.primary && instructor_uids.include?(instructor.uid)
                end

                student_count = primaries.map(&:enrollments).flatten.map(&:grade).select { |g| %w(A+ A A- B+ B B- C+ C C- D+ D D- F).include? g }.length
                logger.info "Enrollment count is #{student_count}"

                if student_count >= 50
                  logger.info 'Checking Newt data'
                  avg = RipleyUtils.average_grade_points primaries
                  visible_term_data = @newt.visible_demographics_term_data course.term
                  it "shows the average grade points for #{test_case} term #{course.term.name}" do
                    expect(visible_term_data[:avg]).to eql(avg.to_s)
                  end
                  it "shows the student count for #{test_case} term #{course.term.name}" do
                    expect(visible_term_data[:count]).to eql(student_count.to_s)
                  end
                end
              rescue => e
                Utils.log_error e
                it("hit an error checking the highcharts graphs with #{test_case} #{course.term.name} #{course.code}") { fail Utils.error(e) }
              end
            end
          end

          shows_prior_enrollments = @newt.verify_block({ screenshot: true, screenshot_name: site.site_id }) do
            @newt.expand_prior_enrollment_table
          end
          it("offers prior enrollment default data and table on #{test_case}") { expect(shows_prior_enrollments).to be true }
        end
      rescue => e
        Utils.log_error e
        it("hit an error loading Newt for #{test_case}") { fail Utils.error(e) }
      end

      if site == test.course_sites.last
        primary_sec = site.sections.find &:primary
        @canvas.stop_masquerading
        @canvas.add_ripley_tools [RipleyTool::ADD_USER]
        non_teachers.each do |user|
          @canvas.stop_masquerading
          @add_user.load_embedded_tool site
          @add_user.search(user.uid, 'CalNet UID')
          @add_user.add_user_by_uid(user, primary_sec)
          user_blocked = @canvas.verify_block do
            @canvas.masquerade_as(user, site)
            @newt.load_embedded_tool site
            @newt.unauthorized_msg_element.when_visible Utils.medium_wait
          end
          it("denies #{user.role} #{user.uid} access to the tool") { expect(user_blocked).to be true }
        end
        admin_access = @newt.verify_block do
          @canvas.masquerade_as(test.canvas_admin, site)
          @newt.load_embedded_tool site
          @newt.expand_demographics_table
        end
        it("permits a #{test.canvas_admin.role} access to the tool") { expect(admin_access).to be true }
      end

    rescue => e
      Utils.log_error e
      it("hit an error with #{test_case}") { fail Utils.error(e) }
    end
  rescue => e
    Utils.log_error e
    it('hit an error initializing') { fail Utils.error(e) }
  ensure
    Utils.quit_browser @driver
  end
end
