require_relative '../../util/spec_helper'

describe 'BOAC' do

  before(:all) do
    @auth_user = BOACUser.new({:uid => Utils.super_admin_uid, :username => Utils.super_admin_username})

    @driver = Utils.launch_browser
    @home_page = BOACHomePage.new @driver
    @cal_net_page = Page::CalNetPage.new @driver
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when someone is not an authorized user' do

    before { BOACUtils.delete_auth_user @auth_user }

    it 'disallows login' do
      @home_page.load_page
      @home_page.click_sign_in_button
      @cal_net_page.log_in(@auth_user, Utils.super_admin_password)
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
