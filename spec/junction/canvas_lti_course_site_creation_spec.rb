require_relative '../../util/spec_helper'

describe 'bCourses course site creation' do

  include Logging

  begin
    @driver = Utils.launch_browser
    test_output = Utils.initialize_canvas_test_output(self, ['Term', 'Course Code', 'Instructor', 'Site ID', 'Students', 'Waitlist Students', 'Teachers', 'TAs'])

    @splash_page = Page::CalCentralPages::SplashPage.new @driver
    @cal_net_page = Page::CalNetPage.new @driver
    @academics_api = ApiMyAcademicsPage.new @driver
    @site_creation_page = Page::CalCentralPages::CanvasSiteCreationPage.new @driver
    @create_course_site_page = Page::CalCentralPages::CanvasCreateCourseSitePage.new @driver
    @canvas_page = Page::CanvasPage.new @driver

    links_tested = false

    @canvas_page.log_in(@cal_net_page, Utils.super_admin_username, Utils.super_admin_password)

    test_courses = Utils.load_test_courses.select { |course| course['tests']['create_course_site'] }
    test_courses.each do |course|

      begin
        @course = Course.new course
        @teacher = User.new @course.teachers.first
        sections = @course.sections.map { |section_data| Section.new section_data }
        sections_for_site = sections.select { |section| section.include_in_site }
        site_abbreviation = nil
        enrollment_counts = []

        logger.info "Creating a course site for #{@course.code} in #{@course.term} using the '#{@course.create_site_workflow}' workflow"

        @site_creation_page.choose_course_site(@driver, @course, @teacher, @canvas_page, @create_course_site_page)
        @create_course_site_page.search_for_course(@course, @teacher, sections_for_site)

        unless links_tested

          @create_course_site_page.maintenance_button_element.when_visible Utils.short_wait
          short_maintenance_notice = @create_course_site_page.maintenance_button_element.text
          it ('shows a collapsed maintenance notice') { expect(short_maintenance_notice).to include('From 8 - 9 AM, you may experience delays of up to 10 minutes') }

          @create_course_site_page.maintenance_button

          long_maintenance_notice = @create_course_site_page.maintenance_notice
          it ('shows an expanded maintenance notice') { expect(long_maintenance_notice).to include('bCourses performs scheduled maintenance every day between 8-9AM') }

          bcourses_link_works = @create_course_site_page.verify_external_link(@driver, @create_course_site_page.bcourses_service_element, 'bCourses | Educational Technology Services')
          it ('shows a link to the bCourses service page') { expect(bcourses_link_works).to be true }

          @canvas_page.switch_to_canvas_iframe @driver
          @create_course_site_page.click_need_help

          help_text = @create_course_site_page.help
          it ('shows suggestions for creating sites for courses with multiple sections') { expect(help_text).to include('If you have a course with multiple sections, you will need to decide') }

          links_tested = true

        end

        @create_course_site_page.toggle_course_sections @course

        (@course.create_site_workflow == 'ccn') ?
            expected_section_ids = sections_for_site.map { |section| section.id } :
            expected_section_ids = sections.map { |section| section.id }
        visible_section_ids = @create_course_site_page.course_section_ids(@driver, @course)
        it ("offers all the expected sections for #{@course.term} #{@course.code}") { expect(visible_section_ids.sort!).to eql(expected_section_ids.sort!) }

        @create_course_site_page.select_sections sections_for_site
        @create_course_site_page.click_next

        default_name = @create_course_site_page.site_name_input
        expected_name = @course.title
        it ("shows the default site name #{@course.title}") { expect(default_name).to eql(expected_name) }

        default_abbreviation = @create_course_site_page.site_abbreviation
        expected_abbreviation = @course.code
        it ("shows the default site abbreviation #{@course.code}") { expect(default_abbreviation).to include(expected_abbreviation) }

        site_abbreviation = @create_course_site_page.enter_site_titles @course
        logger.info "Course site abbreviation will be #{site_abbreviation}"

        @create_course_site_page.click_create_site

        site_created = @create_course_site_page.verify_block do
          @canvas_page.wait_until(Utils.long_wait) { @canvas_page.current_url.include? "#{Utils.canvas_base_url}/courses" }
        end
        it ("redirects to the #{@course.term} #{@course.code} course site in Canvas when finished") { expect(site_created).to be true }

        # If site creation failed, don't check the site's enrollment
        if site_created
          @course.site_id = @canvas_page.current_url.delete "#{Utils.canvas_base_url}/courses/"
          logger.info "Canvas course site ID is #{@course.site_id}"

          # Wait for enrollment to finish updating for each user role type and then store the count for each type
          enrollment_counts = @canvas_page.wait_for_enrollment_import(@course, ['Student', 'Waitlist Student', 'Teacher', 'TA'])
        else
          logger.error "Timed out before the #{@course.term} #{@course.code} course site was created, or another error occurred"
        end

      rescue => e
        it("encountered an error for #{@course.code}") { fail }
        logger.error "#{e.message}#{"\n"}#{e.backtrace.join("\n")}"
      ensure
        Utils.add_csv_row(test_output, [@course.term, @course.code, @teacher.uid, @course.site_id, enrollment_counts[0], enrollment_counts[1], enrollment_counts[2], enrollment_counts[3]])
      end
    end
  rescue => e
    it('encountered an error') { fail }
    logger.error "#{e.message}#{"\n"}#{e.backtrace.join("\n")}"
  ensure
    Utils.quit_browser @driver
  end
end
