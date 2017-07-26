require_relative '../../util/spec_helper'

describe 'bCourses Roster Photos' do

  include Logging

  course_id = ENV['COURSE_ID']

  # Load test course data
  test_course_data = Utils.load_bcourses_test_course_data.find { |course| course['tests']['roster_photos'] }
  course = Course.new test_course_data
  course.site_id = course_id
  sections = course.sections.map { |section_data| Section.new section_data }
  sections_for_site = sections.select { |section| section.include_in_site }
  teacher_1 = User.new course.teachers.first

  # Load test user data
  test_user_data = Utils.load_bcourses_test_user_data.select { |user| user['tests']['roster_photos'] }
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
    @splash_page.basic_auth teacher_1.uid
    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.masquerade_as(@driver, teacher_1)

    # Create test course site if necessary
    if course.site_id.nil?
      @create_course_site_page.provision_course_site(@driver, course, teacher_1, sections_for_site)
      @canvas.publish_course_site(@driver, course)
    end

    # Get enrollment totals on site
    @roster_api.get_feed(@driver, course)
    if course_id.nil?
      user_counts = @canvas.wait_for_enrollment_import(course, ['Student', 'Waitlist Student'])
      @student_count = user_counts[0]
      @waitlist_count = user_counts[1]
    else
      @student_count = @canvas.enrollment_count_by_role(course, 'Student')
      @waitlist_count = @canvas.enrollment_count_by_role(course, 'Waitlist Student')
    end
    @canvas.load_users_page course
    @canvas.click_find_person_to_add @driver

    @total_users = @student_count + @waitlist_count
    logger.info "There are #{@student_count} enrolled students and #{@waitlist_count} waitlisted students, for a total of #{@total_users}"
    logger.warn 'There are no students on this site' if @total_users.zero?

    # Add remaining user roles
    [lead_ta, ta, designer, reader, observer].each do |user|
      @course_add_user_page.search(user.uid, 'CalNet UID')
      @course_add_user_page.add_user_by_uid(user, sections_for_site.first)
    end
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when a Teacher' do

    before(:all) do
      @canvas.load_course_site(@driver, course)
      @roster_photos_page.click_roster_photos_link @driver
    end

    it "shows UID #{teacher_1.uid} all students and waitlisted students on #{course.code} course site ID #{course.site_id}" do
      @roster_photos_page.wait_until(Utils.medium_wait) { @roster_photos_page.roster_sid_elements.length == @total_users }
      expect(@roster_photos_page.all_sids.sort).to eql(@roster_api.student_ids(@roster_api.students).sort)
    end

    it "shows UID #{teacher_1.uid} actual photos for enrolled students on #{course.code} course site ID #{course.site_id}" do
      @roster_photos_page.wait_until(Utils.medium_wait) { @roster_photos_page.roster_photo_elements.length <= @student_count }
      expect(@roster_photos_page.roster_photo_elements.any?).to be true
    end

    it "shows UID #{teacher_1.uid} placeholder photos for waitlisted students on #{course.code} course site ID #{course.site_id}" do
      @roster_photos_page.wait_until(Utils.medium_wait) { @roster_photos_page.roster_photo_placeholder_elements.length >= @waitlist_count }
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
      exported_user_count = @roster_photos_page.export_roster course
      expect(exported_user_count).to eql(@total_users)
    end

    it "shows UID #{teacher_1.uid} a photo print button on #{course.code} course site ID #{course.site_id}" do
      expect(@roster_photos_page.print_roster_link?).to be true
    end

    it "shows UID #{teacher_1.uid} a 'no students enrolled' message on #{course.code} course site ID #{course.site_id}" do
      expect(@roster_photos_page.no_students_msg?).to be true if @total_users.zero?
    end
  end

  context 'when not a Teacher' do

    [lead_ta, ta, designer, reader, student, waitlist, observer].each do |user|

      it "allows a course #{user.role} with UID #{user.uid} to access the tool on #{course.code} course site ID #{course.site_id} if permitted to do so" do
        @canvas.masquerade_as(@driver, user, course)
        @canvas.navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/external_tools/#{Utils.canvas_rosters_tool}"

        if ['Lead TA', 'TA'].include? user.role
          @roster_photos_page.switch_to_canvas_iframe @driver
          @total_users.zero? ?
              @roster_photos_page.no_students_msg_element.when_visible(Utils.short_wait) :
              @roster_photos_page.wait_until(Utils.short_wait) { @roster_photos_page.roster_sid_elements.any? }

        elsif %w(Designer Reader Observer).include? user.role
          @roster_photos_page.switch_to_canvas_iframe @driver
          @roster_photos_page.no_access_msg_element.when_visible Utils.short_wait

        else
          @canvas.unauthorized_msg_element.when_visible Utils.short_wait
        end
      end
    end
  end
end
