require_relative '../../util/spec_helper'

describe 'bCourses course site creation' do

  standalone = ENV['STANDALONE']

  include Logging

  test = JunctionTestConfig.new
  test.course_site_creation
  links_tested = false

  begin
    @driver = Utils.launch_browser

    @splash_page = Page::JunctionPages::SplashPage.new @driver
    @cal_net_page = Page::CalNetPage.new @driver
    @site_creation_page = Page::JunctionPages::CanvasSiteCreationPage.new @driver
    @create_course_site_page = Page::JunctionPages::CanvasCreateCourseSitePage.new @driver
    @canvas_page = Page::CanvasPage.new @driver
    @roster_photos_page = Page::JunctionPages::CanvasRostersPage.new @driver
    @course_captures_page = Page::JunctionPages::CanvasCourseCapturesPage.new @driver

    all_test_courses = []
    sites_created = []
    sites_to_create = []

    # OBTAIN SIS DATA FOR ALL TEST COURSES

    test.courses.each do |course|

      begin
        sections = test.set_course_sections course

        test_course = {
            course: course,
            teacher: test.set_sis_teacher(course),
            sections: sections,
            sections_for_site: sections.select(&:include_in_site),
            site_abbreviation: nil,
            academic_data: ApiAcademicsCourseProvisionPage.new(@driver),
            roster_data: ApiAcademicsRosterPage.new(@driver)
        }

        @splash_page.load_page
        @splash_page.basic_auth(test_course[:teacher].uid, @cal_net_page)
        test_course[:academic_data].get_feed @driver
        all_test_courses << test_course

        # If a test site was already created for the course today, then skip the site creation steps and just verify the site content
        if test_course[:course].site_id && (test_course[:course].site_created_date&.== "#{Date.today}")
          sites_created << test_course
        else
          sites_to_create << test_course
        end

      rescue => e
        it("encountered an error retrieving SIS data for #{test_course[:course].code}") { fail }
        Utils.log_error e
      ensure
        @splash_page.load_page
        @splash_page.log_out
      end
    end

    # CREATE SITES

    @canvas_page.load_homepage
    @canvas_page.log_in(@cal_net_page, Utils.super_admin_username, Utils.super_admin_password) unless standalone

    sites_to_create.each do |site|

      begin

        logger.info "Creating a course site for #{site[:course].code} in #{site[:course].term} using the '#{site[:course].create_site_workflow}' workflow"

        if standalone
          @splash_page.load_page
          uid = %w(uid ccn).include?(site[:course].create_site_workflow) ? Utils.super_admin_uid : site[:teacher].uid
          @splash_page.basic_auth uid
          @site_creation_page.load_standalone_tool
        else
          @canvas_page.load_homepage
          @canvas_page.create_site_link_element.when_present Utils.short_wait
          @canvas_page.stop_masquerading if @canvas_page.stop_masquerading_link?
          @canvas_page.masquerade_as site[:teacher] unless %w(uid ccn).include?(site[:course].create_site_workflow)
          @canvas_page.click_create_site @driver
        end

        @site_creation_page.click_create_course_site

        if site[:course].create_site_workflow == 'self'
          @create_course_site_page.click_cancel
          cancel_works = @site_creation_page.verify_block { @site_creation_page.click_create_course_site }
          it('allows a user to cancel course site creation') { expect(cancel_works).to be true }
        end

        @create_course_site_page.search_for_course(site[:course], site[:teacher], site[:sections_for_site])

        # Verify page content and external links for one of the courses
        unless links_tested

          @create_course_site_page.maintenance_button_element.when_visible Utils.medium_wait
          short_maintenance_notice = @create_course_site_page.maintenance_button_element.text
          it('shows a collapsed maintenance notice') { expect(short_maintenance_notice).to include('From 8 - 9 AM, you may experience delays of up to 10 minutes') }

          @create_course_site_page.maintenance_button

          long_maintenance_notice = @create_course_site_page.maintenance_notice
          it('shows an expanded maintenance notice') { expect(long_maintenance_notice).to include('bCourses performs scheduled maintenance every day between 8-9AM') }

          bcourses_link_works = @create_course_site_page.external_link_valid?(@create_course_site_page.bcourses_service_element, 'bCourses | Digital Learning Services')
          it('shows a link to the bCourses service page') { expect(bcourses_link_works).to be true }

          @canvas_page.switch_to_canvas_iframe unless standalone || "#{@driver.browser}" == 'firefox'
          @create_course_site_page.click_need_help

          help_text = @create_course_site_page.help
          it('shows suggestions for creating sites for courses with multiple sections') { expect(help_text).to include('If you have a course with multiple sections, you will need to decide') }

          mode_link_works = @create_course_site_page.external_link_valid?(@create_course_site_page.instr_mode_link_element, 'IT - How do I create Course Site?')
          it('shows an instruction mode link') { expect(mode_link_works).to be true }

          @canvas_page.switch_to_canvas_iframe unless standalone || "#{@driver.browser}" == 'firefox'

          links_tested = true

        end

        # Unless admin creates site by CCN list, all sections in the test course and all other semester courses should be shown

        # Check the test course against expectations in the test data file
        @create_course_site_page.expand_available_sections site[:course].code
        (site[:course].create_site_workflow == 'ccn') ?
            expected_section_ids = site[:sections_for_site].map { |section| section.id } :
            expected_section_ids = site[:sections].map { |section| section.id }
        visible_section_ids = @create_course_site_page.course_section_ids(site[:course])
        it("offers all the expected sections for #{site[:course].term} #{site[:course].code}") { expect(visible_section_ids.sort!).to eql(expected_section_ids.sort!) }

        unless site[:course].create_site_workflow == 'ccn'

          semester = site[:academic_data].all_teaching_semesters.find { |semester| site[:academic_data].semester_name(semester) == site[:course].term }
          semester_courses = site[:academic_data].semester_courses semester

          # Check all other courses against the academics API
          semester_courses.each do |course_data|
            api_course_code = site[:academic_data].course_code course_data
            api_course_title = site[:academic_data].course_title course_data
            ui_course_title = @create_course_site_page.available_sections_course_title api_course_code
            ui_sections_expanded = @create_course_site_page.expand_available_sections api_course_code

            it("shows the right course title for #{api_course_code}") { expect(ui_course_title).to eql(api_course_title) }
            it("shows no blank course title for #{api_course_code}") { expect(ui_course_title.empty?).to be false }
            it("allows the available sections to be expanded for #{api_course_code}") { expect(ui_sections_expanded).to be_truthy }

            # Check each section
            site[:academic_data].course_sections(course_data).each do |section_data|
              api_section_data = site[:academic_data].section_data section_data
              ui_section_data = @create_course_site_page.section_data api_section_data[:id]

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
        @create_course_site_page.expand_available_sections site[:course].code
        @create_course_site_page.select_sections site[:sections_for_site]
        @create_course_site_page.click_next

        if site == sites_to_create.first
          @create_course_site_page.click_go_back
          go_back_works = @create_course_site_page.verify_block { @create_course_site_page.click_next }
          it('allows the user to go back to the initial course site creation page') { expect(go_back_works).to be true }
        end

        default_name = @create_course_site_page.site_name_input
        expected_name = "#{site[:course].title} (#{site[:course].term})"
        it("shows the default site name #{site[:course].title}") { expect(default_name).to eql(expected_name) }

        default_abbreviation = @create_course_site_page.site_abbreviation
        expected_abbreviation = site[:course].code
        it("shows the default site abbreviation #{site[:course].code}") { expect(default_abbreviation).to include(expected_abbreviation) }

        requires_name_and_abbreviation = @create_course_site_page.verify_block do
          @create_course_site_page.site_name_input_element.clear
          @create_course_site_page.site_name_error_element.when_present 1
          @create_course_site_page.wait_until(1) { @create_course_site_page.create_site_button_element.attribute('disabled') }
          @create_course_site_page.site_abbreviation_element.clear
          @create_course_site_page.site_abbreviation_error_element.when_present 1
        end

        it("requires a site name and abbreviation for #{site[:course].code}") { expect(requires_name_and_abbreviation).to be true }

        site[:course].title = @create_course_site_page.enter_site_titles site[:course]
        logger.info "Course site abbreviation will be #{site[:course].title}"

        @create_course_site_page.click_create_site
        if standalone
          @create_course_site_page.wait_for_standalone_site_id(site[:course], site[:teacher], @splash_page)
        else
          @create_course_site_page.wait_for_site_id site[:course]
        end

        it("redirects to the #{site[:course].term} #{site[:course].code} course site in Canvas when finished") { expect(site[:course].site_id).not_to be_nil }

        # If site creation succeeded, store the site info for the rest of the tests
        site[:course].site_id ?
            (sites_created << site) :
            logger.error("Timed out before the #{site[:course].term} #{site[:course].code} course site was created, or another error occurred")

      rescue => e
        it("encountered an error creating the course site for #{site[:course].code}") { fail }
        Utils.log_error e
      ensure
        if standalone
          @splash_page.load_page
          @splash_page.log_out
        end
      end
    end

    # OBTAIN SIS ROSTERS DATA FOR ALL TEST COURSES

    unless standalone

      @canvas_page.log_out(@driver, @cal_net_page)

      sites_created.each do |site|

        begin
          @splash_page.load_page
          @splash_page.basic_auth(site[:teacher].uid, @cal_net_page)
          site[:roster_data].get_feed(@driver, site[:course])
        ensure
          @splash_page.load_page
          @splash_page.log_out
        end
      end

      # CHECK COURSE SITE CONTENT - MEMBERSHIP, ROSTER PHOTOS, COURSE CAPTURES

      @canvas_page.load_homepage
      @canvas_page.log_in(@cal_net_page, Utils.super_admin_username, Utils.super_admin_password) if @cal_net_page.username?

      sites_created.each do |site|

        begin
          section_ids = site[:sections_for_site].map { |s| s.id }

          logger.info "Verifying content of #{site[:course].term} #{site[:course].code} site ID #{site[:course].site_id}"

          @canvas_page.masquerade_as(site[:teacher], site[:course])
          @canvas_page.publish_course_site site[:course]

          # MEMBERSHIP - check that course site user counts match expectations for each role

          api_semester = site[:academic_data].all_teaching_semesters.find { |s| s['name'] == site[:course].term }
          api_course = site[:academic_data].semester_courses(api_semester).find { |c| c['course_code'] == site[:course].code }
          api_sections = site[:academic_data].course_sections(api_course).select { |s| section_ids.include? s['ccn'] }

          expected_teacher_count = site[:academic_data].course_section_teachers(api_sections).length
          expected_lead_ta_count = site[:academic_data].course_section_lead_tas(api_sections).length
          expected_ta_count = site[:academic_data].course_section_tas(api_sections).length
          expected_student_count = site[:roster_data].enrolled_students.length
          expected_waitlist_count = site[:roster_data].waitlisted_students.length

          expected_enrollment_counts = [{:role => 'Student', :count => expected_student_count}, {:role => 'Waitlist Student', :count => expected_waitlist_count},
                                        {:role => 'Teacher', :count => expected_teacher_count}, {:role => 'Lead TA', :count => expected_lead_ta_count},
                                        {:role => 'TA', :count => expected_ta_count}]
          actual_enrollment_counts = @canvas_page.wait_for_enrollment_import(site[:course], ['Student', 'Waitlist Student', 'Teacher', 'Lead TA', 'TA'])

          actual_student_uids = @canvas_page.get_students(site[:course]).map(&:uid).sort
          expected_student_uids = site[:roster_data].all_student_uids.sort
          logger.warn "Student UIDs expected but not present: #{expected_student_uids - actual_student_uids}"
          logger.warn "Student UIDs present but not expected: #{actual_student_uids - expected_student_uids}"

          it("results in the right course site membership counts for #{site[:course].term} #{site[:course].code} site ID #{site[:course].site_id}") { expect(actual_enrollment_counts).to eql(expected_enrollment_counts) }
          it("results in no missing student enrollments for #{site[:course].term} #{site[:course].code} site ID #{site[:course].site_id}") { expect(expected_student_uids - actual_student_uids).to be_empty }
          it("results in no unexpected student enrollments for #{site[:course].term} #{site[:course].code} site ID #{site[:course].site_id}") { expect(actual_student_uids - expected_student_uids).to be_empty }

          visible_modes = @canvas_page.visible_instruction_modes
          it "shows the instruction mode for sections in #{site[:course].term} #{site[:course].code} site ID #{site[:course].site_id}" do
            expect(visible_modes).not_to be_empty
            expect(visible_modes - ['In Person', 'Online', 'Hybrid', 'Flexible', 'Remote']).to be_empty
          end

          # ROSTER PHOTOS - check that roster photos tool shows the right sections

          has_roster_photos_link = @roster_photos_page.roster_photos_link?
          it("shows a Roster Photos tool link in course site navigation for #{site[:course].term} #{site[:course].code} site ID #{site[:course].site_id}") { expect(has_roster_photos_link).to be true }

          @roster_photos_page.load_embedded_tool site[:course]
          @roster_photos_page.wait_for_load_and_click_js @roster_photos_page.section_select_element

          expected_sections_on_site = (site[:sections_for_site].map { |section| "#{section.course} #{section.label}" })
          actual_sections_on_site = @roster_photos_page.section_options
          it("shows the right section list on the Roster Photos tool for #{site[:course].term} #{site[:course].code} site ID #{site[:course].site_id}") { expect(actual_sections_on_site).to eql(expected_sections_on_site.sort) }

          # COURSE CAPTURE - check that course captures tool is not added automatically

          @canvas_page.load_course_site site[:course]
          has_course_captures_link = @course_captures_page.course_captures_link?
          it("shows no Course Captures tool link in course site navigation for #{site[:course].term} #{site[:course].code} site ID #{site[:course].site_id}") { expect(has_course_captures_link).to be false }

          # GRADES - check that grade distribution is hidden by default

          grade_distribution_hidden = @canvas_page.grade_distribution_hidden? site[:course]
          it("hides grade distribution graphs from students for #{site[:course].term} #{site[:course].code} site ID #{site[:course].site_id}") { expect(grade_distribution_hidden).to be true }

          @canvas_page.stop_masquerading
        rescue => e
          it("encountered an error verifying the course site for #{site[:course].code}") { fail }
          Utils.log_error e
        end
      end

      # VERIFY ACCESS TO TOOL FOR USER ROLES

      @canvas_page.masquerade_as test.students.first
      student_has_button = @canvas_page.verify_block { @canvas_page.create_site_link_element.when_visible Utils.short_wait }
      @canvas_page.click_create_site_settings_link
      student_access_blocked = @create_course_site_page.verify_block do
        @create_course_site_page.create_course_site_link_element.when_present Utils.short_wait
        @create_course_site_page.wait_until(1) { @create_course_site_page.create_course_site_link_element.attribute('disabled') == 'true' }
      end
      it('offers no Create a Site button to a student') { expect(student_has_button).to be false }
      it('denies a student access to the tool') { expect(student_access_blocked).to be true }

      @canvas_page.masquerade_as test.ta
      ta_has_button = @canvas_page.verify_block { @canvas_page.create_site_link_element.when_visible Utils.short_wait }
      @canvas_page.click_create_site_settings_link
      ta_access_permitted = @create_course_site_page.verify_block { @create_course_site_page.create_course_site_link_element.when_visible Utils.short_wait }
      it('offers a Create a Site button to a TA') { expect(ta_has_button).to be true }
      it('permits a TA access to the tool') { expect(ta_access_permitted).to be true }
    end

  rescue => e
    it('encountered an error') { fail }
    Utils.log_error e
  ensure
    Utils.quit_browser @driver
  end
end
