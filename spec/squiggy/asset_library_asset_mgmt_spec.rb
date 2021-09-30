require_relative '../../util/spec_helper'

describe 'Asset' do

  before(:all) do
    @test = SquiggyTestConfig.new 'asset_mgmt'
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
    @asset_1 = @student_1.assets[0]
    @jamboard = @student_2.assets.find { |a| a.url&.include? 'jamboard' }

    @canvas.masquerade_as(@student_1, @test.course)
    @assets_list.load_page @test
    @assets_list.create_asset(@test, @asset_1)
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'edits' do

    it 'are not allowed if the user is a student who is not the asset creator' do
      @canvas.masquerade_as(@student_2, @test.course)
      @asset_detail.load_asset_detail(@test, @asset_1)
      expect(@asset_detail.edit_details_button?).to be false
    end

    it 'are allowed if the user is a teacher' do
      @canvas.masquerade_as(@teacher, @test.course)
      @asset_detail.load_asset_detail(@test, @asset_1)
      @asset_1.title = "#{@asset_1.title} EDITED"
      @asset_detail.edit_asset_details @asset_1
      @asset_detail.wait_until(Utils.short_wait) { @asset_detail.asset_title == @asset_1.title }
    end

    it 'are allowed if the user is a student who is the asset creator' do
      @canvas.masquerade_as(@student_1, @test.course)
      @asset_detail.load_asset_detail(@test, @asset_1)
      @asset_1.description = 'New description'
      @asset_detail.edit_asset_details @asset_1
      @asset_detail.wait_until(Utils.short_wait) { @asset_detail.description.strip == @asset_1.description }
    end
  end

  describe 'preview regeneration' do

    before(:all) do
      @canvas.masquerade_as(@student_2, @test.course)
      @assets_list.load_page @test
      @assets_list.create_asset(@test, @jamboard)
    end

    it 'is allowed if the user is a student who is the asset creator' do
      @assets_list.click_asset_link @jamboard
      @asset_detail.regenerate_preview_button_element.when_present Utils.short_wait
    end

    it 'is allowed if the user is a teacher' do
      @canvas.masquerade_as(@teacher, @test.course)
      @asset_detail.load_asset_detail(@test, @jamboard)
      @asset_detail.regenerate_preview_button_element.when_present Utils.short_wait
    end

    it 'is not allowed if the user is a student who is not the asset creator' do
      @canvas.masquerade_as(@student_1, @test.course)
      @asset_detail.load_asset_detail(@test, @jamboard)
      @asset_detail.like_button_element.when_present Utils.short_wait
      expect(@asset_detail.regenerate_preview_button?).to be false
    end
  end

  describe 'deletion' do

    context 'when the asset has no comments or likes' do

      before(:all) do
        @asset_2 = @student_1.assets[1]
        @asset_3 = @student_1.assets[2]
        @assets_list.create_asset(@test, @asset_2)
        @assets_list.create_asset(@test, @asset_3)
        @canvas.stop_masquerading
        @score = @engagement_index.user_score(@test, @student_1)
      end

      it 'cannot be done by a student who did not create the asset' do
        @canvas.masquerade_as(@student_2, @test.course)
        @asset_detail.load_asset_detail(@test, @asset_2)
        expect(@asset_detail.delete_button?).to be false
      end

      it 'can be done by the student who created the asset' do
        @canvas.masquerade_as(@student_1, @test.course)
        @asset_detail.load_asset_detail(@test, @asset_2)
        @asset_detail.delete_asset @asset_2
      end

      it 'can be done by a teacher' do
        @canvas.masquerade_as(@teacher, @test.course)
        @asset_detail.load_asset_detail(@test, @asset_3)
        @asset_detail.delete_asset @asset_3
      end

      it 'has no effect on points already earned' do
        @canvas.stop_masquerading
        expect(@engagement_index.user_score(@test, @student_1)).to eql(@score)
      end
    end

    context 'when there are comments on the asset' do

      before(:all) do
        @asset_4 = @student_1.assets[3]
        @canvas.masquerade_as(@student_1, @test.course)
        @assets_list.create_asset(@test, @asset_4)

        @canvas.masquerade_as(@student_2, @test.course)
        @asset_detail.load_asset_detail(@test, @asset_4)
        @asset_detail.add_comment(SquiggyComment.new(body: 'Nemo me impune lacessit'))

        @canvas.stop_masquerading
        @uploader_score = @engagement_index.user_score(@test, @student_1)
        @viewer_score = @engagement_index.user_score(@test, @student_2)
      end

      it 'cannot be done by the student who created the asset' do
        @canvas.masquerade_as(@student_1, @test.course)
        @asset_detail.load_asset_detail(@test, @asset_4)
        expect(@asset_detail.delete_button?).to be false
      end

      it 'can be done by a teacher' do
        @canvas.masquerade_as(@teacher, @test.course)
        @asset_detail.load_asset_detail(@test, @asset_4)
        @asset_detail.delete_asset @asset_4
      end

      it 'has no effect on points already earned' do
        @canvas.stop_masquerading
        expect(@engagement_index.user_score(@test, @student_1)).to eql(@uploader_score)
        expect(@engagement_index.user_score(@test, @student_2)).to eql(@viewer_score)
      end
    end

    context 'when there are likes on the asset' do
      before(:all) do
        @asset_5 = @student_1.assets[4]
        @canvas.masquerade_as(@student_1, @test.course)
        @assets_list.create_asset(@test, @asset_5)

        @canvas.masquerade_as(@student_2, @test.course)
        @asset_detail.load_asset_detail(@test, @asset_5)
        @asset_detail.click_like_button

        @canvas.stop_masquerading
        @uploader_score = @engagement_index.user_score(@test, @student_1)
        @viewer_score = @engagement_index.user_score(@test, @student_2)
      end

      it 'cannot be done by the student who created the asset' do
        @canvas.masquerade_as(@student_1, @test.course)
        @asset_detail.load_asset_detail(@test, @asset_5)
        expect(@asset_detail.delete_button?).to be false
      end

      it 'can be done by a teacher' do
        @canvas.masquerade_as(@teacher, @test.course)
        @asset_detail.load_asset_detail(@test, @asset_5)
        @asset_detail.delete_asset @asset_5
      end

      it 'has no effect on points already earned' do
        @canvas.stop_masquerading
        expect(@engagement_index.user_score(@test, @student_1)).to eql(@uploader_score)
        expect(@engagement_index.user_score(@test, @student_2)).to eql(@viewer_score)
      end
    end
  end
end

