require_relative '../../util/spec_helper'

describe 'bCourses Roster Photos' do

  include Logging

  # Load test course data
  test_course_data = JunctionUtils.load_junction_test_course_data.find { |course| course['tests']['roster_photos'] }
  course = Course.new test_course_data
  sections = course.sections.map { |section_data| Section.new section_data }
  sections_for_site = sections.select { |section| section.include_in_site }
  teacher_1 = User.new course.teachers.first

  # Load test user data
  test_user_data = JunctionUtils.load_junction_test_user_data.select { |user| user['tests']['roster_photos'] }
  lead_ta = User.new test_user_data.find { |data| data['role'] == 'Lead TA' }
  ta = User.new test_user_data.find { |data| data['role'] == 'TA' }
  designer = User.new test_user_data.find { |data| data['role'] == 'Designer' }
  observer = User.new test_user_data.find { |data| data['role'] == 'Observer' }
  reader = User.new test_user_data.find { |data| data['role'] == 'Reader' }
  student = User.new test_user_data.find { |data| data['role'] == 'Student' }
  waitlist = User.new test_user_data.find { |data| data['role'] == 'Waitlist Student' }

  before(:all) do
    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasPage.new @driver
    @roster_api = ApiAcademicsRosterPage.new @driver
    @splash_page = Page::JunctionPages::SplashPage.new @driver
    @create_course_site_page = Page::JunctionPages::CanvasCreateCourseSitePage.new @driver
    @course_add_user_page = Page::JunctionPages::CanvasCourseAddUserPage.new @driver
    @roster_photos_page = Page::JunctionPages::CanvasRostersPage.new @driver

    # Authenticate
    @splash_page.load_page
    @splash_page.basic_auth(teacher_1.uid, @cal_net)
    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.masquerade_as teacher_1

    # Create test course site
    @create_course_site_page.provision_course_site(@driver, course, teacher_1, sections_for_site)
    @canvas.publish_course_site course

    # Get enrollment totals on site
    @roster_api.get_feed(@driver, course)
    user_counts = @canvas.wait_for_enrollment_import(course, ['Student', 'Waitlist Student'])
    @student_count = user_counts[0][:count]
    @waitlist_count = user_counts[1][:count]
    @expected_sids = @roster_api.student_ids(@roster_api.students).sort
    @canvas.load_users_page course
    @canvas.click_find_person_to_add @driver

    @total_user_count = @student_count + @waitlist_count
    logger.info "There are #{@student_count} enrolled students and #{@waitlist_count} waitlisted students, for a total of #{@total_user_count}"
    logger.warn 'There are no students on this site' if @total_user_count.zero?

    # Add remaining user roles
    [lead_ta, ta, designer, reader, observer, student, waitlist].each do |user|
      @course_add_user_page.search(user.uid, 'CalNet UID')
      @course_add_user_page.add_user_by_uid(user, sections_for_site.first)
    end
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when a Teacher' do

    before(:all) do
      @canvas.load_course_site course
      @roster_photos_page.click_roster_photos_link @driver
    end

    it "shows UID #{teacher_1.uid} all students and waitlisted students on #{course.code} course site ID #{course.site_id}" do
      @roster_photos_page.wait_until(Utils.medium_wait, "Expected but not present: #{@expected_sids - @roster_photos_page.all_sids.sort}. Present but not expected: #{@roster_photos_page.all_sids.sort - @expected_sids}.
      Expected #{@expected_sids} but got #{@roster_photos_page.all_sids.sort}") do
        @roster_photos_page.all_sids.length == @total_user_count
        @roster_photos_page.all_sids.sort == @expected_sids
      end
    end

    it "shows UID #{teacher_1.uid} actual photos for enrolled students on #{course.code} course site ID #{course.site_id}" do
      @roster_photos_page.wait_until(Utils.medium_wait, "Expected photo count #{@roster_photos_page.roster_photo_elements.length} to be >= #{@student_count}") do
        @roster_photos_page.roster_photo_elements.length <= @student_count
      end
      expect(@roster_photos_page.roster_photo_elements.any?).to be true
    end

    it "shows UID #{teacher_1.uid} placeholder photos for waitlisted students on #{course.code} course site ID #{course.site_id}" do
      @roster_photos_page.wait_until(Utils.medium_wait, "Expected placeholder count #{@roster_photos_page.roster_photo_placeholder_elements.length} to be >= #{@waitlist_count}") do
        @roster_photos_page.roster_photo_placeholder_elements.length >= @waitlist_count
      end
    end

    it "shows UID #{teacher_1.uid} all sections by default on #{course.code} course site ID #{course.site_id}" do
      expected_section_codes = (sections_for_site.map { |section| "#{section.course} #{section.label}" }) << 'All Sections'
      actual_section_codes = @roster_photos_page.section_select_options
      expect(actual_section_codes).to eql(expected_section_codes.sort)
    end

    it "allows UID #{teacher_1.uid} to filter by string on #{course.code} course site ID #{course.site_id}" do
      if @student_count > 0 || @waitlist_count > 0
        sid = @roster_photos_page.roster_sid_elements.last.text
        @roster_photos_page.filter_by_string sid
        @roster_photos_page.wait_until(Utils.short_wait) do
          @roster_photos_page.roster_sid_elements.length == 1
          @roster_photos_page.roster_sid_elements.first.text == sid
        end
      end
    end

    sections_for_site.each do |section|
      it "allows UID #{teacher_1.uid} to filter by section #{section.label} on #{course.code} course site ID #{course.site_id}" do
        section_students = @roster_api.section_students("#{section.course} #{section.label}")
        logger.debug "Expecting #{section_students.length} students in section #{section.label}"
        @roster_photos_page.filter_by_string ''
        @roster_photos_page.filter_by_section section
        @roster_photos_page.wait_until(Utils.short_wait) { @roster_photos_page.all_sids.sort == @roster_api.student_ids(section_students).sort }
      end
    end

    it "allows UID #{teacher_1.uid} to download a CSV of the course site enrollment on #{course.code} course site ID #{course.site_id}" do
      exported_user_sids = @roster_photos_page.export_roster course
      logger.info "Exported SIDs #{exported_user_sids}"
      expect(exported_user_sids.sort).to eql(@expected_sids)
    end

    it "shows UID #{teacher_1.uid} a photo print button on #{course.code} course site ID #{course.site_id}" do
      @roster_photos_page.load_embedded_tool(@driver, course)
      @roster_photos_page.print_roster_link_element.when_visible Utils.medium_wait
    end

    it "shows UID #{teacher_1.uid} a 'no students enrolled' message on #{course.code} course site ID #{course.site_id}" do
      expect(@roster_photos_page.no_students_msg?).to be true if @total_user_count.zero?
    end
  end

  context 'when not a Teacher' do

    [lead_ta, ta, designer, reader, student, waitlist, observer].each do |user|

      it "allows a course #{user.role} with UID #{user.uid} to access the tool on #{course.code} course site ID #{course.site_id} if permitted to do so" do
        @canvas.masquerade_as user, course
        @canvas.navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/external_tools/#{JunctionUtils.canvas_rosters_tool}"

        if ['Lead TA', 'TA'].include? user.role
          @roster_photos_page.switch_to_canvas_iframe
          @total_user_count.zero? ?
              @roster_photos_page.no_students_msg_element.when_visible(Utils.short_wait) :
              @roster_photos_page.wait_until(Utils.short_wait) { @roster_photos_page.roster_sid_elements.any? }
        elsif ['Designer', 'Reader', 'Observer', 'Student', 'Waitlist Student'].include? user.role
          @roster_photos_page.switch_to_canvas_iframe
          @roster_photos_page.no_access_msg_element.when_visible Utils.short_wait
        else
          logger.error "Unknown user role '#{user.role}'"
          fail
        end
      end
    end
  end
end
