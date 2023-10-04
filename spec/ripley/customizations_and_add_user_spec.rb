require_relative '../../util/spec_helper'

describe 'bCourses' do

  include Logging

  test = RipleyTestConfig.new
  test.add_user
  non_teachers = [
    test.lead_ta,
    test.ta,
    test.designer,
    test.reader,
    test.observer,
    test.students.first,
    test.wait_list_student
  ]

  before(:all) do
    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasPage.new @driver
    @canvas_api = CanvasAPIPage.new @driver
    @splash_page = RipleySplashPage.new @driver
    @create_course_site_page = RipleyCreateCourseSitePage.new @driver
    @course_add_user_page = RipleyAddUserPage.new @driver

    @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
    RipleyTool::TOOLS.each { |t| @canvas.add_ripley_tool t }
    section_ids = @canvas_api.get_course_site_sis_section_ids ENV['SITE'] if ENV['SITE']
    @site = test.get_single_test_site section_ids
    @teacher = RipleyUtils.get_primary_instructor(@site) || @site.course.teachers.first
    @canvas.set_canvas_ids([@teacher] + non_teachers)
    @canvas.masquerade_as @teacher

    unless @site.site_id
      @create_course_site_page.provision_course_site @site unless @site.site_id
    end
    @canvas.publish_course_site @site
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'customizations' do

    context 'in the footer' do

      before(:all) { @canvas.load_homepage }

      it 'include an "About" link' do
        @canvas.scroll_to_bottom
        title = 'bCourses | Research, Teaching, and Learning'
        expect(@canvas.external_link_valid?(@canvas.about_link_element, title)).to be true
      end

      it 'include a "Privacy Policy" link' do
        title = 'Product Privacy | Policy | Instructure'
        expect(@canvas.external_link_valid?(@canvas.privacy_policy_link_element, title)).to be true
      end

      it 'include a "Terms of Service" link' do
        title = 'Terms of Use | Policy | Instructure'
        expect(@canvas.external_link_valid?(@canvas.terms_of_service_link_element, title)).to be true
      end

      it 'include a "Data Use & Analytics" link' do
        title = 'bCourses Data Use and Analytics | Digital Learning Services'
        expect(@canvas.external_link_valid?(@canvas.data_use_link_element, title)).to be true
      end

      it 'include a "UC Berkeley Honor Code" link' do
        title = 'Berkeley Honor Code | Center for Teaching & Learning'
        expect(@canvas.external_link_valid?(@canvas.honor_code_link_element, title)).to be true
      end

      it 'include a "Student Resources" link' do
        title = 'Resources | ASUC'
        expect(@canvas.external_link_valid?(@canvas.student_resources_link_element, title)).to be true
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

    context 'in Add People' do

      before(:all) do
        @canvas.load_users_page @site
        @canvas.click_add_people
      end

      it 'include a search by Email Address option' do
        expect(@canvas.add_user_by_email_label).to eql('Email Address')
        @canvas.click_add_by_email
        @canvas.wait_until(1) { @canvas.add_user_placeholder == 'student@berkeley.edu, guest@example.com, gsi@berkeley.edu' }
      end

      it 'include a search by Berkeley UID option' do
        expect(@canvas.add_user_by_uid_label).to eql('Berkeley UID')
        @canvas.click_add_by_uid
        @canvas.wait_until(1) { @canvas.add_user_placeholder == '1032343, 11203443' }
      end

      it 'include a search by Student ID option' do
        expect(@canvas.add_user_by_sid_label).to eql('Student ID')
        @canvas.click_add_by_sid
        @canvas.wait_until(1) { @canvas.add_user_placeholder == '25738808, UID:11203443' }
      end

      it 'include a how-to link' do
        title = 'IT - How do I add users to my course site?'
        expect(@canvas.external_link_valid?(@canvas.add_user_help_link_element, title)).to be true
      end

      it 'include CalNet guest account instructions for unrecognized accounts' do
        title = 'IT - How can I access bCourses without a CalNet Account?'
        @canvas.hit_escape
        @canvas.add_invalid_uid
        expect(@canvas.external_link_valid?(@canvas.invalid_user_info_link_element, title)).to be true
      end
    end
  end

  describe 'Find a Person to Add' do

    before(:all) do
      # TODO - uncomment when link is present
      # @canvas.load_users_page @site
      # @canvas.click_find_person_to_add
      @course_add_user_page.load_embedded_tool @site
    end

    it 'requires that a search term be entered' do
      @course_add_user_page.search_button_element.when_present Utils.short_wait
      expect(@course_add_user_page.search_button_element.enabled?).to be false
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
      @course_add_user_page.no_uid_results_msg_element.when_visible Utils.medium_wait
    end

    it 'offers the right course site sections' do
      @course_add_user_page.search('Bear', 'Last Name, First Name')
      @course_add_user_page.wait_until(Utils.medium_wait) { @course_add_user_page.uid_results.include? "#{Utils.oski_uid}" }
      expect(@course_add_user_page.course_section_options.length).to eql(@site.sections.length)
    end
  end

  describe 'import users to course site' do

    before(:all) do
      @section_to_test = @site.sections.first
      # TODO - uncomment when the link is present
      # @canvas.load_users_page @site
      # @canvas.click_find_person_to_add
      @course_add_user_page.load_embedded_tool @site
      non_teachers.each do |user|
        @course_add_user_page.search(user.uid, 'CalNet UID')
        @course_add_user_page.add_user_by_uid(user, @section_to_test)
      end
      @canvas.load_users_page @site
      @canvas.load_all_students @site
    end

    non_teachers.each do |user|
      it "shows an added #{user.role} user in the course site roster" do
        @canvas.search_user_by_canvas_id user
        @canvas.wait_until(Utils.medium_wait) { @canvas.roster_user? user.canvas_id }
        if user == test.observer
          expect(@canvas.roster_user_roles(user.canvas_id)).to include('Observing: nobody')
        else
          expect(@canvas.roster_user_roles(user.canvas_id)).to include(user.role)
          expect(@canvas.roster_user_sections(user.canvas_id)).to include("#{@section_to_test.course} #{@section_to_test.label}")
        end
      end
    end
  end

  describe 'user role restrictions' do

    before(:all) do
      @policies_heading = 'Academic Accommodations Hub | Executive Vice Chancellor and Provost'
      @mental_health_heading = 'Mental Health | University Health Services'
    end

    [test.lead_ta, test.ta].each do |user|
      it "allows #{user.role} #{user.uid} access to the Find a Person to Add tool with limited roles" do
        @canvas.masquerade_as(user, @site)
        # TODO - uncomment when link is present
        # @canvas.load_users_page @site
        # @canvas.click_find_person_to_add
        @course_add_user_page.load_embedded_tool @site
        @course_add_user_page.search('Oski', 'Last Name, First Name')
        opts = if user == test.lead_ta
                 ['Student', 'Waitlist Student', 'TA', 'Lead TA', 'Reader', 'Observer']
               else
                 ['Student', 'Waitlist Student', 'Observer']
               end
        expect(@course_add_user_page.visible_user_role_options).to eql(opts)
      end

      it "offers no link to the tool in course navigation" do
        @canvas.switch_to_main_content
        expect(@canvas.tool_nav_link(RipleyTool::ADD_USER).exists?).to be false
      end

      it "offers #{user.role} an Academic Policies link" do
        expect(@canvas.external_link_valid?(@canvas.policies_link_element, @policies_heading)).to be true
      end
    end

    [test.designer, test.reader].each do |user|
      it "denies #{user.role} #{user.uid} access to the Find a Person to Add tool" do
        @canvas.masquerade_as(user, @site)
        @course_add_user_page.load_embedded_tool @site
        @course_add_user_page.auth_check_failed_msg_element.when_visible Utils.medium_wait
      end

      it "offers no link to the tool in course navigation" do
        @canvas.switch_to_main_content
        expect(@canvas.tool_nav_link(RipleyTool::ADD_USER).exists?).to be false
      end

      it "offers #{user.role} an Academic Policies link" do
        expect(@canvas.external_link_valid?(@canvas.policies_link_element, @policies_heading)).to be true
      end
    end

    [test.observer, test.students.first, test.wait_list_student].each do |user|
      it "denies #{user.role} #{user.uid} access to the Find a Person to Add tool" do
        Utils.set_default_window_size @driver
        @canvas.masquerade_as(user, @site)
        @course_add_user_page.load_embedded_tool @site
        @course_add_user_page.auth_check_failed_msg_element.when_visible Utils.medium_wait
      end

      it "offers no link to the tool in course navigation" do
        @canvas.switch_to_main_content
        expect(@canvas.tool_nav_link(RipleyTool::ADD_USER).exists?).to be false
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

      it "offers #{user.role} a Mental Health Resources link in reduced viewport" do
        expect(@canvas.external_link_valid?(@canvas.mental_health_responsive_link_element, @mental_health_heading)).to be true
      end
    end
  end
end
