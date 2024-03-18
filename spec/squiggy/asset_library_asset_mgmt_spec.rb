require_relative '../../util/spec_helper'

describe 'Asset' do

  before(:all) do
    @test = SquiggyTestConfig.new 'asset_mgmt'
    @test.course_site.site_id = ENV['COURSE_ID']
    @driver = Utils.launch_browser chrome_3rd_party_cookies: true
    @canvas = Page::CanvasPage.new @driver
    @cal_net= Page::CalNetPage.new @driver
    @assets_list = SquiggyAssetLibraryListViewPage.new @driver
    @asset_detail = SquiggyAssetLibraryDetailPage.new @driver
    @manage_assets = SquiggyAssetLibraryManageAssetsPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver

    @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course_site @test

    @cat_0 = SquiggyCategory.new "Category 1 #{@test.id}"
    @cat_1 = SquiggyCategory.new "Category 2 #{@test.id}"

    @teacher = @test.teachers.first
    @student_1 = @test.students[0]
    @student_2 = @test.students[1]

    @canvas.masquerade_as(@teacher, @test.course_site)
    @assets_list.load_page @test
    @assets_list.click_manage_assets_link
    @manage_assets.create_new_category @cat_0
    @manage_assets.create_new_category @cat_1
    @manage_assets.delete_category @cat_1
  end

  after(:all) do
    @assets_list.load_page @test
    @assets_list.click_manage_assets_link
    @manage_assets.delete_category @cat_0
  ensure
    Utils.quit_browser @driver
  end

  describe 'links' do

    before(:all) do
      @asset = @teacher.assets.find &:url
      @title = @asset.title
      @desc = "Description - #{@test.id}"
      @url = @asset.url
      @initial_score = @engagement_index.user_score(@test, @teacher)
      @assets_list.load_page @test
    end

    it 'can be added with title, category, and description' do
      @asset.title = "#{@title} 1"
      @asset.description = @desc
      @asset.category = @cat_0
      @assets_list.add_link_asset @asset
      expect(@asset.id).not_to be_nil
    end

    it 'earn "Add a new asset to the Asset Library" points on the Engagement Index' do
      expect(@engagement_index.user_score(@test, @teacher)).to eql(@initial_score + SquiggyActivity::ADD_ASSET_TO_LIBRARY.points)
    end

    it 'add "add_asset" activity to the CSV export' do
      csv = @engagement_index.download_csv @test
      activity = csv.find do |r|
        r[:user_name] == @teacher.full_name &&
          r[:action] == SquiggyActivity::ADD_ASSET_TO_LIBRARY.type &&
          r[:score] == SquiggyActivity::ADD_ASSET_TO_LIBRARY.points &&
          r[:running_total] == (@initial_score + SquiggyActivity::ADD_ASSET_TO_LIBRARY.points)
      end
      expect(activity).to be_truthy
    end

    it 'can be added with title and category only' do
      @asset.title = "#{@title} 2"
      @asset.description = nil
      @asset.category = @cat_0
      @assets_list.load_page @test
      @assets_list.add_link_asset @asset
      expect(@asset.id).not_to be_nil
    end

    it 'can be added with title only' do
      @asset.title = "#{@title} 3"
      @asset.description = nil
      @asset.category = nil
      @assets_list.add_link_asset @asset
      expect(@asset.id).not_to be_nil
    end

    it 'can be added with title and description only' do
      @asset.title = "#{@title} 4"
      @asset.description = @desc
      @asset.category = nil
      @assets_list.add_link_asset @asset
      expect(@asset.id).not_to be_nil
    end

    it 'require that the user enter a URL' do
      @asset.title = "#{@title} 5"
      @asset.description = nil
      @asset.category = nil
      @asset.url = nil
      @assets_list.click_add_url_button
      @assets_list.enter_url @asset
      @assets_list.enter_asset_metadata @asset
      expect(@assets_list.save_link_button_element.enabled?).to be false
    end

    it 'require that the user enter a valid URL' do
      @asset.title = "#{@title} 6"
      @asset.description = nil
      @asset.category = nil
      @asset.url = 'fubar'
      @assets_list.click_cancel_link_button
      @assets_list.click_add_url_button
      @assets_list.enter_url @asset
      @assets_list.enter_asset_metadata @asset
      expect(@assets_list.url_input_element.value).to eql("https://#{@asset.url}")
    end

    it 'require that the user enter a title' do
      @asset.title = nil
      @asset.description = nil
      @asset.category = nil
      @asset.url = @url
      @assets_list.click_cancel_link_button
      @assets_list.click_add_url_button
      @assets_list.enter_url @asset
      @assets_list.enter_asset_metadata @asset
      expect(@assets_list.save_link_button_element.enabled?).to be false
    end

    it 'limit a title to 255 characters' do
      @asset.title = "#{'A loooooong title' * 16}?"
      @asset.description = nil
      @asset.category = nil
      @asset.url = @url
      @assets_list.click_cancel_link_button
      @assets_list.click_add_url_button
      @assets_list.enter_url @asset
      @assets_list.enter_asset_metadata @asset
      @assets_list.title_too_long_msg_element.when_visible 2
    end

    it 'can have only non-deleted categories' do
      @assets_list.click_cancel_link_button
      @assets_list.click_add_url_button
      @assets_list.click_category_asset_select
      expect(@assets_list.menu_option_el(@cat_1.name).exists?).to be false
    end
  end

  describe 'files' do

    before(:all) do
      @asset = @teacher.assets.find &:file_name
      @title = @asset.title
      @desc = "Description - #{@test.id}"
      @initial_score = @engagement_index.user_score(@test, @teacher)
      @assets_list.load_page @test
    end

    it 'can be added with title, category, and description' do
      @asset.title = "#{@title} 1"
      @asset.description = @desc
      @asset.category = @cat_0
      @assets_list.upload_file_asset @asset
      expect(@asset.id).not_to be_nil
    end

    it 'earn "Add a new asset to the Asset Library" points on the Engagement Index' do
      expect(@engagement_index.user_score(@test, @teacher)).to eql(@initial_score + SquiggyActivity::ADD_ASSET_TO_LIBRARY.points)
    end

    it 'add "add_asset" activity to the CSV export' do
      csv = @engagement_index.download_csv @test
      activity = csv.find do |r|
        r[:user_name] == @teacher.full_name &&
          r[:action] == SquiggyActivity::ADD_ASSET_TO_LIBRARY.type &&
          r[:score] == SquiggyActivity::ADD_ASSET_TO_LIBRARY.points &&
          r[:running_total] == (@initial_score + SquiggyActivity::ADD_ASSET_TO_LIBRARY.points)
      end
      expect(activity).to be_truthy
    end

    it 'can be added with title and category only' do
      @asset.title = "#{@title} 2"
      @asset.description = nil
      @asset.category = @cat_0
      @assets_list.load_page @test
      @assets_list.upload_file_asset @asset
      expect(@asset.id).not_to be_nil
    end

    it 'can be added with title only' do
      @asset.title = "#{@title} 3"
      @asset.description = nil
      @asset.category = nil
      @assets_list.upload_file_asset @asset
      expect(@asset.id).not_to be_nil
    end

    it 'can be added with title and description only' do
      @asset.title = "#{@title} 4"
      @asset.description = @desc
      @asset.category = nil
      @assets_list.upload_file_asset @asset
      expect(@asset.id).not_to be_nil
    end

    it 'require that the user enter a title' do
      @asset.title = nil
      @asset.description = nil
      @asset.category = nil
      @assets_list.click_upload_file_button
      @assets_list.enter_file_path_for_upload @asset
      @assets_list.enter_asset_metadata @asset
      expect(@assets_list.save_file_button_element.enabled?).to be false
    end

    it 'limit a title to 255 characters' do
      @asset.title = "#{'A loooooong title' * 16}?"
      @asset.description = nil
      @asset.category = nil
      @assets_list.click_cancel_file_button
      @assets_list.click_upload_file_button
      @assets_list.enter_file_path_for_upload @asset
      @assets_list.enter_asset_metadata @asset
      @assets_list.title_too_long_msg_element.when_visible 2
    end

    it 'can have only non-deleted categories' do
      @assets_list.click_cancel_file_button
      @assets_list.click_upload_file_button
      @assets_list.enter_file_path_for_upload @asset
      @assets_list.click_category_asset_select
      expect(@assets_list.menu_option_el(@cat_1.name).exists?).to be false
    end
  end

  describe 'edits' do

    before(:all) do
      @asset = @student_1.assets[0]
      @canvas.masquerade_as(@student_1, @test.course_site)
      @assets_list.load_page @test
      @assets_list.create_asset(@test, @asset)
    end
    
    it 'are not allowed if the user is a student who is not the asset creator' do
      @canvas.masquerade_as(@student_2, @test.course_site)
      @asset_detail.load_asset_detail(@test, @asset)
      expect(@asset_detail.edit_details_button?).to be false
    end

    it 'are allowed if the user is a teacher' do
      @canvas.masquerade_as(@teacher, @test.course_site)
      @asset_detail.load_asset_detail(@test, @asset)
      @asset.title = "#{@asset.title} EDITED"
      @asset_detail.edit_asset_details @asset
      @asset_detail.wait_for_asset_detail
      @asset_detail.wait_until(Utils.short_wait) { @asset_detail.asset_title == @asset.title }
    end

    it 'are allowed if the user is a student who is the asset creator' do
      @canvas.masquerade_as(@student_1, @test.course_site)
      @asset_detail.load_asset_detail(@test, @asset)
      @asset.description = 'New description'
      @asset_detail.edit_asset_details @asset
      @asset_detail.wait_for_asset_detail
      @asset_detail.wait_until(Utils.short_wait) { @asset_detail.description.strip == @asset.description }
    end
  end

  describe 'preview regeneration' do

    before(:all) do
      @link = @student_2.assets.find &:url
      @canvas.masquerade_as(@student_2, @test.course_site)
      @assets_list.load_page @test
      @assets_list.create_asset(@test, @link)
    end

    it 'is allowed if the user is a student who is the asset creator' do
      @asset_detail.load_asset_detail(@test, @link)
      @asset_detail.regenerate_preview_button_element.when_present Utils.short_wait
    end

    it 'is allowed if the user is a teacher' do
      @canvas.masquerade_as(@teacher, @test.course_site)
      @asset_detail.load_asset_detail(@test, @link)
      @asset_detail.regenerate_preview_button_element.when_present Utils.short_wait
    end

    it 'is not allowed if the user is a student who is not the asset creator' do
      @canvas.masquerade_as(@student_1, @test.course_site)
      @asset_detail.load_asset_detail(@test, @link)
      @asset_detail.like_button_element.when_present Utils.short_wait
      expect(@asset_detail.regenerate_preview_button?).to be false
    end
  end

  describe 'deletion' do

    context 'when the asset has no comments or likes' do

      before(:all) do
        @asset_1 = @student_1.assets[1]
        @asset_2 = @student_1.assets[2]
        @assets_list.create_asset(@test, @asset_1)
        @assets_list.create_asset(@test, @asset_2)
        @canvas.stop_masquerading
        @score = @engagement_index.user_score(@test, @student_1)
      end

      it 'cannot be done by a student who did not create the asset' do
        @canvas.masquerade_as(@student_2, @test.course_site)
        @asset_detail.load_asset_detail(@test, @asset_1)
        expect(@asset_detail.delete_button?).to be false
      end

      it 'can be done by the student who created the asset' do
        @canvas.masquerade_as(@student_1, @test.course_site)
        @asset_detail.load_asset_detail(@test, @asset_1)
        @asset_detail.delete_asset @asset_1
      end

      it 'can be done by a teacher' do
        @canvas.masquerade_as(@teacher, @test.course_site)
        @asset_detail.load_asset_detail(@test, @asset_2)
        @asset_detail.delete_asset @asset_2
      end

      it 'has no effect on points already earned' do
        @canvas.stop_masquerading
        expect(@engagement_index.user_score(@test, @student_1)).to eql(@score)
      end
    end

    context 'when there are comments on the asset' do

      before(:all) do
        @asset = @student_1.assets[3]
        @canvas.masquerade_as(@student_1, @test.course_site)
        @assets_list.create_asset(@test, @asset)

        @canvas.masquerade_as(@student_2, @test.course_site)
        @asset_detail.load_asset_detail(@test, @asset)
        @asset_detail.add_comment(SquiggyComment.new(body: 'Nemo me impune lacessit'))

        @canvas.stop_masquerading
        @uploader_score = @engagement_index.user_score(@test, @student_1)
        @viewer_score = @engagement_index.user_score(@test, @student_2)
      end

      it 'cannot be done by the student who created the asset' do
        @canvas.masquerade_as(@student_1, @test.course_site)
        @asset_detail.load_asset_detail(@test, @asset)
        expect(@asset_detail.delete_button?).to be false
      end

      it 'can be done by a teacher' do
        @canvas.masquerade_as(@teacher, @test.course_site)
        @asset_detail.load_asset_detail(@test, @asset)
        @asset_detail.delete_asset @asset
      end

      it 'has no effect on points already earned' do
        @canvas.stop_masquerading
        expect(@engagement_index.user_score(@test, @student_1)).to eql(@uploader_score)
        expect(@engagement_index.user_score(@test, @student_2)).to eql(@viewer_score)
      end
    end

    context 'when there are likes on the asset' do
      before(:all) do
        @asset = @student_1.assets[4]
        @canvas.masquerade_as(@student_1, @test.course_site)
        @assets_list.create_asset(@test, @asset)

        @canvas.masquerade_as(@student_2, @test.course_site)
        @asset_detail.load_asset_detail(@test, @asset)
        @asset_detail.click_like_button

        @canvas.stop_masquerading
        @uploader_score = @engagement_index.user_score(@test, @student_1)
        @viewer_score = @engagement_index.user_score(@test, @student_2)
      end

      it 'cannot be done by the student who created the asset' do
        @canvas.masquerade_as(@student_1, @test.course_site)
        @asset_detail.load_asset_detail(@test, @asset)
        expect(@asset_detail.delete_button?).to be false
      end

      it 'can be done by a teacher' do
        @canvas.masquerade_as(@teacher, @test.course_site)
        @asset_detail.load_asset_detail(@test, @asset)
        @asset_detail.delete_asset @asset
      end

      it 'has no effect on points already earned' do
        @canvas.stop_masquerading
        expect(@engagement_index.user_score(@test, @student_1)).to eql(@uploader_score)
        expect(@engagement_index.user_score(@test, @student_2)).to eql(@viewer_score)
      end
    end
  end
end

