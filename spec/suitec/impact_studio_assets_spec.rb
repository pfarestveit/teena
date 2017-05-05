require_relative '../../util/spec_helper'

describe 'The Impact Studio', order: :defined do

  include Logging
  course_id = ENV['COURSE_ID']
  test_id = Utils.get_test_id

  # Get test users
  user_test_data = Utils.load_test_users.select { |data| data['tests']['impact_studio_assets'] }
  users = user_test_data.map { |data| User.new(data) if %w(Teacher Student).include? data['role'] }
  teacher = users.find { |user| user.role == 'Teacher' }
  students = users.select { |user| user.role == 'Student' }
  student_1 = students[0]
  student_2 = students[1]

  # Get test assets
  all_assets = []
  all_assets << (asset_1 = Asset.new(student_1.assets.find { |a| a['type'] == 'Link' }))
  all_assets << (asset_2 = Asset.new((student_1.assets.select { |a| a['type'] == 'File' })[0]))
  all_assets << (asset_3 = Asset.new((student_1.assets.select { |a| a['type'] == 'File' })[1]))
  all_assets << (asset_4 = Asset.new({}))
  all_assets << (asset_5 = Asset.new(teacher.assets.find { |a| a['type'] == 'File' }))
  all_assets << (asset_6 = Asset.new(student_2.assets.find { |a| a['type'] == 'File' }))
  all_assets << (asset_7 = Asset.new(student_2.assets.find { |a| a['type'] == 'Link' }))
  whiteboard = Whiteboard.new({owner: student_1, title: "Whiteboard #{test_id}", collaborators: [student_2]})

  student_1_assets = [asset_4, asset_3, asset_2, asset_1]
  student_2_assets = [asset_7, asset_6, asset_4]
  teacher_assets = [asset_5]

  before(:all) do
    @course = Course.new({})
    @course.site_id = course_id

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryPage.new @driver
    @engagement_index = Page::SuiteCPages::EngagementIndexPage.new @driver
    @impact_studio = Page::SuiteCPages::ImpactStudioPage.new @driver
    @whiteboards = Page::SuiteCPages::WhiteboardsPage.new @driver

    # Create course site if necessary
    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, users, test_id,
                                       [SuiteCTools::ASSET_LIBRARY, SuiteCTools::ENGAGEMENT_INDEX, SuiteCTools::IMPACT_STUDIO, SuiteCTools::WHITEBOARDS])
    @asset_library_url = @canvas.click_tool_link(@driver, SuiteCTools::ASSET_LIBRARY)
    @engagement_index_url = @canvas.click_tool_link(@driver, SuiteCTools::ENGAGEMENT_INDEX)
    @impact_studio_url = @canvas.click_tool_link(@driver, SuiteCTools::IMPACT_STUDIO)
    @whiteboards_url = @canvas.click_tool_link(@driver, SuiteCTools::WHITEBOARDS)

    [student_1, student_2].each do |student|
      @canvas.masquerade_as(@driver, student, @course)
      @engagement_index.load_page(@driver, @engagement_index_url)
      @engagement_index.share_score
    end
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when a course has no assets' do

    context 'and a user views its own profile' do

      before(:all) do
        @canvas.masquerade_as(@driver, student_1, @course)
        @impact_studio.load_page(@driver, @impact_studio_url)
      end

      it('shows a "no assets" message under My Assets') { @impact_studio.no_my_assets_msg_element.when_visible Utils.short_wait }
      it('shows a "no assets" message under Everyone\'s Assets') { @impact_studio.no_everyone_assets_msg_element.when_visible Utils.short_wait }
      it('offers a Bookmarklet link under My Assets') { expect(@impact_studio.bookmarklet_link?).to be true }
      it('offers a link to create a new Link asset') { expect(@impact_studio.add_site_link?).to be true }
      it('offers a link to create a new File asset') { expect(@impact_studio.upload_link?).to be true }
    end

    context 'and a user views another user\'s profile' do

      before(:all) do
        @engagement_index.load_page(@driver, @engagement_index_url)
        @engagement_index.click_user_dashboard_link(@driver, student_2)
      end

      it('shows a "no assets" message under My Assets') { @impact_studio.no_my_assets_msg_element.when_visible Utils.short_wait }
      it('shows no Everyone\'s Assets UI') { expect(@impact_studio.everyone_assets_heading?).to be false }
      it('offers no Bookmarklet link under My Assets') { expect(@impact_studio.bookmarklet_link?).to be false }
      it('offers no Add Link link under My Assets') { expect(@impact_studio.add_site_link?).to be false }
      it('offers no Upload link under My Assets') { expect(@impact_studio.upload_link?).to be false }
    end
  end

  context 'when a course has assets with no impact' do

    before(:all) do
      # Student 1 add asset 1 via impact studio
      @canvas.masquerade_as(@driver, student_1, @course)
      @impact_studio.load_page(@driver, @impact_studio_url)
      @impact_studio.add_site(@driver, asset_1)
      logger.debug "Asset 1 ID is #{asset_1.id}"

      # Student 1 add asset 2 to whiteboard, exclude from asset library
      @whiteboards.load_page(@driver, @whiteboards_url)
      @whiteboards.create_and_open_whiteboard(@driver, whiteboard)
      @whiteboards.add_asset_exclude_from_library asset_2
      @whiteboards.open_original_asset_link_element.when_visible Utils.long_wait
      logger.debug "Asset 2 ID is #{asset_2.id = @whiteboards.added_asset_id}"
      asset_2.visible = false

      # Student 1 add asset 3 to a whiteboard and include it in the asset library
      @whiteboards.add_asset_include_in_library asset_3
      @whiteboards.open_original_asset_link_element.when_visible Utils.long_wait
      @whiteboards.close_whiteboard @driver
      @asset_library.load_page(@driver, @asset_library_url)
      logger.debug "Asset 3 ID is #{asset_3.id = @asset_library.list_view_asset_ids.first}"
      logger.debug "Asset 3 impact score is #{asset_3.impact_score}"

      # Student 1 export whiteboard to create asset 4
      @whiteboards.load_page(@driver, @whiteboards_url)
      @whiteboards.open_whiteboard(@driver, whiteboard)
      @whiteboards.export_to_asset_library whiteboard
      @whiteboards.close_whiteboard @driver
      @asset_library.load_page(@driver, @asset_library_url)
      logger.debug "Asset 4 ID is #{asset_4.id = @asset_library.list_view_asset_ids.first}"
      asset_4.type = 'Whiteboard'
      asset_4.title = whiteboard.title

      # Teacher add asset 5 via impact studio
      @canvas.masquerade_as(@driver, teacher, @course)
      @impact_studio.load_page(@driver, @impact_studio_url)
      @impact_studio.add_file(@driver, asset_5)
      logger.debug "Asset 5 ID is #{asset_5.id = @asset_library.list_view_asset_ids.first}"

      # Student 2 add asset 6 via asset library
      @canvas.masquerade_as(@driver, student_2, @course)
      @asset_library.load_page(@driver, @asset_library_url)
      @asset_library.upload_file_to_library asset_6
      logger.debug "Asset 6 ID is #{asset_6.id}"

      # Student 2 add asset 7 via asset library and then delete it
      @asset_library.add_site asset_7
      logger.debug "Asset 7 ID is #{asset_7.id}"
      @asset_library.load_asset_detail(@driver, @asset_library_url, asset_7)
      @asset_library.delete_asset
      asset_7.visible = false

      logger.info "Expected asset scores: #{@impact_studio.asset_scores all_assets}"
    end

    context 'and a user views its own profile' do

      before(:all) do
        @canvas.masquerade_as(@driver, student_1, @course)
        @impact_studio.load_page(@driver, @impact_studio_url)
      end

      it('shows the user\'s non-hidden assets under My Assets > Recent') { @impact_studio.verify_my_recent_assets student_1_assets }

      it 'allows the user to click an asset in My Assets > Recent to view its detail' do
        @impact_studio.click_my_asset_link(@driver, asset_1)
        @asset_library.wait_for_asset_detail asset_1
      end

      it 'allows the user to return to its own Impact Studio profile from an asset\'s detail' do
        @asset_library.go_back_to_impact_studio @driver
        @impact_studio.verify_my_recent_assets student_1_assets
      end

      it('does not show the user\'s assets under My Assets > Most Impactful') { @impact_studio.verify_my_impactful_assets student_1_assets }
      it('does not show any assets under Community Assets > Trending') { @impact_studio.verify_all_trending_assets all_assets }
      it('does not show any assets under Community Assets > Most Impactful') { @impact_studio.verify_all_impactful_assets all_assets }
    end

    context 'and a user views another user\'s profile' do

      before(:all) do
        @engagement_index.load_page(@driver, @engagement_index_url)
        @engagement_index.click_user_dashboard_link(@driver, student_2)
      end

      it('shows the other user\'s non-hidden assets under Activities > Recent') { @impact_studio.verify_your_recent_assets student_2_assets }
      it('does not show the other user\'s assets under Activities > Most Impactful') { @impact_studio.verify_your_impactful_assets student_2_assets }
      it('shows no Everyone\'s Assets UI') { expect(@impact_studio.everyone_assets_heading?).to be false }
    end
  end

  context 'when a course has assets with impact' do

    context '"add asset to whiteboard"' do

      before(:all) do
        # One student uses the other's asset on the shared whiteboard
        @canvas.masquerade_as(@driver, student_2, @course)
        @whiteboards.load_page(@driver, @whiteboards_url)
        @whiteboards.open_whiteboard(@driver, whiteboard)
        @whiteboards.add_existing_assets [asset_1]
        @whiteboards.open_original_asset_link_element.when_visible Utils.medium_wait
        @whiteboards.close_whiteboard @driver
        asset_1.impact_score += Activities::ADD_ASSET_TO_WHITEBOARD.impact_points
        logger.info "Expected asset scores: #{@impact_studio.asset_scores all_assets}"
      end

      context 'and the asset owner views its own profile' do

        before(:all) do
          @canvas.masquerade_as(@driver, student_1, @course)
          @impact_studio.load_page(@driver, @impact_studio_url)
        end

        it('shows the user\'s non-hidden assets under My Assets > Recent') { @impact_studio.verify_my_recent_assets student_1_assets }
        it('shows the impactful asset under My Assets > Most Impactful') { @impact_studio.verify_my_impactful_assets student_1_assets }
        it('shows the impactful asset under Community Assets > Trending') { @impact_studio.verify_all_trending_assets all_assets }
        it('shows the impactful asset under Community Assets > Most Impactful') { @impact_studio.verify_all_impactful_assets all_assets }
      end

      context 'and the asset owner views another user\'s profile' do

        before(:all) do
          @engagement_index.load_page(@driver, @engagement_index_url)
          @engagement_index.click_user_dashboard_link(@driver, student_2)
        end

        it('shows no Everyone\'s Assets UI') { expect(@impact_studio.everyone_assets_heading?).to be false }
      end
    end

    context 'with "view asset" impact' do

      before(:all) do
        # Teacher views the student's asset
        @canvas.masquerade_as(@driver, teacher, @course)
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset_3)
        asset_3.impact_score += Activities::VIEW_ASSET.impact_points
        logger.info "Expected asset scores: #{@impact_studio.asset_scores all_assets}"
      end

      context 'and the asset owner views its own profile' do

        before(:all) do
          @canvas.masquerade_as(@driver, student_1, @course)
          @impact_studio.load_page(@driver, @impact_studio_url)
        end

        it('shows the user\'s non-hidden assets under My Assets > Recent') { @impact_studio.verify_my_recent_assets student_1_assets }
        it('shows the impactful asset under My Assets > Most Impactful') { @impact_studio.verify_my_impactful_assets student_1_assets }
        it('shows the impactful asset under Community Assets > Trending') { @impact_studio.verify_all_trending_assets all_assets }
        it('shows the impactful asset under Community Assets > Most Impactful') { @impact_studio.verify_all_impactful_assets all_assets }
      end
    end

    context 'with "comment" impact' do

      before(:all) do
        # Teacher comments twice on the student's asset
        @canvas.masquerade_as(@driver, teacher, @course)
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset_6)
        asset_6.impact_score += Activities::VIEW_ASSET.impact_points
        @asset_library.add_comment 'This is a comment from Teacher to Student 2'
        @asset_library.wait_until(Utils.short_wait) { @asset_library.asset_detail_comment_count == '1' }
        asset_6.impact_score += Activities::COMMENT.impact_points
        @asset_library.reply_to_comment(0, 'This is another comment from Teacher to Student 2')
        @asset_library.wait_until(Utils.short_wait) { @asset_library.asset_detail_comment_count == '2' }
        asset_6.impact_score += Activities::COMMENT.impact_points
        logger.info "Expected asset scores: #{@impact_studio.asset_scores all_assets}"
      end

      context 'and the asset owner views its own profile' do

        before(:all) do
          @canvas.masquerade_as(@driver, student_2, @course)
          @impact_studio.load_page(@driver, @impact_studio_url)
        end

        it('shows the user\'s non-hidden assets under My Assets > Recent') { @impact_studio.verify_my_recent_assets student_2_assets }
        it('shows the impactful asset under My Assets > Most Impactful') { @impact_studio.verify_my_impactful_assets student_2_assets }
        it('shows the impactful asset under Community Assets > Trending') { @impact_studio.verify_all_trending_assets all_assets }
        it('shows the impactful asset under Community Assets > Most Impactful') { @impact_studio.verify_all_impactful_assets all_assets }
      end
    end

    context 'with "like" impact' do

      before(:all) do
        # One student likes the teacher's asset
        @canvas.masquerade_as(@driver, student_1, @course)
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset_5)
        asset_5.impact_score += Activities::VIEW_ASSET.impact_points
        @asset_library.toggle_detail_view_item_like
        @asset_library.wait_until { @asset_library.detail_view_asset_likes_count == '1' }
        asset_5.impact_score += Activities::LIKE.impact_points
        logger.info "Expected asset scores: #{@impact_studio.asset_scores all_assets}"
      end

      context 'and the asset owner views its own profile' do

        before(:all) do
          @canvas.masquerade_as(@driver, teacher, @course)
          @impact_studio.load_page(@driver, @impact_studio_url)
        end

        it('shows the user\'s non-hidden assets under My Assets > Recent') { @impact_studio.verify_my_recent_assets student_2_assets }
        it('shows the impactful asset under My Assets > Most Impactful') { @impact_studio.verify_my_impactful_assets student_2_assets }
        it('shows the impactful asset under Community Assets > Trending') { @impact_studio.verify_all_trending_assets all_assets }
        it('shows the impactful asset under Community Assets > Most Impactful') { @impact_studio.verify_all_impactful_assets all_assets }
      end
    end

    context 'with "remix whiteboard" impact' do

      before(:all) do
        # Teacher remixes the students' whiteboard
        @canvas.masquerade_as(@driver, teacher, @course)
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset_4)
        asset_4.impact_score += Activities::VIEW_ASSET.impact_points
        @asset_library.click_remix
        asset_4.impact_score += Activities::REMIX_WHITEBOARD.impact_points
        logger.info "Expected asset scores: #{@impact_studio.asset_scores all_assets}"
      end

      context 'and one whiteboard asset owner views its own profile' do

        before(:all) do
          @canvas.masquerade_as(@driver, student_1, @course)
          @impact_studio.load_page(@driver, @impact_studio_url)
        end

        it('shows the user\'s non-hidden assets under My Assets > Recent') { @impact_studio.verify_my_recent_assets student_1_assets }
        it('shows the impactful asset under My Assets > Most Impactful') { @impact_studio.verify_my_impactful_assets student_1_assets }
        it('shows the impactful asset under Community Assets > Trending') { @impact_studio.verify_all_trending_assets all_assets }
        it('shows the impactful asset under Community Assets > Most Impactful') { @impact_studio.verify_all_impactful_assets all_assets }
      end

      context 'and another whiteboard asset owner views its own profile' do

        before(:all) do
          @canvas.masquerade_as(@driver, student_2, @course)
          @impact_studio.load_page(@driver, @impact_studio_url)
        end

        it('shows the user\'s non-hidden assets under My Assets > Recent') { @impact_studio.verify_my_recent_assets student_2_assets }
        it('shows the impactful asset under My Assets > Most Impactful') { @impact_studio.verify_my_impactful_assets student_2_assets }
        it('shows the impactful asset under Community Assets > Trending') { @impact_studio.verify_all_trending_assets all_assets }
        it('shows the impactful asset under Community Assets > Most Impactful') { @impact_studio.verify_all_impactful_assets all_assets }
      end
    end

    # TODO context 'with "Peer Mentions Me" impact'
    # TODO context 'with "Peer Cites my Asset" impact'
    # TODO context 'with "Peer Pins my Asset impact"'

  end

  context 'when assets impact their owners' do

    # TODO - users perform impactful actions on themselves, which are therefore not impactful

    it 'does not show viewing impact' do
      # view own asset
    end

    it 'does not show commenting impact' do
      # comment on own asset
    end

    it 'does not show remixing impact' do
      # remix own whiteboard asset
    end
  end

  context 'when impacts are reversed' do

    # TODO - users remove their impactful actions, which are therefore no longer impactful

    it 'removes commenting impact' do
      # remove comment
    end

    it 'removes liking impact' do
      # un-like
    end

    # TODO it 'removes mentioning impact'
    # TODO it 'removes citation impact'
    # TODO it 'removes pinning impact'

  end

  context 'when assets are deleted' do

    # TODO - delete an impactful asset

  end
end
