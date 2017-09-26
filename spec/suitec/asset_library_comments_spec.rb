require_relative '../../util/spec_helper'

include Logging

describe 'An asset comment', order: :defined do

  test_id = Utils.get_test_id
  timeout = Utils.short_wait
  event = Event.new({csv: LRSUtils.initialize_events_csv('Comments')})

  before(:all) do
    @course = Course.new({})
    @course.site_id = ENV['COURSE_ID']

    admin = User.new({username: Utils.super_admin_username, full_name: 'Admin'})
    test_users = SuiteCUtils.load_suitec_test_data.select { |user| user['tests']['asset_library_comments'] }
    students = test_users.select { |user| user['role'] == 'Student' }
    @teacher = User.new test_users.find { |user| user['role'] == 'Teacher' }
    @asset_uploader = User.new students[0]
    @asset_admirer = User.new students[1]
    @asset = Asset.new (@asset_uploader.assets.find { |asset| asset['type'] == 'Link' })
    @asset.title = "#{@asset.title} - #{test_id}"

    @comment_1_by_uploader = Comment.new(@asset_uploader, 'Uploader makes Comment 1')
    @comment_1_reply_by_uploader = Comment.new(@asset_uploader, 'Uploader replies to own Comment 1')
    @comment_1_reply_by_viewer = Comment.new(@asset_admirer, 'Viewer replies to uploader\'s Comment 1')
    @comment_2_by_viewer = Comment.new(@asset_admirer, 'Viewer makes Comment 2')
    @comment_2_reply_by_viewer = Comment.new(@asset_admirer, 'Viewer replies to own Comment 2')
    @comment_3_by_viewer = Comment.new(@asset_admirer, 'Viewer makes Comment 3 with link to www.google.com')

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryPage.new @driver
    @engagement_index = Page::SuiteCPages::EngagementIndexPage.new @driver

    @canvas.log_in(@cal_net, (event.actor = admin).username, Utils.super_admin_password)
    @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, [@teacher, @asset_uploader, @asset_admirer],
                                       test_id, [LtiTools::ASSET_LIBRARY, LtiTools::ENGAGEMENT_INDEX])

    @asset_library_url = @canvas.click_tool_link(@driver, LtiTools::ASSET_LIBRARY, event)
    @engagement_index_url = @canvas.click_tool_link(@driver, LtiTools::ENGAGEMENT_INDEX, event)

    # Upload a new asset for the test
    @canvas.masquerade_as(@driver, (event.actor = @asset_uploader), @course)
    @asset_library.load_page(@driver, @asset_library_url, event)
    @asset_library.add_site(@asset, event)

    # Get the users' initial scores
    @canvas.masquerade_as(@driver, (event.actor = @teacher), @course)
    @engagement_index.load_scores(@driver, @engagement_index_url, event)
    @uploader_score = @engagement_index.user_score @asset_uploader
    @admirer_score = @engagement_index.user_score @asset_admirer
  end

  after(:all) { @driver.quit }

  context 'by the asset uploader' do

    it 'can be added on the detail view' do
      @canvas.masquerade_as(@driver, (event.actor = @asset_uploader), @course)
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset, event)
      @asset_library.add_comment(@asset, @comment_1_by_uploader, event)
      @asset_library.verify_comments @asset
      @asset_library.go_back_to_asset_library
      @asset_library.wait_until(timeout) { @asset_library.asset_comment_count(0) == "#{@asset.comments.length}" }
    end

    it 'can be added as a reply to an existing comment' do
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset, event)
      @asset_library.reply_to_comment(@asset, @comment_1_by_uploader, @comment_1_reply_by_uploader, event)
      @asset_library.verify_comments @asset
      @asset_library.go_back_to_asset_library
      @asset_library.wait_until(timeout) { @asset_library.asset_comment_count(0) == "#{@asset.comments.length}" }
    end

    it 'does not earn commenting points on the engagement index' do
      @canvas.masquerade_as(@driver, (event.actor = @teacher), @course)
      @engagement_index.load_scores(@driver, @engagement_index_url, event)
      @engagement_index.search_for_user(@asset_uploader)
      expect(@engagement_index.user_score @asset_uploader).to eql(@uploader_score)
    end
  end

  context 'by a user who is not the asset creator' do

    before(:all) do
      @canvas.masquerade_as(@driver, (event.actor = @asset_admirer), @course)
    end

    it 'can be added on the detail view' do
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset, event)
      @asset_library.add_comment(@asset, @comment_2_by_viewer, event)
      @asset_library.verify_comments @asset
      @asset_library.go_back_to_asset_library
      @asset_library.wait_until(timeout) { @asset_library.asset_comment_count(0) == "#{@asset.comments.length}" }
    end

    it 'can be added as a reply to the user\'s own comment' do
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset, event)
      @asset_library.reply_to_comment(@asset, @comment_2_by_viewer, @comment_2_reply_by_viewer, event)
      @asset_library.verify_comments @asset
      @asset_library.go_back_to_asset_library
      @asset_library.wait_until(timeout) { @asset_library.asset_comment_count(0) == "#{@asset.comments.length}" }
    end

    it 'can be added as a reply to another user\'s comment' do
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset, event)
      @asset_library.reply_to_comment(@asset, @comment_1_by_uploader, @comment_1_reply_by_viewer, event)
      @asset_library.verify_comments @asset
      @asset_library.go_back_to_asset_library
      @asset_library.wait_until(timeout) { @asset_library.asset_comment_count(0) == "#{@asset.comments.length}" }
    end

    it 'earns "Comment" points on the engagement index for the user adding a comment or reply' do
      @canvas.masquerade_as(@driver, (event.actor = @teacher), @course)
      @engagement_index.load_scores(@driver, @engagement_index_url, event)
      @engagement_index.search_for_user(@asset_admirer)
      expect(@engagement_index.user_score @asset_admirer).to eql((@admirer_score.to_i + (Activity::COMMENT.points * 3)).to_s)
    end

    it 'earns "Receive a Comment" points on the engagement index for the user receiving the comment or reply' do
      @engagement_index.load_scores(@driver, @engagement_index_url, event)
      expect(@engagement_index.user_score @asset_uploader).to eql((@uploader_score.to_i + (Activity::GET_COMMENT.points * 3) + Activity::GET_COMMENT_REPLY.points).to_s)
    end

    it 'shows "Comment" activity on the CSV export for the user adding the comment or reply' do
      scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url, event)
      expect(scores).to include("#{@asset_admirer.full_name}, asset_comment, #{Activity::COMMENT.points}, #{@admirer_score.to_i + Activity::COMMENT.points}")
      expect(scores).to include("#{@asset_admirer.full_name}, asset_comment, #{Activity::COMMENT.points}, #{@admirer_score.to_i + (Activity::COMMENT.points * 2)}")
      expect(scores).to include("#{@asset_admirer.full_name}, asset_comment, #{Activity::COMMENT.points}, #{@admirer_score.to_i + (Activity::COMMENT.points * 3)}")
    end

    it 'shows "Receive a Comment" activity on the CSV export for the user receiving the comment or reply' do
      scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url, event)
      expect(scores).to include("#{@asset_uploader.full_name}, get_asset_comment, #{Activity::GET_COMMENT.points}, #{@uploader_score.to_i + Activity::GET_COMMENT.points}")
      expect(scores).to include("#{@asset_uploader.full_name}, get_asset_comment, #{Activity::GET_COMMENT.points}, #{@uploader_score.to_i + (Activity::GET_COMMENT.points * 2)}")
      expect(scores).to include("#{@asset_uploader.full_name}, get_asset_comment, #{Activity::GET_COMMENT.points}, #{@uploader_score.to_i + (Activity::GET_COMMENT.points * 3)}")
      expect(scores).to include("#{@asset_uploader.full_name}, get_asset_comment_reply, #{Activity::GET_COMMENT_REPLY.points}, #{@uploader_score.to_i + (Activity::GET_COMMENT.points * 3) + Activity::GET_COMMENT_REPLY.points}")
    end
  end

  context 'by any user' do

    it 'can include a link that opens in a new browser window' do
      @canvas.masquerade_as(@driver, (event.actor = @asset_admirer), @course)
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset, event)
      @asset_library.add_comment(@asset, @comment_3_by_viewer, event)
      @asset_library.verify_comments @asset
      @asset_library.external_link_valid?(@driver, @asset_library.comment_body_link(0, 'google'), 'Google')
    end

    it 'cannot be added as a reply to a reply' do
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset, event)
      @asset_library.wait_until(timeout) { @asset_library.comment_elements.length == 6 }
      expect(@asset_library.reply_button_element(@asset.comments.index @comment_2_by_viewer).exists?).to be true
      expect(@asset_library.reply_button_element(@asset.comments.index @comment_2_reply_by_viewer).exists?).to be false
    end

    it 'can be canceled when a reply' do
      index = @asset.comments.index @comment_3_by_viewer
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset, event)
      @asset_library.click_reply_button index
      @asset_library.reply_input_element(index).when_visible timeout
      @asset_library.wait_for_update_and_click_js @asset_library.cancel_button_element(index)
      @asset_library.reply_input_element(index).when_not_visible timeout
    end
  end

  describe 'edit' do

    it 'can be done by the user who created the comment' do
      @comment_2_by_viewer.body = 'Viewer edits own Comment 2'
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset, event)
      @asset_library.edit_comment(@asset, @comment_2_by_viewer, event)
      @asset_library.verify_comments @asset
    end

    it 'cannot be done by a user who did not create the comment' do
      expect(@asset_library.edit_button_element(@asset.comments.index @comment_3_by_viewer).exists?).to be true
      expect(@asset_library.edit_button_element(@asset.comments.index @comment_2_by_viewer).exists?).to be true
      expect(@asset_library.edit_button_element(@asset.comments.index @comment_2_reply_by_viewer).exists?).to be true
      expect(@asset_library.edit_button_element(@asset.comments.index @comment_1_by_uploader).exists?).to be false
      expect(@asset_library.edit_button_element(@asset.comments.index @comment_1_reply_by_viewer).exists?).to be true
      expect(@asset_library.edit_button_element(@asset.comments.index @comment_1_reply_by_uploader).exists?).to be false
    end

    it 'can be done to any comment when the user is a teacher' do
      @canvas.masquerade_as(@driver, (event.actor = @teacher), @course)
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset, event)
      @asset.comments.each { |comment| expect(@asset_library.edit_button_element(@asset.comments.index comment).exists?).to be true }
    end

    it 'can be canceled' do
      index = @asset.comments.index @comment_2_by_viewer
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset, event)
      @asset_library.click_edit_button index
      @asset_library.edit_input_element(index).when_visible timeout
      @asset_library.wait_for_update_and_click_js @asset_library.cancel_button_element(index)
      @asset_library.edit_input_element(index).when_not_visible timeout
    end

    it 'does not alter existing engagement scores' do
      @engagement_index.load_scores(@driver, @engagement_index_url, event)
      @engagement_index.search_for_user(@asset_uploader)
      expect(@engagement_index.user_score @asset_uploader).to eql((@uploader_score.to_i + (Activity::GET_COMMENT.points * 4) + Activity::GET_COMMENT_REPLY.points).to_s)
      @engagement_index.search_for_user(@asset_admirer)
      expect(@engagement_index.user_score @asset_admirer).to eql((@admirer_score.to_i + (Activity::COMMENT.points * 4)).to_s)
    end
  end

  describe 'deletion' do

    it 'can be done by a student who created the comment' do
      @canvas.masquerade_as(@driver, (event.actor = @asset_admirer), @course)
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset, event)
      @asset_library.delete_comment(@asset, @comment_3_by_viewer, event)
      @asset_library.verify_comments @asset
    end

    it 'cannot be done by a student who did not create the comment' do
      expect(@asset_library.delete_button_element(@asset.comments.index @comment_2_by_viewer).exists?).to be false
      expect(@asset_library.delete_button_element(@asset.comments.index @comment_2_reply_by_viewer).exists?).to be true
      expect(@asset_library.delete_button_element(@asset.comments.index @comment_1_by_uploader).exists?).to be false
      expect(@asset_library.delete_button_element(@asset.comments.index @comment_1_reply_by_viewer).exists?).to be true
      expect(@asset_library.delete_button_element(@asset.comments.index @comment_1_reply_by_uploader).exists?).to be false
    end

    it 'can be done when the user is a teacher unless the comment has replies' do
      @canvas.masquerade_as(@driver, (event.actor = @teacher), @course)
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset, event)
      @asset_library.wait_until(timeout) { @asset_library.comment_elements.count == 5 }
      expect(@asset_library.delete_button_element(@asset.comments.index @comment_2_by_viewer).exists?).to be false
      expect(@asset_library.delete_button_element(@asset.comments.index @comment_2_reply_by_viewer).exists?).to be true
      expect(@asset_library.delete_button_element(@asset.comments.index @comment_1_by_uploader).exists?).to be false
      expect(@asset_library.delete_button_element(@asset.comments.index @comment_1_reply_by_viewer).exists?).to be true
      expect(@asset_library.delete_button_element(@asset.comments.index @comment_1_reply_by_uploader).exists?).to be true
    end

    it 'removes engagement index points earned for the comment' do
      @engagement_index.load_scores(@driver, @engagement_index_url, event)
      @engagement_index.search_for_user(@asset_uploader)
      expect(@engagement_index.user_score @asset_uploader).to eql((@uploader_score.to_i + (Activity::GET_COMMENT.points * 3) + Activity::GET_COMMENT_REPLY.points).to_s)
      @engagement_index.search_for_user(@asset_admirer)
      expect(@engagement_index.user_score @asset_admirer).to eql((@admirer_score.to_i + (Activity::COMMENT.points * 3)).to_s)
    end
  end
end
