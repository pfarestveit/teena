require_relative '../../util/spec_helper'

describe 'bCourses welcome email', order: :defined do

  include Logging

  before(:all) do
    @test = RipleyTestConfig.new
    @site = @test.welcome_email
    @email = Email.new("Welcome Email #{@test.id}", "Teena welcomes you")
    @teacher = @site.manual_members.find { |m| m.role == 'Teacher' }
    @student1, @student2, @student3 = @site.manual_members.select { |m| m.role == 'Student' }
    @site_members = [@teacher, @student1]

    # Browser for instructor
    @driver1 = Utils.launch_browser
    @canvas1 = Page::CanvasPage.new @driver1
    @cal_net1 = Page::CalNetPage.new @driver1
    @mailing_list = RipleyMailingListPage.new @driver1
    @canvas1.log_in(@cal_net1, @test.admin.username, Utils.super_admin_password)
    @canvas1.add_ripley_tools RipleyTool::TOOLS.select(&:account)
    @canvas1.set_canvas_ids @site.manual_members

    # Browser for admin
    @driver2 = Utils.launch_browser
    @canvas2 = Page::CanvasPage.new @driver2
    @cal_net2 = Page::CalNetPage.new @driver2
    @ripley2 = RipleySplashPage.new @driver2
    @mailing_lists = RipleyMailingListsPage.new @driver2
    @canvas2.log_in(@cal_net2, @test.admin.username, Utils.super_admin_password)

    @canvas2.create_ripley_mailing_list_site(@site, @site_members)
    @canvas1.masquerade_as(@student1, @site)
    @canvas1.masquerade_as(@teacher, @site)
  end

  after(:all) { Utils.quit_browser @driver1; Utils.quit_browser @driver2 }

  context 'creation' do

    before(:all) do
      @mailing_list.load_embedded_tool @site
      @mailing_list.create_list
    end

    it 'includes a link to more information' do
      title = 'IT - How do I send a welcome email to newly enrolled students with the bCourses Mailing List tool?'
      expect(@mailing_list.external_link_valid?(@mailing_list.welcome_email_link_element, title)).to be true
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
      @mailing_lists.load_embedded_tool
      @mailing_lists.search_for_list @site.site_id
    end

    it 'is sent to existing members of the site' do
      # Update membership
      @mailing_lists.click_update_memberships

      # Verify new emails triggered
      @mailing_list.load_embedded_tool @site
      csv = @mailing_list.download_csv
      expect(csv[:email_address].sort).to eql(@site_members.map(&:email).sort)
    end

    it 'is sent to new members of the site' do
      # Add student, accept invite
      @canvas2.add_users(@site, [@student2])
      @site_members << @student2
      @canvas2.masquerade_as(@student2, @site)
      @canvas2.stop_masquerading

      # Update membership
      @mailing_lists.load_embedded_tool
      @mailing_lists.search_for_list @site.site_id
      @mailing_lists.click_update_memberships

      # Verify new email triggered
      @mailing_list.load_embedded_tool @site
      csv = @mailing_list.download_csv
      expect(csv[:email_address].sort).to eql(@site_members.map(&:email).sort)
    end
  end

  context 'when paused' do

    before(:all) do
      @mailing_list.load_embedded_tool @site
      @mailing_list.click_activation_toggle
    end

    it 'is not sent to new members of the site' do
      # Add student, accept invite
      @canvas2.add_users(@site, [@student3])
      @canvas2.masquerade_as(@student3, @site)
      @canvas2.stop_masquerading

      # Update membership
      @mailing_lists.load_embedded_tool
      @mailing_lists.search_for_list @site.site_id
      @mailing_lists.click_update_memberships

      # Verify no new email triggered
      @mailing_list.load_embedded_tool @site
      csv = @mailing_list.download_csv
      expect(csv[:email_address].sort).to eql([@site_members, @student3].flatten.map(&:email).sort)
      expect(csv[:message_sent].compact.length).to eql(3)
    end
  end
end
