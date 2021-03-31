class SquiggyAssetLibraryManageAssetsPage

  include PageObject
  include Page
  include SquiggyPages
  include Logging

  h2(:manage_assets_heading, xpath: '//h2[text()="Manage Assets"]')

  text_field(:add_category_input, id: 'add-category-input')
  button(:add_category_button, id: 'add-category-btn')
  elements(:category_title, :div, class: 'v-list-item__title')
  elements(:category_usage_count, :div, class: 'v-list-item__subtitle')

  def enter_category_name(name)
    wait_for_element_and_type(add_category_input_element, name)
  end

  def click_add_category_button
    wait_for_update_and_click add_category_button_element
  end

  def create_new_category(name)
    logger.info "Creating a new category called '#{name}'"
    enter_category_name name
    click_add_category_button
  end

end
