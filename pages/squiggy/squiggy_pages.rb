module SquiggyPages

  include PageObject
  include Page
  include Logging

  button(:go_back_button, id: 'go-back-btn')
  button(:back_to_asset_library_button, id: 'asset-library-btn')
  button(:back_to_impact_studio_link, xpath: '//button[contains(., "Back to Impact Studio")]')
  button(:save_button, id: 'save-btn')
  button(:cancel_button, id: 'cancel-btn')
  button(:confirm_delete_button, id: 'confirm-delete-btn')
  button(:cancel_delete_button, id: 'cancel-delete-btn')
  elements(:asset, :div, xpath: '//div[starts-with(@id, "asset-")]')

  def click_back_button
    logger.info 'Clicking back from error message'
    wait_for_update_and_click go_back_button_element
  end

  def click_back_to_asset_library
    logger.debug 'Clicking Back to Asset Library button'
    wait_for_update_and_click back_to_asset_library_button_element
  end

  def click_back_to_impact_studio
    wait_for_load_and_click back_to_impact_studio_link_element
    wait_until(Utils.medium_wait) { title == SquiggyTool::IMPACT_STUDIO.name }
  end

  def clear_input(input_el)
    sleep Utils.click_wait
    input_el.click
    sleep Utils.click_wait
    input_el.click
    255.times { hit_backspace; hit_delete }
  end

  def enter_squiggy_text(el, str)
    logger.info "Entering '#{str}'"
    wait_for_element(el, Utils.short_wait)
    clear_input el
    el.send_keys str
  end

  # FAKE SELECT ELEMENTS

  elements(:menu_option, :div, xpath: '//div[@role="option"]')
  button(:null_option, xpath: '//button[@aria-label="clear icon"]')

  def menu_option_el(option_str)
    div_element(xpath: "//div[@role=\"option\"][contains(., \"#{option_str}\")]")
  end

  def scroll_to_menu_option(option_str)
    tries = 10
    begin
      tries -= 1
      scroll_to_element menu_option_elements.last
      menu_option_el(option_str).when_visible 1
    rescue => e
      logger.error e.message
      tries.zero? ? fail : retry
    end
  end

  def select_squiggy_option(option_str)
    js_click menu_option_el(option_str)
    sleep Utils.click_wait
  end

  def click_clear_button
    wait_for_update_and_click null_option_element
  end

  # ERROR

  span(:lenny_and_squiggy, id: 'unauthorized-message')

  # WHITEBOARDS

  button(:cancel_asset_upload_button, id: 'upload-file-cancel-btn')
  button(:close_modal_button, id: 'close-btn')

  def click_cancel_upload_button
    wait_for_update_and_click cancel_asset_upload_button_element
  end

  def click_cancel_link_button
    wait_for_update_and_click cancel_button_element
  end

  def click_cancel_button
    wait_for_update_and_click_js cancel_button_element
  end

  def click_close_modal_button
    wait_for_update_and_click_js close_modal_button_element
  end

  def get_whiteboard_id(link_element)
    link_element.when_present Utils.short_wait
    partial_url = link_element.attribute('href').split('?').first
    partial_url.split('/').last
  end

  def shift_to_whiteboard_window(whiteboard)
    wait_until(Utils.short_wait) { window_count > 1 }
    switch_to_last_window
    wait_until(Utils.medium_wait) { title.include? whiteboard.title }
  end

  # ASSETS

  def assets_visible_non_deleted(assets)
    assets.select(&:visible).reject(&:deleted)
  end

  def assets_most_recent(assets)
    assets_visible_non_deleted(assets).sort_by(&:id).reverse[0..3]
  end

  def assets_most_viewed(assets)
    assets_visible_non_deleted(assets).sort_by { |a| [a.count_views, a.id] }.reverse[0..3]
  end

  def assets_most_liked(assets)
    assets_visible_non_deleted(assets).sort_by { |a| [a.count_likes, a.id] }.reverse[0..3]
  end

  def assets_most_commented(assets)
    assets_visible_non_deleted(assets).sort_by { |a| [a.comments.length, a.id] }.reverse[0..3]
  end

end
