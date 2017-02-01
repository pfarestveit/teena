require_relative '../../util/spec_helper'

module Page

  module SuiteCPages

    class WhiteboardsPage

      include PageObject
      include Page
      include Logging
      include SuiteCPages

      # Loads Whiteboards tool and switches browser focus to the tool iframe
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      def load_page(driver, url)
        navigate_to url
        wait_until { title == "#{SuiteCTools::WHITEBOARDS.name}" }
        switch_to_canvas_iframe driver
      end

      # CREATE WHITEBOARD

      link(:create_first_whiteboard_link, text: 'Create your first whiteboard')
      link(:add_whiteboard_link, xpath: '//span[text()="Whiteboard"]/..')
      text_area(:new_title_input, id: 'whiteboards-create-title')
      text_area(:new_collaborator_input, xpath: '//label[text()="Collaborators"]/following-sibling::div//input')
      button(:create_whiteboard_button, xpath: '//button[text()="Create whiteboard"]')
      link(:cancel_new_whiteboard_link, text: 'Cancel')

      div(:title_req_msg, xpath: '//div[text()="Please enter a title"]')
      div(:title_max_length_msg, xpath: '//div[text()="A title can only be 255 characters long"]')
      div(:no_collaborators_msg, xpath: '//div[text()="A whiteboard requires at least 1 collaborator"]')

      # Clicks the 'add whiteboard' link
      def click_add_whiteboard
        wait_for_page_load_and_click add_whiteboard_link_element
      end

      # Enters text in the whiteboard title input
      # @param title [String]
      def enter_whiteboard_title(title)
        wait_for_element_and_type(new_title_input_element, title)
      end

      # Returns the element that allows selection of a user as a whiteboard collaborator
      # @param user [User]
      # @return [PageObject::Elements::Element]
      def collaborator_option_link(user)
        button_element(xpath: "//li[contains(@class,'select-dropdown-optgroup-option')][contains(text(),'#{user.full_name}')]")
      end

      # Returns the element indicating that a user is an existing whiteboard collaborator
      # @param user [User]
      # @return [PageObject::Elements::Element]
      def collaborator_name(user)
        list_item_element(xpath: "//li[contains(@class,'select-search-list-item_selection')]/span[contains(text(),'#{user.full_name}')]")
      end

      # Selects a given set of users as whiteboard collaborators
      # @param users [Array<User>]
      def enter_whiteboard_collaborators(users)
        users.each do |user|
          wait_for_element_and_type(new_collaborator_input_element, user.full_name)
          wait_until(timeout=Utils.short_wait) { list_item_element(xpath: "//li[contains(@class,'select-dropdown-optgroup-option')][contains(text(),'#{user.full_name}')]") }
          wait_for_page_update_and_click collaborator_option_link(user)
          wait_until(timeout) { collaborator_name user }
        end
      end

      # Clicks the create button to complete creation of a whiteboard
      def click_create_whiteboard
        wait_for_page_update_and_click create_whiteboard_button_element
      end

      # Combines methods to create a new whiteboard and obtain its ID
      # @param whiteboard [Whiteboard]
      def create_whiteboard(whiteboard)
        logger.info "Creating a new whiteboard named '#{whiteboard.title}'"
        click_add_whiteboard
        enter_whiteboard_title whiteboard.title
        enter_whiteboard_collaborators whiteboard.collaborators
        click_create_whiteboard
        verify_first_whiteboard whiteboard
      end

      # Combines methods to create a new whiteboard and then open it
      # @param driver [Selenium::WebDriver]
      # @param whiteboard [Whiteboard]
      def create_and_open_whiteboard(driver, whiteboard)
        create_whiteboard whiteboard
        open_whiteboard(driver, whiteboard)
      end

      # OPEN / CLOSE EXISTING WHITEBOARD

      # Opens a whiteboard using its ID and shifts browser focus to the new window
      # @param driver [Selenium::WebDriver]
      # @param whiteboard [Whiteboard]
      def open_whiteboard(driver, whiteboard)
        logger.info "Opening whiteboard ID #{whiteboard.id}"
        click_whiteboard_link whiteboard
        driver.switch_to.window driver.window_handles.last
        wait_until { title.include? whiteboard.title }
      end

      # Opens a whiteboard directly via URL
      # @param course [Course]
      # @param whiteboard [Whiteboard]
      def hit_whiteboard_url(course, whiteboards_url, whiteboard)
        url = "#{Utils.suite_c_base_url}/whiteboards/#{whiteboard.id}?api_domain=#{Utils.canvas_base_url[8..-1]}&course_id=#{course.site_id}&tool_url=#{whiteboards_url}"
        logger.debug "Hitting URL '#{url}'"
        navigate_to url
      end

      # Closes a browser window if it contains a whiteboard and if more than one window is open
      # @param driver [Selenium::WebDriver]
      def close_whiteboard(driver)
        sleep 1
        if (driver.window_handles.length > 1) && current_url.include?("#{Utils.suite_c_base_url}/whiteboards")
          logger.debug "The browser window count is #{driver.window_handles.length}, and the current window is a whiteboard. Closing it."
          driver.close
          driver.switch_to.window driver.window_handles.first
          switch_to_canvas_iframe driver
        else
          logger.debug "The browser window count is #{driver.window_handles.length}, and the current window is not a whiteboard. Leaving it open."
        end
      end

      # Verifies that a given set of users matches the list of whiteboard collaborators
      # @param users [Array<User>]
      def verify_collaborators(users)
        click_settings_button
        users.flatten.each do |user|
          wait_until(Utils.short_wait) { collaborator_name user }
        end
      end

      # EDIT WHITEBOARD

      button(:settings_button, xpath: '//button[@title="Settings"]')
      text_area(:edit_title_input, id: 'whiteboards-edit-title')
      elements(:collaborator_name, :span, xpath: '//label[text()="Collaborators"]/following-sibling::div//li/span')
      div(:collaborator_list, class: 'select-search')
      elements(:remove_collaborator_button, :button, xpath: '//label[text()="Collaborators"]/following-sibling::div//li/button')
      button(:cancel_edit, xpath: '//button[text()="Cancel"]')
      button(:save_edit, xpath: '//button[text()="Save settings"]')

      # Clicks the settings button on a whiteboard
      def click_settings_button
        wait_for_page_update_and_click settings_button_element
      end

      # Changes the title of a whiteboard to the whiteboard object's current title
      # @param whiteboard [Whiteboard]
      def edit_whiteboard_title(whiteboard)
        click_settings_button
        wait_for_element_and_type(edit_title_input_element, whiteboard.title)
        wait_for_page_update_and_click save_edit_element
      end

      # Adds a new collaborator to an existing whiteboard
      # @param user [User]
      def add_collaborator(user)
        click_settings_button
        wait_for_page_update_and_click collaborator_list_element
        wait_for_page_update_and_click collaborator_option_link(user)
        wait_until(Utils.short_wait) { collaborator_name user }
        wait_for_page_update_and_click edit_title_input_element
        wait_for_page_update_and_click save_edit_element
        save_edit_element.when_not_present Utils.short_wait
      end

      # Removes a given collaborator from a whiteboard
      # @param user [User]
      def remove_collaborator(user)
        click_settings_button
        logger.debug "Clicking the remove button for #{user.full_name}"
        wait_for_page_update_and_click button_element(xpath: "//span[text()='#{user.full_name}']/following-sibling::button")
        collaborator_name(user).when_not_visible Utils.short_wait
        # An alert can appear, but only if the user removes itself
        confirm(true) { wait_for_page_update_and_click save_edit_element } rescue Selenium::WebDriver::Error::NoAlertPresentError
      end

      # DELETE/RESTORE WHITEBOARD

      button(:delete_button, xpath: '//button[text()="Delete whiteboard"]')
      button(:restore_button, xpath: '//button[@title="Restore"]')
      span(:restored_msg, xpath: '//span[contains(.,"The whiteboard has been restored")]')

      def delete_whiteboard(driver)
        logger.info 'Deleting whiteboard'
        click_settings_button
        wait_for_page_update_and_click delete_button_element
        driver.switch_to.alert.accept
        # Two alerts will appear if the user is an admin
        driver.switch_to.alert.accept rescue Selenium::WebDriver::Error::StaleElementReferenceError
        driver.switch_to.window driver.window_handles.first
        switch_to_canvas_iframe driver
      end

      def restore_whiteboard
        logger.info 'Restoring whiteboard'
        wait_for_page_update_and_click restore_button_element
        restored_msg_element.when_present Utils.short_wait
      end

      # WHITEBOARDS LIST VIEW

      elements(:list_view_whiteboard, :list_item, xpath: '//li[@data-ng-repeat="whiteboard in whiteboards"]')
      elements(:list_view_whiteboard_title, :div, xpath: '//li[@data-ng-repeat="whiteboard in whiteboards"]//div[@class="col-list-item-metadata"]/span')
      elements(:list_view_whiteboard_link, :link, xpath: '//li[@data-ng-repeat="whiteboard in whiteboards"]//a')

      # Returns an array of all whiteboard titles in list view
      # @return [Array<String>]
      def visible_whiteboard_titles
        list_view_whiteboard_title_elements.map &:text
      end

      # Returns the ID of the first whiteboard in list view by extracting the ID from the whiteboard link href
      # @return [String]
      def get_first_whiteboard_id
        wait_until { list_view_whiteboard_link_elements.any? }
        href = list_view_whiteboard_link_elements.first.attribute('href')
        whiteboard_url = href.split('?').first
        whiteboard_url.sub("#{Utils.suite_c_base_url}/whiteboards/", '')
      end

      # Verifies that the title of the first whiteboard in list view matches that of a given whiteboard object
      # @param whiteboard [Whiteboard]
      def verify_first_whiteboard(whiteboard)
        # Pause to allow DOM update to complete
        sleep 1
        logger.debug "Verifying list view whiteboard title includes '#{whiteboard.title}'"
        wait_until(Utils.short_wait) { list_view_whiteboard_title_elements[0].text.include? whiteboard.title }
        whiteboard.id = get_first_whiteboard_id
      end

      # Finds a whiteboard link by its ID and then clicks to open it
      # @param whiteboard [Whiteboard]
      def click_whiteboard_link(whiteboard)
        wait_until { list_view_whiteboard_link_elements.any? }
        whiteboard_link = list_view_whiteboard_link_elements.find { |link| link.attribute('href').include?("/whiteboards/#{whiteboard.id}?") }
        whiteboard_link.click
      end

      # SEARCH

      text_area(:simple_search_input, id: 'whiteboards-search')
      button(:simple_search_button, xpath: '//button[@title="Search"]')
      button(:open_advanced_search_button, xpath: '//button[@title="Advanced search"]')
      text_area(:advanced_search_keyword_input, id: 'whiteboards-search-keywords')
      select_list(:advanced_search_user_select, id: 'whiteboards-search-user')
      checkbox(:include_deleted_cbx, id: 'whiteboards-search-include-deleted')
      link(:cancel_search_link, text: 'Cancel')
      button(:advanced_search_button, xpath: '//button[text()="Search"]')
      span(:no_results_msg, xpath: '//span[contains(text(),"No matching whiteboards were found.")]')

      # Performs a simple whiteboard search
      # @param string [String]
      def simple_search(string)
        logger.info "Performing simple search for '#{string}'"
        cancel_search_link if cancel_search_link_element.visible?
        wait_for_element_and_type(simple_search_input_element, string)
        sleep 1
        click_element_js simple_search_button_element
      end

      # Performs an advanced whiteboard search
      # @param string [String]
      # @param user [User]
      # @param inc_deleted [boolean] defaults to nil
      def advanced_search(string, user, inc_deleted = nil)
        logger.info 'Performing advanced search'
        open_advanced_search_button unless advanced_search_keyword_input_element.visible?
        logger.debug "Search keyword is '#{string}'"
        string.nil? ?
            wait_for_element_and_type(advanced_search_keyword_input_element, '') :
            wait_for_element_and_type(advanced_search_keyword_input_element, string)
        sleep 1
        if user.nil?
          self.advanced_search_user_select = 'Collaborator'
        else
          logger.debug "User is '#{user.full_name}'"
          self.advanced_search_user_select = user.full_name
          sleep 1
        end
        inc_deleted ? check_include_deleted_cbx : uncheck_include_deleted_cbx
        click_element_js advanced_search_button_element
      end

      # WHITEBOARD EXPORT

      button(:export_button, xpath: '//button[@title="Export"]')
      button(:export_to_library_button, xpath: '//button[contains(.,"Export to Asset Library")]')
      text_area(:export_title_input, id: 'whiteboards-exportasasset-title')
      button(:export_confirm_button, xpath: '//span[text()="Export to Asset Library"]/..')
      span(:export_confirm_msg, xpath: '//span[contains(.,"This board has been successfully added")]')
      button(:download_as_image_button, xpath: '//a[contains(.,"Download as image")]')

      # Clicks the 'export' button on an open whiteboard
      def click_export_button
        logger.debug 'Clicking whiteboard export button'
        wait_for_page_update_and_click export_button_element
      end

      # Exports a whiteboard as a new asset library asset
      # @param whiteboard [Whiteboard]
      # @return [Asset]
      def export_to_asset_library(whiteboard)
        click_export_button
        logger.debug 'Exporting whiteboard to asset library'
        wait_for_page_update_and_click export_to_library_button_element
        wait_until(Utils.short_wait) { export_title_input == whiteboard.title }
        wait_for_page_update_and_click export_confirm_button_element
        Asset.new({ type: 'Whiteboard', title: whiteboard.title, preview: 'image' })
      end

      # Cleans the configured download directory and clicks the 'download as image' button on an open whiteboard
      def download_as_image
        Utils.prepare_download_dir
        click_export_button
        logger.debug 'Downloading whiteboard as an image'
        wait_for_page_update_and_click download_as_image_button_element
      end

      # Waits for a downloaded whiteboard PNG file to appear in the configured download directory
      # @param whiteboard [Whiteboard]
      def verify_image_download(whiteboard)
        logger.info 'Waiting for PNG file to be downloaded from whiteboard'
        expected_file_path = "#{Utils.download_dir}/#{whiteboard.title.gsub(' ', '-')}-#{Time.now.strftime('%Y-%m-%d')}-*.png"
        wait_until { Dir[expected_file_path].any? }
        logger.debug 'Whiteboard converted to PNG successfully'
        true
      rescue
        logger.debug 'Whiteboard not converted to PNG successfully'
        false
      end

      # ASSETS ON WHITEBOARD

      button(:add_asset_button, xpath: '//button[@title="Add asset"]')
      button(:use_existing_button, xpath: '//button[@data-ng-click="reuseAsset()"]')
      button(:upload_new_button, xpath: '//button[@data-ng-click="uploadFiles()"]')
      button(:add_link_button, xpath: '//button[@data-ng-click="addLink()"]')
      button(:add_selected_button, xpath: '//button[text()="Add selected"]')
      checkbox(:add_file_to_library_cbx, xpath: '//label[contains(.,"Also add this file to Asset Library")]/input')
      checkbox(:add_link_to_library_cbx, xpath: '//label[contains(.,"Also add this link to Asset Library")]')

      link(:open_original_asset_link, xpath: '//a[@title="Open original asset"]')
      button(:close_original_asset_button, xpath: '//button[contains(.,"Back to whiteboard")]')
      button(:delete_asset_button, xpath: '//button[@title="Delete"]')

      # Clicks the button to add an existing asset to an open whiteboard
      def click_add_existing_asset
        wait_for_page_update_and_click add_asset_button_element unless use_existing_button?
        wait_for_page_update_and_click use_existing_button_element
      end

      # Adds a given set of existing assets to an open whiteboard
      # @param assets [Array<Asset>]
      def add_existing_assets(assets)
        click_add_existing_asset
        assets.each { |asset| wait_for_page_update_and_click text_area_element(xpath: "//input[@value = '#{asset.id}']") }
        wait_for_page_update_and_click add_selected_button_element
        add_selected_button_element.when_not_visible Utils.short_wait
      end

      # Clicks the 'upload new' or 'add link' button to add a new asset to an open whiteboard, depending on asset type
      # @param asset [Asset]
      def click_add_new_asset(asset)
        click_close_modal_button if close_modal_button?
        click_cancel_button if cancel_asset_button?
        if asset.type == 'File'
          wait_for_page_update_and_click add_asset_button_element unless upload_new_button?
          wait_for_page_update_and_click upload_new_button_element
        else
          wait_for_page_update_and_click add_asset_button_element unless add_link_button?
          wait_for_page_update_and_click add_link_button_element
        end
      end

      # Uploads a new file or adds a new link to an open whiteboard but does not make the asset available in the asset library
      # @param asset [Asset]
      def add_asset_exclude_from_library(asset)
        click_add_new_asset asset
        (asset.type == 'File') ? enter_and_upload_file(asset) : enter_and_submit_url(asset)
      end

      # Uploads a new file or adds a new link to an open whiteboard and also makes the asset available in the asset library
      # @param asset [Asset]
      def add_asset_include_in_library(asset)
        click_add_new_asset asset
        if asset.type == 'File'
          enter_file_path_for_upload asset.file_name
          enter_file_metadata(asset)
          check_add_file_to_library_cbx
          click_add_files_button
        else
          enter_url_metadata asset
          check_add_link_to_library_cbx
          click_add_url_button
        end
      end

      # Clicks the link to open a whiteboard asset in the asset library
      # @param driver [Selenium::WebDriver]
      # @param asset_library [Page::SuiteCPages::AssetLibraryPage]
      # @param asset [Asset]
      def open_original_asset(driver, asset_library, asset)
        wait_for_page_update_and_click open_original_asset_link_element
        driver.switch_to.window driver.window_handles.last
        wait_until { asset_library.detail_view_asset_title == asset.title }
      end

      # Closes the browser window containing an asset opened from a whiteboard window using open_original_asset
      # @param driver [Selenium::WebDriver]
      def close_original_asset(driver)
        wait_for_page_update_and_click close_original_asset_button_element
        # Three windows should be open, but check how many just in case
        driver.window_handles.length == 2 ? driver.switch_to.window(driver.window_handles[1]) : driver.switch_to.window(driver.window_handles.first)
      end

      # COLLABORATORS AND CHAT PANES

      button(:collaborators_button, class: 'whiteboards-board-toolbar-collaborators')
      div(:collaborators_pane, id: 'collaborator_list')
      elements(:collaborator, :div, xpath: '//div[contains(@data-ng-repeat,"member in whiteboard.members")]')

      button(:chat_button, class: 'whiteboards-board-toolbar-chat')
      div(:chat_pane, id: 'whiteboards-board-chat-messages-container')
      text_area(:chat_msg_input, xpath: '//textarea[@placeholder="Hit Return to send a message"]')
      elements(:chat_msg, :div, xpath: '//div[@data-ng-repeat="chatMessage in chatMessages"]')
      elements(:chat_msg_body, :paragraph, xpath: '//div[@data-ng-repeat="chatMessage in chatMessages"]//p')
      elements(:chat_msg_sender, :div, xpath: '//div[@data-ng-repeat="chatMessage in chatMessages"]//div[@class="whiteboards-board-chat-actor ng-binding"]')

      # Opens the collaborators pane unless it is already open
      def show_collaborators_pane
        wait_for_page_update_and_click collaborators_button_element unless collaborators_button_element.attribute('class').include?('active')
      end

      # Hides the collaborators pane
      def hide_collaborators_pane
        wait_for_page_update_and_click collaborators_button_element
        collaborators_button if collaborators_pane_element.visible?
      end

      # Returns the collaborators pane element containing a given user
      # @param user [User]
      # @return [PageObject::Elements::Element]
      def collaborator(user)
        div_element(xpath: "//div[contains(@data-ng-repeat,'member in whiteboard.members')][contains(.,'#{user.full_name}')]")
      end

      # Checks whether the collaborators pane indicates that a given user is currently online
      # @param user [User]
      # @return [boolean]
      def collaborator_online?(user)
        image_element(xpath: "//div[contains(@data-ng-repeat,'member in whiteboard.members')][contains(.,'#{user.full_name}')]//i[@data-ng-if='member.online']").exists?
      end

      # Opens the chat pane unless it is already open
      def show_chat_pane
        wait_for_page_update_and_click chat_button_element unless chat_button_element.attribute('class').include?('active')
      end

      # Hides the chat pane
      def hide_chat_pane
        wait_for_page_update_and_click chat_button_element
        chat_button if chat_pane_element.visible?
      end

      # Sends a given message in the chat pane
      # @param body [String]
      def send_chat_msg(body)
        logger.debug "Sending chat message with body '#{body}'"
        wait_for_element_and_type(chat_msg_input_element, body)
        chat_msg_input_element.send_keys :enter
      end

      # Returns the link element within a chat message at a given index that contains the given link text
      # @param index [Integer]
      # @param link_text [String]
      # @return [PageObject::Elements::Element]
      def chat_msg_link(index, link_text)
        link_element(xpath: "//div[@data-ng-repeat='chatMessage in chatMessages'][#{index}]//p/a[contains(.,'#{link_text}')]")
      end

      # Verifies that a chat message from a given user and with a given body appears in the chat pane
      # @param sender [User]
      # @param body [String]
      def verify_chat_msg(sender, body)
        logger.debug "Waiting for chat message from #{sender.full_name} with body '#{body}'"
        wait_until(timeout=Utils.short_wait) { chat_msg_body_elements.any? }
        sleep 1
        wait_until(timeout) { chat_msg_body_elements.last.text == body }
        wait_until(timeout) { chat_msg_sender_elements.last.text.include? sender.full_name }
      end

    end
  end
end
