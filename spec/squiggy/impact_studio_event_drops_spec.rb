require_relative '../../util/spec_helper'

describe 'The Impact Studio' do

  before(:all) do
    @test = SquiggyTestConfig.new 'studio_timeline'
    @teacher = @test.teachers[0]
    @student_1 = @test.students[0]
    @student_2 = @test.students[1]

    @asset_1 = @student_1.assets.find &:url
    @asset_2 = @student_1.assets.select(&:file_name)[0]
    @asset_3 = @student_1.assets.select(&:file_name)[1]
    @asset_4 = SquiggyAsset.new({})
    @asset_5 = @teacher.assets.find &:file_name
    @asset_6 = @student_2.assets.find &:file_name
    @asset_7 = @student_2.assets.find &:url

    @asset_4_comment = SquiggyComment.new user: @student_1,
                                         asset: @asset_4,
                                         body: "Impact-free comment #{@test.id}"
    @asset_6_comment = SquiggyComment.new user: @teacher,
                                         asset: @asset_6,
                                         body: "This is a comment from Teacher to Student 2 #{@test.id}"
    @asset_6_reply = SquiggyComment.new user: @teacher,
                                       asset: @asset_6,
                                       body: "This is another comment from Teacher to Student 2 #{@test.id}"

    @whiteboard = SquiggyWhiteboard.new owner: @student_1,
                                       title: "Whiteboard #{@test.id}",
                                       collaborators: [@student_2]

    @driver = Utils.launch_browser
    @canvas = Page::CanvasAnnounceDiscussPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = SquiggyAssetLibraryDetailPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver
    @impact_studio = SquiggyImpactStudioPage.new @driver
    @whiteboards = SquiggyWhiteboardPage.new @driver

    @student_1_activities = @impact_studio.init_user_activities
    @student_2_activities = @impact_studio.init_user_activities
    @teacher_activities = @impact_studio.init_user_activities

    @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course @test
    @engagement_index.wait_for_new_user_sync(@test, @test.course.roster)

    [@student_1, @student_2].each do |student|
      @canvas.masquerade_as(student, @test.course)
      @engagement_index.load_page @test
      @engagement_index.share_score
    end
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when no assets exist' do

    context 'and a user views its own profile' do
      before(:all) do
        @canvas.masquerade_as @student_1
        @impact_studio.load_page test
      end
      it 'shows empty lanes under My Activity' do
        @impact_studio.no_activity_timeline_element.when_visible Utils.short_wait
      end
    end

    context 'and a user views another user\'s profile' do
      before(:all) do
        @engagement_index.load_page test
        @engagement_index.click_user_dashboard_link @student_2
      end
      it 'shows empty lanes under Activity' do
        @impact_studio.no_activity_timeline_element.when_visible Utils.short_wait
      end
    end
  end

  context 'when assets are contributed' do

    context 'via asset library "add site"' do
      before(:all) do
        @canvas.masquerade_as @student_1
        @asset_library.load_page @test
        @asset_library.add_link_asset @asset_1
        @student_1_activities[:asset_add][:count] += 1
        @impact_studio.load_page @test
      end
      it('adds a My Contributions "Creations" event') { @impact_studio.verify_event_drop_count @student_1_activities }
      it 'shows the event details in a tooltip' do
        @impact_studio.verify_latest_event_drop(@student_1, @asset_1, SquiggyActivity::ADD_ASSET_TO_LIBRARY, 3)
      end
    end

    context 'via adding to a whiteboard but not the library' do
      before(:all) do
        @whiteboards.load_page @test
        @whiteboards.create_and_open_whiteboard @whiteboard
        @whiteboards.add_asset_exclude_from_library @asset_2
        @whiteboards.close_whiteboard
        @impact_studio.load_page @test
      end

      it('adds no My Contributions "Creations" event') { @impact_studio.verify_event_drop_count @student_1_activities }
    end

    context 'via adding to a whiteboard and to the library' do
      before(:all) do
        @whiteboards.load_page @test
        @whiteboards.open_whiteboard @whiteboard
        @whiteboards.add_asset_include_in_library @asset_3
        @student_1_activities[:asset_add][:count] += 1
        @whiteboards.close_whiteboard
        @impact_studio.load_page @test
      end
      it('adds a My Contributions "Creations" event') { @impact_studio.verify_event_drop_count @student_1_activities }
    end

    context 'via whiteboard export' do
      before(:all) do
        @whiteboards.load_page @test
        @whiteboards.open_whiteboard @whiteboard
        asset_4 = @whiteboards.export_to_asset_library @whiteboard
        @student_1_activities[:whiteboard_export][:count] += 1
        @student_2_activities[:whiteboard_export][:count] += 1
        @whiteboards.close_whiteboard
        @impact_studio.load_page @test
      end
      it('adds a My Contributions "Creations" event') { @impact_studio.verify_event_drop_count @student_1_activities }
    end

    context 'via asset library "upload"' do
      before(:all) do
        @canvas.masquerade_as(@teacher, @test.course)
        @asset_library.load_page @test
        @asset_library.upload_file_asset @asset_5
        @teacher_activities[:asset_add][:count] += 1
        @impact_studio.load_page @test
      end
      it('adds a My Contributions "Creations" event') { @impact_studio.verify_event_drop_count @teacher_activities }
    end

    context 'via asset library upload' do
      before(:all) do
        @canvas.masquerade_as @student_2
        @asset_library.load_page @test
        @asset_library.upload_file_asset @asset_6
        @student_2_activities[:asset_add][:count] += 1
        @impact_studio.load_page @test
      end
      it('adds a My Contributions "Creations" event') { @impact_studio.verify_event_drop_count @student_2_activities }
    end
  end

  context 'when assets have impact' do

    context '"add asset to whiteboard"' do
      before(:all) do
        @canvas.masquerade_as @student_2
        @whiteboards.load_page @test
        @whiteboards.open_whiteboard @whiteboard
        @whiteboards.add_existing_assets [@asset_1]
        @student_1_activities[:get_whiteboard_add_asset][:count] += 1
        @student_2_activities[:whiteboard_add_asset][:count] += 1
        @whiteboards.open_original_asset_link_element.when_visible Utils.medium_wait
        @whiteboards.close_whiteboard
      end

      context 'and the asset owner views its own profile' do
        before(:all) do
          @canvas.masquerade_as @student_1
          @impact_studio.load_page @test
        end
        it('adds a My Impacts "Creations" event') { @impact_studio.verify_event_drop_count @student_1_activities }
      end

      context 'and the asset owner views the other user\'s profile' do
        before(:all) { @impact_studio.select_user @student_2 }
        it('adds a My Contributions "Creations" event') { @impact_studio.verify_event_drop_count @student_2_activities }
      end
    end

    context '"view asset"' do
      before(:all) do
        @canvas.masquerade_as @teacher
        @asset_library.load_asset_detail(@test, @asset_3)
        @teacher_activities[:asset_view][:count] += 1
        @student_1_activities[:get_asset_view][:count] += 1
      end

      context 'and the asset owner views its own profile' do
        before(:all) do
          @canvas.masquerade_as @student_1
          @impact_studio.load_page @test
        end

        it('adds a My Impacts "Engagements" event') { @impact_studio.verify_event_drop_count @student_1_activities }
        it 'shows the event details in a tooltip' do
          @impact_studio.verify_latest_event_drop(@teacher, @asset_3, SquiggyActivity::VIEW_ASSET, 4)
        end
      end

      context 'and the asset owner views the other user\'s profile' do
        before(:all) { @impact_studio.select_user @teacher }
        it('adds a My Contributions "Engagements" event') { @impact_studio.verify_event_drop_count @teacher_activities }
        it 'shows the event details in a tooltip' do
          @impact_studio.verify_latest_event_drop(@teacher, @asset_3, SquiggyActivity::VIEW_ASSET, 1)
        end
      end
    end

    context '"comment"' do
      before(:all) do
        @canvas.masquerade_as @teacher
        @asset_library.load_asset_detail(@test, @asset_6)
        @asset_library.add_comment @asset_6_comment
        @teacher_activities[:asset_view][:count] += 1
        @student_2_activities[:get_asset_view][:count] += 1
        @teacher_activities[:asset_comment][:count] += 1
        @student_2_activities[:get_asset_comment][:count] += 1
      end

      context 'and the asset owner views its own profile' do
        before(:all) do
          @canvas.masquerade_as @student_2
          @impact_studio.load_page @test
        end
        it('adds My Impacts "Engagement" and "Interaction" events') { @impact_studio.verify_event_drop_count @student_2_activities }
      end

      context 'and the asset owner views the other user\'s profile' do
        before(:all) { @impact_studio.select_user @teacher }
        it('adds My Contributions "Engagement" and "Interaction" events') { @impact_studio.verify_event_drop_count @teacher_activities }
      end
    end

    context '"comment reply"' do
      before(:all) do
        @canvas.masquerade_as @teacher
        @asset_library.load_asset_detail(@test, @asset_6)
        @asset_library.reply_to_comment(@asset_6_comment, @asset_6_reply)
        @teacher_activities[:asset_view][:count] += 1
        @student_2_activities[:get_asset_view][:count] += 1
        @teacher_activities[:asset_comment][:count] += 1
        @student_2_activities[:get_asset_comment][:count] += 1
      end

      context 'and the asset owner views its own profile' do
        before(:all) do
          @canvas.masquerade_as @student_2
          @impact_studio.load_page @test
        end
        it('adds My Impacts "Engagement" and "Interaction" events') { @impact_studio.verify_event_drop_count @student_2_activities }
      end

      context 'and the asset owner views the other user\'s profile' do
        before(:all) { @impact_studio.select_user @teacher }
        it('adds My Contributions "Engagement" and "Interaction" events') { @impact_studio.verify_event_drop_count @teacher_activities }
      end
    end

    context '"like"' do

      before(:all) do
        @canvas.masquerade_as @student_1
        @asset_library.load_asset_detail(@test, @asset_5)
        @asset_library.click_like_button
        @asset_library.wait_until(Utils.short_wait) { @asset_library.like_count == '1' }
        @student_1_activities[:asset_view][:count] += 1
        @teacher_activities[:get_asset_view][:count] += 1
        @student_1_activities[:asset_like][:count] += 1
        @teacher_activities[:get_asset_like][:count] += 1
      end

      context 'and the asset owner views its own profile' do
        before(:all) do
          @canvas.masquerade_as @teacher
          @impact_studio.load_page @test
        end
        it('adds My Impacts "Engagement" events') { @impact_studio.verify_event_drop_count @teacher_activities }
      end

      context 'and the asset owner views the other user\'s profile' do
        before(:all) { @impact_studio.select_user @student_1 }
        it('adds My Contributions "Engagement" events') { @impact_studio.verify_event_drop_count @student_1_activities }
      end
    end

    context '"remix whiteboard"' do

      before(:all) do
        @canvas.masquerade_as @teacher
        @asset_library.load_asset_detail(@test, @asset_4)
        @asset_library.remix @whiteboard.title
        @teacher_activities[:asset_view][:count] += 1
        @student_1_activities[:get_asset_view][:count] += 1
        @student_2_activities[:get_asset_view][:count] += 1
        @teacher_activities[:whiteboard_remix][:count] += 1
        @student_1_activities[:get_whiteboard_remix][:count] += 1
        @student_2_activities[:get_whiteboard_remix][:count] += 1
      end

      context 'and one whiteboard asset owner views its own profile' do
        before(:all) do
          @canvas.masquerade_as @student_1
          @impact_studio.load_page @test
        end
        it('adds My Impacts "Engagements" and "Creations" events') { @impact_studio.verify_event_drop_count @student_1_activities }
      end

      context 'and another whiteboard asset owner views its own profile' do
        before(:all) do
          @canvas.masquerade_as @student_2
          @impact_studio.load_page @test
        end
        it('adds My Impacts "Engagements" and "Creations" events') { @impact_studio.verify_event_drop_count @student_2_activities }
      end

      context 'and an asset owner views the remixer\'s profile' do
        before(:all) { @impact_studio.select_user @teacher }
        it('adds My Contributions "Engagements" and "Creations" events') { @impact_studio.verify_event_drop_count @teacher_activities }
      end
    end
  end

  context 'when assets impact their owners' do

    before(:all) { @canvas.masquerade_as @student_1 }

    context 'with "view" impact' do
      before(:all) do
        @asset_library.load_asset_detail(@test, @asset_4)
        @impact_studio.load_page @test
      end
      it('does not add My Contributions "Engagements" events') { @impact_studio.verify_event_drop_count @student_1_activities }
    end

    context 'with "comment" impact' do
      before(:all) do
        @asset_library.load_asset_detail(@test, @asset_4)
        @asset_library.add_comment @asset_4_comment
        @impact_studio.load_page @test
      end
      it('does not add My Contributions "Engagements" or "Interactions" events') { @impact_studio.verify_event_drop_count @student_1_activities }
    end

    context 'with "remix" impact' do
      before(:all) do
        @asset_library.load_asset_detail(@test, @asset_4)
        @asset_library.remix @whiteboard.title
        @impact_studio.load_page @test
      end

      it('does not add My Contributions "Engagements" or "Creations" events') { @impact_studio.verify_event_drop_count @student_1_activities }
    end
  end

  context 'when assets lose impact' do

    context '"comment"' do
      before(:all) do
        @canvas.masquerade_as @teacher
        @asset_library.load_asset_detail(@test, @asset_6)
        @asset_library.delete_comment @asset_6_reply
        @teacher_activities[:asset_view][:count] += 1
        @student_2_activities[:get_asset_view][:count] += 1
        @teacher_activities[:asset_comment][:count] -= 1
        @student_2_activities[:get_asset_comment][:count] -= 1
      end

      context 'and the comment deleter views its own profile' do
        before(:all) { @impact_studio.load_page @test }
        it('adds My Contributions "Engagements" and removes "Interactions" events') { @impact_studio.verify_event_drop_count @teacher_activities }
      end

      context 'and the comment deleter views the asset owner\'s profile' do
        before(:all) { @impact_studio.select_user @student_2 }
        it('adds My Impact "Engagements" and removes "Interactions" events') { @impact_studio.verify_event_drop_count @student_2_activities }
      end
    end

    context '"like"' do

      before(:all) do
        @canvas.masquerade_as @student_1
        @asset_library.load_asset_detail(@test, @asset_5)
        likes = @asset_library.like_count.to_i
        @asset_library.click_like_button
        @asset_library.wait_until(Utils.short_wait) { @asset_library.like_count.to_i == likes - 1 }
        sleep Utils.short_wait
        @student_1_activities[:asset_view][:count] += 1
        @teacher_activities[:get_asset_view][:count] += 1
        @student_1_activities[:asset_like][:count] -= 1
        @teacher_activities[:get_asset_like][:count] -= 1
      end

      context 'and the un-liker views its own profile' do
        before(:all) { @impact_studio.load_page @test }
        it('adds and removes My Contributions "Engagements" events') { @impact_studio.verify_event_drop_count @student_1_activities }
      end

      context 'and the un-liker views the asset owner\'s profile' do
        before(:all) { @impact_studio.select_user @teacher }
        it('adds and removes My Impact "Engagements" events') { @impact_studio.verify_event_drop_count @teacher_activities }
      end
    end
  end

  context 'when assets are deleted' do

    context 'before they have impact' do
      before(:all) do
        @asset_library.load_page @test
        @asset_library.add_link_asset @asset_7
        @asset_library.load_asset_detail(@test, @asset_7)
        @asset_library.delete_asset @asset_7
        @impact_studio.load_page @test
      end
      it('adds no My Contributions "Creations" event') { @impact_studio.verify_event_drop_count @student_2_activities }
    end

    context 'when they have impact' do
      before(:all) do
        @canvas.masquerade_as @teacher
        [@asset_1, @asset_3, @asset_4, @asset_5, @asset_6].each do |asset|
          @asset_library.load_asset_detail(@test, asset)
          @asset_library.delete_asset asset
        end
        @teacher_activities = @impact_studio.init_user_activities
        @student_1_activities = @impact_studio.init_user_activities
        @student_2_activities = @impact_studio.init_user_activities
      end

      context 'and a user views its own profile' do
        before(:all) { @impact_studio.load_page @test }
        it('removes My Contributions and My Impacts events') { @impact_studio.verify_event_drop_count @teacher_activities }
      end

      context 'and a user views another users\'s profile' do
        before(:all) { @impact_studio.select_user @student_1 }
        it('removes My Contributions and My Impacts events') { @impact_studio.verify_event_drop_count @student_1_activities }
      end

      context 'and a user views another users\'s profile' do
        before(:all) { @impact_studio.select_user @student_2 }
        it('removes My Contributions and My Impacts events') { @impact_studio.verify_event_drop_count @student_2_activities }
      end
    end
  end

  describe 'Canvas discussions' do

    before(:all) { @discussion = Discussion.new 'Discussion topic' }

    context 'when a new topic is created' do
      before(:all) do
        @canvas.masquerade_as @teacher
        @canvas.create_course_discussion(@test.course, @discussion)
        @teacher_activities[:discussion_topic][:count] += 1
      end
      it('adds a My Contributions "Interactions" event') { @impact_studio.verify_event_drop_count @teacher_activities }
    end

    context 'when an entry is added' do
      before(:all) do
        @canvas.masquerade_as @student_1
        @canvas.add_reply(@discussion, nil, 'Discussion entry')
        @student_1_activities[:discussion_entry][:count] += 1
      end
      it('adds a My Contributions "Interactions" event') { @impact_studio.verify_event_drop_count @student_1_activities }
    end

    context 'when a reply is added' do
      before(:all) do
        @canvas.masquerade_as @student_2
        @canvas.add_reply(@discussion, 0, 'Discussion reply')
        @student_2_activities[:discussion_entry][:count] += 1
        @student_1_activities[:get_discussion_entry_reply][:count] += 1
      end

      context 'and the replier views its own profile' do
        before(:all) { @impact_studio.load_page @test }
        it('adds a My Contributions "Interactions" event') { @impact_studio.verify_event_drop_count @student_2_activities }
      end

      context 'and the entry-creator views its own profile' do
        before(:all) do
          @canvas.masquerade_as @student_1
          @impact_studio.load_page @test
        end
        it('adds a My Impact "Interactions" event') { @impact_studio.verify_event_drop_count @student_1_activities }
      end
    end
  end
end
