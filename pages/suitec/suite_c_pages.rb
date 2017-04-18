require_relative '../../util/spec_helper'

module Page

  module SuiteCPages
  
    include PageObject
    include Logging
    include Page

    # Assets UI shared across tools

    elements(:list_view_asset, :list_item, xpath: '//li[@data-ng-repeat="asset in assets | unique:\'id\'"]')
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

    # FILE UPLOADS

    # Clicks the 'upload file' button
    def click_upload_file_link
      go_back_to_asset_library if back_to_library_link?
      wait_for_load_and_click upload_link_element
      upload_file_heading_element.when_visible Utils.short_wait
    end

    # Combines methods to upload a new file to the asset library, and sets the asset object's ID
    # @param asset [Asset]
    # @return [String]
    def upload_file_to_library(asset)
      click_upload_file_link
      enter_and_upload_file asset
      asset.id = list_view_asset_ids.first
    end

    # Uses JavaScript to make the file upload input visible, then enters the file to be uploaded
    # @param file_name [String]
    def enter_file_path_for_upload(file_name)
      logger.info "Uploading #{file_name}"
      upload_file_path_input_element.when_present Utils.short_wait
      execute_script('arguments[0].style.height="auto"; arguments[0].style.width="auto"; arguments[0].style.visibility="visible";', upload_file_path_input_element)
      sleep 1
      self.upload_file_path_input_element.send_keys Utils.test_data_file_path(file_name)
    end

    # Enters asset metadata while uploading a file type asset
    # @param asset [Asset]
    def enter_file_metadata(asset)
      logger.info "Entering title '#{asset.title}', category '#{asset.category}', and description '#{asset.description}'"
      wait_until(Utils.short_wait) { upload_file_title_input_elements.any? }
      wait_for_element_and_type_js(upload_file_title_input_elements[0], asset.title)
      wait_for_element_and_select_js(upload_file_category_select_element, asset.category) unless asset.category.nil?
      wait_for_element_and_type_js(upload_file_description_input_elements[0], asset.description) unless asset.description.nil?
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
      wait_for_load_and_click add_site_link_element
      add_url_heading_element.when_visible Utils.short_wait
    end

    # Combines methods to add a new site to the asset library, and sets the asset object's ID
    # @param asset [Asset]
    # @return [String]
    def add_site(asset)
      click_add_site_link
      enter_and_submit_url asset
      asset.id = list_view_asset_ids.first
    end

    # Enters asset metadata while adding a link type asset
    # @param asset [Asset]
    def enter_url_metadata(asset)
      wait_for_update_and_click_js url_input_element
      self.url_input = asset.url unless asset.url.nil?
      self.url_title_input = asset.title unless asset.title.nil?
      self.url_description = asset.description unless asset.description.nil?
      self.url_category = asset.category unless asset.category.nil?
    end

    # Clicks the 'add URL' button to finish adding a link
    def click_add_url_button
      wait_for_update_and_click_js add_url_button_element
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

    # Pauses to allow the Canvas poller to complete any active cycle
    def pause_for_poller
      logger.info 'Waiting for the Canvas poller'
      sleep 120
    end

    # Extracts a whiteboard ID from a link to the whiteboard
    # @param link_element [PageObject::Elements::Link]
    # @return [String]
    def get_whiteboard_id(link_element)
      link_element.when_present Utils.short_wait
      href = link_element.attribute('href')
      partial_url = href.split('?').first
      partial_url.sub("#{Utils.suite_c_base_url}/whiteboards/", '')
    end

    # Shifts driver focus to a newly opened whiteboard
    # @param driver [Selenium::WebDriver]
    # @param whiteboard [Whiteboard]
    def shift_to_whiteboard_window(driver, whiteboard)
      wait_until(Utils.short_wait) { driver.window_handles.length > 1 }
      driver.switch_to.window driver.window_handles.last
      wait_until(Utils.medium_wait) { title.include? whiteboard.title }
    end

  end
end
