require_relative '../../util/spec_helper'

describe 'BOAC' do

  before(:all) do
    @auth_user = BOACUser.new({:uid => Utils.super_admin_uid, :username => Utils.super_admin_username})
    @initial_logins = BOACUtils.get_user_login_count @auth_user

    @driver = Utils.launch_browser
    @home_page = BOACHomePage.new @driver
    @cal_net_page = Page::CalNetPage.new @driver
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when an authorized user logs in' do

    before { @home_page.log_in(@auth_user.username, Utils.super_admin_password, @cal_net_page) }
    after { @home_page.log_out }

    it('records the login') { expect(BOACUtils.get_user_login_count @auth_user).to eql(@initial_logins + 1) }
  end

  context 'when an authorized user is deleted' do

    before { BOACUtils.soft_delete_auth_user @auth_user }

    it 'disallows login' do
      @home_page.load_page
      @home_page.click_sign_in_button
      @cal_net_page.log_in(@auth_user.username, Utils.super_admin_password)
      @home_page.not_auth_msg_element.when_visible Utils.short_wait
    end
  end

  context 'when an authorized user is restored' do

    before { BOACUtils.restore_auth_user @auth_user }
    after { @home_page.log_out }

    it 'allows login' do
      @home_page.click_sign_in_button
      @home_page.wait_for_title 'Home'
    end
  end

  context 'when someone is not an authorized user' do

    before { BOACUtils.hard_delete_auth_user @auth_user }

    it 'disallows login' do
      @home_page.load_page
      @home_page.click_sign_in_button
      @cal_net_page.log_in(@auth_user.username, Utils.super_admin_password)
      @home_page.not_auth_msg_element.when_visible Utils.short_wait
    end
  end

  context 'when someone is an authorized user' do

    before { BOACUtils.create_auth_user @auth_user }

    it 'allows login' do
      @home_page.click_sign_in_button
      @home_page.wait_for_title 'Home'
    end
  end
end
