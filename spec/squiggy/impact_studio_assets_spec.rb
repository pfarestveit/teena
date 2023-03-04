require_relative '../../util/spec_helper'

describe 'The Impact Studio' do

  test = SquiggyTestConfig.new 'studio_assets'

  teacher = test.teachers[0]
  student_1 = test.students[0]
  student_2 = test.students[1]

  whiteboard = SquiggyWhiteboard.new({ owner: student_1, title: "Whiteboard #{test.id}", collaborators: [student_2] })
  all_assets = []
  all_assets << (asset_1 = student_1.assets.find &:url)
  all_assets << (asset_2 = student_1.assets.select(&:file_name)[0])
  all_assets << (asset_3 = student_1.assets.select(&:file_name)[1])
  all_assets << (asset_4 = SquiggyAsset.new title: whiteboard.title)
  all_assets << (asset_5 = teacher.assets.find &:url)
  all_assets << (asset_6 = student_2.assets.find &:file_name)
  all_assets << (asset_7 = student_2.assets.find &:url)

  student_1_assets = [asset_4, asset_3, asset_2, asset_1]
  student_2_assets = [asset_7, asset_6, asset_4]
  teacher_assets = [asset_5]

  asset_4_comment = SquiggyComment.new user: student_1,
                                       asset: asset_4,
                                       body: "Impact-free comment #{test.id}"

  asset_6_comment = SquiggyComment.new user: teacher,
                                       asset: asset_6,
                                       body: "This is a comment from Teacher to Student 2 #{test.id}"
  asset_6_reply = SquiggyComment.new user: teacher,
                                     asset: asset_6,
                                     body: "This is another comment from Teacher to Student 2 #{test.id}"

  before(:all) do
    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = SquiggyAssetLibraryDetailPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver
    @impact_studio = SquiggyImpactStudioPage.new @driver
    @whiteboards = SquiggyWhiteboardPage.new @driver

    @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course test
    @engagement_index.wait_for_new_user_sync(test, test.course.roster)

    [student_1, student_2].each do |student|
      @canvas.masquerade_as(student, test.course)
      @engagement_index.load_page test
      @engagement_index.share_score
    end
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when no assets exist' do

    context 'and a user views its own profile' do

      before(:all) do
        @canvas.masquerade_as student_1
        @impact_studio.load_page test
      end

      it('shows a "no assets" message under My Assets') { @impact_studio.wait_for_no_user_asset_results }
      it('shows a "no assets" message under Everyone\'s Assets') { @impact_studio.wait_for_no_everyone_asset_results }
    end

    context 'and a user views another user\'s profile' do

      before(:all) do
        @engagement_index.load_scores test
        @engagement_index.click_user_dashboard_link(test, student_2)
      end

      it('shows a "no assets" message under Assets') { @impact_studio.wait_for_no_user_asset_results }
      it('shows no Everyone\'s Assets UI') { expect(@impact_studio.everyone_assets_heading?).to be false }
    end
  end

  context 'when assets are contributed' do

    before(:all) do
      @canvas.masquerade_as student_1
      @asset_library.load_page test
      @asset_library.add_link_asset asset_1
      @whiteboards.load_page test
      @whiteboards.create_and_open_whiteboard whiteboard
      @whiteboards.add_asset_exclude_from_library asset_2
      @whiteboards.add_asset_include_in_library asset_3
      @whiteboards.export_to_asset_library whiteboard
      asset_4.id = whiteboard.asset_exports.first.id
      @whiteboards.close_whiteboard

      @canvas.masquerade_as(teacher, test.course)
      @asset_library.load_page test
      @asset_library.add_link_asset asset_5

      @canvas.masquerade_as student_2
      @asset_library.load_page test
      @asset_library.upload_file_asset asset_6
      @asset_library.add_link_asset asset_7
      @asset_library.load_asset_detail(test, asset_7)
      @asset_library.delete_asset asset_7
    end

    context 'and a user views its own profile' do

      before(:all) do
        @canvas.masquerade_as student_1
        @impact_studio.load_page test
      end

      it 'shows user most recent assets under My Assets' do
        @impact_studio.wait_for_user_asset_results @impact_studio.assets_most_recent(student_1_assets)
      end

      it 'allows the user to click an asset in My Assets to view its detail' do
        @impact_studio.click_user_asset_link asset_1
        @asset_library.wait_for_asset_detail
      end

      it 'allows the user to return to its own Impact Studio profile from an asset\'s detail' do
        @asset_library.click_back_to_impact_studio
        @impact_studio.wait_for_user_asset_results @impact_studio.assets_most_recent(student_1_assets)
      end

      it 'sorts user assets by most likes' do
        @impact_studio.sort_user_assets 'Most likes'
        @impact_studio.wait_for_user_asset_results @impact_studio.assets_most_liked(student_1_assets)
      end

      it 'sorts user assets by most views' do
        @impact_studio.sort_user_assets 'Most views'
        @impact_studio.wait_for_user_asset_results @impact_studio.assets_most_viewed(student_1_assets)
      end

      it 'sorts user assets by most comments' do
        @impact_studio.sort_user_assets 'Most comments'
        @impact_studio.wait_for_user_asset_results @impact_studio.assets_most_commented(student_1_assets)
      end

      it 'shows everyone most recent non-hidden assets under Community Assets' do
        @impact_studio.wait_for_everyone_asset_results @impact_studio.assets_most_recent(all_assets)
      end

      it 'allows the user to click an asset in Everyone\'s Assets to view its detail' do
        @impact_studio.click_user_asset_link asset_3
        @asset_library.wait_for_asset_detail
      end

      it 'allows the user to return to its own Impact Studio profile from asset detail' do
        @asset_library.click_back_to_impact_studio
        @impact_studio.wait_for_user_asset_results @impact_studio.assets_most_recent(student_1_assets)
      end

      it 'sorts everyone assets by most likes' do
        @impact_studio.sort_everyone_assets 'Most likes'
        @impact_studio.wait_for_everyone_asset_results @impact_studio.assets_most_liked(all_assets)
      end

      it 'sorts everyone assets by most views' do
        @impact_studio.sort_everyone_assets 'Most views'
        @impact_studio.wait_for_everyone_asset_results @impact_studio.assets_most_viewed(all_assets)
      end

      it 'sorts everyone assets by most comments' do
        @impact_studio.sort_everyone_assets 'Most comments'
        @impact_studio.wait_for_everyone_asset_results @impact_studio.assets_most_commented(all_assets)
      end
    end

    context 'and a user views another user\'s profile' do

      before(:all) do
        @engagement_index.load_scores test
        @engagement_index.click_user_dashboard_link(test, student_2)
      end

      it 'shows the other user most recent assets' do
        @impact_studio.wait_for_user_asset_results @impact_studio.assets_most_recent(student_2_assets)
      end

      it 'sorts user assets by most likes' do
        @impact_studio.sort_user_assets 'Most likes'
        @impact_studio.wait_for_user_asset_results @impact_studio.assets_most_liked(student_2_assets)
      end

      it 'sorts user assets by most views' do
        @impact_studio.sort_user_assets 'Most views'
        @impact_studio.wait_for_user_asset_results @impact_studio.assets_most_viewed(student_2_assets)
      end

      it 'sorts user assets by most comments' do
        @impact_studio.sort_user_assets 'Most comments'
        @impact_studio.wait_for_user_asset_results @impact_studio.assets_most_commented(student_2_assets)
      end

      it 'shows no Everyone Assets UI' do
        expect(@impact_studio.everyone_assets_heading?).to be false
      end
    end
  end

  context 'when assets have activity' do

    context '"view asset"' do

      before(:all) do
        @canvas.masquerade_as teacher
        @asset_library.load_asset_detail(test, asset_3)
        asset_3.count_views += 1
      end

      context 'and the asset owner views its own profile' do

        before(:all) do
          @canvas.masquerade_as student_1
          @impact_studio.load_page test
        end

        it 'shows the user most viewed assets' do
          @impact_studio.sort_user_assets 'Most views'
          @impact_studio.wait_for_user_asset_results @impact_studio.assets_most_viewed(student_1_assets)
        end

        it 'shows everyone most viewed assets' do
          @impact_studio.sort_everyone_assets 'Most views'
          @impact_studio.wait_for_everyone_asset_results @impact_studio.assets_most_viewed(all_assets)
        end
      end
    end

    context '"comment"' do

      before(:all) do
        @canvas.masquerade_as teacher
        @asset_library.load_asset_detail(test, asset_6)
        @asset_library.add_comment asset_6_comment
        asset_6.count_views += 1
        asset_6.comments << asset_6_comment
      end

      context 'and the asset owner views its own profile' do

        before(:all) do
          @canvas.masquerade_as student_2
          @impact_studio.load_page test
        end

        it 'shows the user most commented assets' do
          @impact_studio.sort_user_assets 'Most comments'
          @impact_studio.wait_for_user_asset_results @impact_studio.assets_most_commented(student_2_assets)
        end

        it 'shows everyone most commented assets' do
          @impact_studio.sort_everyone_assets 'Most comments'
          @impact_studio.wait_for_everyone_asset_results @impact_studio.assets_most_commented(all_assets)
        end
      end
    end

    context '"comment reply"' do

      before(:all) do
        @canvas.masquerade_as teacher
        @asset_library.load_asset_detail(test, asset_6)
        @asset_library.reply_to_comment(asset_6_comment, asset_6_reply)
        asset_6.count_views += 1
        asset_6.comments << asset_6_reply
      end

      context 'and the asset owner views its own profile' do

        before(:all) do
          @canvas.masquerade_as student_2
          @impact_studio.load_page test
        end

        it 'shows the user most commented assets' do
          @impact_studio.sort_user_assets 'Most comments'
          @impact_studio.wait_for_user_asset_results @impact_studio.assets_most_commented(student_2_assets)
        end

        it 'shows everyone most commented assets' do
          @impact_studio.sort_everyone_assets 'Most comments'
          @impact_studio.wait_for_everyone_asset_results @impact_studio.assets_most_commented(all_assets)
        end
      end
    end

    context '"like"' do

      before(:all) do
        @canvas.masquerade_as student_1
        @asset_library.load_asset_detail(test, asset_5)
        @asset_library.click_like_button
        asset_5.count_views += 1
        asset_5.count_likes += 1
      end

      context 'and the asset owner views its own profile' do

        before(:all) do
          @canvas.masquerade_as teacher
          @impact_studio.load_page test
        end

        it 'shows the user most commented assets' do
          @impact_studio.sort_user_assets 'Most likes'
          @impact_studio.wait_for_user_asset_results @impact_studio.assets_most_liked(teacher_assets)
        end

        it 'shows everyone most commented assets' do
          @impact_studio.sort_everyone_assets 'Most likes'
          @impact_studio.wait_for_everyone_asset_results @impact_studio.assets_most_liked(all_assets)
        end
      end
    end
  end

  context 'when assets impact their owners' do

    before(:all) { @canvas.masquerade_as student_1 }

    context 'with "view" impact' do

      before(:all) do
        @asset_library.load_asset_detail(test, asset_4)
        @impact_studio.load_page test
      end

      it 'does not alter the user most viewed assets' do
        @impact_studio.sort_user_assets 'Most views'
        @impact_studio.wait_for_user_asset_results @impact_studio.assets_most_viewed(student_1_assets)
      end

      it 'does not alter everyone most viewed assets' do
        @impact_studio.sort_everyone_assets 'Most views'
        @impact_studio.wait_for_everyone_asset_results @impact_studio.assets_most_viewed(all_assets)
      end
    end

    context 'with "comment" impact' do

      before(:all) do
        @asset_library.load_asset_detail(test, asset_4)
        @asset_library.add_comment asset_4_comment
        asset_4.comments << asset_4_comment
        @impact_studio.load_page test
      end

      it 'updates the user most commented assets' do
        @impact_studio.sort_user_assets 'Most comments'
        @impact_studio.wait_for_user_asset_results @impact_studio.assets_most_commented(student_1_assets)
      end

      it 'does not alter everyone most commented assets' do
        @impact_studio.sort_everyone_assets 'Most comments'
        @impact_studio.wait_for_everyone_asset_results @impact_studio.assets_most_commented(all_assets)
      end
    end
  end

  context 'when assets lose impact' do

    context '"comment"' do

      before(:all) do
        @canvas.masquerade_as teacher
        @asset_library.load_asset_detail(test, asset_6)
        @asset_library.delete_comment asset_6_reply
        asset_6.count_views += 1
        asset_6.comments.delete asset_6_reply
      end

      context 'and the comment deleter views the asset owner profile' do

        before(:all) do
          @impact_studio.load_page test
          @impact_studio.select_user student_2
        end

        it 'updates the user most commented assets' do
          @impact_studio.sort_user_assets 'Most comments'
          @impact_studio.wait_for_user_asset_results @impact_studio.assets_most_commented(student_2_assets)
        end
      end
    end

    context '"like"' do

      before(:all) do
        @canvas.masquerade_as student_1
        @asset_library.load_asset_detail(test, asset_5)
        @asset_library.click_like_button
        asset_5.count_views += 1
        asset_5.count_likes -= 1
      end

      context 'and the un-liker views the asset owner profile' do

        before(:all) do
          @impact_studio.load_page test
          @impact_studio.select_user teacher
        end

        it 'updates the user most commented assets' do
          @impact_studio.sort_user_assets 'Most likes'
          @impact_studio.wait_for_user_asset_results @impact_studio.assets_most_liked(teacher_assets)
        end
      end
    end
  end

  context 'when there are more than 4 Everyone Assets' do

    before(:all) { @impact_studio.select_user student_1 }

    it 'a link to the Asset Library is shown' do
      @impact_studio.click_view_all_assets
      @asset_library.wait_until(Utils.short_wait) { @asset_library.title == 'Asset Library' }
      @asset_library.wait_for_assets test
    end
  end
end
