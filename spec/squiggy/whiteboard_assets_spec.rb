require_relative '../../util/spec_helper'

include Logging

describe 'Whiteboard Add Asset' do

  before(:all) do
    @test = SquiggyTestConfig.new 'whiteboard_assets'
    @test.course.site_id = ENV['COURSE_ID']
    @student_1 = @test.students[0]
    @student_2 = @test.students[1]
    @student_3 = @test.students[2]

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @assets_list = SquiggyAssetLibraryListViewPage.new @driver
    @asset_detail = SquiggyAssetLibraryDetailPage.new @driver
    @manage_assets = SquiggyAssetLibraryManageAssetsPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver
    @whiteboards = SquiggyWhiteboardPage.new @driver

    @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course @test

    @category = SquiggyCategory.new "Category #{@test.id}"
    @assets_list.load_page @test
    @assets_list.click_manage_assets_link
    @manage_assets.create_new_category @category

    # Set "whiteboard add asset" points to non-zero value
    @engagement_index.load_scores @test
    @engagement_index.click_points_config
    @engagement_index.change_activity_points(SquiggyActivity::ADD_ASSET_TO_WHITEBOARD, 1)
    @engagement_index.wait_for_new_user_sync(@test, [@student_1, @student_2, @student_3])

    # Student 1 create whiteboard, invite Student 2
    @whiteboard = SquiggyWhiteboard.new(
      owner: @student_1,
      title: "Whiteboard #{@test.id}",
      collaborators: [@student_2]
    )
    @canvas.masquerade_as(@student_1, @course)
    @whiteboards.load_page @test
    @whiteboards.create_whiteboard @whiteboard
    @canvas.stop_masquerading
  end

  context 'when using existing assets' do

    before(:all) do
      # Student 1 add file to asset library
      @student_1_file = @student_1.assets.find &:file_name
      @student_1_file.title = "#{@student_1.full_name} file #{@test.id}"
      @student_1_file.category = @category
      @canvas.masquerade_as(@student_1, @test.course)
      @assets_list.load_page @test
      @assets_list.upload_file_asset @student_1_file

      # Student 2 add URL to asset library
      @student_2_url = @student_2.assets.find &:url
      @student_2_url.title = "#{@student_2.full_name} link #{@test.id}"
      @student_2_url.category = @category
      @canvas.masquerade_as(@student_2, @test.course)
      @assets_list.load_page @test
      @assets_list.add_link_asset @student_2_url

      # Student 3 add file to asset library
      @student_3_file = @student_3.assets.find &:file_name
      @student_3_file.title = "#{@student_3.full_name} file #{@test.id}"
      @student_3_file.category = @category
      @canvas.masquerade_as(@student_3, @test.course)
      @assets_list.load_page @test
      @assets_list.upload_file_asset @student_3_file

      # Get initial scores
      @canvas.stop_masquerading
      @initial_score_stu_1 = @engagement_index.user_score(@test, @student_1)
      @initial_score_stu_2 = @engagement_index.user_score(@test, @student_2)
      @initial_score_stu_3 = @engagement_index.user_score(@test, @student_3)

      @canvas.masquerade_as @student_1
      @whiteboards.load_page @test
      @whiteboards.open_whiteboard @whiteboard
    end

    before(:each) { @whiteboards.click_cancel_button if @whiteboards.cancel_button? }

    it 'allows the user to cancel adding assets' do
      @whiteboards.click_add_existing_asset
      @whiteboards.wait_until(Utils.short_wait) { @whiteboards.asset_elements.any? }
      expect(@whiteboards.save_button_element.attribute 'disabled').to eql('true')
      @whiteboards.click_cancel_button
      @whiteboards.wait_until(Utils.short_wait) { @whiteboards.asset_elements.empty? }
    end

    it 'allows the user to add its own assets' do
      @whiteboards.add_existing_assets [@student_1_file]
      @whiteboards.wait_until(Utils.short_wait) do
        @whiteboards.open_original_asset_link_element.attribute('href').include? @student_1_file.id
      end
    end

    it 'allows the user to add a collaborator\'s assets' do
      @whiteboards.add_existing_assets [@student_2_url]
      @whiteboards.wait_until(Utils.short_wait) do
        @whiteboards.open_original_asset_link_element.attribute('href').include? @student_2_url.id
      end
    end

    it 'allows the user to add a non-collaborator\'s assets' do
      @whiteboards.add_existing_assets [@student_3_file]
      @whiteboards.wait_until(Utils.short_wait) do
        @whiteboards.open_original_asset_link_element.attribute('href').include? @student_3_file.id
      end
    end

    it 'allows the user to add multiple assets at once' do
      @whiteboards.add_existing_assets [@student_1_file, @student_2_url, @student_3_file]
      @whiteboards.wait_until(Utils.short_wait) do
        href = @whiteboards.open_original_asset_link_element.attribute('href')
        href.include?(@student_1_file.id) || href.include?(@student_2_url.id) || href.include?(@student_3_file.id)
      end
    end

    it 'earns "Add an asset to a whiteboard" but not "Add a new asset to the Asset Library" points on the Engagement Index for each asset used' do
      @whiteboards.close_whiteboard
      @canvas.stop_masquerading
      expect(@engagement_index.user_score(@test, @student_1)).to eql(@initial_score_stu_1.to_i + 4)
    end

    it 'shows "add_asset_to_whiteboard" but not "add_asset" activity on the CSV export for each asset belonging to another user' do
      csv = @engagement_index.download_csv @test
      4.times do
        expect(@engagement_index.csv_activity_row(csv, SquiggyActivity::ADD_ASSET_TO_WHITEBOARD, @student_1, @initial_score_stu_1)).to be_truthy
      end
      expect(@engagement_index.csv_activity_row(csv, SquiggyActivity::GET_ADD_ASSET_TO_WHITEBOARD, @student_2, @initial_score_stu_2)).to be_truthy
      expect(@engagement_index.csv_activity_row(csv, SquiggyActivity::GET_ADD_ASSET_TO_WHITEBOARD, @student_3, @initial_score_stu_3)).to be_truthy
    end
  end

  context 'when uploading new assets' do

    before(:all) do
      @initial_score = @engagement_index.user_score(@test, @student_1)
      @student_1_asset_no_title = @student_1.assets.find &:file_name
      @student_1_asset_long_title = @student_1.assets.select(&:file_name)[0]
      @student_1_asset_visible = @student_1.assets.select(&:file_name)[1]
      @student_1_asset_hidden = @student_1.assets.select(&:file_name)[2]
      @canvas.masquerade_as(@student_1, @test.course)
    end

    before(:each) { @whiteboards.close_whiteboard }

    it 'requires an asset title' do
      @student_1_asset_no_title.title = nil
      @whiteboards.load_page @test
      @whiteboards.open_whiteboard @whiteboard
      @whiteboards.click_add_new_asset @student_1_asset_no_title
      @whiteboards.enter_file_path_for_upload @student_1_asset_no_title
      @whiteboards.enter_asset_metadata @student_1_asset_no_title
      expect(@whiteboards.save_file_button_element.enabled?).to be false
    end

    it 'requires an asset title of 255 characters maximum' do
      @student_1_asset_long_title.title = "File #{@test.id} #{'A loooooong title' * 15}"
      @whiteboards.load_page @test
      @whiteboards.open_whiteboard @whiteboard

      # More than 255 chars is rejected
      @whiteboards.click_add_new_asset @student_1_asset_long_title
      @whiteboards.enter_file_path_for_upload @student_1_asset_long_title
      @whiteboards.enter_asset_metadata @student_1_asset_long_title
      @whiteboards.title_length_at_max_msg_element.when_visible 2
      @whiteboards.hit_escape

      # Exactly 255 chars is accepted and asset is created
      @student_1_asset_long_title.title = @student_1_asset_long_title.title[0, 255]
      @whiteboards.add_asset_include_in_library @student_1_asset_long_title
      expect(@student_1_asset_long_title.id).not_to be_nil
    end

    it 'allows the user to add the upload to the asset library' do
      @student_1_asset_visible.title = "#{@test.id} Student 1 file added to library"
      @whiteboards.load_page @test
      @whiteboards.open_whiteboard @whiteboard
      @whiteboards.add_asset_include_in_library @student_1_asset_visible
      expect(@student_1_asset_visible.id).not_to be_nil

      # Asset appears in the library
      @whiteboards.close_whiteboard
      @assets_list.load_page @test
      @assets_list.asset_el(@student_1_asset_visible).when_present Utils.short_wait
    end

    it 'allows the user to exclude the upload from the asset library' do
      @student_1_asset_hidden.title = "#{@test.id} Student 1 file not added to library"
      @whiteboards.load_page @test
      @whiteboards.open_whiteboard @whiteboard
      @whiteboards.add_asset_exclude_from_library @student_1_asset_hidden
      expect(@student_1_asset_hidden.id).not_to be_nil

      # Asset is not searchable
      @assets_list.load_page @test
      @assets_list.advanced_search(@student_1_asset_hidden.title, nil, @student_1, 'File', nil)
      @assets_list.no_results_msg_element.when_visible Utils.short_wait
    end

    it 'allows the asset owner to view a hidden asset deep link' do
      @whiteboards.close_whiteboard
      @asset_detail.load_asset_detail(@test, @student_1_asset_hidden)
    end

    it 'allows a whiteboard collaborator to view a hidden asset deep link' do
      @canvas.masquerade_as(@student_2, @test.course)
      @asset_detail.load_asset_detail(@test, @student_1_asset_hidden)
    end

    it 'does not allow a user who is not the owner or whiteboard collaborator to view a hidden asset deep link' do
      @canvas.masquerade_as(@student_3, @test.course)
      visible_to_other = @assets_list.verify_block { @asset_library.load_asset_detail(@test, @student_1_asset_hidden) }
      expect(visible_to_other).to be false
    end

    it 'earns "Add a new asset to the Asset Library" points on the Engagement Index' do
      @canvas.stop_masquerading
      expect(@engagement_index.user_score(@test, @student_1)).to eql(@initial_score.to_i + (SquiggyActivity::ADD_ASSET_TO_LIBRARY.points * 2))
    end

    it 'shows "add_asset" activity on the CSV export' do
      csv = @engagement_index.download_csv @test
      2.times do
        expect(@engagement_index.csv_activity_row(csv, SquiggyActivity::ADD_ASSET_TO_LIBRARY, @student_1, @initial_score)).to be_truthy
      end
      expect(@engagement_index.csv_activity_row(csv, SquiggyActivity::ADD_ASSET_TO_LIBRARY, @student_1, @initial_score)).to be_falsey
    end
  end

  context 'when adding new URL assets' do

    before(:all) do
      @initial_score = @engagement_index.user_score(@test, @student_2)
      @canvas.masquerade_as(@student_2, @test.course)
    end

    before(:each) { @whiteboards.close_whiteboard }

    it 'requires an asset title' do
      student_2_asset_no_title = @student_2.assets.find &:url
      student_2_asset_no_title.title = nil
      @whiteboards.load_page @test
      @whiteboards.open_whiteboard @whiteboard
      @whiteboards.click_add_new_asset student_2_asset_no_title
      @whiteboards.enter_asset_metadata student_2_asset_no_title
      expect(@whiteboards.save_button_element.enabled?).to be false
    end

    it 'requires an asset title of 255 characters maximum' do
      student_2_asset_long_title = @student_2.assets.find &:url
      student_2_asset_long_title.title = "Link #{@test.id} #{'A loooooong title' * 15}"
      @whiteboards.load_page @test
      @whiteboards.open_whiteboard @whiteboard

      # More than 255 chars is rejected
      @whiteboards.click_add_new_asset student_2_asset_long_title
      @whiteboards.enter_asset_metadata student_2_asset_long_title
      @whiteboards.title_length_at_max_msg_element.when_visible 2
      @whiteboards.click_cancel_link_button

      # Exactly 255 chars is accepted and asset is created
      student_2_asset_long_title.title = student_2_asset_long_title.title[0, 255]
      @whiteboards.add_asset_include_in_library student_2_asset_long_title
      expect(student_2_asset_long_title.id).not_to be_nil
    end

    it 'allows the user to add the site to the asset library' do
      student_2_asset_visible = @student_2.assets.find &:url
      student_2_asset_visible.title = "#{@test.id} Student 2 link added to library"
      @whiteboards.load_page @test
      @whiteboards.open_whiteboard @whiteboard
      @whiteboards.add_asset_include_in_library student_2_asset_visible
      expect(student_2_asset_visible.id).not_to be_nil

      # Asset appears in the library
      @whiteboards.close_whiteboard
      @assets_list.load_page @test
      @assets_list.asset_el(student_2_asset_visible).when_present Utils.short_wait
    end

    it 'allows the user to exclude the site from the asset library' do
      student_2_asset_hidden = @student_2.assets.find &:url
      student_2_asset_hidden.title = "#{@test.id} Student 2 link not added to library"
      @whiteboards.load_page @test
      @whiteboards.open_whiteboard @whiteboard
      @whiteboards.add_asset_exclude_from_library student_2_asset_hidden
      expect(student_2_asset_hidden.id).not_to be_nil

      # Asset is reachable via deep link
      @whiteboards.close_whiteboard
      @asset_detail.load_asset_detail(@test, student_2_asset_hidden)

      # Asset is not searchable
      @assets_list.load_page @test
      @assets_list.advanced_search(student_2_asset_hidden.title, nil, @student_2, 'Link', nil)
      @assets_list.no_results_msg_element.when_visible Utils.short_wait
    end

    it 'earns "Add a new asset to the Asset Library" points on the Engagement Index' do
      @canvas.stop_masquerading
      expect(@engagement_index.user_score(@test, @student_2)).to eql(@initial_score.to_i + (SquiggyActivity::ADD_ASSET_TO_LIBRARY.points * 2))
    end

    it 'shows "add_asset" activity on the CSV export' do
      csv = @engagement_index.download_csv @test
      2.times do
        expect(@engagement_index.csv_activity_row(csv, SquiggyActivity::ADD_ASSET_TO_LIBRARY, @student_2, @initial_score)).to be_truthy
      end
      expect(@engagement_index.csv_activity_row(csv, SquiggyActivity::ADD_ASSET_TO_LIBRARY, @student_2, @initial_score)).to be_falsey
    end
  end

  context 'when the asset is hidden from the asset library' do

    before(:all) do
      @canvas.masquerade_as(@student_1, @test.course)
      @whiteboards.load_page @test
      @whiteboards.open_whiteboard @whiteboard
      @whiteboards.add_collaborator @student_3
      @whiteboards.close_whiteboard
      @canvas.stop_masquerading

      @student_3_asset_hidden = @student_3.assets.find &:file_name
      @student_3_asset_hidden.title = "#{@test.id} Student 3 file not added to library"

      @canvas.masquerade_as(@student_3, @test.course)
      @whiteboards.load_page @test
      @whiteboards.open_whiteboard @whiteboard
      @whiteboards.add_asset_exclude_from_library @student_3_asset_hidden
      @whiteboards.open_original_asset(@test, @student_3_asset_hidden)
    end

    it 'allows the user to comment on it via the whiteboard' do
      comment = Comment.new(@student_3, 'Comment on a hidden asset')
      visible_comment = @asset_library.add_comment(@student_3_asset_hidden, comment)
      expect(visible_comment[:commenter]).to include(@student_3.full_name)
      expect(visible_comment[:body]).to eql(comment.body)
    end

    it 'allows the user to edit its metadata via the whiteboard' do
      @student_3_asset_hidden.title = "#{@student_3_asset_hidden.title} - edited"
      @asset_detail.edit_asset_details @student_3_asset_hidden
    end

    it 'does not allow a student user to delete it via the whiteboard' do
      expect(@asset_detail.delete_asset_button?).to be false
    end
  end
end
