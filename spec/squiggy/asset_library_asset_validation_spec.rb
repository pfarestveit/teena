require_relative '../../util/spec_helper'

describe 'Asset Library' do

  before(:all) do
    @test = SquiggyTestConfig.new 'asset_creation'
    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net= Page::CalNetPage.new @driver
    @assets_list = SquiggyAssetLibraryListViewPage.new @driver
    @asset_detail = SquiggyAssetLibraryDetailPage.new @driver
    @manage_assets = SquiggyAssetLibraryManageAssetsPage.new @driver

    @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course @test

    # TODO Create two categories but delete one

    @canvas.masquerade_as(@test.course.teachers.first, @test.course)
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'links' do
    it 'can be added with title, category, and description'
    it 'can be added with title and category only'
    it 'can be added with title only'
    it 'can be added with title and description only'
    it 'earn "Add a new asset to the Asset Library" points on the Engagement Index'
    it 'add "add_asset" activity to the CSV export'
    it 'require that the user enter a URL'
    it 'require that the user enter a valid URL'
    it 'require that the user enter a title'
    it 'limit a title to 255 characters'
    it 'do not have a default category'
    it 'can have only non-deleted categories'
    it 'can be canceled and not added'
  end

  describe 'files' do
    it 'can be added with title, category, and description'
    it 'can be added with title and category only'
    it 'can be added with title only'
    it 'can be added with title and description only'
    it 'earn "Add a new asset to the Asset Library" points on the Engagement Index'
    it 'add "add_asset" activity to the CSV export'
    it 'require that the user enter a title'
    it 'limit a title to 255 characters'
    it 'do not have a default category'
    it 'can have only non-deleted categories'
    it 'can be canceled and not added'
  end
end


