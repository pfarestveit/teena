require_relative '../../util/spec_helper'

describe 'Impact Studio Activity Network' do

  test = SquiggyTestConfig.new 'studio_network'

  student1_student2_expected, student1_student3_expected,
    student2_student1_expected, student2_student3_expected,
    student3_student1_expected, student3_student2_expected = nil

  before(:all) do

    @driver = Utils.launch_browser
    @canvas = Page::CanvasAnnounceDiscussPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library_page = SquiggyAssetLibraryDetailPage.new @driver
    @impact_studio_page = SquiggyImpactStudioPage.new @driver
    @whiteboards_page = SquiggyWhiteboardsPage.new @driver
    @engagement_index_page = SquiggyEngagementIndexPage.new @driver

    @teacher = test.teachers[0]
    @student_1 = test.students[0]
    @student_2 = test.students[1]
    @student_3 = test.students[2]

    @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course test
    @engagement_index_page.wait_for_new_user_sync(test, test.course.roster)

    # Initialize expected user interactions
    student1_student2_expected = @impact_studio_page.init_user_interactions
    student1_student3_expected = @impact_studio_page.init_user_interactions
    student2_student3_expected = @impact_studio_page.init_user_interactions
    student2_student1_expected = @impact_studio_page.init_user_interactions
    student3_student1_expected = @impact_studio_page.init_user_interactions
    student3_student2_expected = @impact_studio_page.init_user_interactions

    @canvas.masquerade_as(@student_1, @course)
    @asset_library_page.load_page test
    @asset = @student_1.assets.first
    @asset.file_name ? @asset_library_page.upload_file_asset(@asset) : @asset_library_page.add_site(@asset)

    @canvas.masquerade_as(@student_3, @course)
    @whiteboards_page.load_page test
    @whiteboard = SquiggyWhiteboard.new owner: @student_3,
                                        title: "Whiteboard #{test.id}",
                                        collaborators: [@student_2]
    @whiteboards_page.create_whiteboard @whiteboard

    @discussion = Discussion.new "Discussion #{test.id}"
    @canvas.create_course_discussion(@course, @discussion)
    @canvas.add_reply(@discussion, nil, 'Discussion topic entry')

    @comment = SquiggyComment.new asset: @asset,
                                  body: "Comment #{test.id}",
                                  user: @student_2
    @reply = SquiggyComment.new asset: @asset,
                                body: "Reply #{test.id}",
                                user: @teacher
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when an asset is added to a whiteboard' do

    before(:all) do
      @canvas.masquerade_as(@student_3, test.course)
      @whiteboards_page.load_page test
      @whiteboards_page.open_whiteboard @whiteboard
      @whiteboards_page.add_existing_assets [@asset]
      @whiteboards_page.wait_until(Utils.short_wait) do
        @whiteboards_page.open_original_asset_link_element.attribute('href').include? @asset.id
      end
      @whiteboards_page.close_whiteboard
      student3_student1_expected[:use_assets][:exports] += 1
      student1_student3_expected[:use_assets][:imports] += 1
    end

    it 'the asset user acquires a "use asset" connection to the asset owner' do
      @impact_studio_page.load_page test
      @impact_studio_page.verify_network_interactions(student3_student1_expected, @student_1)
    end

    it 'the asset owner acquires a "use asset" connection to the asset user' do
      @impact_studio_page.search_for_user @student_1
      @impact_studio_page.verify_network_interactions(student1_student3_expected, @student_3)
    end
  end

  context 'when a whiteboard is exported to the asset library' do

    before(:all) do
      @canvas.masquerade_as(@student_2, test.course)
      @whiteboards_page.load_page test
      @whiteboards_page.open_whiteboard @whiteboard
      @whiteboards_page.export_to_asset_library @whiteboard
      @whiteboards_page.close_whiteboard
      student2_student3_expected[:co_creations][:exports] += 1
      student2_student3_expected[:co_creations][:imports] += 1
      student3_student2_expected[:co_creations][:exports] += 1
      student3_student2_expected[:co_creations][:imports] += 1
    end

    it 'the exporter acquires a "co-creation" connection to the whiteboard collaborator' do
      @impact_studio_page.load_page test
      @impact_studio_page.verify_network_interactions(student2_student3_expected, @student_3)
    end

    it 'a collaborator acquires a "co-creation" connection to the exporter' do
      @impact_studio_page.search_for_user @student_3
      @impact_studio_page.verify_network_interactions(student3_student2_expected, @student_2)
    end

    context 'and then remixed' do

      before(:all) do
        @canvas.masquerade_as(@student_1, test.course)
        @asset_library_page.load_asset_detail(test, @whiteboard.asset_exports[0])
        student1_student2_expected[:views][:exports] += 1
        student1_student3_expected[:views][:exports] += 1
        student2_student1_expected[:views][:imports] += 1
        student3_student1_expected[:views][:imports] += 1

        @asset_library_page.remix @whiteboard.title
        student1_student2_expected[:remixes][:exports] += 1
        student1_student3_expected[:remixes][:exports] += 1
        student2_student1_expected[:remixes][:imports] += 1
        student3_student1_expected[:remixes][:imports] += 1
      end

      it 'the remixer acquires a "view" and "remix" connection to the whiteboard asset owners' do
        @impact_studio_page.load_page test
        @impact_studio_page.verify_network_interactions(student1_student3_expected, @student_3)
      end

      it 'the whiteboard asset owners acquire a "view" and "remix" connection to the remixer' do
        @impact_studio_page.search_for_user @student_2
        @impact_studio_page.verify_network_interactions(student2_student1_expected, @student_1)
      end
    end
  end

  context 'when an asset is liked' do

    before(:all) do
      @canvas.masquerade_as(@student_2, test.course)
      @asset_library_page.load_asset_detail(test, @asset)
      student2_student1_expected[:views][:exports] += 1
      student1_student2_expected[:views][:imports] += 1

      @asset_library_page.click_like_button
      student2_student1_expected[:likes][:exports] += 1
      student1_student2_expected[:likes][:imports] += 1
    end

    it 'the liker acquires a "view" and "like" connection to the asset owner' do
      @impact_studio_page.load_page test
      @impact_studio_page.verify_network_interactions(student2_student1_expected, @student_1)
    end

    it 'the asset owner acquires a "view" and "like" connection to the liker' do
      @impact_studio_page.search_for_user @student_1
      @impact_studio_page.verify_network_interactions(student1_student2_expected, @student_2)
    end
  end

  context 'when an asset is unliked' do

    before(:all) do
      @canvas.masquerade_as(@student_2, test.course)
      @asset_library_page.load_asset_detail(test, @asset)
      student2_student1_expected[:views][:exports] += 1
      student1_student2_expected[:views][:imports] += 1

      @asset_library_page.click_like_button
      student2_student1_expected[:likes][:exports] -= 1
      student1_student2_expected[:likes][:imports] -= 1
    end

    it 'the un-liker acquires a "view" connection and loses a "like" connection to the asset owner' do
      @impact_studio_page.load_page test
      @impact_studio_page.verify_network_interactions(student2_student1_expected, @student_1)
    end

    it 'the asset owner acquires a "view" connection and loses a "like connection" to the un-liker' do
      @impact_studio_page.search_for_user @student_1
      @impact_studio_page.verify_network_interactions(student1_student2_expected, @student_2)
    end
  end

  context 'when an asset receives a comment' do

    before(:all) do
      @canvas.masquerade_as(@student_2, test.course)
      @asset_library_page.load_asset_detail(test, @asset)
      student2_student1_expected[:views][:exports] += 1
      student1_student2_expected[:views][:imports] += 1

      @asset_library_page.add_comment @comment
      student2_student1_expected[:comments][:exports] += 1
      student1_student2_expected[:comments][:imports] += 1
    end

    it 'the commenter acquires a "view" and "comment" connection to the asset owner' do
      @impact_studio_page.load_page test
      @impact_studio_page.verify_network_interactions(student2_student1_expected, @student_1)
    end

    it 'the asset owner acquires a "view" and "comment" connection to the commenter' do
      @impact_studio_page.search_for_user @student_1
      @impact_studio_page.verify_network_interactions(student1_student2_expected, @student_2)
    end
  end

  context 'when an asset comment receives a reply' do

    before(:all) do
      @canvas.masquerade_as(@student_3, test.course)
      @asset_library_page.load_asset_detail(test, @asset)
      student3_student1_expected[:views][:exports] += 1
      student1_student3_expected[:views][:imports] += 1

      @asset_library_page.reply_to_comment(@comment, @reply)
      student3_student1_expected[:comments][:exports] += 1
      student1_student3_expected[:comments][:imports] += 1
      student3_student2_expected[:comments][:exports] += 1
      student2_student3_expected[:comments][:imports] += 1
    end

    it 'the replier acquires a "view" and "comment" connection to the asset owner' do
      @impact_studio_page.load_page test
      @impact_studio_page.verify_network_interactions(student3_student1_expected, @student_1)
    end

    it 'the replier acquires a "comment" connection to the commenter' do
      @impact_studio_page.verify_network_interactions(student3_student2_expected, @student_2)
    end

    it 'the asset owner acquires a "view" and "comment" connection to the replier' do
      @impact_studio_page.search_for_user @student_1
      @impact_studio_page.verify_network_interactions(student1_student3_expected, @student_3)
    end

    it 'the commenter acquires a "comment" connection to the replier' do
      @impact_studio_page.search_for_user @student_2
      @impact_studio_page.verify_network_interactions(student2_student3_expected, @student_3)
    end
  end

  context 'when an asset comment reply is deleted' do

    before(:all) do
      @canvas.masquerade_as(@student_3, test.course)
      @asset_library_page.load_asset_detail(test, @asset)
      student3_student1_expected[:views][:exports] += 1
      student1_student3_expected[:views][:imports] += 1

      @asset_library_page.delete_comment @reply
      student3_student1_expected[:comments][:exports] -= 1
      student1_student3_expected[:comments][:imports] -= 1
      student3_student2_expected[:comments][:exports] -= 1
      student2_student3_expected[:comments][:imports] -= 1
    end

    it 'the replier acquires a "view" connection and loses a "comment" connection to the asset owner' do
      @impact_studio_page.load_page test
      @impact_studio_page.verify_network_interactions(student3_student1_expected, @student_1)
    end

    it 'the replier loses a "comment" connection to the commenter' do
      @impact_studio_page.verify_network_interactions(student3_student2_expected, @student_2)
    end

    it 'the asset owner acquires a "view" connection and loses a "comment" connection to the replier' do
      @impact_studio_page.search_for_user @student_1
      @impact_studio_page.verify_network_interactions(student1_student3_expected, @student_3)
    end

    it 'the commenter loses a "comment" connection to the replier' do
      @impact_studio_page.search_for_user @student_2
      @impact_studio_page.verify_network_interactions(student2_student3_expected, @student_3)
    end
  end

  context 'when an asset is deleted' do

    before(:all) do
      @canvas.masquerade_as(@teacher, test.course)
      @asset_library_page.load_asset_detail(test, @asset)
      @asset_library_page.delete_asset @asset
      student3_student1_expected[:use_assets][:exports] -= 1
      student1_student3_expected[:use_assets][:imports] -= 1
      student2_student1_expected[:comments][:exports] -= 1
      student1_student2_expected[:comments][:imports] -= 1
      student2_student1_expected[:views][:exports] -= 3
      student1_student2_expected[:views][:imports] -= 3
      student3_student1_expected[:views][:exports] -= 2
      student1_student3_expected[:views][:imports] -= 2
    end

    it 'removes all connections the deleter has to the asset owner through that asset' do
      @impact_studio_page.load_page test
      @impact_studio_page.search_for_user @student_3
      @impact_studio_page.verify_network_interactions(student3_student1_expected, @student_1)
    end

    it 'removes all connections another user has to the asset owner through that asset' do
      @impact_studio_page.search_for_user @student_2
      @impact_studio_page.verify_network_interactions(student2_student1_expected, @student_1)
    end

    it 'removes all connections the asset owner has to another users through that asset' do
      @impact_studio_page.search_for_user @student_1
      @impact_studio_page.verify_network_interactions(student1_student3_expected, @student_3)
      @impact_studio_page.verify_network_interactions(student1_student2_expected, @student_2)
    end
  end
end
