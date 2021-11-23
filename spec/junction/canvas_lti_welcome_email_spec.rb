unless ENV['STANDALONE']

  require_relative '../../util/spec_helper'

  describe 'bCourses welcome email', order: :defined do

    include Logging

    before(:all) do
      @test = JunctionTestConfig.new
      @test.mailing_lists
      @course = Course.new title: "#{@test.id} Welcome", code: "#{@test.id} Welcome Email"
      @email = Email.new("Welcome Email #{@test.id}", "Teena welcomes you")
      @site_members = [@test.manual_teacher, @test.students.first]

      # Browser for instructor
      @driver1 = Utils.launch_browser
      @canvas1 = Page::CanvasPage.new @driver1
      @cal_net1 = Page::CalNetPage.new @driver1
      @mailing_list = Page::JunctionPages::CanvasMailingListPage.new @driver1
      @canvas1.log_in(@cal_net1, Utils.super_admin_username, Utils.super_admin_password)

      # Browser for admin
      @driver2 = Utils.launch_browser
      @canvas2 = Page::CanvasPage.new @driver2
      @cal_net2 = Page::CalNetPage.new @driver2
      @junction2 = Page::JunctionPages::SplashPage.new @driver2
      @mailing_lists = Page::JunctionPages::CanvasMailingListsPage.new @driver2
      @canvas2.log_in(@cal_net2, Utils.super_admin_username, Utils.super_admin_password)

      @canvas2.create_generic_course_site(Utils.canvas_official_courses_sub_account, @course, @site_members, @test.id)
      @canvas1.masquerade_as(@test.students[0], @course)
      @canvas1.masquerade_as(@test.manual_teacher, @course)
    end

    after(:all) { Utils.quit_browser @driver1; Utils.quit_browser @driver2 }

    context 'creation' do

      before(:all) do
        @mailing_list.load_embedded_tool @course
        @mailing_list.create_list
      end

      it 'includes a link to more information' do
        expect(@mailing_list.external_link_valid?(@mailing_list.welcome_email_link_element, 'Service at UC Berkeley')).to be true
      end

      it('is not possible with an empty subject or body') do
        @mailing_list.switch_to_canvas_iframe if @canvas1.canvas_iframe?
        expect(@mailing_list.email_save_button_element.disabled?).to be true
      end

      it 'is possible with a subject and body' do
        @mailing_list.enter_email_subject @email.subject
        @mailing_list.enter_email_body @email.body
        @mailing_list.click_save_email_button
        expect(@mailing_list.email_subject).to eql(@email.subject)
        expect(@mailing_list.email_body).to eql(@email.body)
      end

      it('sets the email to paused by default') { expect(@mailing_list.email_paused_msg?).to be true }
    end

    context 'edits' do

      it 'can be canceled' do
        @mailing_list.click_edit_email_button
        @mailing_list.enter_email_subject "#{@email.subject} - edited"
        @mailing_list.enter_email_body "#{@email.body} - edited"
        @mailing_list.click_cancel_edit_button
        expect(@mailing_list.email_subject).to eql(@email.subject)
        expect(@mailing_list.email_body).to eql(@email.body)
      end

      it 'can be saved' do
        @mailing_list.click_edit_email_button
        @mailing_list.enter_email_subject(@email.subject = "#{@email.subject} - edited")
        @mailing_list.enter_email_body(@email.body = "#{@email.body} - edited")
        @mailing_list.click_save_email_button
        expect(@mailing_list.email_subject).to eql(@email.subject)
        expect(@mailing_list.email_body).to eql(@email.body)
      end
    end

    context 'when activated' do

      before(:all) do
        @mailing_list.click_activation_toggle
        @mailing_list.email_activated_msg_element.when_visible 3
        @mailing_lists.load_embedded_tool
        @mailing_lists.search_for_list @course.site_id
      end

      it 'is sent to existing members of the site' do
        # Update membership
        @mailing_lists.click_update_memberships

        # Verify new emails triggered
        @mailing_list.load_embedded_tool @course
        csv = @mailing_list.download_csv
        expect(csv[:email_address].sort).to eql(@site_members.map(&:email).sort)
      end

      it 'is sent to new members of the site' do
        # Add student, accept invite
        @canvas2.add_users(@course, [@test.students[1]])
        @site_members << @test.students[1]
        @canvas2.masquerade_as(@test.students[1], @course)
        @canvas2.stop_masquerading

        # Update membership
        JunctionUtils.clear_cache(@driver2, @junction2)
        @mailing_lists.load_embedded_tool
        @mailing_lists.search_for_list @course.site_id
        @mailing_lists.click_update_memberships

        # Verify new email triggered
        @mailing_list.load_embedded_tool @course
        csv = @mailing_list.download_csv
        expect(csv[:email_address].sort).to eql(@site_members.map(&:email).sort)
      end
    end

    context 'when paused' do

      before(:all) do
        @mailing_list.click_activation_toggle
        @mailing_list.email_paused_msg_element.when_visible 3
      end

      it 'is not sent to new members of the site' do
        # Add student, accept invite
        @canvas2.add_users(@course, [@test.students[2]])
        @canvas2.masquerade_as(@test.students[2], @course)
        @canvas2.stop_masquerading

        # Update membership
        JunctionUtils.clear_cache(@driver2, @junction2)
        @mailing_lists.load_embedded_tool
        @mailing_lists.search_for_list @course.site_id
        @mailing_lists.click_update_memberships

        # Verify no new email triggered
        @mailing_list.load_embedded_tool @course
        csv = @mailing_list.download_csv
        expect(csv[:email_address].sort).to eql(@site_members.map(&:email).sort)
      end

    end
  end
end
