require_relative '../util/spec_helper'

begin

  whiteboards = SquiggyUtils.whiteboards.map { |i| SquiggyWhiteboard.new id: i }

  @driver = Utils.launch_browser
  @assets_list = SquiggyAssetLibraryListViewPage.new @driver
  @whiteboards = SquiggyWhiteboardPage.new @driver

  @assets_list.dev_auth(SquiggyUtils.dev_auth_user_id, SquiggyUtils.dev_auth_password)

  whiteboards.each do |whiteboard|
    tab = @whiteboards.open_new_window
    @whiteboards.hit_whiteboard_url whiteboard
    @whiteboards.canvas_element.when_present Utils.short_wait
    whiteboard.window_handle = tab
  end

  whiteboards.each do |whiteboard|
    @whiteboards.switch_to_window_handle whiteboard.window_handle
    SquiggyUtils.load_test_reps.times do |i|
      @whiteboards.add_squiggle(10*i, 10*i)
      @whiteboards.add_shape(20*i, 20*i)
      @whiteboards.add_url_and_drag('https://news.google.com', 30*i, 30*i)
    end
    @whiteboards.click_export_button
    @whiteboards.click_download_as_image_button
  end

rescue => e
  Utils.log_error e
  Utils.log_js_errors @driver
ensure
  Utils.quit_browser @driver
end
