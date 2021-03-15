class SquiggyAssetLibraryListViewPage

  include PageObject
  include Page
  include Logging
  include SquiggyAssetLibrarySearchForm
  include SquiggyAssetLibraryMetadataForm

  button(:upload_button, id: 'go-upload-asset-btn')
  button(:add_link_button, id: 'go-add-link-asset-btn')
  button(:manage_assets_button, id: 'manage-assets-btn')
  elements(:asset, :div, xpath: '//div[starts-with(@id, "asset-")]')

  def click_add_url_button
    wait_for_update_and_click_js add_link_button_element
  end

  def add_link_asset(asset)
    click_add_url_button
    enter_url_metadata asset
    click_save_link_button
  end

  def wait_for_assets
    wait_until(Utils.short_wait) { asset_elements.any? }
    sleep 1
  end

  def asset_xpath(asset)
    "//div[@id='asset-#{asset.id}']"
  end

  def asset_el(asset)
    div_element(asset_xpath asset)
  end

  def visible_list_view_asset_data(asset)
    xpath = asset_xpath(asset)
    title_el = div_element(xpath: "#{xpath}//div[contains(@class, \"asset-metadata\")]/div[1]")
    owner_el = div_element(xpath: "#{xpath}//div[contains(@class, \"asset-metadata\")]/div[2]")
    view_count_el = div_element(xpath: "#{xpath}//*[@data-icon='eye']/..")
    like_count_el = div_element(xpath: "#{xpath}//*[@data-icon='thumbs-up']/..")
    comment_count_el = div_element(xpath: "#{xpath}//*[@data-icon='comment']/..")
    {
      title: (title_el.text if title_el.exists?),
      owner: (owner_el.text.gsub('by', '').strip if owner_el.exists?),
      view_count: (view_count_el.text.strip.to_i if view_count_el.exists?),
      like_count: (like_count_el.text.strip.to_i if like_count_el.exists?),
      comment_count: (comment_count_el.text.strip.to_i if comment_count_el.exists?)
    }
  end

  def click_manage_assets_link
    wait_for_load_and_click manage_assets_button_element
  end

  def click_asset_link(asset)
    logger.info "Clicking thumbnail for asset ID #{asset.id}"
    wait_for_update_and_click asset_el(asset)
  end

end
