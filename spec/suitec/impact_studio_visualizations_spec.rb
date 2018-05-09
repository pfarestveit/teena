require_relative '../../util/spec_helper'

describe 'The Impact Studio', order: :defined do

  include Logging
  test_id = Utils.get_test_id

  # Get test users
  user_test_data = SuiteCUtils.load_suitec_test_data.select { |data| data['tests']['impact_studio_assets'] }
  users = user_test_data.map { |data| User.new(data) if %w(Teacher Student).include? data['role'] }
  teacher = users.find { |user| user.role == 'Teacher' }
  students = users.select { |user| user.role == 'Student' }
  student_1 = students[0]
  student_2 = students[1]
  student_1_activities, student_2_activities, teacher_activities = nil

  # Get test assets
  whiteboard = Whiteboard.new({owner: student_1, title: "Whiteboard #{test_id}", collaborators: [student_2]})
  asset_1 = Asset.new(student_1.assets.find { |a| a['type'] == 'Link' })
  asset_2 = Asset.new((student_1.assets.select { |a| a['type'] == 'File' })[0])
  asset_3 = Asset.new((student_1.assets.select { |a| a['type'] == 'File' })[1])
  asset_4 = Asset.new({title: whiteboard.title, type: 'Whiteboard'})
  asset_5 = Asset.new(teacher.assets.find { |a| a['type'] == 'File' })
  asset_6 = Asset.new(student_2.assets.find { |a| a['type'] == 'File' })
  asset_7 = Asset.new(student_2.assets.find { |a| a['type'] == 'Link' })
  # Append test ID to all asset titles, except whiteboard asset which will inherit test ID from its whiteboard
  [asset_1, asset_2, asset_3, asset_5, asset_6, asset_7].each { |a| a.title = "#{a.title} #{test_id}" }
  asset_1_activities, asset_3_activities, asset_4_activities, asset_5_activities, asset_6_activities = nil

  asset_4_comment = Comment.new(student_1, 'Impact-free comment')
  asset_6_comment = Comment.new(teacher, 'This is a comment from Teacher to Student 2')
  asset_6_reply = Comment.new(teacher, 'This is another comment from Teacher to Student 2')

  before(:all) do
    @course = Course.new({title: "Impact Studio Visualizations #{test_id}", code: "Impact Studio Visualizations #{test_id}"})

    @driver = Utils.launch_browser
    @canvas = Page::CanvasAnnounceDiscussPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryDetailPage.new @driver
    @engagement_index = Page::SuiteCPages::EngagementIndexPage.new @driver
    @impact_studio = Page::SuiteCPages::ImpactStudioPage.new @driver
    @whiteboards = Page::SuiteCPages::WhiteboardPage.new @driver

    # Create course site if necessary
    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, users, test_id,
                                       [LtiTools::ASSET_LIBRARY, LtiTools::ENGAGEMENT_INDEX, LtiTools::IMPACT_STUDIO, LtiTools::WHITEBOARDS])
    @asset_library_url = @canvas.click_tool_link(@driver, LtiTools::ASSET_LIBRARY)
    @engagement_index_url = @canvas.click_tool_link(@driver, LtiTools::ENGAGEMENT_INDEX)
    @impact_studio_url = @canvas.click_tool_link(@driver, LtiTools::IMPACT_STUDIO)
    @whiteboards_url = @canvas.click_tool_link(@driver, LtiTools::WHITEBOARDS)

    # Initialize user activity hashes to store activity data
    student_1_activities = @impact_studio.init_user_activities
    student_2_activities = @impact_studio.init_user_activities
    teacher_activities = @impact_studio.init_user_activities

    # Initialize asset activity hashes to store activity data
    asset_1_activities = @asset_library.init_asset_activities
    asset_3_activities = @asset_library.init_asset_activities
    asset_4_activities = @asset_library.init_asset_activities
    asset_5_activities = @asset_library.init_asset_activities
    asset_6_activities = @asset_library.init_asset_activities

    # Each student hits the EI to make sure they are synced to the tools
    [student_1, student_2].each do |student|
      @canvas.masquerade_as(@driver, student, @course)
      @engagement_index.load_page(@driver, @engagement_index_url)
      @engagement_index.share_score
    end
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when no assets exist' do

    context 'and a user views its own profile' do

      before(:all) do
        @canvas.masquerade_as(@driver, student_1, @course)
        @impact_studio.load_page(@driver, @impact_studio_url)
      end

      it('shows empty lanes under My Activity') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_1_activities) }
      it('shows "currently no contributions" under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_1_activities, 'My Contributions') }
      it('shows "currently no contributions" under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      it('shows "currently no impacts" under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_1_activities, 'My Impacts') }
      it('shows "currently no impacts" under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
    end

    context 'and a user views another user\'s profile' do

      before(:all) do
        @engagement_index.load_page(@driver, @engagement_index_url)
        @engagement_index.click_user_dashboard_link(@driver, student_2)
      end

      it('shows empty lanes under Activity') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_2_activities) }
      it('shows "currently no contributions" under Activity > User Contributions') { @impact_studio.verify_user_contributions(@driver, student_2_activities, "#{student_2.full_name}") }
      it('shows "currently no contributions" under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      it('shows "currently no impacts" under Activity > User Impacts') { @impact_studio.verify_user_impacts(@driver, student_2_activities, "#{student_2.full_name}") }
      it('shows "currently no impacts" under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
    end
  end

  context 'when assets are contributed' do

    context 'via impact studio "add site"' do

      before(:all) do
        # Student 1 add asset 1 via impact studio
        @canvas.masquerade_as(@driver, student_1, @course)
        @impact_studio.load_page(@driver, @impact_studio_url)
        @impact_studio.add_site(@driver, asset_1)
        student_1_activities[:add_asset][:count] += 1
        @impact_studio.load_page(@driver, @impact_studio_url)
      end

      it('shows a My Contributions "Creations" event') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_1_activities) }
      it('shows the event details in a tooltip') { @impact_studio.verify_latest_event_drop(@driver, student_1, asset_1, Activity::ADD_ASSET_TO_LIBRARY, 3) }
      it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_1_activities, 'My Contributions') }
      it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      it('shows no activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_1_activities, 'My Impacts') }
      it('shows no activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
    end

    context 'via adding to a whiteboard but not the library' do

      before(:all) do
        # Student 1 add asset 2 to whiteboard, exclude from asset library
        @whiteboards.load_page(@driver, @whiteboards_url)
        @whiteboards.create_and_open_whiteboard(@driver, whiteboard)
        @whiteboards.add_asset_exclude_from_library asset_2
        @whiteboards.close_whiteboard @driver
        @impact_studio.load_page(@driver, @impact_studio_url)
      end

      it('shows no My Contributions "Creations" event') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_1_activities) }
      it('shows no additional activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_1_activities, 'My Contributions') }
      it('shows no additional activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      it('shows no activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_1_activities, 'My Impacts') }
      it('shows no activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
    end

    context 'via adding to a whiteboard and to the library' do

      before(:all) do
        # Student 1 add asset 3 to a whiteboard and include it in the asset library
        @whiteboards.load_page(@driver, @whiteboards_url)
        @whiteboards.open_whiteboard(@driver, whiteboard)
        @whiteboards.add_asset_include_in_library asset_3
        student_1_activities[:add_asset][:count] += 1
        @whiteboards.close_whiteboard @driver
        @impact_studio.load_page(@driver, @impact_studio_url)
      end

      it('shows a My Contributions "Creations" event') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_1_activities) }
      it('shows the event details in a tooltip') { @impact_studio.verify_latest_event_drop(@driver, student_1, asset_3, Activity::ADD_ASSET_TO_LIBRARY, 3) }
      it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_1_activities, 'My Contributions') }
      it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      it('shows no activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_1_activities, 'My Impacts') }
      it('shows no activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
    end

    context 'via whiteboard export' do

      before(:all) do
        # Student 1 export whiteboard to create asset 4
        @whiteboards.load_page(@driver, @whiteboards_url)
        @whiteboards.open_whiteboard(@driver, whiteboard)
        @whiteboards.export_to_asset_library whiteboard
        asset_4.id = SuiteCUtils.get_asset_id_by_title asset_4
        student_1_activities[:export_whiteboard][:count] += 1
        student_2_activities[:export_whiteboard][:count] += 1
        @whiteboards.close_whiteboard @driver
        @impact_studio.load_page(@driver, @impact_studio_url)
      end

      it('shows a My Contributions "Creations" event') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_1_activities) }
      it('shows the event details in a tooltip') { @impact_studio.verify_latest_event_drop(@driver, student_1, asset_4, Activity::EXPORT_WHITEBOARD, 3) }
      it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_1_activities, 'My Contributions') }
      it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      it('shows no activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_1_activities, 'My Impacts') }
      it('shows no activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
    end

    context 'via impact studio "upload"' do

      before(:all) do
        # Teacher add asset 5 via impact studio
        @canvas.masquerade_as(@driver, teacher, @course)
        @impact_studio.load_page(@driver, @impact_studio_url)
        @impact_studio.add_file(@driver, asset_5)
        teacher_activities[:add_asset][:count] += 1
        @impact_studio.load_page(@driver, @impact_studio_url)
      end

      it('shows a My Contributions "Creations" event') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count teacher_activities) }
      it('shows the event details in a tooltip') { @impact_studio.verify_latest_event_drop(@driver, teacher, asset_5, Activity::ADD_ASSET_TO_LIBRARY, 3) }
      it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, teacher_activities, 'My Contributions') }
      it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      it('shows no activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, teacher_activities, 'My Impacts') }
      it('shows no activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
    end

    context 'via asset library upload' do

      before(:all) do
        # Student 2 add asset 6 via asset library
        @canvas.masquerade_as(@driver, student_2, @course)
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.upload_file_to_library asset_6
        student_2_activities[:add_asset][:count] += 1
        @impact_studio.load_page(@driver, @impact_studio_url)
      end

      it('shows a My Contributions "Creations" event') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_2_activities) }
      it('shows the event details in a tooltip') { @impact_studio.verify_latest_event_drop(@driver, student_2, asset_6, Activity::ADD_ASSET_TO_LIBRARY, 3) }
      it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_2_activities, 'My Contributions') }
      it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      it('shows no activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_2_activities, 'My Impacts') }
      it('shows no activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
    end
  end

  context 'when assets have impact' do

    context '"add asset to whiteboard"' do

      before(:all) do
        # One student uses the other's asset on the shared whiteboard
        @canvas.masquerade_as(@driver, student_2, @course)
        @whiteboards.load_page(@driver, @whiteboards_url)
        @whiteboards.open_whiteboard(@driver, whiteboard)
        @whiteboards.add_existing_assets [asset_1]
        student_1_activities[:get_whiteboard_add_asset][:count] += 1
        student_2_activities[:whiteboard_add_asset][:count] += 1
        asset_1_activities[:get_whiteboard_add_asset] += 1
        @whiteboards.open_original_asset_link_element.when_visible Utils.medium_wait
        @whiteboards.close_whiteboard @driver
      end

      context 'and the asset owner views its own profile' do

        before(:all) do
          @canvas.masquerade_as(@driver, student_1, @course)
          @impact_studio.load_page(@driver, @impact_studio_url)
        end

        it('shows a My Impacts "Creations" event') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_1_activities) }
        it('shows the event details in a tooltip') { @impact_studio.verify_latest_event_drop(@driver, student_2, asset_1, Activity::ADD_ASSET_TO_WHITEBOARD, 6) }
        it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_1_activities, 'My Contributions') }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_1_activities, 'My Impacts') }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end

      context 'and the asset owner views the other user\'s profile' do

        before(:all) { @impact_studio.search_for_user student_2 }

        it('shows a My Contributions "Creations" event') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_2_activities) }
        it('shows the event details in a tooltip') { @impact_studio.verify_latest_event_drop(@driver, student_2, asset_1, Activity::ADD_ASSET_TO_WHITEBOARD, 3) }
        it('shows the activity under Activity > User Contributions') { @impact_studio.verify_user_contributions(@driver, student_2_activities, "#{student_2.full_name}") }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > User Impacts') { @impact_studio.verify_user_impacts(@driver, student_2_activities, "#{student_2.full_name}") }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end

      context 'and the asset owner views the asset detail' do

        before(:all) { @asset_library.load_asset_detail(@driver, @asset_library_url, asset_1) }

        it('shows an "added to whiteboard" event') { expect(@asset_library.visible_event_drop_count(@driver, asset_1)).to eql(@asset_library.expected_event_drop_count(asset_1, asset_1_activities)) }
        it('shows the event details in a tooltip') { @asset_library.verify_latest_asset_event_drop(@driver, student_2, Activity::ADD_ASSET_TO_WHITEBOARD, 5) }
      end
    end

    context '"view asset"' do

      before(:all) do
        # Teacher views the student's asset
        @canvas.masquerade_as(@driver, teacher, @course)
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset_3)
        teacher_activities[:view_asset][:count] += 1
        student_1_activities[:get_view_asset][:count] += 1
        asset_3_activities[:get_view_asset] += 1
      end

      context 'and the asset owner views its own profile' do

        before(:all) do
          @canvas.masquerade_as(@driver, student_1, @course)
          @impact_studio.load_page(@driver, @impact_studio_url)
        end

        it('shows a My Impacts "Engagements" event') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_1_activities) }
        it('shows the event details in a tooltip') { @impact_studio.verify_latest_event_drop(@driver, teacher, asset_3, Activity::VIEW_ASSET, 4) }
        it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_1_activities, 'My Contributions') }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_1_activities, 'My Impacts') }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end

      context 'and the asset owner views the other user\'s profile' do

        before(:all) { @impact_studio.search_for_user teacher }

        it('shows a My Contributions "Engagements" event') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count teacher_activities) }
        it('shows the event details in a tooltip') { @impact_studio.verify_latest_event_drop(@driver, teacher, asset_3, Activity::VIEW_ASSET, 1) }
        it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, teacher_activities, "#{teacher.full_name}") }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, teacher_activities, "#{teacher.full_name}") }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end

      context 'and the asset owner views the asset detail' do

        before(:all) { @asset_library.load_asset_detail(@driver, @asset_library_url, asset_3) }

        it('shows a "viewed" event') { expect(@asset_library.visible_event_drop_count(@driver, asset_3)).to eql(@asset_library.expected_event_drop_count(asset_3, asset_3_activities)) }
        it('shows the event details in a tooltip') { @asset_library.verify_latest_asset_event_drop(@driver, teacher, Activity::VIEW_ASSET, 1) }
      end
    end

    context '"comment"' do

      before(:all) do
        # Teacher comments on the student's asset
        @canvas.masquerade_as(@driver, teacher, @course)

        @asset_library.load_asset_detail(@driver, @asset_library_url, asset_6)
        teacher_activities[:view_asset][:count] += 1
        student_2_activities[:get_view_asset][:count] += 1
        asset_6_activities[:get_view_asset] += 1

        @asset_library.add_comment(asset_6, asset_6_comment)
        @asset_library.wait_until(Utils.short_wait) { @asset_library.asset_detail_comment_count == '1' }
        teacher_activities[:comment][:count] += 1
        student_2_activities[:get_comment][:count] += 1
        asset_6_activities[:get_comment] += 1
      end

      context 'and the asset owner views its own profile' do

        before(:all) do
          @canvas.masquerade_as(@driver, student_2, @course)
          @impact_studio.load_page(@driver, @impact_studio_url)
        end

        it('shows My Impacts "Engagement" and "Interaction" events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_2_activities) }
        it('shows the comment event details in a tooltip') { @impact_studio.verify_latest_event_drop(@driver, teacher, asset_6, Activity::COMMENT, 5) }
        it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_2_activities, 'My Contributions') }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_2_activities, 'My Impacts') }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end

      context 'and the asset owner views the other user\'s profile' do

        before(:all) { @impact_studio.search_for_user teacher }

        it('shows My Contributions "Engagement" and "Interaction" events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count teacher_activities) }
        it('shows the comment event details in a tooltip') { @impact_studio.verify_latest_event_drop(@driver, teacher, asset_6, Activity::COMMENT, 2) }
        it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, teacher_activities, "#{teacher.full_name}") }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, teacher_activities, "#{teacher.full_name}") }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end

      context 'and the asset owner views the asset detail' do

        before(:all) { @asset_library.load_asset_detail(@driver, @asset_library_url, asset_6) }

        it('shows a "commented" event') { expect(@asset_library.visible_event_drop_count(@driver, asset_6)).to eql(@asset_library.expected_event_drop_count(asset_6, asset_6_activities)) }
        it('shows the event details in a tooltip') { @asset_library.verify_latest_asset_event_drop(@driver, teacher, Activity::COMMENT, 4) }
      end
    end

    context '"comment reply"' do

      before(:all) do
        # Teacher replies to comment on the student's asset
        @canvas.masquerade_as(@driver, teacher, @course)

        @asset_library.load_asset_detail(@driver, @asset_library_url, asset_6)
        teacher_activities[:view_asset][:count] += 1
        student_2_activities[:get_view_asset][:count] += 1
        asset_6_activities[:get_view_asset] += 1

        @asset_library.reply_to_comment(asset_6, asset_6_comment, asset_6_reply)
        @asset_library.wait_until(Utils.short_wait) { @asset_library.asset_detail_comment_count == '2' }
        teacher_activities[:comment][:count] += 1
        student_2_activities[:get_comment][:count] += 1
        asset_6_activities[:get_comment] += 1
      end

      context 'and the asset owner views its own profile' do

        before(:all) do
          @canvas.masquerade_as(@driver, student_2, @course)
          @impact_studio.load_page(@driver, @impact_studio_url)
        end

        it('shows My Impacts "Engagement" and "Interaction" events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_2_activities) }
        it('shows the comment event details in a tooltip') { @impact_studio.verify_latest_event_drop(@driver, teacher, asset_6, Activity::COMMENT, 5) }
        it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_2_activities, 'My Contributions') }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_2_activities, 'My Impacts') }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end

      context 'and the asset owner views the other user\'s profile' do

        before(:all) { @impact_studio.search_for_user teacher }

        it('shows My Contributions "Engagement" and "Interaction" events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count teacher_activities) }
        it('shows the comment event details in a tooltip') { @impact_studio.verify_latest_event_drop(@driver, teacher, asset_6, Activity::COMMENT, 2) }
        it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, teacher_activities, "#{teacher.full_name}") }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, teacher_activities, "#{teacher.full_name}") }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end

      context 'and the asset owner views the asset detail' do

        before(:all) { @asset_library.load_asset_detail(@driver, @asset_library_url, asset_6) }

        it('shows a "commented" event') { expect(@asset_library.visible_event_drop_count(@driver, asset_6)).to eql(@asset_library.expected_event_drop_count(asset_6, asset_6_activities)) }
        it('shows the event details in a tooltip') { @asset_library.verify_latest_asset_event_drop(@driver, teacher, Activity::COMMENT, 4) }
      end
    end

    context '"like"' do

      before(:all) do
        # One student likes the teacher's asset
        @canvas.masquerade_as(@driver, student_1, @course)

        @asset_library.load_asset_detail(@driver, @asset_library_url, asset_5)
        student_1_activities[:view_asset][:count] += 1
        teacher_activities[:get_view_asset][:count] += 1
        asset_5_activities[:get_view_asset] += 1

        @asset_library.toggle_detail_view_item_like asset_5
        @asset_library.wait_until { @asset_library.detail_view_asset_likes_count == '1' }
        student_1_activities[:like][:count] += 1
        teacher_activities[:get_like][:count] += 1
        asset_5_activities[:get_like] += 1
      end

      context 'and the asset owner views its own profile' do

        before(:all) do
          @canvas.masquerade_as(@driver, teacher, @course)
          @impact_studio.load_page(@driver, @impact_studio_url)
        end

        it('shows My Impacts "Engagement" events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count teacher_activities) }
        it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, teacher_activities, 'My Contributions') }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, teacher_activities, 'My Impacts') }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end

      context 'and the asset owner views the other user\'s profile' do

        before(:all) { @impact_studio.search_for_user student_1 }

        it('shows My Contributions "Engagement" events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_1_activities) }
        it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_1_activities, "#{student_1.full_name}") }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_1_activities, "#{student_1.full_name}") }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end

      context 'and the asset owner views the asset detail' do

        before(:all) { @asset_library.load_asset_detail(@driver, @asset_library_url, asset_5) }

        it('shows a "liked" event') { expect(@asset_library.visible_event_drop_count(@driver, asset_5)).to eql(@asset_library.expected_event_drop_count(asset_5, asset_5_activities)) }
        it('shows the event details in a tooltip') { @asset_library.verify_latest_asset_event_drop(@driver, student_1, Activity::LIKE, 2) }
      end
    end

    context '"remix whiteboard"' do

      before(:all) do
        # Teacher remixes the students' whiteboard
        @canvas.masquerade_as(@driver, teacher, @course)

        @asset_library.load_asset_detail(@driver, @asset_library_url, asset_4)
        teacher_activities[:view_asset][:count] += 1
        student_1_activities[:get_view_asset][:count] += 1
        student_2_activities[:get_view_asset][:count] += 1
        asset_4_activities[:get_view_asset] += 1

        @asset_library.click_remix
        teacher_activities[:remix_whiteboard][:count] += 1
        student_1_activities[:get_remix_whiteboard][:count] += 1
        student_2_activities[:get_remix_whiteboard][:count] += 1
        asset_4_activities[:get_remix_whiteboard] += 1
      end

      context 'and one whiteboard asset owner views its own profile' do

        before(:all) do
          @canvas.masquerade_as(@driver, student_1, @course)
          @impact_studio.load_page(@driver, @impact_studio_url)
        end

        it('shows My Impacts "Engagements" and "Creations" events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_1_activities) }
        it('shows the remix event details in a tooltip') { @impact_studio.verify_latest_event_drop(@driver, teacher, asset_4, Activity::REMIX_WHITEBOARD, 6) }
        it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_1_activities, 'My Contributions') }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_1_activities, 'My Impacts') }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end

      context 'and another whiteboard asset owner views its own profile' do

        before(:all) do
          @canvas.masquerade_as(@driver, student_2, @course)
          @impact_studio.load_page(@driver, @impact_studio_url)
        end

        it('shows My Impacts "Engagements" and "Creations" events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_2_activities) }
        it('shows the remix event details in a tooltip') { @impact_studio.verify_latest_event_drop(@driver, teacher, asset_4, Activity::REMIX_WHITEBOARD, 6) }
        it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_2_activities, 'My Contributions') }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_2_activities, 'My Impacts') }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end

      context 'and an asset owner views the remixer\'s profile' do

        before(:all) { @impact_studio.search_for_user teacher }

        it('shows My Contributions "Engagements" and "Creations" events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count teacher_activities) }
        it('shows the remix event details in a tooltip') { @impact_studio.verify_latest_event_drop(@driver, teacher, asset_4, Activity::REMIX_WHITEBOARD, 3) }
        it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, teacher_activities, "#{teacher.full_name}") }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, teacher_activities, "#{teacher.full_name}") }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end

      context 'and the asset owner views the asset detail' do

        before(:all) { @asset_library.load_asset_detail(@driver, @asset_library_url, asset_4) }

        it('shows a "remixed" event') { expect(@asset_library.visible_event_drop_count(@driver, asset_4)).to eql(@asset_library.expected_event_drop_count(asset_4, asset_4_activities)) }
        it('shows the event details in a tooltip') { @asset_library.verify_latest_asset_event_drop(@driver, teacher, Activity::REMIX_WHITEBOARD, 6) }
      end
    end

    context '"pin"' do

      before(:all) do
        # Student 2 pins Student 1's asset
        @canvas.masquerade_as(@driver, student_2, @course)

        @asset_library.load_asset_detail(@driver, @asset_library_url, asset_1)
        student_2_activities[:view_asset][:count] += 1
        student_1_activities[:get_view_asset][:count] += 1
        asset_1_activities[:get_view_asset] += 1

        @asset_library.pin_detail_view_asset asset_1
        student_2_activities[:pin_asset][:count] += 1
        student_1_activities[:get_pin_asset][:count] += 1
        asset_1_activities[:get_pin_asset] += 1
      end

      context 'and the asset owner views its own profile' do

        before(:all) do
          @canvas.masquerade_as(@driver, student_1, @course)
          @impact_studio.load_page(@driver, @impact_studio_url)
        end

        it('shows My Impacts "Engagements" and "Interactions" events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_1_activities) }
        it('shows the pin event details in a tooltip') { @impact_studio.verify_latest_event_drop(@driver, student_2, asset_1, Activity::PIN_ASSET, 5) }
        it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_1_activities, 'My Contributions') }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_1_activities, 'My Impacts') }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end

      context 'and the asset owner views the pinner\'s profile' do

        before(:all) { @impact_studio.search_for_user student_2 }

        it('shows My Contributions "Engagements" and "Creations" events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_2_activities) }
        it('shows the remix event details in a tooltip') { @impact_studio.verify_latest_event_drop(@driver, student_2, asset_1, Activity::PIN_ASSET, 2) }
        it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_2_activities, "#{student_2.full_name}") }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_2_activities, "#{student_2.full_name}") }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end

      context 'and the asset owner views the asset detail' do

        before(:all) { @asset_library.load_asset_detail(@driver, @asset_library_url, asset_1) }

        it('shows a "pinned" event') { expect(@asset_library.visible_event_drop_count(@driver, asset_1)).to eql(@asset_library.expected_event_drop_count(asset_1, asset_1_activities)) }
        it('shows the event details in a tooltip') { @asset_library.verify_latest_asset_event_drop(@driver, student_2, Activity::PIN_ASSET, 3) }
      end
    end
  end

  context 'when assets impact their owners' do

    before(:all) { @canvas.masquerade_as(@driver, student_1, @course) }

    context 'with "view" impact' do

      before(:all) do
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset_4)
        @impact_studio.load_page(@driver, @impact_studio_url)
      end

      it('does not show My Contributions "Engagements" events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_1_activities) }
      it('shows no activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_1_activities, 'My Contributions') }
      it('shows no activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      it('shows no activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_1_activities, 'My Impacts') }
      it('shows no activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }

      context 'and the asset owner views the asset detail' do

        before(:all) { @asset_library.load_asset_detail(@driver, @asset_library_url, asset_4) }

        it('shows no "viewed" event') { expect(@asset_library.visible_event_drop_count(@driver, asset_4)).to eql(@asset_library.expected_event_drop_count(asset_4, asset_4_activities)) }
      end
    end

    context 'with "comment" impact' do

      before(:all) do
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset_4)
        @asset_library.add_comment(asset_4, asset_4_comment)
        @impact_studio.load_page(@driver, @impact_studio_url)
      end

      it('does not show My Contributions "Engagements" or "Interactions" events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_1_activities) }
      it('shows no activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_1_activities, 'My Contributions') }
      it('shows no activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      it('shows no activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_1_activities, 'My Impacts') }
      it('shows no activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }

      context 'and the asset owner views the asset detail' do

        before(:all) { @asset_library.load_asset_detail(@driver, @asset_library_url, asset_4) }

        it('shows no "commented" event') { expect(@asset_library.visible_event_drop_count(@driver, asset_4)).to eql(@asset_library.expected_event_drop_count(asset_4, asset_4_activities)) }
      end
    end

    context 'with "remix" impact' do

      before(:all) do
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset_4)
        @asset_library.click_remix
        @impact_studio.load_page(@driver, @impact_studio_url)
      end

      it('does not show My Contributions "Engagements" or "Creations" events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_1_activities) }
      it('shows no activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_1_activities, 'My Contributions') }
      it('shows no activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      it('shows no activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_1_activities, 'My Impacts') }
      it('shows no activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
    end

    context 'and the asset owner views the asset detail' do

      before(:all) { @asset_library.load_asset_detail(@driver, @asset_library_url, asset_4) }

      it('shows no "remixed" event') { expect(@asset_library.visible_event_drop_count(@driver, asset_4)).to eql(@asset_library.expected_event_drop_count(asset_4, asset_4_activities)) }
    end

    context 'with "pin" impact' do

      before(:all) do
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset_4)
        @asset_library.pin_detail_view_asset asset_4
        @impact_studio.load_page(@driver, @impact_studio_url)
      end

      it('does not show My Contributions "Engagements" events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_1_activities) }
      it('shows no activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_1_activities, 'My Contributions') }
      it('shows no activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      it('shows no activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_1_activities, 'My Impacts') }
      it('shows no activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
    end
  end

  context 'when assets lose impact' do

    context '"comment"' do

      before(:all) do
        @canvas.masquerade_as(@driver, teacher, @course)

        @asset_library.load_asset_detail(@driver, @asset_library_url, asset_6)
        teacher_activities[:view_asset][:count] += 1
        student_2_activities[:get_view_asset][:count] += 1
        asset_6_activities[:get_view_asset] += 1

        @asset_library.delete_comment(asset_6, asset_6_reply)
        teacher_activities[:comment][:count] -= 1
        student_2_activities[:get_comment][:count] -= 1
        asset_6_activities[:get_comment] -= 1
      end

      after(:all) do
        # Up the expected asset 6 view count since it was viewed to verify the impact of un-commenting
        asset_6_activities[:get_view_asset] += 1
      end

      context 'and the comment deleter views the asset detail' do

        before(:all) do
          @asset_library.load_asset_detail(@driver, @asset_library_url, asset_6)
          teacher_activities[:view_asset][:count] += 1
          student_2_activities[:get_view_asset][:count] += 1
        end

        it('subtracts a "commented" event') { expect(@asset_library.visible_event_drop_count(@driver, asset_6)).to eql(@asset_library.expected_event_drop_count(asset_6, asset_6_activities)) }
      end

      context 'and the comment deleter views its own profile' do

        before(:all) { @impact_studio.load_page(@driver, @impact_studio_url) }

        it('adds My Contributions "Engagements" and removes "Interactions" events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count teacher_activities) }
        it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, teacher_activities, 'My Contributions') }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, teacher_activities, 'My Impacts') }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end

      context 'and the comment deleter views the asset owner\'s profile' do

        before(:all) { @impact_studio.search_for_user student_2 }

        it('adds My Impact "Engagements" and removes "Interactions" events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_2_activities) }
        it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_2_activities, "#{student_2.full_name}") }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_2_activities, "#{student_2.full_name}") }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end
    end

    context '"like"' do

      before(:all) do
        @canvas.masquerade_as(@driver, student_1, @course)

        @asset_library.load_asset_detail(@driver, @asset_library_url, asset_5)
        student_1_activities[:view_asset][:count] += 1
        teacher_activities[:get_view_asset][:count] += 1
        asset_5_activities[:get_view_asset] += 1

        likes = @asset_library.detail_view_asset_likes_count.to_i
        @asset_library.toggle_detail_view_item_like asset_5
        @asset_library.wait_until(Utils.short_wait) { @asset_library.detail_view_asset_likes_count.to_i == likes - 1 }
        sleep Utils.short_wait
        student_1_activities[:like][:count] -= 1
        teacher_activities[:get_like][:count] -= 1
        asset_5_activities[:get_like] -= 1
      end

      after(:all) do
        # Up the expected asset 5 view count since it was viewed to verify the impact of un-liking
        asset_5_activities[:get_view_asset] += 1
      end

      context 'and the un-liker views the asset detail' do

        before(:all) do
          @asset_library.load_asset_detail(@driver, @asset_library_url, asset_5)
          student_1_activities[:view_asset][:count] +=1
          teacher_activities[:get_view_asset][:count] += 1
        end

        it('subtracts a "liked" event') { expect(@asset_library.visible_event_drop_count(@driver, asset_5)).to eql(@asset_library.expected_event_drop_count(asset_5, asset_5_activities)) }
      end

      context 'and the un-liker views its own profile' do

        before(:all) { @impact_studio.load_page(@driver, @impact_studio_url) }

        it('adds and removes My Contributions "Engagements" events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_1_activities) }
        it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_1_activities, 'My Contributions') }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_1_activities, 'My Impacts') }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end

      context 'and the un-liker views the asset owner\'s profile' do

        before(:all) { @impact_studio.search_for_user teacher }

        it('adds and removes My Impact "Engagements" events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count teacher_activities) }
        it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, teacher_activities, "#{teacher.full_name}") }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, teacher_activities, "#{teacher.full_name}") }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end
    end

    context '"pin"' do

      before(:all) do
        @canvas.masquerade_as(@driver, student_2, @course)

        @asset_library.load_asset_detail(@driver, @asset_library_url, asset_1)
        student_2_activities[:view_asset][:count] += 1
        student_1_activities[:get_view_asset][:count] += 1
        asset_1_activities[:get_view_asset] += 1

        @asset_library.unpin_detail_view_asset asset_1
        # No change to pinning activity, since pins are expected to be removed eventually
      end

      after(:all) do
        # Up the expected asset 5 view count since it was viewed to verify the impact of un-pinning
        asset_1_activities[:get_view_asset] += 1
      end

      context 'and the un-pinner views the asset detail' do

        before(:all) do
          @asset_library.load_asset_detail(@driver, @asset_library_url, asset_1)
          student_2_activities[:view_asset][:count] +=1
          student_1_activities[:get_view_asset][:count] += 1
        end

        it('does not remove the "pinned" event') { expect(@asset_library.visible_event_drop_count(@driver, asset_1)).to eql(@asset_library.expected_event_drop_count(asset_1, asset_1_activities)) }
      end

      context 'and the un-pinner views its own profile' do

        before(:all) { @impact_studio.load_page(@driver, @impact_studio_url) }

        it('adds and removes My Contributions "Engagements" events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_2_activities) }
        it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_2_activities, 'My Contributions') }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_2_activities, 'My Impacts') }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end

      context 'and the un-pinner views the asset owner\'s profile' do

        before(:all) { @impact_studio.search_for_user student_1 }

        it('adds and removes My Impact "Engagements" events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_1_activities) }
        it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_1_activities, "#{student_1.full_name}") }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_1_activities, "#{student_1.full_name}") }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end
    end
  end

  context 'when assets are deleted' do

    context 'before they have impact' do

      before(:all) do
        # Student 2 add asset 7 via asset library and then delete it
        @asset_library.load_page(@driver, @asset_library_url)
        @asset_library.add_site asset_7
        logger.debug "Asset 7 ID is #{asset_7.id}"
        @asset_library.load_asset_detail(@driver, @asset_library_url, asset_7)
        @asset_library.delete_asset asset_7
        @impact_studio.load_page(@driver, @impact_studio_url)
      end

      it('shows no My Contributions "Creations" event') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_2_activities) }
      it('shows no additional activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_2_activities, 'My Contributions') }
      it('shows no additional activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      it('shows no additional activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_2_activities, 'My Impacts') }
      it('shows no additional activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
    end

    context 'when they have impact' do

      before(:all) do
        # Teacher deletes all assets
        @canvas.masquerade_as(@driver, teacher, @course)
        [asset_1, asset_3, asset_4, asset_5, asset_6].each do |asset|
          @asset_library.load_asset_detail(@driver, @asset_library_url, asset)
          @asset_library.delete_asset asset
        end

        # Re-initialize all activities hashes so they're back to zero counts
        teacher_activities = @impact_studio.init_user_activities
        student_1_activities = @impact_studio.init_user_activities
        student_2_activities = @impact_studio.init_user_activities
      end

      context 'and a user views its own profile' do

        before(:all) { @impact_studio.load_page(@driver, @impact_studio_url) }

        it('removes My Contributions and My Impacts events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count teacher_activities) }
        it('removes activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, teacher_activities, 'My Contributions') }
        it('removes activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('removes activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, teacher_activities, 'My Impacts') }
        it('removes activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end

      context 'and a user views another users\'s profile' do
        before(:all) { @impact_studio.search_for_user student_1 }

        it('removes My Contributions and My Impacts events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_1_activities) }
        it('removes activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_1_activities, "#{student_1.full_name}") }
        it('removes activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('removes activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_1_activities, "#{student_1.full_name}") }
        it('removes activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end

      context 'and a user views another users\'s profile' do
        before(:all) { @impact_studio.search_for_user student_2 }

        it('removes My Contributions and My Impacts events') { expect(@impact_studio.visible_event_drop_count(@driver)).to eql(@impact_studio.expected_event_drop_count student_2_activities) }
        it('removes activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_2_activities, "#{student_2.full_name}") }
        it('removes activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('removes activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_2_activities, "#{student_2.full_name}") }
        it('removes activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end
    end
  end

  describe 'Canvas discussions' do

    before(:all) { @discussion = Discussion.new 'Discussion topic' }

    context 'when a new topic is created' do

      before(:all) do
        @canvas.masquerade_as(@driver, teacher, @course)
        @canvas.create_course_discussion(@driver, @course, @discussion)
        teacher_activities[:discussion_topic][:count] += 1
      end

      it('adds a My Contributions "Interactions" event') { @impact_studio.wait_for_canvas_event(@driver, @impact_studio_url, @impact_studio.expected_event_drop_count(teacher_activities)) }
      it('shows the event details in a tooltip') { @impact_studio.verify_latest_event_drop(@driver, teacher, nil, Activity::ADD_DISCUSSION_TOPIC, 2) }
      it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, teacher_activities, 'My Contributions') }
      it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, teacher_activities, 'My Impacts') }
      it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
    end

    context 'when an entry is added' do

      before(:all) do
        @canvas.masquerade_as(@driver, student_1, @course)
        @canvas.add_reply(@discussion, nil, 'Discussion entry')
        student_1_activities[:discussion_entry][:count] += 1
      end

      it('adds a My Contributions "Interactions" event') { @impact_studio.wait_for_canvas_event(@driver, @impact_studio_url, @impact_studio.expected_event_drop_count(student_1_activities)) }
      it('shows the event details in a tooltip') { @impact_studio.verify_latest_event_drop(@driver, student_1, nil, Activity::ADD_DISCUSSION_ENTRY, 2) }
      it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_1_activities, 'My Contributions') }
      it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_1_activities, 'My Impacts') }
      it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
    end

    context 'when a reply is added' do

      before(:all) do
        @canvas.masquerade_as(@driver, student_2, @course)
        @canvas.add_reply(@discussion, 0, 'Discussion reply')
        student_2_activities[:discussion_entry][:count] += 1
        student_1_activities[:get_discussion_entry_reply][:count] += 1
      end

      context 'and the replier views its own profile' do

        before(:all) { @impact_studio.load_page(@driver, @impact_studio_url) }

        it('adds a My Contributions "Interactions" event') { @impact_studio.wait_for_canvas_event(@driver, @impact_studio_url, @impact_studio.expected_event_drop_count(student_2_activities)) }
        it('shows the event details in a tooltip') { @impact_studio.verify_latest_event_drop(@driver, student_2, nil, Activity::GET_DISCUSSION_REPLY, 2) }
        it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_2_activities, 'My Contributions') }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_2_activities, 'My Impacts') }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end

      context 'and the entry-creator views its own profile' do

        before(:all) do
          @canvas.masquerade_as(@driver, student_1, @course)
          @impact_studio.load_page(@driver, @impact_studio_url)
        end

        it('adds a My Impact "Interactions" event') { @impact_studio.wait_for_canvas_event(@driver, @impact_studio_url, @impact_studio.expected_event_drop_count(student_1_activities)) }
        it('shows the event details in a tooltip') { @impact_studio.verify_latest_event_drop(@driver, student_2, nil, Activity::GET_DISCUSSION_REPLY, 5) }
        it('shows the activity under Activity > My Contributions') { @impact_studio.verify_user_contributions(@driver, student_1_activities, 'My Contributions') }
        it('shows the activity under Activity > Everyone Contributions') { @impact_studio.verify_everyone_contributions(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
        it('shows the activity under Activity > My Impacts') { @impact_studio.verify_user_impacts(@driver, student_1_activities, 'My Impacts') }
        it('shows the activity under Activity > Everyone Impacts') { @impact_studio.verify_everyone_impacts(@driver, [student_1_activities, student_2_activities, teacher_activities], users) }
      end
    end
  end
end
