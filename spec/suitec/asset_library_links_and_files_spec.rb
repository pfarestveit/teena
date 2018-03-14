require_relative '../../util/spec_helper'

describe 'Asset Library', order: :defined do

test_id = Utils.get_test_id
timeout = Utils.short_wait

  before(:all) do
    @course = Course.new({title: "Asset Library Links and Files #{test_id}"})
    @course.site_id = ENV['COURSE_ID']

    # Get test user and asset
    test_user_data = SuiteCUtils.load_suitec_test_data.find { |data| data['tests']['asset_library_links_and_files'] }
    @user = User.new test_user_data
    @activity = Activity::ADD_ASSET_TO_LIBRARY

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net= Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryPage.new @driver
    @engagement_index = Page::SuiteCPages::EngagementIndexPage.new @driver

    # Create test course site
    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, [@user], test_id, [LtiTools::ASSET_LIBRARY, LtiTools::ENGAGEMENT_INDEX])
    @canvas.load_course_site(@driver, @course)
    @asset_library_url = @canvas.click_tool_link(@driver, LtiTools::ASSET_LIBRARY)
    @engagement_index_url = @canvas.click_tool_link(@driver, LtiTools::ENGAGEMENT_INDEX)

    # Create two categories but delete one
    category_id = "#{Time.now.to_i}"
    @asset_library.add_custom_categories(@driver, @asset_library_url, [(@category_1="Category 1 - #{category_id}"), (@category_2="Category 2 - #{category_id}")])
    @asset_library.delete_custom_category @category_2

    @canvas.masquerade_as(@driver, @user, @course)
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'links' do

    before(:all) do
      @link_asset = Asset.new @user.assets.find { |asset| asset['type'] == 'Link' }
      @link_title = "#{@link_asset.title} - #{test_id}"
      @link_desc = "#{@link_asset.description} - #{test_id}"
      @link_url = @link_asset.url
      @initial_score = @engagement_index.user_score(@driver, @engagement_index_url, @user).to_i

      @asset_library.load_page(@driver, @asset_library_url)
    end

    # Metadata

    it 'can be added with title, category, and description' do
      @link_asset.title = "#{@link_title} 1"
      @link_asset.description = @link_desc
      @link_asset.category = @category_1
      @asset_library.add_site @link_asset
      @asset_library.wait_until(timeout) { @asset_library.list_view_asset_elements.any? }
      @asset_library.verify_first_asset(@user, @link_asset)
    end

    it 'earn "Add a new asset to the Asset Library" points on the Engagement Index' do
      current_score = @engagement_index.user_score(@driver, @engagement_index_url, @user)
      expect(current_score).to eql("#{@initial_score + @activity.points}")
    end

    it 'add "add_asset" activity to the CSV export' do
      scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
      expect(scores).to include("#{@user.full_name}, #{@activity.type}, #{@activity.points}, #{@initial_score + @activity.points}")
    end

    it 'can be added with title and category only' do
      @link_asset.title = "#{@link_title} 2"
      @link_asset.description = nil
      @link_asset.category = @category_1
      @asset_library.load_page(@driver, @asset_library_url)
      @asset_library.add_site @link_asset
      @asset_library.verify_first_asset(@user, @link_asset)
    end

    it 'can be added with title only' do
      @link_asset.title = "#{@link_title} 3"
      @link_asset.description = nil
      @link_asset.category = nil
      @asset_library.add_site @link_asset
      @asset_library.verify_first_asset(@user, @link_asset)
    end

    it 'can be added with title and description only' do
      @link_asset.title = "#{@link_title} 4"
      @link_asset.description = @link_desc
      @link_asset.category = nil
      @asset_library.add_site @link_asset
      @asset_library.verify_first_asset(@user, @link_asset)
    end

    # Validation

    it 'require that the user enter a URL' do
      @link_asset.title = "#{@link_title} 5"
      @link_asset.description = nil
      @link_asset.category = nil
      @link_asset.url = nil
      @asset_library.click_add_site_link
      @asset_library.enter_and_submit_url @link_asset
      @asset_library.missing_url_error_element.when_visible timeout
      expect(@asset_library.url_title_input).to eql(@link_asset.title)
    end

    it 'require that the user enter a valid URL' do
      @link_asset.title = "#{@link_title} 6"
      @link_asset.description = nil
      @link_asset.category = nil
      @link_asset.url = 'foo bar'
      @asset_library.click_add_site_link
      @asset_library.enter_and_submit_url @link_asset
      @asset_library.bad_url_error_element.when_visible timeout
      expect(@asset_library.url_input).to eql("http://#{@link_asset.url}")
      expect(@asset_library.url_title_input).to eql(@link_asset.title)
    end

    it 'require that the user enter a title' do
      @link_asset.title = nil
      @link_asset.description = nil
      @link_asset.category = nil
      @link_asset.url = @link_url
      @asset_library.click_add_site_link
      @asset_library.enter_and_submit_url @link_asset
      @asset_library.wait_until(timeout) { @asset_library.missing_title_error_elements.any? }
      expect(@asset_library.url_input).to include(@link_asset.url)
    end

    it 'limit a title to 255 characters' do
      @link_asset.title = "#{'A loooooong title' * 15}?"
      @link_asset.description = nil
      @link_asset.category = nil
      @link_asset.url = @link_url
      @asset_library.click_add_site_link
      @asset_library.enter_and_submit_url @link_asset
      @asset_library.wait_until(timeout) { @asset_library.long_title_error_elements.any? }
      @link_asset.title = @link_asset.title[0, 255]
      @asset_library.add_site @link_asset
      @asset_library.verify_first_asset(@user, @link_asset)
    end

    it 'do not have a default category' do
      @asset_library.go_back_to_asset_library if @asset_library.back_to_library_link?
      @asset_library.click_add_site_link
      expect(@asset_library.url_category).to eql('Which assignment or topic is this related to')
    end

    it 'can have only non-deleted categories' do
      expect(@asset_library.url_category_options).not_to include(@category_2)
    end

    it 'can be canceled and not added' do
      @asset_library.click_cancel_button
      @asset_library.add_site_link_element.when_visible timeout
    end
  end

  describe 'files' do

    before(:all) do
      @file_asset = Asset.new @user.assets.find { |asset| asset['type'] == 'File' }
      @file_title = "#{@file_asset.title} - #{test_id}"
      @file_desc = "#{@file_asset.description} - #{test_id}"
      @initial_score = @engagement_index.user_score(@driver, @engagement_index_url, @user).to_i

      @asset_library.load_page(@driver, @asset_library_url)
    end

    it 'can be added with title, category, and description' do
      @file_asset.title = @file_title
      @file_asset.description = @file_desc
      @file_asset.category = @category_1
      @asset_library.upload_file_to_library @file_asset
      @asset_library.verify_first_asset(@user, @file_asset)
    end

    it 'earn "Add a new asset to the Asset Library" points on the Engagement Index' do
      current_score = @engagement_index.user_score(@driver, @engagement_index_url, @user)
      expect(current_score).to eql("#{@initial_score + @activity.points}")
    end

    it 'add "add_asset" activity to the CSV export' do
      scores = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
      expect(scores).to include("#{@user.full_name}, #{@activity.type}, #{@activity.points}, #{@initial_score + @activity.points}")
    end

    it 'can be added with title and category only' do
      @file_asset.title = @file_title
      @file_asset.description = nil
      @file_asset.category = @category_1
      @asset_library.load_page(@driver, @asset_library_url)
      @asset_library.upload_file_to_library @file_asset
      @asset_library.verify_first_asset(@user, @file_asset)
    end

    it 'can be added with title only' do
      @file_asset.title = @file_title
      @file_asset.description = nil
      @file_asset.category = nil
      @asset_library.upload_file_to_library @file_asset
      @asset_library.verify_first_asset(@user, @file_asset)
    end

    it 'can be added with title and description only' do
      @file_asset.title = @file_title
      @file_asset.description = @file_desc
      @file_asset.category = nil
      @asset_library.upload_file_to_library @file_asset
      @asset_library.verify_first_asset(@user, @file_asset)
    end

    it 'require that the user enter a title' do
      @file_asset.title = nil
      @file_asset.description = nil
      @file_asset.category = nil
      @asset_library.click_upload_file_link
      @asset_library.enter_and_upload_file @file_asset
      @asset_library.wait_until(timeout) { @asset_library.missing_title_error_elements.any? }
    end

    it 'limit a title to 255 characters' do
      @file_asset.title = "#{'A loooooong title' * 15}?"
      @file_asset.description = nil
      @file_asset.category = nil
      @asset_library.click_upload_file_link
      @asset_library.enter_and_upload_file @file_asset
      @asset_library.wait_until(timeout) { @asset_library.long_title_error_elements.any? }
      @file_asset.title = @file_asset.title[0, 255]
      @asset_library.upload_file_to_library @file_asset
      @asset_library.verify_first_asset(@user, @file_asset)
    end

    it 'do not have a default category' do
      @asset_library.go_back_to_asset_library if @asset_library.back_to_library_link?
      @asset_library.click_upload_file_link
      @asset_library.enter_file_path_for_upload @file_asset.file_name
      expect(@asset_library.upload_file_category_select).to eql('Which assignment or topic is this related to')
    end

    it 'can have only non-deleted categories' do
      expect(@asset_library.upload_file_category_select_options).not_to include(@category_2)
    end

    it 'can be canceled and not added' do
      @asset_library.click_cancel_button
      @asset_library.add_site_link_element.when_visible timeout
    end
  end
end
