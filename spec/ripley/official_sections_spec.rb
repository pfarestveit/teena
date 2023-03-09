require_relative '../../util/spec_helper'

standalone = ENV['STANDALONE']

include Logging

test = RipleyTestConfig.new
site = test.get_single_test_site
teacher = site.course.teachers.first
sections_for_site = site.course.sections.select { |s| site.sections.include? s }
sections_to_add_delete = (site.course.sections - sections_for_site)
term_courses = RipleyUtils.get_instructor_term_courses(teacher, test.current_term)

describe 'bCourses Official Sections tool', order: :defined do

  before(:all) do
    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasPage.new @driver
    @splash_page = RipleySplashPage.new @driver
    @site_creation_page = RipleySiteCreationPage.new @driver
    @create_course_site_page = RipleyCreateCourseSitePage.new @driver
    @course_add_user_page = RipleyAddUserPage.new @driver
    @official_sections_page = RipleyOfficialSectionsPage.new @driver

    if standalone
      @splash_page.dev_auth teacher.uid
      @create_course_site_page.provision_course_site(site, { standalone: true })
      @create_course_site_page.wait_for_standalone_site_id(site, @splash_page)
    else
      @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
      @canvas.set_canvas_ids([teacher] + site.manual_members)
      @canvas.masquerade_as teacher
      @create_course_site_page.provision_course_site site
      @canvas.publish_course_site site
    end
  end

  after(:all) { Utils.quit_browser @driver }

  unless standalone
    it 'shows a link to the official sections help page on the course site' do
      @canvas.load_course_sections site
      @canvas.expand_official_sections_notice
      title = 'IT - How do I add or remove a section roster from my course site?'
      expect(@canvas.external_link_valid?(@canvas.official_sections_help_link_element, title)).to be true
    end
  end

  context 'when viewing sections' do

    before(:all) do
      standalone ? @official_sections_page.load_standalone_tool site : @official_sections_page.load_embedded_tool site
    end

    it 'shows all the sections currently on the course site' do
      expect(@official_sections_page.current_sections_count).to eql(sections_for_site.length)
    end

    sections_for_site.each do |section|
      it "shows the course code for section #{section.id}" do
        expect(@official_sections_page.current_section_course section).to eql(section.course)
      end
      it "shows the section label for section #{section.id}" do
        expect(@official_sections_page.current_section_label section).to eql(section.label)
      end
      it "shows no Delete button for section #{section.id}" do
        expect(@official_sections_page.section_delete_button(section).exists?).to be false
      end
    end
  end

  context 'when editing sections' do

    before(:all) { @official_sections_page.click_edit_sections }

    it 'shows a collapsed maintenance notice' do
      @official_sections_page.maintenance_notice_button_element.when_present Utils.short_wait
      expect(@official_sections_page.maintenance_detail_element.visible?).to be false
    end

    it 'allows the user to reveal an expanded maintenance notice' do
      @official_sections_page.maintenance_notice_button
      @official_sections_page.maintenance_detail_element.when_visible Utils.short_wait
    end

    unless standalone
      it 'offers a link to the bCourses service page in the expanded maintenance notice' do
        title = 'bCourses | Research, Teaching, and Learning'
        expect(@official_sections_page.external_link_valid?(@official_sections_page.bcourses_service_link_element, title).to be true)
      end
    end

    it 'shows all the sections currently on the course site' do
      @official_sections_page.switch_to_canvas_iframe unless standalone
      expect(@official_sections_page.current_sections_count).to eql(site[:sections_for_site].length)
    end

    sections_for_site.each do |section|
      it "shows section #{section.id} is already in the course site" do
        expect(@official_sections_page.current_section_id_element(section).exists?).to be true
      end
      it "shows a Delete button for section #{section.id}" do
        expect(@official_sections_page.section_delete_button(section).exists?).to be true
      end
    end

    it 'shows an expanded view of courses with sections already in the course site' do
      expect(@official_sections_page.available_sections_table(site.code).exists?).to be true
    end
    it 'shows all the sections in the course' do
      expect(@official_sections_page.available_sections_count site).to eql(site.sections.length)
    end
    it 'shows a disabled save button when no changes have been made in the course site' do
      expect(@official_sections_page.save_changes_button_element.enabled?).to be false
    end

    site.course.sections.each do |section|
      it "shows section #{section.id} is available for the course site" do
        expect(@official_sections_page.available_section_id_element(site.code, section.id).exists?).to be true
      end
      if sections_to_add_delete.include? section
        it "shows an Add button for section #{section.id}" do
          expect(@official_sections_page.section_add_button(site, section).exists?).to be true
        end
      else
        it "shows no Add button for section #{section.id}" do
          expect(@official_sections_page.section_add_button(site, section).exists?).to be false
        end
      end
    end

    term_courses.each do |course|
      it "shows the right course title for #{course.code}" do
        visible = @official_sections_page.available_sections_course_title course.code
        expect(visible).to eql(course.title)
      end
      it "shows no blank course title for #{course.code}" do
        expect(course.title.empty?).to be false
      end
      it "allows the user to to expand the available sections for #{course.code}" do
        ui_sections_expanded = @official_sections_page.expand_available_sections course.code
        expect(ui_sections_expanded).to be_truthy
      end

      course.sections.each do |section|
        it "shows the right course code for #{course.code} section #{section.id}" do
          visible = @official_sections_page.available_section_data(course.code, section.id)[:code]
          expect(visible).to eql(section.course)
        end
        it "shows no blank course code for #{course.code} section #{section.id}" do
          visible = @official_sections_page.available_section_data(course.code, section.id)[:code]
          expect(visible.empty?).to be false
        end
        it "shows the right section labels for #{course.code} section #{section.id}" do
          visible = @official_sections_page.available_section_data(course.code, section.id)[:label]
          expect(visible).to eql(section.label)
        end
        it "shows no blank section labels for #{course.code} section #{section.id}" do
          visible = @official_sections_page.available_section_data(course.code, section.id)[:label]
          expect(visible.empty?).to be false
        end
        it "shows the right section schedules for #{course.code} section #{section.id}" do
          visible = @official_sections_page.available_section_data(course.code, section.id)[:schedules]
          expect(visible).to eql(section.schedules)
        end
        it "shows the right section locations for #{course.code} section #{section.id}" do
          visible = @official_sections_page.available_section_data(course.code, section.id)[:locations]
          expect(visible).to eql(section.locations)
        end
        it "shows an expected instruction mode for #{course.code} section #{section.id}" do
          mode = @official_sections_page.available_section_data(course.code, section.id)[:label].split('(').last.gsub(')', '')
          expect(['In Person', 'Online', 'Hybrid', 'Flexible', 'Remote', 'Web-based']).to include(mode)
        end
      end

      it "allows the user to collapse the available sections for #{course.code}" do
        expect(@official_sections_page.collapse_available_sections course.code).to be_truthy
      end
    end
  end

  context 'when staging a section for adding' do

    before(:all) do
      @official_sections_page.expand_available_sections site.course.code
      @section = sections_to_add_delete.last
      @official_sections_page.click_add_section(site.course, @section)
    end

    it 'moves the section from available to current sections' do
      expect(@official_sections_page.current_section_id_element(@section).exists?).to be true
    end
    it 'hides the add button for the section' do
      expect(@official_sections_page.section_add_button(site.course, @section).exists?).to be false
    end
    it 'shows an added message for the section' do
      expect(@official_sections_page.section_added_element(site.course, @section).exists?).to be true
    end
  end

  context 'when un-staging a section for adding' do

    before(:all) do
      @section = sections_to_add_delete.last
      @official_sections_page.click_undo_add_section section
    end

    it 'undo-add button removes the section from current sections' do
      expect(@official_sections_page.current_section_id_element(@section).exists?).to be false
    end
    it 'reveals the add button for the section when un-staged for adding' do
      expect(@official_sections_page.section_add_button(site, @section).exists?).to be true
    end
  end

  context 'when staging a section for deleting' do

    before(:all) do
      @section = sections_for_site.first
      @official_sections_page.click_delete_section @section
    end

    it 'removes the section from current sections' do
      expect(@official_sections_page.current_section_id_element(@section).exists?).to be false
    end
    it 'reveals the undo-delete button for the section' do
      expect(@official_sections_page.section_undo_delete_button(site.course, @section).exists?).to be true
    end
  end

  context 'when un-staging a section for deleting' do

    before(:all) do
      @section = sections_for_site.first
      @official_sections_page.click_undo_delete_section(site.course, @section)
    end

    it 'restores the section to current sections' do
      expect(@official_sections_page.current_section_id_element(@section).exists?).to be true
    end
    it 'hides the undo-delete button for the section' do
      expect(@official_sections_page.section_undo_delete_button(site.course, @section).exists?).to be false
    end
    it 'still shows the section among available sections' do
      expect(@official_sections_page.available_section_id_element(site.course, @section).exists?).to be true
    end
  end

  context 'when sections have been added' do
    before(:all) do
      standalone ? @official_sections_page.load_standalone_tool(site) : @official_sections_page.load_embedded_tool(site)
      @official_sections_page.click_edit_sections
      @official_sections_page.add_sections(site, sections_to_add_delete)
    end

    it 'shows an updating message when sections are being added to the course site' do
      @official_sections_page.updating_sections_msg_element.when_visible Utils.medium_wait
    end
    it 'shows an updated message when sections have been added to the course site' do
      @official_sections_page.sections_updated_msg_element.when_visible Utils.long_wait
    end
    it 'allows the user to close an update success message when sections have been added to the course site' do
      @official_sections_page.close_section_update_success
      @official_sections_page.sections_updated_msg_element.when_not_visible Utils.short_wait
    end
    it 'shows the right number of current sections when sections have been added to the course site' do
      expect(@official_sections_page.current_sections_count).to eql(site.sections.length)
    end

    sections_to_add_delete.each do |section|
      it "shows added section #{section.id} among current sections on the course site" do
        expect(@official_sections_page.current_section_id_element(section).exists?).to be true
      end
    end

    context 'and a user views Find a Person to Add' do

      before(:all) do
        standalone ? @course_add_user_page.load_standalone_tool(site) : @course_add_user_page.load_embedded_tool(site)
        @course_add_user_page.search(Utils.oski_uid, 'CalNet UID')
      end

      it 'shows the right number of current sections on Find a Person to Add when sections have been added to the course site' do
        @course_add_user_page.wait_until(Utils.medium_wait) { @course_add_user_page.course_section_options.length == site.sections.length }
      end
    end

    unless standalone
      context 'and a user views the course site enrollment' do

        it 'adds all the sections to the site' do
          tries = 5
          begin
            tries -= 1
            sleep Utils.short_wait
            @canvas.load_users_page site
            @canvas.load_all_students site
            visible_sections = @canvas.section_label_elements.map(&:text).uniq
            added_sections = sections_to_add_delete.map { |s| "#{s.course} #{s.label}" }
            @canvas.wait_until(1) { (visible_sections & added_sections).any? }
          rescue
            tries.zero? ? fail : retry
          end
        end
      end
    end
  end

  context 'when sections have been deleted' do

    before(:all) do
      standalone ? @official_sections_page.load_standalone_tool(site) : @official_sections_page.load_embedded_tool(site)
      @official_sections_page.click_edit_sections
      @official_sections_page.delete_sections sections_to_add_delete
    end

    it 'shows an updating message when sections are being added to the course site' do
      @official_sections_page.updating_sections_msg_element.when_visible Utils.short_wait
    end
    it 'shows an updated message when sections have been added to the course site' do
      @official_sections_page.sections_updated_msg_element.when_visible Utils.long_wait
    end
    it 'allows the user to close an update success message when sections have been added to the course site' do
      @official_sections_page.close_section_update_success
      @official_sections_page.sections_updated_msg_element.when_not_visible Utils.short_wait
    end
    it 'shows the right number of current sections when sections have been added to the course site' do
      expect(@official_sections_page.current_sections_count).to eql(sections_for_site.length)
    end

    sections_to_add_delete.each do |section|
      it "shows added section #{section.id} among current sections on the course site" do
        expect(@official_sections_page.current_section_id_element(section).exists?).to be false
      end
    end

    context 'and a user views Find a Person to Add' do

      before(:all) do
        standalone ? @course_add_user_page.load_standalone_tool(site) : @course_add_user_page.load_embedded_tool(site)
        @course_add_user_page.search(Utils.oski_uid, 'CalNet UID')
      end

      it 'shows the right number of current sections on Find a Person to Add when sections have been removed from the course site' do
        @course_add_user_page.wait_until(Utils.medium_wait) { @course_add_user_page.course_section_options.length == sections_for_site.length }
      end
    end

    unless standalone
      context 'and a user views the course site enrollment' do

        it 'removes the sections from the site' do
          tries = Utils.short_wait
          begin
            tries -= 1
            sleep Utils.short_wait
            @canvas.load_users_page site
            @canvas.load_all_students site
            visible_sections = @canvas.section_label_elements.map(&:text).uniq
            deleted_sections = sections_to_add_delete.map { |s| "#{s.course} #{s.label}" }
            @canvas.wait_until(1) { (visible_sections & deleted_sections).empty? }
          rescue
            tries.zero? ? fail : retry
          end
        end
      end
    end
  end

  unless standalone
    context 'user permissions' do

      before(:all) do
        @canvas.stop_masquerading
        [test.lead_ta, test.ta, test.designer, test.reader, test.observer, test.students.first, test.wait_list_student].each do |user|
          @course_add_user_page.load_embedded_tool site
          @course_add_user_page.search(user.uid, 'CalNet UID')
          @course_add_user_page.add_user_by_uid(user, sections_for_site.first)
        end
      end

      it 'allow a Lead TA full access to the tool' do
        @canvas.masquerade_as(test.lead_ta, site)
        @official_sections_page.load_embedded_tool site
        @official_sections_page.current_sections_table.when_visible Utils.medium_wait
        @official_sections_page.edit_sections_button_element.when_visible 1
      end

      [test.ta, test.designer].each do |user|
        it "allow a #{user.role} read only access to the tool" do
          @canvas.masquerade_as(user, site)
          @official_sections_page.load_embedded_tool site
          @official_sections_page.current_sections_table.when_visible Utils.medium_wait
          @official_sections_page.edit_sections_button_element.when_not_visible 1
        end
      end

      it 'deny a Reader access to the tool' do
        @canvas.masquerade_as(test.reader, site)
        @official_sections_page.load_embedded_tool site
        @official_sections_page.unexpected_error_element.when_present Utils.medium_wait
        @official_sections_page.current_sections_table.when_not_visible 1
      end

      [test.observer, test.students.first, test.wait_list_student].each do |user|
        it "deny a #{user.role} access to the tool" do
          @canvas.masquerade_as(user, site)
          @official_sections_page.hit_embedded_tool_url site
          @canvas.wait_for_error(@canvas.access_denied_msg_element, @official_sections_page.unexpected_error_element)
        end
      end
    end
  end

  unless standalone
    context 'section name updates' do

      before(:all) do
        @canvas.stop_masquerading
        @canvas.set_course_sis_id site
        @section = sections_to_add_delete.first
        section_id = "SEC:#{Utils.term_name_to_hyphenated_code site.course.term}-#{@section.id}"
        section_name = "#{site.code} FAKE LABEL"
        csv = File.join(Utils.initialize_test_output_dir, "section-#{site.course.code}.csv")
        CSV.open(csv, 'wb') { |heading| heading << %w(section_id course_id name status start_date end_date) }
        Utils.add_csv_row(csv, [section_id, site.course.sis_id, section_name, 'active', nil, nil])
        @canvas.upload_sis_imports([csv])
        RipleyUtils.clear_cache
      end

      it 'shows a section name mismatch message when the section name has changed' do
        @canvas.masquerade_as teacher
        @official_sections_page.load_embedded_tool site
        @official_sections_page.current_sections_table.when_visible Utils.medium_wait
        @official_sections_page.click_edit_sections
        @official_sections_page.section_name_msg_element.when_visible(Utils.short_wait)
      end

      it 'shows no section name mismatch when the section has been updated' do
        @official_sections_page.click_update_section @section
        @official_sections_page.save_changes_and_wait_for_success
        @official_sections_page.click_edit_sections
        expect(@official_sections_page.section_name_msg?).to be false
      end
    end
  end
end
