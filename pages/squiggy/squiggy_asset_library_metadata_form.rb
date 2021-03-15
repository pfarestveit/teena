module SquiggyAssetLibraryMetadataForm

  include PageObject
  include Page
  include Logging
  include SquiggyPages

  text_field(:url_input, id: 'asset-url-input')
  text_field(:title_input, id: 'asset-title-input')
  text_field(:category_input, id: 'asset-category-select')
  text_area(:description_input, id: 'asset-description-textarea')
  button(:save_link_button, id: 'add-link-btn')
  button(:cancel_link_button, id: 'add-link-cancel-btn')

  def enter_url_metadata(asset)
    logger.info "Entering URL '#{asset.inspect}'"
    wait_for_element_and_type(url_input_element, asset.url.to_s)
    wait_for_element_and_type(title_input_element, asset.title.to_s)
    wait_for_element_and_type(description_input_element, asset.description.to_s)
    if asset.category
      wait_for_update_and_click_js category_input_element unless asset.category.nil?
      select_menu_option asset.category
    end
  end

  def click_save_link_button
    wait_for_update_and_click_js save_link_button_element
  end

  def click_cancel_link_button
    wait_for_update_and_click_js cancel_link_button_element
  end

end
