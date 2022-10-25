require_relative '../../util/spec_helper'

describe 'Asset Library' do

  test = SquiggyTestConfig.new 'asset_search'
  test.course.site_id = ENV['COURSE_ID']

  before(:all) do
    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @assets_list = SquiggyAssetLibraryListViewPage.new @driver
    @asset_detail = SquiggyAssetLibraryDetailPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver
    @manage_assets = SquiggyAssetLibraryManageAssetsPage.new @driver

    @student_1 = test.students[0]
    @student_2 = test.students[1]
    @student_3 = test.students[2]
    @student_1_upload = @student_1.assets.find &:file_name
    @student_2_upload = @student_2.assets.find &:file_name
    @student_3_link = @student_3.assets.find &:url

    @cat_1 = SquiggyCategory.new "Category 1 #{test.id}"
    @cat_2 = SquiggyCategory.new "Category 2 #{test.id}"

    @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course test
    @engagement_index.wait_for_new_user_sync(test, test.course.roster)
  end

  after(:all) do
    @canvas.stop_masquerading
    @assets_list.load_page test
    @assets_list.click_manage_assets_link
    @manage_assets.delete_category @cat_2
  ensure
    @driver.quit
  end

  describe 'categories' do

    [test.teachers.first, test.ta, test.lead_ta, test.designer, test.reader].each do |user|
      it "can be managed by a course #{user.role}" do
        @canvas.masquerade_as(user, test.course)
        @assets_list.load_page test
        @assets_list.manage_assets_button_element.when_visible Utils.short_wait
      end
    end

    [test.students.first, test.observer].each do |user|
      it "cannot be managed by a course #{user.role}" do
        @canvas.masquerade_as(user, test.course)
        @assets_list.load_page test
        @assets_list.upload_button_element.when_visible Utils.short_wait
        expect(@assets_list.manage_assets_button?).to be false
      end
    end

    context 'when created' do

      before(:all) do
        @canvas.masquerade_as(@student_1, test.course)
        @assets_list.load_page test
        @assets_list.upload_file_asset @student_1_upload
        @canvas.masquerade_as test.teachers.first
      end

      it 'require a title' do
        @assets_list.load_page test
        @assets_list.click_manage_assets_link
        @manage_assets.add_category_button_element.when_present Utils.short_wait
        expect(@manage_assets.add_category_button_element.enabled?).to be false
      end

      it 'require a title under 256 characters' do
        long_title = 'A loooooong title ' * 15
        @manage_assets.enter_category_name long_title
        @manage_assets.name_too_long_msg_element.when_visible 1
        expect(@manage_assets.add_category_button_element.enabled?).to be false
      end

      it 'are added to the list of available categories' do
        @assets_list.load_page test
        @assets_list.click_manage_assets_link
        @manage_assets.create_new_category @cat_1
        @manage_assets.create_new_category @cat_2
        @manage_assets.category_row(@cat_1).when_visible 1
        @manage_assets.category_row(@cat_2).when_visible 1
      end

      it 'can be added to existing assets' do
        @student_1_upload.category = @cat_1
        @manage_assets.click_back_to_asset_library
        @assets_list.click_asset_link(test, @student_1_upload)
        @asset_detail.edit_asset_details @student_1_upload
        expect(@asset_detail.visible_asset_metadata(@student_1_upload)[:category]).to eql(@cat_1.name)
      end

      it 'show how many assets with which they are associated' do
        @asset_detail.click_back_to_asset_library
        @assets_list.click_manage_assets_link
        @manage_assets.category_row(@cat_1).when_present Utils.short_wait
        expect(@manage_assets.category_usage @cat_1).to eql('Used by one asset')
        expect(@manage_assets.category_usage @cat_2).to eql('No assets')
      end

      it 'appear on the asset detail of associated assets as links to the asset library filtered for that category' do
        @assets_list.load_page test
        @assets_list.click_asset_link(test, @student_1_upload)
        @asset_detail.click_category_link @cat_1
        @assets_list.selected_category_element.when_present Utils.short_wait
        @assets_list.wait_until(Utils.short_wait) { @assets_list.selected_category == @cat_1.name }
        expect(@assets_list.selected_asset_type?).to be false
        expect(@assets_list.selected_user?).to be false
        expect(@assets_list.selected_sort).to eql('Most recent')
      end
    end

    context 'when edited' do

      before(:all) do
        @assets_list.load_page test
        @assets_list.click_manage_assets_link
      end

      it 'can be canceled' do
        @manage_assets.click_edit_category @cat_1
        @manage_assets.click_cancel_category_edit @cat_1
      end

      it 'require a title' do
        @manage_assets.click_edit_category @cat_1
        @manage_assets.wait_for_update_and_click @manage_assets.edit_category_clear_button(@cat_1)
        expect(@manage_assets.edit_category_save_button(@cat_1).enabled?).to be false
      end

      it 'are updated on assets with which they are associated' do
        @manage_assets.click_cancel_category_edit @cat_1
        @cat_1.name = "#{@cat_1.name} EDITED"
        @manage_assets.edit_category @cat_1
        @manage_assets.click_back_to_asset_library
        @assets_list.click_asset_link(test, @student_1_upload)
        expect(@asset_detail.visible_asset_metadata(@student_1_upload)[:category]).to eql(@cat_1.name)
      end
    end

    context 'when deleted' do

      before(:all) do
        @assets_list.load_page test
        @assets_list.click_manage_assets_link
      end

      it('no longer appear in the list of categories') { @manage_assets.delete_category @cat_1 }

      it 'no longer appear in search options' do
        @manage_assets.click_back_to_asset_library
        @assets_list.expand_adv_search
        @assets_list.click_category_search_select
        expect(@assets_list.parameter_option(@cat_1.name).exists?).to be false
      end

      it 'no longer appear on asset detail' do
        @assets_list.hit_escape
        @assets_list.click_asset_link(test, @student_1_upload)
        expect(@asset_detail.visible_asset_metadata(@student_1_upload)[:category]).to be_nil
      end
    end
  end

  describe 'search' do

    before(:all) do
      @student_2_upload.category = @cat_2
      @student_2_upload.description = "Description for uploaded file #{test.id}"
      @canvas.masquerade_as(@student_2, test.course)
      @assets_list.load_page test
      @assets_list.upload_file_asset @student_2_upload

      @student_3_link.category = @cat_2
      @student_3_link.description = "Link #MakeOurDreamsComeTrue#{test.id}"
      @canvas.masquerade_as(@student_3, test.course)
      @assets_list.load_page test
      @assets_list.add_link_asset @student_3_link

      @assets_list.wait_for_assets test
      @assets_list.click_asset_link(test, @student_2_upload)
      @asset_detail.add_comment SquiggyComment.new user: @student_3, body: '#BooBooKitty'
      @asset_detail.click_like_button

      @canvas.masquerade_as @student_2
      @assets_list.load_page test
      @assets_list.click_asset_link(test, @student_3_link)
      @asset_detail.click_like_button

      @canvas.masquerade_as @student_1
      @assets_list.load_page test
      @assets_list.click_asset_link(test, @student_3_link)
      @asset_detail.click_like_button
      @asset_detail.click_back_to_asset_library
      @assets_list.click_asset_link(test, @student_2_upload)
      @asset_detail.click_back_to_asset_library

      @assets = [@student_1_upload, @student_2_upload, @student_3_link]
    end

    it 'lets a user perform a simple search by a string in the title' do
      @assets_list.simple_search @student_3_link.title
      @assets_list.wait_for_asset_results [@student_3_link]
    end

    it 'lets a user perform a simple search by a string in the description' do
      @assets_list.simple_search @student_2_upload.description
      @assets_list.wait_for_asset_results [@student_2_upload]
    end

    it 'lets a user perform a simple search by a hashtag in the description' do
      @assets_list.simple_search @student_3_link.description
      @assets_list.wait_for_asset_results [@student_3_link]
    end

    it 'lets a user perform an advanced search by a string in the title, sorted by Most Recent' do
      @assets_list.advanced_search(@student_3_link.title, nil, nil, nil, nil, 'Most recent')
      @assets_list.wait_for_asset_results [@student_3_link]
    end

    it 'lets a user perform an advanced search by a string in the description, sorted by Most Recent' do
      @assets_list.advanced_search(@student_2_upload.description, nil, nil, nil, nil, 'Most recent')
      @assets_list.wait_for_asset_results [@student_2_upload]
    end

    it 'lets a user perform an advanced search by a hashtag in the description, sorted by Most Recent' do
      @assets_list.advanced_search(@student_3_link.description, nil, nil, nil, nil, 'Most recent')
      @assets_list.wait_for_asset_results [@student_3_link]
    end

    it 'lets a user perform an advanced search by category, sorted by Most Recent' do
      @assets_list.advanced_search(nil, @cat_2, nil, nil, nil, nil)
      @assets_list.wait_for_asset_results [@student_3_link, @student_2_upload]
    end

    it 'lets a user perform an advanced search by category and uploader, sorted by Most Recent' do
      @assets_list.advanced_search(nil, @cat_2, @student_3, nil, nil, nil)
      @assets_list.wait_for_asset_results [@student_3_link]
    end

    it 'lets a user perform an advanced search by category and type, sorted by Most Recent' do
      @assets_list.advanced_search(nil, @cat_2, nil, 'Link', nil, nil)
      @assets_list.wait_for_asset_results [@student_3_link]
    end

    it 'lets a user perform an advanced search by keyword and category, sorted by Most Recent' do
      @assets_list.advanced_search(test.id, @cat_2, nil, nil, nil,nil)
      @assets_list.wait_for_asset_results [@student_3_link, @student_2_upload]
    end

    it 'lets a user perform an advanced search by keyword and uploader, sorted by Most Recent' do
      @assets_list.advanced_search(test.id, nil, @student_3, nil, nil, nil)
      @assets_list.wait_for_asset_results [@student_3_link]
    end

    it 'lets a user perform an advanced search by keyword and type, sorted by Most Recent' do
      @assets_list.advanced_search(test.id, nil, nil, 'File', nil, nil)
      @assets_list.wait_for_asset_results [@student_2_upload, @student_1_upload]
    end

    it 'returns a no results message for an advanced search by a hashtag in a comment, sorted by Most Recent' do
      @assets_list.advanced_search('#BooBooKitty', nil, nil, nil, nil, nil)
      @assets_list.wait_for_no_results
    end

    it 'lets a user perform an advanced search by keyword, category, and type, sorted by Most Recent' do
      @assets_list.advanced_search(test.id, @cat_2, nil, 'File', nil, nil)
      @assets_list.wait_for_asset_results [@student_2_upload]
    end

    it 'lets a user perform an advanced search by keyword, uploader, and type, sorted by Most Recent' do
      @assets_list.advanced_search(test.id, nil, @student_3, 'Link', nil, nil)
      @assets_list.wait_for_asset_results [@student_3_link]
    end

    it 'lets a user perform an advanced search by keyword, category, uploader, and type, sorted by Most Recent' do
      @assets_list.advanced_search(test.id, @cat_2, @student_2, 'File', nil, nil)
      @assets_list.wait_for_asset_results [@student_2_upload]
    end

    it 'lets a user perform an advanced search by keyword, sorted by Most Likes' do
      @assets_list.advanced_search(test.id, nil, nil, nil, nil, 'Most likes')
      @assets_list.wait_for_asset_results [@student_3_link, @student_2_upload, @student_1_upload]
    end

    it 'lets a user perform an advanced search by keyword, sorted by Most Comments' do
      @assets_list.advanced_search(test.id, nil, nil, nil, nil, 'Most comments')
      @assets_list.wait_for_asset_results [@student_2_upload, @student_3_link, @student_1_upload]
    end

    it 'lets a user perform an advanced search by keyword, sorted by Most Views' do
      @assets_list.advanced_search(test.id, nil, nil, nil, nil, 'Most views')
      @assets_list.wait_for_asset_results [@student_1_upload, @student_3_link, @student_2_upload]
    end

    it 'lets a user perform an advanced search by keyword and uploader, sorted by Most Likes' do
      @assets_list.advanced_search(test.id, nil, @student_1, nil, nil, 'Most likes')
      @assets_list.wait_for_asset_results [@student_1_upload]
    end

    it 'lets a user perform an advanced search by keyword and category, sorted by Most Comments' do
      @assets_list.advanced_search(test.id, @cat_2, nil, nil, nil, 'Most comments')
      @assets_list.wait_for_asset_results [@student_2_upload, @student_3_link]
    end

    it 'lets a user perform an advanced search by keyword and uploader, sorted by Most Views' do
      @assets_list.advanced_search(test.id, nil, @student_1, nil, nil, 'Most views')
      @assets_list.wait_for_asset_results [@student_1_upload]
    end

    it 'allows sorting by "Most recent", "Most likes", "Most views", "Most comments"' do
      @assets_list.click_sort_by_select
      @assets_list.wait_until(2) { @assets_list.sort_by_options.any? }
      @assets_list.wait_until(3) { @assets_list.sort_by_options == ['Most recent', 'Most likes', 'Most views', 'Most comments'] }
    end

    it 'allows searching by asset type "File", "Link", "Whiteboard"' do
      @assets_list.click_asset_type_select
      @assets_list.wait_until(2) { @assets_list.asset_type_options.any? }
      @assets_list.wait_until(3) { @assets_list.asset_type_options == %w(File Link Whiteboard) }
    end
  end
end
