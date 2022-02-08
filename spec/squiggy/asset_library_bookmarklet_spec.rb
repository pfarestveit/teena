require_relative '../../util/spec_helper'

describe 'The Asset Library bookmarklet' do

  include Logging

  before(:all) do
    @test = SquiggyTestConfig.new 'bizmarklet'
    @test.course.site_id = ENV['COURSE_ID']
    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @assets_list = SquiggyAssetLibraryListViewPage.new @driver
    @asset_detail = SquiggyAssetLibraryDetailPage.new @driver
    @manage_assets = SquiggyAssetLibraryManageAssetsPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver

    @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course @test

    @teacher = @test.teachers.first
    @student = @test.students[0]
    @cat_0 = SquiggyCategory.new "Category 1 #{@test.id}"

    @canvas.masquerade_as(@teacher, @test.course)
    @assets_list.load_page @test
    @assets_list.click_manage_assets_link
    @manage_assets.create_new_category @cat_0

    @canvas.masquerade_as(@student, @test.course)
    @assets_list.load_page @test
    @bizmarklet = @assets_list.get_bizmarklet
    @canvas.stop_masquerading
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when adding a page' do

    before(:all) do
      @link_asset = SquiggyAsset.new title: "Biz Markie #{@test.id}",
                                     category: @cat_0,
                                     description: "#{'A loooooong description ' * 16}",
                                     url: 'https://en.wikipedia.org/wiki/Biz_Markie'
      @assets_list.navigate_to @link_asset.url
      @original_window = @assets_list.launch_bizmarklet @bizmarklet
      @assets_list.click_bizmarklet_next_button
    end

    it 'defaults the asset title to the page title' do
      @assets_list.title_input_element.when_present 2
      expect(@assets_list.title_input_element.value).to eql('Biz Markie - Wikipedia')
    end

    it 'requires a title' do
      @assets_list.enter_squiggy_text(@assets_list.title_input_element, '')
      expect(@assets_list.bizmarklet_save_button_element.disabled_attribute).to eql('true')
    end

    it 'allows a title up to 255 characters' do
      @assets_list.enter_squiggy_text(@assets_list.title_input_element, "#{'A loooooong title' * 16}?")
      expect(@assets_list.title_input_element.value).to eql("#{'A loooooong title' * 16}?"[0..254])
    end

    it 'does not require a category or a description' do
      expect(@assets_list.bizmarklet_save_button_element.disabled_attribute).to be_nil
    end

    it 'allows a user to cancel the asset' do
      @assets_list.cancel_bizmarklet @original_window
    end

    it 'allows a user to add the asset' do
      @original_window = @assets_list.launch_bizmarklet @bizmarklet
      @assets_list.click_bizmarklet_next_button
      @assets_list.enter_asset_metadata @link_asset
      @assets_list.save_bizmarklet_assets
      @assets_list.close_bookmarklet @original_window
      @assets_list.load_page @test
      @assets_list.get_asset_id @link_asset
    end
  end

  context 'when adding page images' do

    before(:all) do
      @assets = [
        (SquiggyAsset.new title: "They #{@test.id}",
                          description: 'Can you feel it, nothing can save ya For this is the season of catching the vapors'),
        (SquiggyAsset.new title: "Caught #{@test.id}",
                          category: @cat_0),
        (SquiggyAsset.new title: "The Vapors #{@test.id}")
      ]
      @assets_list.navigate_to 'https://www.google.com/search?q=biz+markie&tbm=isch'
      @original_window = @assets_list.launch_bizmarklet @bizmarklet
    end

    it 'allows a user to cancel image assets' do
      @assets_list.click_bizmarklet_add_items
      @assets_list.cancel_bizmarklet @original_window
    end

    it 'allows a user to add image assets' do
      @original_window = @assets_list.launch_bizmarklet @bizmarklet
      @assets_list.click_bizmarklet_add_items
      @assets_list.click_bizmarklet_next_button
      @assets_list.select_bizmarklet_items @assets
      @assets_list.click_bizmarklet_next_button
      @assets_list.enter_bizmarklet_items_metadata @assets
      @assets_list.save_bizmarklet_assets
      @assets_list.close_bookmarklet @original_window
      @assets_list.load_page @test
      @assets.each { |a| @assets_list.get_asset_id a }
    end
  end

  context 'when no eligible images are present on a page' do

    before(:all) do
      @assets_list.navigate_to 'https://www.google.com'
      @original_window = @assets_list.launch_bizmarklet @bizmarklet
    end

    it 'breaks the sad news to the user' do
      @assets_list.no_eligible_images_msg_element.when_visible Utils.short_wait
    end
  end

  context 'when a user is no longer part of the course' do

    before(:all) do
      @canvas.remove_users_from_course(@test.course, [@student])
      @engagement_index.wait_until(Utils.medium_wait) do
        sleep 10
        @engagement_index.load_scores @test
        !@engagement_index.visible_names.include? @student.full_name
      end
    end

    it 'no longer allows the user to add assets' do
      @assets_list.navigate_to 'https://www.berkeley.edu/'
      @original_window = @assets_list.launch_bizmarklet @bizmarklet
      # TODO expect error msg
    end
  end
end
