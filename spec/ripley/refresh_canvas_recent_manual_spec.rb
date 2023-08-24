unless ENV['STANDALONE']

  require_relative '../../util/spec_helper'

  # Prior to running, set Junction recent_refresh_cutoff_days as required, same as Teena's cutoff setting

  describe 'bCourses recent enrollment updates' do

    include Logging

    begin

      @test = RipleyTestConfig.new
      @test.refresh_canvas_recent
      @driver = Utils.launch_browser
      @splash_page = Page::JunctionPages::SplashPage.new @driver
      @cal_net = Page::CalNetPage.new @driver
      @create_course_site = Page::JunctionPages::CanvasCreateCourseSitePage.new @driver
      @canvas = Page::CanvasPage.new @driver
      @canvas_api = CanvasAPIPage.new @driver

      roles = ['Teacher', 'Lead TA', 'TA', 'Student', 'Waitlist Student']
      sites_to_verify = []

      logger.debug "There are #{@test.course_sites.length} test courses"
      @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)

      @test.course_sites.each do |site|
        begin
          section_ids = @canvas_api.get_course_site_sis_section_ids site.site_id
          @test.get_existing_site_data(site, section_ids)
          course = site.course
          course.site_id = site.site_id

          if site.site_id
            @canvas.load_course_site site
          else
            # TODO create course site
            # TODO @canvas.publish_course_site site
          end
          @canvas.set_course_sis_id course
          @canvas.set_section_sis_ids course
          @canvas.load_users_page course
          @canvas.wait_for_enrollment_import(course, roles)

          initial_users_with_sections = []
          course.sections.each do |section|
            initial_users_with_sections << @canvas.get_users_with_sections(course, section)
          end
          initial_users_with_sections.flatten!
          initial_enrollment_data = initial_users_with_sections.map do |u|
            {
              sid: u[:user].sis_id,
              section_id: u[:section].sis_id,
              role: u[:user].role
            }
          end
          sites_to_verify << { site: site, enrollment_data: initial_enrollment_data }

          student_enrollments = initial_users_with_sections.select { |h| h[:user].role == 'student' }
          waitlisted_enrollments = initial_users_with_sections.select { |h| h[:user].role == 'Waitlist Student' }
          ta_enrollments = initial_users_with_sections.select { |h| h[:user].role == 'ta' }
          lead_ta_enrollments = initial_users_with_sections.select { |h| h[:user].role == 'Lead TA' }
          teacher_enrollments = initial_users_with_sections.select { |h| h[:user].role == 'teacher' }

          csv = File.join(Utils.initialize_test_output_dir, "enrollments-#{course.code}.csv")
          CSV.open(csv, 'wb') { |heading| heading << %w(course_id user_id role section_id status) }

          students_to_delete = student_enrollments[0..9].map &:dup
          waitlists_to_delete = waitlisted_enrollments[0..9].map &:dup
          tas_to_delete = ta_enrollments[0..0].map &:dup
          lead_tas_to_delete = lead_ta_enrollments[0..1].map &:dup
          teachers_to_delete = teacher_enrollments[0..0].map &:dup
          students_to_convert = student_enrollments[10..19].map &:dup

          deletes = [students_to_delete + students_to_convert + waitlists_to_delete + tas_to_delete + lead_tas_to_delete + teachers_to_delete]
          deletes.flatten!
          logger.debug "#{deletes.map { |h| {sid: h[:user].sis_id, role: h[:user].role} }}"
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

          # For one of the deletions, add a different user role manually to ensure that the manual role persists after an enrollment update
          if lead_tas_to_delete[0] && course.sections.length == 1
            teacher = lead_tas_to_delete[0].dup
            teacher[:user].role = 'Teacher'
            @canvas.add_users(course, [teacher[:user]])
            initial_enrollment_data << {sid: teacher[:user].sis_id, role: teacher[:user].role.downcase, section_id: teacher[:section].sis_id}
          end

          @canvas.upload_sis_imports([csv])
          sites_to_verify << site
        rescue => e
          Utils.log_error e
          it("hit an error in the test for #{site[:course].code}") { fail }
        end
      end

      @canvas.log_out @cal_net
      @canvas.load_homepage
      RipleyUtils.set_last_sync_timestamps
      @cal_net.prompt_for_action 'RUN EXPORT AND REFRESH SCRIPTS MANUALLY'
      @cal_net.wait_for_manual_login 9000

      #########################################
      ############  MANUAL STEPS  #############
      #########################################

      # 1. Run job Export Term Enrollments
      # 2. Run Junction data_loch_recent_refresh
      # 3. Run Nessie RefreshSisedoSchemaIncremental
      # 4. Run job Bcourses Refresh Incremental
      # 5. Log in manually to resume tests

      sites_to_verify.each do |site|
        course = site[:site].course
        @canvas.load_course_site course
        updated_users_with_sections = @canvas.get_users_with_sections course
        updated_enrollment_data = updated_users_with_sections.map do |u|
          {
            sid: u[:user].sis_id,
            section_id: u[:section].sis_id,
            role: u[:user].role
          }
        end
        logger.debug "Original site membership: #{site[:enrollment_data]}"
        logger.debug "Updated site membership: #{updated_enrollment_data}"
        logger.debug "Current less original: #{updated_enrollment_data - site[:enrollment_data]}"
        logger.debug "Original less current: #{site[:enrollment_data] - updated_enrollment_data}"
        it("updates the enrollment for site ID #{site[:course].site_id} with no unexpected memberships") do
          expect(updated_enrollment_data - site[:enrollment_data]).to be_empty
        end
        it("updates the enrollment for site ID #{site[:course].site_id} with no missing memberships") do
          expect(site[:enrollment_data] - updated_enrollment_data).to be_empty
        end
      end
    end
  end
end
