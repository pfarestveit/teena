unless ENV['STANDALONE']

  require_relative '../../util/spec_helper'

  describe 'bCourses Mailgun mailing lists', order: :defined do

    include Logging

    test = JunctionTestConfig.new
    test.mailing_lists
    timeout = Utils.short_wait
    # For good measure, wipe any old mailing list test data that's lying around
    JunctionUtils.drop_existing_mailing_lists

    course_site_1 = CourseSite.new({title: "QA Mailing List 1 #{test.id}", abbreviation: "QA admin #{test.id}", term: JunctionUtils.term_name})
    course_site_2 = CourseSite.new({title: "QA Mailing List 2 #{test.id}", abbreviation: "QA admin #{test.id}", term: JunctionUtils.term_name})
    course_site_3 = CourseSite.new({title: "QA Mailing List 3 #{test.id}", abbreviation: "QA instructor #{test.id}"})

    users = [test.manual_teacher, test.designer, test.lead_ta, test.ta, test.observer, test.reader, test.students].flatten

    before(:all) do
      @driver = Utils.launch_browser
      @canvas_page = Page::CanvasPage.new @driver
      @cal_net_page = Page::CalNetPage.new @driver
      @splash_page = Page::JunctionPages::SplashPage.new @driver
      @mailing_list_page = Page::JunctionPages::CanvasMailingListPage.new @driver
      @mailing_lists_page = Page::JunctionPages::CanvasMailingListsPage.new @driver
      @site_creation_page = Page::JunctionPages::CanvasSiteCreationPage.new @driver
      @create_project_site_page = Page::JunctionPages::CanvasCreateProjectSitePage.new @driver

      # Create three course sites in the Official Courses sub-account
      @canvas_page.log_in(@cal_net_page, Utils.super_admin_username, Utils.super_admin_password)
      @canvas_page.create_generic_course_site(Utils.canvas_official_courses_sub_account, course_site_1, users, test.id)
      @canvas_page.create_generic_course_site(Utils.canvas_official_courses_sub_account, course_site_2, [test.manual_teacher], test.id)
      @canvas_page.create_generic_course_site(Utils.canvas_official_courses_sub_account, course_site_3, users, test.id)
    end

    after(:all) { Utils.quit_browser @driver }

    it 'is not added to site navigation by default' do
      @canvas_page.load_course_site course_site_1
      @canvas_page.list_item_element(id: 'section-tabs').when_present Utils.medium_wait
      expect(@mailing_list_page.mailing_list_link?).to be false
    end

    users.each do |user|
      it "can be managed by a course #{user.role} if the user has permission to reach the instructor-facing tool" do
        @canvas_page.masquerade_as(user, course_site_1)
        @mailing_list_page.hit_embedded_tool_url course_site_1
        if [test.manual_teacher, test.lead_ta, test.ta, test.reader].include? user
          logger.debug "Verifying that #{user.role} UID #{user.uid} has access to the instructor-facing mailing list tool"
          @mailing_list_page.switch_to_canvas_iframe
          @mailing_list_page.create_list_button_element.when_present(Utils.medium_wait)
        else
          logger.debug "Verifying that #{user.role} UID #{user.uid} has no access to the instructor-facing mailing list tool"
          @canvas_page.wait_for_error(@canvas_page.access_denied_msg_element, @mailing_list_page.unexpected_error_element)
        end
      end

      it "cannot be managed by a course #{user.role} via the admin tool" do
        @canvas_page.masquerade_as(user, course_site_1)
        @mailing_lists_page.hit_embedded_tool_url
        @canvas_page.access_denied_msg_element.when_visible Utils.short_wait
      rescue
        @mailing_lists_page.switch_to_canvas_iframe
        @mailing_lists_page.search_for_list course_site_1.site_id
        logger.debug "Verifying that #{user.role} UID #{user.uid} has no access to the admin mailing lists tool"
        @mailing_lists_page.unexpected_error_element.when_visible Utils.medium_wait
      end
    end

    describe 'admin tool' do

      before(:all) do
        @driver.switch_to.default_content
        @canvas_page.stop_masquerading if @canvas_page.stop_masquerading_link?
        @mailing_lists_page.load_embedded_tool
      end

      context 'when creating a list' do

        it 'requires a numeric site ID in order to find a site' do
          @mailing_lists_page.search_for_list 'foo'
          @mailing_lists_page.bad_input_msg_element.when_visible timeout
        end

        it 'requires a valid numeric site ID in order to find a site' do
          @mailing_lists_page.search_for_list '99999999999'
          @mailing_lists_page.not_found_msg_element.when_visible timeout
        end

        it 'retrieves a course site for a valid numeric site ID' do
          @mailing_lists_page.search_for_list course_site_1.site_id
          @mailing_lists_page.register_list_button_element.when_visible timeout
        end

        it 'shows the course site code, title, and ID' do
          expect(@mailing_lists_page.site_name).to eql(course_site_1.title)
          expect(@mailing_lists_page.site_code).to eql(("#{course_site_1.abbreviation}, #{course_site_1.term}").strip)
          expect(@mailing_lists_page.site_id).to eql("Site ID: #{course_site_1.site_id}")
        end

        it('shows a link to the course site') { expect(@mailing_lists_page.external_link_valid?(@mailing_lists_page.view_site_link_element, course_site_1.title)).to be true }

        it('shows a default mailing list name') do
          @mailing_lists_page.switch_to_canvas_iframe unless "#{@driver.browser}" == 'firefox'
          @mailing_lists_page.wait_until(Utils.short_wait) { @mailing_lists_page.list_name_input_element.value == @mailing_lists_page.default_list_name(course_site_1) }
        end

        it 'requires a non-default mailing list name have no spaces' do
          @mailing_lists_page.enter_mailgun_list_name 'lousy-list name'
          @mailing_lists_page.list_name_error_msg_element.when_visible timeout
        end

        it 'requires a non-default mailing list name have no special characters' do
          @mailing_lists_page.enter_mailgun_list_name 'lousier-list-name?'
          @mailing_lists_page.list_name_error_msg_element.when_visible timeout
        end

        it 'creates a mailing list with a valid, unique mailing list name' do
          @mailing_lists_page.enter_mailgun_list_name @mailing_lists_page.default_list_name(course_site_1)
          @mailing_lists_page.wait_until(timeout) { @mailing_lists_page.list_address == "#{@mailing_lists_page.default_list_name course_site_1}@bcourses-mail.berkeley.edu" }
        end

        it 'will not create a mailing list for a course site with the same course code as an existing list' do
          @mailing_lists_page.click_cancel
          @mailing_lists_page.search_for_list course_site_2.site_id
          @mailing_lists_page.enter_mailgun_list_name @mailing_lists_page.default_list_name(course_site_1)
          @mailing_lists_page.list_name_taken_error_msg_element.when_visible timeout
        end
      end

      context 'when viewing a list' do

        before(:all) do
          @mailing_lists_page.load_embedded_tool
          @mailing_lists_page.search_for_list course_site_1.site_id
          @mailing_lists_page.list_address_element.when_visible timeout
        end

        it('shows the mailing list email address') do
          @mailing_lists_page.wait_until(timeout) { @mailing_lists_page.list_address == "#{@mailing_lists_page.default_list_name course_site_1}@bcourses-mail.berkeley.edu" }
        end

        it('shows the membership count') { expect(@mailing_lists_page.list_membership_count).to eql('No members') }
        it('shows the most recent membership update') { expect(@mailing_lists_page.list_update_time).to eql('never') }
        it('shows a link to the course site') { expect(@mailing_lists_page.external_link_valid?(@mailing_lists_page.list_site_link_element, course_site_1.title)).to be true }

        it 'shows the course site code, title, and ID' do
          @canvas_page.switch_to_canvas_iframe unless "#{@driver.browser}" == 'firefox'
          expect(@mailing_lists_page.site_name).to eql("#{@mailing_lists_page.default_list_name course_site_1}@bcourses-mail.berkeley.edu")
          expect(@mailing_lists_page.site_code).to eql(("#{course_site_1.abbreviation}, #{course_site_1.term}").strip)
          expect(@mailing_lists_page.site_id).to eql("Site ID: #{course_site_1.site_id}")
        end

        it 'creates mailing list memberships for users who are members of the site' do
          @mailing_lists_page.click_update_memberships
          @mailing_lists_page.wait_until(timeout) { @mailing_lists_page.list_membership_count.include? "#{users.length}" }
          expect(@mailing_lists_page.list_update_time).to include(Time.now.strftime '%b %-d, %Y')
        end

        it 'deletes mailing list memberships for users who have been removed from the site' do
          @canvas_page.remove_users_from_course(course_site_1, [test.students[0]])
          JunctionUtils.clear_cache(@driver, @splash_page)
          @mailing_lists_page.load_embedded_tool
          @mailing_lists_page.search_for_list course_site_1.site_id
          @mailing_lists_page.click_update_memberships
          @mailing_lists_page.wait_until(timeout) { @mailing_lists_page.list_membership_count == "#{users.length - 1} members" }
        end

        it 'creates mailing list memberships for users who have been restored to the site' do
          @canvas_page.add_users(course_site_1, [test.students[0]])
          @canvas_page.masquerade_as(test.students[0], course_site_1)
          @canvas_page.stop_masquerading
          JunctionUtils.clear_cache(@driver, @splash_page)
          @mailing_lists_page.load_embedded_tool
          @mailing_lists_page.search_for_list course_site_1.site_id
          @mailing_lists_page.click_update_memberships
          @mailing_lists_page.wait_until(timeout) { @mailing_lists_page.list_membership_count == "#{users.length} members" }
        end

        it 'does not create mailing list memberships for site members with the same email addresses as existing mailing list members' do
          test.students[1].email = test.students[0].email
          @canvas_page.activate_user_and_reset_email [test.students[1]]
          JunctionUtils.clear_cache(@driver, @splash_page)
          @mailing_lists_page.load_embedded_tool
          @mailing_lists_page.search_for_list course_site_1.site_id
          @mailing_lists_page.click_update_memberships
          @mailing_lists_page.wait_until(timeout) { @mailing_lists_page.list_membership_count == "#{users.length - 1} members" }
        end
      end
    end

    describe 'instructor-facing tool' do

      before(:all) do
        course_site_2.title = course_site_1.title
        @canvas_page.edit_course_name course_site_2
        @canvas_page.masquerade_as(test.manual_teacher, course_site_3)
        @mailing_list_page.load_embedded_tool course_site_3
      end

      context 'when no mailing list exists' do

        it('shows a "no existing list" message') { @mailing_list_page.wait_until(timeout) { @mailing_list_page.no_list_msg? } }

        it 'allows the user to create a mailing list with a default list name' do
          @mailing_list_page.create_list
          expect(@mailing_list_page.list_address).to eql("#{@mailing_lists_page.default_list_name course_site_3}@bcourses-mail.berkeley.edu")
        end

        it 'will not create a mailing list for a course site with the same course code and term as an existing list' do
          @canvas_page.load_course_site course_site_2
          @mailing_list_page.load_embedded_tool course_site_2
          @mailing_list_page.list_dupe_error_msg_element.when_present timeout
          expect(@mailing_list_page.list_dupe_email_msg).to include(@mailing_lists_page.default_list_name course_site_2)
        end
      end

      context 'when a mailing list exists' do

        it 'shows the mailing list email address' do
          @mailing_list_page.load_embedded_tool course_site_3
          @mailing_list_page.list_address_element.when_present timeout
          expect(@mailing_list_page.list_address).to include("#{@mailing_lists_page.default_list_name course_site_3}@bcourses-mail.berkeley.edu")
        end
      end
    end
  end
end
