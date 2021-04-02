require_relative '../../util/spec_helper'

describe 'Asset' do

  before(:all) do
    @test = SquiggyTestConfig.new 'asset_reactions'
    @test.course.site_id = ENV['COURSE_ID']
    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net= Page::CalNetPage.new @driver
    @assets_list = SquiggyAssetLibraryListViewPage.new @driver
    @asset_detail = SquiggyAssetLibraryDetailPage.new @driver
    @manage_assets = SquiggyAssetLibraryManageAssetsPage.new @driver

    @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course @test

    @canvas.masquerade_as(@test.teachers.first, @test.course)

    @student_1 = @test.students[0]
    @student_2 = @test.students[1]
    @asset = @student_1.assets.find &:file_name
    @comment_1_by_uploader = SquiggyComment.new user: @student_1, body: "#{@test.id} Uploader makes Comment 1"
    @comment_1_reply_by_uploader = SquiggyComment.new user: @student_1, body: "#{@test.id} Uploader replies to own Comment 1"
    @comment_1_reply_by_viewer = SquiggyComment.new user: @student_2, body: "#{@test.id} Viewer replies to uploader\'s Comment 1"
    @comment_2_by_viewer = SquiggyComment.new user: @student_2, body: "#{@test.id} Viewer makes Comment 2"
    @comment_2_reply_by_viewer = SquiggyComment.new user: @student_2, body: "#{@test.id} Viewer replies to own Comment 2"
    @comment_link = 'www.google.com'
    @comment_3_by_viewer = SquiggyComment.new user: @student_2, body: "#{@test.id} Viewer makes Comment 3 with link to #{@comment_link}"
    @date = Date.today.strftime('%B %-d, %Y')

    # Upload a new asset for the test
    @canvas.masquerade_as(@student_1, @test.course)
    @assets_list.load_page @test
    @assets_list.upload_file_asset @asset
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'likes' do

    context 'when the user is the asset creator' do
      it 'cannot be added on the list view'
      it 'cannot be added on the detail view'
    end

    context 'when the user is not the asset creator' do
      it 'cannot be added on the list view'
    end

    context 'when added on the detail view' do
      it 'increase the asset\'s total likes'
      it 'earn Engagement Index "like" points for the liker'
      it 'earn Engagement Index "get_like" points for the asset creator'
      it 'add the liker\'s "like" activity to the activities csv'
      it 'add the asset creator\'s "get_like" activity to the activities csv'
    end

    context 'when removed on the detail view' do
      it 'decrease the asset\'s total likes'
      it 'remove Engagement Index "like" points from the un-liker'
      it 'remove Engagement Index "get_like" points from the asset creator'
      it 'remove the un-liker\'s "like" activity from the activities csv'
      it 'remove the asset creator\'s "get_like" activity from the activities csv'
    end
  end

  describe 'comments' do

    context 'by the asset uploader' do

      before(:all) { @canvas.masquerade_as(@student_1, @test.course) }

      context 'added as a top level comment' do

        before(:all) do
          @assets_list.load_page @test
          @assets_list.click_asset_link @asset
          # TODO - load asset detail to verify bookmark-able
          @visible_comment = @asset_detail.add_comment @comment_1_by_uploader
        end

        it('show the commenter name') { expect(@visible_comment[:commenter]).to eql("#{@student_1.full_name} on #{@date}") }
        it('show the comment body') { expect(@visible_comment[:body]).to eql(@comment_1_by_uploader.body) }
        it('increment the comment count on the detail view') { expect(@asset_detail.visible_asset_metadata[:comment_count]).to eql(1.to_s) }
        it 'increment the comment count on the list view' do
          @asset_detail.click_back_to_asset_library
          expect(@assets_list.visible_list_view_asset_data(@asset)[:comment_count]).to eql(1.to_s)
        end
      end

      context 'added as a reply to the user\'s own comment' do

        before(:all) do
          @assets_list.click_asset_link @asset
          @visible_comment = @asset_detail.reply_to_comment(@comment_1_by_uploader, @comment_1_reply_by_uploader)
        end

        it('show the commenter name') { expect(@visible_comment[:commenter]).to eql("#{@student_1.full_name} on #{@date}") }
        it('show the comment body') { expect(@visible_comment[:body]).to eql(@comment_1_reply_by_uploader.body) }
        it('increment the comment count on the detail view') { expect(@asset_detail.visible_asset_metadata[:comment_count]).to eql(2.to_s) }
        it 'increment the comment count on the list view' do
          @asset_detail.click_back_to_asset_library
          expect(@assets_list.visible_list_view_asset_data(@asset)[:comment_count]).to eql(2.to_s)
        end
      end

      # TODO it 'does not earn commenting points on the engagement index'
    end

    context 'by a user who is not the asset creator' do

      before(:all) { @canvas.masquerade_as(@student_2, @test.course) }

      context 'added as a top level comment' do

        before(:all) do
          @assets_list.click_asset_link @asset
          @visible_comment = @asset_detail.add_comment @comment_2_by_viewer
        end

        it('show the commenter name') { expect(@visible_comment[:commenter]).to eql("#{@student_2.full_name} on #{@date}") }
        it('show the comment body') { expect(@visible_comment[:body]).to eql(@comment_2_by_viewer.body) }
        it('increment the comment count on the detail view') { expect(@asset_detail.visible_asset_metadata[:comment_count]).to eql(3.to_s) }
        it 'increment the comment count on the list view' do
          @asset_detail.click_back_to_asset_library
          expect(@assets_list.visible_list_view_asset_data(@asset)[:comment_count]).to eql(3.to_s)
        end
      end

      context 'added as a reply to the user\'s own comment' do

        before(:all) do
          @assets_list.click_asset_link @asset
          @visible_comment = @asset_detail.reply_to_comment(@comment_2_by_viewer, @comment_2_reply_by_viewer)
        end

        it('show the commenter name') { expect(@visible_comment[:commenter]).to eql("#{@student_2.full_name} on #{@date}") }
        it('show the comment body') { expect(@visible_comment[:body]).to eql(@comment_2_reply_by_viewer.body) }
        it('increment the comment count on the detail view') { expect(@asset_detail.visible_asset_metadata[:comment_count]).to eql(4.to_s) }
        it 'increment the comment count on the list view' do
          @asset_detail.click_back_to_asset_library
          expect(@assets_list.visible_list_view_asset_data(@asset)[:comment_count]).to eql(4.to_s)
        end
      end

      context 'added as a reply to another user\'s comment' do

        before(:all) do
          @assets_list.click_asset_link @asset
          @visible_comment = @asset_detail.reply_to_comment(@comment_1_by_uploader, @comment_1_reply_by_viewer)
        end

        it('show the commenter name') { expect(@visible_comment[:commenter]).to eql("#{@student_2.full_name} on #{@date}") }
        it('show the comment body') { expect(@visible_comment[:body]).to eql(@comment_1_reply_by_viewer.body) }
        it('increment the comment count on the detail view') { expect(@asset_detail.visible_asset_metadata[:comment_count]).to eql(5.to_s) }
        it 'increment the comment count on the list view' do
          @asset_detail.click_back_to_asset_library
          expect(@assets_list.visible_list_view_asset_data(@asset)[:comment_count]).to eql(5.to_s)
        end
      end

      # TODO it 'earns "Comment" points on the engagement index for the user adding a comment or reply'
      # TODO it 'earns "Receive a Comment" points on the engagement index for the user receiving the comment or reply'
      # TODO it 'shows "Comment" activity on the CSV export for the user adding the comment or reply'
      # TODO it 'shows "Receive a Comment" activity on the CSV export for the user receiving the comment or reply'
    end

    context 'by any user' do

      it 'can include a link that opens in a new browser window' do
        @assets_list.click_asset_link @asset
        @asset_detail.add_comment @comment_3_by_viewer
        expect(@asset_detail.external_link_valid?(@asset_detail.link_element(text: @comment_link), 'Google')).to be true
      end

      it('cannot be added as a reply to a reply') { expect(@asset_detail.reply_button_el @comment_1_reply_by_uploader).to be_nil }

      it 'can be canceled when a reply' do
        @asset_detail.click_reply_button @comment_3_by_viewer
        @asset_detail.click_cancel_reply @comment_3_by_viewer
      end
    end

    describe 'edit' do

      it 'can be done by the user who created the comment' do
        @comment_1_by_uploader.body = "#{@comment_1_by_uploader.body} - EDITED"
        @canvas.masquerade_as(@student_1, @test.course)
        @assets_list.load_page @test
        @assets_list.click_asset_link @asset
        @asset_detail.edit_comment @comment_1_by_uploader
      end

      it('cannot be done by a user who did not create the comment') do
        expect(@asset_detail.edit_button(@comment_2_by_viewer).exists?).to be false
      end

      it 'can be done to any comment when the user is a teacher' do
        @comment_2_by_viewer.body = "#{@comment_2_by_viewer.body} - EDITED"
        @canvas.masquerade_as(@test.teachers.first, @test.course)
        @assets_list.load_page @test
        @assets_list.click_asset_link @asset
        @asset_detail.edit_comment @comment_2_by_viewer
      end

      it 'can be canceled' do
        @asset_detail.click_edit_button @comment_2_by_viewer
        @asset_detail.click_cancel_edit_button
      end

      # TODO it 'does not alter existing engagement scores'
    end

    describe 'deletion' do

      it 'can be done by a student who created the comment' do
        @canvas.masquerade_as(@student_1, @test.course)
        @assets_list.load_page @test
        @assets_list.click_asset_link @asset
        @asset_detail.delete_comment @comment_1_reply_by_uploader
      end

      it 'cannot be done by a student who did not create the comment' do
        expect(@asset_detail.delete_comment_button(@comment_1_reply_by_viewer).exists?).to be false
      end

      it 'can be done by a teacher if the comment has no replies' do
        @canvas.masquerade_as(@test.teachers.first, @test.course)
        @assets_list.load_page @test
        @assets_list.click_asset_link @asset
        @asset_detail.delete_comment @comment_3_by_viewer
      end

      it 'cannot be done by a teacher if the comment has replies' do
        expect(@asset_detail.delete_comment_button(@comment_1_by_uploader).exists?).to be false
      end

      # TODO it 'removes engagement index points earned for the comment'
    end
  end

  describe 'views' do
    it 'are only incremented when viewed by users other than the asset creator'
  end
end