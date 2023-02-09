require_relative '../../util/spec_helper'

standalone = ENV['STANDALONE']

describe 'bCourses Roster Photos' do

  include Logging

  test = RipleyTestConfig.new
  test.rosters
  course = test.courses.first
  sections = test.set_course_sections(course).select &:include_in_site
  teacher = test.set_sis_teacher course
  non_teachers = [
    test.lead_ta,
    test.ta,
    test.designer,
    test.reader,
    test.observer,
    test.students.first,
    test.wait_list_student
  ]

  before(:all) do
    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasPage.new @driver
    @splash_page = RipleySplashPage.new @driver
    @create_course_site_page = RipleyCreateCourseSitePage.new @driver
    @course_add_user_page = RipleyAddUserPage.new @driver
    @roster_photos_page = RipleyRosterPhotosPage.new @driver
    @roster_api = ApiAcademicsRosterPage.new @driver

    @splash_page.load_page
    @splash_page.basic_auth(teacher.uid, @cal_net)
    unless standalone
      @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
      @canvas.masquerade_as teacher
    end

    @create_course_site_page.provision_course_site(course, teacher, sections, {standalone: standalone})
    @create_course_site_page.wait_for_standalone_site_id(course, teacher, @splash_page) if standalone
    @canvas.publish_course_site course unless standalone

    # TODO - replace with data collection from Nessie
    @roster_api.get_feed course
    @expected_sids = @roster_api.student_ids(@roster_api.students).sort

    @student_count = @roster_api.enrolled_students.length
    @waitlist_count = @roster_api.waitlist_only_students.length
    @total_user_count = @student_count + @waitlist_count
    logger.info "There are #{@student_count} enrolled students and #{@waitlist_count} waitlisted students, for a total of #{@total_user_count}"
    logger.warn 'There are no students on this site' if @total_user_count.zero?

    unless standalone
      @canvas.load_users_page course
      @canvas.click_find_person_to_add
      non_teachers.each do |user|
        @course_add_user_page.search(user.uid, 'CalNet UID')
        @course_add_user_page.add_user_by_uid(user, sections.first)
      end
    end
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when a Teacher' do

    before(:all) do
      if standalone
        @roster_photos_page.load_standalone_tool course
      else
        @canvas.load_course_site course
        @roster_photos_page.click_roster_photos_link
      end
    end

    it "shows UID #{teacher.uid} all students and waitlisted students on #{course.code} course site ID #{course.site_id}" do
      @roster_photos_page.wait_until(Utils.medium_wait, "Missing: #{@expected_sids - @roster_photos_page.all_sids.sort}.
                                                             Unexpected: #{@roster_photos_page.all_sids.sort - @expected_sids}.
                                                             Expected #{@expected_sids} but got #{@roster_photos_page.all_sids.sort}") do
        @roster_photos_page.all_sids.length == @total_user_count
        @roster_photos_page.all_sids.sort == @expected_sids
      end
    end

    it "shows UID #{teacher.uid} actual photos for enrolled students on #{course.code} course site ID #{course.site_id}" do
      @roster_photos_page.wait_until(Utils.medium_wait, "Expected photo count #{@roster_photos_page.roster_photo_elements.length} to be <= #{@student_count}") do
        @roster_photos_page.roster_photo_elements.length <= @student_count
      end
      expect(@roster_photos_page.roster_photo_elements.any?).to be true
    end

    it "shows UID #{teacher.uid} placeholder photos for waitlisted students on #{course.code} course site ID #{course.site_id}" do
      @roster_photos_page.wait_until(Utils.medium_wait, "Expected placeholder count #{@roster_photos_page.roster_photo_placeholder_elements.length} to be >= #{@waitlist_count}") do
        @roster_photos_page.roster_photo_placeholder_elements.length >= @waitlist_count
      end
    end

    it "shows UID #{teacher.uid} all sections by default on #{course.code} course site ID #{course.site_id}" do
      expected_section_codes = (sections.map { |section| "#{section.course} #{section.label}" }) << 'All sections'
      actual_section_codes = @roster_photos_page.section_select_options
      expect(actual_section_codes).to eql(expected_section_codes.sort)
    end

    it "allows UID #{teacher.uid} to filter by string on #{course.code} course site ID #{course.site_id}" do
      if @student_count > 0 || @waitlist_count > 0
        sid = @roster_photos_page.roster_sid_elements.last.text.gsub('Student ID:', '').strip
        @roster_photos_page.filter_by_string sid
        @roster_photos_page.wait_until(Utils.short_wait) do
          @roster_photos_page.roster_sid_elements.length == 1
          @roster_photos_page.roster_sid_elements.first.text.gsub('Student ID:', '').strip == sid
        end
      end
    end

    sections.each do |section|
      it "allows UID #{teacher.uid} to filter by section #{section.label} on #{course.code} course site ID #{course.site_id}" do
        section_students = @roster_api.section_students(section.id)
        logger.debug "Expecting #{section_students.length} students in section #{section.label}"
        @roster_photos_page.filter_by_string ''
        @roster_photos_page.filter_by_section section
        @roster_photos_page.wait_until(Utils.short_wait) { @roster_photos_page.all_sids.sort == @roster_api.student_ids(section_students).sort }
      end
    end

    it "allows UID #{teacher.uid} to download a CSV of the course site enrollment on #{course.code} course site ID #{course.site_id}" do
      exported_user_sids = @roster_photos_page.export_roster course
      logger.info "Exported SIDs #{exported_user_sids}"
      expect(exported_user_sids.sort).to eql(@expected_sids)
    end

    it "shows UID #{teacher.uid} a photo print button on #{course.code} course site ID #{course.site_id}" do
      standalone ? @roster_photos_page.load_standalone_tool(course) : @roster_photos_page.load_embedded_tool(course)
      @roster_photos_page.print_roster_link_element.when_visible Utils.medium_wait
    end

    it "shows UID #{teacher.uid} a 'no students enrolled' message on #{course.code} course site ID #{course.site_id}" do
      expect(@roster_photos_page.no_students_msg?).to be true if @total_user_count.zero?
    end
  end

  unless standalone

    context 'when not a Teacher' do

      [test.lead_ta, test.ta].each do |user|
        it "permits #{user.role} #{user.uid} access to the tool" do
          @canvas.masquerade_as(user, course)
          @roster_photos_page.load_embedded_tool course
          if @total_user_count.zero?
            @roster_photos_page.no_students_msg_element.when_visible(Utils.short_wait)
          else
            @roster_photos_page.wait_until(Utils.short_wait) { @roster_photos_page.roster_sid_elements.any? }
          end
        end
      end

      [test.reader, test.designer].each do |user|
        it "denies #{user.role} #{user.uid} access to the tool" do
          @canvas.masquerade_as(user, course)
          @roster_photos_page.load_embedded_tool course
          @roster_photos_page.no_access_msg_element.when_visible Utils.short_wait
        end
      end

      [test.observer, test.students.first, test.wait_list_student].each do |user|
        it "denies #{user.role} #{user.uid} access to the tool" do
          @canvas.masquerade_as(user, course)
          @roster_photos_page.hit_embedded_tool_url course
          @canvas.wait_for_error(@canvas.access_denied_msg_element, @roster_photos_page.no_access_msg_element)
        end
      end
    end
  end
end
