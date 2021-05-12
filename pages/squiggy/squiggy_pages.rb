module SquiggyPages

  include PageObject
  include Page
  include Logging

  button(:back_to_asset_library_button, id: 'asset-library-btn')

  def click_back_to_asset_library
    logger.debug 'Clicking Back to Asset Library button'
    2.times { wait_for_update_and_click back_to_asset_library_button_element }
  end

  def clear_input(input_el)
    input_el.click
    50.times { hit_backspace; hit_delete }
  end

  def enter_squiggy_text(el, str)
    logger.info "Entering '#{str}'"
    wait_for_element(el, Utils.short_wait)
    clear_input el
    el.send_keys str
  end

  # FAKE SELECT ELEMENTS

  elements(:menu_option, :div, xpath: '//div[@role="option"]')

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
    scroll_to_menu_option option_str
    js_click menu_option_el(option_str)
  end

end
