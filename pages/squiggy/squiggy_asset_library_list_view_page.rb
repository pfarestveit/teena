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
  span(:bad_jam_error_msg, xpath: "//span[text()='In order to add a Google Jamboard to the Asset Library, sharing must be set to \"Anyone with the link.\"']")

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

  def click_manage_assets_link
    manage_assets_button_element.when_visible Utils.short_wait
    sleep 1
    wait_for_update_and_click manage_assets_button_element
  end

  # LIST VIEW ASSETS

  def load_page(test)
    navigate_to test.course.asset_library_url
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

  def visible_asset_ids
    els = div_elements(xpath: '//div[contains(@class, "v-card")][contains(@id, "asset-")]')
    els.map { |el| el.attribute('id').split('-').last }
  end

  def get_asset_id(asset)
    wait_until(Utils.short_wait) { !SquiggyUtils.set_asset_id(asset).empty? }
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
    title_el = div_element(xpath: "#{xpath}//div[contains(@class, 'asset-metadata')]/div[1]")
    owner_el = div_element(xpath: "#{xpath}//div[contains(@class, 'asset-metadata')]/div[2]")
    view_count_el = div_element(xpath: "#{xpath}//*[@data-icon='eye']/..")
    like_count_el = div_element(xpath: "#{xpath}//*[@data-icon='thumbs-up']/..")
    comment_count_el = div_element(xpath: "#{xpath}//*[@data-icon='comment']/..")
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

  # SEARCH / FILTER

  def parameter_option(option)
    span_element(xpath: "//span[text()=\"#{option}\"]")
  end

  def parameter_clear_button(parameter)
    button_element(xpath: "//label[text()='#{parameter}']/following-sibling::div[@class='v-input__append-inner']//button")
  end

  # Simple search

  text_area(:search_input, id: 'basic-search-input')
  button(:search_button, id: 'search-btn')

  def simple_search(keyword)
    logger.info "Performing simple search of asset library by keyword '#{keyword}'"
    click_cancel_advanced_search if cancel_advanced_search?
    wait_for_textbox_and_type(search_input_element, keyword)
    wait_for_update_and_click search_button_element
  end

  # Advanced search

  button(:advanced_search_button, id: 'search-assets-btn')
  button(:advanced_search_reset_button, id: 'reset-adv-search-btn')
  text_area(:keyword_search_input, id: 'adv-search-keywords-input')
  button(:keyword_clear_button, xpath: '//input[@id="adv-search-keywords-input"]/../following-sibling::div//button')

  def open_advanced_search
    scroll_to_top
    sleep Utils.click_wait
    if keyword_search_input_element.visible?
      logger.debug 'Advanced search input is already visible'
      advanced_search_reset_button if advanced_search_reset_button?
    else
      wait_for_load_and_click_js advanced_search_button_element
    end
  end

  # Category

  select_list(:category_select, id: 'adv-search-categories-select')
  button(:category_clear_button, xpath: '//input[@id="adv-search-categories-select"]/../following-sibling::div//button')

  def click_category_search_select
    category_select_element.when_present 2
    js_click category_select_element
  end

  # Uploader

  select_list(:uploader_select, id: 'adv-search-user-select')
  div(:selected_user, id: 'adv-search-user-option-selected')
  button(:user_clear_button, xpath: '//input[@id="adv-search-user-select"]/../following-sibling::div//button')

  def click_uploader_select
    uploader_select_element.when_present 2
    js_click uploader_select_element
  end

  def asset_uploader_options
    span_elements(xpath: '//span[contains(@id, "adv-search-user-option")]').map &:text
  end

  def asset_uploader_selected
    wait_until(Utils.short_wait) { selected_user? && !selected_user.empty? }
    selected_user
  end

  # Asset type

  select_list(:asset_type_select, id: 'adv-search-asset-types-select')
  div(:selected_asset_type, id: 'adv-search-asset-types-option-selected')
  button(:asset_type_clear_button, xpath: '//input[@id="adv-search-asset-types-select"]/../following-sibling::div//button')

  def click_asset_type_select
    asset_type_select_element.when_present 2
    js_click asset_type_select_element
  end

  def asset_type_options
    span_elements(xpath: '//span[contains(@id, "adv-search-asset-types-option")]').map &:text
  end

  # Section

  select_list(:section_select, id: 'adv-search-section-select')
  div(:selected_section, id: 'adv-search-section-option-selected')
  button(:section_clear_button, xpath: '//input[@id="adv-search-section-select"]/../following-sibling::div//button')

  def click_section_select
    section_select_element.when_present 2
    js_click section_select_element
  end

  def section_options
    span_elements(xpath: '//span[contains(@id, "adv-search-section-option")]').map &:text
  end

  # Sort by

  select_list(:sort_by_select, id: 'adv-search-order-by-option-selected')
  div(:selected_sort, id: 'adv-search-order-by-option-selected')

  def click_sort_by_select
    sort_by_select_element.when_present 2
    js_click sort_by_select_element
  end

  def sort_by_options
    span_elements(xpath: '//span[contains(@id, "adv-search-order-by-option")]').map &:text
  end

  # Advanced search form

  button(:advanced_search_submit, id: 'adv-search-btn')
  button(:cancel_advanced_search, id: 'cancel-adv-search-btn')
  span(:no_results_msg, xpath: '//span[text()="No matching assets found"]')

  def advanced_search(keyword, category, user, asset_type, section, sort_by)
    logger.info "Searching keyword '#{keyword}', category '#{category.name if category}', user '#{user&.full_name}',
                          asset type '#{asset_type}', section '#{section&.sis_id}', sort by '#{sort_by}'."
    open_advanced_search
    if keyword
      wait_for_textbox_and_type(keyword_search_input_element, keyword)
    else
      wait_for_textbox_and_type(keyword_search_input_element, '')
    end

    if category
      click_category_search_select
      wait_for_update_and_click_js parameter_option(category.name)
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

    if section
      click_section_select
      wait_for_update_and_click_js parameter_option(section.sis_id)
    elsif section_select?
      js_click(parameter_clear_button('Section')) if parameter_clear_button('Section').visible?
    end

    click_sort_by_select
    if sort_by
      wait_for_update_and_click_js parameter_option(sort_by)
    else
      wait_for_update_and_click_js parameter_option('Most recent')
    end
    wait_for_update_and_click advanced_search_submit_element
  end

  def wait_for_asset_results(assets)
    sleep 1
    expected = assets.map &:id
    wait_until(3, "Expected #{expected}, got #{visible_asset_ids}") { visible_asset_ids == expected }
  end

  def wait_for_no_results
    no_results_msg_element.when_visible 3
  end

  def click_cancel_advanced_search
    wait_for_update_and_click cancel_advanced_search_element
  end

  # CANVAS SYNC

  button(:resume_sync_button, xpath: '//button[contains(.,"Resume syncing")]')
  div(:resume_sync_success, xpath: '//div[text()=" Syncing has been resumed for this course. There may be a short delay before SuiteC tools are updated. "]')

  def ensure_canvas_sync(test, canvas_assign_page)
    add_link_button_element.when_visible Utils.short_wait
    if resume_sync_button?
      assign = Assignment.new title: 'resume sync'
      canvas_assign_page.load_page test.course
      canvas_assign_page.create_assignment(test.course, assign)
      load_page test
      logger.info 'Resuming syncing for the course'
      wait_for_update_and_click resume_sync_button_element
      resume_sync_success_element.when_visible Utils.short_wait
    else
      logger.info 'Syncing is still enabled for this course site'
    end
  end
end
