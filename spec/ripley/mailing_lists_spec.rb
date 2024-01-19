require_relative '../../util/spec_helper'

describe 'bCourses Mailgun mailing lists' do

  include Logging
  timeout = Utils.short_wait

  test = RipleyTestConfig.new
  test.mailing_lists
  course_site_1 = test.course_sites[0]
  course_site_2 = test.course_sites[1]
  course_site_3 = test.course_sites[2]
  course_site_4 = test.course_sites[3]
  project_site = test.course_sites[4]
  RipleyUtils.drop_existing_mailing_lists

  before(:all) do
    @driver = Utils.launch_browser
    @canvas_page = Page::CanvasPage.new @driver
    @canvas_api_page = CanvasAPIPage.new @driver
    @cal_net_page = Page::CalNetPage.new @driver
    @splash_page = RipleySplashPage.new @driver
    @jobs_page = RipleyAdminPage.new @driver
    @mailing_list_page = RipleyMailingListPage.new @driver
    @mailing_lists_page = RipleyMailingListsPage.new @driver
    @site_creation_page = RipleySiteCreationPage.new @driver
    @create_project_site_page = RipleyCreateProjectSitePage.new @driver

    @canvas_page.log_in(@cal_net_page, test.admin.username, Utils.super_admin_password)
    @canvas_page.add_ripley_tools RipleyTool::TOOLS.select(&:account)
    @canvas_api_page.get_support_admin_canvas_id test.canvas_admin
    @canvas_page.create_ripley_mailing_list_site course_site_1
    @canvas_page.create_ripley_mailing_list_site course_site_2
    @canvas_page.create_ripley_mailing_list_site course_site_3
    @canvas_page.create_ripley_mailing_list_site course_site_4

    @site_creation_page.load_embedded_tool test.admin
    @site_creation_page.click_create_project_site
    @create_project_site_page.create_project_site project_site.title
    @create_project_site_page.wait_for_site_id project_site
    @canvas_page.add_users(project_site, project_site.manual_members)
  end

  after(:all) { Utils.quit_browser @driver }

  it 'is not added to site navigation by default' do
    @canvas_page.load_course_site course_site_1
    expect(@mailing_list_page.mailing_list_link?).to be false
  end

  (course_site_1.manual_members + [test.canvas_admin]).each do |user|
    if ['Canvas Admin', 'Teacher', 'Lead TA', 'TA', 'Reader'].include? user.role
      it "can be managed by a course #{user.role}" do
        @canvas_page.masquerade_as(user, course_site_1)
        @mailing_list_page.load_embedded_tool course_site_1
        @mailing_list_page.create_list_button_element.when_present Utils.short_wait
      end
    elsif %w[Designer Observer Student].include? user.role
      it "cannot be managed by a course #{user.role}" do
        @canvas_page.masquerade_as(user, course_site_1)
        @mailing_list_page.load_embedded_tool course_site_1
        @mailing_list_page.unauthorized_msg_element.when_present Utils.short_wait
      end
    end
    if 'Canvas Admin' == user.role
      it "can be managed by a course #{user.role} via the admin tool" do
        @mailing_lists_page.load_embedded_tool
        @mailing_lists_page.search_for_list course_site_1.site_id
      end
    else
      it "cannot be managed by a course #{user.role} via the admin tool" do
        @mailing_lists_page.load_embedded_tool
        @mailing_lists_page.unauthorized_msg_element.when_present Utils.short_wait
      end
    end
  end

  describe 'admin tool' do

    before(:all) do
      @canvas_page.switch_to_main_content
      @canvas_page.stop_masquerading if @canvas_page.stop_masquerading_link?
      @mailing_lists_page.load_embedded_tool
    end

    context 'when creating a list' do

      it 'requires a valid numeric site ID in order to find a site' do
        @mailing_lists_page.search_for_list '99999999'
        @mailing_lists_page.not_found_msg_element.when_visible timeout
      end

      it 'retrieves a course site for a valid numeric site ID' do
        @mailing_lists_page.search_for_list course_site_1.site_id
        @mailing_lists_page.register_list_button_element.when_visible timeout
      end

      it('shows the course site code') { expect(@mailing_lists_page.site_name_link_element.text).to include(course_site_1.title) }
      it('shows the course site term') { expect(@mailing_lists_page.site_term).to eql(course_site_1.term.name) }
      it('shows the course site ID') { expect(@mailing_lists_page.site_id).to eql("bCourses Site ID #{course_site_1.site_id}") }

      it 'shows a link to the course site' do
        expect(@mailing_lists_page.external_link_valid?(@mailing_lists_page.site_name_link_element, course_site_1.title)).to be true
      end

      it 'shows a default mailing list name' do
        @mailing_lists_page.switch_to_canvas_iframe
        @mailing_lists_page.wait_until(Utils.short_wait) do
          @mailing_lists_page.list_name_input_element.value == @mailing_lists_page.default_list_name(course_site_1)[0..-6]
        end
      end

      it 'requires a non-default mailing list name have no spaces' do
        @mailing_lists_page.enter_custom_list_name 'lousy-list name'
        @mailing_lists_page.list_name_error_msg_element.when_visible timeout
      end

      it 'requires a non-default mailing list name have no invalid characters' do
        @mailing_lists_page.enter_custom_list_name 'lousier-list-name?'
        @mailing_lists_page.list_name_error_msg_element.when_visible timeout
      end

      it 'creates a mailing list with a valid, unique mailing list name' do
        @mailing_lists_page.enter_custom_list_name @mailing_lists_page.default_list_name(course_site_1)[0..-6]
        expected_list_name = "#{@mailing_lists_page.default_list_name course_site_1}@bcourses-mail.berkeley.edu"
        @mailing_lists_page.wait_until(timeout) do
          logger.info "Expected #{expected_list_name}; actual #{@mailing_lists_page.list_address}"
          @mailing_lists_page.list_address == expected_list_name
        end
      end

      it 'will not create a mailing list for a course site with the same course code as an existing list' do
        @mailing_lists_page.click_cancel_list
        @mailing_lists_page.search_for_list course_site_2.site_id
        @mailing_lists_page.enter_custom_list_name @mailing_lists_page.default_list_name(course_site_1)[0..-6]
        @mailing_lists_page.list_name_taken_error_msg_element.when_visible timeout
      end
    end

    context 'when viewing a list' do

      before(:all) do
        @mailing_lists_page.load_embedded_tool
        @mailing_lists_page.search_for_list course_site_1.site_id
        @mailing_lists_page.list_address_element.when_visible timeout
      end

      it 'shows the mailing list email address' do
        expected_list_name = "#{@mailing_lists_page.default_list_name course_site_1}@bcourses-mail.berkeley.edu"
        @mailing_lists_page.wait_until(timeout) do
          logger.info "Expected #{expected_list_name}; actual #{@mailing_lists_page.list_address}"
          @mailing_lists_page.list_address == expected_list_name
        end
      end

      it('shows the membership count') { expect(@mailing_lists_page.list_membership_count).to eql('0') }
      it('shows the most recent membership update') { expect(@mailing_lists_page.list_update_time).to eql('Never') }
      it('shows the course site code') { expect(@mailing_lists_page.list_site_link_element.text).to eql(course_site_1.title) }
      it('shows the course site title and term') { expect(@mailing_lists_page.list_site_desc).to eql("#{course_site_1.abbreviation}, #{course_site_1.term.name}") }
      it('shows the course site ID') { expect(@mailing_lists_page.list_site_id).to eql(course_site_1.site_id) }
      it('shows a link to the course site') { expect(@mailing_lists_page.external_link_valid?(@mailing_lists_page.list_site_link_element, course_site_1.title)).to be true }

      it 'creates mailing list memberships for users who are confirmed members of the site' do
        @canvas_page.switch_to_canvas_iframe
        @mailing_lists_page.click_update_memberships
        @mailing_lists_page.update_membership_again_button_element.when_present Utils.short_wait
        sleep 1
        expect(@mailing_lists_page.list_membership_count).to eql("#{course_site_1.manual_members.length}")
        expect(@mailing_lists_page.list_update_time).to include(Time.now.strftime '%b %-d, %Y')
      end

      it 'shows a list of members who have been added to the mailing list' do
        @mailing_lists_page.expand_added_users
        course_site_1.manual_members.each do |user|
          logger.info "Checking if #{user.username} has been added"
          expect(@mailing_lists_page.user_added?(user)).to be true
        end
      end

      it 'deletes mailing list memberships for users who have been removed from the site' do
        @canvas_page.remove_users_from_course(course_site_1, [course_site_1.manual_members.last])
        @mailing_lists_page.load_embedded_tool
        @mailing_lists_page.search_for_list course_site_1.site_id
        @mailing_lists_page.click_update_memberships
        @mailing_lists_page.update_membership_again_button_element.when_present Utils.short_wait
        sleep 1
        expect(@mailing_lists_page.list_membership_count).to eql("#{course_site_1.manual_members.length - 1}")
      end

      it 'shows a list of members who have been removed from the mailing list' do
        @mailing_lists_page.expand_removed_users
        logger.info "Checking if #{course_site_1.manual_members.last.username} has been removed"
        expect(@mailing_lists_page.user_removed?(course_site_1.manual_members.last)).to be true
      end

      it 'creates mailing list memberships for users who have been restored to the site' do
        @canvas_page.add_users(course_site_1, [course_site_1.manual_members.last])
        @canvas_page.masquerade_as(course_site_1.manual_members.last, course_site_1)
        @canvas_page.stop_masquerading
        @mailing_lists_page.load_embedded_tool
        @mailing_lists_page.search_for_list course_site_1.site_id
        @mailing_lists_page.click_update_memberships
        @mailing_lists_page.update_membership_again_button_element.when_present Utils.short_wait
        sleep 1
        expect(@mailing_lists_page.list_membership_count).to eql("#{course_site_1.manual_members.length}")
      end

      it 'shows a list of members who have been restored to the mailing list' do
        @mailing_lists_page.expand_restored_users
        logger.info "Checking if #{course_site_1.manual_members.last.username} has been restored"
        expect(@mailing_lists_page.user_restored?(course_site_1.manual_members.last)).to be true
      end

      it 'updates a mailing list member\'s email address' do
        RipleyUtils.set_mailing_list_member_email(course_site_1.manual_members.last, "foo#{Time.now.to_i}@bar.com")
        @mailing_lists_page.load_embedded_tool
        @mailing_lists_page.search_for_list course_site_1.site_id
        @mailing_lists_page.click_update_memberships
        @mailing_lists_page.update_membership_again_button_element.when_present Utils.short_wait
        sleep 1
        @mailing_lists_page.expand_added_users
        expect(@mailing_lists_page.user_added?(course_site_1.manual_members.last)).to be true
        @mailing_lists_page.expand_removed_users
      end
    end

    context 'when updating a list via Ripley Jobs' do

      it 'deletes mailing list memberships for users who have been removed from the site' do
        @canvas_page.remove_users_from_course(course_site_1, [course_site_1.manual_members.last])
        @splash_page.load_page
        @jobs_page.run_job RipleyJob::REFRESH_MAILING_LIST
        @mailing_lists_page.load_embedded_tool
        @mailing_lists_page.search_for_list course_site_1.site_id
        @mailing_lists_page.list_membership_count_element.when_present Utils.short_wait
        expect(@mailing_lists_page.list_membership_count).to eql("#{course_site_1.manual_members.length - 1}")
      end

      it 'creates mailing list memberships for users who have been restored to the site' do
        @canvas_page.add_users(course_site_1, [course_site_1.manual_members.last])
        @canvas_page.masquerade_as(course_site_1.manual_members.last, course_site_1)
        @canvas_page.stop_masquerading
        @splash_page.load_page
        @jobs_page.run_job RipleyJob::REFRESH_MAILING_LIST
        @mailing_lists_page.load_embedded_tool
        @mailing_lists_page.search_for_list course_site_1.site_id
        @mailing_lists_page.list_membership_count_element.when_present Utils.short_wait
        expect(@mailing_lists_page.list_membership_count).to eql("#{course_site_1.manual_members.length}")
      end

      it 'updates a mailing list member\'s email address' do
        RipleyUtils.set_mailing_list_member_email(course_site_1.manual_members.last, "bar#{Time.now.to_i}@foo.com")
        @splash_page.load_page
        @jobs_page.run_job RipleyJob::REFRESH_MAILING_LIST
        updated = RipleyUtils.get_mailing_list_member_email course_site_1.manual_members.last
        expect(updated).not_to eql('foo@bar.com')
      end

      it 'does not update mailing list memberships for lists from two terms past' do
        @mailing_lists_page.load_embedded_tool
        @mailing_lists_page.search_for_list course_site_4.site_id
        @mailing_lists_page.enter_custom_list_name @mailing_lists_page.default_list_name(course_site_4)[0..-6]
        expected_list_name = "#{@mailing_lists_page.default_list_name course_site_4}@bcourses-mail.berkeley.edu"
        @mailing_lists_page.wait_until(timeout) do
          logger.info "Expected #{expected_list_name}; actual #{@mailing_lists_page.list_address}"
          @mailing_lists_page.list_address == expected_list_name
        end

        @canvas_page.masquerade_as(course_site_4.manual_members.first, course_site_4)
        @canvas_page.stop_masquerading
        @splash_page.load_page
        @jobs_page.run_job RipleyJob::REFRESH_MAILING_LIST
        @mailing_lists_page.load_embedded_tool
        @mailing_lists_page.search_for_list course_site_4.site_id
        @mailing_lists_page.list_membership_count_element.when_present Utils.short_wait
        expect(@mailing_lists_page.list_membership_count).to eql('0')
      end
    end
  end

  describe 'instructor-facing tool' do

    before(:all) do
      course_site_2.title = course_site_1.title
      @canvas_page.edit_course_name course_site_2
      @canvas_page.masquerade_as(course_site_2.manual_members.first, course_site_3)
      @mailing_list_page.load_embedded_tool course_site_3
    end

    context 'when no mailing list exists' do

      it 'shows a "no existing list" message' do
        @mailing_list_page.wait_until(timeout) { @mailing_list_page.no_list_msg? }
      end

      it 'allows the user to create a mailing list with a default list name' do
        @mailing_list_page.create_list
        expect(@mailing_list_page.list_address).to eql("#{@mailing_lists_page.default_list_name course_site_3}@bcourses-mail.berkeley.edu")
      end

      it 'will not create a mailing list for a course site with the same course code and term as an existing list' do
        @canvas_page.load_course_site course_site_2
        @mailing_list_page.load_embedded_tool course_site_2
        @mailing_list_page.click_create_list
        @mailing_list_page.list_dupe_email_msg_element.when_present timeout
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

  describe 'project sites' do

    before(:all) { @canvas_page.stop_masquerading }

    it 'allow an admin to create a list' do
      @mailing_lists_page.load_embedded_tool
      @mailing_lists_page.search_for_list project_site.site_id
      @mailing_lists_page.enter_custom_list_name @mailing_lists_page.default_list_name(project_site)
      expected_list_name = "#{@mailing_lists_page.default_list_name project_site}@bcourses-mail.berkeley.edu"
      @mailing_lists_page.wait_until(timeout) do
        logger.info "Expected #{expected_list_name}; actual #{@mailing_lists_page.list_address}"
        @mailing_lists_page.list_address == expected_list_name
      end
    end

    it 'allow an admin to update the list membership' do
      @mailing_lists_page.click_update_memberships
      @mailing_lists_page.update_membership_again_button_element.when_present Utils.short_wait
    end
  end
end
