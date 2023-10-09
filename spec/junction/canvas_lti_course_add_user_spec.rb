require_relative '../../util/spec_helper'

standalone = ENV['STANDALONE']

describe 'bCourses Find a Person to Add', order: :defined do

  include Logging

  # Load test course data
  test = JunctionTestConfig.new
  test.add_user
  course = test.courses.first
  sections = test.set_course_sections(course).select(&:include_in_site)
  sis_teacher = test.set_sis_teacher course
  users_to_add = [test.manual_teacher, test.lead_ta, test.ta, test.designer, test.reader, test.observer, test.students.first, test.wait_list_student]

  before(:all) do
    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasPage.new @driver
    @splash_page = Page::JunctionPages::SplashPage.new @driver
    @create_course_site_page = Page::JunctionPages::CanvasCreateCourseSitePage.new @driver
    @course_add_user_page = Page::JunctionPages::CanvasCourseAddUserPage.new @driver

    if standalone
      @splash_page.load_page
      @splash_page.basic_auth sis_teacher.uid
    else
      @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
      @canvas.masquerade_as sis_teacher
    end
  end

  after(:all) { Utils.quit_browser @driver }

  unless standalone
    describe 'customizations in the footer' do

      it 'include an "About" link' do
        @canvas.scroll_to_bottom
        expect(@canvas.external_link_valid?(@canvas.about_link_element, 'bCourses | Research, Teaching, and Learning')).to be true
      end

      it 'include a "Privacy Policy" link' do
        expect(@canvas.external_link_valid?(@canvas.privacy_policy_link_element, 'Product Privacy | Policy | Instructure')).to be true
      end

      it 'include a "Terms of Service" link' do
        expect(@canvas.external_link_valid?(@canvas.terms_of_service_link_element, 'Terms of Use | Policy | Instructure')).to be true
      end

      it 'include a "Data Use & Analytics" link' do
        expect(@canvas.external_link_valid?(@canvas.data_use_link_element, 'bCourses Data Use and Analytics | Digital Learning Services')).to be true
      end

      it 'include a "UC Berkeley Honor Code" link' do
        expect(@canvas.external_link_valid?(@canvas.honor_code_link_element, 'Berkeley Honor Code | Center for Teaching & Learning')).to be true
      end

      it 'include a "Student Resources" link' do
        expect(@canvas.external_link_valid?(@canvas.student_resources_link_element, 'Resources | ASUC')).to be true
      end

      it 'include an "Accessibility" link' do
        title = 'bCourses Accessibility | Research, Teaching, and Learning'
        expect(@canvas.external_link_valid?(@canvas.accessibility_link_element, title)).to be true
      end

      it 'include a "Nondiscrimination" link' do
        title = 'Nondiscrimination Policy Statement | Office for the Prevention of Harassment & Discrimination'
        expect(@canvas.external_link_valid?(@canvas.nondiscrimination_link_element, title)).to be true
      end
    end
  end

  describe 'customizations in Add People' do

    before(:all) do
      @create_course_site_page.provision_course_site(course, sis_teacher, sections, {standalone: standalone})
      if standalone
        @create_course_site_page.wait_for_standalone_site_id(course, sis_teacher, @splash_page)
      else
        @canvas.publish_course_site course
        @canvas.load_users_page course
      end
    end

    it 'include a search by Email Address option' do
      if standalone
        skip 'Skipping test since in standalone mode'
      else
        @canvas.wait_for_load_and_click @canvas.add_people_button_element
        @canvas.find_person_to_add_link_element.when_visible Utils.short_wait
        expect(@canvas.add_user_by_email_label_element.text).to eql('Email Address')
        @canvas.wait_for_update_and_click @canvas.add_user_by_email_element
        @canvas.wait_until(1) do
          @canvas.user_list_element.attribute('placeholder') == 'student@berkeley.edu, guest@example.com, gsi@berkeley.edu'
        end
      end
    end

    it 'include a search by Berkeley UID option' do
      if standalone
        skip 'Skipping test since in standalone mode'
      else
        expect(@canvas.add_user_by_uid_label_element.text).to eql('Berkeley UID')
        @canvas.wait_for_update_and_click @canvas.add_user_by_uid_element
        @canvas.wait_until(1) do
          @canvas.user_list_element.attribute('placeholder') == '1032343, 11203443'
        end
      end
    end

    it 'include a search by Student ID option' do
      if standalone
        skip 'Skipping test since in standalone mode'
      else
        expect(@canvas.add_user_by_sid_label_element.text).to eql('Student ID')
        @canvas.wait_for_update_and_click @canvas.add_user_by_sid_element
        @canvas.wait_until(1) do
          @canvas.user_list_element.attribute('placeholder') == '25738808, UID:11203443'
        end
      end
    end

    it 'include a how-to link' do
      if standalone
        skip 'Skipping test since in standalone mode'
      else
        title = 'IT - How do I add users to my course site?'
        expect(@canvas.external_link_valid?(@canvas.add_user_help_link_element, title)).to be true
      end
    end

    it 'include CalNet guest account instructions for unrecognized accounts' do
      if standalone
        skip 'Skipping test since in standalone mode'
      else
        title = 'IT - How can I access bCourses without a CalNet Account?'
        @canvas.hit_escape
        @canvas.add_invalid_uid
        expect(@canvas.external_link_valid?(@canvas.invalid_user_info_link_element, title)).to be true
      end
    end
  end

  describe 'search' do

    before(:all) do
      if standalone
        @course_add_user_page.load_standalone_tool course
      else
        @canvas.load_users_page course
        @canvas.click_find_person_to_add
      end
    end

    before(:each) do
      @course_add_user_page.page_heading_element.when_present Utils.short_wait
    rescue
      @course_add_user_page.switch_to_canvas_iframe
    end

    it 'allows the user to search by name' do
      @course_add_user_page.search('Bear', 'Last Name, First Name')
      @course_add_user_page.wait_until(Utils.medium_wait) { @course_add_user_page.uid_results.include? "#{Utils.oski_uid}" }
    end

    it 'notifies the user if a name search produces no results' do
      @course_add_user_page.search('zyxwvu', 'Last Name, First Name')
      @course_add_user_page.no_results_msg_element.when_visible Utils.medium_wait
    end

    it 'limits the results of a name search to 20' do
      @course_add_user_page.search('Smith', 'Last Name, First Name')
      @course_add_user_page.wait_until(Utils.medium_wait) { @course_add_user_page.name_results.length == 20 }
      @course_add_user_page.too_many_results_msg_element.when_visible Utils.medium_wait
    end

    it 'allows the user to search by email and limits the results of an email search to 20' do
      @course_add_user_page.search('smith@berkeley', 'Email')
      @course_add_user_page.wait_until(Utils.medium_wait) { @course_add_user_page.email_results.length == 20 }
      @course_add_user_page.too_many_results_msg_element.when_visible Utils.medium_wait
    end

    it 'notifies the user if an email search produces no result' do
      @course_add_user_page.search('foo@bar', 'Email')
      @course_add_user_page.no_results_msg_element.when_visible Utils.medium_wait
    end

    it 'allows the user to search by UID' do
      @course_add_user_page.search(Utils.oski_uid, 'CalNet UID')
      @course_add_user_page.wait_until(Utils.medium_wait) { @course_add_user_page.uid_results.include? "#{Utils.oski_uid}" }
    end

    it 'notifies the user if a UID search produces no result' do
      @course_add_user_page.search('12324', 'CalNet UID')
      @course_add_user_page.no_results_msg_element.when_visible Utils.medium_wait
    end

    it 'requires that a search term be entered' do
      @course_add_user_page.search(' ', 'Last Name, First Name')
      @course_add_user_page.blank_search_msg_element.when_visible Utils.medium_wait
    end

    it 'offers the right course site sections' do
      @course_add_user_page.search('Bear', 'Last Name, First Name')
      @course_add_user_page.wait_until(Utils.medium_wait) { @course_add_user_page.uid_results.include? "#{Utils.oski_uid}" }
      expect(@course_add_user_page.course_section_options.length).to eql(sections.length)
    end
  end

  unless standalone

    describe 'import users to course site' do

      before(:all) do
        @section_to_test = sections.first
        @canvas.masquerade_as(sis_teacher, course)
        @canvas.load_users_page course
        @canvas.click_find_person_to_add
        users_to_add.each do |user|
          @course_add_user_page.search(user.uid, 'CalNet UID')
          @course_add_user_page.add_user_by_uid(user, @section_to_test)
        end
        @canvas.load_users_page course
        @canvas.load_all_students course
      end

      users_to_add.each do |user|
        it "shows an added #{user.role} user in the course site roster" do
          @canvas.search_user_by_canvas_id user
          @canvas.wait_until(Utils.medium_wait) { @canvas.roster_user? user.canvas_id }
          expect(@canvas.roster_user_sections(user.canvas_id)).to include("#{@section_to_test.course} #{@section_to_test.label}") unless user == test.observer
          (user == test.observer) ?
              (expect(@canvas.roster_user_roles(user.canvas_id)).to include('Observing: nobody')) :
              (expect(@canvas.roster_user_roles(user.canvas_id)).to include(user.role))
        end
      end
    end

    describe 'user role restrictions' do

      before(:all) do
        @policies_heading = 'Academic Accommodations Hub | Executive Vice Chancellor and Provost'
        @mental_health_heading = 'Mental Health | University Health Services'
        @canvas.masquerade_as(sis_teacher, course)
        @canvas.publish_course_site course
      end

      # Check each user role's access to the tool

      [test.lead_ta, test.ta].each do |user|
        it "allows #{user.role} #{user.uid} access to the tool with limited roles" do
          @canvas.masquerade_as(user, course)
          @canvas.load_users_page course
          @canvas.click_find_person_to_add
          @course_add_user_page.search('Oski', 'Last Name, First Name')
          @course_add_user_page.user_role_element.when_visible Utils.short_wait
          @course_add_user_page.wait_until(Utils.medium_wait, "Visible #{@course_add_user_page.user_role_options}") do
            opts = if user == test.lead_ta
                     ['Student', 'Waitlist Student', 'TA', 'Lead TA', 'Reader', 'Observer']
                   else
                     ['Student', 'Waitlist Student', 'Observer']
                   end
            @course_add_user_page.user_role_options.map(&:strip) == opts
          end
        end

        it "offers #{user.role} an Academic Policies link" do
          @canvas.switch_to_main_content
          expect(@canvas.external_link_valid?(@canvas.policies_link_element, @policies_heading)).to be true
        end
      end

      [test.designer, test.reader].each do |user|
        it "denies #{user.role} #{user.uid} access to the tool" do
          @canvas.masquerade_as(user, course)
          @course_add_user_page.load_embedded_tool course
          @course_add_user_page.no_access_msg_element.when_visible Utils.medium_wait
        end

        it "offers #{user.role} an Academic Policies link" do
          @canvas.switch_to_main_content
          expect(@canvas.external_link_valid?(@canvas.policies_link_element, @policies_heading)).to be true
        end
      end

      [test.observer, test.students.first, test.wait_list_student].each do |user|
        it "denies #{user.role} #{user.uid} access to the tool" do
          Utils.set_default_window_size @driver
          @canvas.masquerade_as(user, course)
          @course_add_user_page.hit_embedded_tool_url course
          @canvas.wait_for_error(@canvas.access_denied_msg_element, @course_add_user_page.no_access_msg_element)
        end

        it "offers #{user.role} an Academic Policies link" do
          @canvas.switch_to_main_content
          expect(@canvas.external_link_valid?(@canvas.policies_link_element, @policies_heading)).to be true
        end

        it "offers #{user.role} a Mental Health Resources link" do
          expect(@canvas.external_link_valid?(@canvas.mental_health_link_element, @mental_health_heading)).to be true
        end

        it "offers #{user.role} an Academic Policies link in reduced viewport" do
          Utils.set_reduced_window_size @driver
          @canvas.expand_mobile_menu
          expect(@canvas.external_link_valid?(@canvas.policies_responsive_link_element, @policies_heading)).to be true
        end

        it "offers #{user.role} a Mental Health Resources link" do
          expect(@canvas.external_link_valid?(@canvas.mental_health_responsive_link_element, @mental_health_heading)).to be true
        end
      end
    end
  end
end
