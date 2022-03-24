module SquiggyAssetLibraryMetadataForm

  include PageObject
  include Page
  include Logging
  include SquiggyPages

  # FILES

  text_field(:file_input, xpath: '//input[@type="file"]')
  button(:save_file_button, id: 'upload-file-btn')
  button(:cancel_file_button, id: 'upload-file-cancel-btn')
  span(:upload_error, xpath: '//span[contains(text(), "Files can be maximum 10MB in size.")]')

  def enter_file_path_for_upload(asset)
    logger.info "Uploading #{asset.file_name}"
    file_input_element.when_present Utils.short_wait
    execute_script('arguments[0].style.height="auto"; arguments[0].style.width="auto"; arguments[0].style.visibility="visible";', file_input_element)
    sleep Utils.click_wait
    self.file_input_element.send_keys File.join(Utils.config_dir, "assets/#{asset.file_name}")
  end

  def click_add_files_button
    logger.info 'Confirming new file uploads'
    wait_for_update_and_click_js save_file_button_element
  end

  def enter_and_upload_file(asset)
    enter_file_path_for_upload asset
    enter_asset_metadata asset
    click_add_files_button
  end

  def click_cancel_file_button
    logger.info 'Clicking cancel upload button'
    wait_for_update_and_click cancel_file_button_element
  end

  # URL

  text_field(:url_input, id: 'asset-url-input')
  button(:save_link_button, id: 'add-link-btn')
  button(:cancel_link_button, id: 'add-link-cancel-btn')

  def enter_url(asset)
    logger.info "Entering URL '#{asset.url}'"
    wait_for_element_and_type(url_input_element, asset.url.to_s)
  end

  def enter_and_submit_url(asset)
    enter_url asset
    enter_asset_metadata asset
    click_save_link_button
  end

  def click_save_link_button
    wait_for_update_and_click_js save_link_button_element
  end

  def click_cancel_link_button
    wait_for_update_and_click_js cancel_link_button_element
  end

  # FILES OR URL

  text_field(:title_input, id: 'asset-title-input')
  text_field(:category_input, id: 'asset-category-select')
  text_area(:description_input, id: 'asset-description-textarea')
  div(:title_too_long_msg, xpath: '//div[text()="Title must be 255 characters or less"]')

  div(:selected_category, id: 'adv-search-categories-option-selected')

  def click_category_asset_select
    category_input_element.when_present Utils.short_wait
    js_click category_input_element
  end

  def category_clear_button
    button_element(xpath: '//input[@id="asset-category-select"]/../following-sibling::div//button')
  end

  def enter_asset_metadata(asset)
    logger.info "Entering title '#{asset.title}', category '#{asset.category}', and description '#{asset.description}'"
    enter_squiggy_text(title_input_element, asset.title.to_s)
    enter_squiggy_text(description_input_element, asset.description.to_s)
    if asset.category
      click_category_asset_select
      select_squiggy_option(asset.category.name)
    else
      wait_for_update_and_click(category_clear_button) if selected_category?
    end
  end

end
