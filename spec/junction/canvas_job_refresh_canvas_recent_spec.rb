require_relative '../../util/spec_helper'

describe 'bCourses recent enrollment updates' do

  include Logging

  begin

    @driver = Utils.launch_browser
    @splash_page = Page::JunctionPages::SplashPage.new @driver
    @cal_net_page = Page::CalNetPage.new @driver
    @ccadmin_page = CCAdminPage.new @driver
    @create_course_site_page = Page::JunctionPages::CanvasCreateCourseSitePage.new @driver
    @canvas_page = Page::CanvasPage.new @driver

    test_data = JunctionUtils.load_junction_test_course_data.select { |course| course['tests']['recent_update'] }
    roles = ['Teacher', 'Lead TA', 'TA', 'Student', 'Waitlist Student']
    last_sis_update = JunctionUtils.sis_update_date
    @admin = User.new username: Utils.super_admin_username, canvas_id: Utils.super_admin_canvas_id
    sites_to_verify = []

    course_sites = test_data.map do |data|
      course = Course.new data
      course.sections.map! { |h| Section.new h }
      course.teachers.map! { |h| User.new h }
      {course: course, user_data: []}
    end

    logger.debug "There are #{course_sites.length} test courses"
    @canvas_page.log_in(@cal_net_page, Utils.super_admin_username, Utils.super_admin_password)
    @ccadmin_page.load_page(@cal_net_page, Utils.super_admin_username, Utils.super_admin_password)
    @ccadmin_page.edit_canvas_sync last_sis_update

    course_sites.each do |site|
      begin
        course = site[:course]
        @create_course_site_page.provision_course_site(@driver, course, @admin, course.sections, {admin: true})
        @canvas_page.set_course_sis_id course
        @canvas_page.set_section_sis_ids course
        @canvas_page.load_users_page course
        @canvas_page.wait_for_enrollment_import(course, roles)
        initial_users_with_sections = @canvas_page.get_users_with_sections course
        initial_enrollment_data = initial_users_with_sections.map do |u|
          {
              sid: u[:user].sis_id,
              section_id: u[:section].sis_id,
              role: u[:user].role
          }
        end
        site.merge!({enrollment: initial_enrollment_data})

        student_enrollments = initial_users_with_sections.select { |h| h[:user].role == 'student' }
        waitlisted_enrollments = initial_users_with_sections.select { |h| h[:user].role == 'Waitlist Student' }
        ta_enrollments = initial_users_with_sections.select { |h| h[:user].role == 'ta' }
        lead_ta_enrollments = initial_users_with_sections.select { |h| h[:user].role == 'Lead TA' }
        teacher_enrollments = initial_users_with_sections.select { |h| h[:user].role == 'teacher' }

        csv = File.join(Utils.initialize_test_output_dir, "enrollments-#{course.code}.csv")
        CSV.open(csv, 'wb') { |heading| heading << %w(course_id user_id role section_id status) }

        students_to_delete = student_enrollments[0..9].map &:dup
        waitlists_to_delete = waitlisted_enrollments[0..9].map &:dup
        tas_to_delete = ta_enrollments[0..9].map &:dup
        lead_tas_to_delete = lead_ta_enrollments[0..1].map &:dup
        teachers_to_delete = teacher_enrollments[0..1].map &:dup
        students_to_convert = student_enrollments[10..19].map &:dup

        deletes = [students_to_delete + students_to_convert + waitlists_to_delete + tas_to_delete + lead_tas_to_delete + teachers_to_delete]
        deletes.flatten!
        logger.debug "#{deletes}"
        deletes.each { |h| h[:user].status = 'deleted' }
        deletes.each do |delete|
          user = delete[:user]
          section = delete[:section]
          Utils.add_csv_row(csv, [course.sis_id, user.sis_id, user.role, section.sis_id, user.status])
        end

        logger.debug "#{students_to_convert}"
        students_to_convert.each do |h|
          h[:user].role = 'Waitlist Student'
          h[:user].status = 'active'
        end
        students_to_convert.each do |converts|
          user = converts[:user]
          section = converts[:section]
          Utils.add_csv_row(csv, [course.sis_id, user.sis_id, user.role, section.sis_id, user.status])
        end

        #### TODO add manual memberships of all roles
        @canvas_page.upload_sis_imports([csv], [])
        sites_to_verify << site
      rescue => e
        Utils.log_error e
        it("hit an error in the test for #{site[:course].code}") { fail }
      end
    end

    @canvas_page.log_out(@driver, @cal_net_page)
    @canvas_page.load_homepage
    @cal_net_page.prompt_for_action 'RUN EXPORT AND REFRESH SCRIPTS MANUALLY'
    @cal_net_page.wait_for_manual_login

    #########################################
    ############  MANUAL STEPS  #############
    #########################################

    # 1. Run export_cached_csv_enrollments.sh
    # 2. Run refresh_canvas_recent.sh
    # 3. Log in manually to resume tests

    sites_to_verify.each do |site|
      course = site[:course]
      @canvas_page.load_course_site course
      updated_users_with_sections = @canvas_page.get_users_with_sections course
      updated_enrollment_data = updated_users_with_sections.map do |u|
        {
            sid: u[:user].sis_id,
            section_id: u[:section].sis_id,
            role: u[:user].role
        }
      end
      logger.debug "Original site membership: #{site[:enrollment]}"
      logger.debug "Updated site membership: #{updated_enrollment_data}"
      it("updates the enrollment for site ID #{site[:course].site_id}") do
        expect(updated_enrollment_data & site[:enrollment]).to eql(site[:enrollment])
      end
    end
  end
end
