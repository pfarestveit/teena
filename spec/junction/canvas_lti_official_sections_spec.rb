require_relative '../../util/spec_helper'

describe 'bCourses Official Sections tool' do

  include Logging

  masquerade = ENV['masquerade']
  course_id = ENV['course_id']
  test_id = "#{Time.now.to_i}"

  begin

    # Load courses test data
    test_course_data = Utils.load_test_courses.select { |course| course['tests']['official_sections'] }
    test_output = Utils.initialize_canvas_test_output(self, ['UID', 'Semester', 'Course', 'Section Label', 'Section CCN',
                                                             'Section Schedules', 'Section Locations', 'Section Instructors'])

    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasPage.new @driver
    @roster_api = Page::ApiAcademicsRosterPage.new @driver
    @academics_api = ApiMyAcademicsPage.new @driver
    @splash_page = Page::CalCentralPages::SplashPage.new @driver
    @site_creation_page = Page::CalCentralPages::CanvasSiteCreationPage.new @driver
    @create_course_site_page = Page::CalCentralPages::CanvasCreateCourseSitePage.new @driver
    @course_add_user_page = Page::CalCentralPages::CanvasCourseAddUserPage.new @driver
    @official_sections_page = Page::CalCentralPages::CanvasCourseManageSectionsPage.new @driver
    @roster_photos_page = Page::CalCentralPages::CanvasRostersPage.new @driver

    # Authenticate in Canvas
    masquerade ?
        @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password) :
        @canvas.log_in(@cal_net, Utils.ets_qa_username, Utils.ets_qa_password)

    test_course_data.each do |test_data|

      begin
        # Load course test data
        @course = Course.new test_data
        @teacher = User.new @course.teachers.first
        @course.site_id = course_id

        sections = @course.sections.map { |section_data| Section.new section_data }
        sections_for_site = sections.select { |section| section.include_in_site }
        section_ids_for_site = (sections_for_site.map { |section| section.id }).join(', ')
        logger.debug "Sections to be included at site creation are #{section_ids_for_site}"
        sections_to_add_delete = (sections - sections_for_site)
        section_ids_to_add_delete = (sections_to_add_delete.map { |section| section.id }).join(', ')
        logger.debug "Sections to be added and deleted are #{section_ids_to_add_delete}"

        # Authenticate in Junction to get feeds
        @splash_page.basic_auth @teacher.uid
        @academics_api.get_feed @driver

        if masquerade
          @splash_page.log_out @splash_page
          @canvas.masquerade_as @teacher
        end

        # Create test course site if necessary
        if @course.site_id.nil?
          @course.create_site_workflow = nil
          if masquerade
            @create_course_site_page.load_embedded_tool(@driver, @teacher)
            @site_creation_page.click_create_course_site @create_course_site_page
          else
            @create_course_site_page.load_standalone_tool
          end
          @create_course_site_page.provision_course_site(@course, @teacher, sections_for_site)
          @canvas.publish_course_site(@course) if masquerade
        end

        # Get enrollment totals on site
        if masquerade
          if course_id.nil?
            user_counts = @canvas.wait_for_enrollment_import(@course, ['Student', 'Waitlist Student'])
            @student_count = user_counts[0]
            @waitlist_count = user_counts[1]
          else
            @student_count = @canvas.enrollment_count_by_role(@course, 'Student')
            @waitlist_count = @canvas.enrollment_count_by_role(@course, 'Waitlist Student')
          end
          @canvas.load_users_page @course
          @canvas.click_find_person_to_add @driver
        else
          @roster_api.get_feed(@driver, @course)
          @student_count = @roster_api.enrolled_students.length
          @waitlist_count = @roster_api.waitlisted_students.length
        end
        @total_users = @student_count + @waitlist_count
        logger.info "There are #{@student_count} enrolled students and #{@waitlist_count} waitlisted students, for a total of #{@total_users}"
        logger.warn 'There are no students on this site' if @total_users.zero?

        masquerade ?
            @official_sections_page.load_embedded_tool(@driver, @course) :
            @official_sections_page.load_standalone_tool(@course)
        @official_sections_page.current_sections_table.when_visible Utils.medium_wait

        # Sections currently in the site - static view

        static_view_sections_count = @official_sections_page.current_sections_count
        it("shows all the sections currently on course site ID #{@course.site_id}") { expect(static_view_sections_count).to eql(sections_for_site.length) }

        sections_for_site.each do |section|
          ui_course_code = @official_sections_page.current_section_course section
          ui_section_label = @official_sections_page.current_section_label section
          has_delete_button = @official_sections_page.section_delete_button(section).exists?

          it("shows the course code for section #{section.id}") { expect(ui_course_code).to eql(section.course) }
          it("shows the section label for section #{section.id}") { expect(ui_section_label).to eql(section.label) }
          it("shows no Delete button for section #{section.id}") { expect(has_delete_button).to be false }
        end

        # EDITING VIEW - NOTICES AND LINKS

        @official_sections_page.click_edit_sections
        logger.debug "There are #{@official_sections_page.available_sections_count(@driver, @course)} rows in the available sections table"

        has_maintenance_notice = @official_sections_page.verify_block do
          @official_sections_page.maintenance_notice_button_element.when_present Utils.short_wait
          @official_sections_page.maintenance_detail_element.when_not_visible 1
        end

        has_maintenance_detail = @official_sections_page.verify_block do
          @official_sections_page.maintenance_notice_button
          @official_sections_page.maintenance_detail_element.when_visible Utils.short_wait
        end

        has_bcourses_service_link = @official_sections_page.external_link_valid?(@driver, @official_sections_page.bcourses_service_link_element, 'bCourses | Educational Technology Services')

        it("shows a collapsed maintenance notice on course site ID #{@course.site_id}") { expect(has_maintenance_notice).to be true }
        it("allows the user to reveal an expanded maintenance notice #{@course.site_id}") { expect(has_maintenance_detail).to be true }
        it("offers a link to the bCourses service page in the expanded maintenance notice #{@course.site_id}") { expect(has_bcourses_service_link).to be true }

        # EDITING VIEW - ALL COURSE SECTIONS CURRENTLY IN A COURSE SITE

        @official_sections_page.switch_to_canvas_iframe @driver
        edit_view_sections_count = @official_sections_page.current_sections_count
        it("shows all the sections currently on course site ID #{@course.site_id}") { expect(edit_view_sections_count).to eql(sections_for_site.length) }

        sections_for_site.each do |section|
          has_section_in_site = @official_sections_page.current_section_id_element(section).exists?
          has_delete_button = @official_sections_page.section_delete_button(section).exists?

          it("shows section #{section.id} is already in course site #{@course.site_id}") { expect(has_section_in_site).to be true }
          it("shows no Delete button for section #{section.id}") { expect(has_delete_button).to be true }
        end

        # EDITING VIEW - THE RIGHT TEST COURSE SECTIONS ARE AVAILABLE TO ADD TO THE COURSE SITE

        is_expanded = @official_sections_page.available_sections_table(@course.code).exists?
        available_section_count = @official_sections_page.available_sections_count(@driver, @course)
        save_button_enabled = @official_sections_page.save_changes_button_element.enabled?

        it("shows an expanded view of courses with sections already in course site ID #{@course.site_id}") { expect(is_expanded).to be true }
        it("shows all the sections in the course #{@course.code}") { expect(available_section_count).to eql(sections.length) }
        it("shows a disabled save button in course site ID #{@course.site_id}") { expect(save_button_enabled).to be false }

        sections.each do |section|
          has_section_available = @official_sections_page.available_section_id_element(@course, section).exists?
          has_add_button = @official_sections_page.section_add_button(@course, section).exists?

          it("shows section #{section.id} is available for course site #{@course.site_id}") { expect(has_section_available).to be true }
          it "shows an Add button for section #{section.id}" do
            (sections_for_site.include? section) ?
                (expect(has_add_button).to be false) :
                (expect(has_add_button).to be true)
          end
        end

        # EDITING VIEW - THE RIGHT DATA IS DISPLAYED FOR ALL AVAILABLE SEMESTER COURSES

        teaching_semesters = @academics_api.all_teaching_semesters
        semester_name = @course.term
        semester = teaching_semesters.find { |semester| @academics_api.semester_name(semester) == semester_name }
        semester_courses = @academics_api.semester_courses semester

        semester_courses.each do |course_data|
          api_course_code = @academics_api.course_code course_data
          api_course_title = @academics_api.course_title course_data
          api_sections = @academics_api.course_sections course_data
          api_section_labels = @academics_api.course_section_labels(api_sections).sort
          api_section_ccns = @academics_api.course_ccns(api_sections).sort
          api_section_schedules = @academics_api.course_section_schedules(api_sections).sort
          api_section_locations = @academics_api.course_section_locations(api_sections).sort
          api_section_instructors = @academics_api.course_section_instructors(api_sections).sort

          logger.info "Checking the info displayed for the #{api_sections.length} sections in #{api_course_code}"
          ui_sections_expanded = @official_sections_page.expand_available_sections api_course_code
          ui_course_title = @official_sections_page.available_sections_course_title api_course_code
          ui_section_labels = @official_sections_page.visible_section_labels(@driver, api_course_code).sort
          ui_section_ccns = @official_sections_page.visible_section_ids(@driver, api_course_code).sort
          ui_section_schedules = @official_sections_page.visible_section_schedules(@driver, api_course_code).sort
          ui_section_locations = @official_sections_page.visible_section_locations(@driver, api_course_code).sort
          ui_section_instructors = @official_sections_page.visible_section_instructors(@driver, api_course_code).sort
          ui_sections_collapsed = @official_sections_page.collapse_available_sections api_course_code

          it("shows the right course title for #{api_course_code}") { expect(ui_course_title).to eql(api_course_title) }
          it("shows no blank course title for #{api_course_code}") { expect(ui_course_title.empty?).to be false }
          it("allows to expand the available sections for #{api_course_code}") { expect(ui_sections_expanded).to be_truthy }
          it("allows the user to collapse the available sections for #{api_course_code}") { expect(ui_sections_collapsed).to be_truthy }
          it("shows the right section IDs for #{api_course_code}") { expect(ui_section_ccns).to eql(api_section_ccns) }
          it("shows no blank section IDs for #{api_course_code}") { expect(ui_section_ccns.all? &:empty?).to be false }
          it("shows the right section labels for #{api_course_code}") { expect(ui_section_labels).to eql(api_section_labels) }
          it("shows no blank section labels for #{api_course_code}") { expect(ui_section_labels.all? &:empty?).to be false }
          it("shows the right section schedules for #{api_course_code}") { expect(ui_section_schedules).to eql(api_section_schedules) }
          it("shows the right section locations for #{api_course_code}") { expect(ui_section_locations).to eql(api_section_locations) }
          it("shows the right section instructors for #{api_course_code}") { expect(ui_section_instructors).to eql(api_section_instructors) }

          api_sections.each do |section|
            i = api_sections.index section
            test_output_row = [@teacher.uid, semester_name, api_course_code, api_section_labels[i], api_section_ccns[i], api_section_schedules[i],
                               api_section_locations[i], api_section_instructors[i]]
            Utils.add_csv_row(test_output, test_output_row)
          end
        end

        # STAGING OR UN-STAGING SECTIONS FOR ADDING OR DELETING

        @official_sections_page.expand_available_sections @course.code

        sections_to_add_delete.last do |section|

          logger.debug 'Testing add and undo add'
          @official_sections_page.click_add_section(@course, section)
          section_staged_for_add = @official_sections_page.current_section_id_element(section).exists?
          section_add_button_gone = !@official_sections_page.section_add_button(@course, section).exists?
          section_added_msg = @official_sections_page.section_added_element(@course, section).exists?

          it("'add' button moves section #{section.id} from available to current sections") { expect(section_staged_for_add).to be true }
          it("hides the add button for section #{section.id} when staged for adding") { expect(section_add_button_gone).to be true }
          it("shows an 'added' message for section #{section.id} when staged for adding") { expect(section_added_msg).to be true }

          @official_sections_page.click_undo_add_section section
          section_unstaged_for_add = !@official_sections_page.current_section_id_element(section).exists?
          section_add_button_back = @official_sections_page.section_add_button(@course, section).exists?

          it("'undo add' button removes section #{section.id} from current sections") { expect(section_unstaged_for_add).to be true }
          it("reveals the add button for section #{section.id} when un-staged for adding") { expect(section_add_button_back).to be true }
        end

        sections_for_site.first do |section|

          logger.debug 'Testing delete and undo delete'
          @official_sections_page.click_delete_section section
          section_staged_for_delete = !@official_sections_page.current_section_id_element(section).exists?
          section_undo_delete_button = @official_sections_page.section_undo_delete_button(@course, section).exists?

          it("'delete' button removes section #{section.id} from current sections") { expect(section_staged_for_delete).to be true }
          it("reveals the 'undo delete' button for section #{section.id} when staged for deleting") { expect(section_undo_delete_button).to be true }

          @official_sections_page.click_undo_delete_section(@course, section)
          section_unstaged_for_delete = @official_sections_page.current_section_id_element(section).exists?
          section_undo_delete_button_gone = !@official_sections_page.section_undo_delete_button(@course, section).exists?
          section_still_available = @official_sections_page.available_section_id_element(@course, section).exists?

          it("allows the user to un-stage section #{section.id} for deleting from course site ID #{@course.site_id}") { expect(section_unstaged_for_delete).to be true }
          it("hides the 'undo delete' button for section #{section.id} when un-staged for deleting") { expect(section_undo_delete_button_gone).to be true }
          it("still shows section #{section.id} among available sections when un-staged for deleting") { expect(section_still_available).to be true }
        end

        # ADDING SECTIONS

        masquerade ?
            @official_sections_page.load_embedded_tool(@driver, @course) :
            @official_sections_page.load_standalone_tool(@course)
        @official_sections_page.click_edit_sections
        @official_sections_page.add_sections(@course, sections_to_add_delete)

        added_sections_updating_msg = @official_sections_page.updating_sections_msg_element.when_visible Utils.short_wait
        added_sections_updated_msg = @official_sections_page.sections_updated_msg_element.when_visible Utils.long_wait

        @official_sections_page.close_section_update_success

        add_success_msg_closed = @official_sections_page.sections_updated_msg_element.when_not_visible Utils.short_wait
        total_sections_with_adds = @official_sections_page.current_sections_count

        it("shows an 'updating' message when sections #{section_ids_to_add_delete} are being added to course site #{@course.site_id}") { expect(added_sections_updating_msg).to be_truthy }
        it("shows an 'updated' message when sections #{section_ids_to_add_delete} have been added to course site #{@course.site_id}") { expect(added_sections_updated_msg).to be_truthy }
        it("allows the user to close an 'update success' message when sections #{section_ids_to_add_delete} have been added to course site #{@course.site_id}") { expect(add_success_msg_closed).to be_truthy }
        it("shows the right number of current sections when sections #{section_ids_to_add_delete} have been added to course site #{@course.site_id}") { expect(total_sections_with_adds).to eql(sections.length) }

        sections_to_add_delete.each do |section|
          section_added = @official_sections_page.current_section_id_element(section).exists?
          it("shows added section #{section.id} among current sections on course site #{@course.site_id}") { expect(section_added).to be true }
        end

        # TODO - SECTIONS ADDED TO ROSTER PHOTOS TOOL
        # TODO - SECTIONS ADDED TO FIND PERSON TO ADD TOOL
        # TODO - SECTIONS ADDED TO E-GRADES EXPORT TOOL

        # DELETING SECTIONS

        masquerade ?
            @official_sections_page.load_embedded_tool(@driver, @course) :
            @official_sections_page.load_standalone_tool(@course)
        @official_sections_page.click_edit_sections
        @official_sections_page.delete_sections sections_to_add_delete

        deleted_sections_updating_msg = @official_sections_page.updating_sections_msg_element.when_visible Utils.short_wait
        deleted_sections_updated_msg = @official_sections_page.sections_updated_msg_element.when_visible Utils.long_wait

        @official_sections_page.close_section_update_success

        delete_success_msg_closed = @official_sections_page.sections_updated_msg_element.when_not_visible Utils.short_wait
        total_sections_without_deletes = @official_sections_page.current_sections_count

        it("shows an 'updating' message when sections #{section_ids_to_add_delete} are being added to course site #{@course.site_id}") { expect(deleted_sections_updating_msg).to be_truthy }
        it("shows an 'updated' message when sections #{section_ids_to_add_delete} have been added to course site #{@course.site_id}") { expect(deleted_sections_updated_msg).to be_truthy }
        it("allows the user to close an 'update success' message when sections #{section_ids_to_add_delete} have been added to course site #{@course.site_id}") { expect(delete_success_msg_closed).to be_truthy }
        it("shows the right number of current sections when sections #{section_ids_to_add_delete} have been added to course site #{@course.site_id}") { expect(total_sections_without_deletes).to eql(sections_for_site.length) }

        sections_to_add_delete.each do |section|
          section_deleted = !@official_sections_page.current_section_id_element(section).exists?
          it("shows added section #{section.id} among current sections on course site #{@course.site_id}") { expect(section_deleted).to be true }
        end

        # TODO - SECTIONS REMOVED FROM ROSTER PHOTOS TOOL
        # TODO - SECTIONS REMOVED FROM FIND PERSON TO ADD TOOL
        # TODO - SECTIONS REMOVED FROM E-GRADES EXPORT TOOL

        # CHECK USER ROLE ACCESS TO THE TOOL FOR ONE COURSE

        if test_data == test_course_data.last

          # Load test user data and add each to the site
          test_user_data = Utils.load_test_users.select { |user| user['tests']['official_sections'] }
          lead_ta = User.new test_user_data.find { |data| data['role'] == 'Lead TA' }
          ta = User.new test_user_data.find { |data| data['role'] == 'TA' }
          designer = User.new test_user_data.find { |data| data['role'] == 'Designer' }
          observer = User.new test_user_data.find { |data| data['role'] == 'Observer' }
          reader = User.new test_user_data.find { |data| data['role'] == 'Reader' }
          student = User.new test_user_data.find { |data| data['role'] == 'Student' }
          waitlist = User.new test_user_data.find { |data| data['role'] == 'Waitlist Student' }

          [lead_ta, ta, designer, reader, observer, student, waitlist].each do |user|
            masquerade ?
                @course_add_user_page.load_embedded_tool(@driver, @course) :
                @course_add_user_page.load_standalone_tool(@course)
            @course_add_user_page.search(user.uid, 'CalNet UID')
            @course_add_user_page.add_user_by_uid(user, sections_for_site.first)
          end

          # Check each user role's access to the tool
          [lead_ta, ta, designer, reader, observer, student, waitlist].each do |user|
            if masquerade
              @canvas.masquerade_as(user, @course)
              @official_sections_page.load_embedded_tool(@driver, @course)
            else
              @splash_page.basic_auth user.uid
              @official_sections_page.load_standalone_tool @course
            end
            if ['Lead TA', 'TA', 'Designer'].include? user.role
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
        it("encountered an error for #{@course.code}") { fail }
        logger.error "#{e.message}#{"\n"}#{e.backtrace.join("\n")}"
        Utils.save_screenshot(@driver, test_id, @teacher.uid)
        @canvas.delete_course(@driver, @course) if masquerade && @course.site_id
      end
    end
  rescue => e
    it('encountered an error') { fail }
    logger.error "#{e.message}#{"\n"}#{e.backtrace.join("\n")}"
  ensure
    Utils.quit_browser @driver
  end

end
