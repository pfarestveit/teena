require_relative '../../util/spec_helper'

describe 'Asset' do

  before(:all) do
    @test = SquiggyTestConfig.new 'asset_mgmt'
    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net= Page::CalNetPage.new @driver
    @assets_list = SquiggyAssetLibraryListViewPage.new @driver
    @asset_detail = SquiggyAssetLibraryDetailPage.new @driver
    @manage_assets = SquiggyAssetLibraryManageAssetsPage.new @driver

    @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course @test

    @canvas.masquerade_as(@test.course.teachers.first, @test.course)
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'metadata edits' do
    it 'are not allowed if the user is a student who is not the asset creator'
    it 'are allowed if the user is a teacher'
    it 'are allowed if the user is a student who is the asset creator'
  end

  describe 'deletion' do

    context 'when the asset has no comments or likes and has not been used on a whiteboard' do
      it 'can be done by a teacher with no effect on points already earned'
      it 'can be done by the student who created the asset with no effect on points already earned'
      it 'cannot be done by a student who did not create the asset'
    end

    context 'when there are comments on the asset' do
      it 'can be done by a teacher with no effect on points already earned'
      it 'cannot be done by the student who created the asset'
      it 'cannot be done by a student who did not create the asset'
    end

    context 'when there are likes on the asset' do
      it 'can be done by a teacher with no effect on points already earned'
      it 'cannot be done by the student who created the asset'
      it 'cannot be done by a student who did not create the asset'
    end
  end

  describe 'migration' do
    it 'copies File type assets'
    it 'copies Link type assets'
    it 'does not copy deleted assets'
  end
end

