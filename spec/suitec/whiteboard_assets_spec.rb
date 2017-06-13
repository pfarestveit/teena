require_relative '../../util/spec_helper'

describe 'Whiteboard Add Asset', order: :defined do

  test_id = Utils.get_test_id
  timeout = Utils.short_wait

  before(:all) do
    @course = Course.new({})
    @course.site_id = ENV['COURSE_ID']

    # Load test data
    test_user_data = Utils.load_test_users.select { |user| user['tests']['whiteboardAssets'] }
    @student_1 = User.new test_user_data[0]
    @student_2 = User.new test_user_data[1]
    @student_3 = User.new test_user_data[2]

    @student_1_asset_file = Asset.new(@student_1.assets.find { |asset| asset['type'] == 'File' })
    @student_1_asset_file.title = "#{@student_1.full_name} file #{test_id}"
    @student_1_asset_file.category = @category

    @student_2_asset_url = Asset.new(@student_2.assets.find { |asset| asset['type'] == 'Link' })
    @student_2_asset_url.title = "#{@student_2.full_name} link #{test_id}"
    @student_2_asset_url.category = @category

    @student_3_asset_file = Asset.new(@student_3.assets.find { |asset| asset['type'] == 'File' })
    @student_3_asset_file.title = "#{@student_3.full_name} file #{test_id}"
    @student_3_asset_file.category = @category

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryPage.new @driver
    @engagement_index = Page::SuiteCPages::EngagementIndexPage.new @driver
    @whiteboards = Page::SuiteCPages::WhiteboardsPage.new @driver

    # Create test course
    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, [@student_1, @student_2, @student_3], test_id, [SuiteCTools::ASSET_LIBRARY, SuiteCTools::ENGAGEMENT_INDEX, SuiteCTools::WHITEBOARDS])
    @canvas.load_course_site(@driver, @course)
    @asset_library_url = @canvas.click_tool_link(@driver, SuiteCTools::ASSET_LIBRARY)
    @engagement_index_url = @canvas.click_tool_link(@driver, SuiteCTools::ENGAGEMENT_INDEX)
    @whiteboards_url = @canvas.click_tool_link(@driver, SuiteCTools::WHITEBOARDS)
    @asset_library.add_custom_categories(@driver, @asset_library_url, [(@category = "#{test_id}")])

    # Set "whiteboard add asset" points to non-zero value
    @engagement_index.load_page(@driver, @engagement_index_url)
    @engagement_index.click_points_config
    @engagement_index.change_activity_points(Activity::ADD_ASSET_TO_WHITEBOARD, '1')

    # Student 1 add file to asset library
    @canvas.masquerade_as(@driver, @student_1, @course)
    @asset_library.load_page(@driver, @asset_library_url)
    @asset_library.upload_file_to_library @student_1_asset_file

    # Student 2 add URL to asset library
    @canvas.masquerade_as(@driver, @student_2, @course)
    @asset_library.load_page(@driver, @asset_library_url)
    @asset_library.add_site @student_2_asset_url

    # Student 3 add file to asset library
    @canvas.masquerade_as(@driver, @student_3, @course)
    @asset_library.load_page(@driver, @asset_library_url)
    @asset_library.upload_file_to_library @student_3_asset_file

    # Student 1 create whiteboard, invite Student 2
    @whiteboard = Whiteboard.new({ owner: @student_1, title: "Whiteboard #{test_id}", collaborators: [@student_2] })
    @canvas.masquerade_as(@driver, @student_1, @course)
    @whiteboards.load_page(@driver, @whiteboards_url)
    @whiteboards.create_whiteboard @whiteboard
    @canvas.stop_masquerading @driver
  end

  after(:all) { @driver.quit }

  context 'when using existing assets' do

    before(:all) do
      @engagement_index.load_scores(@driver, @engagement_index_url)
      @initial_score_stu_1 = @engagement_index.user_score @student_1
      @initial_score_stu_2 = @engagement_index.user_score @student_2
      @initial_score_stu_3 = @engagement_index.user_score @student_3

      @canvas.masquerade_as(@driver, @student_1, @course)
      @whiteboards.load_page(@driver, @whiteboards_url)
      @whiteboards.open_whiteboard(@driver, @whiteboard)
    end

    before(:each) { @whiteboards.click_cancel_button if @whiteboards.cancel_asset_button? }

    it 'allows the user to cancel adding assets' do
      @whiteboards.click_add_existing_asset
      @whiteboards.wait_until(timeout) { @whiteboards.list_view_asset_elements.any? }
      expect(@whiteboards.add_selected_button_element.attribute 'disabled').to eql('true')
      @whiteboards.click_cancel_button
      @whiteboards.wait_until(timeout) { @whiteboards.list_view_asset_elements.empty? }
    end

    it 'allows the user to add the user\'s own assets' do
      @whiteboards.add_existing_assets [@student_1_asset_file]
      @whiteboards.wait_until(timeout) { @whiteboards.open_original_asset_link_element.attribute('href').include? @student_1_asset_file.id }
    end

    it 'allows the user to add a collaborator\'s assets' do
      @whiteboards.add_existing_assets [@student_2_asset_url]
      @whiteboards.wait_until(timeout) { @whiteboards.open_original_asset_link_element.attribute('href').include? @student_2_asset_url.id }
    end

    it 'allows the user to add a non-collaborator\'s assets' do
      @whiteboards.add_existing_assets [@student_3_asset_file]
      @whiteboards.wait_until(timeout) { @whiteboards.open_original_asset_link_element.attribute('href').include? @student_3_asset_file.id }
    end

    it 'allows the user to add multiple assets at once' do
      @whiteboards.add_existing_assets [@student_1_asset_file, @student_2_asset_url, @student_3_asset_file]
      @whiteboards.wait_until(timeout) { @whiteboards.open_original_asset_link_element.attribute('href').include? (@student_1_asset_file.id || @student_2_asset_url.id || @student_3_asset_file.id) }
    end

    it 'earns "Add an asset to a whiteboard" but not "Add a new asset to the Asset Library" points on the Engagement Index for each asset used' do
      @whiteboards.close_whiteboard @driver
      @canvas.stop_masquerading @driver
      @engagement_index.load_scores(@driver, @engagement_index_url)
      expect(@engagement_index.user_score @student_1).to eql("#{@initial_score_stu_1.to_i + 4}")
    end

    it 'shows "add_asset_to_whiteboard" but not "add_asset" activity on the CSV export for each asset belonging to another user' do
      scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
      expect(scores).to include("#{@student_1.full_name}, #{Activity::ADD_ASSET_TO_WHITEBOARD.type}, 1, #{@initial_score_stu_1.to_i + 1}")
      expect(scores).to include("#{@student_2.full_name}, #{Activity::GET_ADD_ASSET_TO_WHITEBOARD.type}, 0, #{@initial_score_stu_2}")

      expect(scores).to include("#{@student_1.full_name}, #{Activity::ADD_ASSET_TO_WHITEBOARD.type}, 1, #{@initial_score_stu_1.to_i + 2}")
      expect(scores).to include("#{@student_3.full_name}, #{Activity::GET_ADD_ASSET_TO_WHITEBOARD.type}, 0, #{@initial_score_stu_3}")

      expect(scores).to include("#{@student_1.full_name}, #{Activity::ADD_ASSET_TO_WHITEBOARD.type}, 1, #{@initial_score_stu_1.to_i + 3}")
      expect(scores).to include("#{@student_2.full_name}, #{Activity::GET_ADD_ASSET_TO_WHITEBOARD.type}, 0, #{@initial_score_stu_2}")

      expect(scores).to include("#{@student_1.full_name}, #{Activity::ADD_ASSET_TO_WHITEBOARD.type}, 1, #{@initial_score_stu_1.to_i + 4}")
      expect(scores).to include("#{@student_3.full_name}, #{Activity::GET_ADD_ASSET_TO_WHITEBOARD.type}, 0, #{@initial_score_stu_3}")
    end
  end

  context 'when uploading new assets' do

    before(:all) do
      @engagement_index.load_scores(@driver, @engagement_index_url)
      @initial_score = @engagement_index.user_score @student_1
      @canvas.masquerade_as(@driver, @student_1, @course)
      @whiteboards.load_page(@driver, @whiteboards_url)
      @whiteboards.open_whiteboard(@driver, @whiteboard)
    end

    before(:each) { @whiteboards.close_whiteboard @driver }

    it 'requires an asset title' do
      @whiteboards.load_page(@driver, @whiteboards_url)
      @whiteboards.open_whiteboard(@driver, @whiteboard)
      @student_1_asset_file.title = nil
      @whiteboards.add_asset_exclude_from_library @student_1_asset_file
      @whiteboards.wait_until(timeout) { @whiteboards.missing_title_error_elements.any? }
    end

    it 'requires an asset title of 255 characters maximum' do
      @whiteboards.load_page(@driver, @whiteboards_url)
      @whiteboards.open_whiteboard(@driver, @whiteboard)

      @student_1_asset_file.title = "#{'A loooooong title' * 15}?"
      @whiteboards.add_asset_include_in_library @student_1_asset_file
      @whiteboards.wait_until(timeout) { @whiteboards.long_title_error_elements.any? }

      @student_1_asset_file.title = @student_1_asset_file.title[0, 255]
      @whiteboards.enter_file_metadata @student_1_asset_file
      @whiteboards.click_add_files_button
      @whiteboards.open_original_asset_link_element.when_present Utils.long_wait
    end

    it 'allows the user to add the upload to the asset library' do
      @whiteboards.load_page(@driver, @whiteboards_url)
      @whiteboards.open_whiteboard(@driver, @whiteboard)
      @student_1_asset_file.title = 'Student 1 file added to library'
      @whiteboards.add_asset_include_in_library @student_1_asset_file
      @whiteboards.open_original_asset_link_element.when_visible Utils.long_wait
      @whiteboards.close_whiteboard @driver
      @asset_library.load_page(@driver, @asset_library_url)
      @asset_library.verify_first_asset(@student_1, @student_1_asset_file)
    end

    it 'allows the user to exclude the upload from the asset library' do
      @whiteboards.load_page(@driver, @whiteboards_url)
      @whiteboards.open_whiteboard(@driver, @whiteboard)
      @student_1_asset_file.title = 'Student 1 file not added to library'
      @whiteboards.add_asset_exclude_from_library @student_1_asset_file
      @whiteboards.open_original_asset_link_element.when_present Utils.long_wait
      @whiteboards.close_whiteboard @driver
      @asset_library.load_page(@driver, @asset_library_url)
      @asset_library.advanced_search(@student_1_asset_file.title, @student_1_asset_file.category, @student_1, 'File')
      @asset_library.no_search_results_element.when_visible
    end

    it 'earns "Add a new asset to the Asset Library" points on the Engagement Index' do
      @canvas.stop_masquerading @driver
      @engagement_index.load_scores(@driver, @engagement_index_url)
      expect(@engagement_index.user_score @student_1).to eql("#{@initial_score.to_i + (Activity::ADD_ASSET_TO_LIBRARY.points * 2)}")
    end

    it 'shows "add_asset" activity on the CSV export' do
      scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
      expect(scores).to include("#{@student_1.full_name}, #{Activity::ADD_ASSET_TO_LIBRARY.type}, #{Activity::ADD_ASSET_TO_LIBRARY.points}, #{@initial_score.to_i + Activity::ADD_ASSET_TO_LIBRARY.points}")
      expect(scores).to include("#{@student_1.full_name}, #{Activity::ADD_ASSET_TO_LIBRARY.type}, #{Activity::ADD_ASSET_TO_LIBRARY.points}, #{@initial_score.to_i + (Activity::ADD_ASSET_TO_LIBRARY.points * 2)}")
      expect(scores).to_not include("#{@student_1.full_name}, #{Activity::ADD_ASSET_TO_LIBRARY.type}, #{Activity::ADD_ASSET_TO_LIBRARY.points}, #{@initial_score.to_i + (Activity::ADD_ASSET_TO_LIBRARY.points * 3)}")
    end
  end

  context 'when adding new URL assets' do

    before(:all) do
      @engagement_index.load_scores(@driver, @engagement_index_url)
      @initial_score = @engagement_index.user_score @student_2
      @canvas.masquerade_as(@driver, @student_2, @course)
      @whiteboards.load_page(@driver, @whiteboards_url)
      @whiteboards.open_whiteboard(@driver, @whiteboard)
    end

    before(:each) { @whiteboards.click_cancel_button if @whiteboards.cancel_asset_button? }

    it 'requires an asset title' do
      @student_2_asset_url.title = nil
      @whiteboards.add_asset_exclude_from_library @student_2_asset_url
      @whiteboards.wait_until(timeout) { @whiteboards.missing_title_error_elements.any? }
    end

    it 'requires an asset title of 255 characters maximum' do
      @student_2_asset_url.title = "#{'A loooooong title' * 15}?"
      @whiteboards.add_asset_include_in_library @student_2_asset_url
      @whiteboards.wait_until(timeout) { @whiteboards.long_title_error_elements.any? }

      @student_2_asset_url.title = @student_2_asset_url.title[0, 255]
      @whiteboards.enter_url_metadata @student_2_asset_url
      @whiteboards.click_add_url_button
      @whiteboards.open_original_asset_link_element.when_present
    end

    it 'allows the user to add the upload to the asset library' do
      @student_2_asset_url.title = 'Student 2 link added to library'
      @whiteboards.add_asset_include_in_library @student_2_asset_url
      @whiteboards.open_original_asset_link_element.when_present
      @whiteboards.close_whiteboard @driver
      @asset_library.load_page(@driver, @asset_library_url)
      @asset_library.verify_first_asset(@student_2, @student_2_asset_url)
    end

    it 'allows the user to exclude the upload from the asset library' do
      @student_2_asset_url.title = 'Student 2 link not added to library'
      @whiteboards.load_page(@driver, @whiteboards_url)
      @whiteboards.open_whiteboard(@driver, @whiteboard)
      @whiteboards.add_asset_exclude_from_library @student_2_asset_url
      @whiteboards.open_original_asset_link_element.when_present
      @whiteboards.close_whiteboard @driver
      @asset_library.load_page(@driver, @asset_library_url)
      @asset_library.advanced_search(@student_2_asset_url.title, nil, @student_2, 'Link')
      @asset_library.no_search_results_element.when_visible
    end

    it 'earns "Add a new asset to the Asset Library" points on the Engagement Index' do
      @canvas.stop_masquerading @driver
      @engagement_index.load_scores(@driver, @engagement_index_url)
      expect(@engagement_index.user_score @student_2).to eql("#{@initial_score.to_i + (Activity::ADD_ASSET_TO_LIBRARY.points * 2)}")
    end

    it 'shows "add_asset" activity on the CSV export' do
      scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
      expect(scores).to include("#{@student_2.full_name}, #{Activity::ADD_ASSET_TO_LIBRARY.type}, #{Activity::ADD_ASSET_TO_LIBRARY.points}, #{@initial_score.to_i + Activity::ADD_ASSET_TO_LIBRARY.points}")
      expect(scores).to include("#{@student_2.full_name}, #{Activity::ADD_ASSET_TO_LIBRARY.type}, #{Activity::ADD_ASSET_TO_LIBRARY.points}, #{@initial_score.to_i + (Activity::ADD_ASSET_TO_LIBRARY.points * 2)}")
      expect(scores).to_not include("#{@student_2.full_name}, #{Activity::ADD_ASSET_TO_LIBRARY.type}, #{Activity::ADD_ASSET_TO_LIBRARY.points}, #{@initial_score.to_i + (Activity::ADD_ASSET_TO_LIBRARY.points * 3)}")
    end
  end

  context 'when the asset is hidden from the asset library' do

    before(:all) do
      @canvas.masquerade_as(@driver, @student_2, @course)
      @whiteboards.load_page(@driver, @whiteboards_url)
      @whiteboards.open_whiteboard(@driver, @whiteboard)
      @whiteboards.add_asset_exclude_from_library @student_2_asset_url
      @whiteboards.open_original_asset(@driver, @asset_library, @student_2_asset_url)
    end

    it 'allows the user to comment on it via the whiteboard' do
      @asset_library.add_comment 'Comment on a hidden asset'
      @asset_library.wait_until(timeout) { @asset_library.comment_elements.length == 1 }
      @asset_library.wait_until(timeout) { @asset_library.asset_detail_comment_count == '1' }
      @asset_library.wait_until(timeout) { @asset_library.commenter_name(0).include?(@student_2.full_name) }
      expect(@asset_library.comment_body(0)).to eql('Comment on a hidden asset')
    end

    it 'allows the user to edit its metadata via the whiteboard' do
      @student_2_asset_url.title = 'Edited asset title'
      @asset_library.edit_asset_details @student_2_asset_url
      sleep 1
      @asset_library.wait_until(timeout) { @asset_library.detail_view_asset_title == 'Edited asset title' }
    end

    it('does not allow a student user to delete it via the whiteboard') { expect(@asset_library.delete_asset_button?).to be false }

  end
end
