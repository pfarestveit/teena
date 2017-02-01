require_relative '../../util/spec_helper'

include Logging

describe 'Asset', order: :defined do

  test_id = Utils.get_test_id

  # Get test users
  user_test_data = Utils.load_test_users.select { |data| data['tests']['assetLibraryCategorySearch'] }
  users = user_test_data.map { |data| User.new(data) if ['Teacher', 'Designer', 'Lead TA', 'TA', 'Observer', 'Reader', 'Student'].include? data['role'] }
  teacher = users.find { |user| user.role == 'Teacher' }
  students = users.select { |user| user.role == 'Student' }
  student_uploader = students[0]
  student_viewer = students[1]
  asset = Asset.new (student_uploader.assets.find { |asset| asset['type'] == 'Link' })

  before(:all) do
    @course = Course.new({})
    @course.site_id = ENV['course_id']

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryPage.new @driver
    @engagement_index = Page::SuiteCPages::EngagementIndexPage.new @driver
    @whiteboards = Page::SuiteCPages::WhiteboardsPage.new @driver

    # Obtain course site and add two new asset categories
    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.get_suite_c_test_course(@course, users, test_id, [SuiteCTools::ASSET_LIBRARY, SuiteCTools::ENGAGEMENT_INDEX, SuiteCTools::WHITEBOARDS])
    @whiteboards_url = @canvas.click_tool_link(@driver, SuiteCTools::WHITEBOARDS)
    @engagement_index_url = @canvas.click_tool_link(@driver, SuiteCTools::ENGAGEMENT_INDEX)
    @asset_library_url = @canvas.click_tool_link(@driver, SuiteCTools::ASSET_LIBRARY)
    @asset_library.add_custom_categories(@driver, @asset_library_url, [(@category_1="Category 1 - #{test_id}"), (@category_2="Category 2 - #{test_id}")])
  end

  after(:all) { @driver.quit }

  describe 'metadata edits' do

    before(:all) do
      # Upload a new asset for the test
      @canvas.masquerade_as(student_uploader, @course)
      @asset_library.load_page(@driver, @asset_library_url)
      asset.title = "#{Time.now.to_i}"
      asset.category = @category_1
      @asset_library.add_site asset
      logger.debug "Asset ID #{asset.id} has title '#{asset.title}'"

      @asset_library.load_asset_detail(@driver, @asset_library_url, asset)
      @asset_library.add_comment 'An asset comment'
      @asset_library.toggle_detail_view_item_like
    end

    it 'are not allowed if the user is a student who is not the asset creator' do
      @canvas.masquerade_as(student_viewer, @course)
      @asset_library.load_asset_detail(@driver, @asset_library_url, asset)
      expect(@asset_library.edit_details_link_element.visible?).to be false
    end

    it 'are allowed if the user is a teacher' do
      @canvas.masquerade_as(teacher, @course)
      @asset_library.load_asset_detail(@driver, @asset_library_url, asset)

      asset.title = "#{asset.title} - edited by teacher"
      asset.category = @category_2
      asset.description = 'Description edited by teacher'

      @asset_library.edit_asset_details asset
      @asset_library.load_list_view_asset(@driver, @asset_library_url, asset)
      @asset_library.verify_first_asset(student_uploader, asset)
    end

    it 'are allowed if the user is a student who is the asset creator' do
      @canvas.masquerade_as(student_uploader, @course)
      @asset_library.load_asset_detail(@driver, @asset_library_url, asset)

      asset.title = "#{asset.title} - edited by student"
      asset.category = nil
      asset.description = 'Description edited by student'

      @asset_library.edit_asset_details asset
      @asset_library.load_list_view_asset(@driver, @asset_library_url, asset)
      @asset_library.verify_first_asset(student_uploader, asset)
    end
  end

  describe 'deleting' do

    context 'when the asset has no comments or likes and has not been used on a whiteboard' do

      before(:each) do
        # Upload a new asset for the test
        asset.title = "#{Time.now.to_i}"
        @canvas.masquerade_as(student_uploader, @course)
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.add_site asset
        logger.debug "Asset ID #{asset.id} has title '#{asset.title}'"

        # Get the students' initial scores
        @canvas.stop_masquerading
        @engagement_index.load_page(@driver, @engagement_index_url)
        @uploader_score = @engagement_index.user_score student_uploader
      end

      it 'can be done by a teacher with no effect on points already earned' do
        # Delete asset
        @canvas.masquerade_as(teacher, @course)
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset)
        @asset_library.delete_asset
        @asset_library.advanced_search(test_id, nil, student_uploader, nil)
        @asset_library.no_search_results_element.when_present Utils.short_wait

        # Check points
        @canvas.stop_masquerading
        @engagement_index.load_page(@driver, @engagement_index_url)
        expect(@engagement_index.user_score student_uploader).to eql(@uploader_score)
        scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
        expect(scores).to include("#{student_uploader.full_name}, add_asset, #{Activities::ADD_ASSET_TO_LIBRARY.points}, #{@uploader_score}")
      end

      it 'can be done by the student who created the asset with no effect on points already earned' do
        # Delete asset
        @canvas.masquerade_as(student_uploader, @course)
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset)
        @asset_library.delete_asset
        @asset_library.advanced_search(test_id, nil, student_uploader, nil)
        @asset_library.no_search_results_element.when_present Utils.short_wait

        # Check points
        @canvas.stop_masquerading
        @engagement_index.load_page(@driver, @engagement_index_url)
        expect(@engagement_index.user_score student_uploader).to eql(@uploader_score)
      end

      it 'cannot be done by a student who did not create the asset' do
        @canvas.masquerade_as(student_viewer, @course)
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset)
        expect(@asset_library.delete_asset_button?).to be false
      end

    end

    context 'when there are comments on the asset' do

      before(:each) do
        # Upload a new asset for the test
        asset.title = "#{Time.now.to_i}"
        @canvas.masquerade_as(student_uploader, @course)
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.add_site asset
        logger.debug "Asset ID #{asset.id} has title '#{asset.title}'"

        # Add a comment
        @canvas.masquerade_as(student_viewer, @course)
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset)
        @asset_library.add_comment 'An asset comment'

        # Get the students' initial scores
        @canvas.stop_masquerading
        @engagement_index.load_page(@driver, @engagement_index_url)
        @uploader_score = @engagement_index.user_score student_uploader
        @viewer_score = @engagement_index.user_score student_viewer
      end

      it 'can be done by a teacher with no effect on points already earned' do
        # Delete asset
        @canvas.masquerade_as(teacher, @course)
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset)
        @asset_library.delete_asset
        @asset_library.advanced_search(test_id, nil, student_uploader, nil)
        @asset_library.no_search_results_element.when_present Utils.short_wait

        # Check points
        @canvas.stop_masquerading
        @engagement_index.load_page(@driver, @engagement_index_url)
        expect(@engagement_index.user_score student_uploader).to eql(@uploader_score)
        expect(@engagement_index.user_score student_viewer).to eql(@viewer_score)
        scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
        expect(scores).to include("#{student_uploader.full_name}, get_asset_comment, #{Activities::GET_COMMENT.points}, #{@uploader_score}")
        expect(scores).to include("#{student_viewer.full_name}, asset_comment, #{Activities::COMMENT.points}, #{@viewer_score}")
      end

      it 'cannot be done by the student who created the asset' do
        @canvas.masquerade_as(student_uploader, @course)
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset)
        expect(@asset_library.delete_asset_button?).to be false
      end

      it 'cannot be done by a student who did not create the asset' do
        @canvas.masquerade_as(student_viewer, @course)
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset)
        expect(@asset_library.delete_asset_button?).to be false
      end

    end

    context 'when there are likes on the asset' do

      before(:each) do
        # Upload a new asset for the test
        asset.title = "#{Time.now.to_i}"
        @canvas.masquerade_as(student_uploader, @course)
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.add_site asset
        logger.debug "Asset ID #{asset.id} has title '#{asset.title}'"

        # Add a like
        @canvas.masquerade_as(student_viewer, @course)
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset)
        @asset_library.toggle_detail_view_item_like

        # Get the students' initial scores
        @canvas.stop_masquerading
        @engagement_index.load_page(@driver, @engagement_index_url)
        @uploader_score = @engagement_index.user_score student_uploader
        @viewer_score = @engagement_index.user_score student_viewer
      end

      it 'can be done by a teacher with no effect on points already earned' do
        # Delete asset
        @canvas.masquerade_as(teacher, @course)
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset)
        @asset_library.delete_asset
        @asset_library.advanced_search(test_id, nil, student_uploader, nil)
        @asset_library.no_search_results_element.when_present Utils.short_wait

        # Check points
        @canvas.stop_masquerading
        @engagement_index.load_page(@driver, @engagement_index_url)
        expect(@engagement_index.user_score student_uploader).to eql(@uploader_score)
        expect(@engagement_index.user_score student_viewer).to eql(@viewer_score)
        scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
        expect(scores).to include("#{student_uploader.full_name}, get_like, #{Activities::GET_LIKE.points}, #{@uploader_score}")
        expect(scores).to include("#{student_viewer.full_name}, like, #{Activities::LIKE.points}, #{@viewer_score}")
      end

      it 'cannot be done by the student who created the asset' do
        @canvas.masquerade_as(student_uploader, @course)
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset)
        expect(@asset_library.delete_asset_button?).to be false
      end

      it 'cannot be done by a student who did not create the asset' do
        @canvas.masquerade_as(student_viewer, @course)
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset)
        expect(@asset_library.delete_asset_button?).to be false
      end

    end

    context 'when the asset has been used on a whiteboard' do

      before(:each) do
        # Upload a new asset for the test
        asset.title = "#{Time.now.to_i}"
        @canvas.masquerade_as(student_uploader, @course)
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.add_site asset
        logger.debug "Asset ID #{asset.id} has title '#{asset.title}'"

        # Add to a whiteboard
        @whiteboard = Whiteboard.new({owner: student_viewer, title: 'Test Whiteboard', collaborators: [student_uploader]})
        @canvas.masquerade_as(student_viewer, @course)
        @whiteboards.load_page(@driver, @whiteboards_url)
        @whiteboards.create_whiteboard @whiteboard
        @whiteboards.open_whiteboard(@driver, @whiteboard)
        begin
          @whiteboards.add_existing_assets [asset]
        ensure
          @whiteboards.close_whiteboard @driver
        end

        # Get the students' initial scores
        @canvas.stop_masquerading
        @engagement_index.load_page(@driver, @engagement_index_url)
        @uploader_score = @engagement_index.user_score student_uploader
        @viewer_score = @engagement_index.user_score student_viewer
      end

      it 'can be done by a teacher with no effect on points already earned' do
        # Delete asset
        @canvas.masquerade_as(teacher, @course)
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset)
        @asset_library.delete_asset
        @asset_library.advanced_search(test_id, nil, student_uploader, nil)
        @asset_library.no_search_results_element.when_present Utils.short_wait

        # Check points
        @canvas.stop_masquerading
        @engagement_index.load_page(@driver, @engagement_index_url)
        expect(@engagement_index.user_score student_uploader).to eql(@uploader_score)
        expect(@engagement_index.user_score student_viewer).to eql(@viewer_score)
        # TODO: verify that whiteboard points remain on csv
      end

      it 'cannot be done by the student who created the asset' do
        @canvas.masquerade_as(student_uploader, @course)
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset)
        expect(@asset_library.delete_asset_button?).to be false
      end

      it 'cannot be done by a student who did not create the asset' do
        @canvas.masquerade_as(student_viewer, @course)
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset)
        expect(@asset_library.delete_asset_button?).to be false
      end

    end
  end

  describe 'files in Canvas' do

    users.each do |user|
      it "are visible to course #{user.role} UID #{user.uid} if the user has permission to see them" do
        @canvas.masquerade_as(user, @course)
        expect(@canvas.suitec_files_hidden?(@course, user)).to be true
      end
    end
  end

  describe 'migration' do

    before(:all) do
      @canvas.stop_masquerading

      # Create a destination course site with an asset library for asset migration
      destination_test_id = Utils.get_test_id
      @destination_course = Course.new({})
      @canvas.get_suite_c_test_course(@destination_course, [teacher], destination_test_id, [SuiteCTools::ASSET_LIBRARY])
      @destination_library = Page::SuiteCPages::AssetLibraryPage.new @driver
      @destination_library_url = @canvas.click_tool_link(@driver, SuiteCTools::ASSET_LIBRARY)

      # Teacher logs in to new asset library so that enrollment is synced immediately
      @canvas.masquerade_as(teacher, @destination_course)
      @destination_library.load_page(@driver, @destination_library_url)

      # Teacher creates an asset of each type in origin course site plus one extra that is deleted
      @asset_library.load_page(@driver, @asset_library_url)
      @non_migrated_delete = Asset.new({type: 'File', file_name: 'image-jpegSmall2.jpg', title: "#{destination_test_id} - Deleted File"})
      @asset_library.upload_file_to_library @non_migrated_delete
      @asset_library.load_asset_detail(@driver, @asset_library_url, @non_migrated_delete)
      @asset_library.delete_asset

      @migrated_link = Asset.new({type: 'Link', url: 'https://news.google.com', title: "#{destination_test_id} - Migrated Link", description: 'Migrated link description'})
      @asset_library.add_site @migrated_link

      @migrated_file = Asset.new({type: 'File', file_name: 'image-jpegSmall1.jpg', title: "#{destination_test_id} - Migrated File", category: @category_1})
      @asset_library.upload_file_to_library @migrated_file

      @non_migrated_whiteboard = Whiteboard.new({owner: teacher, title: "#{destination_test_id} - Migrated Whiteboard", collaborators: []})
      @whiteboards.load_page(@driver, @whiteboards_url)
      @whiteboards.create_whiteboard @non_migrated_whiteboard
      @whiteboards.open_whiteboard(@driver, @non_migrated_whiteboard)
      begin
        @whiteboards.add_existing_assets [@migrated_link]
        @migrated_whiteboard = @whiteboards.export_to_asset_library @non_migrated_whiteboard
      ensure
        @whiteboards.close_whiteboard @driver
      end

      # Migrate assets
      @asset_library.migrate_assets(@driver, @asset_library_url, @destination_course)
    end

    it('copies File type assets') { expect(@destination_library.asset_migrated?(@driver, @destination_library_url, @migrated_file, teacher)).to be true }
    it('copies Link type assets') { expect(@destination_library.asset_migrated?(@driver, @destination_library_url, @migrated_link, teacher)).to be true }
    it('does not copy Whiteboard type assets') { expect(@destination_library.asset_migrated?(@driver, @destination_library_url, @migrated_whiteboard, teacher)).to be false }
    it('does not copy deleted assets') { expect(@destination_library.asset_migrated?(@driver, @destination_library_url, @non_migrated_delete, teacher)).to be false }

  end
end
