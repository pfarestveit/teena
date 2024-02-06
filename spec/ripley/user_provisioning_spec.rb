require_relative '../../util/spec_helper'

test = RipleyTestConfig.new
test.user_provisioning
test_users = [
  test.manual_teacher,
  test.lead_ta,
  test.ta,
  test.designer,
  test.observer,
  test.reader,
  test.students.first
]

describe 'User Provisioning' do

  before(:all) do
    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @splash_page = RipleySplashPage.new @driver
    @canvas = Page::CanvasPage.new @driver
    @canvas_api = CanvasAPIPage.new @driver
    @user_prov_tool = RipleyUserProvisioningPage.new @driver

    @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
    @canvas.add_ripley_tools RipleyTool::TOOLS.select(&:account)
    @canvas.set_canvas_ids test_users
    @canvas_api.get_support_admin_canvas_id test.canvas_admin
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when the user is an authorized user' do

    it 'can be reached from a navigation link' do
      @canvas.load_sub_account Utils.canvas_uc_berkeley_sub_account
      @canvas.click_user_prov
    end
  end

  context 'when the user is an authorized user' do

    before(:each) { @user_prov_tool.load_embedded_tool }

    it 'provisions users via line break separated UIDs' do
      uids = test_users.map(&:uid).join("\n")
      @user_prov_tool.enter_uids_and_submit uids
      @user_prov_tool.success_msg_element.when_visible Utils.long_wait
    end

    it 'provisions users via space separated UIDs' do
      uids = test_users.map(&:uid).join(' ')
      @user_prov_tool.enter_uids_and_submit uids
      @user_prov_tool.success_msg_element.when_visible Utils.long_wait
    end

    it 'provisions users via comma separated UIDs' do
      uids = test_users.map(&:uid).join(',')
      @user_prov_tool.enter_uids_and_submit uids
      @user_prov_tool.success_msg_element.when_visible Utils.long_wait
    end

    it 'rejects non-numeric input' do
      uids = 'Starchild'
      @user_prov_tool.enter_uids_and_submit uids
      @user_prov_tool.non_numeric_msg_element.when_visible Utils.short_wait
    end

    it 'rejects more than 200 UIDs' do
      uids = test_users.map(&:uid).join(' ')
      uids = "#{uids} " * 29
      @user_prov_tool.enter_uids_and_submit uids
      @user_prov_tool.max_input_msg_element.when_visible Utils.short_wait
    end
  end

  context 'when the user is a Canvas admin' do

    it 'permits the user to reach the tool' do
      @canvas.masquerade_as test.canvas_admin
      @user_prov_tool.load_embedded_tool
      @user_prov_tool.uid_input_element.when_present Utils.short_wait
    end
  end

  context 'when the user is not an authorized user' do

    test_users.each do |user|
      it "prevents the #{user.role} from reaching the tool" do
        @canvas.masquerade_as user
        @user_prov_tool.load_embedded_tool
        @user_prov_tool.unauthorized_msg_element.when_visible Utils.short_wait
      end
    end
  end
end
