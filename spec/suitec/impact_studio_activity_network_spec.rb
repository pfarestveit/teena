require_relative '../../util/spec_helper'

describe 'Impact Studio Activity Network', :order => :defined do

  include Logging

  test_id = Utils.get_test_id

  # Load test users, of which there should be one teacher and three students
  user_data = SuiteCUtils.load_suitec_test_data.select { |u| u['tests']['impact_studio_activity_network'] }
  users = user_data.map { |d| User.new d }
  teacher = users.find { |u| u.role == 'Teacher' }
  students = users.select { |u| u.role == 'Student' }
  student_1 = students[0]
  student_2 = students[1]
  student_3 = students[2]
  student1_student2_expected, student1_student3_expected, student2_student1_expected, student2_student3_expected, student3_student1_expected, student3_student2_expected = nil

  # Initialize asset, whiteboard, discussion, and comments
  asset = Asset.new student_1.assets.first
  asset.title = "Asset #{test_id}"
  whiteboard = Whiteboard.new({:owner => student_3, :title => "Whiteboard #{test_id}", :collaborators => [student_2]})
  discussion = Discussion.new("Discussion #{test_id}")
  comment = Comment.new(student_2, "Comment #{test_id}")
  reply = Comment.new(teacher, "Reply #{test_id}")

  before(:all) do
    course_title = "Impact Studio Activity Network #{test_id}"
    course_id = ENV['COURSE_ID']
    @course = Course.new({:title => course_title, :code => course_title, :site_id => course_id})
    @driver = Utils.launch_browser
    @canvas = Page::CanvasAnnounceDiscussPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library_page = Page::SuiteCPages::AssetLibraryDetailPage.new @driver
    @impact_studio_page = Page::SuiteCPages::ImpactStudioPage.new @driver
    @whiteboards_page = Page::SuiteCPages::WhiteboardPage.new @driver
    @engagement_index_page = Page::SuiteCPages::EngagementIndexPage.new @driver

    # Create course site
    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.create_generic_course_site(Utils.canvas_qa_sub_account, @course, users, test_id,
                                       [LtiTools::ASSET_LIBRARY, LtiTools::IMPACT_STUDIO, LtiTools::WHITEBOARDS, LtiTools::ENGAGEMENT_INDEX])
    @asset_library_page_url = @canvas.click_tool_link(@driver, LtiTools::ASSET_LIBRARY)
    @impact_studio_page_url = @canvas.click_tool_link(@driver, LtiTools::IMPACT_STUDIO)
    @whiteboards_url = @canvas.click_tool_link(@driver, LtiTools::WHITEBOARDS)
    @engagement_index_url = @canvas.click_tool_link(@driver, LtiTools::ENGAGEMENT_INDEX)
    @engagement_index_page.wait_for_new_user_sync(@driver, @engagement_index_url, @course, users)

    # Initialize expected user interactions
    student1_student2_expected = @impact_studio_page.init_user_interactions
    student1_student3_expected = @impact_studio_page.init_user_interactions
    student2_student3_expected = @impact_studio_page.init_user_interactions
    student2_student1_expected = @impact_studio_page.init_user_interactions
    student3_student1_expected = @impact_studio_page.init_user_interactions
    student3_student2_expected = @impact_studio_page.init_user_interactions

    # Create asset, whiteboard, and discussion
    @canvas.masquerade_as(student_1, @course)
    @asset_library_page.load_page(@driver, @asset_library_page_url)
    asset.type == 'File' ? @asset_library_page.upload_file_to_library(asset) : @asset_library_page.add_site(asset)

    @canvas.masquerade_as(student_3, @course)
    @whiteboards_page.load_page(@driver, @whiteboards_url)
    @whiteboards_page.create_whiteboard whiteboard

    @canvas.create_course_discussion(@course, discussion)
    @canvas.add_reply(discussion, nil, 'Discussion topic entry')
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when an asset is added to a whiteboard' do

    before(:all) do
      @canvas.masquerade_as(student_3, @course)
      @whiteboards_page.load_page(@driver, @whiteboards_url)
      @whiteboards_page.open_whiteboard(@driver, whiteboard)
      @whiteboards_page.add_existing_assets [asset]
      @whiteboards_page.wait_until(Utils.short_wait) { @whiteboards_page.open_original_asset_link_element.attribute('href').include? asset.id }
      @whiteboards_page.close_whiteboard @driver
      student3_student1_expected[:use_assets][:exports] += 1
      student1_student3_expected[:use_assets][:imports] += 1
    end

    it 'the asset user acquires a "use asset" connection to the asset owner' do
      @impact_studio_page.load_page(@driver, @impact_studio_page_url)
      @impact_studio_page.verify_network_interactions(@driver, student3_student1_expected, student_1)
    end

    it 'the asset owner acquires a "use asset" connection to the asset user' do
      @impact_studio_page.search_for_user student_1
      @impact_studio_page.verify_network_interactions(@driver, student1_student3_expected, student_3)
    end
  end

  context 'when a whiteboard is exported to the asset library' do

    before(:all) do
      @canvas.masquerade_as(student_2, @course)
      @whiteboards_page.load_page(@driver, @whiteboards_url)
      @whiteboards_page.open_whiteboard(@driver, whiteboard)
      @whiteboard_asset = @whiteboards_page.export_to_asset_library(whiteboard)
      @whiteboards_page.close_whiteboard @driver
      student2_student3_expected[:co_creations][:exports] += 1
      student2_student3_expected[:co_creations][:imports] += 1
      student3_student2_expected[:co_creations][:exports] += 1
      student3_student2_expected[:co_creations][:imports] += 1
    end

    it 'the exporter acquires a "co-creation" connection to the whiteboard collaborator' do
      @impact_studio_page.load_page(@driver, @impact_studio_page_url)
      @impact_studio_page.verify_network_interactions(@driver, student2_student3_expected, student_3)
    end

    it 'a collaborator acquires a "co-creation" connection to the exporter' do
      @impact_studio_page.search_for_user student_3
      @impact_studio_page.verify_network_interactions(@driver, student3_student2_expected, student_2)
    end

    context 'and then remixed' do

      before(:all) do
        @canvas.masquerade_as(student_1, @course)
        @asset_library_page.load_asset_detail(@driver, @asset_library_page_url, @whiteboard_asset)
        student1_student2_expected[:views][:exports] += 1
        student1_student3_expected[:views][:exports] += 1
        student2_student1_expected[:views][:imports] += 1
        student3_student1_expected[:views][:imports] += 1

        @asset_library_page.click_remix
        student1_student2_expected[:remixes][:exports] += 1
        student1_student3_expected[:remixes][:exports] += 1
        student2_student1_expected[:remixes][:imports] += 1
        student3_student1_expected[:remixes][:imports] += 1
      end

      it 'the remixer acquires a "view" and "remix" connection to the whiteboard asset owners' do
        @impact_studio_page.load_page(@driver, @impact_studio_page_url)
        @impact_studio_page.verify_network_interactions(@driver, student1_student3_expected, student_3)
      end

      it 'the whiteboard asset owners acquire a "view" and "remix" connection to the remixer' do
        @impact_studio_page.search_for_user student_2
        @impact_studio_page.verify_network_interactions(@driver, student2_student1_expected, student_1)
      end
    end
  end

  context 'when an asset is liked' do

    before(:all) do
      @canvas.masquerade_as(student_2, @course)
      @asset_library_page.load_asset_detail(@driver, @asset_library_page_url, asset)
      student2_student1_expected[:views][:exports] += 1
      student1_student2_expected[:views][:imports] += 1

      @asset_library_page.like_asset asset
      student2_student1_expected[:likes][:exports] += 1
      student1_student2_expected[:likes][:imports] += 1
    end

    it 'the liker acquires a "view" and "like" connection to the asset owner' do
      @impact_studio_page.load_page(@driver, @impact_studio_page_url)
      @impact_studio_page.verify_network_interactions(@driver, student2_student1_expected, student_1)
    end

    it 'the asset owner acquires a "view" and "like" connection to the liker' do
      @impact_studio_page.search_for_user student_1
      @impact_studio_page.verify_network_interactions(@driver, student1_student2_expected, student_2)
    end
  end

  context 'when an asset is unliked' do

    before(:all) do
      @canvas.masquerade_as(student_2, @course)
      @asset_library_page.load_asset_detail(@driver, @asset_library_page_url, asset)
      student2_student1_expected[:views][:exports] += 1
      student1_student2_expected[:views][:imports] += 1

      @asset_library_page.unlike_asset asset
      student2_student1_expected[:likes][:exports] -= 1
      student1_student2_expected[:likes][:imports] -= 1
    end

    it 'the un-liker acquires a "view" connection and loses a "like" connection to the asset owner' do
      @impact_studio_page.load_page(@driver, @impact_studio_page_url)
      @impact_studio_page.verify_network_interactions(@driver, student2_student1_expected, student_1)
    end

    it 'the asset owner acquires a "view" connection and loses a "like connection" to the un-liker' do
      @impact_studio_page.search_for_user student_1
      @impact_studio_page.verify_network_interactions(@driver, student1_student2_expected, student_2)
    end
  end

  context 'when an asset receives a comment' do

    before(:all) do
      @canvas.masquerade_as(student_2, @course)
      @asset_library_page.load_asset_detail(@driver, @asset_library_page_url, asset)
      student2_student1_expected[:views][:exports] += 1
      student1_student2_expected[:views][:imports] += 1

      @asset_library_page.add_comment(asset, comment)
      student2_student1_expected[:comments][:exports] += 1
      student1_student2_expected[:comments][:imports] += 1
    end

    it 'the commenter acquires a "view" and "comment" connection to the asset owner' do
      @impact_studio_page.load_page(@driver, @impact_studio_page_url)
      @impact_studio_page.verify_network_interactions(@driver, student2_student1_expected, student_1)
    end

    it 'the asset owner acquires a "view" and "comment" connection to the commenter' do
      @impact_studio_page.search_for_user student_1
      @impact_studio_page.verify_network_interactions(@driver, student1_student2_expected, student_2)
    end
  end

  context 'when an asset comment receives a reply' do

    before(:all) do
      @canvas.masquerade_as(student_3, @course)
      @asset_library_page.load_asset_detail(@driver, @asset_library_page_url, asset)
      student3_student1_expected[:views][:exports] += 1
      student1_student3_expected[:views][:imports] += 1

      @asset_library_page.reply_to_comment(asset, comment, reply)
      student3_student1_expected[:comments][:exports] += 1
      student1_student3_expected[:comments][:imports] += 1
      student3_student2_expected[:comments][:exports] += 1
      student2_student3_expected[:comments][:imports] += 1
    end

    it 'the replier acquires a "view" and "comment" connection to the asset owner' do
      @impact_studio_page.load_page(@driver, @impact_studio_page_url)
      @impact_studio_page.verify_network_interactions(@driver, student3_student1_expected, student_1)
    end

    it 'the replier acquires a "comment" connection to the commenter' do
      @impact_studio_page.verify_network_interactions(@driver, student3_student2_expected, student_2)
    end

    it 'the asset owner acquires a "view" and "comment" connection to the replier' do
      @impact_studio_page.search_for_user student_1
      @impact_studio_page.verify_network_interactions(@driver, student1_student3_expected, student_3)
    end

    it 'the commenter acquires a "comment" connection to the replier' do
      @impact_studio_page.search_for_user student_2
      @impact_studio_page.verify_network_interactions(@driver, student2_student3_expected, student_3)
    end
  end

  context 'when an asset comment reply is deleted' do

    before(:all) do
      @canvas.masquerade_as(student_3, @course)
      @asset_library_page.load_asset_detail(@driver, @asset_library_page_url, asset)
      student3_student1_expected[:views][:exports] += 1
      student1_student3_expected[:views][:imports] += 1

      @asset_library_page.delete_comment(asset, reply)
      student3_student1_expected[:comments][:exports] -= 1
      student1_student3_expected[:comments][:imports] -= 1
      student3_student2_expected[:comments][:exports] -= 1
      student2_student3_expected[:comments][:imports] -= 1
    end

    it 'the replier acquires a "view" connection and loses a "comment" connection to the asset owner' do
      @impact_studio_page.load_page(@driver, @impact_studio_page_url)
      @impact_studio_page.verify_network_interactions(@driver, student3_student1_expected, student_1)
    end

    it 'the replier loses a "comment" connection to the commenter' do
      @impact_studio_page.verify_network_interactions(@driver, student3_student2_expected, student_2)
    end

    it 'the asset owner acquires a "view" connection and loses a "comment" connection to the replier' do
      @impact_studio_page.search_for_user student_1
      @impact_studio_page.verify_network_interactions(@driver, student1_student3_expected, student_3)
    end

    it 'the commenter loses a "comment" connection to the replier' do
      @impact_studio_page.search_for_user student_2
      @impact_studio_page.verify_network_interactions(@driver, student2_student3_expected, student_3)
    end
  end

  context 'when an asset is pinned' do

    before(:all) do
      @canvas.masquerade_as(student_2, @course)
      @asset_library_page.load_asset_detail(@driver, @asset_library_page_url, asset)
        student2_student1_expected[:views][:exports] += 1
        student1_student2_expected[:views][:imports] += 1

      @asset_library_page.pin_detail_view_asset asset
      student2_student1_expected[:pins][:exports] += 1
      student1_student2_expected[:pins][:imports] += 1
    end

    it 'the pinner acquires a "view" and "pin" connection to the asset owner' do
      @impact_studio_page.load_page(@driver, @impact_studio_page_url)
      @impact_studio_page.verify_network_interactions(@driver, student2_student1_expected, student_1)
    end

    it 'the owner acquires a "view" and "pin" connection to the pinner' do
      @impact_studio_page.search_for_user student_1
      @impact_studio_page.verify_network_interactions(@driver, student1_student2_expected, student_2)
    end
  end

  context 'when an asset is unpinned' do

    before(:all) do
      @canvas.masquerade_as(student_2, @course)
      @asset_library_page.load_asset_detail(@driver, @asset_library_page_url, asset)
      student2_student1_expected[:views][:exports] += 1
      student1_student2_expected[:views][:imports] += 1

      @asset_library_page.unpin_detail_view_asset asset
    end

    it 'the un-pinner acquires a "view" connection and retains a "pin" connection to the asset owner' do
      @impact_studio_page.load_page(@driver, @impact_studio_page_url)
      @impact_studio_page.verify_network_interactions(@driver, student2_student1_expected, student_1)
    end

    it 'the asset owner acquires a "view" connection and retains a "pin" connection to the un-pinner' do
      @impact_studio_page.search_for_user student_1
      @impact_studio_page.verify_network_interactions(@driver, student1_student2_expected, student_2)
    end
  end

  context 'when an asset is re-pinned' do

    before(:all) do
      @canvas.masquerade_as(student_2, @course)
      @asset_library_page.load_asset_detail(@driver, @asset_library_page_url, asset)
      student2_student1_expected[:views][:exports] += 1
      student1_student2_expected[:views][:imports] += 1

      @asset_library_page.pin_detail_view_asset asset
    end

    it 'the re-pinner acquires a "view" connection but not a "pin" connection to the asset owner' do
      @impact_studio_page.load_page(@driver, @impact_studio_page_url)
      @impact_studio_page.verify_network_interactions(@driver, student2_student1_expected, student_1)
    end

    it 'the asset owner acquires a "view" connection but not a "pin" connection to the re-pinner' do
      @impact_studio_page.search_for_user student_1
      @impact_studio_page.verify_network_interactions(@driver, student1_student2_expected, student_2)
    end
  end

  context 'when an asset is deleted' do

    before(:all) do
      @canvas.masquerade_as(teacher, @course)
      @asset_library_page.load_asset_detail(@driver, @asset_library_page_url, asset)
      @asset_library_page.delete_asset asset
      student3_student1_expected[:use_assets][:exports] -= 1
      student1_student3_expected[:use_assets][:imports] -= 1
      student2_student1_expected[:comments][:exports] -= 1
      student1_student2_expected[:comments][:imports] -= 1
      student2_student1_expected[:pins][:exports] -= 1
      student1_student2_expected[:pins][:imports] -= 1
      student2_student1_expected[:views][:exports] -= 6
      student1_student2_expected[:views][:imports] -= 6
      student3_student1_expected[:views][:exports] -= 2
      student1_student3_expected[:views][:imports] -= 2
    end

    it 'removes all connections the deleter has to the asset owner through that asset' do
      @impact_studio_page.load_page(@driver, @impact_studio_page_url)
      @impact_studio_page.search_for_user student_3
      @impact_studio_page.verify_network_interactions(@driver, student3_student1_expected, student_1)
    end

    it 'removes all connections another user has to the asset owner through that asset' do
      @impact_studio_page.search_for_user student_2
      @impact_studio_page.verify_network_interactions(@driver, student2_student1_expected, student_1)
    end

    it 'removes all connections the asset owner has to another users through that asset' do
      @impact_studio_page.search_for_user student_1
      @impact_studio_page.verify_network_interactions(@driver, student1_student3_expected, student_3)
      @impact_studio_page.verify_network_interactions(@driver, student1_student2_expected, student_2)
    end
  end

  # TODO - discussion reply

end
