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
    @oec_user = User.new uid: JunctionUtils.junction_oec_user_uid
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
    it('shows no OEC interface') { expect(@toolbox_page.oec_task_select?).to be false }
  end

  describe 'OEC view' do

    before(:all) { @splash_page.basic_auth @oec_user.uid }

    after(:all) { @toolbox_page.log_out }

    it('shows an OEC interface') { @toolbox_page.oec_task_select_element.when_visible Utils.short_wait }
    it('shows no View As interface') { expect(@toolbox_page.view_as_input?).to be false }

    it 'offers a dropdown with all expected OEC tasks' do
      tasks = ['Term setup',
               'SIS data import',
               'Create confirmation sheeets',
               'Diff confirmation sheets',
               'Merge confirmation sheets',
               'Validate confirmed data',
               'Publish confirmed data to Explorance']
      expect(@toolbox_page.visible_oec_task_options & tasks).to eql(tasks)
    end

    it 'shows all participating departments' do
      depts = OECDepartments::DEPARTMENTS.map &:file_name
      logger.debug "Teena's departments: #{depts.sort}"
      @toolbox_page.toggle_oec_depts_visibility
      logger.debug "Junction's departments: #{@toolbox_page.visible_participating_depts.sort}"
      expect(@toolbox_page.visible_participating_depts.sort).to eql(depts.sort)
    end
  end

  describe 'admin view' do

    before(:all) { @splash_page.basic_auth @super_user.uid }

    after(:all) { @toolbox_page.log_out }

    it 'allows the user to view as another user via the view-as input'
    it 'saves a viewed-as user in the "Recent" list'

    it('shows an OEC interface') { @toolbox_page.oec_task_select_element.when_visible Utils.short_wait }

    it 'offers a dropdown with all expected OEC tasks' do
      tasks = ['Term setup',
               'SIS data import',
               'Create confirmation sheets',
               'Diff confirmation sheets',
               'Merge confirmation sheets',
               'Validate confirmed data',
               'Publish confirmed data to Explorance']
      expect(@toolbox_page.visible_oec_task_options & tasks).to eql(tasks)
    end

    it 'shows all participating departments' do
      depts = OECDepartments::DEPARTMENTS.map &:dept_name
      depts.uniq!
      @toolbox_page.select_task 'SIS data import'
      @toolbox_page.toggle_oec_depts_visibility
      @toolbox_page.wait_until(1, "Missing: #{depts - @toolbox_page.visible_participating_depts},
                                              Unexpected: #{@toolbox_page.visible_participating_depts - depts}") do
        @toolbox_page.visible_participating_depts.sort == depts.sort
      end
    end
  end
end
