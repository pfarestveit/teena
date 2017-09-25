require_relative '../../util/spec_helper'

include Logging

describe 'Asset', order: :defined do

  test_id = Utils.get_test_id
  test_users = SuiteCUtils.load_suitec_test_data.select { |user| user['tests']['asset_library_likes'] }
  event = Event.new({csv: LRSUtils.initialize_events_csv('Likes')})

  before(:all) do
    @course = Course.new({})
    @course.site_id = ENV['COURSE_ID']

    admin = User.new({username: Utils.ets_qa_username, full_name: 'Admin'})
    @asset_uploader = User.new test_users[0]
    @asset_admirer = User.new test_users[1]
    @asset = Asset.new (@asset_uploader.assets.find { |asset| asset['type'] == 'Link' })
    @asset.title = "#{@asset.title} - #{test_id}"

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryPage.new @driver
    @engagement_index = Page::SuiteCPages::EngagementIndexPage.new @driver

    @canvas.log_in(@cal_net, (event.actor = admin).username, Utils.ets_qa_password)
    @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, [@asset_uploader, @asset_admirer],
                                       test_id, [SuiteCTools::ASSET_LIBRARY, SuiteCTools::ENGAGEMENT_INDEX])

    @asset_library_url = @canvas.click_tool_link(@driver, SuiteCTools::ASSET_LIBRARY, event)
    @engagement_index_url = @canvas.click_tool_link(@driver, SuiteCTools::ENGAGEMENT_INDEX, event)

    # Upload a new asset for the test
    @canvas.log_out(@driver, @cal_net)
    @canvas.log_in(@cal_net, (event.actor = @asset_uploader).username, Utils.test_user_password)
    @canvas.load_course_site(@driver, @course)
    @asset_library.load_page(@driver, @asset_library_url, event)
    @asset_library.add_site(@asset, event)

    # Get the users' initial scores
    @engagement_index.load_scores(@driver, @engagement_index_url, event)
    @uploader_score = @engagement_index.user_score @asset_uploader
    @admirer_score = @engagement_index.user_score @asset_admirer
  end

  after(:all) { @driver.quit }

  describe 'likes' do

    context 'when the user is the asset creator' do

      it 'cannot be added on the list view' do
        @asset_library.load_page(@driver, @asset_library_url, event)
        @asset_library.advanced_search(@asset.title, nil, @asset_uploader, @asset.type, nil, event)
        expect(@asset_library.enabled_like_buttons.any?).to be false
      end

      it 'cannot be added on the detail view' do
        @asset_library.click_asset_link_by_id @asset
        @asset_library.wait_for_asset_detail(@asset, event)
        expect(@asset_library.enabled_like_buttons.any?).to be false
      end

    end

    context 'when the user is not the asset creator' do

      before(:all) do
        @canvas.log_out(@driver, @cal_net)
        @canvas.log_in(@cal_net, (event.actor = @asset_admirer).username, Utils.test_user_password)
        @canvas.load_course_site(@driver, @course)
        @asset_library.load_list_view_asset(@driver, @asset_library_url, @asset, event)
      end

      it 'cannot be added on the list view' do
        @asset_library.advanced_search(@asset.title, nil, @asset_uploader, @asset.type, nil, event)
        expect(@asset_library.enabled_like_buttons.any?).to be false
      end

    end

    context 'when added on the detail view' do

      before(:all) do
        @asset_library.load_list_view_asset(@driver, @asset_library_url, @asset, event)
        @asset_library.click_asset_link_by_id @asset
        @asset_library.wait_for_asset_detail(@asset, event)
      end

      it 'increase the asset\'s total likes' do
        @asset_library.wait_until { @asset_library.detail_view_asset_likes_count == '0' }
        @asset_library.toggle_detail_view_item_like(@asset, event)
        @asset_library.wait_until { @asset_library.detail_view_asset_likes_count == '1' }
      end

      it 'earn Engagement Index "like" points for the liker' do
        @engagement_index.load_scores(@driver, @engagement_index_url, event)
        @engagement_index.search_for_user @asset_admirer
        expect(@engagement_index.user_score @asset_admirer).to eql((@admirer_score.to_i + Activity::LIKE.points).to_s)
      end

      it 'earn Engagement Index "get_like" points for the asset creator' do
        @engagement_index.search_for_user @asset_uploader
        expect(@engagement_index.user_score @asset_uploader).to eql((@uploader_score.to_i + Activity::GET_LIKE.points).to_s)
      end

      it 'add the liker\'s "like" activity to the activities csv' do
        scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url, event)
        expect(scores).to include("#{@asset_admirer.full_name}, like, #{Activity::LIKE.points}, #{@admirer_score.to_i + Activity::LIKE.points}")
      end

      it 'add the asset creator\'s "get_like" activity to the activities csv' do
        scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url, event)
        expect(scores).to include("#{@asset_uploader.full_name}, get_like, #{Activity::GET_LIKE.points}, #{@uploader_score.to_i + Activity::GET_LIKE.points}")
      end

    end

    context 'when removed on the detail view' do

      before(:all) do
        @asset_library.load_list_view_asset(@driver, @asset_library_url, @asset, event)
        @asset_library.click_asset_link_by_id @asset
        @asset_library.wait_for_asset_detail(@asset, event)
      end

      it 'decrease the asset\'s total likes' do
        @asset_library.toggle_detail_view_item_like(@asset, event)
        @asset_library.wait_until { @asset_library.detail_view_asset_likes_count == '0' }
      end

      it 'remove Engagement Index "like" points from the un-liker' do
        @engagement_index.load_scores(@driver, @engagement_index_url, event)
        @engagement_index.search_for_user @asset_admirer
        expect(@engagement_index.user_score @asset_admirer).to eql("#{@admirer_score}")
      end

      it 'remove Engagement Index "get_like" points from the asset creator' do
        @engagement_index.search_for_user @asset_uploader
        expect(@engagement_index.user_score @asset_uploader).to eql("#{@uploader_score}")
      end

      it 'remove the un-liker\'s "like" activity from the activities csv' do
        scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url, event)
        expect(scores).not_to include("#{@asset_admirer.full_name}, like, #{Activity::LIKE.points}, #{@admirer_score.to_i + Activity::LIKE.points}")
      end

      it 'remove the asset creator\'s "get_like" activity from the activities csv' do
        scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url, event)
        expect(scores).not_to include("#{@asset_uploader.full_name}, get_like, #{Activity::GET_LIKE.points}, #{@uploader_score.to_i + Activity::GET_LIKE.points}")
      end

    end
  end

  describe 'views' do

    # View count update can be slow to happen
    before { sleep Utils.short_wait }

    it 'are only incremented when viewed by users other than the asset creator' do
      @asset_library.load_list_view_asset(@driver, @asset_library_url, @asset, event)
      @asset_library.wait_until(Utils.short_wait) { @asset_library.list_view_asset_view_count(0) == '2' }
    end
  end
end
