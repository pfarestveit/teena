class SquiggyAssetLibraryListViewPage

  include PageObject
  include Page
  include Logging
  include SquiggyPages
  include SquiggyAssetLibrarySearchForm
  include SquiggyAssetLibraryMetadataForm

  def create_asset(test, asset)
    load_page test
    asset.file_name ? upload_file_asset(asset) : add_link_asset(asset)
  end

  ### UPLOADING FILES

  button(:upload_button, id: 'go-upload-asset-btn')

  def click_upload_file_button
    wait_for_update_and_click upload_button_element
  end

  def upload_file_asset(asset)
    logger.info "Uploading asset with file name '#{asset.file_name}'"
    click_upload_file_button
    enter_and_upload_file asset
    get_asset_id asset
  end

  ### ADDING LINKS

  button(:add_link_button, id: 'go-add-link-asset-btn')
  span(:bad_jam_error_msg, xpath: "//span[text()='In order to add a Google Jamboard to the Asset Library, sharing must be set to \"Anyone with the link.\"']")

  def click_add_url_button
    wait_for_update_and_click add_link_button_element
  end

  def add_link_asset(asset)
    logger.info "Adding asset with URL '#{asset.url}'"
    click_add_url_button
    enter_url asset
    enter_asset_metadata asset
    click_save_link_button
    get_asset_id asset
  end

  # BIZMARKLET

  link(:add_assets_easily_link, id: 'link-to-bookmarklet-start')
  div(:no_eligible_images_msg, xpath: '//div[contains(text(), "The current page has no images of sufficient size for the Asset Library.")]')
  button(:next_steps_button, id: 'go-to-next-step-btn')
  link(:bizmarklet_link, xpath: '//a[contains(@class, "bookmarklet")]')
  radio_button(:bizmarklet_add_page_button, id: 'entire-page-as-asset-radio')
  radio_button(:bizmarklet_add_items_button, id: 'selected-items-from-page-radio')
  button(:bizmarklet_select_all_button, id: 'select-all-images-btn')
  elements(:bizmarklet_asset_title_input, :text_field, xpath: '//input[contains(@id, "add-asset-title-input-"]')
  elements(:bizmarklet_asset_desc_input, :text_area, xpath: '//textarea[contains(@id, "asset-description-textarea-")]')

  button(:bizmarklet_next_button, id: 'go-next-btn')
  button(:bizmarklet_previous_button, id: 'go-previous-btn')
  button(:bizmarklet_save_button, id: 'done-btn')
  button(:bizmarklet_close_button, id: 'close-btn')
  span(:bizmarklet_success_msg, xpath: '//span[text()=" Success! "]')

  def select_images_cbx(idx)
    text_field_element(id: "image-checkbox-#{idx}")
  end

  def asset_titles_input(idx)
    text_field_element(id: "asset-title-input-#{idx}")
  end

  def asset_categories_input(idx)
    text_field_element(id: "asset-category-select-#{idx}-select")
  end

  def asset_descrips_input(idx)
    text_area_element(id: "asset-description-textarea-#{idx}")
  end

  def get_bizmarklet
    wait_for_update_and_click add_assets_easily_link_element
    wait_for_update_and_click next_steps_button_element
    sleep 1
    wait_for_update_and_click next_steps_button_element
    sleep 1
    bizmarklet_link_element.when_present Utils.short_wait
    bizmarklet_link_element.attribute('href').gsub('javascript:(() => ', '')[0..-4].gsub('%20', ' ').gsub('%27', "'")
  end

  def launch_bizmarklet(js)
    sleep 1
    original_window = @driver.window_handle
    execute_script(js)
    wait_until(Utils.short_wait) { @driver.window_handles.length > 1 }
    @driver.switch_to.window @driver.window_handles.last
    original_window
  end

  def cancel_bizmarklet(original_window)
    wait_for_update_and_click cancel_button_element
    @driver.switch_to.window original_window
  end

  def close_bookmarklet(original_window)
    wait_for_update_and_click bizmarklet_close_button_element
    @driver.switch_to.window original_window
  end

  def click_bizmarklet_add_items
    js_click bizmarklet_add_items_button_element
  end

  def select_bizmarklet_items(assets)
    assets.each_with_index { |_, idx| js_click select_images_cbx(idx) }
  end

  def click_bizmarklet_next_button
    wait_for_update_and_click bizmarklet_next_button_element
  end

  def save_bizmarklet_assets
    wait_for_update_and_click bizmarklet_save_button_element
    bizmarklet_success_msg_element.when_visible Utils.short_wait
  end

  def enter_bizmarklet_items_metadata(assets)
    assets.each_with_index do |asset, idx|
      enter_squiggy_text(asset_titles_input(idx), asset.title.to_s)
      sleep Utils.click_wait
      asset.title = asset_titles_input(idx).value
      scroll_to_bottom
      enter_squiggy_text(asset_descrips_input(idx), asset.description.to_s)
      if asset.category
        asset_categories_input(idx).when_present Utils.short_wait
        js_click asset_categories_input(idx)
        select_squiggy_option asset.category.name
      end
    end
  end

  # MANAGE ASSETS

  button(:manage_assets_button, id: 'manage-assets-btn')
  h2(:manage_assets_heading, xpath: '//h2[text()="Manage Assets"]')

  def click_manage_assets_link
    tries ||=2
    manage_assets_button_element.when_visible Utils.short_wait
    sleep 1
    wait_for_update_and_click manage_assets_button_element
    manage_assets_heading_element.when_visible Utils.short_wait
  rescue => e
    logger.error e.message
     (tries -= 1).zero? ? fail : retry
  end

  # LIST VIEW ASSETS

  def load_page(test)
    navigate_to test.course_site.asset_library_url
    wait_until(Utils.medium_wait) { title == SquiggyTool::ASSET_LIBRARY.name }
    hide_canvas_footer_and_popup
    switch_to_canvas_iframe
  end

  def wait_for_assets(test)
    start = Time.now
    tries ||= 2
    wait_until(Utils.medium_wait) { asset_elements.any? }
  rescue => e
    logger.error e.message
    if (tries -= 1).zero?
      fail
    else
      load_page test
      retry
    end
  ensure
    logger.warn "PERF - took #{Time.now - start} seconds for assets to appear"
    sleep Utils.click_wait
  end

  def get_asset_id(asset)
    wait_until(Utils.medium_wait) { !SquiggyUtils.set_asset_id(asset).empty? }
  end

  def asset_xpath(asset)
    "//div[@id='asset-#{asset.id}']"
  end

  def asset_el(asset)
    div_element(xpath: asset_xpath(asset))
  end

  def canvas_submission_title(asset)
    # For Canvas submissions, the file name or the URL are used as the asset title
    asset.title = asset.file_name || asset.url
  end

  def load_list_view_asset(test, asset)
    load_page test
    wait_until(Utils.medium_wait) do
      scroll_to_bottom
      sleep 1
      asset_el(asset).exists?
    end
  end

  def visible_list_view_asset_data(asset)
    xpath = asset_xpath(asset)
    begin
      tries ||= 2
      start = Time.now
      asset_el(asset).when_present Utils.short_wait
    rescue => e
      logger.error e.message
      if (tries -= 1).zero?
        fail
      else
        refresh_page
        switch_to_canvas_iframe
        retry
      end
    end
    logger.warn "PERF - took #{Time.now - start} seconds for asset element to become visible"
    sleep 1
    title_el = div_element(xpath: "#{xpath}//div[contains(@class, 'asset-metadata')]//span[1]")
    owner_el = div_element(xpath: "#{xpath}//div[contains(@class, 'asset-metadata')]//span[2]")
    view_count_el = div_element(xpath: "#{xpath}/following-sibling::div//*[@data-icon='eye']/..")
    like_count_el = div_element(xpath: "#{xpath}/following-sibling::div//*[@data-icon='thumbs-up']/..")
    comment_count_el = div_element(xpath: "#{xpath}/following-sibling::div//*[@data-icon='comment']/..")
    wait_for_element(title_el, Utils.short_wait)
    wait_for_element(owner_el, Utils.short_wait)
    {
      title: (title_el.text.strip if title_el.exists?),
      owner: (owner_el.text.gsub('by', '').strip if owner_el.exists?),
      view_count: (view_count_el.text.strip if view_count_el.exists?),
      like_count: (like_count_el.text.strip if like_count_el.exists?),
      comment_count: (comment_count_el.text.strip if comment_count_el.exists?)
    }
  end

  def click_asset_link(test, asset)
    logger.info "Clicking thumbnail for asset ID #{asset.id}"
    wait_for_assets test
    wait_for_update_and_click asset_el(asset)
  end

  # CANVAS SYNC

  button(:resume_sync_button, xpath: '//button[contains(.,"Resume syncing")]')
  div(:resume_sync_success, xpath: '//div[text()=" Syncing has been resumed for this course. There may be a short delay before SuiteC tools are updated. "]')

  def ensure_canvas_sync(test, canvas_assign_page)
    add_link_button_element.when_visible Utils.medium_wait
    if resume_sync_button?
      assign = Assignment.new title: 'resume sync'
      canvas_assign_page.load_page test.course_site
      canvas_assign_page.create_assignment(test.course_site, assign)
      load_page test
      logger.info 'Resuming syncing for the course'
      wait_for_update_and_click resume_sync_button_element
      resume_sync_success_element.when_visible Utils.short_wait
    else
      logger.info 'Syncing is still enabled for this course site'
    end
  end
end
