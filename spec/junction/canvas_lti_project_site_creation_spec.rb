require_relative '../../util/spec_helper'

describe 'bCourses project site', order: :defined do

  include Logging

  masquerade = ENV['MASQUERADE']

  # Load test data

  test_user_data = Utils.load_test_users.select { |u| u['tests']['create_project_site'] }
  teacher = User.new test_user_data.find { |u| u['role'] == 'Teacher' }
  ta = User.new test_user_data.find { |u| u['role'] == 'TA' }
  staff = User.new test_user_data.find { |u| u['role'] == 'Staff' }
  student = User.new test_user_data.find { |u| u['role'] == 'Student' }
  project = Course.new({})

  before(:all) do
    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasPage.new @driver
    @splash_page = Page::JunctionPages::SplashPage.new @driver
    @site_creation_page = Page::JunctionPages::CanvasSiteCreationPage.new @driver
    @create_project_site_page = Page::JunctionPages::CanvasCreateProjectSitePage.new @driver
    @find_person_to_add_page = Page::JunctionPages::CanvasCourseAddUserPage.new @driver
    @roster_photos_page = Page::JunctionPages::CanvasRostersPage.new @driver
    @official_sections_page = Page::JunctionPages::CanvasCourseManageSectionsPage.new @driver

    if masquerade
      @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
      @canvas.masquerade_as(@driver, teacher)
    else
      @canvas.log_in(@cal_net, Utils.ets_qa_username, Utils.ets_qa_password)
      @splash_page.basic_auth teacher.uid
    end
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'information' do

    before(:all) do
      masquerade ?
          @site_creation_page.load_embedded_tool(@driver, teacher) :
          @site_creation_page.load_standalone_tool
    end

    it('shows a link to project site help') { expect(@site_creation_page.external_link_valid?(@driver, @site_creation_page.projects_learn_more_link_element, 'Service at UC Berkeley')).to be true }

  end

  describe 'creation' do

    before(:each) do
      if masquerade
        @site_creation_page.load_embedded_tool(@driver, teacher)
        @site_creation_page.click_create_project_site
      else
        @create_project_site_page.load_standalone_tool
      end
    end

    it 'requires that a site name be no more than 255 characters' do
      @create_project_site_page.create_project_site "#{'A loooooong title' * 15}?"
      @create_project_site_page.name_too_long_msg_element.when_present Utils.short_wait
    end

    it 'allows a user to create a project site' do
      @create_project_site_page.create_project_site (project.title = "QA Project Site #{Time.now}")
      @canvas.wait_until(Utils.long_wait) { @canvas.current_url.include? "#{Utils.canvas_base_url}/courses" }
      project.site_id = @canvas.current_url.delete "#{Utils.canvas_base_url}/courses/"
      logger.info "Project site ID is #{project.site_id}"
      expect(@canvas.course_site_heading).to eql("Recent Activity in #{project.title}")
    end

    it('does not add the Roster Photos tool') { expect(@roster_photos_page.roster_photos_link?).to be false }
    it('does not add the Official Sections tool') { expect(@official_sections_page.official_sections_link?).to be false }

  end

  describe 'user roles' do

    it 'include Owner, Maintainer, and Member in the Add People tool' do
      if masquerade
        @canvas.load_users_page project
        @canvas.wait_for_load_and_click @canvas.add_people_button_element
        @canvas.user_role_element.when_visible Utils.short_wait
        logger.debug "Available user roles are '#{@canvas.user_role_element.options.map &:text}'"
        expect((@canvas.user_role_element.options.map(&:text) & %w(Owner Maintainer Member)).length == 3).to be true
      else
        logger.warn 'Skipping a test that requires masquerading'
      end
    end

    %w(Owner Maintainer Member).each do |user_role|

      it "include '#{user_role}' in the Find a Person to Add tool" do
        user = User.new({uid: '61889', role: user_role})
        masquerade ?
            @find_person_to_add_page.load_embedded_tool(@driver, project) :
            @find_person_to_add_page.load_standalone_tool(project)
        @find_person_to_add_page.search('61889', 'CalNet UID')
        @find_person_to_add_page.add_user_by_uid user
        @find_person_to_add_page.success_msg_element.when_visible Utils.short_wait
      end
    end
  end

  describe 'user role restrictions' do

    [ta, staff, student].each do |user|

      it "allows #{user.role} UID #{user.uid} to see a Create a Site button if permitted to do so" do
        if masquerade
          @canvas.masquerade_as(@driver, user)
          @canvas.load_homepage
          has_create_site_button = @canvas.verify_block { @canvas.create_site_link_element.when_visible(Utils.short_wait) }
          (%w(TA Staff).include? user.role) ?
              (expect(has_create_site_button).to be true) :
              (expect(has_create_site_button).to be false)
        else
          logger.warn 'Skipping a test that requires masquerading'
        end
      end

      it "allows #{user.role} UID #{user.uid} to navigate to the tool if permitted to do so" do
        if masquerade
          @canvas.masquerade_as(@driver, user)
          @site_creation_page.load_embedded_tool(@driver, user)
        else
          @splash_page.basic_auth user.uid
          @site_creation_page.load_standalone_tool
        end

        case user.role
          when 'TA'
            logger.debug "Verifying that #{user.role} UID #{user.uid} has access to the project site UI"
            @site_creation_page.create_course_site_link_element.when_present Utils.medium_wait
            expect(@site_creation_page.create_course_site_link_element.attribute('aria-disabled')).to eql('false')
            @site_creation_page.click_create_project_site
            expect(@create_project_site_page.site_name_input_element.when_present Utils.short_wait).to be_truthy
          when 'Staff'
            logger.debug "Verifying that #{user.role} UID #{user.uid} has access to the project site UI but not the course site UI"
            @site_creation_page.create_course_site_link_element.when_present Utils.medium_wait
            expect(@site_creation_page.create_course_site_link_element.attribute('aria-disabled')).to eql('true')
            @site_creation_page.click_create_project_site
            expect(@create_project_site_page.site_name_input_element.when_present Utils.short_wait).to be_truthy
          else
            logger.debug "Verifying that #{user.role} UID #{user.uid} has access to neither the course nor the project site UIs"
            expect(@site_creation_page.access_denied_element.when_present Utils.medium_wait).to be_truthy
            expect(@site_creation_page.create_course_site_link?).to be false
            expect(@site_creation_page.create_project_site_link?).to be false
        end
      end

      it "allows #{user.role} UID #{user.uid} to hit the tool directly if permitted to do so" do
        unless masquerade
          @splash_page.basic_auth user.uid
          @create_project_site_page.load_standalone_tool
          has_project_name_input = @create_project_site_page.verify_block { @create_project_site_page.site_name_input_element.when_visible Utils.short_wait }
          (%w(TA Staff).include? user.role) ?
              (expect(has_project_name_input).to be true) :
              (expect(has_project_name_input).to be false)
        end
      end
    end
  end
end
