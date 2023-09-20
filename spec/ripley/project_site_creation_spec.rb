require_relative '../../util/spec_helper'

describe 'bCourses project site', order: :defined do

  include Logging

  test = RipleyTestConfig.new
  project = test.projects

  before(:all) do
    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasPage.new @driver
    @splash_page = RipleySplashPage.new @driver
    @site_creation_page = RipleySiteCreationPage.new @driver
    @create_project_site_page = RipleyCreateProjectSitePage.new @driver
    @find_person_to_add_page = RipleyAddUserPage.new @driver
    @roster_photos_page = RipleyRosterPhotosPage.new @driver
    @official_sections_page = RipleyOfficialSectionsPage.new @driver

    @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
    RipleyTool::TOOLS.each { |t| @canvas.add_ripley_tool t }
    @canvas.set_canvas_ids project.manual_members
    @canvas.masquerade_as test.manual_teacher
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'information' do

    before(:all) do
      @site_creation_page.load_embedded_tool test.manual_teacher
    end

    it 'shows a link to project site help' do
      title = 'bCourses Project Sites | Research, Teaching, and Learning'
      expect(@site_creation_page.external_link_valid?(@site_creation_page.project_help_link_element, title)).to be true
    end

    it 'shows a link to info about other collaboration tools' do
      @site_creation_page.switch_to_canvas_iframe
      title = 'Collaboration Services | bConnected'
      expect(@site_creation_page.external_link_valid?(@site_creation_page.projects_learn_more_link_element, title)).to be true
    end
  end

  describe 'cancellation' do

    it 'returns the user to site creation' do
      @site_creation_page.load_embedded_tool test.manual_teacher
      @site_creation_page.click_create_project_site
      @create_project_site_page.cancel_project_site
      @site_creation_page.create_project_site_link_element.when_present Utils.short_wait
    end
  end

  describe 'creation' do

    it 'requires that a site name be no more than 255 characters' do
      long_name = "#{'A loooooong title' * 15}?"
      @site_creation_page.load_embedded_tool test.manual_teacher
      @site_creation_page.click_create_project_site
      @create_project_site_page.enter_site_name long_name
      expect(@create_project_site_page.site_name_input_element.attribute('value')).to eql(long_name[0..254])
    end

    it 'allows a user to create a project site' do
      project.title = "QA Project Site #{Time.now}"
      @create_project_site_page.create_project_site project.title
      @create_project_site_page.wait_for_site_id project
      @canvas.course_site_heading_element.when_present Utils.short_wait
      expect(@canvas.course_site_heading).to eql("#{project.title}")
    end

    it('redirects to a custom project homepage') { @canvas.project_site_heading_element.when_visible Utils.short_wait }
    it('does not add the Roster Photos tool') { expect(@roster_photos_page.roster_photos_link?).to be false }
    it('does not add the Official Sections tool') { expect(@official_sections_page.official_sections_link?).to be false }
  end

  describe 'user roles' do

    it 'include Owner, Maintainer, and Member in the Add People tool' do
      @canvas.load_users_page project
      @canvas.click_add_people
      options = @canvas.user_role_options
      logger.debug "Available user roles are '#{options}'"
      expect((options & %w(Owner Maintainer Member)).length == 3).to be true
    end

    %w(Owner Maintainer Member).each do |user_role|

      it "include '#{user_role}' in the Find a Person to Add tool" do
        user = User.new uid: Utils.oski_uid,
                        role: user_role
        @find_person_to_add_page.load_embedded_tool project
        @find_person_to_add_page.search(user.uid, 'CalNet UID')
        @find_person_to_add_page.add_user_by_uid user
        @find_person_to_add_page.success_msg_element.when_visible Utils.short_wait
      end
    end
  end

  describe 'user role restrictions' do

    [test.ta, test.staff, test.students.first].each do |user|

      it "allows #{user.role} UID #{user.uid} to see a Create a Site button if permitted to do so" do
        @canvas.masquerade_as user
        @canvas.load_homepage
        has_create_site_button = @canvas.verify_block { @canvas.create_site_link_element.when_visible(Utils.short_wait) }
        (%w(TA Staff).include? user.role) ? (expect(has_create_site_button).to be true) : (expect(has_create_site_button).to be false)
      end

      it "allows #{user.role} UID #{user.uid} to navigate to the tool if permitted to do so" do
        @canvas.masquerade_as user
        @site_creation_page.load_embedded_tool user

        case user.role
        when 'TA'
          logger.debug "Verifying that #{user.role} UID #{user.uid} has access to the project site UI"
          @site_creation_page.click_create_project_site
          expect(@create_project_site_page.site_name_input_element.when_present Utils.short_wait).to be_truthy
        when 'Staff'
          logger.debug "Verifying that #{user.role} UID #{user.uid} has access to the project site UI but not the course site UI"
          @site_creation_page.click_create_project_site
          expect(@create_project_site_page.site_name_input_element.when_present Utils.short_wait).to be_truthy
        else
          logger.debug "Verifying that #{user.role} UID #{user.uid} has access to neither the course nor the project site UIs"
          @site_creation_page.create_course_site_link_element.when_present Utils.short_wait
          expect(@site_creation_page.create_project_site_link_element.disabled?).to be true
        end
      end
    end
  end
end
