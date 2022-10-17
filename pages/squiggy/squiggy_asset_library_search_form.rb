module SquiggyAssetLibrarySearchForm

  include PageObject
  include Page
  include Logging
  include SquiggyPages

  text_field(:search_input, id: 'basic-search-input')
  button(:expand_search_button, id: 'search-assets-btn')
  text_field(:adv_search_input, id: 'adv-search-keywords-input')
  text_field(:adv_search_categories_input, id: 'adv-search-categories-select')
  text_field(:adv_search_asset_types_input, id: 'adv-search-asset-types-select')
  text_field(:adv_search_asset_owners_input, id: 'adv-search-user-select')
  text_field(:adv_search_sections_input, id: 'adv-search-section-select')
  text_field(:adv_search_sorting_input, id: 'adv-search-order-by-select')
  button(:adv_search_button, id: 'adv-search-btn')
  button(:adv_search_cancel_button, id: 'cancel-adv-search-btn')

  def search_by_keyword(string)
    logger.info "Searching by keyword '#{string}'"
    search_input_element.when_visible Utils.short_wait
    clear_input search_input_element
    search_input_element.send_keys string
    sleep 1
    hit_enter
  end

  def expand_adv_search
    logger.info 'Expanding advanced search form'
    wait_for_update_and_click expand_search_button_element
  end

  def enter_adv_search_term(string)
    logger.info "Entering advanced search term '#{string}'"
    adv_search_input_element.when_visible Utils.short_wait
    clear_input adv_search_input_element
    adv_search_input_element.send_keys string
    sleep 1
  end

  def select_adv_search_category(category)
    logger.info "Selecting advanced search category '#{category}'"
    wait_for_update_and_click_js adv_search_categories_input_element
    select_squiggy_option category
    sleep 1
  end

  def select_adv_search_asset_type(type)
    logger.info "Selecting asset type '#{type}'"
    wait_for_update_and_click_js adv_search_asset_types_input_element
    select_squiggy_option type
    sleep 1
  end

  def select_adv_search_asset_owner(owner)
    logger.info "Selecting asset owner '#{owner}'"
    wait_for_update_and_click_js adv_search_asset_owners_input_element
    select_squiggy_option owner
    sleep 1
  end

  def select_adv_search_section(section)
    logger.info "Selecting section '#{section.sis_id}'"
    wait_for_update_and_click_js adv_search_sections_input_element
    select_squiggy_option section.sis_id
    sleep 1
  end

  def select_adv_search_sorting(sort)
    logger.info "Selecting search results sort-by '#{sort}'"
    wait_for_update_and_click_js adv_search_sorting_input_element
    select_squiggy_option sort
    sleep 1
  end

  def click_adv_search_button
    logger.info 'Clicking advanced search button'
    wait_for_update_and_click adv_search_button_element
  end

  def click_adv_search_cancel_button
    logger.info 'Clicking advanced search cancel button'
    wait_for_update_and_click adv_search_cancel_button_element
  end

end
