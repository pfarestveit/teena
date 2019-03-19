require_relative '../../util/spec_helper'

module Page

  module SuiteCPages

    class AssetLibraryDetailPage < AssetLibraryListViewPage

      include PageObject
      include Logging
      include Page
      include SuiteCPages

      h2(:detail_view_asset_title, xpath: '//h2')
      elements(:detail_view_asset_owner_link, :link, xpath: '//li[contains(@data-ng-repeat,"user in asset.users")]//a[contains(@href,"/assetlibrary?user=")]')
      button(:detail_view_asset_like_button, xpath: '//div[@class="assetlibrary-item-metadata"]//button[@data-ng-click="like(asset)"]')
      span(:detail_view_asset_likes_count, xpath: '//div[@class="assetlibrary-item-metadata"]//span[@data-ng-bind="asset.likes | number"]')
      div(:detail_view_asset_desc, xpath: '//div[text()="Description"]/following-sibling::div/div')
      elements(:detail_view_asset_category, :link, xpath: '//div[@data-ng-repeat="category in asset.categories"]/a')
      div(:detail_view_asset_no_category, xpath: '//div[text()="No category"]')
      link(:detail_view_asset_url_source, xpath: '//div[text()="Source"]/following-sibling::div//a')
      div(:detail_view_asset_no_source, xpath: '//div[text()="No source"]')
      elements(:detail_view_used_in, :link, xpath: '//div[text()="Used in"]/following-sibling::div//a')

      # Waits for an asset's detail view to load
      # @param asset [Asset]
      # @param event [Event]
      def wait_for_asset_detail(asset, event = nil)
        wait_until(Utils.short_wait) { detail_view_asset_title.include? "#{asset.title}" }
        add_event(event, EventType::VIEW, asset.id)
        add_event(event, EventType::VIEW_ASSET, asset.id)
      end

      # Combines methods to load the asset library, find a given asset, and load its detail view
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      # @param asset [Asset]
      # @param event [Event]
      def load_asset_detail(driver, url, asset, event = nil)
        # TODO - remove the following line when asset deep links work from the Asset Library
        navigate_to 'https://en.wikipedia.org/wiki/Main_Page'
        navigate_to "#{url}#col_asset=#{asset.id}"
        switch_to_canvas_iframe driver
        add_event(event, EventType::NAVIGATE)
        add_event(event, EventType::VIEW)
        add_event(event, EventType::LAUNCH_ASSET_LIBRARY)
        add_event(event, EventType::DEEP_LINK_ASSET, asset.id)
        add_event(event, EventType::LIST_ASSETS)
        wait_for_asset_detail(asset, event)
      end

      # On an asset's detail view, clicks the category link at the given index
      # @param category_link_index [Integer]
      def click_asset_category(category_link_index)
        wait_until(Utils.short_wait) { detail_view_asset_category_elements.any? }
        wait_for_update_and_click_js detail_view_asset_category_elements[category_link_index]
      end

      # Returns the titles of whiteboard assets in which the asset has been used
      # @return [Array<String>]
      def detail_view_whiteboards_list
        detail_view_used_in_elements.map &:text
      end

      # On an asset's detail view, clicks the first link to a whiteboard asset in which the asset was used
      # @param whiteboard_asset [Asset]
      # @param event [Event]
      def click_whiteboard_usage_link(whiteboard_asset, event = nil)
        wait_for_update_and_click_js link_element(text: "#{whiteboard_asset.title}")
        wait_until(Utils.short_wait) { detail_view_asset_title == whiteboard_asset.title }
        add_event(event, EventType::VIEW_ASSET, whiteboard_asset.id)
      end

      # Verifies that the metadata of the first list view asset detail matches the expected metadata and gets the asset's
      # ID. Used to make sure the most recent asset addition has appeared at the top of the list.
      # @param user [User]
      # @param asset [Asset]
      # @param event [Event]
      def verify_first_asset(user, asset, event = nil)
        wait_until(timeout=Utils.short_wait) { list_view_asset_elements.any? }
        # Pause to allow DOM update to complete
        sleep 1
        logger.debug "Verifying list view asset title includes '#{asset.title}'"
        wait_until(timeout) { list_view_asset_title_elements[0].text.include? asset.title }
        logger.debug "Verifying list view asset owner is '#{user.full_name}'"
        # Subtract the 'by ' prefix
        wait_until(timeout) { list_view_asset_owner_name_elements[0].text[3..-1] == user.full_name }
        asset.id = list_view_asset_ids.first
        logger.debug "Asset ID is #{asset.id}"
        wait_for_load_and_click list_view_asset_elements.first
        add_event(event, EventType::VIEW, asset.id)
        add_event(event, EventType::VIEW_ASSET, asset.id)
        logger.debug "Verifying detail view asset title is '#{asset.title}'"
        wait_until(timeout) { detail_view_asset_title.include? asset.title }
        logger.debug "Verifying detail view asset owner is '#{user.full_name}'"
        wait_until(timeout) { detail_view_asset_owner_link_elements[0].text == user.full_name } rescue Selenium::WebDriver::Error::StaleElementReferenceError
        logger.debug 'Verifying asset description'
        asset.description.nil? ?
            wait_until(timeout) { detail_view_asset_desc == 'No description' } :
            wait_until(timeout) { detail_view_asset_desc == asset.description }
        logger.debug 'Verifying asset category'
        asset.category.nil? ?
            wait_until(timeout) { detail_view_asset_no_category? } :
            wait_until(timeout) { detail_view_asset_category_elements[0].text == asset.category }
        logger.debug 'Verifying asset source'
        (asset.type == 'Link') ?
            wait_until(timeout) { detail_view_asset_url_source_element.text == asset.url } :
            wait_until(timeout) { detail_view_asset_no_source? }
        logger.debug 'Checking presence of Remix button'
        (%w(File Link).include? asset.type) ?
            remix_button_element.when_not_visible(timeout) :
            remix_button_element.when_visible(timeout)
      end

      # PREVIEW SERVICE

      paragraph(:preparing_preview, xpath: '//p[contains(.,"preparing a preview")]')

      # Checks whether the expected type of asset preview has been generated for a given asset
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      # @param asset [Asset]
      # @param user [User]
      # @return [boolean]
      def preview_generated?(driver, url, asset, user)
        timeout = Utils.medium_wait
        logger.info "Verifying a preview of type '#{asset.preview}' is generated for the asset within #{timeout} seconds"
        preview_element = case asset.preview
                            when 'image'
                              image_element(class: 'preview-image')
                            when 'pdf_document'
                              div_element(xpath: '//iframe[@class="preview-document"]')
                            when 'embeddable_link'
                              div_element(xpath: "//iframe[contains(@src,'#{asset.url.sub(/https?\:(\/\/)(www.)?/,'')}')]")
                            when 'non_embeddable_link'
                              image_element(class: 'preview-image')
                            when 'embeddable_youtube'
                              div_element(xpath: '//iframe[contains(@src,"www.youtube.com/embed")]')
                            when 'embeddable_vimeo'
                              div_element(xpath: '//iframe[contains(@src,"player.vimeo.com")]')
                            when 'embeddable_video'
                              video_element(xpath: '//video')
                            else
                                paragraph_element(xpath: '//p[contains(.,"No preview available")]')
                          end
        load_page(driver, url)
        advanced_search(nil, asset.category, user, asset.type, nil)
        click_asset_link_by_id asset
        verify_block do
          preparing_preview_element.when_not_present(timeout) if preparing_preview?
          sleep 1
          preview_element.when_present Utils.short_wait
        end
      end

      # EDIT ASSET DETAILS

      link(:edit_details_link, xpath: '//span[contains(.,"Edit details")]/..')
      text_area(:title_edit_input, id: 'assetlibrary-edit-title')
      select_list(:category_edit_select, id: 'assetlibrary-edit-category')
      text_area(:description_edit_input, id: 'assetlibrary-edit-description')
      button(:save_changes, xpath: '//button[contains(.,"Save changes")]')

      # Edits the metadata of an existing asset
      # @param asset [Asset]
      # @param event [Event]
      def edit_asset_details(asset, event = nil)
        logger.info "Entering title '#{asset.title}', category '#{asset.category}', and description '#{asset.description}'"
        wait_for_load_and_click edit_details_link_element
        wait_for_element_and_type(title_edit_input_element, asset.title)
        asset.category.nil? ?
            wait_for_element_and_select_js(category_edit_select_element, 'Which assignment or topic is this related to') :
            wait_for_element_and_select_js(category_edit_select_element, asset.category)
        wait_for_element_and_type(description_edit_input_element, asset.description)
        sleep 1
        wait_for_update_and_click save_changes_element
        add_event(event, EventType::MODIFY, asset.id)
        add_event(event, EventType::EDIT_ASSET, asset.id)
        sleep 1
        wait_until(Utils.short_wait) { detail_view_asset_title == asset.title }
        add_event(event, EventType::VIEW, asset.id)
        add_event(event, EventType::VIEW)
        add_event(event, EventType::VIEW_ASSET, asset.id)
        add_event(event, EventType::LIST_ASSETS)
      end

      # REMIX

      button(:remix_button, xpath: '//button[contains(.,"Remix")]')
      link(:remixed_board_link, xpath: '//span[contains(.,"A new board")]/a')

      # Clicks the 'Remix' button for a whiteboard asset and returns a new whiteboard object
      # @return [Whiteboard]
      def click_remix
        wait_for_update_and_click remix_button_element
        id = get_whiteboard_id remixed_board_link_element
        title = remixed_board_link_element.text.delete('\"')
        Whiteboard.new({id: id, title: title})
      end

      # Clicks the link to a newly created remix whiteboard and shifts focus to the whiteboard
      # @param driver [Selenium::WebDriver]
      # @param whiteboard [Whiteboard]
      # @param event [Event]
      def open_remixed_board(driver, whiteboard, event = nil)
        wait_for_update_and_click remixed_board_link_element
        shift_to_whiteboard_window(driver, whiteboard)
        add_event(event, EventType::OPEN_WHITEBOARD)
        add_event(event, EventType::GET_CHAT_MSG)
      end

      # DOWNLOAD

      link(:download_asset_link, xpath: '//a[contains(.,"Download")]')

      # Prepares the download directory, clicks an asset's download button, waits for a file to appear in the
      # directory and reach the right size, and returns the resulting file name
      # @param asset [Asset]
      # @param event [Event]
      # @return [String]
      def download_asset(asset, event = nil)
        logger.info 'Downloading original asset'
        Utils.prepare_download_dir
        wait_for_load_and_click download_asset_link_element
        sleep 2
        wait_until(Utils.medium_wait) do
          Dir.entries("#{Utils.download_dir}").length == 3
          download_file_name = Dir.entries("#{Utils.download_dir}")[2]
          logger.debug "Downloaded file name is '#{download_file_name}'"
          download_file = File.new File.join(Utils.download_dir, download_file_name)
          asset_file = File.new SuiteCUtils.test_data_file_path(asset.file_name)
          wait_until(Utils.medium_wait) do
            logger.debug "The downloaded file size is currently #{download_file.size}, waiting for it to reach #{asset_file.size}"
            download_file.size == asset_file.size
          end
          add_event(event, EventType::DOWNLOAD_ASSET, asset.id)
          download_file_name
        end
      end

      # DELETE

      button(:delete_asset_button, xpath: '//button[@data-ng-click="deleteAsset()"]')

      # Deletes an asset
      # @param asset [Asset]
      # @param event [Event]
      def delete_asset(asset, event = nil)
        logger.info "Deleting asset ID #{asset.id}" unless asset.nil?
        alert { wait_for_update_and_click delete_asset_button_element }
        add_event(event, EventType::LIST_ASSETS)
        asset.visible = false unless asset.nil?
        delete_asset_button_element.when_not_visible Utils.short_wait rescue Selenium::WebDriver::Error::StaleElementReferenceError
      end

      # Toggles the 'like' button on an asset's detail view and returns the 'like' count prior to toggling
      # @param asset [Asset]
      # @param event [Event]
      # @return [String]
      def toggle_detail_view_item_like(asset, event = nil)
        logger.info 'Clicking the like button'
        wait_for_element(detail_view_asset_like_button_element, Utils.short_wait)
        already_liked = detail_view_asset_like_button_element.attribute('class').include? 'active'
        count = detail_view_asset_likes_count
        js_click detail_view_asset_like_button_element
        if already_liked
          add_event(event, EventType::REMOVE, asset.id)
          add_event(event, EventType::UNLIKE_ASSET, asset.id)
        else
          add_event(event, EventType::LIKE, asset.id)
          add_event(event, EventType::LIKE_ASSET, asset.id)
        end
        count
      end

      # Likes an asset and waits for its 'like' count to increment
      # @param asset [Asset]
      # @param event [Event]
      def like_asset(asset, event = nil)
        count = toggle_detail_view_item_like(asset, event)
        wait_until(Utils.short_wait) { detail_view_asset_likes_count == "#{count.to_i + 1}" }
      end

      # Unlikes an asset and waits for its 'like' count to decrement
      # @param asset [Asset]
      # @param event [Event]
      def unlike_asset(asset, event = nil)
        count = toggle_detail_view_item_like(asset, event)
        wait_until(Utils.short_wait) { detail_view_asset_likes_count == "#{count.to_i - 1}" }
      end

      button(:detail_view_pin_button, class: 'assetlibrary-item-pin')

      # Pins a detail view asset
      # @param asset [Asset]
      # @param event [Event]
      def pin_detail_view_asset(asset, event = nil)
        logger.info "Pinning detail view asset ID #{asset.id}"
        change_asset_pinned_state(detail_view_pin_button_element, 'Pinned')
        add_event(event, EventType::PIN_ASSET_DETAIL, asset.id)
      end

      # Unpins a detail view asset
      # @param asset [Asset]
      def unpin_detail_view_asset(asset)
        logger.info "Un-pinning detail view asset ID #{asset.id}"
        change_asset_pinned_state(detail_view_pin_button_element, 'Pin')
      end

      # ACTIVITY EVENT DROPS

      element(:activity_timeline_event_drops, xpath: '//h3[contains(.,"Activity Timeline")]/following-sibling::div[@data-ng-if="assetActivity"]//*[name()="svg"]')

      # Initializes a hash of all an asset's activities. Key is the activity type that appears on the popover and value is a zero count.
      # @return [Hash]
      def init_asset_activities
        (Activity::ACTIVITIES.map { |a| [a.type.to_sym, 0] }).to_h
      end

      # Given an asset activity hash, returns a hash with the activity counts that should appear on the four or five asset event drops lines.
      # @param asset_activity_count [Hash]
      # @return [Hash]
      def expected_event_drop_count(asset, asset_activity_count)
        event_drop_counts = {
            viewed: asset_activity_count[:get_view_asset],
            liked: asset_activity_count[:get_like],
            pinned: asset_activity_count[:get_pin_asset],
            commented: asset_activity_count[:get_comment],
            used_in_whiteboard: asset_activity_count[:get_whiteboard_add_asset]
        }
        # Whiteboard assets have an extra lane of metaballs for remixes
        (event_drop_counts[:remixed] = asset_activity_count[:get_remix_whiteboard]) if asset.type == 'Whiteboard'
        logger.debug "Expected asset event drop counts are #{event_drop_counts}"
        event_drop_counts
      end

      # Returns the activity labels on the My Classmates event drops
      # @param driver [Selenium::WebDriver]
      # @return [Array<String>]
      def visible_event_drop_count(driver, asset)
        # Shift focus to the new comment input so that the event drops will also move into the viewport.
        wait_for_element_and_type_js(text_area_element(id: 'assetlibrary-item-newcomment-body'), ' ')
        sleep 1
        activity_timeline_event_drops_element.when_visible Utils.short_wait
        div_element(xpath: '//strong[contains(text(), "View by")]').when_visible Utils.short_wait
        if (button = button_element(xpath: '//button[text()="All"]')).exists?
         wait_for_update_and_click_js button unless button.attribute('disabled')
        end
        sleep 1
        elements = driver.find_elements(xpath: '//h3[contains(.,"Activity Timeline")]/following-sibling::div[@data-ng-if="assetActivity"]//*[name()="svg"]/*[name()="g"]/*[name()="text"]')
        labels = elements.map &:text
        visible_event_drop_counts = {
            viewed: activity_type_count(labels, 0),
            liked: activity_type_count(labels, 1),
            pinned: activity_type_count(labels, 2),
            commented: activity_type_count(labels, 3),
            used_in_whiteboard: activity_type_count(labels, 4)
        }
        # Whiteboard assets have an extra lane of metaballs for remixes
        (visible_event_drop_counts[:remixed] = activity_type_count(labels, 5)) if asset.type == 'Whiteboard'
        logger.debug "Visible asset event drop counts are #{visible_event_drop_counts}"
        visible_event_drop_counts
      end

      # Given the position of an event drop in the HTML, zooms in very close, drags the drop into view, hovers over it,
      # and verifies the content of the tool-tip that appears.
      # @param driver [Selenium::WebDriver]
      # @param user [User]
      # @param activity [Activity]
      # @param line_node [Integer]
      def verify_latest_asset_event_drop(driver, user, activity, line_node)
        mouseover_event_drop(driver, line_node)
        wait_until(Utils.short_wait) { driver.find_element(:class => 'details-popover') }
        wait_until(Utils.short_wait) do
          logger.debug "Verifying that the user in the tooltip is '#{user.full_name}'"
          link_element(xpath: '//p[@class="details-popover-description"]//a').text == user.full_name
        end
        wait_until(Utils.short_wait) do
          logger.debug "Verifying the activity type in the tooltip is '#{activity.impact_type_drop}'"
          span_element(xpath: '//p[@class="details-popover-description"]/span/span').text.include? activity.impact_type_drop
        end
      end

      # COMMENTS

      span(:asset_detail_comment_count, xpath: '//div[@class="assetlibrary-item-metadata"]//span[@data-ng-bind="asset.comment_count | number"]')
      text_area(:comment_input, id: 'assetlibrary-item-newcomment-body')
      button(:comment_add_button, xpath: '//span[text()="Comment"]/..')
      elements(:comment, :div, :class => 'assetlibrary-item-comment')

      # Adds a comment on an asset's detail view
      # @param asset [Asset]
      # @param comment [Comment]
      # @param event [Event]
      def add_comment(asset, comment, event = nil)
        logger.info "Adding the comment '#{comment.body}'"
        scroll_to_bottom
        wait_for_element_and_type_js(comment_input_element, comment.body)
        wait_until(Utils.short_wait) { comment_add_button_element.enabled? }
        wait_for_update_and_click_js comment_add_button_element
        asset.comments.unshift(comment)
        add_event(event, EventType::POST, asset.id)
        add_event(event, EventType::CREATE_COMMENT, asset.id)
      end

      # Returns the body of an asset comment at a given index in the list of comments
      # @param index [Integer]
      # @return [String]
      def comment_body(index)
        comment_elements[index].paragraph_element.text
      end

      # Returns the link containing the commenter's name at a given index in the list of comments
      # @param index [Integer]
      # @return [PageObject::Elements::Link]
      def commenter_link(index)
        comment_elements[index].link_element
      end

      # Returns the text of the link containing the commenter's name at a given index in the list of comments
      # @param index [Integer]
      # @return [String]
      def commenter_name(index)
        commenter_link(index).text
      end

      # Returns a link with given text within the body of a comment at a given index in the list of comments
      # @param index [Integer]
      # @param link_text [String]
      # @return [PageObject::Elements::Link]
      def comment_body_link(index, link_text)
        link_element(xpath: "//div[@data-ng-repeat='comment in asset.comments'][#{index + 1}]//p/a[contains(.,'#{link_text}')]")
      end

      # Returns the reply button at a given index in the list of comments or nil if no button exists
      # @param index [Integer]
      # @return [PageObject::Elements::Button]
      def reply_button_element(index)
        button_element(xpath: "//div[@data-ng-repeat='comment in asset.comments'][#{index + 1}]//button[@title='Reply to this comment']")
      rescue Selenium::WebDriver::Error::NoSuchElementError
        nil
      end

      # Clicks the reply button at a given index in the list of comments
      # @param index [Integer]
      def click_reply_button(index)
        wait_for_load_and_click_js reply_button_element(index)
      end

      # Returns the textarea element of a reply at a given index in the list of comments
      # @param index [Integer]
      # @return [PageObject::Elements::TextArea]
      def reply_input_element(index)
        comment_elements[index].text_area_element(id: 'assetlibrary-item-addcomment-body')
      end

      # Returns the 'add' button of a reply at a given index in the list of comments
      # @param index [Integer]
      # @return [PageObject::Elements::Button]
      def reply_add_button_element(index)
        comment_elements[index].button_element(xpath: '//span[text()="Reply"]/..')
      end

      # Replies to a comment
      # @param asset [Asset]
      # @param comment [Comment]
      # @param reply [Comment]
      # @param event [Event]
      def reply_to_comment(asset, comment, reply, event = nil)
        logger.info "Replying '#{reply.body}'"
        index = asset.comments.index comment
        click_reply_button(index)
        reply_input_element(index).when_visible Utils.short_wait
        reply_input_element(index).send_keys reply.body
        wait_for_update_and_click_js reply_add_button_element(index)
        asset.comments.insert((index + 1), reply)
        add_event(event, EventType::POST, asset.id)
        add_event(event, EventType::CREATE_COMMENT, asset.id)
      end

      # Returns the reply edit button at a given index in the list of comments or nil if no button exists
      # @param index [Integer]
      # @return [PageObject::Elements::Button]
      def edit_button_element(index)
        button_element(xpath: "//div[@data-ng-repeat='comment in asset.comments'][#{index + 1}]//button[@title='Edit this comment']")
      rescue Selenium::WebDriver::Error::NoSuchElementError
        nil
      end

      # Clicks the edit button at a given index in the list of comments
      # @param index [Integer]
      def click_edit_button(index)
        wait_for_load_and_click_js edit_button_element(index)
      end

      # Returns the textarea element of a comment edit at a given index in the list of comments
      # @param index [Integer]
      # @return [PageObject::Elements::TextArea]
      def edit_input_element(index)
        comment_elements[index].text_area_element(id: 'assetlibrary-item-editcomment-body')
      end

      # Edits a comment
      # @param asset [Asset]
      # @param comment [Comment]
      # @param event [Event]
      def edit_comment(asset, comment, event = nil)
        index = asset.comments.index comment
        logger.info "Editing comment at index #{index}. New comment is '#{comment.body}'"
        click_edit_button(index)
        wait_for_element_and_type_js(edit_input_element(index), comment.body)
        wait_for_update_and_click_js comment_elements[index].button_element(xpath: '//button[contains(.,"Save Changes")]')
        wait_until(Utils.short_wait) { comment_body(index) == comment.body }
        add_event(event, EventType::MODIFY, asset.id)
        add_event(event, EventType::EDIT_COMMENT, asset.id)
      end

      # Returns the 'cancel' comment edit button at a given index in the list of comments
      # @param index [Integer]
      # @return [PageObject::Elements::Button]
      def cancel_button_element(index)
        comment_elements[index].button_element(xpath: '//button[contains(.,"Cancel")]')
      end

      # Returns the 'delete' comment button at a given index in the list of comments or nil if no button exists
      # @param index [Integer]
      # @return [PageObject::Elements::Button]
      def delete_button_element(index)
        button_element(xpath: "//div[@data-ng-repeat='comment in asset.comments'][#{(index + 1).to_s}]//button[@title='Delete this comment']")
      rescue Selenium::WebDriver::Error::NoSuchElementError
        nil
      end

      # Deletes a comment
      # @param asset [Asset]
      # @param comment [Comment]
      # @param event [Event]
      def delete_comment(asset, comment, event = nil)
        index = asset.comments.index comment
        logger.info "Deleting comment at index #{index}"
        alert { wait_for_load_and_click_js delete_button_element(index) }
        asset.comments.delete comment
        add_event(event, EventType::DELETE, asset.id)
        add_event(event, EventType::DELETE_COMMENT, asset.id)
        sleep 1
      end

      # Given an asset, verifies that each of its comments appears correctly in the asset detail view
      # @param asset [Asset]
      def verify_comments(asset)
        wait_until(timeout = Utils.short_wait) { comment_elements.length == asset.comments.length }
        wait_until(timeout) { asset_detail_comment_count == "#{asset.comments.length}" }
        asset.comments.each do |comment|
          index = asset.comments.index comment
          wait_until(timeout) { commenter_name(index).include?(comment.user.full_name) }
          wait_until(timeout) { comment_body(index) == comment.body }
        end
      end

    end
  end
end
