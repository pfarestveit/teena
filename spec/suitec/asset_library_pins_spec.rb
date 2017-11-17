require_relative '../../util/spec_helper'

describe 'Asset pinning', order: :defined do

  include Logging
  test_id = Utils.get_test_id

  user_test_data = SuiteCUtils.load_suitec_test_data.select { |data| data['tests']['asset_library_pins'] }
  users = user_test_data.map { |data| User.new(data) }
  user_1 = users[0]
  user_2 = users[1]
  user_3 = users[2]

  user_1_asset = Asset.new(user_1.assets.find { |a| a['type'] == 'File' })
  user_2_asset = Asset.new(user_2.assets.find { |a| a['type'] == 'File' })
  user_3_asset = Asset.new(user_3.assets.find { |a| a['type'] == 'File' })

  [user_1_asset, user_2_asset, user_3_asset].each { |a| a.title = "#{a.title} #{test_id}" }

  pin = Activity::PIN_ASSET
  get_pin = Activity::GET_PIN_ASSET
  re_pin = Activity::REPIN_ASSET
  get_re_pin = Activity::GET_REPIN_ASSET

  before(:all) do
    @course = Course.new({title: "Asset Pinning #{test_id}", code: "Asset Pinning #{test_id}", site_id: ENV['COURSE_ID']})

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryPage.new @driver
    @engagement_index = Page::SuiteCPages::EngagementIndexPage.new @driver

    # Create course site if necessary
    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, users, test_id, [LtiTools::ASSET_LIBRARY, LtiTools::ENGAGEMENT_INDEX])
    @asset_library_url = @canvas.click_tool_link(@driver, LtiTools::ASSET_LIBRARY)
    @engagement_index_url = @canvas.click_tool_link(@driver, LtiTools::ENGAGEMENT_INDEX)
    @engagement_index.wait_for_new_user_sync(@driver, @engagement_index_url, @course, users)

    # Users 1 and 2 upload assets
    @canvas.masquerade_as(@driver, user_1, @course)
    @asset_library.load_page(@driver, @asset_library_url)
    @asset_library.upload_file_to_library user_1_asset

    @canvas.masquerade_as(@driver, user_2, @course)
    @asset_library.load_page(@driver, @asset_library_url)
    @asset_library.upload_file_to_library user_2_asset

    # Get the users' initial scores
    @canvas.stop_masquerading @driver
    @engagement_index.load_scores(@driver, @engagement_index_url)
    @user_1_score = @engagement_index.user_score(user_1).to_i
    @user_2_score = @engagement_index.user_score(user_2).to_i
    @user_3_score = @engagement_index.user_score(user_3).to_i
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when a user pins its own asset' do

    before(:all) do
      @canvas.masquerade_as(@driver, user_1, @course)
      @asset_library.load_page(@driver, @asset_library_url)
    end

    it('shows a "pinned" state') { @asset_library.pin_list_view_asset user_1_asset }

    context 'the Engagement Index' do

      before(:all) do
        @canvas.stop_masquerading @driver
        @engagement_index.load_scores(@driver, @engagement_index_url)
      end

      it('shows no "pin" points for the pinner') { expect(@engagement_index.user_score user_1).to eql("#{@user_1_score}") }
      it('shows no "get pin" points for the asset creator') { expect(@engagement_index.user_score user_1).to eql("#{@user_1_score}") }

      context 'activities csv' do

        before(:all) { @scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url) }

        it('adds no "pin" activity') { expect(@scores).not_to include("#{user_1.full_name}, #{pin.type}, #{pin.points}, #{@user_1_score + pin.points}") }
        it('adds no "get_pin" activity') { expect(@scores).not_to include("#{user_1.full_name}, #{get_pin.type}, #{get_pin.points}, #{@user_1_score + get_pin.points}") }
      end
    end
  end

  context 'when a user un-pins its own asset' do

    before(:all) do
      @canvas.masquerade_as(@driver, user_1, @course)
      @asset_library.load_page(@driver, @asset_library_url)
    end

    it('shows an "un-pinned" state') { @asset_library.unpin_list_view_asset user_1_asset }
  end

  context 'when a user re-pins its own asset' do

    it('shows a "pinned" state') { @asset_library.pin_list_view_asset user_1_asset }

    context 'the Engagement Index' do

      before(:all) do
        @canvas.stop_masquerading @driver
        @engagement_index.load_scores(@driver, @engagement_index_url)
      end

      it('shows no "re-pin" points for the pinner') { expect(@engagement_index.user_score user_1).to eql("#{@user_1_score}") }
      it('shows no "get re-pin" points for the asset creator') { expect(@engagement_index.user_score user_1).to eql("#{@user_1_score}") }

      context 'activities csv' do

        before(:all) { @scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url) }

        it('adds no "re-pin" activity') { expect(@scores).not_to include("#{user_1.full_name}, #{re_pin.type}, #{re_pin.points}, #{@user_1_score + re_pin.points}") }
        it('adds no "get re-pin" activity') { expect(@scores).not_to include("#{user_1.full_name}, #{get_re_pin.type}, #{get_re_pin.points}, #{@user_1_score + get_re_pin.points}") }
      end
    end
  end

  context 'when a user pins another user\'s asset' do

    before(:all) do
      @canvas.masquerade_as(@driver, user_1, @course)
      @asset_library.load_asset_detail(@driver, @asset_library_url, user_2_asset)
    end

    it('shows a "pinned" state') { @asset_library.pin_detail_view_asset user_2_asset }

    context 'the Engagement Index' do

      before(:all) do
        @canvas.stop_masquerading @driver
        @engagement_index.load_scores(@driver, @engagement_index_url)
      end

      it('shows "pin" points for the pinner') { expect(@engagement_index.user_score user_1).to eql("#{@user_1_score + pin.points}") }
      it('shows "get pin" points for the asset creator') { expect(@engagement_index.user_score user_2).to eql("#{@user_2_score + get_pin.points}") }

      context 'activities csv' do

        before(:all) { @scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url) }

        it('adds "pin" activity') { expect(@scores).to include("#{user_1.full_name}, #{pin.type}, #{pin.points}, #{@user_1_score + pin.points}") }
        it('adds "get_pin" activity') { expect(@scores).to include("#{user_2.full_name}, #{get_pin.type}, #{get_pin.points}, #{@user_2_score + get_pin.points}") }
      end
    end
  end

  context 'when a user unpins another user\'s asset' do

    before(:all) do
      @canvas.masquerade_as(@driver, user_1, @course)
      @asset_library.load_asset_detail(@driver, @asset_library_url, user_2_asset)
    end

    it('shows an "unpinned" state') { @asset_library.unpin_detail_view_asset user_2_asset }

    context 'the Engagement Index' do

      before(:all) do
        @canvas.stop_masquerading @driver
        @engagement_index.load_scores(@driver, @engagement_index_url)
      end

      it('deducts no "pin" points from the pinner') { expect(@engagement_index.user_score user_1).to eql("#{@user_1_score + pin.points}") }
      it('deducts no "get pin" points for the asset creator') { expect(@engagement_index.user_score user_2).to eql("#{@user_2_score + get_pin.points}") }

      context 'activities csv' do

        before(:all) { @scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url) }

        it('does not delete "pin" activity') { expect(@scores).to include("#{user_1.full_name}, #{pin.type}, #{pin.points}, #{@user_1_score + pin.points}") }
        it('does not delete "get pin" activity') { expect(@scores).to include("#{user_2.full_name}, #{get_pin.type}, #{get_pin.points}, #{@user_2_score + get_pin.points}") }
      end
    end
  end

  context 'when a user re-pins another user\'s asset' do

    before(:all) do
      @canvas.masquerade_as(@driver, user_1, @course)
      @asset_library.load_asset_detail(@driver, @asset_library_url, user_2_asset)
    end

    it('shows a "pinned" state') { @asset_library.pin_detail_view_asset user_2_asset }

    context 'the Engagement Index' do

      before(:all) do
        @canvas.stop_masquerading @driver
        @engagement_index.load_scores(@driver, @engagement_index_url)
      end

      it('shows "re-pin" points for the re-pinner') { expect(@engagement_index.user_score user_1).to eql("#{@user_1_score + pin.points + re_pin.points}") }
      it('shows "get re-pin" points for the asset creator') { expect(@engagement_index.user_score user_2).to eql("#{@user_2_score + get_pin.points + get_re_pin.points}") }

      context 'activities csv' do

        before(:all) { @scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url) }

        it('adds "re-pin" activity') { expect(@scores).to include("#{user_1.full_name}, #{re_pin.type}, #{re_pin.points}, #{@user_1_score + pin.points + re_pin.points}") }
        it('adds "get re-pin" activity') { expect(@scores).to include("#{user_2.full_name}, #{get_re_pin.type}, #{get_re_pin.points}, #{@user_2_score + get_pin.points + get_re_pin.points}") }
      end
    end
  end

  context 'when a user un-re-pins another user\'s asset' do

    before(:all) do
      @canvas.masquerade_as(@driver, user_1, @course)
      @asset_library.load_asset_detail(@driver, @asset_library_url, user_2_asset)
    end

    it('shows an "unpinned" state') { @asset_library.unpin_detail_view_asset user_2_asset }

    context 'the Engagement Index' do

      before(:all) do
        @canvas.stop_masquerading @driver
        @engagement_index.load_scores(@driver, @engagement_index_url)
      end

      it('deducts no "re-pin" points from the re-pinner') { expect(@engagement_index.user_score user_1).to eql("#{@user_1_score + pin.points + re_pin.points}") }
      it('deducts no "get re-pin" points from the asset creator') { expect(@engagement_index.user_score user_2).to eql("#{@user_2_score + get_pin.points + get_re_pin.points}") }

      context 'activities csv' do

        before(:all) { @scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url) }

        it('does not delete "re-pin" activity') { expect(@scores).to include("#{user_1.full_name}, #{pin.type}, #{pin.points}, #{@user_1_score + pin.points + re_pin.points}") }
        it('does not delete "get re-pin" activity') { expect(@scores).to include("#{user_2.full_name}, #{get_pin.type}, #{get_pin.points}, #{@user_2_score + get_pin.points + get_re_pin.points}") }
      end
    end
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
        # User 3 pins assets 1 and 3
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.pin_list_view_asset user_1_asset
        @asset_library.pin_list_view_asset user_3_asset
        @asset_library.advanced_search(test_id, nil, nil, nil, 'Pinned')
      end

      it 'returns only the assets that the user has pinned' do
        @asset_library.wait_until(Utils.short_wait) { @asset_library.list_view_asset_ids == [user_3_asset.id, user_1_asset.id] }
      end
    end

    context 'when a user searches for the assets that another user has pinned' do

      before(:all) do
        @canvas.masquerade_as(@driver, user_1, @course)
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.advanced_search(test_id, nil, user_3, nil, 'Pinned')
      end

      it 'returns only the assets that the other user has pinned' do
        @asset_library.wait_until(Utils.short_wait) { @asset_library.list_view_asset_ids == [user_3_asset.id, user_1_asset.id] }
      end
    end

    context 'when a search result asset is unpinned' do

      before(:all) do
        # User 1 unpins asset 1
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.advanced_search(test_id, nil, nil, nil, 'Pinned')
        @asset_library.wait_until(Utils.short_wait) { @asset_library.list_view_asset_ids == [user_1_asset.id] }
        @asset_library.unpin_list_view_asset user_1_asset
      end

      it('updates search results dynamically') { @asset_library.no_search_results_element.when_visible Utils.short_wait }
    end
  end

  context 'when an asset is deleted' do

    before(:all) do
      # User 2 pins its own asset then deletes it
      @canvas.masquerade_as(@driver, user_2, @course)
      @asset_library.load_asset_detail(@driver, @asset_library_url, user_2_asset)
      @asset_library.pin_detail_view_asset user_2_asset
      @asset_library.delete_asset user_2_asset
      @asset_library.advanced_search(test_id, nil, nil, nil, 'Pinned')
    end

    it('does not return the asset among the user\'s pins') { @asset_library.no_search_results_element.when_visible Utils.short_wait }

    context 'the Engagement Index' do

      before(:all) do
        @canvas.stop_masquerading @driver
        @engagement_index.load_scores(@driver, @engagement_index_url)
      end

      it('deducts no "pin" or "re-pin" points from the pinner') { expect(@engagement_index.user_score user_1).to eql("#{@user_1_score + pin.points + re_pin.points + get_pin.points}") }
      it('deducts no "get pin" or "get re-pin" points from the asset creator') { expect(@engagement_index.user_score user_2).to eql("#{@user_2_score + get_pin.points + get_re_pin.points}") }

      context 'activities csv' do

        before(:all) { @scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url) }

        it('does not delete "pin" activity') { expect(@scores).to include("#{user_1.full_name}, #{pin.type}, #{pin.points}, #{@user_1_score + pin.points}") }
        it('does not delete "get pin" activity') { expect(@scores).to include("#{user_2.full_name}, #{get_pin.type}, #{get_pin.points}, #{@user_2_score + get_pin.points}") }
        it('does not delete "re-pin" activity') { expect(@scores).to include("#{user_1.full_name}, #{pin.type}, #{pin.points}, #{@user_1_score + pin.points + re_pin.points}") }
        it('does not delete "get re-pin" activity') { expect(@scores).to include("#{user_2.full_name}, #{get_pin.type}, #{get_pin.points}, #{@user_2_score + get_pin.points + get_re_pin.points}") }
      end
    end
  end
end
