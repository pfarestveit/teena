require_relative '../../util/spec_helper'

include Logging

describe 'bCourses Official Sections tool' do

  begin
    test = RipleyTestConfig.new
    test.official_sections
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
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasPage.new @driver
    @canvas_api = CanvasAPIPage.new @driver
    @splash_page = RipleySplashPage.new @driver
    @create_course_site = RipleyCreateCourseSitePage.new @driver
    @add_user = RipleyAddUserPage.new @driver
    @official_sections = RipleyOfficialSectionsPage.new @driver

    @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
    section_ids = @canvas_api.get_course_site_sis_section_ids ENV['SITE'] if ENV['SITE']
    site = test.get_single_test_site section_ids

    if ENV['SITE'] && site.course.sections == site.sections
      it('cannot be tested using the given course site, since it already has all sections') { fail }
    else
      @canvas.add_ripley_tools RipleyTool::TOOLS.select(&:account)
      teacher = site.course.teachers.first
      # TODO revert to current term when Ripley switches term
      term_courses = RipleyUtils.get_instructor_term_courses(teacher, test.next_term)
      site.sections = site.sections.select &:primary unless ENV['SITE']
      if site.sections == site.course.sections
        sections_to_add_delete = if site.sections.all?(&:primary) || site.sections.none?(&:primary)
                                   site.sections[1..-1]
                                 else
                                   site.sections.select { |s| !s.primary }
                                 end
        site.sections = site.sections.reject { |s| sections_to_add_delete.include? s }
      else
        sections_to_add_delete = site.course.sections - site.sections
      end

      roles = ['Teacher', 'Lead TA', 'TA', 'Student', 'Waitlist Student']
      @canvas.set_canvas_ids([teacher] + non_teachers)
      @canvas_api.get_support_admin_canvas_id test.canvas_admin
      @canvas.masquerade_as teacher

      logger.info "Sections to add/delete are #{sections_to_add_delete.map &:id}"

      if site.site_id
        @canvas.load_course_site site
      else
        @create_course_site.provision_course_site site
        @canvas.publish_course_site site
      end

      @canvas.load_course_sections site
      @canvas.expand_official_sections_notice
      title = 'IT - How do I add or remove a section roster from my course site?'
      official_sections_link = @canvas.external_link_valid?(@canvas.official_sections_help_link_element, title)
      it('shows a link to the official sections help page on the course site') { expect(official_sections_link).to be true }

      # STATIC VIEW

      @official_sections.load_embedded_tool teacher
      @official_sections.select_site_and_manage site

      initial_sec_count = site.sections.length
      static_section_count = @official_sections.static_sections_count
      it('shows all the sections currently on the course site') { expect(static_section_count).to eql(initial_sec_count) }
      site.sections.each do |section|
        static_sec = @official_sections.static_section_data section
        static_del_btn_exists = @official_sections.section_delete_button(section).exists?
        static_instr = @official_sections.expected_instructors section
        it("shows the course code for static section #{section.id}") { expect(static_sec[:course]).to eql(section.course) }
        it("shows the section label for static section #{section.id}") { expect(static_sec[:label]).to eql(section.label) }
        it("shows the section id for static section #{section.id}") { expect(static_sec[:id]).to eql(section.id) }
        it("shows the section schedules for static section #{section.id}") { expect(static_sec[:schedules]).to eql(section.schedules) }
        it("shows the section locations for static section #{section.id}") { expect(static_sec[:locations]).to eql(section.locations) }
        it("shows the section instructors for static section #{section.id}") { expect(static_sec[:instructors]).to eql(static_instr) }
        it("shows no Delete button for static section #{section.id}") { expect(static_del_btn_exists).to be false }
      rescue => e
        Utils.log_error e
        it("hit an error verifying site #{site.site_id} section #{section.id}") { fail Utils.error(e) }
      end

      # EDIT VIEW

      @official_sections.click_edit_sections

      # Current site sections

      current_sections_count = @official_sections.current_sections_count
      it('shows all the sections currently on the course site') { expect(current_sections_count).to eql(initial_sec_count) }
      site.sections.each do |section|
        current_sec = @official_sections.current_section_data section
        current_instr = @official_sections.expected_instructors section
        current_del_btn_exists = @official_sections.section_delete_button(section).exists?
        it("shows the course code for current section #{section.id}") { expect(current_sec[:course]).to eql(section.course) }
        it("shows the section label for current section #{section.id}") { expect(current_sec[:label]).to eql(section.label) }
        it("shows the section id for current section #{section.id}") { expect(current_sec[:id]).to eql(section.id) }
        it("shows the section schedules for current section #{section.id}") { expect(current_sec[:schedules]).to eql(section.schedules) }
        it("shows the section locations for current section #{section.id}") { expect(current_sec[:locations]).to eql(section.locations) }
        it("shows the section instructors for current section #{section.id}") { expect(current_sec[:instructors]).to eql(current_instr) }
        it("shows a Delete button for current section #{section.id}") { expect(current_del_btn_exists).to be true }
      end

      # Available sections - current course(s)

      logger.warn "Site sections are #{site.sections.map &:id}"
      logger.warn "Course sections are #{site.course.sections.map &:id}"
      course_expanded = @official_sections.available_sections_table(site.course, site.sections.first).exists?
      course_section_count = site.course.sections.length
      existing_sections_count = @official_sections.available_sections_count(site.course, site.sections.first)
      save_button_enabled = @official_sections.save_changes_button_element.enabled?
      it('shows an expanded view of courses with sections already in the course site') { expect(course_expanded).to be true }
      it('shows all the sections in the course') { expect(existing_sections_count).to eql(course_section_count) }
      it('shows a disabled save button when no changes have been made in the course site') { expect(save_button_enabled).to be false }

      site.course.sections.each do |section|
        logger.info "Checking course section #{section.id}"
        avail_section_present = @official_sections.available_section_row(site.course, section).exists?
        avail_section_button_exists = @official_sections.section_add_button(section).exists?
        it("shows section #{section.id} is available for the course site") { expect(avail_section_present).to be true }
        if site.sections.include? section
          it("shows no Add button for section #{section.id}") { expect(avail_section_button_exists).to be false }
        else
          it("shows an Add button for section #{section.id}") { expect(avail_section_button_exists).to be true }
        end
      end

      # Available sections - other course(s)

      term_courses.each do |course|
        logger.info "Checking visible data for #{course.term.name} #{course.code}"
        available_course_title = @official_sections.available_sections_course_title course
        available_course_expanded = @official_sections.expand_available_course_sections(course, course.sections.first)
        it("shows the right course title for #{course.code}") { expect(available_course_title).to include(course.title.gsub(':', '')) }
        it("shows no blank course title for #{course.code}") { expect(available_course_title.empty?).to be false }
        it("allows the user to to expand the available sections for #{course.code}") { expect(available_course_expanded).to be_truthy }

        course.sections.each do |section|
          available_sec = @official_sections.available_section_data(course, section)
          available_instr = @official_sections.expected_instructors section
          available_sec_mode = available_sec[:label].split('(').last.gsub(')', '')
          it("shows the right course code for #{course.code} available section #{section.id}") { expect(available_sec[:course]).to eql(section.course) }
          it("shows no blank course code for #{course.code} available section #{section.id}") { expect(available_sec[:course].empty?).to be false }
          it("shows the right label for #{course.code} available section #{section.id}") { expect(available_sec[:label]).to eql(section.label) }
          it("shows no blank label for #{course.code} available section #{section.id}") { expect(available_sec[:label].empty?).to be false }
          it("shows the right schedules for #{course.code} available section #{section.id}") { expect(available_sec[:schedules]).to eql(section.schedules) }
          it("shows the right locations for #{course.code} available section #{section.id}") { expect(available_sec[:locations]).to eql(section.locations) }
          it("shows the right instructors for #{course.code} available section #{section.id}") { expect(available_sec[:instructors]).to eql(available_instr) }
          it "shows a valid instruction mode for #{course.code} section #{section.id}" do
            expect(['In Person', 'Online', 'Hybrid', 'Flexible', 'Remote', 'Web-based']).to include(available_sec_mode)
          end
        rescue => e
          Utils.log_error e
          it("hit an error verifying course #{course.code} section #{section.id}") { fail Utils.error(e) }
        end

        collapsed_sections = @official_sections.collapse_available_sections(course, course.sections.first)
        it("allows the user to collapse the available sections for #{course.code}") { expect(collapsed_sections).to be_truthy }
      rescue => e
        Utils.log_error e
        it("hit an error verifying course #{course.code}") { fail Utils.error(e) }
      end

      # ADDING - Staging, Un-staging

      @official_sections.expand_available_course_sections(site.course, site.course.sections.first)
      @section = sections_to_add_delete.last
      @official_sections.click_add_section(site.course, @section)
      staged_link_sec = @official_sections.current_section_row(@section).exists?
      staged_link_sec_add_button = @official_sections.section_add_button(@section).exists?
      staged_link_sec_msg = @official_sections.section_added_element(site.course, @section).exists?
      it('moves the section from available to current sections') { expect(staged_link_sec).to be true }
      it('hides the add button for the section') { expect(staged_link_sec_add_button).to be false }
      it('shows an added message for the section') { expect(staged_link_sec_msg).to be true }

      @section = sections_to_add_delete.last
      @official_sections.click_undo_add_section @section
      un_staged_link_sec = @official_sections.current_section_row(@section).exists?
      un_staged_link_sec_add_button = @official_sections.section_add_button(@section).exists?
      it('undo-add button removes the section from current sections') { expect(un_staged_link_sec).to be false }
      it('reveals the add button for the section when un-staged for adding') { expect(un_staged_link_sec_add_button).to be true }

      # DELETING - Staging, Un-staging

      @section = site.sections.first
      @official_sections.click_delete_section @section
      staged_unlink_sec = @official_sections.current_section_row(@section).exists?
      staged_unlink_sec_undo_button = @official_sections.section_undo_delete_button(@section).exists?
      it('removes the section from current sections') { expect(staged_unlink_sec).to be false }
      it('reveals the undo-delete button for the section') { expect(staged_unlink_sec_undo_button).to be true }

      @section = site.sections.first
      @official_sections.click_undo_delete_section(@section)
      un_staged_unlink_sec = @official_sections.current_section_row(@section).exists?
      un_staged_unlink_sec_undo_button = @official_sections.section_undo_delete_button(@section).exists?
      un_staged_unlink_sec_available = @official_sections.available_section_row(site.course, @section).exists?
      it('restores the section to current sections') { expect(un_staged_unlink_sec).to be true }
      it('hides the undo-delete button for the section') { expect(un_staged_unlink_sec_undo_button).to be false }
      it('still shows the section among available sections') { expect(un_staged_unlink_sec_available).to be true }

      # ADDING - SIS import

      initial_population = @canvas.visible_user_section_data site
      @official_sections.load_embedded_tool teacher
      @official_sections.select_site_and_manage site
      @official_sections.click_edit_sections
      @official_sections.add_sections(site, sections_to_add_delete)
      site.sections += sections_to_add_delete
      updated_add_count = site.sections.length
      updating_add_msg = @official_sections.verify_block { @official_sections.updating_sections_msg_element.when_visible Utils.medium_wait }
      updated_add_msg = @official_sections.verify_block { @official_sections.sections_updated_msg_element.when_visible Utils.long_wait }
      updated_add_msg_closed = @official_sections.verify_block do
        @official_sections.close_section_update_success
        @official_sections.sections_updated_msg_element.when_not_visible Utils.short_wait
      end
      updated_added_sections_count = @official_sections.static_sections_count
      it('shows an updating message when sections are being added to the course site') { expect(updating_add_msg).to be true }
      it('shows an updated message when sections have been added to the course site') { expect(updated_add_msg).to be true }
      it('allows the user to close an update success message after adding sections') { expect(updated_add_msg_closed).to be true }
      it('shows the right number of current sections after adding sections') { expect(updated_added_sections_count).to eql(updated_add_count) }

      sections_to_add_delete.each do |section|
        section_added = @official_sections.static_section_row(section).exists?
        it("shows added section #{section.id} among current sections on the course site") { expect(section_added).to be true }
      end

      # FIND A PERSON TO ADD

      @add_user.load_embedded_tool site
      @add_user.search(Utils.oski_uid, 'CalNet UID')
      @add_user.wait_until(Utils.medium_wait) { @add_user.course_section_options&.any? }
      add_user_sec_count = @add_user.course_section_options.length
      expected_sec_count = site.sections.length
      it('shows the added sections on Find a Person to Add') { expect(add_user_sec_count).to eql(expected_sec_count) }

      # CANVAS USERS

      @canvas.wait_for_enrollment_import(site, roles)
      visible_users_post_add = @canvas.visible_user_section_data site
      expected_instructors_post_add = RipleyUtils.expected_instr_section_data(site, sections_to_add_delete)
      expected_students_post_add = RipleyUtils.expected_student_section_data(site, sections_to_add_delete)
      expected_users_post_add = (initial_population + expected_instructors_post_add + expected_students_post_add).uniq
      logger.warn "Unexpected users after adding sections: #{visible_users_post_add - expected_users_post_add}"
      logger.warn "Missing users after adding sections: #{expected_users_post_add - visible_users_post_add}"
      it('adds no unexpected users to the site') { expect(visible_users_post_add - expected_users_post_add).to be_empty }
      it('neglects no expected users on the site') { expect(expected_users_post_add - visible_users_post_add).to be_empty }

      visible_sections = @canvas.section_label_elements.map(&:text).uniq
      added_sections = sections_to_add_delete.map { |s| "#{s.course} #{s.label}" }
      site_sections_added = @canvas.verify_block { @canvas.wait_until(1) { (visible_sections & added_sections).any? } }
      it('adds all the sections to the site') { expect(site_sections_added).to be true }

      # CANVAS SECTIONS

      updated_sections_post_add = site.sections.map &:id
      section_ids_post_add = @canvas_api.get_course_site_section_ccns site.site_id
      it('shows all the right added sections in the Canvas API') { expect(section_ids_post_add.sort).to eql(updated_sections_post_add.sort) }

      # DELETING - SIS import

      @official_sections.load_embedded_tool teacher
      @official_sections.select_site_and_manage site
      @official_sections.click_edit_sections
      @official_sections.delete_sections sections_to_add_delete
      site.sections -= sections_to_add_delete
      updated_delete_count = site.sections.length
      updating_delete_msg = @official_sections.verify_block { @official_sections.updating_sections_msg_element.when_visible Utils.short_wait }
      updated_delete_msg = @official_sections.verify_block { @official_sections.sections_updated_msg_element.when_visible Utils.long_wait }
      updated_delete_msg_closed = @official_sections.verify_block do
        @official_sections.close_section_update_success
        @official_sections.sections_updated_msg_element.when_not_visible Utils.short_wait
      end
      updated_deleted_sections_count = @official_sections.static_sections_count
      it('shows an updating message when sections are being deleted') { expect(updating_delete_msg).to be true }
      it('shows an updated message when sections have been deleted') { expect(updated_delete_msg).to be true }
      it('allows the user to close an update success message when sections have been deleted') { expect(updated_delete_msg_closed).to be true }
      it('shows the right number of current sections when sections have been deleted') { expect(updated_deleted_sections_count).to eql(updated_delete_count) }

      sections_to_add_delete.each do |section|
        section_present = @official_sections.static_section_row(section).exists?
        it("shows added section #{section.id} among current sections on the course site") { expect(section_present).to be false }
      end

      # FIND A PERSON TO ADD

      @add_user.load_embedded_tool site
      @add_user.search(Utils.oski_uid, 'CalNet UID')
      @add_user.wait_until(Utils.medium_wait) { @add_user.course_section_options&.any? }
      add_user_sec_count_del = @add_user.course_section_options.length
      it('shows no deleted sections on Find a Person to Add') { expect(add_user_sec_count_del).to eql(site.sections.length) }

      # CANVAS USERS

      @canvas.wait_for_enrollment_import(site, roles)
      visible_users_post_del = @canvas.visible_user_section_data site
      logger.warn "Unexpected users after removing sections: #{visible_users_post_del - initial_population}"
      logger.warn "Missing users after removing sections: #{initial_population - visible_users_post_del}"
      it('leaves no unexpected users on the site') { expect(visible_users_post_del - initial_population).to be_empty }
      it('removes no expected users from the site') { expect(initial_population - visible_users_post_del).to be_empty }

      visible_sections = @canvas.section_label_elements.map(&:text).uniq
      deleted_sections = sections_to_add_delete.map { |s| "#{s.course} #{s.label}" }
      site_sections_removed = @canvas.verify_block { @canvas.wait_until(1) { (visible_sections & deleted_sections).empty? } }
      it('removes the sections from the site') { expect(site_sections_removed).to be true }

      # CANVAS SECTIONS

      updated_sections_post_delete = site.sections.map &:id
      section_ids_post_delete = @canvas_api.get_course_site_section_ccns site.site_id
      it 'shows all the right added sections in the Canvas API' do
        expect(section_ids_post_delete.sort).to eql(updated_sections_post_delete.sort)
      end

      @canvas.stop_masquerading
      non_teachers.each { |u| logger.info "Test user to add: #{u.inspect}" }
      non_teachers.each do |user|
        @add_user.load_embedded_tool site
        @add_user.search(user.uid, 'CalNet UID')
        @add_user.add_user_by_uid(user, site.sections.first)
      end

      support_admin_access = @canvas.verify_block do
        @canvas.masquerade_as(test.canvas_admin, site)
        @official_sections.load_embedded_tool test.canvas_admin
        @official_sections.enter_site_and_manage site
        @official_sections.static_view_sections_table.when_visible Utils.medium_wait
        @official_sections.edit_sections_button_element.when_not_visible 1
      end
      it('allows a Support Admin read only access to the tool') { expect(support_admin_access).to be true }

      edit_access = @canvas.verify_block do
        @canvas.masquerade_as(test.lead_ta, site)
        @official_sections.load_embedded_tool test.lead_ta
        @official_sections.select_site_and_manage site
        @official_sections.click_edit_sections
      end
      it("allow a #{test.lead_ta.role} full access to the tool") { expect(edit_access).to be true }

      [test.ta, test.designer].each do |user|
        no_edit_access = @canvas.verify_block do
          @canvas.masquerade_as(user, site)
          @official_sections.load_embedded_tool user
          @official_sections.select_site_and_manage site
          @official_sections.static_view_sections_table.when_visible Utils.medium_wait
          @official_sections.edit_sections_button_element.when_not_visible 1
        end
        it("allow a #{user.role} read only access to the tool") { expect(no_edit_access).to be true }
      end

      [test.reader, test.observer, test.students.first, test.wait_list_student].each do |user|
        access = @canvas.verify_block do
          @canvas.masquerade_as(user, site)
          @official_sections.load_embedded_tool user
          @official_sections.select_site_and_manage site
        end
        it("deny a #{user.role} access to the tool") { expect(access).to be false }
      end

      # SECTION NAME UPDATES

      @canvas.stop_masquerading
      @canvas.set_course_sis_id site
      @section = sections_to_add_delete.first
      section_id = "SEC:#{site.course.term.code}-#{@section.id}"
      section_name = "#{site.course.code} FAKE LABEL"
      csv = Utils.create_test_output_csv("section-#{site.course.code}.csv", %w(section_id course_id name status start_date end_date))
      Utils.add_csv_row(csv, [section_id, site.course.sis_id, section_name, 'active', nil, nil])
      @canvas.upload_sis_imports([csv])

      section_name_mismatch_msg = @canvas.verify_block do
        @canvas.masquerade_as teacher
        @official_sections.load_embedded_tool teacher
        @official_sections.select_site_and_manage site
        @official_sections.click_edit_sections
        @official_sections.section_name_msg_element.when_visible(Utils.short_wait)
      end
      it('shows a section name mismatch message when the section name has changed') { expect(section_name_mismatch_msg).to be true }

      section_name_mismatch = @official_sections.verify_block do
        @official_sections.click_update_section @section
        @official_sections.save_changes_and_wait_for_success
        @official_sections.click_edit_sections
        @official_sections.section_name_msg_element.when_present 2
      end
      it('shows no section name mismatch when the section has been updated') { expect(section_name_mismatch).to be false }
    end

  rescue => e
    Utils.log_error e
    it('hit an error initializing') { fail Utils.error(e) }
  ensure
    Utils.quit_browser @driver
  end
end
