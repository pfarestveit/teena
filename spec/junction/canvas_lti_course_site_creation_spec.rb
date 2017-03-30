require_relative '../../util/spec_helper'

describe 'bCourses course site creation' do

  include Logging

  links_tested = false
  course_sites = []

  begin
    @driver = Utils.launch_browser
    test_output = Utils.initialize_canvas_test_output(self, ['Term', 'Course', 'Instructor', 'Site ID', 'Teachers', 'TAs', 'Students', 'Waitlist Students'])

    @splash_page = Page::JunctionPages::SplashPage.new @driver
    @cal_net_page = Page::CalNetPage.new @driver
    @academics_api = ApiAcademicsCourseProvisionPage.new @driver
    @rosters_api = ApiAcademicsRosterPage.new @driver
    @site_creation_page = Page::JunctionPages::CanvasSiteCreationPage.new @driver
    @create_course_site_page = Page::JunctionPages::CanvasCreateCourseSitePage.new @driver
    @canvas_page = Page::CanvasPage.new @driver
    @roster_photos_page = Page::JunctionPages::CanvasRostersPage.new @driver
    @course_captures_page = Page::JunctionPages::CanvasCourseCapturesPage.new @driver

    # SITE CREATION

    test_courses = Utils.load_test_courses.select { |course| course['tests']['create_course_site'] }
    test_courses.each do |course|

      begin
        course = Course.new course
        teacher = User.new course.teachers.first
        sections = course.sections.map { |section_data| Section.new section_data }
        sections_for_site = sections.select { |section| section.include_in_site }
        site_abbreviation = nil

        logger.info "Creating a course site for #{course.code} in #{course.term} using the '#{course.create_site_workflow}' workflow"

        # Get academics data, deleting cookies to avoid authentication conflicts before and after
        @driver.manage.delete_all_cookies
        @splash_page.load_page
        @splash_page.basic_auth teacher.uid
        @academics_api.get_feed @driver
        @driver.manage.delete_all_cookies

        # Authenticate in Canvas as needed
        @canvas_page.load_homepage
        @canvas_page.log_in(@cal_net_page, Utils.super_admin_username, Utils.super_admin_password) if @cal_net_page.username?
        @canvas_page.stop_masquerading @driver if @canvas_page.stop_masquerading_link?
        @canvas_page.masquerade_as(@driver, teacher) unless %w(uid ccn).include?(course.create_site_workflow)

        # Navigate to Create a Course Site page
        @canvas_page.load_homepage
        @canvas_page.click_create_site @driver
        @site_creation_page.click_create_course_site
        @create_course_site_page.search_for_course(course, teacher, sections_for_site)

        # Verify page content and external links for one of the courses
        unless links_tested

          @create_course_site_page.maintenance_button_element.when_visible Utils.medium_wait
          short_maintenance_notice = @create_course_site_page.maintenance_button_element.text
          it ('shows a collapsed maintenance notice') { expect(short_maintenance_notice).to include('From 8 - 9 AM, you may experience delays of up to 10 minutes') }

          @create_course_site_page.maintenance_button

          long_maintenance_notice = @create_course_site_page.maintenance_notice
          it ('shows an expanded maintenance notice') { expect(long_maintenance_notice).to include('bCourses performs scheduled maintenance every day between 8-9AM') }

          bcourses_link_works = @create_course_site_page.external_link_valid?(@driver, @create_course_site_page.bcourses_service_element, 'bCourses | Educational Technology Services')
          it ('shows a link to the bCourses service page') { expect(bcourses_link_works).to be true }

          @canvas_page.switch_to_canvas_iframe @driver
          @create_course_site_page.click_need_help

          help_text = @create_course_site_page.help
          it ('shows suggestions for creating sites for courses with multiple sections') { expect(help_text).to include('If you have a course with multiple sections, you will need to decide') }

          links_tested = true

        end

        # Unless admin creates site by CCN list, all sections in the test course and all other semester courses should be shown

        # Check the test course against expectations in the test data file
        @create_course_site_page.expand_available_sections course.code
        (course.create_site_workflow == 'ccn') ?
            expected_section_ids = sections_for_site.map { |section| section.id } :
            expected_section_ids = sections.map { |section| section.id }
        visible_section_ids = @create_course_site_page.course_section_ids(@driver, course)
        it ("offers all the expected sections for #{course.term} #{course.code}") { expect(visible_section_ids.sort!).to eql(expected_section_ids.sort!) }

        unless course.create_site_workflow == 'ccn'

          semester = @academics_api.all_teaching_semesters.find { |semester| @academics_api.semester_name(semester) == course.term }
          semester_courses = @academics_api.semester_courses semester

          # Check all other courses against the academics API
          semester_courses.each do |course_data|
            api_course_code = @academics_api.course_code course_data
            api_course_title = @academics_api.course_title course_data
            ui_course_title = @create_course_site_page.available_sections_course_title api_course_code
            ui_sections_expanded = @create_course_site_page.expand_available_sections api_course_code

            it("shows the right course title for #{api_course_code}") { expect(ui_course_title).to eql(api_course_title) }
            it("shows no blank course title for #{api_course_code}") { expect(ui_course_title.empty?).to be false }
            it("allows the available sections to be expanded for #{api_course_code}") { expect(ui_sections_expanded).to be_truthy }

            # Check each section
            @academics_api.course_sections(course_data).each do |section_data|
              api_section_data = @academics_api.section_data section_data
              ui_section_data = @create_course_site_page.section_data(@driver, api_section_data[:id])

              it("shows the right section labels for #{api_course_code} section #{api_section_data[:id]}") { expect(ui_section_data[:label]).to eql(api_section_data[:label]) }
              it("shows no blank section labels for #{api_course_code} section #{api_section_data[:id]}") { expect(ui_section_data[:label].empty?).to be false }
              it("shows the right section schedules for #{api_course_code} section #{api_section_data[:id]}") { expect(ui_section_data[:schedules]).to eql(api_section_data[:schedules]) }
              it("shows the right section locations for #{api_course_code} section #{api_section_data[:id]}") { expect(ui_section_data[:locations]).to eql(api_section_data[:locations]) }
            end

            ui_sections_collapsed = @create_course_site_page.collapse_available_sections api_course_code
            it("allows the available sections to be collapsed for #{api_course_code}") { expect(ui_sections_collapsed).to be_truthy }
          end
        end

        # Choose sections and create site
        @create_course_site_page.expand_available_sections course.code
        @create_course_site_page.select_sections sections_for_site
        @create_course_site_page.click_next

        default_name = @create_course_site_page.site_name_input
        expected_name = "#{course.title} (#{course.term})"
        it ("shows the default site name #{course.title}") { expect(default_name).to eql(expected_name) }

        default_abbreviation = @create_course_site_page.site_abbreviation
        expected_abbreviation = course.code
        it ("shows the default site abbreviation #{course.code}") { expect(default_abbreviation).to include(expected_abbreviation) }

        site_abbreviation = @create_course_site_page.enter_site_titles course
        logger.info "Course site abbreviation will be #{site_abbreviation}"

        @create_course_site_page.click_create_site

        # Wait for redirect to new Canvas course site
        site_created = @create_course_site_page.verify_block do
          @canvas_page.wait_until(Utils.long_wait) { @canvas_page.current_url.include? "#{Utils.canvas_base_url}/courses" }
        end
        it ("redirects to the #{course.term} #{course.code} course site in Canvas when finished") { expect(site_created).to be true }

        # If site creation succeeded, store the site info
        if site_created
          course.site_id = @canvas_page.current_url.delete "#{Utils.canvas_base_url}/courses/"
          logger.info "Canvas course site ID is #{course.site_id}"
          course_sites << {course: course, sections: sections_for_site, teacher: teacher}
        else
          logger.error "Timed out before the #{course.term} #{course.code} course site was created, or another error occurred"
        end

      rescue => e
        it("encountered an error creating the course site for #{course.code}") { fail }
        logger.error "#{e.message}#{"\n"}#{e.backtrace.join("\n")}"
      end
    end

    # COURSE SITE CONTENT - MEMBERSHIP, ROSTER PHOTOS, COURSE CAPTURES

    if course_sites.any?
      course_sites.each do |site|

        begin
          course = site[:course]
          sections = site[:sections]
          section_ids = sections.map { |s| s.id }
          teacher = site[:teacher]
          expected_enrollment_counts = []
          actual_enrollment_counts = []

          logger.info "Verifying content of #{course.term} #{course.code} site ID #{course.site_id}"

          # Get academics and roster data, while avoiding authenticated session conflicts
          @driver.manage.delete_all_cookies
          @splash_page.load_page
          @splash_page.basic_auth teacher.uid
          @academics_api.get_feed @driver
          @rosters_api.get_feed(@driver, course)
          @canvas_page.load_homepage
          @canvas_page.log_in(@cal_net_page, Utils.super_admin_username, Utils.super_admin_password) if @cal_net_page.username?
          @canvas_page.masquerade_as(@driver, teacher, course)

          # MEMBERSHIP - check that course site user counts match expectations for each role

          api_semester = @academics_api.all_teaching_semesters.find { |s| s['name'] == course.term }
          api_course = @academics_api.semester_courses(api_semester).find { |c| c['course_code'] == course.code }
          api_sections = @academics_api.course_sections(api_course).select { |s| section_ids.include? s['ccn'] }

          expected_teacher_count = @academics_api.course_section_teachers(api_sections).length
          expected_ta_count = @academics_api.course_section_tas(api_sections).length
          expected_student_count = @rosters_api.enrolled_students.length
          expected_waitlist_count = @rosters_api.waitlisted_students.length

          expected_enrollment_counts = [expected_student_count, expected_waitlist_count, expected_teacher_count, expected_ta_count]
          actual_enrollment_counts = @canvas_page.wait_for_enrollment_import(course, ['Student', 'Waitlist Student', 'Teacher', 'TA'])
          it("results in the right course site membership for #{course.term} #{course.code} site ID #{course.site_id}") { expect(actual_enrollment_counts).to eql(expected_enrollment_counts) }

          # ROSTER PHOTOS - check that roster photos tool shows the right sections

          has_roster_photos_link = @roster_photos_page.roster_photos_link?
          it ("shows a Roster Photos tool link in course site navigation for #{course.term} #{course.code} site ID #{course.site_id}") { expect(has_roster_photos_link).to be true }

          @roster_photos_page.load_embedded_tool(@driver, course)
          @roster_photos_page.wait_for_load_and_click_js @roster_photos_page.section_select_element

          expected_sections_on_site = (sections.map { |section| "#{section.course} #{section.label}" })
          actual_sections_on_site = @roster_photos_page.section_options.length
          it("shows the right section list on the Roster Photos tool for #{course.term} #{course.code} site ID #{course.site_id}") { expect(actual_sections_on_site).to eql(expected_sections_on_site.sort) }

          # COURSE CAPTURE - check that course captures tool is not added automatically

          @canvas_page.load_course_site(@driver, course)
          has_course_captures_link = @course_captures_page.course_captures_link?
          it ("shows no Course Captures tool link in course site navigation for #{course.term} #{course.code} site ID #{course.site_id}") { expect(has_course_captures_link).to be false }

          @canvas_page.stop_masquerading @driver
        rescue => e
          it("encountered an error verifying the course site for #{course.code}") { fail }
          logger.error "#{e.message}#{"\n"}#{e.backtrace.join("\n")}"
        ensure
          Utils.add_csv_row(test_output, [course.term, course.code, teacher.uid, course.site_id, expected_teacher_count,
                                          expected_ta_count, expected_student_count, expected_waitlist_count])
          @canvas_page.delete_course(@driver, course)
        end
      end
    end

  rescue => e
    it('encountered an error') { fail }
    logger.error "#{e.message}#{"\n"}#{e.backtrace.join("\n")}"
  ensure
    Utils.quit_browser @driver
  end
end
