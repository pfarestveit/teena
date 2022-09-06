require_relative '../../util/spec_helper'

describe 'The Impact Studio' do

  test = SquiggyTestConfig.new 'studio_assets'

  teacher = test.course.teachers[0]
  student_1 = test.course.students[0]
  student_2 = test.course.students[1]

  # Get test assets
  whiteboard = Whiteboard.new({ owner: student_1, title: "Whiteboard #{test_id}", collaborators: [student_2] })
  all_assets = []
  all_assets << (asset_1 = student_1.assets.find &:url)
  all_assets << (asset_2 = student_1.assets.select(&:file_name)[0])
  all_assets << (asset_3 = student_1.assets.select(&:file_name)[1])
  all_assets << (asset_4 = Asset.new({ title: whiteboard.title, type: 'Whiteboard' }))
  all_assets << (asset_5 = teacher.assets.find &:file_name)
  all_assets << (asset_6 = student_2.assets.find &:file_name)
  all_assets << (asset_7 = student_2.assets.find &:url)

  student_1_assets = [asset_4, asset_3, asset_2, asset_1]
  student_2_assets = [asset_7, asset_6, asset_4]
  teacher_assets = [asset_5]

  asset_4_comments = []
  asset_4_comment = SquiggyComment.new user: student_1,
                                       asset: asset_4,
                                       body: 'Impact-free comment'
  asset_6_comments = []
  asset_6_comment = SquiggyComment.new user: teacher,
                                       asset: asset_6,
                                       body: 'This is a comment from Teacher to Student 2'
  asset_6_reply = SquiggyComment.new user: teacher,
                                     asset: asset_6,
                                     body: 'This is another comment from Teacher to Student 2'

  before(:all) do
    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = SquiggyAssetLibraryDetailPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver
    @impact_studio = SquiggyImpactStudioPage.new @driver
    @whiteboards = SquiggyWhiteboardsPage.new @driver

    @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course test
    @engagement_index.wait_for_new_user_sync(test, test.course.roster)

    [student_1, student_2].each do |student|
      @canvas.masquerade_as student
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

      it('shows a "no assets" message under My Assets') { @impact_studio.no_user_assets_msg_element.when_visible Utils.short_wait }
      it('shows a "no assets" message under Everyone\'s Assets') { @impact_studio.no_everyone_assets_msg_element.when_visible Utils.short_wait }
      it('offers a Bookmarklet link under My Assets') { expect(@impact_studio.bookmarklet_link?).to be true }
      it('offers a link to create a new Link asset') { expect(@impact_studio.add_site_link?).to be true }
      it('offers a link to create a new File asset') { expect(@impact_studio.upload_link?).to be true }
    end

    context 'and a user views another user\'s profile' do

      before(:all) do
        @engagement_index.load_scores test
        @engagement_index.click_user_dashboard_link student_2
      end

      it('shows a "no assets" message under Assets') { @impact_studio.no_user_assets_msg_element.when_visible Utils.short_wait }
      it('shows no Everyone\'s Assets UI') { expect(@impact_studio.everyone_assets_heading?).to be false }
      it('offers no Bookmarklet link under Assets') { expect(@impact_studio.bookmarklet_link?).to be false }
      it('offers no Add Link link under Assets') { expect(@impact_studio.add_site_link?).to be false }
      it('offers no Upload link under Assets') { expect(@impact_studio.upload_link?).to be false }
    end
  end

  context 'when assets are contributed' do

    before(:all) do
      @canvas.masquerade_as student_1
      @impact_studio.load_page test
      @impact_studio.add_site asset_1

      @whiteboards.load_page test
      @whiteboards.create_and_open_whiteboard whiteboard
      @whiteboards.add_asset_exclude_from_library asset_2

      @whiteboards.add_asset_include_in_library asset_3

      @whiteboards.export_to_asset_library whiteboard
      asset_4 = whiteboard.asset_exports.first
      @whiteboards.close_whiteboard

      @canvas.masquerade_as teacher
      @impact_studio.load_page test
      @impact_studio.add_file asset_5

      @canvas.masquerade_as student_2
      @asset_library.load_page test
      @asset_library.upload_file_asset asset_6

      @asset_library.add_site asset_7
      @asset_library.load_asset_detail(test, asset_7)
      @asset_library.delete_asset asset_7
    end

    context 'and a user views its own profile' do

      before(:all) do
        @canvas.masquerade_as student_1
        @impact_studio.load_page test
      end

      it 'shows the user\'s non-hidden assets under My Assets > Recent' do
        @impact_studio.verify_user_recent_assets(student_1_assets, student_1)
      end

      it 'allows the user to click an asset in My Assets > Recent to view its detail' do
        @impact_studio.click_user_asset_link asset_1
        @asset_library.wait_for_asset_detail
      end

      it 'allows the user to return to its own Impact Studio profile from an asset\'s detail' do
        @asset_library.go_back_to_impact_studio
        @impact_studio.verify_user_recent_assets(student_1_assets, student_1)
      end

      it 'shows all the most recent assets under Community Assets > Recent' do
        @impact_studio.verify_all_recent_assets all_assets
      end

      # TODO - most viewed, most liked, most commented
    end

    context 'and a user views another user\'s profile' do

      before(:all) do
        @engagement_index.load_scores test
        @engagement_index.click_user_dashboard_link student_2
      end

      it 'shows the other user\'s non-hidden assets under Assets > Recent' do
        @impact_studio.verify_user_recent_assets(student_2_assets, student_2)
      end

      it 'shows no Everyone\'s Assets UI' do
        expect(@impact_studio.everyone_assets_heading?).to be false
      end

      # TODO - most viewed, most liked, most commented
    end
  end

  context 'when assets have activity' do

    context '"view asset"' do

      before(:all) do
        @canvas.masquerade_as teacher
        @asset_library.load_asset_detail(test, asset_3)
      end

      context 'and the asset owner views its own profile' do

        before(:all) do
          @canvas.masquerade_as student_1
          @impact_studio.load_page test
        end

        it 'shows the user\'s non-hidden assets under My Assets > Recent' do
          @impact_studio.verify_user_recent_assets(student_1_assets, student_1)
        end

        it 'shows all the most recent assets under Community Assets > Recent' do
          @impact_studio.verify_all_recent_assets all_assets
        end

        # TODO - most viewed, most liked, most commented
      end
    end

    context '"comment"' do

      before(:all) do
        @canvas.masquerade_as teacher
        @asset_library.load_asset_detail(test, asset_6)
        @asset_library.add_comment asset_6_comment
      end

      context 'and the asset owner views its own profile' do

        before(:all) do
          @canvas.masquerade_as student_2
          @impact_studio.load_page test
        end

        it 'shows the user\'s non-hidden assets under My Assets > Recent' do
          @impact_studio.verify_user_recent_assets(student_2_assets, student_2)
        end

        it 'shows all the most recent assets under Community Assets > Recent' do
          @impact_studio.verify_all_recent_assets all_assets
        end

        # TODO - most viewed, most liked, most commented
      end
    end

    context '"comment reply"' do

      before(:all) do
        @canvas.masquerade_as teacher
        @asset_library.load_asset_detail(test, asset_6)
        @asset_library.reply_to_comment(asset_6_comment, asset_6_reply)
      end

      context 'and the asset owner views its own profile' do

        before(:all) do
          @canvas.masquerade_as student_2
          @impact_studio.load_page test
        end

        it 'shows the user\'s non-hidden assets under My Assets > Recent' do
          @impact_studio.verify_user_recent_assets(student_2_assets, student_2)
        end

        it 'shows all the most recent assets under Community Assets > Recent' do
          @impact_studio.verify_all_recent_assets all_assets
        end

        # TODO - most viewed, most liked, most commented
      end
    end

    context '"like"' do

      before(:all) do
        @canvas.masquerade_as student_1
        @asset_library.load_asset_detail(test, asset_5)
        @asset_library.click_like_button
      end

      context 'and the asset owner views its own profile' do

        before(:all) do
          @canvas.masquerade_as teacher
          @impact_studio.load_page test
        end

        it 'shows the user\'s non-hidden assets under My Assets > Recent' do
          @impact_studio.verify_user_recent_assets(teacher_assets, teacher)
        end

        it 'shows all the most recent assets under Community Assets > Recent' do
          @impact_studio.verify_all_recent_assets all_assets
        end

        # TODO - most viewed, most liked, most commented
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

      # TODO - most viewed, most liked, most commented
    end

    context 'with "comment" impact' do

      before(:all) do
        @asset_library.load_asset_detail(test, asset_4)
        @asset_library.add_comment asset_4_comment
        @impact_studio.load_page test
      end

      # TODO - most viewed, most liked, most commented
    end
  end

  context 'when assets lose impact' do

    context '"comment"' do

      before(:all) do
        @canvas.masquerade_as teacher
        @asset_library.load_asset_detail(test, asset_6)
        @asset_library.delete_comment asset_6_reply
      end

      context 'and the comment deleter views its own profile' do

        before(:all) { @impact_studio.load_page test }

        # TODO - most viewed, most liked, most commented
      end

      context 'and the comment deleter views the asset owner\'s profile' do

        before(:all) { @impact_studio.search_for_user student_2 }

        # TODO - most viewed, most liked, most commented
      end
    end

    context '"like"' do

      before(:all) do
        @canvas.masquerade_as student_1
        @asset_library.load_asset_detail(test, asset_5)
        @asset_library.click_like_button
      end

      context 'and the un-liker views its own profile' do

        before(:all) { @impact_studio.load_page test }

        # TODO - most viewed, most liked, most commented
      end

      context 'and the un-liker views the asset owner\'s profile' do

        before(:all) { @impact_studio.search_for_user teacher }

        # TODO - most viewed, most liked, most commented
      end
    end
  end
end
