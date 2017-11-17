require_relative '../../util/spec_helper'

describe 'Whiteboard Add Asset', order: :defined do

  test_id = Utils.get_test_id
  timeout = Utils.short_wait
  event = Event.new({csv: LRSUtils.initialize_events_csv('WhiteboardAssets')})

  before(:all) do
    @course = Course.new({})
    @course.site_id = ENV['COURSE_ID']

    # Load test data
    test_user_data = SuiteCUtils.load_suitec_test_data.select { |user| user['tests']['whiteboard_assets'] }
    @admin = User.new({username: Utils.super_admin_username, full_name: 'Admin'})
    @student_1 = User.new test_user_data[0]
    @student_2 = User.new test_user_data[1]
    @student_3 = User.new test_user_data[2]

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryPage.new @driver
    @engagement_index = Page::SuiteCPages::EngagementIndexPage.new @driver
    @whiteboards = Page::SuiteCPages::WhiteboardsPage.new @driver

    # Create test course
    @canvas.log_in(@cal_net, (event.actor = @admin).username, Utils.super_admin_password)
    @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, [@student_1, @student_2, @student_3], test_id,
                                       [LtiTools::ASSET_LIBRARY, LtiTools::ENGAGEMENT_INDEX, LtiTools::WHITEBOARDS])
    @canvas.load_course_site(@driver, @course)
    @asset_library_url = @canvas.click_tool_link(@driver, LtiTools::ASSET_LIBRARY, event)
    @engagement_index_url = @canvas.click_tool_link(@driver, LtiTools::ENGAGEMENT_INDEX, event)
    @whiteboards_url = @canvas.click_tool_link(@driver, LtiTools::WHITEBOARDS, event)
    @asset_library.add_custom_categories(@driver, @asset_library_url, [(@category = "Category #{test_id}")], event)

    # Set "whiteboard add asset" points to non-zero value
    @engagement_index.load_scores(@driver, @engagement_index_url, event)
    @engagement_index.click_points_config event
    @engagement_index.change_activity_points(Activity::ADD_ASSET_TO_WHITEBOARD, '1')
    @engagement_index.wait_for_new_user_sync(@driver, @engagement_index_url, @course, [@student_1, @student_2, @student_3])

    # Student 1 create whiteboard, invite Student 2
    @whiteboard = Whiteboard.new({ owner: @student_1, title: "Whiteboard #{test_id}", collaborators: [@student_2] })
    @canvas.masquerade_as(@driver, (event.actor = @student_1), @course)
    @whiteboards.load_page(@driver, @whiteboards_url, event)
    @whiteboards.create_whiteboard(@whiteboard, event)
    @canvas.stop_masquerading @driver
  end

  after(:all) { @driver.quit }

  context 'when using existing assets' do

    before(:all) do
      # Student 1 add file to asset library
      @student_1_asset_file = Asset.new(@student_1.assets.find { |asset| asset['type'] == 'File' })
      @student_1_asset_file.title = "#{@student_1.full_name} file #{test_id}"
      @student_1_asset_file.category = @category
      @canvas.masquerade_as(@driver, (event.actor = @student_1), @course)
      @asset_library.load_page(@driver, @asset_library_url, event)
      @asset_library.upload_file_to_library(@student_1_asset_file, event)

      # Student 2 add URL to asset library
      @student_2_asset_url = Asset.new(@student_2.assets.find { |asset| asset['type'] == 'Link' })
      @student_2_asset_url.title = "#{@student_2.full_name} link #{test_id}"
      @student_2_asset_url.category = @category
      @canvas.masquerade_as(@driver, (event.actor = @student_2), @course)
      @asset_library.load_page(@driver, @asset_library_url, event)
      @asset_library.add_site(@student_2_asset_url, event)

      # Student 3 add file to asset library
      @student_3_asset_file = Asset.new(@student_3.assets.find { |asset| asset['type'] == 'File' })
      @student_3_asset_file.title = "#{@student_3.full_name} file #{test_id}"
      @student_3_asset_file.category = @category
      @canvas.masquerade_as(@driver, (event.actor = @student_3), @course)
      @asset_library.load_page(@driver, @asset_library_url, event)
      @asset_library.upload_file_to_library(@student_3_asset_file, event)

      # Get initial scores
      @canvas.stop_masquerading @driver
      event.actor = @admin
      @engagement_index.load_scores(@driver, @engagement_index_url, event)
      @initial_score_stu_1 = @engagement_index.user_score @student_1
      @initial_score_stu_2 = @engagement_index.user_score @student_2
      @initial_score_stu_3 = @engagement_index.user_score @student_3

      @canvas.masquerade_as(@driver, (event.actor = @student_1), @course)
      @whiteboards.load_page(@driver, @whiteboards_url, event)
      @whiteboards.open_whiteboard(@driver, @whiteboard, event)
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
      @whiteboards.add_existing_assets([@student_1_asset_file], event)
      @whiteboards.wait_until(timeout) { @whiteboards.open_original_asset_link_element.attribute('href').include? @student_1_asset_file.id }
    end

    it 'allows the user to add a collaborator\'s assets' do
      @whiteboards.add_existing_assets([@student_2_asset_url], event)
      @whiteboards.wait_until(timeout) { @whiteboards.open_original_asset_link_element.attribute('href').include? @student_2_asset_url.id }
    end

    it 'allows the user to add a non-collaborator\'s assets' do
      @whiteboards.add_existing_assets([@student_3_asset_file], event)
      @whiteboards.wait_until(timeout) { @whiteboards.open_original_asset_link_element.attribute('href').include? @student_3_asset_file.id }
    end

    it 'allows the user to add multiple assets at once' do
      @whiteboards.add_existing_assets([@student_1_asset_file, @student_2_asset_url, @student_3_asset_file], event)
      @whiteboards.wait_until(timeout) { @whiteboards.open_original_asset_link_element.attribute('href').include? (@student_1_asset_file.id || @student_2_asset_url.id || @student_3_asset_file.id) }
    end

    it 'earns "Add an asset to a whiteboard" but not "Add a new asset to the Asset Library" points on the Engagement Index for each asset used' do
      @whiteboards.close_whiteboard @driver
      @canvas.stop_masquerading @driver
      event.actor = @admin
      @engagement_index.load_scores(@driver, @engagement_index_url, event)
      expect(@engagement_index.user_score @student_1).to eql("#{@initial_score_stu_1.to_i + 4}")
    end

    it 'shows "add_asset_to_whiteboard" but not "add_asset" activity on the CSV export for each asset belonging to another user' do
      scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url, event)
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
      @engagement_index.load_scores(@driver, @engagement_index_url, event)
      @initial_score = @engagement_index.user_score @student_1
      @student_1_asset_no_title = Asset.new(@student_1.assets.find { |asset| asset['type'] == 'File' })
      @student_1_asset_long_title = Asset.new((@student_1.assets.select { |asset| asset['type'] == 'File' })[0])
      @student_1_asset_visible = Asset.new((@student_1.assets.select { |asset| asset['type'] == 'File' })[1])
      @student_1_asset_hidden = Asset.new((@student_1.assets.select { |asset| asset['type'] == 'File' })[2])
      @canvas.masquerade_as(@driver, (event.actor = @student_1), @course)
    end

    before(:each) { @whiteboards.close_whiteboard @driver }

    it 'requires an asset title' do
      @student_1_asset_no_title.title = nil
      @whiteboards.load_page(@driver, @whiteboards_url, event)
      @whiteboards.open_whiteboard(@driver, @whiteboard, event)
      @whiteboards.click_add_new_asset @student_1_asset_no_title
      @whiteboards.enter_file_path_for_upload @student_1_asset_no_title.file_name
      @whiteboards.enter_file_metadata @student_1_asset_no_title
      @whiteboards.click_add_files_button
      @whiteboards.wait_until(timeout) { @whiteboards.missing_title_error_elements.any? }
    end

    it 'requires an asset title of 255 characters maximum' do
      @student_1_asset_long_title.title = "File #{test_id} #{'A loooooong title' * 15}"
      @whiteboards.load_page(@driver, @whiteboards_url, event)
      @whiteboards.open_whiteboard(@driver, @whiteboard, event)

      # More than 255 chars is rejected
      @whiteboards.click_add_new_asset @student_1_asset_long_title
      @whiteboards.enter_file_path_for_upload @student_1_asset_long_title.file_name
      @whiteboards.enter_file_metadata @student_1_asset_long_title
      @whiteboards.click_add_files_button
      @whiteboards.wait_until(timeout) { @whiteboards.long_title_error_elements.any? }
      @whiteboards.click_cancel_button

      # Exactly 255 chars is accepted and asset is created
      @student_1_asset_long_title.title = @student_1_asset_long_title.title[0, 255]
      @whiteboards.add_asset_include_in_library(@student_1_asset_long_title, event)
      expect(@student_1_asset_long_title.id).not_to be_nil
    end

    it 'allows the user to add the upload to the asset library' do
      @student_1_asset_visible.title = "#{test_id} Student 1 file added to library"
      @whiteboards.load_page(@driver, @whiteboards_url, event)
      @whiteboards.open_whiteboard(@driver, @whiteboard, event)
      @whiteboards.add_asset_include_in_library(@student_1_asset_visible, event)
      expect(@student_1_asset_visible.id).not_to be_nil

      # Asset appears in the library
      @whiteboards.close_whiteboard @driver
      @asset_library.load_page(@driver, @asset_library_url, event)
      @asset_library.verify_first_asset(@student_1, @student_1_asset_visible, event)
    end

    it 'allows the user to exclude the upload from the asset library' do
      @student_1_asset_hidden.title = "#{test_id} Student 1 file not added to library"
      @whiteboards.load_page(@driver, @whiteboards_url, event)
      @whiteboards.open_whiteboard(@driver, @whiteboard, event)
      @whiteboards.add_asset_exclude_from_library(@student_1_asset_hidden, event)
      expect(@student_1_asset_hidden.id).not_to be_nil

      # Asset is not searchable
      @asset_library.load_page(@driver, @asset_library_url, event)
      @asset_library.advanced_search(@student_1_asset_hidden.title, nil, @student_1, 'File', nil, event)
      @asset_library.no_search_results_element.when_visible Utils.short_wait

    end

    it 'allows the asset owner to view a hidden asset deep link' do
      @whiteboards.close_whiteboard @driver
      visible_to_owner = @asset_library.verify_block { @asset_library.load_asset_detail(@driver, @asset_library_url, @student_1_asset_hidden, event) }
      expect(visible_to_owner).to be true
    end

    it 'allows a whiteboard collaborator to view a hidden asset deep link' do
      @canvas.masquerade_as(@driver, (event.actor = @student_2), @course)
      visible_to_collab = @asset_library.verify_block { @asset_library.load_asset_detail(@driver, @asset_library_url, @student_1_asset_hidden, event) }
      expect(visible_to_collab).to be true
    end

    it 'does not allow a user who is not the owner or whiteboard collaborator to view a hidden asset deep link' do
      @canvas.masquerade_as(@driver, (event.actor = @student_3), @course)
      visible_to_other = @asset_library.verify_block { @asset_library.load_asset_detail(@driver, @asset_library_url, @student_1_asset_hidden, event) }
      expect(visible_to_other).to be false
    end

    it 'earns "Add a new asset to the Asset Library" points on the Engagement Index' do
      @canvas.stop_masquerading @driver
      event.actor = @admin
      @engagement_index.load_scores(@driver, @engagement_index_url, event)
      expect(@engagement_index.user_score @student_1).to eql("#{@initial_score.to_i + (Activity::ADD_ASSET_TO_LIBRARY.points * 2)}")
    end

    it 'shows "add_asset" activity on the CSV export' do
      scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url, event)
      expect(scores).to include("#{@student_1.full_name}, #{Activity::ADD_ASSET_TO_LIBRARY.type}, #{Activity::ADD_ASSET_TO_LIBRARY.points}, #{@initial_score.to_i + Activity::ADD_ASSET_TO_LIBRARY.points}")
      expect(scores).to include("#{@student_1.full_name}, #{Activity::ADD_ASSET_TO_LIBRARY.type}, #{Activity::ADD_ASSET_TO_LIBRARY.points}, #{@initial_score.to_i + (Activity::ADD_ASSET_TO_LIBRARY.points * 2)}")
      expect(scores).to_not include("#{@student_1.full_name}, #{Activity::ADD_ASSET_TO_LIBRARY.type}, #{Activity::ADD_ASSET_TO_LIBRARY.points}, #{@initial_score.to_i + (Activity::ADD_ASSET_TO_LIBRARY.points * 3)}")
    end
  end

  context 'when adding new URL assets' do

    before(:all) do
      @engagement_index.load_scores(@driver, @engagement_index_url, event)
      @initial_score = @engagement_index.user_score @student_2
      @canvas.masquerade_as(@driver, (event.actor = @student_2), @course)
    end

    before(:each) { @whiteboards.close_whiteboard @driver }

    it 'requires an asset title' do
      student_2_asset_no_title = Asset.new(@student_2.assets.find { |asset| asset['type'] == 'Link' })
      student_2_asset_no_title.title = nil
      @whiteboards.load_page(@driver, @whiteboards_url, event)
      @whiteboards.open_whiteboard(@driver, @whiteboard, event)
      @whiteboards.click_add_new_asset student_2_asset_no_title
      @whiteboards.enter_url_metadata student_2_asset_no_title
      @whiteboards.click_add_url_button
      @whiteboards.wait_until(timeout) { @whiteboards.missing_title_error_elements.any? }
    end

    it 'requires an asset title of 255 characters maximum' do
      student_2_asset_long_title = Asset.new(@student_2.assets.find { |asset| asset['type'] == 'Link' })
      student_2_asset_long_title.title = "Link #{test_id} #{'A loooooong title' * 15}"
      @whiteboards.load_page(@driver, @whiteboards_url, event)
      @whiteboards.open_whiteboard(@driver, @whiteboard, event)

      # More than 255 chars is rejected
      @whiteboards.click_add_new_asset student_2_asset_long_title
      @whiteboards.enter_url_metadata student_2_asset_long_title
      @whiteboards.click_add_url_button
      @whiteboards.wait_until(timeout) { @whiteboards.long_title_error_elements.any? }
      @whiteboards.click_cancel_button

      # Exactly 255 chars is accepted and asset is created
      student_2_asset_long_title.title = student_2_asset_long_title.title[0, 255]
      @whiteboards.add_asset_include_in_library(student_2_asset_long_title, event)
      expect(student_2_asset_long_title.id).not_to be_nil
    end

    it 'allows the user to add the site to the asset library' do
      student_2_asset_visible = Asset.new(@student_2.assets.find { |asset| asset['type'] == 'Link' })
      student_2_asset_visible.title = "#{test_id} Student 2 link added to library"
      @whiteboards.load_page(@driver, @whiteboards_url, event)
      @whiteboards.open_whiteboard(@driver, @whiteboard, event)
      @whiteboards.add_asset_include_in_library(student_2_asset_visible, event)
      expect(student_2_asset_visible.id).not_to be_nil

      # Asset appears in the library
      @whiteboards.close_whiteboard @driver
      @asset_library.load_page(@driver, @asset_library_url, event)
      @asset_library.verify_first_asset(@student_2, student_2_asset_visible, event)
    end

    it 'allows the user to exclude the site from the asset library' do
      student_2_asset_hidden = Asset.new(@student_2.assets.find { |asset| asset['type'] == 'Link' })
      student_2_asset_hidden.title = "#{test_id} Student 2 link not added to library"
      @whiteboards.load_page(@driver, @whiteboards_url, event)
      @whiteboards.open_whiteboard(@driver, @whiteboard, event)
      @whiteboards.add_asset_exclude_from_library(student_2_asset_hidden, event)
      expect(student_2_asset_hidden.id).not_to be_nil

      # Asset is reachable via deep link
      @whiteboards.close_whiteboard @driver
      reachable = @asset_library.verify_block { @asset_library.load_asset_detail(@driver, @asset_library_url, student_2_asset_hidden, event) }
      expect(reachable).to be true

      # Asset is not searchable
      @asset_library.load_page(@driver, @asset_library_url, event)
      @asset_library.advanced_search(student_2_asset_hidden.title, nil, @student_2, 'Link', nil, event)
      @asset_library.no_search_results_element.when_visible Utils.short_wait
    end

    it 'earns "Add a new asset to the Asset Library" points on the Engagement Index' do
      @canvas.stop_masquerading @driver
      event.actor = @admin
      @engagement_index.load_scores(@driver, @engagement_index_url, event)
      expect(@engagement_index.user_score @student_2).to eql("#{@initial_score.to_i + (Activity::ADD_ASSET_TO_LIBRARY.points * 2)}")
    end

    it 'shows "add_asset" activity on the CSV export' do
      scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url, event)
      expect(scores).to include("#{@student_2.full_name}, #{Activity::ADD_ASSET_TO_LIBRARY.type}, #{Activity::ADD_ASSET_TO_LIBRARY.points}, #{@initial_score.to_i + Activity::ADD_ASSET_TO_LIBRARY.points}")
      expect(scores).to include("#{@student_2.full_name}, #{Activity::ADD_ASSET_TO_LIBRARY.type}, #{Activity::ADD_ASSET_TO_LIBRARY.points}, #{@initial_score.to_i + (Activity::ADD_ASSET_TO_LIBRARY.points * 2)}")
      expect(scores).to_not include("#{@student_2.full_name}, #{Activity::ADD_ASSET_TO_LIBRARY.type}, #{Activity::ADD_ASSET_TO_LIBRARY.points}, #{@initial_score.to_i + (Activity::ADD_ASSET_TO_LIBRARY.points * 3)}")
    end
  end

  context 'when the asset is hidden from the asset library' do

    before(:all) do
      @canvas.masquerade_as(@driver, (event.actor = @student_1), @course)
      @whiteboards.load_page(@driver, @whiteboards_url, event)
      @whiteboards.open_whiteboard(@driver, @whiteboard, event)
      @whiteboards.add_collaborator(@whiteboard, @student_3, event)
      @whiteboards.close_whiteboard @driver
      @canvas.stop_masquerading @driver

      @student_3_asset_hidden = Asset.new(@student_3.assets.find { |asset| asset['type'] == 'File' })
      @student_3_asset_hidden.title = "#{test_id} Student 3 file not added to library"

      @canvas.masquerade_as(@driver, (event.actor = @student_3), @course)
      @whiteboards.load_page(@driver, @whiteboards_url, event)
      @whiteboards.open_whiteboard(@driver, @whiteboard, event)
      @whiteboards.add_asset_exclude_from_library(@student_3_asset_hidden, event)
      @whiteboards.open_original_asset(@driver, @asset_library, @student_3_asset_hidden, event)
    end

    it 'allows the user to comment on it via the whiteboard' do
      @asset_library.add_comment(@student_3_asset_hidden, Comment.new(@student_3, 'Comment on a hidden asset'), event)
      @asset_library.verify_comments @student_3_asset_hidden
    end

    it 'allows the user to edit its metadata via the whiteboard' do
      @student_3_asset_hidden.title = "#{@student_3_asset_hidden.title} - edited"
      @asset_library.edit_asset_details(@student_3_asset_hidden, event)
    end

    it('does not allow a student user to delete it via the whiteboard') { expect(@asset_library.delete_asset_button?).to be false }

  end
end
