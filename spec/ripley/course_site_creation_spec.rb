require_relative '../../util/spec_helper'

describe 'bCourses course site creation' do

  include Logging

  test = RipleyTestConfig.new
  test.course_site_creation
  sites_created = []

  begin
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
    @splash_page = RipleySplashPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @site_creation = RipleySiteCreationPage.new @driver
    @create_course_site = RipleyCreateCourseSitePage.new @driver
    @canvas = Page::CanvasPage.new @driver
    @canvas_api = CanvasAPIPage.new @driver
    @canvas_assignments = Page::CanvasAssignmentsPage.new @driver
    @official_sections = RipleyOfficialSectionsPage.new @driver
    @roster_photos = RipleyRosterPhotosPage.new @driver

    @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
    @canvas.add_ripley_tools RipleyTool::TOOLS.select(&:account)
    @canvas.set_canvas_ids non_teachers
    @canvas_api.get_support_admin_canvas_id test.canvas_admin

    test.course_sites.reverse.each do |site|

      begin

        # -- Authenticate and load tool --

        logger.info "Creating a course site for #{site.course.code} in #{site.course.term.name} using the '#{site.create_site_workflow}' workflow"
        teacher = site.course.teachers.first
        @canvas.stop_masquerading
        @canvas.set_canvas_ids [teacher]
        (site.create_site_workflow == 'self') ? @canvas.masquerade_as(teacher) : @canvas.load_homepage
        @canvas.click_manage_sites
        @site_creation.click_create_course_site

        if site.create_site_workflow == 'self'
          @create_course_site.click_cancel_site_creation
          cancel_works = @site_creation.verify_block { @site_creation.click_create_course_site }
          it('allows a user to cancel course site creation') { expect(cancel_works).to be true }
        end
        @create_course_site.search_for_course site

        # -- Verify page content and external links for one of the courses --

        if site == test.course_sites.find { |s| %w(self uid).include? s.create_site_workflow }
          help = @create_course_site.need_help?
          it('shows suggestions for creating sites for courses with multiple sections') { expect(help).to be true }

          mode_title = 'IT - How do I create a Course Site?'
          mode_link_works = @create_course_site.external_link_valid?(@create_course_site.instr_mode_link_element, mode_title)
          it('shows an instruction mode link') { expect(mode_link_works).to be true }
          @canvas.switch_to_canvas_iframe
        end

        # -- Verify expected sections are visible --

        if site.create_site_workflow == 'ccn'
          @create_course_site.expand_all_available_sections
          expected_section_ids = site.sections.map &:id
          visible_section_ids = @create_course_site.all_section_ids
        else
          @create_course_site.expand_available_course_sections(site.course, site.course.sections.first)
          expected_section_ids = site.course.sections.map &:id
          visible_section_ids = @create_course_site.course_section_ids site.course
        end
        logger.warn "Unexpected sections: #{visible_section_ids - expected_section_ids}"
        logger.warn "Missing sections: #{expected_section_ids - visible_section_ids}"
        it "offers no unexpected sections for #{site.course.term.name} #{site.course.code} with the '#{site.create_site_workflow}' workflow" do
          expect(visible_section_ids - expected_section_ids).to be_empty
        end
        it "offers no missing sections for #{site.course.term.name} #{site.course.code} with the '#{site.create_site_workflow}' workflow" do
          expect(expected_section_ids - visible_section_ids).to be_empty
        end

        # -- Verify instructor courses data, unless search is section ID based --

        unless site.create_site_workflow == 'ccn'
          term_courses = RipleyUtils.get_instructor_term_courses(teacher, site.course.term)
          term_courses.each do |course|
            ui_course_title = @create_course_site.available_sections_course_title course
            ui_sections_expanded = @create_course_site.expand_available_course_sections(course, course.sections.first)

            it("shows the right course title for #{site.course.term.name} #{course.code}") { expect(ui_course_title).to include(course.title.gsub(':', '')) }
            it("shows no blank course title for #{site.course.term.name} #{course.code}") { expect(ui_course_title.empty?).to be false }
            it("allows the available sections to be expanded for #{site.course.term.name} #{course.code}") { expect(ui_sections_expanded).to be_truthy }

            course.sections.each do |section|
              ui_section_data = @create_course_site.section_data section.id

              it "shows the right section labels for #{site.course.term.name} #{course.code} section #{section.id}" do
                expect(ui_section_data[:label]).to eql(section.label)
              end
              it "shows no blank section labels for #{site.course.term.name} #{course.code} section #{section.id}" do
                expect(ui_section_data[:label].empty?).to be false
              end
              it "shows the right section schedules for #{site.course.term.name} #{course.code} section #{section.id}" do
                expect(ui_section_data[:schedules]).to eql(section.schedules)
              end
              it "shows the right section locations for #{site.course.term.name} #{course.code} section #{section.id}" do
                expect(ui_section_data[:locations]).to eql(section.locations)
              end
            end

            ui_sections_collapsed = @create_course_site.collapse_available_sections(course, course.sections.first)
            it("allows the available sections to be collapsed for #{site.course.term.name} #{course.code}") { expect(ui_sections_collapsed).to be_truthy }
          end
        end

        # -- Choose sections, verify validations, and create site --

        if site.create_site_workflow == 'ccn'
          @create_course_site.expand_all_available_sections
        else
          @create_course_site.expand_available_course_sections(site.course, site.sections.first)
        end
        @create_course_site.select_sections site.sections
        @create_course_site.click_next

        if site == test.course_sites.first
          default_name = @create_course_site.site_name_input_element.value
          expected_name = "#{site.course.title} (#{site.course.term.name})"
          it("shows the default site name #{site.course.title}") { expect(default_name).to eql(expected_name) }
          default_abbreviation = @create_course_site.site_abbreviation_element.value
          expected_abbreviation = site.course.code
          it("shows the default site abbreviation #{site.course.code}") { expect(default_abbreviation).to include(expected_abbreviation) }

          requires_name_and_abbreviation = @create_course_site.verify_block do
            @create_course_site.enter_site_name ''
            @create_course_site.site_name_error_element.when_present 1
            @create_course_site.wait_until(1) { @create_course_site.create_site_button_element.disabled? }
            @create_course_site.enter_site_abbreviation ''
            @create_course_site.site_abbreviation_error_element.when_present 1
          end
          it("requires a site name and abbreviation for #{site.course.code}") { expect(requires_name_and_abbreviation).to be true }

          @create_course_site.click_go_back
          go_back_works = @create_course_site.verify_block { @create_course_site.click_next }
          it('allows the user to go back to the initial course site creation page') { expect(go_back_works).to be true }
        end

        site.title = @create_course_site.enter_site_titles site.course
        logger.info "Course site abbreviation will be #{site.title}"
        @create_course_site.click_create_site
        @create_course_site.wait_for_site_id site
        it "redirects to the #{site.course.term.name} #{site.course.code} course site in Canvas when finished" do
          expect(site.site_id).not_to be_nil
        end
        sites_created << site

      rescue => e
        it("encountered an error creating the course site for #{site.course.term.name} #{site.course.code}") { fail Utils.error(e) }
        Utils.log_error e
      end
    end

    # CHECK COURSE SITE CONTENT - MEMBERSHIP, TOOL CONTENT, CUSTOMIZATIONS

    sites_created.each_with_index do |site, i|

      begin
        teacher = site.course.teachers.first
        test_case = "#{site.course.term.name} #{site.course.code} site ID #{site.site_id}"

        logger.info "Verifying content of #{test_case}"

        @canvas.masquerade_as teacher
        @canvas.publish_course_site site

        # -- Verify course site membership matches expectations --

        @canvas.load_users_page site
        visible_modes = @canvas.visible_instruction_modes
        it "shows the instruction mode for sections in #{test_case}" do
          expect(visible_modes).not_to be_empty
          expect(visible_modes - ['In Person', 'Online', 'Hybrid', 'Flexible', 'Remote', 'Web-based']).to be_empty
        end

        visible_site_members = @canvas.visible_user_section_data site
        expected_instructors = RipleyUtils.expected_instr_section_data(site, site.sections)
        expected_students = RipleyUtils.expected_student_section_data(site, site.sections)
        expected_site_members = expected_instructors + expected_students
        logger.warn "Unexpected users after creating site: #{visible_site_members - expected_site_members}"
        logger.warn "Missing users after creating site: #{expected_site_members - visible_site_members}"

        it "adds no unexpected users to #{test_case}" do
          expect(visible_site_members - expected_site_members).to be_empty
        end
        it "neglects no expected users on #{test_case}" do
          expect(expected_site_members - visible_site_members).to be_empty
        end

        # -- Verify roster photos tool shows the right sections --

        has_roster_photos_link = @roster_photos.roster_photos_link?
        it("shows a Roster Photos tool link in course site navigation for #{test_case}") { expect(has_roster_photos_link).to be true }

        @roster_photos.load_embedded_tool site
        @roster_photos.wait_for_load_and_click @roster_photos.section_select_element
        expected_sections_on_site = (site.sections.map { |section| "#{section.course} #{section.label}" })
        actual_sections_on_site = @roster_photos.section_options
        actual_sections_on_site.delete 'All Sections'
        it "shows the right section list on the Roster Photos tool for #{test_case}" do
          expect(actual_sections_on_site).to eql(expected_sections_on_site.sort)
        end

        # -- Verify TA Teachers have edit rights to manage sections --

        if RipleyUtils.get_course_instructor_roles(site.course, teacher) == ['TNIC']
          manage_sections_access = @official_sections.verify_block do
            @site_creation.load_embedded_tool teacher
            @site_creation.select_site_and_manage site
            @official_sections.static_view_sections_table.when_visible Utils.medium_wait
            @official_sections.edit_sections_button_element.when_visible 1
          end
          it "grants a Teacher TA the right to manage sections on #{test_case}" do
            expect(manage_sections_access).to be true
          end
        end

        # -- Customizations --

        grade_distribution_hidden = @canvas.grade_distribution_hidden? site
        it("hides grade distribution graphs from students for #{test_case}") { expect(grade_distribution_hidden).to be true }

        conf_nav_hidden = @canvas.conf_link_hidden?
        it("shows no Conferences tool link in course site navigation for #{test_case}") { expect(conf_nav_hidden).to be true }

        sub_account = @canvas.selected_course_sub_account site
        dept = site.course.code.split.delete_if { |c| c =~ /\d/ }.join(' ')
        it("shows the right sub-account for #{test_case}") { expect(sub_account).to eql(dept) }

        if i.zero?

          # -- Verify Files tab accessibility links --

          @canvas.click_files_tab
          @canvas.toggle_access_links

          basics_title = 'A11y Basics'
          basics_link = @canvas.external_link_valid?(@canvas.access_basics_link_element, basics_title)
          it("shows an Accessibility Basics for bCourses link for #{test_case}") { expect(basics_link).to be true }

          access_title = 'How do I use the Accessibility Checker in the Rich'
          access_checker = @canvas.external_link_valid?(@canvas.access_checker_link_element, access_title)
          it("shows a How Do I Use the Accessibility Checker link for #{test_case}") { expect(access_checker).to be true }

          dsp_title = 'Creating Accessible Content'
          dsp_link = @canvas.external_link_valid?(@canvas.access_dsp_link_element, dsp_title)
          it("shows a DSP link for #{test_case}") { expect(dsp_link).to be true }

          sensus_title = 'SensusAccess'
          sensus_link = @canvas.external_link_valid?(@canvas.access_sensus_link_element, sensus_title)
          it("shows a SensusAccess link for #{test_case}") { expect(sensus_link).to be true }

          ally_title = 'Ally in bCourses'
          ally_link = @canvas.external_link_valid?(@canvas.access_ally_link_element, ally_title)
          it("shows an Ally in bCourses link for #{test_case}") { expect(ally_link).to be true }

          # -- Verify Assignments tab religious holiday info --

          @canvas_assignments.load_new_assignment_page site
          @canvas_assignments.expand_religious_holidays
          religious_title = 'Religious Holidays & Religious Creed Policy'
          religious_link = @canvas_assignments.external_link_valid?(@canvas_assignments.religious_holiday_link_element, religious_title)
          it("shows a religious holiday policy link for #{test_case}") { expect(religious_link).to be true }
        end

        @canvas.stop_masquerading
      rescue => e
        it("encountered an error verifying course site #{site.site_id} for #{site.course.term.name} #{site.course.code}") { fail Utils.error(e) }
        Utils.log_error e
      end
    end

    # VERIFY ACCESS TO TOOL FOR USER ROLES

    @canvas.masquerade_as test.canvas_admin
    canvas_admin_has_button = @canvas.verify_block { @canvas.ripley_manage_sites_link_element.when_visible Utils.short_wait }
    @canvas.click_manage_sites_settings_link
    canvas_admin_access_permitted = @create_course_site.verify_block do
      @create_course_site.create_course_site_link_element.when_visible Utils.short_wait
    end
    it('offers a Create a Site button to a Canvas Admin') { expect(canvas_admin_has_button).to be true }
    it('permits a Canvas Admin access to the tool') { expect(canvas_admin_access_permitted).to be true }

    @canvas.masquerade_as test.students.first
    student_has_button = @canvas.verify_block { @canvas.ripley_manage_sites_link_element.when_visible Utils.short_wait }
    @canvas.click_manage_sites_settings_link
    student_access_blocked = @create_course_site.verify_block do
      @create_course_site.create_course_site_link_element.when_present Utils.short_wait
      @create_course_site.wait_until(1) do
        @create_course_site.create_course_site_link_element.attribute('disabled') == 'true'
      end
    end
    it('offers no Create a Site button to a student') { expect(student_has_button).to be false }
    it('denies a student access to the tool') { expect(student_access_blocked).to be true }

    @canvas.masquerade_as test.ta
    ta_has_button = @canvas.verify_block { @canvas.ripley_manage_sites_link_element.when_visible Utils.short_wait }
    @canvas.click_manage_sites_settings_link
    ta_access_permitted = @create_course_site.verify_block do
      @create_course_site.create_course_site_link_element.when_visible Utils.short_wait
    end
    it('offers a Create a Site button to a TA') { expect(ta_has_button).to be true }
    it('permits a TA access to the tool') { expect(ta_access_permitted).to be true }

  rescue => e
    it('encountered an error') { fail Utils.error(e) }
    Utils.log_error e
  ensure
    Utils.quit_browser @driver
  end
end
