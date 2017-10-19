require_relative '../../util/spec_helper'

describe 'bCourses Find a Person to Add', order: :defined do

  include Logging

  # Load test course data
  test_course_data = JunctionUtils.load_junction_test_course_data.find { |course| course['tests']['course_add_user'] }
  course = Course.new test_course_data
  sections = course.sections.map { |section_data| Section.new section_data }
  sections_for_site = sections.select { |section| section.include_in_site }

  # Load test user data
  test_user_data = JunctionUtils.load_junction_test_user_data.select { |user| user['tests']['course_add_user'] }
  teachers_data = test_user_data.select { |data| data['role'] == 'Teacher' }
  teacher_1 = User.new teachers_data[0]
  teacher_2 = User.new teachers_data[1]
  lead_ta = User.new test_user_data.find { |data| data['role'] == 'Lead TA' }
  ta = User.new test_user_data.find { |data| data['role'] == 'TA' }
  designer = User.new test_user_data.find { |data| data['role'] == 'Designer' }
  observer = User.new test_user_data.find { |data| data['role'] == 'Observer' }
  reader = User.new test_user_data.find { |data| data['role'] == 'Reader' }
  student = User.new test_user_data.find { |data| data['role'] == 'Student' }
  waitlist = User.new test_user_data.find { |data| data['role'] == 'Waitlist Student' }

  before(:all) do
    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasPage.new @driver
    @splash_page = Page::JunctionPages::SplashPage.new @driver
    @create_course_site_page = Page::JunctionPages::CanvasCreateCourseSitePage.new @driver
    @course_add_user_page = Page::JunctionPages::CanvasCourseAddUserPage.new @driver

    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.masquerade_as(@driver, teacher_1)

    @create_course_site_page.provision_course_site(@driver, course, teacher_1, sections_for_site) if course.site_id.nil?
    @canvas.publish_course_site(@driver, course)
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'customizations in Add People' do

    before(:all) do
      @canvas.masquerade_as(@driver, teacher_1, course)
      @canvas.load_users_page course
    end

    it 'include a link to a help page on the Everyone tab' do
      @canvas.help_finding_users_link_element.when_visible Utils.short_wait
      expect(@canvas.external_link_valid?(@driver, @canvas.help_finding_users_link_element, 'Service at UC Berkeley')).to be true
    end

    it 'include a search by Email Address option' do
      @canvas.wait_for_load_and_click_js @canvas.add_people_button_element
      @canvas.find_person_to_add_link_element.when_visible Utils.short_wait
      expect(@canvas.add_user_by_email?).to be true
    end

    it('include a search by Berkeley UID option') { expect(@canvas.add_user_by_uid?).to be true }
    it('include a search by Student ID option') { expect(@canvas.add_user_by_sid?).to be true }
  end

  describe 'search' do

    before(:all) do
      @canvas.masquerade_as(@driver, teacher_1, course)
      @canvas.load_users_page course
      @canvas.click_find_person_to_add @driver
    end

    before(:each) { @course_add_user_page.switch_to_canvas_iframe @driver unless @course_add_user_page.page_heading? }

    it 'allows the user to search by name' do
      @course_add_user_page.search('Bear', 'Last Name, First Name')
      @course_add_user_page.wait_until(Utils.medium_wait) { @course_add_user_page.name_results(@driver).include? 'Oski Bear' }
    end

    it 'notifies the user if a name search produces no results' do
      @course_add_user_page.search('zyxwvu', 'Last Name, First Name')
      @course_add_user_page.no_results_msg_element.when_visible Utils.medium_wait
    end

    it 'limits the results of a name search to 20' do
      @course_add_user_page.search('Smith', 'Last Name, First Name')
      @course_add_user_page.wait_until(Utils.medium_wait) { @course_add_user_page.name_results(@driver).length == 20 }
      @course_add_user_page.too_many_results_msg_element.when_visible Utils.medium_wait
    end

    it 'allows the user to search by email and limits the results of an email search to 20' do
      @course_add_user_page.search('smith@berkeley', 'Email')
      @course_add_user_page.wait_until(Utils.medium_wait) { @course_add_user_page.email_results(@driver).length == 20 }
      @course_add_user_page.too_many_results_msg_element.when_visible Utils.medium_wait
    end

    it 'notifies the user if an email search produces no result' do
      @course_add_user_page.search('foo@bar', 'Email')
      @course_add_user_page.no_results_msg_element.when_visible Utils.medium_wait
    end

    it 'allows the user to search by UID' do
      @course_add_user_page.search(Utils.oski_uid, 'CalNet UID')
      @course_add_user_page.wait_until(Utils.medium_wait) { @course_add_user_page.uid_results(@driver).include? "#{Utils.oski_uid}" }
    end

    it 'notifies the user if a UID search produces no result' do
      @course_add_user_page.search('12324', 'CalNet UID')
      @course_add_user_page.no_results_msg_element.when_visible Utils.medium_wait
    end

    it 'requires that a search term be entered' do
      @course_add_user_page.search('', 'Last Name, First Name')
      @course_add_user_page.blank_search_msg_element.when_visible Utils.medium_wait
    end

    it 'offers the right course site sections' do
      @course_add_user_page.search('Bear', 'Last Name, First Name')
      @course_add_user_page.wait_until(Utils.medium_wait) { @course_add_user_page.name_results(@driver).include? 'Oski Bear' }
      expect(@course_add_user_page.course_section_options.length).to eql(sections_for_site.length)
    end
  end

  describe 'import users to course site' do

    before(:all) do
      @section_to_test = sections_for_site.first
      @canvas.masquerade_as(@driver, teacher_1, course)
    end

    before(:each) do
      @canvas.load_users_page course
      @canvas.click_find_person_to_add @driver
    end

    [teacher_2, lead_ta, ta, designer, reader, student, waitlist, observer].each do |user|

      it "allows a course Teacher to add a #{user.role} to a course site with any type of role" do
        @course_add_user_page.search(user.uid, 'CalNet UID')
        @course_add_user_page.add_user_by_uid(user, @section_to_test)
        @canvas.load_users_page course
        @canvas.search_user_by_canvas_id user
        @canvas.wait_until(Utils.short_wait) { @canvas.roster_user_uid user.canvas_id }
        expect(@canvas.roster_user_sections(user.canvas_id)).to include("#{@section_to_test.course} #{@section_to_test.label}") unless user.role == 'Observer'
        (user.role == 'Observer') ?
            (expect(@canvas.roster_user_roles(user.canvas_id)).to include('Observing: nobody')) :
            (expect(@canvas.roster_user_roles(user.canvas_id)).to include(user.role))
      end
    end
  end

  describe 'user role restrictions' do

    before(:all) do
      @canvas.masquerade_as(@driver, teacher_1, course)
      @canvas.publish_course_site(@driver, course)
    end

    [lead_ta, ta, designer, reader, student, waitlist, observer].each do |user|

      it "allows a course #{user.role} to access the tool and add a subset of roles to a course site if permitted to do so" do
          @canvas.masquerade_as(@driver, user, course)
        if ['Lead TA', 'TA'].include? user.role
          @canvas.load_users_page course
          @canvas.click_find_person_to_add @driver
          @course_add_user_page.search('Oski', 'Last Name, First Name')
          @course_add_user_page.wait_until(Utils.medium_wait) { @course_add_user_page.user_role_options == ['Student', 'Waitlist Student', 'Observer'] }
        elsif user.role == 'Designer'
          @canvas.load_users_page course
          @canvas.click_find_person_to_add @driver
          @course_add_user_page.no_access_msg_element.when_visible Utils.medium_wait
        elsif user.role == 'Reader'
          @course_add_user_page.load_embedded_tool(@driver, course)
          @course_add_user_page.no_sections_msg_element.when_visible Utils.medium_wait
        elsif ['Student', 'Waitlist Student', 'Observer'].include? user.role
          @course_add_user_page.load_embedded_tool(@driver, course)
          @course_add_user_page.no_access_msg_element.when_visible Utils.medium_wait
        end
      end
    end
  end
end
