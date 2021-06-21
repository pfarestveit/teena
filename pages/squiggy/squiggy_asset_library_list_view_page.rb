class SquiggyAssetLibraryListViewPage

  include PageObject
  include Page
  include Logging
  include SquiggyAssetLibrarySearchForm
  include SquiggyAssetLibraryMetadataForm

  ### UPLOADING FILES

  button(:upload_button, id: 'go-upload-asset-btn')

  def click_upload_file_button
    wait_for_update_and_click_js upload_button_element
  end

  def upload_file_asset(asset)
    logger.info "Uploading asset with file name '#{asset.file_name}'"
    click_upload_file_button
    enter_and_upload_file asset
    get_asset_id asset
  end

  ### ADDING LINKS

  button(:add_link_button, id: 'go-add-link-asset-btn')

  def click_add_url_button
    wait_for_update_and_click_js add_link_button_element
  end

  def add_link_asset(asset)
    logger.info "Adding asset with URL '#{asset.url}'"
    click_add_url_button
    enter_url asset
    enter_asset_metadata asset
    click_save_link_button
    get_asset_id asset
  end

  # MANAGE ASSETS

  button(:manage_assets_button, id: 'manage-assets-btn')

  def click_manage_assets_link
    wait_for_load_and_click manage_assets_button_element
  end

  # LIST VIEW ASSETS

  elements(:asset, :div, xpath: '//div[starts-with(@id, "asset-")]')

  def load_page(test)
    navigate_to test.course.asset_library_url
    wait_until(Utils.medium_wait) { title == SquiggyTool::ASSET_LIBRARY.name }
    hide_canvas_footer_and_popup
    switch_to_canvas_iframe
  end

  def wait_for_assets
    start = Time.now
    wait_until(Utils.medium_wait) { asset_elements.any? }
    logger.warn "PERF - took #{Time.now - start} seconds for assets to appear"
    sleep Utils.click_wait
  end

  def get_asset_id(asset)
    wait_for_assets
    SquiggyUtils.set_asset_id asset
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
    start = Time.now
    asset_el(asset).when_present Utils.short_wait
    logger.warn "PERF - took #{Time.now - start} seconds for asset element to become visible"
    start = Time.now
    thumbnail_el = div_element(xpath: "#{xpath}//div[contains(@style, \"background-image\")]")
    thumbnail_el.when_present Utils.short_wait
    logger.warn "PERF - took #{Time.now - start} seconds for asset thumbnail to become visible"
    title_el = div_element(xpath: "#{xpath}//div[contains(@class, \"asset-metadata\")]/div[1]")
    wait_until(2) { title_el.text }
    owner_el = div_element(xpath: "#{xpath}//div[contains(@class, \"asset-metadata\")]/div[2]")
    view_count_el = div_element(xpath: "#{xpath}//*[@data-icon='eye']/..")
    like_count_el = div_element(xpath: "#{xpath}//*[@data-icon='thumbs-up']/..")
    comment_count_el = div_element(xpath: "#{xpath}//*[@data-icon='comment']/..")
    {
      title: (title_el.text if title_el.exists?),
      owner: (owner_el.text.gsub('by', '').strip if owner_el.exists?),
      view_count: (view_count_el.text.strip if view_count_el.exists?),
      like_count: (like_count_el.text.strip if like_count_el.exists?),
      comment_count: (comment_count_el.text.strip if comment_count_el.exists?)
    }
  end

  def click_asset_link(asset)
    logger.info "Clicking thumbnail for asset ID #{asset.id}"
    wait_for_update_and_click asset_el(asset)
  end

  # SEARCH / FILTER

  text_area(:search_input, id: 'basic-search-input')
  button(:search_button, id: 'search-btn')

  button(:advanced_search_button, id: 'search-assets-btn')
  text_area(:keyword_search_input, id: 'adv-search-keywords-input')
  select_list(:category_select, id: 'adv-search-categories-select')
  select_list(:uploader_select, id: 'adv-search-user-select')
  select_list(:asset_type_select, id: 'adv-search-asset-types-select')
  select_list(:sort_by_select, id: 'adv-search-order-by-option-selected')
  button(:advanced_search_submit, id: 'adv-search-btn')
  button(:cancel_advanced_search, id: 'cancel-adv-search-btn')

  def parameter_option(option)
    span_element(xpath: "//span[text()=\"#{option}\"]")
  end

  def parameter_clear_button(parameter)
    button_element(xpath: "//label[text()='#{parameter}']/following-sibling::div[@class='v-input__append-inner']//button")
  end

  def simple_search(keyword)
    logger.info "Performing simple search of asset library by keyword '#{keyword}'"
    wait_for_update_and_click(cancel_advanced_search_element) if cancel_advanced_search?
    search_input_element.when_visible Utils.short_wait
    search_input_element.clear
    search_input_element.send_keys(keyword) unless keyword.nil?
    wait_for_update_and_click search_button_element
  end

  def open_advanced_search
    sleep Utils.click_wait
    if keyword_search_input_element.visible?
      logger.debug 'Advanced search input is already visible'
    else
      wait_for_load_and_click advanced_search_button_element
    end
  end

  def click_category_select
    category_select_element.when_present 2
    js_click category_select_element
  end

  def click_uploader_select
    uploader_select_element.when_present 2
    js_click uploader_select_element
  end

  def click_asset_type_select
    asset_type_select_element.when_present 2
    js_click asset_type_select_element
  end

  def click_sort_by_select
    sort_by_select_element.when_present 2
    js_click sort_by_select_element
  end

  def advanced_search(keyword, category, user, asset_type, sort_by)
    logger.info "Performing advanced search by keyword '#{keyword}', category '#{category}', user '#{user && user.full_name}', asset type '#{asset_type}', sort by '#{sort_by}'."
    open_advanced_search
    if keyword
      wait_for_element_and_type(keyword_search_input_element, keyword)
    else
      wait_for_element_and_type(keyword_search_input_element, '')
    end

    if category
      click_category_select
      wait_for_update_and_click_js parameter_option(category)
    else
      js_click(parameter_clear_button('Category')) if parameter_clear_button('Category').visible?
    end

    if user
      click_uploader_select
      wait_for_update_and_click_js parameter_option(user.full_name)
    else
      js_click(parameter_clear_button('User')) if parameter_clear_button('User').visible?
    end

    if asset_type
      click_asset_type_select
      wait_for_update_and_click_js parameter_option(asset_type)
    else
      js_click(parameter_clear_button('Asset type')) if parameter_clear_button('Asset type').visible?
    end

    click_sort_by_select
    if sort_by
      wait_for_update_and_click_js parameter_option(sort_by)
    else
      wait_for_update_and_click_js parameter_option('Most recent')
    end
    wait_for_update_and_click advanced_search_submit_element
  end

end
