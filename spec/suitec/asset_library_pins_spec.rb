require_relative '../../util/spec_helper'

describe 'Asset pinning', order: :defined do

  include Logging
  test_id = Utils.get_test_id

  user_test_data = Utils.load_test_users.select { |data| data['tests']['asset_pinning'] }
  users = user_test_data.map { |data| User.new(data) }
  user_1 = users[0]
  user_2 = users[1]
  user_3 = users[2]

  user_1_asset = Asset.new(user_1.assets.find { |a| a['type'] == 'File' })
  user_2_asset = Asset.new(user_2.assets.find { |a| a['type'] == 'File' })
  user_3_asset = Asset.new(user_3.assets.find { |a| a['type'] == 'File' })

  user_1_asset.title = "User 1 asset #{test_id}"
  user_2_asset.title = "User 2 asset #{test_id}"
  user_3_asset.title = "User 3 asset #{test_id}"

  before(:all) do
    @course = Course.new({title: "Asset Pinning #{test_id}", site_id: ENV['COURSE_ID']})

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryPage.new @driver

    # Create course site if necessary
    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, users, test_id, [SuiteCTools::ASSET_LIBRARY])
    @asset_library_url = @canvas.click_tool_link(@driver, SuiteCTools::ASSET_LIBRARY)
  end

  after(:all) { Utils.quit_browser @driver }

  context 'on list view' do

    before(:all) do
      @canvas.masquerade_as(@driver, user_1, @course)
      @asset_library.load_page(@driver, @asset_library_url)
      @asset_library.upload_file_to_library user_1_asset
    end

    it('shows a "pinned" state when a user pins an asset') { @asset_library.pin_list_view_asset user_1_asset }
    it('shows an "unpinned" state when a user unpins an asset') { @asset_library.unpin_list_view_asset user_1_asset }
  end

  context 'on detail view' do

    before(:all) do
      @canvas.masquerade_as(@driver, user_2, @course)
      @asset_library.load_page(@driver, @asset_library_url)
      @asset_library.upload_file_to_library user_2_asset
      @asset_library.load_asset_detail(@driver, @asset_library_url, user_2_asset)
    end

    it('shows a "pinned" state when a user pins an asset') { @asset_library.pin_detail_view_asset user_2_asset }
    it('shows an "unpinned" state when a user unpins an asset') { @asset_library.unpin_detail_view_asset user_2_asset }
  end

  describe 'advanced search' do

    before(:all) do
      @canvas.masquerade_as(@driver, user_3, @course)
      @asset_library.load_page(@driver, @asset_library_url)
      @asset_library.upload_file_to_library user_3_asset
    end

    context 'when a user has no pinned assets' do

      before(:all) { @asset_library.advanced_search(test_id, nil, nil, nil, 'Pinned') }

      it('shows a "No assets" message') { @asset_library.no_search_results_element.when_visible Utils.short_wait }
    end

    context 'when a user searches for the assets that it has pinned' do

      before(:all) do
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.pin_list_view_asset user_1_asset
        @asset_library.pin_list_view_asset user_2_asset
        @asset_library.pin_list_view_asset user_3_asset
        @asset_library.unpin_list_view_asset user_2_asset
        @asset_library.advanced_search(test_id, nil, nil, nil, 'Pinned')
      end

      it 'returns only the assets that the user has pinned and not unpinned' do
        @asset_library.wait_until(Utils.short_wait) { @asset_library.list_view_asset_ids == [user_3_asset.id, user_1_asset.id] }
      end
    end

    context 'when a user searches for the assets that another user has pinned' do

      before(:all) do
        @canvas.masquerade_as(@driver, user_1, @course)
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.advanced_search(test_id, nil, user_3, nil, 'Pinned')
      end

      it 'returns only the assets that the other user has pinned and not unpinned' do
        @asset_library.wait_until(Utils.short_wait) { @asset_library.list_view_asset_ids == [user_3_asset.id, user_1_asset.id] }
      end
    end

    context 'when a search result asset is unpinned' do

      before(:all) do
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.pin_list_view_asset user_2_asset
        @asset_library.advanced_search(test_id, nil, nil, nil, 'Pinned')
        @asset_library.wait_until(Utils.short_wait) { @asset_library.list_view_asset_ids == [user_2_asset.id] }
        @asset_library.unpin_list_view_asset user_2_asset
      end

      it('updates search results dynamically') { @asset_library.no_search_results_element.when_visible Utils.short_wait }
    end

    context 'when a pinned asset is deleted' do

      before(:all) do
        @asset_library.load_asset_detail(@driver, @asset_library_url, user_1_asset)
        @asset_library.delete_asset
        @canvas.masquerade_as(@driver, user_3, @course)
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.advanced_search(test_id, nil, nil, nil, 'Pinned')
      end

      it 'no longer returns the asset among the user\'s pins' do
        @asset_library.wait_until(Utils.short_wait) { @asset_library.list_view_asset_ids == [user_3_asset.id] }
      end
    end

  end
end
