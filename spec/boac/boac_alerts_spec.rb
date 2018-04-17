require_relative '../../util/spec_helper'

describe 'A BOAC alert' do

  include Logging

  before(:all) do
    @alert = BOACUtils.get_test_alert
    @advisor = BOACUtils.get_authorized_users.find { |u| u.uid != Utils.super_admin_uid }
    BOACUtils.remove_alert_dismissal(@alert) if BOACUtils.get_dismissed_alerts([@alert], @advisor).any?

    @driver = Utils.launch_browser
    @homepage = Page::BOACPages::HomePage.new @driver
    @student_page = Page::BOACPages::StudentPage.new @driver
    @homepage.dev_auth
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when not dismissed' do

    before(:all) { @student_page.load_page @alert.user }

    it('is shown by default on the student page') do
      @student_page.wait_until(Utils.short_wait) { @student_page.non_dismissed_alert_msgs.include? @alert.message }
    end
  end

  context 'when dismissed' do

    before(:all) { @student_page.dismiss_alert @alert }

    it 'is no longer shown by default' do
      @student_page.wait_until(1) { !@student_page.non_dismissed_alert_msgs.include? @alert.message }
      expect(@student_page.dismissed_alert_msgs).to include(@alert.message)
      @student_page.wait_until(1) { !@student_page.dismissed_alert_msg_elements.any?(&:visible?) }
    end

    it 'can be revealed' do
      @student_page.click_view_dismissed_alerts
      @student_page.wait_until(1) { @student_page.dismissed_alert_msg_elements.all? &:visible? }
    end

    it 'can be hidden' do
      @student_page.click_hide_dismissed_alerts
      @student_page.wait_until(1) { !@student_page.dismissed_alert_msg_elements.any?(&:visible?) }
    end

    it 'is not dismissed for other users' do
      @student_page.log_out
      @homepage.dev_auth @advisor
      @student_page.load_page @alert.user
      @student_page.wait_until(Utils.short_wait) { @student_page.non_dismissed_alert_msgs.include? @alert.message }
    end
  end
end
