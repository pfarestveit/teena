require_relative '../../util/spec_helper'

describe 'bCourses Find a Person to Add', order: :defined do

  include Logging

  masquerade = ENV['masquerade']
  course_id = ENV['course_id']

  # Load test data

  test_course_data = Utils.load_test_courses.find { |course| course['tests']['course_add_user'] }
  course = Course.new test_course_data
  sections = course.sections.map { |section_data| Section.new section_data }
  sections_for_site = sections.select { |section| section.include_in_site }

  test_user_data = Utils.load_test_users.select { |user| user['tests']['course_add_user'] }

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
    @splash_page = Page::CalCentralPages::SplashPage.new @driver
    @site_creation_page = Page::CalCentralPages::CanvasSiteCreationPage.new @driver
    @create_course_site_page = Page::CalCentralPages::CanvasCreateCourseSitePage.new @driver
    @course_add_user_page = Page::CalCentralPages::CanvasCourseAddUserPage.new @driver

    if masquerade
      @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
      @canvas.masquerade_as teacher_1
      @create_course_site_page.load_embedded_tool(@driver, teacher_1)
      @site_creation_page.click_create_course_site @create_course_site_page
    else
      @canvas.log_in(@cal_net, Utils.ets_qa_username, Utils.ets_qa_password)
      @splash_page.load_page
      @splash_page.basic_auth teacher_1.uid
      @create_course_site_page.load_standalone_tool
    end

    course.site_id = course_id
    @create_course_site_page.provision_course_site(course, teacher_1, sections_for_site) if course.site_id.nil?
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'links and instructions' do

    before(:all) do
      if masquerade
        @canvas.masquerade_as(teacher_1, course)
        @canvas.load_users_page course
        @canvas.click_find_person_to_add @driver
      else
        @splash_page.load_page
        @splash_page.basic_auth teacher_1.uid
        @course_add_user_page.load_standalone_tool course
      end
    end

    before(:each) { @course_add_user_page.switch_to_canvas_iframe @driver unless @course_add_user_page.page_heading? }

    it 'shows a collapsed maintenance notice' do
      @course_add_user_page.maintenance_notice_element.when_visible Utils.medium_wait
      expect(@course_add_user_page.maintenance_notice).to include('From 8 - 9 AM, you may experience delays of up to 10 minutes before your user is added.')
      expect(@course_add_user_page.maintenance_detail_element.visible?).to be false
    end

    it 'allows the user to expand the maintenance notice' do
      @course_add_user_page.expand_maintenance_notice
      expect(@course_add_user_page.maintenance_detail).to include('bCourses performs scheduled maintenance every day between 8-9AM, during which time bCourses user and enrollment information is synchronized with other campus systems. This process may cause delays of up to 10 minutes before your request is completed.')
    end

    it 'shows a bCourses service page link in the expanded maintenance notice' do
      expect(@course_add_user_page.verify_external_link(@driver, @course_add_user_page.bcourses_service_link_element, 'bCourses | Educational Technology Services')).to be true
    end

    it 'allows the user to collapse the maintenance notice' do
      expect(@course_add_user_page.hide_maintenance_notice).to be_truthy
    end

    it 'shows a collapsed help notice' do
      @course_add_user_page.need_help_button_element.when_visible Utils.short_wait
      expect(@course_add_user_page.help_notice_element.visible?).to be false
    end

    it 'allows the user to expand the help notice' do
      @course_add_user_page.expand_help_notice
      expect(@course_add_user_page.help_notice).to include('UC Berkeley Faculty, Staff and Students')
    end

    it 'shows a CalNet Directory link in the expanded maintenance notice' do
      expect(@course_add_user_page.verify_external_link(@driver, @course_add_user_page.cal_net_dir_link_element, 'Campus Directory | University of California, Berkeley')).to be true
    end

    it 'shows a CalNet Guest Account link in the expanded maintenance notice' do
      expect(@course_add_user_page.cal_net_guest_acct_link?).to be true
    end

    it 'shows a bCourses help page link in the expanded maintenance notice' do
      expect(@course_add_user_page.verify_external_link(@driver, @course_add_user_page.bcourses_help_link_element, 'Service at UC Berkeley')).to be true
    end
  end

  describe 'search' do

    before(:all) do
      if masquerade
        @canvas.masquerade_as(teacher_1, course)
        @canvas.load_users_page course
        @canvas.click_find_person_to_add @driver
      else
        @splash_page.basic_auth teacher_1.uid
        @course_add_user_page.load_standalone_tool course
      end
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
      @course_add_user_page.search('61889', 'CalNet UID')
      @course_add_user_page.wait_until(Utils.medium_wait) { @course_add_user_page.uid_results(@driver).include? '61889' }
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
      @section_to_test = sections_for_site.find { |section| section.code }
      @canvas.masquerade_as(teacher_1, course) if masquerade
    end

    before(:each) do
      if masquerade
        @canvas.load_users_page course
        @canvas.click_find_person_to_add @driver
      else
        @splash_page.basic_auth teacher_1.uid
        @course_add_user_page.load_standalone_tool course
      end
    end

    [teacher_2, lead_ta, ta, designer, reader, student, waitlist, observer].each do |user|

      it "allows a course Teacher to add a #{user.role} to a course site with any type of role" do
        @course_add_user_page.search(user.uid, 'CalNet UID')
        @course_add_user_page.add_user_by_uid(user, @section_to_test)
        if masquerade
          @canvas.load_users_page course
          @canvas.search_user_by_canvas_id user
          @canvas.wait_until(Utils.short_wait) { @canvas.roster_user_uid user.canvas_id }
          expect(@canvas.roster_user_sections(user.canvas_id)).to include(@section_to_test.code) unless user.role == 'Observer'
          (user.role == 'Observer') ?
              (expect(@canvas.roster_user_roles(user.canvas_id)).to include('Observing: nobody')) :
              (expect(@canvas.roster_user_roles(user.canvas_id)).to include(user.role))
        end
      end
    end
  end

  describe 'user role restrictions' do

    before(:all) do
      if masquerade
        @canvas.masquerade_as(teacher_1, course)
        @canvas.publish_course_site course
      end
    end

    [lead_ta, ta, designer, reader, student, waitlist, observer].each do |user|

      it "allows a course #{user.role} to access the tool and add a subset of roles to a course site if permitted to do so" do
        if masquerade
          @canvas.masquerade_as(user, course)
          @canvas.load_users_page course
        else
          @splash_page.basic_auth user.uid
          @course_add_user_page.load_standalone_tool course
        end

        if ['Lead TA', 'TA'].include? user.role
          @canvas.click_find_person_to_add @driver if masquerade
          @course_add_user_page.search('Oski', 'Last Name, First Name')
          @course_add_user_page.wait_until(Utils.medium_wait) { @course_add_user_page.user_role_options == ['Student', 'Waitlist Student', 'Observer'] }
        elsif user.role == 'Designer'
          @canvas.click_find_person_to_add @driver if masquerade
          @course_add_user_page.no_access_msg_element.when_visible Utils.medium_wait
        elsif user.role == 'Reader'
          @course_add_user_page.load_embedded_tool(@driver, course) if masquerade
          @course_add_user_page.no_sections_msg_element.when_visible Utils.medium_wait
        elsif ['Student', 'Waitlist Student', 'Observer'].include? user.role
          @course_add_user_page.load_embedded_tool(@driver, course) if masquerade
          @course_add_user_page.no_access_msg_element.when_visible Utils.medium_wait
        end
      end
    end
  end
end
