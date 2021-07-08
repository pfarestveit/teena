require_relative '../../util/spec_helper'

include Logging

describe 'Asset Library' do

  before(:all) do
    @test = SquiggyTestConfig.new 'asset_mgmt'
    @test.course.site_id = ENV['COURSE_ID']
    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net= Page::CalNetPage.new @driver
    @assets_list = SquiggyAssetLibraryListViewPage.new @driver
    @asset_detail = SquiggyAssetLibraryDetailPage.new @driver
    @manage_assets = SquiggyAssetLibraryManageAssetsPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver

    @cat_0 = SquiggyCategory.new "Category 1 #{@test.id}"
    @cat_1 = SquiggyCategory.new "Category 2 #{@test.id}"
    @teacher = @test.teachers.first

    @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course @test

    @canvas.masquerade_as(@teacher, @test.course)
    @assets_list.load_page @test
    @assets_list.click_manage_assets_link
    @manage_assets.create_new_category @cat_0
    @manage_assets.create_new_category @cat_1
    @manage_assets.delete_category @cat_1
  end

  after(:all) do
    @assets_list.load_page @test
    @assets_list.click_manage_assets_link
    @manage_assets.delete_category @cat_0
  ensure
    Utils.quit_browser @driver
  end

  describe 'links' do

    before(:all) do
      @asset = @teacher.assets.find &:url
      @title = @asset.title
      @desc = "Description - #{@test.id}"
      @url = @asset.url
      @initial_score = @engagement_index.user_score(@test, @teacher)
      @assets_list.load_page @test
    end

    it 'can be added with title, category, and description' do
      @asset.title = "#{@title} 1"
      @asset.description = @desc
      @asset.category = @cat_0
      @assets_list.add_link_asset @asset
      expect(@asset.id).not_to be_nil
    end

    it 'earn "Add a new asset to the Asset Library" points on the Engagement Index' do
      expect(@engagement_index.user_score(@test, @teacher)).to eql(@initial_score + SquiggyActivity::ADD_ASSET_TO_LIBRARY.points)
    end

    it 'add "add_asset" activity to the CSV export' do
      csv = @engagement_index.download_csv @test
      activity = csv.find do |r|
        r[:user_name] == @teacher.full_name &&
          r[:action] == SquiggyActivity::ADD_ASSET_TO_LIBRARY.type &&
          r[:score] == SquiggyActivity::ADD_ASSET_TO_LIBRARY.points &&
          r[:running_total] == (@initial_score + SquiggyActivity::ADD_ASSET_TO_LIBRARY.points)
      end
      expect(activity).to be_truthy
    end

    it 'can be added with title and category only' do
      @asset.title = "#{@title} 2"
      @asset.description = nil
      @asset.category = @cat_0
      @assets_list.load_page @test
      @assets_list.add_link_asset @asset
      expect(@asset.id).not_to be_nil
    end

    it 'can be added with title only' do
      @asset.title = "#{@title} 3"
      @asset.description = nil
      @asset.category = nil
      @assets_list.add_link_asset @asset
      expect(@asset.id).not_to be_nil
    end

    it 'can be added with title and description only' do
      @asset.title = "#{@title} 4"
      @asset.description = @desc
      @asset.category = nil
      @assets_list.add_link_asset @asset
      expect(@asset.id).not_to be_nil
    end

    it 'require that the user enter a URL' do
      @asset.title = "#{@title} 5"
      @asset.description = nil
      @asset.category = nil
      @asset.url = nil
      @assets_list.click_add_url_button
      @assets_list.enter_url @asset
      @assets_list.enter_asset_metadata @asset
      expect(@assets_list.save_link_button_element.enabled?).to be false
    end

    it 'require that the user enter a valid URL' do
      @asset.title = "#{@title} 6"
      @asset.description = nil
      @asset.category = nil
      @asset.url = 'fubar'
      @assets_list.click_cancel_link_button
      @assets_list.click_add_url_button
      @assets_list.enter_url @asset
      @assets_list.enter_asset_metadata @asset
      expect(@assets_list.url_input_element.value).to eql("http://#{@asset.url}")
    end

    it 'require that the user enter a title' do
      @asset.title = nil
      @asset.description = nil
      @asset.category = nil
      @asset.url = @url
      @assets_list.click_cancel_link_button
      @assets_list.click_add_url_button
      @assets_list.enter_url @asset
      @assets_list.enter_asset_metadata @asset
      expect(@assets_list.save_link_button_element.enabled?).to be false
    end

    it 'limit a title to 255 characters' do
      @asset.title = "#{'A loooooong title' * 16}?"
      @asset.description = nil
      @asset.category = nil
      @asset.url = @url
      @assets_list.click_cancel_link_button
      @assets_list.click_add_url_button
      @assets_list.enter_url @asset
      @assets_list.enter_asset_metadata @asset
      @assets_list.title_too_long_msg_element.when_visible 2
    end

    it 'can have only non-deleted categories' do
      @assets_list.click_cancel_link_button
      @assets_list.click_add_url_button
      @assets_list.click_category_asset_select
      expect(@assets_list.menu_option_el(@cat_1.name).exists?).to be false
    end
  end

  describe 'files' do

    before(:all) do
      @asset = @teacher.assets.find &:file_name
      @title = @asset.title
      @desc = "Description - #{@test.id}"
      @initial_score = @engagement_index.user_score(@test, @teacher)
      @assets_list.load_page @test
    end

    it 'can be added with title, category, and description' do
      @asset.title = "#{@title} 1"
      @asset.description = @desc
      @asset.category = @cat_0
      @assets_list.upload_file_asset @asset
      expect(@asset.id).not_to be_nil
    end

    it 'earn "Add a new asset to the Asset Library" points on the Engagement Index' do
      expect(@engagement_index.user_score(@test, @teacher)).to eql(@initial_score + SquiggyActivity::ADD_ASSET_TO_LIBRARY.points)
    end

    it 'add "add_asset" activity to the CSV export' do
      csv = @engagement_index.download_csv @test
      activity = csv.find do |r|
        r[:user_name] == @teacher.full_name &&
          r[:action] == SquiggyActivity::ADD_ASSET_TO_LIBRARY.type &&
          r[:score] == SquiggyActivity::ADD_ASSET_TO_LIBRARY.points &&
          r[:running_total] == (@initial_score + SquiggyActivity::ADD_ASSET_TO_LIBRARY.points)
      end
      expect(activity).to be_truthy
    end

    it 'can be added with title and category only' do
      @asset.title = "#{@title} 2"
      @asset.description = nil
      @asset.category = @cat_0
      @assets_list.load_page @test
      @assets_list.upload_file_asset @asset
      expect(@asset.id).not_to be_nil
    end

    it 'can be added with title only' do
      @asset.title = "#{@title} 3"
      @asset.description = nil
      @asset.category = nil
      @assets_list.upload_file_asset @asset
      expect(@asset.id).not_to be_nil
    end

    it 'can be added with title and description only' do
      @asset.title = "#{@title} 4"
      @asset.description = @desc
      @asset.category = nil
      @assets_list.upload_file_asset @asset
      expect(@asset.id).not_to be_nil
    end

    it 'require that the user enter a title' do
      @asset.title = nil
      @asset.description = nil
      @asset.category = nil
      @assets_list.click_upload_file_button
      @assets_list.enter_file_path_for_upload @asset
      @assets_list.enter_asset_metadata @asset
      expect(@assets_list.save_file_button_element.enabled?).to be false
    end

    it 'limit a title to 255 characters' do
      @asset.title = "#{'A loooooong title' * 16}?"
      @asset.description = nil
      @asset.category = nil
      @assets_list.click_cancel_file_button
      @assets_list.click_upload_file_button
      @assets_list.enter_file_path_for_upload @asset
      @assets_list.enter_asset_metadata @asset
      @assets_list.title_too_long_msg_element.when_visible 2
    end

    it 'can have only non-deleted categories' do
      @assets_list.click_cancel_file_button
      @assets_list.click_upload_file_button
      @assets_list.enter_file_path_for_upload @asset
      @assets_list.click_category_asset_select
      expect(@assets_list.menu_option_el(@cat_1.name).exists?).to be false
    end
  end
end


