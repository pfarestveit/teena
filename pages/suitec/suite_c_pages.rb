require_relative '../../util/spec_helper'

module Page

  module SuiteCPages

    include PageObject
    include Logging
    include Page

    # Assets UI shared across tools

    elements(:list_view_asset, :list_item, xpath: '//li[@data-ng-repeat="asset in assets | unique:\'id\'"]')
    elements(:list_view_asset_link, :link, xpath: '//li[@data-ng-repeat="asset in assets | unique:\'id\'"]//a')
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
      list_view_asset_link_elements.map { |link| link.attribute('href').sub("#{Utils.suite_c_base_url}/assetlibrary/", '') }
    end

    # Clicks the 'back to asset library' link and waits for list view to load
    def go_back_to_asset_library
      wait_for_update_and_click back_to_library_link_element
      wait_until(Utils.short_wait) { list_view_asset_elements.any? }
    end

    # Clicks the 'back to impact studio' link and shifts focus to the iframe
    # @param driver [Selenium::WebDriver]
    def go_back_to_impact_studio(driver)
      wait_for_load_and_click back_to_impact_studio_link_element
      wait_until(Utils.medium_wait) { title == SuiteCTools::IMPACT_STUDIO.name }
      hide_canvas_footer
      switch_to_canvas_iframe driver
    end

    # Given an array of assets, returns their IDs in descending order of creation
    # @param assets [Array<Asset>]
    # @return [Array<String>]
    def recent_asset_ids(assets)
      asset_ids = assets.map { |asset| asset.id if asset.visible }
      asset_ids.compact.sort.reverse
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
      wait_for_update_and_click url_input_element
      self.url_input = asset.url unless asset.url.nil?
      self.url_title_input = asset.title unless asset.title.nil?
      self.url_description = asset.description unless asset.description.nil?
      self.url_category = asset.category unless asset.category.nil?
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

    # PINS

    # Clicks a given pin element and waits for its text to match a given string
    # @param pin_element [PageObject::Elements::Button]
    # @param state [String]
    def change_asset_pinned_state(pin_element, state)
      wait_for_load_and_click_js pin_element
      wait_until(1) { pin_element.span_element(xpath: "//span[text()='#{state}']") }
      sleep 1
    end

    # EVENT DROPS

    # Determines the count of drops from the activity type label
    # @param labels [Array<String>]
    # @param index [Integer]
    # @return [Integer]
    def activity_type_count(labels, index)
      labels[index] && (((type = labels[index]).include? ' (') ? type.split(' ').last.delete('()').to_i : 0)
    end

    # Returns true if an event drop element is in the viewport and therefore clickable
    # @param drop_element [Selenium::WebDriver::Element]
    # @return [boolean]
    def drop_clickable?(drop_element)
      drop_element.click
      logger.debug 'Drop is clickable'
      true
    rescue
      Selenium::WebDriver::Error::UnknownError
      logger.debug 'Nope, not clickable'
      false
    end

    # Attempts to drag an event drop into view so that it is clickable. In tests, if the drop is not visible then the drop
    # should be to the right, so this drags the drops to the left a configurable number of times.
    # @param driver [Selenium::WebDriver]
    def drag_drop_into_view(driver, line_node, drop_node)
      # Find the drop in the SVG
      logger.info 'Checking an event drop'
      wait_for_update_and_click_js button_element(xpath: '//button[text()="All"]') unless button_element(xpath: '//button[text()="All"]').attribute('disabled')
      wait_until(Utils.short_wait) { driver.find_element(xpath: "//*[name()='svg']//*[@class='drop-line'][#{line_node}]/*[name()='circle'][#{drop_node}]") }
      container = driver.find_element(xpath: '//*[name()="svg"]//*[name()="rect"]')
      drop = driver.find_element(xpath: "//*[name()='svg']//*[@class='drop-line'][#{line_node}]/*[name()='circle'][#{drop_node}]")

      # Zoom in, but a little less if on asset detail since drops are less likely to be tightly clustered
      logger.debug 'Zooming in to distinguish the drop'
      asset_detail = h3_element(xpath: '//h3[contains(.,"Activity Timeline")]').exists?
      zooms = asset_detail ? 6 : 7
      zooms.times do
        js_click button_element(xpath: '//button[contains(text(),"+")]')
        sleep 1
        driver.action.drag_and_drop_by(container, -50, 0).perform
        sleep 1
      end

      # If on the asset detail, hit the comment input in order to bring the event drops into view. Scroll the lines till the drop appears.
      wait_for_element_and_type_js(text_area_element(id: 'assetlibrary-item-newcomment-body'), ' ') if asset_detail
      unless drop_clickable? drop
        logger.debug 'Trying to bring the drop into view'
        begin
          tries ||= Utils.event_drop_drags
          driver.action.drag_and_drop_by(container, -65, 0).perform
          drop.click
          logger.debug "It took #{tries} attempts to drag the drop into view"
        rescue
          (tries -= 1).zero? ? fail : retry
        end
      end

      # Mouse over the drop to reveal the tooltip.
      driver.action.move_to(driver.find_element(xpath: "//*[name()='svg']//*[@class='drop-line'][#{line_node}]/*[name()='circle'][#{drop_node}]")).perform
    end

  end
end
