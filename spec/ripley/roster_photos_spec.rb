require_relative '../../util/spec_helper'

describe 'bCourses Roster Photos' do

  include Logging

  test = RipleyTestConfig.new
  test.rosters
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
    @driver = Utils.launch_browser chrome_3rd_party_cookies: true
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasPage.new @driver
    @canvas_api = CanvasAPIPage.new @driver
    @splash_page = RipleySplashPage.new @driver
    @create_course_site_page = RipleyCreateCourseSitePage.new @driver
    @course_add_user_page = RipleyAddUserPage.new @driver
    @roster_photos_page = RipleyRosterPhotosPage.new @driver

    @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
    @site, @teacher = test.configure_single_site(@canvas, @canvas_api, non_teachers)

    @canvas.masquerade_as @teacher
    @create_course_site_page.provision_course_site(@site) unless @site.site_id
    @canvas.publish_course_site @site

    @expected_sids = @site.sections.map { |s| s.enrollments.map { |e| e.user.sis_id } }.flatten.uniq.sort
    @student_count = @site.expected_student_count
    @waitlist_count = @site.expected_wait_list_count
    @total_user_count = @student_count + @waitlist_count
    logger.info "There are #{@student_count} enrolled students and #{@waitlist_count} waitlisted students, for a total of #{@total_user_count}"
    logger.warn 'There are no students on this @site' if @total_user_count.zero?

    @canvas.load_users_page @site
    @canvas.click_find_person_to_add
    non_teachers.each do |user|
      @course_add_user_page.search(user.uid, 'CalNet UID')
      @course_add_user_page.add_user_by_uid(user, @site.sections.first)
    end
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when a Teacher' do

    before(:all) do
      @canvas.masquerade_as(@teacher, @site)
      @roster_photos_page.click_roster_photos_link
    end

    it "shows a teacher all students and waitlisted students on a course site" do
      @roster_photos_page.wait_until(Utils.medium_wait, "Missing: #{@expected_sids - @roster_photos_page.all_sids.sort}.
                                                             Unexpected: #{@roster_photos_page.all_sids.sort - @expected_sids}") do
        @roster_photos_page.all_sids.length == @total_user_count
        @roster_photos_page.all_sids.sort == @expected_sids
      end
    end

    it "shows a teacher actual photos for enrolled students on a course site" do
      @roster_photos_page.wait_for_photos_to_load
      @roster_photos_page.wait_until(Utils.medium_wait, "Expected photo count #{@roster_photos_page.roster_photo_elements.length} to be <= #{@student_count}") do
        @roster_photos_page.roster_photo_elements.length <= @student_count
      end
    end

    it "shows a teacher placeholder photos for waitlisted students on a course site" do
      @roster_photos_page.wait_until(Utils.medium_wait, "Expected placeholder count #{@roster_photos_page.roster_photo_placeholder_elements.length} to be >= #{@waitlist_count}") do
        @roster_photos_page.roster_photo_placeholder_elements.length >= @waitlist_count
      end
    end

    it "shows a teacher all sections by default on a course site" do
      expected_section_codes = @site.sections.map { |section| "#{section.course} #{section.label}" }.sort
      expected_section_codes.prepend('All Sections')
      actual_section_codes = @roster_photos_page.section_options
      expect(actual_section_codes).to eql(expected_section_codes)
    end

    it "allows a teacher to filter by string on a course site" do
      if @student_count > 0 || @waitlist_count > 0
        sid = @roster_photos_page.roster_sid_elements.last.text.gsub('Student ID:', '').strip
        @roster_photos_page.filter_by_string sid
        @roster_photos_page.wait_until(Utils.short_wait) do
          @roster_photos_page.roster_sid_elements.length == 1
          @roster_photos_page.roster_sid_elements.first.text.gsub('Student ID:', '').strip == sid
        end
      end
    end

    it "allows a teacher to filter by section on a course site" do
      @roster_photos_page.filter_by_string ''
      @site.sections.each do |section|
        section_sids = section.enrollments.map { |e| e.user }.map(&:sis_id).sort
        @roster_photos_page.filter_by_section section
        @roster_photos_page.wait_until(Utils.short_wait, "Expected CCN #{section.id} SIDs #{section_sids}, got #{@roster_photos_page.all_sids.sort}") do
          @roster_photos_page.all_sids.sort == section_sids
        end
      end
    end

    it "allows a teacher to download a CSV of the course @site enrollment on a course site" do
      @roster_photos_page.filter_by_section @site.sections.find &:primary
      exported_user_sids = @roster_photos_page.export_roster @site
      logger.info "Exported SIDs #{exported_user_sids}"
      expect(exported_user_sids.sort).to eql(@expected_sids.sort)
    end

    it "shows a teacher a photo print button on a course site" do
      @roster_photos_page.load_embedded_tool @site
      @roster_photos_page.print_roster_link_element.when_visible Utils.medium_wait
    end

    it "shows a teacher a 'no students enrolled' message on a course site" do
      expect(@roster_photos_page.no_students_msg?).to be true if @total_user_count.zero?
    end
  end

  context 'when not a Teacher' do

    [test.canvas_admin, test.lead_ta, test.ta].each do |user|
      it "permits #{user.role} #{user.uid}, #{user.canvas_id} access to the tool" do
        @canvas.masquerade_as(user, @site)
        @roster_photos_page.load_embedded_tool @site
        if @total_user_count.zero?
          @roster_photos_page.no_students_msg_element.when_visible(Utils.short_wait)
        else
          @roster_photos_page.wait_until(Utils.short_wait) { @roster_photos_page.roster_sid_elements.any? }
        end
      end

      it "offers #{user.role} #{user.uid} #{user.canvas_id} a link to the tool in course navigation" do
        @canvas.switch_to_main_content
        expect(@canvas.tool_nav_link(RipleyTool::ROSTER_PHOTOS).exists?).to be true
      end
    end

    [test.observer].each do |user|
      it "denies #{user.role} #{user.uid} access to the tool" do
        @canvas.masquerade_as(user, @site)
        @roster_photos_page.load_embedded_tool @site
        @roster_photos_page.wait_until(Utils.short_wait) do
          @roster_photos_page.no_access_msg? || @roster_photos_page.unauthorized_msg?
        end
      end

      it "offers #{user.role} #{user.uid} no link to the tool in course navigation" do
        @canvas.switch_to_main_content
        expect(@canvas.tool_nav_link(RipleyTool::ROSTER_PHOTOS).exists?).to be false
      end
    end

    [test.designer, test.reader].each do |user|
      it "denies #{user.role} #{user.uid} access to the tool" do
        @canvas.masquerade_as(user, @site)
        @roster_photos_page.load_embedded_tool @site
        @roster_photos_page.wait_until(Utils.short_wait) do
          @roster_photos_page.no_access_msg? || @roster_photos_page.unauthorized_msg?
        end
      end

      it "offers #{user.role} #{user.uid} a link to the tool in course navigation" do
        @canvas.switch_to_main_content
        expect(@canvas.tool_nav_link(RipleyTool::ROSTER_PHOTOS).exists?).to be true
      end
    end

    [test.students.first, test.wait_list_student].each do |user|
      it "denies #{user.role} #{user.uid} #{user.canvas_id} access to the tool" do
        @canvas.masquerade_as user
        @roster_photos_page.hit_embedded_tool_url @site
        @canvas.wait_for_error(@canvas.access_denied_msg_element, @roster_photos_page.unauthorized_msg_element)
      end

      it "offers #{user.role} #{user.uid} #{user.canvas_id} no link to the tool in course navigation" do
        @canvas.switch_to_main_content
        expect(@canvas.tool_nav_link(RipleyTool::ROSTER_PHOTOS).exists?).to be false
      end
    end
  end
end
