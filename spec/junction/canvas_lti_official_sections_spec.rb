require_relative '../../util/spec_helper'

describe 'bCourses Official Sections tool' do

  include Logging

  begin

    # Load test course data
    test_data = JunctionUtils.load_junction_test_course_data.select { |course| course['tests']['official_sections'] }
    test_output = JunctionUtils.initialize_junction_test_output(self, ['UID', 'Semester', 'Course', 'Section Label', 'Section CCN',
                                                             'Section Schedules', 'Section Locations', 'Section Instructors'])

    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasPage.new @driver
    @splash_page = Page::JunctionPages::SplashPage.new @driver
    @site_creation_page = Page::JunctionPages::CanvasSiteCreationPage.new @driver
    @create_course_site_page = Page::JunctionPages::CanvasCreateCourseSitePage.new @driver
    @course_add_user_page = Page::JunctionPages::CanvasCourseAddUserPage.new @driver
    @official_sections_page = Page::JunctionPages::CanvasCourseManageSectionsPage.new @driver

    all_test_courses = []
    sites_to_create = []

    # COLLECT SIS DATA FOR ALL TEST COURSES

    test_data.each do |data|

      begin
        course = Course.new data
        teacher = User.new(course.teachers.first)
        sections = course.sections.map { |section_data| Section.new section_data }
        sections_for_site = sections.select { |section| section.include_in_site }

        test_course = {:course => course, :teacher => teacher, :sections => sections, :sections_for_site => sections_for_site,
                       :site_abbreviation => nil, :academic_data => nil}

        @splash_page.load_page
        @splash_page.basic_auth(test_course[:teacher].uid, @cal_net)
        test_course[:academic_data] = ApiAcademicsCourseProvisionPage.new @driver
        test_course[:academic_data].get_feed @driver
        all_test_courses << test_course
        sites_to_create << test_course unless test_course[:course].site_id

      rescue => e
        it("encountered an error retrieving SIS data for #{test_course[:course].code}") { fail }
        Utils.log_error e
      ensure
        @splash_page.load_page
        @splash_page.log_out @splash_page
      end
    end

    # Authenticate in Canvas
    @canvas.load_homepage
    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)

    # Create course sites that don't already exist
    sites_to_create.each do |site|
      @canvas.masquerade_as(@driver, site[:teacher])
      logger.debug "Sections to be included at site creation are #{site[:sections_for_site].map { |s| s.id }}"
      @create_course_site_page.provision_course_site(@driver, site[:course], site[:teacher], site[:sections_for_site])
    end

    # ADD AND REMOVE SECTIONS FOR ALL TEST COURSES

    all_test_courses.each do |site|

      begin
        logger.info "Test course is #{site[:course].code}"
        sections_to_add_delete = (site[:sections] - site[:sections_for_site])
        section_ids_to_add_delete = (sections_to_add_delete.map { |section| section.id }).join(', ')
        logger.debug "Sections to be added and deleted are #{section_ids_to_add_delete}"

        @canvas.stop_masquerading @driver if @canvas.stop_masquerading_link?
        @canvas.masquerade_as(@driver, site[:teacher])
        @canvas.publish_course_site(@driver, site[:course])

        # STATIC VIEW - sections currently in the site

        @official_sections_page.load_embedded_tool(@driver, site[:course])
        @official_sections_page.current_sections_table.when_visible Utils.medium_wait

        static_view_sections_count = @official_sections_page.current_sections_count
        it("shows all the sections currently on course site ID #{site[:course].site_id}") { expect(static_view_sections_count).to eql(site[:sections_for_site].length) }

        site[:sections_for_site].each do |section|
          ui_course_code = @official_sections_page.current_section_course section
          ui_section_label = @official_sections_page.current_section_label section
          has_delete_button = @official_sections_page.section_delete_button(section).exists?

          it("shows the course code for section #{section.id}") { expect(ui_course_code).to eql(section.course) }
          it("shows the section label for section #{section.id}") { expect(ui_section_label).to eql(section.label) }
          it("shows no Delete button for section #{section.id}") { expect(has_delete_button).to be false }
        end

        # EDITING VIEW - NOTICES AND LINKS

        @official_sections_page.click_edit_sections
        logger.debug "There are #{@official_sections_page.available_sections_count(@driver, site[:course])} rows in the available sections table"

        has_maintenance_notice = @official_sections_page.verify_block do
          @official_sections_page.maintenance_notice_button_element.when_present Utils.short_wait
          @official_sections_page.maintenance_detail_element.when_not_visible 1
        end

        has_maintenance_detail = @official_sections_page.verify_block do
          @official_sections_page.maintenance_notice_button
          @official_sections_page.maintenance_detail_element.when_visible Utils.short_wait
        end

        has_bcourses_service_link = @official_sections_page.external_link_valid?(@driver, @official_sections_page.bcourses_service_link_element, 'bCourses | Educational Technology Services')
        @official_sections_page.switch_to_canvas_iframe @driver

        it("shows a collapsed maintenance notice on course site ID #{site[:course].site_id}") { expect(has_maintenance_notice).to be true }
        it("allows the user to reveal an expanded maintenance notice #{site[:course].site_id}") { expect(has_maintenance_detail).to be true }
        it("offers a link to the bCourses service page in the expanded maintenance notice #{site[:course].site_id}") { expect(has_bcourses_service_link).to be true }

        # EDITING VIEW - ALL COURSE SECTIONS CURRENTLY IN A COURSE SITE

        edit_view_sections_count = @official_sections_page.current_sections_count
        it("shows all the sections currently on course site ID #{site[:course].site_id}") { expect(edit_view_sections_count).to eql(site[:sections_for_site].length) }

        site[:sections_for_site].each do |section|
          has_section_in_site = @official_sections_page.current_section_id_element(section).exists?
          has_delete_button = @official_sections_page.section_delete_button(section).exists?

          it("shows section #{section.id} is already in course site #{site[:course].site_id}") { expect(has_section_in_site).to be true }
          it("shows a Delete button for section #{section.id}") { expect(has_delete_button).to be true }
        end

        # EDITING VIEW - THE RIGHT TEST COURSE SECTIONS ARE AVAILABLE TO ADD TO THE COURSE SITE

        is_expanded = @official_sections_page.available_sections_table(site[:course].code).exists?
        available_section_count = @official_sections_page.available_sections_count(@driver, site[:course])
        save_button_enabled = @official_sections_page.save_changes_button_element.enabled?

        it("shows an expanded view of courses with sections already in course site ID #{site[:course].site_id}") { expect(is_expanded).to be true }
        it("shows all the sections in the course #{site[:course].code}") { expect(available_section_count).to eql(site[:sections].length) }
        it("shows a disabled save button when no changes have been made in course site ID #{site[:course].site_id}") { expect(save_button_enabled).to be false }

        site[:sections].each do |section|
          has_section_available = @official_sections_page.available_section_id_element(site[:course].code, section.id).exists?
          has_add_button = @official_sections_page.section_add_button(site[:course], section).exists?

          it("shows section #{section.id} is available for course site #{site[:course].site_id}") { expect(has_section_available).to be true }
          it "shows an Add button for section #{section.id}" do
            (site[:sections_for_site].include? section) ?
                (expect(has_add_button).to be false) :
                (expect(has_add_button).to be true)
          end
        end

        # EDITING VIEW - THE RIGHT DATA IS DISPLAYED FOR ALL AVAILABLE SEMESTER COURSES

        semester_name = site[:course].term
        semester = site[:academic_data].all_teaching_semesters.find { |semester| site[:academic_data].semester_name(semester) == semester_name }
        semester_courses = site[:academic_data].semester_courses semester

        semester_courses.each do |course_data|
          api_course_code = site[:academic_data].course_code course_data
          api_course_title = site[:academic_data].course_title course_data

          ui_sections_expanded = @official_sections_page.expand_available_sections api_course_code
          ui_course_title = @official_sections_page.available_sections_course_title api_course_code

          it("shows the right course title for #{api_course_code}") { expect(ui_course_title).to eql(api_course_title) }
          it("shows no blank course title for #{api_course_code}") { expect(ui_course_title.empty?).to be false }
          it("allows the user to to expand the available sections for #{api_course_code}") { expect(ui_sections_expanded).to be_truthy }

          # Check each section
          site[:academic_data].course_sections(course_data).each do |section_data|
            api_section_data = site[:academic_data].section_data section_data
            logger.debug "Checking data for section ID #{api_section_data[:id]}"
            ui_section_data = @official_sections_page.available_section_data(api_course_code, api_section_data[:id])

            it("shows the right course code for #{api_course_code} section #{api_section_data[:id]}") { expect(ui_section_data[:code]).to eql(api_section_data[:code]) }
            it("shows no blank course code for #{api_course_code} section #{api_section_data[:id]}") { expect(ui_section_data[:code].empty?).to be false }
            it("shows the right section labels for #{api_course_code} section #{api_section_data[:id]}") { expect(ui_section_data[:label]).to eql(api_section_data[:label]) }
            it("shows no blank section labels for #{api_course_code} section #{api_section_data[:id]}") { expect(ui_section_data[:label].empty?).to be false }
            it("shows the right section schedules for #{api_course_code} section #{api_section_data[:id]}") { expect(ui_section_data[:schedules]).to eql(api_section_data[:schedules]) }
            it("shows the right section locations for #{api_course_code} section #{api_section_data[:id]}") { expect(ui_section_data[:locations]).to eql(api_section_data[:locations]) }

            test_output_row = [site[:teacher].uid, site[:course].term, api_section_data[:code], api_section_data[:label], api_section_data[:id],
                               api_section_data[:schedules], api_section_data[:locations], api_section_data[:instructors]]
            Utils.add_csv_row(test_output, test_output_row)
          end

          ui_sections_collapsed = @official_sections_page.collapse_available_sections api_course_code
          it("allows the user to collapse the available sections for #{api_course_code}") { expect(ui_sections_collapsed).to be_truthy }
        end

        # STAGING OR UN-STAGING SECTIONS FOR ADDING OR DELETING

        @official_sections_page.expand_available_sections site[:course].code

        sections_to_add_delete.last do |section|

          logger.debug 'Testing add and undo add'
          @official_sections_page.click_add_section(site[:course], section)
          section_staged_for_add = @official_sections_page.current_section_id_element(section).exists?
          section_add_button_gone = !@official_sections_page.section_add_button(site[:course], section).exists?
          section_added_msg = @official_sections_page.section_added_element(site[:course], section).exists?

          it("'add' button moves section #{section.id} from available to current sections") { expect(section_staged_for_add).to be true }
          it("hides the add button for section #{section.id} when staged for adding") { expect(section_add_button_gone).to be true }
          it("shows an 'added' message for section #{section.id} when staged for adding") { expect(section_added_msg).to be true }

          @official_sections_page.click_undo_add_section section
          section_unstaged_for_add = !@official_sections_page.current_section_id_element(section).exists?
          section_add_button_back = @official_sections_page.section_add_button(site[:course], section).exists?

          it("'undo add' button removes section #{section.id} from current sections") { expect(section_unstaged_for_add).to be true }
          it("reveals the add button for section #{section.id} when un-staged for adding") { expect(section_add_button_back).to be true }
        end

        site[:sections_for_site].first do |section|

          logger.debug 'Testing delete and undo delete'
          @official_sections_page.click_delete_section section
          section_staged_for_delete = !@official_sections_page.current_section_id_element(section).exists?
          section_undo_delete_button = @official_sections_page.section_undo_delete_button(site[:course], section).exists?

          it("'delete' button removes section #{section.id} from current sections") { expect(section_staged_for_delete).to be true }
          it("reveals the 'undo delete' button for section #{section.id} when staged for deleting") { expect(section_undo_delete_button).to be true }

          @official_sections_page.click_undo_delete_section(site[:course], section)
          section_unstaged_for_delete = @official_sections_page.current_section_id_element(section).exists?
          section_undo_delete_button_gone = !@official_sections_page.section_undo_delete_button(site[:course], section).exists?
          section_still_available = @official_sections_page.available_section_id_element(site[:course], section).exists?

          it("allows the user to un-stage section #{section.id} for deleting from course site ID #{site[:course].site_id}") { expect(section_unstaged_for_delete).to be true }
          it("hides the 'undo delete' button for section #{section.id} when un-staged for deleting") { expect(section_undo_delete_button_gone).to be true }
          it("still shows section #{section.id} among available sections when un-staged for deleting") { expect(section_still_available).to be true }
        end

        # ADDING SECTIONS

        @official_sections_page.load_embedded_tool(@driver, site[:course])
        @official_sections_page.click_edit_sections
        @official_sections_page.add_sections(site[:course], sections_to_add_delete)

        added_sections_updating_msg = @official_sections_page.updating_sections_msg_element.when_visible Utils.medium_wait
        added_sections_updated_msg = @official_sections_page.sections_updated_msg_element.when_visible Utils.long_wait

        @official_sections_page.close_section_update_success

        add_success_msg_closed = @official_sections_page.sections_updated_msg_element.when_not_visible Utils.short_wait
        total_sections_with_adds = @official_sections_page.current_sections_count

        it("shows an 'updating' message when sections #{section_ids_to_add_delete} are being added to course site #{site[:course].site_id}") { expect(added_sections_updating_msg).to be_truthy }
        it("shows an 'updated' message when sections #{section_ids_to_add_delete} have been added to course site #{site[:course].site_id}") { expect(added_sections_updated_msg).to be_truthy }
        it("allows the user to close an 'update success' message when sections #{section_ids_to_add_delete} have been added to course site #{site[:course].site_id}") { expect(add_success_msg_closed).to be_truthy }
        it("shows the right number of current sections when sections #{section_ids_to_add_delete} have been added to course site #{site[:course].site_id}") { expect(total_sections_with_adds).to eql(site[:sections].length) }

        sections_to_add_delete.each do |section|
          section_added = @official_sections_page.current_section_id_element(section).exists?
          it("shows added section #{section.id} among current sections on course site #{site[:course].site_id}") { expect(section_added).to be true }
        end

        # Check that sections present on Find a Person to Add tool are updated immediately
        @course_add_user_page.load_embedded_tool(@driver, site[:course])
        @course_add_user_page.search(Utils.oski_uid, 'CalNet UID')
        ttl_user_sections_with_adds = @course_add_user_page.verify_block do
          @course_add_user_page.wait_until(Utils.medium_wait) { @course_add_user_page.course_section_options.length == site[:sections].length }
        end
        it("shows the right number of current sections on Find a Person to Add when sections #{section_ids_to_add_delete} have been added to course site #{site[:course].site_id}") { expect(ttl_user_sections_with_adds).to be true }

        # TODO - SECTIONS ADDED TO E-GRADES EXPORT TOOL

        # DELETING SECTIONS

        @official_sections_page.load_embedded_tool(@driver, site[:course])
        @official_sections_page.click_edit_sections
        @official_sections_page.delete_sections sections_to_add_delete

        deleted_sections_updating_msg = @official_sections_page.updating_sections_msg_element.when_visible Utils.short_wait
        deleted_sections_updated_msg = @official_sections_page.sections_updated_msg_element.when_visible Utils.long_wait

        @official_sections_page.close_section_update_success

        delete_success_msg_closed = @official_sections_page.sections_updated_msg_element.when_not_visible Utils.short_wait
        total_sections_without_deletes = @official_sections_page.current_sections_count

        it("shows an 'updating' message when sections #{section_ids_to_add_delete} are being added to course site #{site[:course].site_id}") { expect(deleted_sections_updating_msg).to be_truthy }
        it("shows an 'updated' message when sections #{section_ids_to_add_delete} have been added to course site #{site[:course].site_id}") { expect(deleted_sections_updated_msg).to be_truthy }
        it("allows the user to close an 'update success' message when sections #{section_ids_to_add_delete} have been added to course site #{site[:course].site_id}") { expect(delete_success_msg_closed).to be_truthy }
        it("shows the right number of current sections when sections #{section_ids_to_add_delete} have been added to course site #{site[:course].site_id}") { expect(total_sections_without_deletes).to eql(site[:sections_for_site].length) }

        sections_to_add_delete.each do |section|
          section_deleted = !@official_sections_page.current_section_id_element(section).exists?
          it("shows added section #{section.id} among current sections on course site #{site[:course].site_id}") { expect(section_deleted).to be true }
        end

        # Check that sections present on Find a Person to Add tool are updated immediately
        @course_add_user_page.load_embedded_tool(@driver, site[:course])
        @course_add_user_page.search(Utils.oski_uid, 'CalNet UID')
        ttl_user_sections_with_deletes = @course_add_user_page.verify_block do
          @course_add_user_page.wait_until(Utils.medium_wait) { @course_add_user_page.course_section_options.length == site[:sections_for_site].length }
        end
        it("shows the right number of current sections on Find a Person to Add when sections #{section_ids_to_add_delete} have been removed from course site #{site[:course].site_id}") { expect(ttl_user_sections_with_deletes).to be true }

        # TODO - SECTIONS REMOVED FROM E-GRADES EXPORT TOOL

        # CHECK USER ROLE ACCESS TO THE TOOL FOR ONE COURSE

        if site == all_test_courses.last

          # Load test user data and add each to the site
          test_user_data = JunctionUtils.load_junction_test_user_data.select { |user| user['tests']['official_sections'] }
          lead_ta = User.new test_user_data.find { |data| data['role'] == 'Lead TA' }
          ta = User.new test_user_data.find { |data| data['role'] == 'TA' }
          designer = User.new test_user_data.find { |data| data['role'] == 'Designer' }
          observer = User.new test_user_data.find { |data| data['role'] == 'Observer' }
          reader = User.new test_user_data.find { |data| data['role'] == 'Reader' }
          student = User.new test_user_data.find { |data| data['role'] == 'Student' }
          waitlist = User.new test_user_data.find { |data| data['role'] == 'Waitlist Student' }

          @canvas.stop_masquerading @driver
          [lead_ta, ta, designer, reader, observer, student, waitlist].each do |user|
            @course_add_user_page.load_embedded_tool(@driver, site[:course])
            @course_add_user_page.search(user.uid, 'CalNet UID')
            @course_add_user_page.add_user_by_uid(user, site[:sections_for_site].first)
          end

          # Check each user role's access to the tool
          [lead_ta, ta, designer, reader, observer, student, waitlist].each do |user|
            @canvas.masquerade_as(@driver, user, site[:course])
            @official_sections_page.load_embedded_tool(@driver, site[:course])
            if user.role == 'Lead TA'
              has_right_perms = @official_sections_page.verify_block do
                @official_sections_page.current_sections_table_element.when_visible Utils.medium_wait
                @official_sections_page.edit_sections_button_element.when_visible 1
              end
            elsif %w(TA Designer).include? user.role
              has_right_perms = @official_sections_page.verify_block do
                @official_sections_page.current_sections_table_element.when_visible Utils.medium_wait
                @official_sections_page.edit_sections_button_element.when_not_visible 1
              end
            else
              has_right_perms = @official_sections_page.verify_block do
                @official_sections_page.unexpected_error_element.when_present Utils.medium_wait
                @official_sections_page.current_sections_table_element.when_not_visible 1
              end
            end

            it("allows #{user.role} #{user.uid} access to the tool if permitted") { expect(has_right_perms).to be true }
          end
        end

      rescue => e
        it("encountered an error for #{site[:course].code}") { fail }
        logger.error "#{e.message}#{"\n"}#{e.backtrace.join("\n")}"
      end
    end
  rescue => e
    it('encountered an error') { fail }
    logger.error "#{e.message}#{"\n"}#{e.backtrace.join("\n")}"
  ensure
    Utils.quit_browser @driver
  end
end
