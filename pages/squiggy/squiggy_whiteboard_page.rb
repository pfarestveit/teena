class SquiggyWhiteboardPage < SquiggyWhiteboardsPage

  include PageObject
  include Logging
  include Page
  include SquiggyPages
  include SquiggyWhiteboardEditForm
  include SquiggyAssetLibraryMetadataForm
  include SquiggyAssetLibrarySearchForm

  def hit_whiteboard_url(whiteboard)
    url = "#{SquiggyUtils.base_url}/whiteboards/#{whiteboard.id}"
    logger.debug "Hitting URL '#{url}'"
    navigate_to url
  end

  def close_whiteboard
    sleep 1
    count = window_count
    if (count > 1) && current_url.include?("#{SquiggyUtils.base_url}/whiteboard/")
      logger.debug "The browser window count is #{count}, and the current window is a whiteboard. Closing it."
      @driver.close
      switch_to_first_window
      switch_to_canvas_iframe if "#{@driver.browser}" == 'chrome'
    else
      logger.debug "The browser window count is #{count}, and the current window is not a whiteboard. Leaving it open."
    end
  end

  # EDIT WHITEBOARD

  button(:settings_button, id: 'toolbar-settings')

  def click_settings_button
    wait_for_update_and_click_js settings_button_element
  end

  def edit_whiteboard_title(whiteboard)
    click_settings_button
    enter_whiteboard_title whiteboard.title
    save_whiteboard
  end

  def add_collaborator(user)
    click_settings_button
    enter_whiteboard_collaborator user
    save_whiteboard
  end

  def remove_collaborator(user)
    click_settings_button
    click_remove_collaborator user
    save_whiteboard
  end

  def verify_collaborators(users)
    click_settings_button
    users.flatten.each { |user| collaborator_name(user).when_visible Utils.short_wait }
  end

  # DELETE/RESTORE WHITEBOARD

  button(:delete_button, xpath: 'TODO')
  button(:restore_button, xpath: 'TODO')
  span(:restored_msg, xpath: 'TODO')

  def delete_whiteboard
    logger.info "Deleting whiteboard #{title}"
    click_settings_button
    wait_for_update_and_click_js delete_button_element
    @driver.switch_to.alert.accept
    # Two alerts will appear if the user is an admin
    @driver.switch_to.alert.accept rescue Selenium::WebDriver::Error::StaleElementReferenceError
    switch_to_first_window
    switch_to_canvas_iframe if "#{@driver.browser}" == 'chrome'
  end

  def restore_whiteboard
    logger.info 'Restoring whiteboard'
    wait_for_update_and_click_js restore_button_element
    restored_msg_element.when_present Utils.short_wait
  end

  # WHITEBOARD EXPORT

  button(:export_button, xpath: 'TODO')
  button(:export_to_library_button, xpath: 'TODO')
  h2(:export_heading, xpath: 'TODO')
  div(:export_not_ready_msg, xpath: 'TODO')
  div(:export_not_possible_msg, xpath: 'TODO')
  text_area(:export_title_input, id: 'TODO')
  button(:export_confirm_button, xpath: 'TODO')
  button(:export_cancel_button, xpath: 'TODO')
  span(:export_success_msg, xpath: 'TODO')
  button(:download_as_image_button, xpath: 'TODO')

  def click_export_button
    logger.debug 'Clicking whiteboard export button'
    wait_for_load_and_click export_button_element
  end

  def export_to_asset_library(whiteboard)
    click_export_button
    logger.debug 'Exporting whiteboard to asset library'
    wait_for_update_and_click export_to_library_button_element
    wait_until(Utils.short_wait) { export_title_input == whiteboard.title }
    wait_for_update_and_click_js export_confirm_button_element
    export_title_input_element.when_not_present Utils.medium_wait
    export_success_msg_element.when_visible Utils.short_wait
    asset = SquiggyAsset.new(
      type: 'Whiteboard',
      title: whiteboard.title,
      preview: 'image'
    )
    asset.id = SquiggyUtils.set_asset_id asset
    whiteboard.asset_exports << asset
  end

  def download_as_image
    Utils.prepare_download_dir
    click_export_button
    logger.debug 'Downloading whiteboard as an image'
    wait_for_update_and_click_js download_as_image_button_element
  end

  def verify_image_download(whiteboard)
    logger.info 'Waiting for PNG file to be downloaded from whiteboard'
    expected_file_path = "#{Utils.download_dir}/#{whiteboard.title.gsub(' ', '-')}-#{Time.now.strftime('%Y-%m-%d')}-*.png"
    wait_until(Utils.medium_wait) { Dir[expected_file_path].any? }
    logger.debug 'Whiteboard converted to PNG successfully'
    true
  rescue
    logger.debug 'Whiteboard not converted to PNG successfully'
    false
  end

  # ASSETS ON WHITEBOARD

  button(:add_asset_button, id: 'toolbar-add-asset')
  button(:use_existing_button, id: 'toolbar-add-existing-assets')
  button(:upload_new_button, id: 'toolbar-upload-new-asset')
  button(:add_link_button, id: 'toolbar-asset-add-link')
  button(:add_selected_button, xpath: 'TODO')
  checkbox(:add_file_to_library_cbx, xpath: 'TODO')
  checkbox(:add_link_to_library_cbx, xpath: 'TODO')

  link(:open_original_asset_link, xpath: 'TODO')
  button(:close_original_asset_button, xpath: 'TODO')
  button(:delete_asset_button, xpath: 'TODO')

  def click_add_existing_asset
    wait_for_update_and_click add_asset_button_element unless use_existing_button_element.visible?
    wait_for_update_and_click use_existing_button_element
  end

  def add_existing_assets(assets)
    click_add_existing_asset
    assets.each { |asset| wait_for_update_and_click text_area_element(xpath: 'TODO') }
    wait_for_update_and_click_js add_selected_button_element
    add_selected_button_element.when_not_visible Utils.short_wait
  end

  def click_add_new_asset(asset)
    click_close_modal_button if close_modal_button?
    click_cancel_button if cancel_asset_button?
    if asset.type == 'File'
      wait_for_update_and_click_js add_asset_button_element unless upload_new_button?
      wait_for_update_and_click_js upload_new_button_element
    else
      wait_for_update_and_click_js add_asset_button_element unless add_link_button?
      wait_for_update_and_click_js add_link_button_element
    end
  end

  def add_asset_exclude_from_library(asset)
    click_add_new_asset asset
    (asset.file_name) ? enter_and_upload_file(asset) : enter_and_submit_url(asset)
    asset.visible = false
    open_original_asset_link_element.when_visible Utils.medium_wait
    asset.id = SquiggyUtils.set_asset_id asset
  end

  def add_asset_include_in_library(asset)
    click_add_new_asset asset
    if asset.type == 'File'
      enter_file_path_for_upload asset.file_name
      enter_asset_metadata(asset)
      check_add_file_to_library_cbx
      click_add_files_button
    else
      enter_url asset
      enter_asset_metadata asset
      check_add_link_to_library_cbx
      click_add_url_button
    end
    open_original_asset_link_element.when_visible Utils.medium_wait
    asset.id = SquiggyUtils.set_asset_id asset
  end

  def added_asset_id
    open_original_asset_link_element.attribute('href').split('?').first.split('/').last
  end

  def open_original_asset(asset_library, asset)
    wait_for_update_and_click open_original_asset_link_element
    switch_to_last_window
    wait_until(Utils.short_wait) { asset_library.detail_view_asset_title == asset.title }
  end

  def close_original_asset
    wait_for_update_and_click_js close_original_asset_button_element
    # Three windows should be open, but check how many just in case
    handle = (window_count == 2) ? 1 : 0
    switch_to_window handle
  end

  # COLLABORATORS

  div(:collaborators_pane, xpath: '//nav')
  elements(:collaborator, :span, xpath: '//nav//div[contains(@class, "v-list-item__content")]')

  def show_collaborators_pane
    mouseover collaborators_pane_element
  end

  def hide_collaborators_pane
    mouseover settings_button_element
  end

  def collaborator(user)
    div_element(xpath: "//nav//div[contains(@class, \"v-list-item__content\")][contains(., #{user.full_name})]")
  end

  def collaborator_online?(user)
    collaborator(user).text.include? 'is online'
  end
end
