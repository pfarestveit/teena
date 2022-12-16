module SquiggyAssetLibrarySearchForm

  include PageObject
  include Page
  include Logging
  include SquiggyPages

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
    sleep Utils.click_wait
    if uploader_select?
      logger.debug 'Advanced search input is already visible'
      scroll_to_top
      advanced_search_reset_button if advanced_search_reset_button?
    else
      scroll_to_top
      wait_for_load_and_click advanced_search_button_element
    end
  end

  # Category

  select_list(:category_select, id: 'adv-search-categories-select')
  button(:category_clear_button, xpath: '//input[@id="adv-search-categories-select"]/../following-sibling::div//button')

  def click_category_search_select
    category_select_element.when_present 2
    js_click category_select_element
    sleep Utils.click_wait
  end

  # Uploader

  select_list(:uploader_select, id: 'adv-search-user-select')
  div(:selected_user, id: 'adv-search-user-option-selected')
  button(:user_clear_button, xpath: '//input[@id="adv-search-user-select"]/../following-sibling::div//button')

  def click_uploader_select
    uploader_select_element.when_present 2
    js_click uploader_select_element
    sleep Utils.click_wait
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
    sleep Utils.click_wait
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
    sleep Utils.click_wait
  end

  def section_options
    span_elements(xpath: '//span[contains(@id, "adv-search-section-option")]').map &:text
  end

  # Group

  select_list(:group_select, id: 'adv-search-group-set-select')
  div(:selected_group, id: 'adv-search-group-set-option-selected')
  button(:group_clear_button, xpath: '//input[@id="adv-search-group-set-select"]/../following-sibling::div//button')

  def click_group_select
    group_select_element.when_present 2
    js_click group_select_element
    sleep Utils.click_wait
  end

  def group_options
    span_elements(xpath: '//span[contains(@id, "adv-search-group-set-option")]').map &:text
  end

  # Sort by

  select_list(:sort_by_select, id: 'adv-search-order-by-option-selected')
  div(:selected_sort, id: 'adv-search-order-by-option-selected')

  def click_sort_by_select
    sort_by_select_element.when_present 2
    js_click sort_by_select_element
    sleep Utils.click_wait
  end

  def sort_by_options
    span_elements(xpath: '//span[contains(@id, "adv-search-order-by-option")]').map &:text
  end

  # Advanced search form

  button(:advanced_search_submit, id: 'adv-search-btn')
  button(:cancel_advanced_search, id: 'cancel-adv-search-btn')
  span(:no_results_msg, xpath: '//span[text()="No matching assets found"]')

  def advanced_search(keyword, category, user, asset_type, section, group, sort_by)
    logger.info "Searching keyword '#{keyword}', category '#{category.name if category}', user '#{user&.full_name}',
                          asset type '#{asset_type}', section '#{section&.sis_id}', group '#{group&.title}' sort by '#{sort_by}'."
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

    if group
      click_group_select
      wait_for_update_and_click_js parameter_option("#{group.group_set.title} - #{group.title}")
    elsif group_select?
      js_click(parameter_clear_button('Group')) if parameter_clear_button('Group').visible?
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
end
