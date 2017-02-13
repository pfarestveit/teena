require_relative '../../util/spec_helper'

include Logging

describe 'An asset comment', order: :defined do

  test_id = Utils.get_test_id
  timeout = Utils.short_wait

  comment_1_by_uploader = 'Uploader makes Comment 1'
  comment_1_reply_by_uploader = 'Uploader replies to own Comment 1'
  comment_1_reply_by_viewer = 'Viewer replies to uploader\'s Comment 1'
  comment_2_by_viewer = 'Viewer makes Comment 2'
  comment_2_reply_by_viewer = 'Viewer replies to own Comment 2'
  comment_2_edit_by_viewer = 'Viewer edits own Comment 2'
  comment_3_by_viewer = 'Viewer makes Comment 3 with link to www.google.com'

  before(:all) do
    @course = Course.new({})
    @course.site_id = ENV['course_id']

    test_users = Utils.load_test_users.select { |user| user['tests']['assetLibraryComments'] }
    students = test_users.select { |user| user['role'] == 'Student' }
    @teacher = User.new test_users.find { |user| user['role'] == 'Teacher' }
    @asset_uploader = User.new students[0]
    @asset_admirer = User.new students[1]
    @asset = Asset.new (@asset_uploader.assets.find { |asset| asset['type'] == 'Link' })
    @asset.title = "#{@asset.title} - #{test_id}"

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryPage.new @driver
    @engagement_index = Page::SuiteCPages::EngagementIndexPage.new @driver

    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.get_suite_c_test_course(@course, [@teacher, @asset_uploader, @asset_admirer], test_id, [SuiteCTools::ASSET_LIBRARY, SuiteCTools::ENGAGEMENT_INDEX])

    @asset_library_url = @canvas.click_tool_link(@driver, SuiteCTools::ASSET_LIBRARY)
    @engagement_index_url = @canvas.click_tool_link(@driver, SuiteCTools::ENGAGEMENT_INDEX)

    # Upload a new asset for the test
    @canvas.masquerade_as(@asset_uploader, @course)
    @asset_library.load_page(@driver, @asset_library_url)
    @asset_library.add_site @asset

    # Get the users' initial scores
    @canvas.masquerade_as(@teacher, @course)
    @engagement_index.load_scores(@driver, @engagement_index_url)
    @uploader_score = @engagement_index.user_score @asset_uploader
    @admirer_score = @engagement_index.user_score @asset_admirer
  end

  after(:all) { @driver.quit }

  context 'by the asset uploader' do

    it 'can be added on the detail view' do
      @canvas.masquerade_as(@asset_uploader, @course)
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset)
      @asset_library.add_comment comment_1_by_uploader
      @asset_library.wait_until(timeout) { @asset_library.comment_elements.length == 1 }
      @asset_library.wait_until(timeout) { @asset_library.asset_detail_comment_count == '1' }
      @asset_library.wait_until(timeout) { @asset_library.commenter_name(0).include?(@asset_uploader.full_name) }
      expect(@asset_library.comment_body(0)).to eql(comment_1_by_uploader)
      @asset_library.go_back_to_asset_library
      expect(@asset_library.asset_comment_count(0)).to eql('1')
    end

    it 'can be added as a reply to an existing comment' do
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset)
      @asset_library.reply_to_comment(0, comment_1_reply_by_uploader)
      @asset_library.wait_until(timeout) { @asset_library.comment_elements.length == 2 }
      @asset_library.wait_until(timeout) { @asset_library.asset_detail_comment_count == '2' }
      expect(@asset_library.commenter_name(0)).to include(@asset_uploader.full_name)
      expect(@asset_library.comment_body(0)).to eql(comment_1_by_uploader)
      expect(@asset_library.commenter_name(1)).to include(@asset_uploader.full_name)
      expect(@asset_library.comment_body(1)).to eql(comment_1_reply_by_uploader)
      @asset_library.go_back_to_asset_library
      expect(@asset_library.asset_comment_count(0)).to eql('2')
    end

    it 'does not earn commenting points on the engagement index' do
      @canvas.masquerade_as(@teacher, @course)
      @engagement_index.load_page(@driver, @engagement_index_url)
      @engagement_index.search_for_user @asset_uploader
      expect(@engagement_index.user_score @asset_uploader).to eql(@uploader_score)
    end
  end

  context 'by a user who is not the asset creator' do

    before(:all) do
      @canvas.masquerade_as(@asset_admirer, @course)
    end

    it 'can be added on the detail view' do
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset)
      @asset_library.add_comment comment_2_by_viewer
      @asset_library.wait_until(timeout) { @asset_library.comment_elements.length == 3 }
      @asset_library.wait_until(timeout) { @asset_library.asset_detail_comment_count == '3' }
      expect(@asset_library.commenter_name(0)).to include(@asset_admirer.full_name)
      expect(@asset_library.comment_body(0)).to eql(comment_2_by_viewer)
      expect(@asset_library.commenter_name(1)).to include(@asset_uploader.full_name)
      expect(@asset_library.comment_body(1)).to eql(comment_1_by_uploader)
      expect(@asset_library.commenter_name(2)).to include(@asset_uploader.full_name)
      expect(@asset_library.comment_body(2)).to eql(comment_1_reply_by_uploader)
      @asset_library.go_back_to_asset_library
      expect(@asset_library.asset_comment_count(0)).to eql('3')
    end

    it 'can be added as a reply to the user\'s own comment' do
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset)
      @asset_library.reply_to_comment(0, comment_2_reply_by_viewer)
      @asset_library.wait_until(timeout) { @asset_library.comment_elements.length == 4 }
      @asset_library.wait_until(timeout) { @asset_library.asset_detail_comment_count == '4' }
      expect(@asset_library.commenter_name(0)).to include(@asset_admirer.full_name)
      expect(@asset_library.comment_body(0)).to eql(comment_2_by_viewer)
      expect(@asset_library.commenter_name(1)).to include(@asset_admirer.full_name)
      expect(@asset_library.comment_body(1)).to eql(comment_2_reply_by_viewer)
      expect(@asset_library.commenter_name(2)).to include(@asset_uploader.full_name)
      expect(@asset_library.comment_body(2)).to eql(comment_1_by_uploader)
      expect(@asset_library.commenter_name(3)).to include(@asset_uploader.full_name)
      expect(@asset_library.comment_body(3)).to eql(comment_1_reply_by_uploader)
      @asset_library.go_back_to_asset_library
      expect(@asset_library.asset_comment_count(0)).to eql('4')
    end

    it 'can be added as a reply to another user\'s comment' do
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset)
      @asset_library.reply_to_comment(2, comment_1_reply_by_viewer)
      @asset_library.wait_until(timeout) { @asset_library.comment_elements.length == 5 }
      @asset_library.wait_until(timeout) { @asset_library.asset_detail_comment_count == '5' }
      expect(@asset_library.commenter_name(0)).to include(@asset_admirer.full_name)
      expect(@asset_library.comment_body(0)).to eql(comment_2_by_viewer)
      expect(@asset_library.commenter_name(1)).to include(@asset_admirer.full_name)
      expect(@asset_library.comment_body(1)).to eql(comment_2_reply_by_viewer)
      expect(@asset_library.commenter_name(2)).to include(@asset_uploader.full_name)
      expect(@asset_library.comment_body(2)).to eql(comment_1_by_uploader)
      expect(@asset_library.commenter_name(3)).to include(@asset_admirer.full_name)
      expect(@asset_library.comment_body(3)).to eql(comment_1_reply_by_viewer)
      expect(@asset_library.commenter_name(4)).to include(@asset_uploader.full_name)
      expect(@asset_library.comment_body(4)).to eql(comment_1_reply_by_uploader)
      @asset_library.go_back_to_asset_library
      expect(@asset_library.asset_comment_count(0)).to eql('5')
    end

    it 'earns "Comment" points on the engagement index for the user adding a comment or reply' do
      @canvas.masquerade_as(@teacher, @course)
      @engagement_index.load_page(@driver, @engagement_index_url)
      @engagement_index.search_for_user @asset_admirer
      expect(@engagement_index.user_score @asset_admirer).to eql((@admirer_score.to_i + (Activities::COMMENT.points * 3)).to_s)
    end

    it 'earns "Receive a Comment" points on the engagement index for the user receiving the comment or reply' do
      @engagement_index.load_page(@driver, @engagement_index_url)
      @engagement_index.search_for_user @asset_uploader
      expect(@engagement_index.user_score @asset_uploader).to eql((@uploader_score.to_i + (Activities::GET_COMMENT.points * 3) + Activities::GET_COMMENT_REPLY.points).to_s)
    end

    it 'shows "Comment" activity on the CSV export for the user adding the comment or reply' do
      scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
      expect(scores).to include("#{@asset_admirer.full_name}, asset_comment, #{Activities::COMMENT.points}, #{@admirer_score.to_i + Activities::COMMENT.points}")
      expect(scores).to include("#{@asset_admirer.full_name}, asset_comment, #{Activities::COMMENT.points}, #{@admirer_score.to_i + (Activities::COMMENT.points * 2)}")
      expect(scores).to include("#{@asset_admirer.full_name}, asset_comment, #{Activities::COMMENT.points}, #{@admirer_score.to_i + (Activities::COMMENT.points * 3)}")
    end

    it 'shows "Receive a Comment" activity on the CSV export for the user receiving the comment or reply' do
      scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
      expect(scores).to include("#{@asset_uploader.full_name}, get_asset_comment, #{Activities::GET_COMMENT.points}, #{@uploader_score.to_i + Activities::GET_COMMENT.points}")
      expect(scores).to include("#{@asset_uploader.full_name}, get_asset_comment, #{Activities::GET_COMMENT.points}, #{@uploader_score.to_i + (Activities::GET_COMMENT.points * 2)}")
      expect(scores).to include("#{@asset_uploader.full_name}, get_asset_comment, #{Activities::GET_COMMENT.points}, #{@uploader_score.to_i + (Activities::GET_COMMENT.points * 3)}")
      expect(scores).to include("#{@asset_uploader.full_name}, get_asset_comment_reply, #{Activities::GET_COMMENT_REPLY.points}, #{@uploader_score.to_i + (Activities::GET_COMMENT.points * 3) + Activities::GET_COMMENT_REPLY.points}")
    end
  end

  context 'by any user' do

    it 'can include a link that opens in a new browser window' do
      @canvas.masquerade_as(@asset_admirer, @course)
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset)
      @asset_library.add_comment comment_3_by_viewer
      @asset_library.wait_until(timeout) { @asset_library.comment_elements.count == 6 }
      @asset_library.external_link_valid?(@driver, @asset_library.comment_body_link(0, 'google'), 'Google')
    end

    it 'cannot be added as a reply to a reply' do
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset)
      @asset_library.wait_until(timeout) { @asset_library.comment_elements.length == 6 }
      expect(@asset_library.reply_button_element(1).exists?).to be true
      expect(@asset_library.reply_button_element(2).exists?).to be false
    end

    it 'can be canceled when a reply' do
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset)
      @asset_library.click_reply_button 0
      @asset_library.reply_input_element(0).when_visible timeout
      @asset_library.cancel_button_element(0).click
      @asset_library.reply_input_element(0).when_not_visible timeout
    end
  end

  describe 'edit' do

    it 'can be done by the user who created the comment' do
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset)
      @asset_library.edit_comment(1, comment_2_edit_by_viewer)
      @asset_library.wait_until(timeout) { @asset_library.comment_body(1) == comment_2_edit_by_viewer }
      expect(@asset_library.asset_detail_comment_count).to eql('6')
      expect(@asset_library.comment_body(0)).to eql(comment_3_by_viewer)
      expect(@asset_library.comment_body(2)).to eql(comment_2_reply_by_viewer)
      expect(@asset_library.comment_body(3)).to eql(comment_1_by_uploader)
      expect(@asset_library.comment_body(4)).to eql(comment_1_reply_by_viewer)
      expect(@asset_library.comment_body(5)).to eql(comment_1_reply_by_uploader)
    end

    it 'cannot be done by a user who did not create the comment' do
      expect(@asset_library.edit_button_element(0).exists?).to be true
      expect(@asset_library.edit_button_element(1).exists?).to be true
      expect(@asset_library.edit_button_element(2).exists?).to be true
      expect(@asset_library.edit_button_element(3).exists?).to be false
      expect(@asset_library.edit_button_element(4).exists?).to be true
      expect(@asset_library.edit_button_element(5).exists?).to be false
    end

    it 'can be done to any comment when the user is a teacher' do
      @canvas.masquerade_as(@teacher, @course)
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset)
      expect(@asset_library.edit_button_element(0).exists?).to be true
      expect(@asset_library.edit_button_element(1).exists?).to be true
      expect(@asset_library.edit_button_element(2).exists?).to be true
      expect(@asset_library.edit_button_element(3).exists?).to be true
      expect(@asset_library.edit_button_element(4).exists?).to be true
      expect(@asset_library.edit_button_element(5).exists?).to be true
    end

    it 'can be canceled' do
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset)
      @asset_library.click_edit_button 1
      @asset_library.edit_input_element(1).when_visible timeout
      @asset_library.cancel_button_element(1).click
      @asset_library.edit_input_element(1).when_not_visible timeout
    end

    it 'does not alter existing engagement scores' do
      @engagement_index.load_page(@driver, @engagement_index_url)
      @engagement_index.search_for_user @asset_uploader
      expect(@engagement_index.user_score @asset_uploader).to eql((@uploader_score.to_i + (Activities::GET_COMMENT.points * 4) + Activities::GET_COMMENT_REPLY.points).to_s)
      @engagement_index.search_for_user @asset_admirer
      expect(@engagement_index.user_score @asset_admirer).to eql((@admirer_score.to_i + (Activities::COMMENT.points * 4)).to_s)
    end
  end

  describe 'deletion' do

    it 'can be done by a student who created the comment' do
      @canvas.masquerade_as(@asset_admirer, @course)
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset)
      @asset_library.delete_comment 0
      @asset_library.wait_until(timeout) { @asset_library.comment_elements.count == 5 }
      @asset_library.wait_until(timeout) { @asset_library.asset_detail_comment_count == '5' }
      expect(@asset_library.comment_body(0)).to eql(comment_2_edit_by_viewer)
      expect(@asset_library.comment_body(1)).to eql(comment_2_reply_by_viewer)
      expect(@asset_library.comment_body(2)).to eql(comment_1_by_uploader)
      expect(@asset_library.comment_body(3)).to eql(comment_1_reply_by_viewer)
      expect(@asset_library.comment_body(4)).to eql(comment_1_reply_by_uploader)
    end

    it 'cannot be done by a student who did not create the comment' do
      expect(@asset_library.delete_button_element(0).exists?).to be false
      expect(@asset_library.delete_button_element(1).exists?).to be true
      expect(@asset_library.delete_button_element(2).exists?).to be false
      expect(@asset_library.delete_button_element(3).exists?).to be true
      expect(@asset_library.delete_button_element(4).exists?).to be false
    end

    it 'can be done when the user is a teacher unless the comment has replies' do
      @canvas.masquerade_as(@teacher, @course)
      @asset_library.load_asset_detail(@driver, @asset_library_url, @asset)
      @asset_library.wait_until(timeout) { @asset_library.comment_elements.count == 5 }
      expect(@asset_library.delete_button_element(0).exists?).to be false
      expect(@asset_library.delete_button_element(1).exists?).to be true
      expect(@asset_library.delete_button_element(2).exists?).to be false
      expect(@asset_library.delete_button_element(3).exists?).to be true
      expect(@asset_library.delete_button_element(4).exists?).to be true
    end

    it 'removes engagement index points earned for the comment' do
      @engagement_index.load_page(@driver, @engagement_index_url)
      @engagement_index.search_for_user @asset_uploader
      expect(@engagement_index.user_score @asset_uploader).to eql((@uploader_score.to_i + (Activities::GET_COMMENT.points * 3) + Activities::GET_COMMENT_REPLY.points).to_s)
      @engagement_index.search_for_user @asset_admirer
      expect(@engagement_index.user_score @asset_admirer).to eql((@admirer_score.to_i + (Activities::COMMENT.points * 3)).to_s)
    end
  end
end
