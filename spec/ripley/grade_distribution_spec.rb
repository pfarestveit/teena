require_relative '../../util/spec_helper'

describe 'The Grade Distribution tool' do

  include Logging

  test = RipleyTestConfig.new
  test.grade_distribution

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

    test.course_sites.each do |site|

      begin
        @canvas.stop_masquerading

        section_ids = @canvas_api.get_course_site_sis_section_ids site.site_id
        test.get_existing_site_data(site, section_ids)
        instructor = RipleyUtils.get_primary_instructor(site) || site.course.teachers.first
        test_case = "#{site.course.term.name} #{site.course.code} site #{site.site_id}"
        RipleyUtils.get_completed_enrollments site.course
        enrollment_count = site.sections.map { |s| s.enrollments.map { |e| e.user.uid } }.flatten.uniq.length
        logger.info "#{test_case} has #{enrollment_count} students"
        @canvas.set_canvas_ids [instructor]
        @canvas.add_ripley_tools(RipleyTool::TOOLS.reject(&:account), site)
        @canvas.add_ripley_tools [RipleyTool::ADD_USER]

        @canvas.masquerade_as(instructor, site)
        @newt.load_embedded_tool site

        begin
          if enrollment_count < 150
            user_blocked = @newt.verify_block({ screenshot: true, screenshot_name: site.site_id }) do
              @newt.no_grade_dist_msg_element.when_visible Utils.medium_wait
            end
            it("denies low enrollment #{test_case} Teacher UID #{instructor.uid} access to the tool") { expect(user_blocked).to be true }

          else
            if site.course.teachers.length == 1

              shows_demographics = @newt.verify_block({ screenshot: true, screenshot_name: site.site_id }) do
                @newt.expand_demographics_table
              end
              it("offers demographics default data and table on #{test_case}") do
                expect(shows_demographics).to be true
              end

              shows_prior_enrollments = @newt.verify_block({ screenshot: true, screenshot_name: site.site_id }) do
                @newt.expand_prior_enrollment_table
              end
              it("offers prior enrollment default data and table on #{test_case}") do
                expect(shows_prior_enrollments).to be true
              end
            else
              user_blocked = @newt.verify_block({ screenshot: true, screenshot_name: site.site_id }) do
                @newt.no_grade_dist_msg_element.when_visible Utils.medium_wait
              end
              it("denies #{test_case} Teacher UID #{instructor.uid} access to the tool") { expect(user_blocked).to be true }
            end
          end
        rescue => e
          Utils.log_error e
          it("hit an error checking the highcharts graphs with #{test_case}") { fail Utils.error(e) }
        end

        if site == test.course_sites.last
          primary_sec = site.sections.find &:primary
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
