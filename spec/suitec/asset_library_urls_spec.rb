require_relative '../../util/spec_helper'

describe 'Asset Library URLs', order: :defined do

  test_id = Utils.get_test_id
  timeout = Utils.short_wait

  before(:all) do
    @course = Course.new({})
    @course.site_id = ENV['course_id']

    # Get test user and asset
    test_user_data = Utils.load_test_users.find { |data| data['tests']['assetLibraryUrls'] }
    @user = User.new test_user_data
    @asset = Asset.new @user.assets.find { |asset| asset['type'] == 'Link' }
    @title = "#{@asset.title} - #{test_id}"
    @description = "#{@asset.description} - #{test_id}"
    @url = @asset.url

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net= Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryPage.new @driver

    # Create test course site
    @canvas.log_in(@cal_net, Utils.ets_qa_username, Utils.ets_qa_password)
    @canvas.get_suite_c_test_course(@driver, @course, [@user], test_id, [SuiteCTools::ASSET_LIBRARY])

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

  after(:all) { @driver.quit }

  # Metadata

  it 'can be added with title, category, and description' do
    @asset.title = "#{@title} 1"
    @asset.description = @description
    @asset.category = @category_1
    @asset_library.add_site @asset
    @asset_library.wait_until(timeout) { @asset_library.list_view_asset_elements.any? }
    @asset_library.verify_first_asset(@user, @asset)
  end

  it 'can be added with title and category only' do
    @asset.title = "#{@title} 2"
    @asset.description = nil
    @asset.category = @category_1
    @asset_library.add_site @asset
    @asset_library.wait_until(timeout) { @asset_library.list_view_asset_elements.any? }
    @asset_library.verify_first_asset(@user, @asset)
  end

  it 'can be added with title only' do
    @asset.title = "#{@title} 3"
    @asset.description = nil
    @asset.category = nil
    @asset_library.add_site @asset
    @asset_library.wait_until(timeout) { @asset_library.list_view_asset_elements.any? }
    @asset_library.verify_first_asset(@user, @asset)
  end

  it 'can be added with title and description only' do
    @asset.title = "#{@title} 4"
    @asset.description = @description
    @asset.category = nil
    @asset_library.add_site @asset
    @asset_library.wait_until(timeout) { @asset_library.list_view_asset_elements.any? }
    @asset_library.verify_first_asset(@user, @asset)
  end

  # Validation

  it 'require that the user enter a URL' do
    @asset.title = "#{@title} 5"
    @asset.description = nil
    @asset.category = nil
    @asset.url = nil
    @asset_library.click_add_site_link
    @asset_library.enter_and_submit_url @asset
    @asset_library.missing_url_error_element.when_visible timeout
    expect(@asset_library.url_title_input).to eql(@asset.title)
  end

  it 'require that the user enter a valid URL' do
    @asset.title = "#{@title} 6"
    @asset.description = nil
    @asset.category = nil
    @asset.url = 'foo bar'
    @asset_library.click_add_site_link
    @asset_library.enter_and_submit_url @asset
    @asset_library.bad_url_error_element.when_visible timeout
    expect(@asset_library.url_input).to eql("http://#{@asset.url}")
    expect(@asset_library.url_title_input).to eql(@asset.title)
  end

  it 'require that the user enter a title' do
    @asset.title = nil
    @asset.description = nil
    @asset.category = nil
    @asset.url = @url
    @asset_library.click_add_site_link
    @asset_library.enter_and_submit_url @asset
    @asset_library.wait_until(timeout) { @asset_library.missing_title_error_elements.any? }
    expect(@asset_library.url_input).to include(@asset.url)
  end

  it 'limit a title to 255 characters' do
    @asset.title = "#{'A loooooong title' * 15}?"
    @asset.description = nil
    @asset.category = nil
    @asset.url = @url
    @asset_library.click_add_site_link
    @asset_library.enter_and_submit_url @asset
    @asset_library.wait_until(timeout) { @asset_library.long_title_error_elements.any? }
    @asset.title = @asset.title[0, 255]
    @asset_library.add_site @asset
    @asset_library.wait_until(timeout) { @asset_library.list_view_asset_elements.any? }
    @asset_library.verify_first_asset(@user, @asset)
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
