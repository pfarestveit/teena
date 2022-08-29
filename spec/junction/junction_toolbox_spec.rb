require_relative '../../util/spec_helper'

standalone = ENV['STANDALONE']

include Logging

describe 'The Junction Toolbox' do

  before(:all) do
    @driver = Utils.launch_browser
    @splash_page = Page::JunctionPages::SplashPage.new @driver
    @toolbox_page = Page::JunctionPages::MyToolboxPage.new @driver
    @calnet_page = Page::CalNetPage.new @driver

    @super_user = User.new uid: Utils.super_admin_uid, username: Utils.super_admin_username
    @basic_user = User.new OecUtils.oec_user
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'non-admin, non-OEC view' do

    before(:all) do
      @splash_page.load_page
      @splash_page.basic_auth @basic_user.uid
    end

    after(:all) { @toolbox_page.log_out }

    it('shows a delightful choo choo train image') { @toolbox_page.conjunction_junction_element.when_visible Utils.short_wait }
    it('shows no View As interface') { expect(@toolbox_page.view_as_input?).to be false }
  end

  describe 'admin view' do

    before(:all) { @splash_page.basic_auth @super_user.uid }

    after(:all) { @toolbox_page.log_out }

    it 'allows the user to view as another user via the view-as input'
    it 'saves a viewed-as user in the "Recent" list'

  end
end
