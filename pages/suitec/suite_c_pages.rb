require_relative '../../util/spec_helper'

module Page

  module SuiteCPages

    include PageObject
    include Logging
    include Page

    # Assets UI shared across tools

    elements(:list_view_asset, :list_item, xpath: '//li[contains(@data-ng-repeat,"asset")]')
    elements(:list_view_asset_link, :link, xpath: '//li[contains(@data-ng-repeat,"asset")]//a')
    div(:no_search_results, class: 'assetlibrary-list-noresults')

    link(:upload_link, xpath: '//a[contains(.,"Upload")]')
    h2(:upload_file_heading, xpath: '//h2[text()="Upload a file"]')
    file_field(:upload_file_path_input, xpath: '//body/input[@type="file"]')
    elements(:upload_file_title_input, :text_area, id: 'assetlibrary-upload-title')
    select_list(:upload_file_category_select, id: 'assetlibrary-upload-category')
    elements(:upload_file_description_input, :text_area, id: 'assetlibrary-upload-description')
    elements(:upload_file_remove_button, :button, class: 'assetlibrary-upload-file-remove')
    button(:upload_file_button, xpath: '//button[text()="Upload files"]')
    div(:upload_error, class: 'alert-danger')

    link(:add_site_link, xpath: '//a[contains(.,"Add Link")]')
    h2(:add_url_heading, xpath: '//h2[text()="Add a link"]')
    text_area(:url_input, id: 'assetlibrary-addlink-url')
    text_area(:url_title_input, id: 'assetlibrary-addlink-title')
    select_list(:url_category, id: 'assetlibrary-addlink-category')
    text_area(:url_description, id: 'assetlibrary-addlink-description')
    button(:add_url_button, xpath: '//button[text()="Add link"]')

    div(:missing_url_error, xpath: '//div[text()="Please enter a URL"]')
    elements(:missing_title_error, :div, xpath: '//div[text()="Please enter a title"]')
    elements(:long_title_error, :div, xpath: '//div[text()="A title can only be 255 characters long"]')
    div(:bad_url_error, xpath: '//div[text()="Please enter a valid URL"]')
    button(:close_modal_button, xpath: '//button[@data-ng-click="closeModal()"]')
    button(:cancel_asset_button, xpath: '//button[text()="Cancel"]')

    link(:bookmarklet_link, xpath: '//a[contains(.,"Add assets more easily")]')
    link(:back_to_impact_studio_link, text: 'Back to Impact Studio')
    link(:back_to_library_link, text: 'Back to Asset Library')

    # Returns an array of list view asset IDs extracted from the href attributes of the asset links
    # @return [Array<String>]
    def list_view_asset_ids
      wait_until { list_view_asset_link_elements.any? }
      list_view_asset_link_elements.map do |link|
        query = link.attribute('href').sub("#{SuiteCUtils.suite_c_base_url}/assetlibrary/", '')
        query.include?('?') ? query.split('?').first : query
      end
    end

    # Clicks the 'back to asset library' link and waits for list view to load
    # @param event [Event]
    def go_back_to_asset_library(event = nil)
      sleep 1
      wait_for_update_and_click back_to_library_link_element
      wait_until(Utils.short_wait) { list_view_asset_elements.any? }
      add_event(event, EventType::LIST_ASSETS)
    end

    # Clicks the 'back to impact studio' link and shifts focus to the iframe
    # @param driver [Selenium::WebDriver]
    # @param event [Event]
    def go_back_to_impact_studio(driver, event = nil)
      wait_for_load_and_click back_to_impact_studio_link_element
      wait_until(Utils.medium_wait) { title == LtiTools::IMPACT_STUDIO.name }
      add_event(event, EventType::LAUNCH_IMPACT_STUDIO)
      hide_canvas_footer_and_popup
      switch_to_canvas_iframe driver
    end

    # Waits for asset list view to load when a new asset is created, then gets the asset's ID. Requires that the asset have a unique title.
    # @param asset [Asset]
    def wait_for_asset_and_get_id(asset)
      wait_until(Utils.medium_wait) { list_view_asset_link_elements.any? }
      asset.id = SuiteCUtils.get_asset_id_by_title asset
    end

    # Given an array of assets, returns their IDs in descending order of creation
    # @param assets [Array<Asset>]
    # @return [Array<String>]
    def recent_asset_ids(assets)
      asset_ids = assets.map { |asset| asset.id if asset.visible }
      asset_ids.compact.sort.reverse
    end

    def pinned_asset_ids(pinned_assets)
      pinned_assets.map { |asset| asset.id if asset.visible }
    end

    # Given an array of assets, returns the IDs of the assets with non-zero impact scores in descending order of score
    # @param assets [Array<Asset>]
    # @return [Array<String>]
    def impactful_asset_ids(assets)
      visible_assets = assets.select { |asset| asset.visible }
      assets_with_impact = visible_assets.select { |asset| !asset.impact_score.zero? }
      sorted_assets = (assets_with_impact.sort_by { |asset| [asset.impact_score, asset.id] }).reverse
      sorted_assets.map { |asset| asset.id }
    end

    # FILE UPLOADS

    # Clicks the 'upload file' button
    def click_upload_file_link
      go_back_to_asset_library if back_to_library_link? && back_to_library_link_element.visible?
      wait_for_load_and_click_js upload_link_element
      upload_file_heading_element.when_visible Utils.short_wait
    end

    # Combines methods to upload a new file to the asset library, and sets the asset object's ID
    # @param asset [Asset]
    # @param event [Event]
    def upload_file_to_library(asset, event = nil)
      click_upload_file_link
      enter_and_upload_file asset
      wait_for_asset_and_get_id asset
      add_event(event, EventType::CREATE, asset.id)
      add_event(event, EventType::VIEW)
      add_event(event, EventType::CREATE_FILE_ASSET, asset.id)
      add_event(event, EventType::LIST_ASSETS)
    end

    # Uses JavaScript to make the file upload input visible, then enters the file to be uploaded
    # @param file_name [String]
    def enter_file_path_for_upload(file_name)
      logger.info "Uploading #{file_name}"
      upload_file_path_input_element.when_present Utils.short_wait
      execute_script('arguments[0].style.height="auto"; arguments[0].style.width="auto"; arguments[0].style.visibility="visible";', upload_file_path_input_element)
      sleep 1
      self.upload_file_path_input_element.send_keys SuiteCUtils.test_data_file_path(file_name)
    end

    # Enters asset metadata while uploading a file type asset
    # @param asset [Asset]
    def enter_file_metadata(asset)
      logger.info "Entering title '#{asset.title}', category '#{asset.category}', and description '#{asset.description}'"
      wait_until(Utils.medium_wait) { upload_file_title_input_elements.any? }
      wait_for_element_and_type(upload_file_title_input_elements[0], asset.title)
      wait_for_element_and_select_js(upload_file_category_select_element, asset.category) unless asset.category.nil?
      wait_for_element_and_type(upload_file_description_input_elements[0], asset.description) unless asset.description.nil?
    end

    # Clicks the 'upload file' button to complete a file upload
    def click_add_files_button
      logger.info 'Confirming new file uploads'
      wait_for_update_and_click_js upload_file_button_element
    end

    # Combines methods to upload a new file type asset
    # @param asset [Asset]
    def enter_and_upload_file(asset)
      enter_file_path_for_upload asset.file_name
      enter_file_metadata(asset)
      click_add_files_button
    end

    # ADD SITE

    # Clicks the 'add site' button
    def click_add_site_link
      go_back_to_asset_library if back_to_library_link?
      wait_for_load_and_click_js add_site_link_element
      add_url_heading_element.when_visible Utils.short_wait
    end

    # Combines methods to add a new site to the asset library, and sets the asset object's ID
    # @param asset [Asset]
    # @param event [Event]
    def add_site(asset, event = nil)
      click_add_site_link
      enter_and_submit_url asset
      wait_for_asset_and_get_id asset
      add_event(event, EventType::CREATE, asset.id)
      add_event(event, EventType::VIEW)
      add_event(event, EventType::CREATE_LINK_ASSET, asset.id)
      add_event(event, EventType::LIST_ASSETS)
    end

    # Enters asset metadata while adding a link type asset
    # @param asset [Asset]
    def enter_url_metadata(asset)
      logger.info "Entering URL '#{asset.url}', title '#{asset.title}', category '#{asset.category}', and description '#{asset.description}'"
      wait_for_update_and_click_js url_input_element
      wait_for_element_and_type(url_input_element, asset.url) unless asset.url.nil?
      wait_for_element_and_type(url_title_input_element, asset.title) unless asset.title.nil?
      wait_for_element_and_type(url_description_element, asset.description) unless asset.description.nil?
      wait_for_element_and_select_js(url_category_element, asset.category) unless asset.category.nil?
    end

    # Clicks the 'add URL' button to finish adding a link
    def click_add_url_button
      wait_for_update_and_click add_url_button_element
    end

    # Combines methods to add a new link type asset
    # @param asset [Asset]
    def enter_and_submit_url(asset)
      enter_url_metadata asset
      click_add_url_button
    end

    # Clicks the 'cancel' button for either a file or a link type asset
    def click_cancel_button
      wait_for_update_and_click_js cancel_asset_button_element
    end

    # Closes the modal opened during either a file or a link type asset upload
    def click_close_modal_button
      wait_for_update_and_click_js close_modal_button_element
    end

    # Extracts a whiteboard ID from a link to the whiteboard
    # @param link_element [PageObject::Elements::Link]
    # @return [String]
    def get_whiteboard_id(link_element)
      link_element.when_present Utils.short_wait
      href = link_element.attribute('href')
      partial_url = href.split('?').first
      partial_url.sub("#{SuiteCUtils.suite_c_base_url}/whiteboards/", '')
    end

    # Shifts driver focus to a newly opened whiteboard
    # @param driver [Selenium::WebDriver]
    # @param whiteboard [Whiteboard]
    def shift_to_whiteboard_window(driver, whiteboard)
      wait_until(Utils.short_wait) { driver.window_handles.length > 1 }
      driver.switch_to.window driver.window_handles.last
      wait_until(Utils.medium_wait) { title.include? whiteboard.title }
    end

    # PINS

    # Clicks a given pin element and waits for its text to match a given string
    # @param pin_element [PageObject::Elements::Button]
    # @param state [String]
    def change_asset_pinned_state(pin_element, state)
      wait_for_load_and_click_js pin_element
      wait_until(1) { pin_element.span_element(xpath: "//span[text()='#{state}']") }
      sleep 1
    end

    # SEARCH / FILTER

    text_area(:search_input, id: 'assetlibrary-search')
    button(:search_button, xpath: '//button[@title="Search"]')

    button(:advanced_search_button, class: 'search-advanced')
    text_area(:keyword_search_input, id: 'assetlibrary-search-keywords')
    select_list(:category_select, id: 'assetlibrary-search-category')
    select_list(:uploader_select, id: 'assetlibrary-search-user')
    select_list(:asset_type_select, id: 'assetlibrary-search-type')
    select_list(:sort_by_select, id: 'assetlibrary-sort-by')
    button(:advanced_search_submit, xpath: '//button[text()="Search"]')
    link(:cancel_advanced_search, text: 'Cancel')

    # Performs a simple search of the asset library
    # @param keyword [String]
    # @param event [Event]
    def simple_search(keyword, event = nil)
      logger.info "Performing simple search of asset library by keyword '#{keyword}'"
      wait_for_update_and_click(cancel_advanced_search_element) if cancel_advanced_search?
      search_input_element.when_visible Utils.short_wait
      search_input_element.clear
      search_input_element.send_keys(keyword) unless keyword.nil?
      wait_for_update_and_click search_button_element
      add_event(event, EventType::SEARCH_ASSETS, keyword)
    end

    # Ensures the advanced search form is expanded
    def open_advanced_search
      wait_for_load_and_click_js advanced_search_button_element unless keyword_search_input_element.visible?
    end

    # Performs an advanced search of the asset library
    # @param keyword [String]
    # @param category [String]
    # @param user [User]
    # @param asset_type [String]
    # @param sort_by [String]
    # @param event [Event]
    def advanced_search(keyword, category, user, asset_type, sort_by, event = nil)
      logger.info "Performing advanced search of asset library by keyword '#{keyword}', category '#{category}', user '#{user && user.full_name}', asset type '#{asset_type}', sort by '#{sort_by}'."
      open_advanced_search
      keyword.nil? ?
          wait_for_element_and_type(keyword_search_input_element, '') :
          wait_for_element_and_type(keyword_search_input_element, keyword)
      category.nil? ?
          (wait_for_element_and_select_js(category_select_element, 'Category')) :
          (wait_for_element_and_select_js(category_select_element, category))
      user.nil? ?
          (self.uploader_select = 'User') :
          (self.uploader_select = user.full_name)
      asset_type.nil? ?
          (self.asset_type_select = 'Asset type') :
          (self.asset_type_select = asset_type)
      sort_by.nil? ?
          (self.sort_by_select = 'Most recent') :
          (self.sort_by_select = sort_by)
      wait_for_update_and_click advanced_search_submit_element
      add_event(event, EventType::SEARCH)
      add_event(event, EventType::SEARCH_ASSETS, keyword)
    end

    # EVENT DROPS

    # Determines the count of drops from the activity type label
    # @param labels [Array<String>]
    # @param index [Integer]
    # @return [Integer]
    def activity_type_count(labels, index)
      labels[index] && (((type = labels[index]).include? ' (') ? type.split(' ').last.delete('()').to_i : 0)
    end

    # Mouses over an event drop at a given location
    # @param driver [Selenium::WebDriver]
    # @param line_node [Integer]
    def mouseover_event_drop(driver, line_node)
      mouseover(driver, driver.find_element(xpath: "//*[name()='svg']//*[@class='drop-line'][#{line_node}]/*[name()='circle'][last()]"))
    end

    # LOOKING FOR COLLABORATORS

    text_area(:collaboration_msg_input, xpath: '//textarea[contains(@placeholder, "looking to collaborate on...")]')
    button(:collaboration_msg_cancel, xpath: '//div[@id="collaboration-modal-dialog"]//button[text()="Cancel"]')
    button(:collaboration_msg_send, xpath: '//div[@id="collaboration-modal-dialog"]//button[text()="Send Invite"]')
    div(:collaboration_msg_success, xpath: '//div[contains(.,"Your message was sent to")]')

    # Clicks the Cancel button in the collaboration popup
    def click_cancel_collaborate_msg
      logger.debug 'Clicking cancel'
      wait_for_update_and_click collaboration_msg_cancel_element
      sleep 1
    end

    # Enters and sends a message
    # @param msg_text [String]
    def send_collaborate_msg(msg_text)
      logger.info "Sending message '#{msg_text}'"
      wait_for_element_and_type(collaboration_msg_input_element, msg_text)
      wait_for_update_and_click collaboration_msg_send_element
      collaboration_msg_success_element.when_visible Utils.short_wait
    end

  end
end
