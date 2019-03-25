require_relative '../../util/spec_helper'

module Page

  module SuiteCPages

    class WhiteboardPage < WhiteboardListViewPage

      include PageObject
      include Logging
      include Page
      include SuiteCPages

      # Opens a whiteboard directly via URL
      # @param course [Course]
      # @param whiteboard [Whiteboard]
      # @param event [Event]
      def hit_whiteboard_url(course, whiteboards_url, whiteboard, event = nil)
        url = "#{SuiteCUtils.suite_c_base_url}/whiteboards/#{whiteboard.id}?api_domain=#{Utils.canvas_base_url[8..-1]}&course_id=#{course.site_id}&tool_url=#{whiteboards_url}"
        logger.debug "Hitting URL '#{url}'"
        navigate_to url
        if title.include? whiteboard.title
          add_event(event, EventType::VIEW, whiteboard.id)
          add_event(event, EventType::VIEW, object: 'Chat')
          add_event(event, EventType::GET_CHAT_MSG, whiteboard.id)
        end
      end

      # Closes a browser window if it contains a whiteboard and if more than one window is open
      # @param driver [Selenium::WebDriver]
      def close_whiteboard(driver)
        sleep 1
        if (driver.window_handles.length > 1) && current_url.include?("#{SuiteCUtils.suite_c_base_url}/whiteboards")
          logger.debug "The browser window count is #{driver.window_handles.length}, and the current window is a whiteboard. Closing it."
          driver.close
          driver.switch_to.window driver.window_handles.first
          switch_to_canvas_iframe driver if driver.browser == 'chrome'
        else
          logger.debug "The browser window count is #{driver.window_handles.length}, and the current window is not a whiteboard. Leaving it open."
        end
      end

      # EDIT WHITEBOARD

      button(:settings_button, xpath: '//button[@title="Settings"]')
      text_area(:edit_title_input, id: 'whiteboards-edit-title')
      elements(:collaborator_name, :span, xpath: '//label[text()="Collaborators"]/following-sibling::div//li/span')
      div(:collaborator_list, xpath: '//li[contains(@class,"select-search-list-item_input")]')
      elements(:remove_collaborator_button, :button, xpath: '//label[text()="Collaborators"]/following-sibling::div//li/button')
      button(:cancel_edit, xpath: '//button[text()="Cancel"]')
      button(:save_edit, xpath: '//button[text()="Save settings"]')

      # Clicks the settings button on a whiteboard
      def click_settings_button
        wait_for_update_and_click_js settings_button_element
      end

      # Changes the title of a whiteboard to the whiteboard object's current title
      # @param whiteboard [Whiteboard]
      # @param event [Event]
      def edit_whiteboard_title(whiteboard, event = nil)
        click_settings_button
        wait_for_element_and_type_js(edit_title_input_element, whiteboard.title)
        wait_for_update_and_click_js save_edit_element
        add_event(event, EventType::MODIFY, whiteboard.id)
        add_event(event, EventType::WHITEBOARD_SETTINGS, whiteboard.id)
      end

      # Adds a new collaborator to an existing whiteboard
      # @param whiteboard [Whiteboard]
      # @param user [User]
      # @param event [Event]
      def add_collaborator(whiteboard, user, event = nil)
        click_settings_button
        # Try a couple times since the click() doesn't always trigger the options
        tries = 2
        begin
          # Click the title first to ensure the subsequent collaborator click always fires
          wait_for_update_and_click edit_title_input_element
          wait_for_update_and_click_js collaborator_list_element
          sleep 1
          wait_for_update_and_click collaborator_option_link(user)
        rescue
          (tries -= 1).zero? ? fail : retry
        end
        wait_until(Utils.short_wait) { collaborator_name user }
        wait_for_update_and_click edit_title_input_element
        wait_for_update_and_click save_edit_element
        save_edit_element.when_not_visible Utils.short_wait rescue Selenium::WebDriver::Error::NoAlertPresentError
        add_event(event, EventType::MODIFY, whiteboard.id)
        add_event(event, EventType::WHITEBOARD_SETTINGS, user.uid)
      end

      # Removes a given collaborator from a whiteboard
      # @param user [User]
      # @param event [Event]
      def remove_collaborator(user, event = nil)
        click_settings_button
        logger.debug "Clicking the remove button for #{user.full_name}"
        wait_for_update_and_click button_element(xpath: "//span[text()='#{user.full_name}']/following-sibling::button")
        collaborator_name(user).when_not_visible Utils.short_wait
        # An alert can appear, but only if the user removes itself
        alert { wait_for_update_and_click save_edit_element } rescue Selenium::WebDriver::Error::NoAlertPresentError
        add_event(event, EventType::MODIFY)
        add_event(event, EventType::WHITEBOARD_SETTINGS, user.uid)
      end

      # Verifies that a given set of users matches the list of whiteboard collaborators
      # @param users [Array<User>]
      def verify_collaborators(users)
        click_settings_button
        users.flatten.each do |user|
          wait_until(Utils.short_wait) { collaborator_name user }
        end
      end

      # DELETE/RESTORE WHITEBOARD

      button(:delete_button, xpath: '//button[text()="Delete whiteboard"]')
      button(:restore_button, xpath: '//button[@title="Restore"]')
      span(:restored_msg, xpath: '//span[contains(.,"The whiteboard has been restored")]')

      # Deletes an open whiteboard
      # @param driver [Selenium::WebDriver]
      # @param event [Event]
      def delete_whiteboard(driver, event = nil)
        logger.info "Deleting whiteboard #{board = title}"
        click_settings_button
        wait_for_update_and_click_js delete_button_element
        driver.switch_to.alert.accept
        # Two alerts will appear if the user is an admin
        driver.switch_to.alert.accept rescue Selenium::WebDriver::Error::StaleElementReferenceError
        add_event(event, EventType::MODIFY, board)
        add_event(event, EventType::WHITEBOARD_SETTINGS, board)
        add_event(event, EventType::LIST_WHITEBOARDS)
        driver.switch_to.window driver.window_handles.first
        switch_to_canvas_iframe driver if driver.browser == 'chrome'
        add_event(event, EventType::VIEW)
      end

      # Clicks the 'restore' button and waits for the success message
      def restore_whiteboard
        logger.info 'Restoring whiteboard'
        wait_for_update_and_click_js restore_button_element
        restored_msg_element.when_present Utils.short_wait
      end

      # WHITEBOARD EXPORT

      button(:export_button, xpath: '//button[@title="Export"]')
      button(:export_to_library_button, xpath: '//button[contains(.,"Export to Asset Library")]')
      h2(:export_heading, xpath: '//h2[contains(.,"Export Whiteboard to Asset Library")]')
      div(:export_not_ready_msg, xpath: '//div[contains(.,"The whiteboard could not be exported because one or more assets are still processing. Try again once processing is complete.")]')
      div(:export_not_possible_msg, xpath: '//div[contains(.,"The whiteboard could not be exported because one or more assets had a processing error. Remove blank assets to try again.")]')
      text_area(:export_title_input, id: 'whiteboards-exportasasset-title')
      button(:export_confirm_button, xpath: '//span[text()="Export to Asset Library"]/..')
      button(:export_cancel_button, xpath: '//button[contains(.,"Cancel")]')
      span(:export_success_msg, xpath: '//span[contains(.,"This board has been successfully added")]')
      button(:download_as_image_button, xpath: '//a[contains(.,"Download as image")]')

      # Clicks the 'export' button on an open whiteboard
      def click_export_button
        logger.debug 'Clicking whiteboard export button'
        wait_for_load_and_click export_button_element
      end

      # Exports a whiteboard as a new asset library asset
      # @param whiteboard [Whiteboard]
      # @param event [Event]
      # @return [Asset]
      def export_to_asset_library(whiteboard, event = nil)
        click_export_button
        logger.debug 'Exporting whiteboard to asset library'
        wait_for_update_and_click export_to_library_button_element
        wait_until(Utils.short_wait) { export_title_input == whiteboard.title }
        wait_for_update_and_click_js export_confirm_button_element
        export_title_input_element.when_not_visible Utils.medium_wait rescue Selenium::WebDriver::Error::StaleElementReferenceError
        export_success_msg_element.when_visible Utils.short_wait
        add_event(event, EventType::SHARE, whiteboard.title)
        add_event(event, EventType::EXPORT_WHITEBOARD_ASSET, whiteboard.id)
        asset = Asset.new({type: 'Whiteboard', title: whiteboard.title, preview: 'image'})
        asset.id = SuiteCUtils.get_asset_id_by_title asset
        asset
      end

      # Cleans the configured download directory and clicks the 'download as image' button on an open whiteboard
      def download_as_image
        Utils.prepare_download_dir
        click_export_button
        logger.debug 'Downloading whiteboard as an image'
        wait_for_update_and_click_js download_as_image_button_element
      end

      # Waits for a downloaded whiteboard PNG file to appear in the configured download directory
      # @param whiteboard [Whiteboard]
      # @param event [Event]
      def verify_image_download(whiteboard, event = nil)
        logger.info 'Waiting for PNG file to be downloaded from whiteboard'
        expected_file_path = "#{Utils.download_dir}/#{whiteboard.title.gsub(' ', '-')}-#{Time.now.strftime('%Y-%m-%d')}-*.png"
        wait_until { Dir[expected_file_path].any? }
        logger.debug 'Whiteboard converted to PNG successfully'
        add_event(event, EventType::RETRIEVE, whiteboard.title)
        add_event(event, EventType::EXPORT_WHITEBOARD_IMAGE, whiteboard.id)
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
      # @param event [Event]
      def click_add_existing_asset(event = nil)
        wait_for_update_and_click add_asset_button_element unless use_existing_button_element.visible?
        wait_for_update_and_click use_existing_button_element
        2.times do
          add_event(event, EventType::VIEW, 'Assets')
          add_event(event, EventType::LIST_ASSETS)
        end
      end

      # Adds a given set of existing assets to an open whiteboard
      # @param assets [Array<Asset>]
      # @param event [Event]
      def add_existing_assets(assets, event = nil)
        click_add_existing_asset event
        assets.each { |asset| wait_for_update_and_click text_area_element(xpath: "//input[@value = '#{asset.id}']") }
        wait_for_update_and_click_js add_selected_button_element
        add_selected_button_element.when_not_visible Utils.short_wait
        assets.each do |asset|
          add_event(event, EventType::ADD, asset.id)
          add_event(event, EventType::ADD_WHITEBOARD_ELEMENT, asset.id)
          add_event(event, EventType::SELECT_WHITEBOARD_ELEMENT, asset.id)
        end
      end

      # Clicks the 'upload new' or 'add link' button to add a new asset to an open whiteboard, depending on asset type
      # @param asset [Asset]
      def click_add_new_asset(asset)
        click_close_modal_button if close_modal_button?
        click_cancel_button if cancel_asset_button?
        if asset.type == 'File'
          wait_for_update_and_click_js add_asset_button_element unless upload_new_button?
          wait_for_update_and_click_js upload_new_button_element
        else
          wait_for_update_and_click_js add_asset_button_element unless add_link_button?
          wait_for_update_and_click_js add_link_button_element
        end
      end

      # Uploads a new file or adds a new link to an open whiteboard but does not make the asset available in the asset library
      # @param asset [Asset]
      # @param event [Event]
      def add_asset_exclude_from_library(asset, event = nil)
        click_add_new_asset asset
        (asset.type == 'File') ? enter_and_upload_file(asset) : enter_and_submit_url(asset)
        asset.visible = false
        open_original_asset_link_element.when_visible Utils.medium_wait
        asset.id = SuiteCUtils.get_asset_id_by_title asset
        add_event(event, EventType::CREATE, asset.id)
        add_event(event, EventType::ADD, asset.id)
        (asset.type == 'File') ? add_event(event, EventType::CREATE_FILE_ASSET, asset.id) : add_event(event, EventType::CREATE_LINK_ASSET, asset.id)
        add_event(event, EventType::ADD_WHITEBOARD_ELEMENT, asset.id)
        add_event(event, EventType::SELECT_WHITEBOARD_ELEMENT, asset.id)
      end

      # Uploads a new file or adds a new link to an open whiteboard and also makes the asset available in the asset library
      # @param asset [Asset]
      # @param event [Event]
      def add_asset_include_in_library(asset, event = nil)
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
        open_original_asset_link_element.when_visible Utils.medium_wait
        asset.id = SuiteCUtils.get_asset_id_by_title asset
        add_event(event, EventType::CREATE, asset.id)
        add_event(event, EventType::ADD, asset.id)
        (asset.type == 'File') ? add_event(event, EventType::CREATE_FILE_ASSET, asset.id) : add_event(event, EventType::CREATE_LINK_ASSET, asset.id)
        add_event(event, EventType::ADD_WHITEBOARD_ELEMENT, asset.id)
        add_event(event, EventType::SELECT_WHITEBOARD_ELEMENT, asset.id)
      end

      # Returns the ID of the currently highlighted asset on a whiteboard
      # @return [String]
      def added_asset_id
        open_original_asset_link_element.attribute('href').split('?').first.split('/').last
      end

      # Clicks the link to open a whiteboard asset in the asset library
      # @param driver [Selenium::WebDriver]
      # @param asset_library [Page::SuiteCPages::AssetLibraryDetailPage]
      # @param asset [Asset]
      # @param event [Event]
      def open_original_asset(driver, asset_library, asset, event = nil)
        wait_for_update_and_click open_original_asset_link_element
        driver.switch_to.window driver.window_handles.last
        wait_until { asset_library.detail_view_asset_title == asset.title }
        add_event(event, EventType::VIEW, asset.id)
        add_event(event, EventType::VIEW)
        add_event(event, EventType::OPEN_ASSET_FROM_WHITEBOARD, asset.id)
        add_event(event, EventType::VIEW_ASSET, asset.id)
        add_event(event, EventType::LIST_ASSETS)
      end

      # Closes the browser window containing an asset opened from a whiteboard window using open_original_asset
      # @param driver [Selenium::WebDriver]
      def close_original_asset(driver)
        wait_for_update_and_click_js close_original_asset_button_element
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
        wait_for_update_and_click_js collaborators_button_element unless collaborators_button_element.attribute('class').include?('active')
      end

      # Hides the collaborators pane
      def hide_collaborators_pane
        wait_for_update_and_click_js collaborators_button_element
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
        wait_for_update_and_click_js chat_button_element unless chat_button_element.attribute('class').include?('active')
      end

      # Hides the chat pane
      def hide_chat_pane
        wait_for_update_and_click_js chat_button_element
        chat_button if chat_pane_element.visible?
      end

      # Sends a given message in the chat pane
      # @param body [String]
      # @param event [Event]
      def send_chat_msg(body, event = nil)
        logger.debug "Sending chat message with body '#{body}'"
        wait_for_element_and_type_js(chat_msg_input_element, body)
        chat_msg_input_element.send_keys :enter
        add_event(event, EventType::CREATE_CHAT_MSG)
        add_event(event, EventType::GET_CHAT_MSG)
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
      # @param event [Event]
      def verify_chat_msg(sender, body, event = nil)
        logger.debug "Waiting for chat message from #{sender.full_name} with body '#{body}'"
        wait_until(timeout=Utils.short_wait) { chat_msg_body_elements.any? }
        sleep 1
        wait_until(timeout) { chat_msg_body_elements.last.text == body }
        wait_until(timeout) { chat_msg_sender_elements.last.text.include? sender.full_name }
        add_event(event, EventType::GET_CHAT_MSG)
      end

    end
  end
end
