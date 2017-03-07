require_relative '../../util/spec_helper'

describe 'Asset library file uploads', order: :defined do

  test_id = Utils.get_test_id
  timeout = Utils.short_wait

  before(:all) do
    @course = Course.new({})
    @course.site_id = ENV['course_id']
    test_user_data = Utils.load_test_users.find { |data| data['tests']['assetLibraryUploads'] }
    @user = User.new test_user_data
    @asset = Asset.new @user.assets.find { |asset| asset['type'] == 'File' }
    @title = "#{@asset.title} - #{test_id}"
    @description = "#{@asset.description} - #{test_id}"

    @driver = Utils.launch_browser

    @canvas = Page::SuiteCPages::CanvasPage.new @driver
    @cal_net= Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryPage.new @driver

    @canvas.log_in(@cal_net, Utils.ets_qa_username, Utils.ets_qa_password)
    @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, [@user], test_id, [SuiteCTools::ASSET_LIBRARY])

    @canvas.load_course_site(@driver, @course)
    @asset_library_url = @canvas.click_tool_link(@driver, SuiteCTools::ASSET_LIBRARY)

    category_id = "#{Time.now.to_i}"
    @asset_library.add_custom_categories(@driver, @asset_library_url, [(@category_1="Category 1 - #{category_id}"), (@category_2="Category 2 - #{category_id}")])
    @asset_library.delete_custom_category @category_2
    @canvas.log_out(@driver, @cal_net)

    @canvas.log_in(@cal_net, @user.username, Utils.test_user_password)
    @canvas.load_course_site(@driver, @course)
    @asset_library.load_page(@driver, @asset_library_url)
  end

  after(:all) do
    @driver.quit
  end

  it 'can be added with title, category, and description' do
    @asset.title = @title
    @asset.description = @description
    @asset.category = @category_1
    @asset_library.upload_file_to_library @asset
    @asset_library.wait_until(timeout) { @asset_library.list_view_asset_elements.any? }
    @asset_library.verify_first_asset(@user, @asset)
  end

  it 'can be added with title and category only' do
    @asset.title = @title
    @asset.description = nil
    @asset.category = @category_1
    @asset_library.upload_file_to_library @asset
    @asset_library.wait_until(timeout) { @asset_library.list_view_asset_elements.any? }
    @asset_library.verify_first_asset(@user, @asset)
  end

  it 'can be added with title only' do
    @asset.title = @title
    @asset.description = nil
    @asset.category = nil
    @asset_library.upload_file_to_library @asset
    @asset_library.wait_until(timeout) { @asset_library.list_view_asset_elements.any? }
    @asset_library.verify_first_asset(@user, @asset)
  end

  it 'can be added with title and description only' do
    @asset.title = @title
    @asset.description = @description
    @asset.category = nil
    @asset_library.upload_file_to_library @asset
    @asset_library.wait_until(timeout) { @asset_library.list_view_asset_elements.any? }
    @asset_library.verify_first_asset(@user, @asset)
  end

  it 'require that the user enter a title' do
    @asset.title = nil
    @asset.description = nil
    @asset.category = nil
    @asset_library.click_upload_file_link
    @asset_library.enter_and_upload_file @asset
    @asset_library.wait_until(timeout) { @asset_library.missing_title_error_elements.any? }
  end

  it 'limit a title to 255 characters' do
    @asset.title = "#{'A loooooong title' * 15}?"
    @asset.description = nil
    @asset.category = nil
    @asset_library.click_upload_file_link
    @asset_library.enter_and_upload_file @asset
    @asset_library.wait_until(timeout) { @asset_library.long_title_error_elements.any? }
    @asset.title = @asset.title[0, 255]
    @asset_library.upload_file_to_library @asset
    @asset_library.wait_until(timeout) { @asset_library.list_view_asset_elements.any? }
    @asset_library.verify_first_asset(@user, @asset)
  end

  it 'do not have a default category' do
    @asset_library.go_back_to_asset_library if @asset_library.back_to_library_link?
    @asset_library.click_upload_file_link
    @asset_library.enter_file_path_for_upload @asset.file_name
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
