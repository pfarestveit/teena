require_relative '../../util/spec_helper'

describe 'An asset' do

  before(:all) do
    @test = SquiggyTestConfig.new 'asset_reactions'
    @test.course.site_id = ENV['COURSE_ID']
    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net= Page::CalNetPage.new @driver
    @assets_list = SquiggyAssetLibraryListViewPage.new @driver
    @asset_detail = SquiggyAssetLibraryDetailPage.new @driver
    @manage_assets = SquiggyAssetLibraryManageAssetsPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver

    @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course @test

    @teacher = @test.teachers.first
    @student_1 = @test.students[0]
    @student_2 = @test.students[1]
    @asset = @student_1.assets.find &:file_name
    @comment_1_by_uploader = SquiggyComment.new user: @student_1
    @comment_1_reply_by_uploader = SquiggyComment.new user: @student_1
    @comment_1_reply_by_viewer = SquiggyComment.new user: @student_2
    @comment_2_by_viewer = SquiggyComment.new user: @student_2
    @comment_2_reply_by_viewer = SquiggyComment.new user: @student_2
    @comment_3_by_viewer = SquiggyComment.new user: @student_2
    @comment_link = 'www.google.com'
    @comment_3_by_viewer.body += " #{@comment_link}"
    @date = Date.today.strftime('%B %-d, %Y')

    # Upload a new asset for the test
    @canvas.masquerade_as(@student_1, @test.course)
    @assets_list.load_page @test
    @assets_list.upload_file_asset @asset
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'view count' do

    it 'is not incremented when viewed by the asset creator' do
      @assets_list.load_page @test
      @assets_list.click_asset_link @asset
      expect(@asset_detail.visible_asset_metadata(@asset)[:view_count]).to eql('0')
    end

    it 'is incremented when viewed by a user other than the asset creator' do
      @canvas.masquerade_as(@student_2, @test.course)
      @asset_detail.load_asset_detail(@test, @asset)
      expect(@asset_detail.visible_asset_metadata(@asset)[:view_count]).to eql('1')
      @asset_detail.click_back_to_asset_library
      expect(@assets_list.visible_list_view_asset_data(@asset)[:view_count]).to eql('1')
    end

    it 'is incremented when viewed again by a user other than the asset creator' do
      @assets_list.click_asset_link @asset
      expect(@asset_detail.visible_asset_metadata(@asset)[:view_count]).to eql('2')
      @asset_detail.click_back_to_asset_library
      expect(@assets_list.visible_list_view_asset_data(@asset)[:view_count]).to eql('2')
    end
  end

  describe 'like' do

    it 'cannot be added by the asset creator' do
      @canvas.masquerade_as(@student_1, @test.course)
      @assets_list.load_page @test
      @assets_list.click_asset_link @asset
      @asset_detail.wait_for_asset_detail
      expect(@asset_detail.like_button?).to be false
    end

    context 'when added' do

      before(:all) do
        @canvas.stop_masquerading
        @student_1.score = @engagement_index.user_score(@test, @student_1)
        @student_2.score = @engagement_index.user_score(@test, @student_2)

        @canvas.masquerade_as(@student_2, @test.course)
        @asset_detail.load_asset_detail(@test, @asset)
        @asset_detail.click_like_button
      end

      it('increases the asset\'s total likes') { expect(@asset_detail.visible_asset_metadata(@asset)[:like_count]).to eql('1') }

      it 'earns Engagement Index "like" points for the liker' do
        @canvas.stop_masquerading
        expect(@engagement_index.user_score(@test, @student_2)).to eql(@student_2.score + SquiggyActivity::LIKE.points)
      end

      it 'earns Engagement Index "get_like" points for the asset creator' do
        expect(@engagement_index.user_score(@test, @student_1)).to eql(@student_1.score + SquiggyActivity::GET_LIKE.points)
      end

      it 'adds the liker\'s "like" activity  and the likee\'s "liked" activity to the activities csv' do
        csv = @engagement_index.download_csv @test
        give = csv.find do |r|
          r[:user_name] == @student_2.full_name &&
            r[:action] == SquiggyActivity::LIKE.type &&
            r[:score] == SquiggyActivity::LIKE.points &&
            r[:running_total] == (@student_2.score + SquiggyActivity::LIKE.points)
        end
        get = csv.find do |r|
          r[:user_name] == @student_1.full_name &&
            r[:action] == SquiggyActivity::GET_LIKE.type &&
            r[:score] == SquiggyActivity::GET_LIKE.points &&
            r[:running_total] == (@student_1.score + SquiggyActivity::GET_LIKE.points)
        end
        expect(give).to be_truthy
        expect(get).to be_truthy
      end
    end

    context 'when removed' do

      before(:all) do
        @canvas.masquerade_as(@student_2, @test.course)
        @assets_list.load_page @test
        @assets_list.click_asset_link @asset
        @asset_detail.click_like_button
      end

      it('decreases the asset\'s total likes') { expect(@asset_detail.visible_asset_metadata(@asset)[:like_count]).to eql('0') }

      it 'removes Engagement Index "like" points from the un-liker' do
        @canvas.stop_masquerading
        expect(@engagement_index.user_score(@test, @student_2)).to eql(@student_2.score)
      end

      it 'removes Engagement Index "get_like" points from the asset creator' do
        expect(@engagement_index.user_score(@test, @student_1)).to eql(@student_1.score)
      end

      it 'removes the liker\'s "like" activity  and the likee\'s "liked" activity from the activities csv' do
        csv = @engagement_index.download_csv @test
        give = csv.find do |r|
          r[:user_name] == @student_2.full_name &&
            r[:action] == SquiggyActivity::LIKE.type &&
            r[:score] == SquiggyActivity::LIKE.points &&
            r[:running_total] == (@student_2.score + SquiggyActivity::LIKE.points)
        end
        get = csv.find do |r|
          r[:user_name] == @student_1.full_name &&
            r[:action] == SquiggyActivity::GET_LIKE.type &&
            r[:score] == SquiggyActivity::GET_LIKE.points &&
            r[:running_total] == (@student_1.score + SquiggyActivity::GET_LIKE.points)
        end
        expect(give).to be_falsey
        expect(get).to be_falsey
      end
    end
  end

  describe 'comment' do

    context 'by the asset uploader' do

      context 'added as a top level comment' do

        before(:all) do
          @student_1.score = @engagement_index.user_score(@test, @student_1)

          @canvas.masquerade_as(@student_1, @test.course)
          @assets_list.load_page @test
          @assets_list.click_asset_link @asset
          @visible_comment = @asset_detail.add_comment @comment_1_by_uploader
        end

        it('shows the commenter name') { expect(@visible_comment[:commenter]).to eql("#{@student_1.full_name} on #{@date}") }
        it('shows the comment body') { expect(@visible_comment[:body]).to eql(@comment_1_by_uploader.body) }
        it('increments the comment count on the detail view') { expect(@asset_detail.visible_asset_metadata(@asset)[:comment_count]).to eql(1.to_s) }
        it 'increments the comment count on the list view' do
          @asset_detail.click_back_to_asset_library
          expect(@assets_list.visible_list_view_asset_data(@asset)[:comment_count]).to eql(1.to_s)
        end

        it 'earns no points for the commenter' do
          @canvas.stop_masquerading
          expect(@engagement_index.user_score(@test, @student_1)).to eql(@student_1.score)
        end
      end

      context 'added as a reply to the user\'s own comment' do

        before(:all) do
          @student_1.score = @engagement_index.user_score(@test, @student_1)

          @canvas.masquerade_as(@student_1, @test.course)
          @asset_detail.load_asset_detail(@test, @asset)
          @visible_comment = @asset_detail.reply_to_comment(@comment_1_by_uploader, @comment_1_reply_by_uploader)
        end

        it('shows the commenter name') { expect(@visible_comment[:commenter]).to eql("#{@student_1.full_name} on #{@date}") }
        it('shows the comment body') { expect(@visible_comment[:body]).to eql(@comment_1_reply_by_uploader.body) }
        it('increments the comment count on the detail view') { expect(@asset_detail.visible_asset_metadata(@asset)[:comment_count]).to eql(2.to_s) }
        it 'increments the comment count on the list view' do
          @asset_detail.click_back_to_asset_library
          expect(@assets_list.visible_list_view_asset_data(@asset)[:comment_count]).to eql(2.to_s)
        end

        it 'does not earn commenting points on the engagement index' do
          @canvas.stop_masquerading
          expect(@engagement_index.user_score(@test, @student_1)).to eql(@student_1.score)
        end
      end
    end

    context 'by a user who is not the asset creator' do

      context 'added as a top level comment' do

        before(:all) do
          @student_1.score = @engagement_index.user_score(@test, @student_1)
          @student_2.score = @engagement_index.user_score(@test, @student_2)

          @canvas.masquerade_as(@student_2, @test.course)
          @assets_list.load_page @test
          @assets_list.click_asset_link @asset
          @visible_comment = @asset_detail.add_comment @comment_2_by_viewer
        end

        it('shows the commenter name') { expect(@visible_comment[:commenter]).to eql("#{@student_2.full_name} on #{@date}") }
        it('shows the comment body') { expect(@visible_comment[:body]).to eql(@comment_2_by_viewer.body) }
        it('increments the comment count on the detail view') { expect(@asset_detail.visible_asset_metadata(@asset)[:comment_count]).to eql(3.to_s) }
        it 'increments the comment count on the list view' do
          @asset_detail.click_back_to_asset_library
          expect(@assets_list.visible_list_view_asset_data(@asset)[:comment_count]).to eql(3.to_s)
        end

        it 'adds Engagement Index "comment" points for the commenter' do
          @canvas.stop_masquerading
          expect(@engagement_index.user_score(@test, @student_2)).to eql(@student_2.score + SquiggyActivity::COMMENT.points)
        end

        it 'adds Engagement Index "get_comment" points from the asset creator' do
          expect(@engagement_index.user_score(@test, @student_1)).to eql(@student_1.score + SquiggyActivity::GET_COMMENT.points)
        end

        it 'adds the commenter\'s "comment" activity  and the commentee\'s "get comment" activity to the activities csv' do
          csv = @engagement_index.download_csv @test
          give = csv.find do |r|
            r[:user_name] == @student_2.full_name &&
              r[:action] == SquiggyActivity::COMMENT.type &&
              r[:score] == SquiggyActivity::COMMENT.points &&
              r[:running_total] == (@student_2.score + SquiggyActivity::COMMENT.points)
          end
          get = csv.find do |r|
            r[:user_name] == @student_1.full_name &&
              r[:action] == SquiggyActivity::GET_COMMENT.type &&
              r[:score] == SquiggyActivity::GET_COMMENT.points &&
              r[:running_total] == (@student_1.score + SquiggyActivity::GET_COMMENT.points)
          end
          expect(give).to be_truthy
          expect(get).to be_truthy
        end
      end

      context 'added as a reply to the user\'s own comment' do

        before(:all) do
          @student_1.score = @engagement_index.user_score(@test, @student_1)
          @student_2.score = @engagement_index.user_score(@test, @student_2)

          @canvas.masquerade_as(@student_2, @test.course)
          @assets_list.load_page @test
          @assets_list.click_asset_link @asset
          @visible_comment = @asset_detail.reply_to_comment(@comment_2_by_viewer, @comment_2_reply_by_viewer)
        end

        it('shows the commenter name') { expect(@visible_comment[:commenter]).to eql("#{@student_2.full_name} on #{@date}") }
        it('shows the comment body') { expect(@visible_comment[:body]).to eql(@comment_2_reply_by_viewer.body) }
        it('increments the comment count on the detail view') { expect(@asset_detail.visible_asset_metadata(@asset)[:comment_count]).to eql(4.to_s) }
        it 'increments the comment count on the list view' do
          @asset_detail.click_back_to_asset_library
          expect(@assets_list.visible_list_view_asset_data(@asset)[:comment_count]).to eql(4.to_s)
        end

        it 'adds Engagement Index "comment" points for the commenter' do
          @canvas.stop_masquerading
          expect(@engagement_index.user_score(@test, @student_2)).to eql(@student_2.score + SquiggyActivity::COMMENT.points)
        end

        it 'adds Engagement Index "get_comment" points for the asset creator' do
          expect(@engagement_index.user_score(@test, @student_1)).to eql(@student_1.score + SquiggyActivity::GET_COMMENT.points)
        end

        it 'adds the commenter\'s "comment" activity  and the commentee\'s "get comment" activity to the activities csv' do
          csv = @engagement_index.download_csv @test
          give = csv.find do |r|
            r[:user_name] == @student_2.full_name &&
              r[:action] == SquiggyActivity::COMMENT.type &&
              r[:score] == SquiggyActivity::COMMENT.points &&
              r[:running_total] == (@student_2.score + SquiggyActivity::COMMENT.points)
          end
          get = csv.find do |r|
            r[:user_name] == @student_1.full_name &&
              r[:action] == SquiggyActivity::GET_COMMENT.type &&
              r[:score] == SquiggyActivity::GET_COMMENT.points &&
              r[:running_total] == (@student_1.score + SquiggyActivity::GET_COMMENT.points)
          end
          expect(give).to be_truthy
          expect(get).to be_truthy
        end
      end

      context 'added as a reply to another user\'s comment' do

        before(:all) do
          @student_1.score = @engagement_index.user_score(@test, @student_1)
          @student_2.score = @engagement_index.user_score(@test, @student_2)

          @canvas.masquerade_as(@student_2, @test.course)
          @assets_list.load_page @test
          @assets_list.click_asset_link @asset
          @visible_comment = @asset_detail.reply_to_comment(@comment_1_by_uploader, @comment_1_reply_by_viewer)
        end

        it('shows the commenter name') { expect(@visible_comment[:commenter]).to eql("#{@student_2.full_name} on #{@date}") }
        it('shows the comment body') { expect(@visible_comment[:body]).to eql(@comment_1_reply_by_viewer.body) }
        it('increments the comment count on the detail view') { expect(@asset_detail.visible_asset_metadata(@asset)[:comment_count]).to eql(5.to_s) }
        it 'increments the comment count on the list view' do
          @asset_detail.click_back_to_asset_library
          expect(@assets_list.visible_list_view_asset_data(@asset)[:comment_count]).to eql(5.to_s)
        end

        it 'adds Engagement Index "comment" points for the replier' do
          @canvas.stop_masquerading
          expect(@engagement_index.user_score(@test, @student_2)).to eql(@student_2.score + SquiggyActivity::COMMENT.points)
        end

        it 'adds Engagement Index "get_comment" and "get_comment_reply" points for the asset creator' do
          expected = @student_1.score + SquiggyActivity::GET_COMMENT.points + SquiggyActivity::GET_COMMENT_REPLY.points
          expect(@engagement_index.user_score(@test, @student_1)).to eql(expected)
        end

        it 'adds the commenter\'s "comment" activity  and the commentee\'s "get comment reply" activity to the activities csv' do
          csv = @engagement_index.download_csv @test
          give = csv.find do |r|
            r[:user_name] == @student_2.full_name &&
              r[:action] == SquiggyActivity::COMMENT.type &&
              r[:score] == SquiggyActivity::COMMENT.points &&
              r[:running_total] == (@student_2.score + SquiggyActivity::COMMENT.points)
          end
          get_1 = csv.find do |r|
            r[:user_name] == @student_1.full_name &&
              r[:action] == SquiggyActivity::GET_COMMENT.type &&
              r[:score] == SquiggyActivity::GET_COMMENT.points &&
              r[:running_total] == (@student_1.score + SquiggyActivity::GET_COMMENT.points)
          end
          get_2 = csv.find do |r|
            r[:user_name] == @student_1.full_name &&
              r[:action] == SquiggyActivity::GET_COMMENT_REPLY.type &&
              r[:score] == SquiggyActivity::GET_COMMENT_REPLY.points &&
              r[:running_total] == (@student_1.score + SquiggyActivity::GET_COMMENT.points + SquiggyActivity::GET_COMMENT_REPLY.points)
          end
          expect(give).to be_truthy
          expect(get_2).to be_truthy
        end
      end
    end

    describe 'adding by any user' do

      before(:all) { @canvas.masquerade_as(@student_2, @test.course) }

      it 'can include a link that opens in a new browser window' do
        @asset_detail.load_asset_detail(@test, @asset)
        @asset_detail.add_comment @comment_3_by_viewer
        expect(@asset_detail.external_link_valid?(@asset_detail.link_element(text: @comment_link), 'Google')).to be true
      end

      it 'cannot be added as a reply to a reply' do
        @canvas.switch_to_canvas_iframe
        expect((@asset_detail.reply_button_el @comment_1_reply_by_uploader).exists?).to be false
      end

      it 'can be canceled when a reply' do
        @asset_detail.click_reply_button @comment_3_by_viewer
        @asset_detail.click_cancel_reply @comment_3_by_viewer
      end
    end

    describe 'editing' do

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
    end

    # TODO it 'lets a user click a commenter name to view the asset gallery filtered by the commenter\'s submissions'

    describe 'deleting' do

      before(:all) do
        @student_1.score = @engagement_index.user_score(@test, @student_1)
        @student_2.score = @engagement_index.user_score(@test, @student_2)
      end

      it 'can be done by a student who created the comment' do
        @canvas.masquerade_as(@student_2, @test.course)
        @assets_list.load_page @test
        @assets_list.click_asset_link @asset
        @asset_detail.delete_comment @comment_1_reply_by_viewer
      end

      it 'cannot be done by a student who did not create the comment' do
        expect(@asset_detail.delete_comment_button(@comment_1_reply_by_uploader).exists?).to be false
      end

      it 'removes engagement index points earned for the comment' do
        @canvas.masquerade_as(@test.teachers.first, @test.course)
        expect(@engagement_index.user_score(@test, @student_2)).to eql(@student_2.score - SquiggyActivity::COMMENT.points)
      end

      it 'removes Engagement Index "get_comment_reply" points for the asset creator' do
        expect(@engagement_index.user_score(@test, @student_1)).to eql(@student_1.score - SquiggyActivity::GET_COMMENT_REPLY.points)
      end

      it 'removes the commenter\'s "comment" activity  and the commentee\'s "get comment reply" activity to the activities csv' do
        csv = @engagement_index.download_csv @test
        give = csv.find do |r|
          r[:user_name] == @student_2.full_name &&
            r[:action] == SquiggyActivity::COMMENT.type &&
            r[:score] == SquiggyActivity::COMMENT.points &&
            r[:running_total] == @student_2.score
        end
        get = csv.find do |r|
          r[:user_name] == @student_1.full_name &&
            r[:action] == SquiggyActivity::GET_COMMENT_REPLY.type &&
            r[:score] == SquiggyActivity::GET_COMMENT_REPLY.points &&
            r[:running_total] == @student_1.score
        end
        expect(give).to be_falsey
        expect(get).to be_falsey
      end

      it 'can be done by a teacher if the comment has no replies' do
        @assets_list.load_page @test
        @assets_list.click_asset_link @asset
        @asset_detail.delete_comment @comment_3_by_viewer
      end

      it 'cannot be done by a teacher if the comment has replies' do
        expect(@asset_detail.delete_comment_button(@comment_1_by_uploader).exists?).to be false
      end
    end
  end
end
