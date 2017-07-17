require_relative '../../util/spec_helper'

module Page

  module SuiteCPages

    class AssetLibraryPage

      include PageObject
      include Logging
      include Page
      include SuiteCPages

      # Loads the Asset Library tool and switches browser focus to the tool iframe
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      def load_page(driver, url)
        navigate_to url
        wait_until { title == "#{SuiteCTools::ASSET_LIBRARY.name}" }
        hide_canvas_footer
        switch_to_canvas_iframe driver
      end

      button(:resume_sync_button, xpath: '//button[contains(.,"Resume syncing")]')
      div(:resume_sync_success, xpath: '//div[contains(.,"Syncing has been resumed for this course. There may be a short delay before SuiteC tools are updated.")]')

      # Checks if Canvas sync is disabled. If so, adds an asset to create new activity and resumes sync.
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      def ensure_canvas_sync(driver, url)
        load_page(driver, url)
        add_site_link_element.when_visible Utils.short_wait
        if resume_sync_button?
          add_site Asset.new({ url: 'www.google.com', title: 'resume sync asset' })
          logger.info 'Syncing is disabled for this course site, re-enabling'
          wait_for_update_and_click_js resume_sync_button_element
          resume_sync_success_element.when_visible Utils.short_wait
          sleep Utils.medium_wait
        else
          logger.info 'Syncing is still enabled for this course site'
        end
      end

      # ASSETS

      elements(:list_view_asset, :list_item, class: 'assetlibrary-list-item')
      elements(:list_view_asset_title, :span, xpath: '//li[contains(@data-ng-repeat,"asset")]//div[@class="col-list-item-metadata"]/div[1]')
      elements(:list_view_asset_owner_name, :element, xpath: '//li[contains(@data-ng-repeat,"asset")]//small')
      elements(:list_view_asset_likes_count, :span, xpath: '//span[@data-ng-bind="asset.likes | number"]')
      elements(:list_view_asset_like_button, :button, xpath: '//button[@data-ng-click="like(asset)"]')
      elements(:list_view_asset_views_count, :span, xoath: '//div[@class="assetlibrary-item-metadata"]//span[@data-ng-bind="asset.views | number"]')
      elements(:list_view_asset_comments_count, :span, xpath: '//span[@data-ng-bind="asset.comment_count | number"]')

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

      # Returns an array of list view asset titles
      # @return [Array<String>]
      def list_view_asset_titles
        wait_until { list_view_asset_title_elements.any? }
        list_view_asset_title_elements.map &:text
      end

      # Loads the list view and scrolls down until a given asset appears
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      # @param asset [Asset]
      def load_list_view_asset(driver, url, asset)
        load_page(driver, url)
        wait_until(Utils.medium_wait) do
          scroll_to_bottom
          sleep 1
          link_element(xpath: "//a[contains(@href,'/assetlibrary/#{asset.id}')]").exists?
        end
      end

      # Given the index of an asset in list view, returns the asset's view count
      # @param index [Integer]
      # @return [String]
      def list_view_asset_view_count(index)
        list_view_asset_elements[index].span_element(xpath: '//span[@data-ng-bind="asset.views | number"]').text
      end

      # Clicks the list view asset link containing a given asset ID
      # @param asset [Asset]
      def click_asset_link_by_id(asset)
        logger.info "Clicking thumbnail for asset ID #{asset.id}"
        wait_for_update_and_click link_element(xpath: "//a[contains(@href,'/assetlibrary/#{asset.id}')]")
      end

      # Waits for an asset's detail view to load
      # @param asset [Asset]
      def wait_for_asset_detail(asset)
        wait_until(Utils.short_wait) { detail_view_asset_title.include? "#{asset.title}" }
      end

      # Combines methods to load the asset library, find a given asset, and load its detail view
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      # @param asset [Asset]
      def load_asset_detail(driver, url, asset)
        # TODO - remove the following line when asset deep links work from the Asset Library
        navigate_to 'http://www.google.com'
        navigate_to "#{url}#col_asset=#{asset.id}"
        switch_to_canvas_iframe driver
        wait_for_asset_detail asset
      end

      # On an asset's detail view, clicks the category link at the given index
      # @param category_link_index [Integer]
      def click_asset_category(category_link_index)
        wait_until(Utils.short_wait) { detail_view_asset_category_elements.any? }
        wait_for_update_and_click_js detail_view_asset_category_elements[category_link_index]
      end

      # Returns the expected asset title for an asset derived from a Canvas assignment submission
      # @param asset [Asset]
      # @return [String]
      def get_canvas_submission_title(asset)
        # For Canvas submissions, the file name or the URL are used as the asset title
        asset.type == 'File' ? asset.title = asset.file_name.sub(/\..*/, '') : asset.title = asset.url
      end

      # Returns the titles of whiteboard assets in which the asset has been used
      # @return [Array<String>]
      def detail_view_whiteboards_list
        (detail_view_used_in_elements.map &:text).to_a
      end

      # Verifies that the metadata of the first list view asset matches the expected metadata and sets the asset object's
      # ID. Used to make sure the most recent asset addition has appeared at the top of the list.
      # @param user [User]
      # @param asset [Asset]
      def verify_first_asset(user, asset)
        # Pause to allow DOM update to complete
        sleep 1
        logger.debug "Verifying list view asset title includes '#{asset.title}'"
        wait_until(timeout=Utils.medium_wait) { list_view_asset_title_elements[0].text.include? asset.title }
        logger.debug "Verifying list view asset owner is '#{user.full_name}'"
        # Subtract the 'by ' prefix
        wait_until(timeout) { list_view_asset_owner_name_elements[0].text[3..-1] == user.full_name }
        asset.id = list_view_asset_ids.first
        logger.debug "Asset ID is #{asset.id}"
        wait_for_load_and_click_js list_view_asset_link_elements.first
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
        advanced_search(nil, asset.category, user, asset.type)
        click_asset_link_by_id asset
        verify_block do
          preparing_preview_element.when_not_present(timeout) if preparing_preview?
          sleep 1
          preview_element.when_present Utils.short_wait
        end
      end

      # MANAGE ASSETS

      link(:manage_assets_link, xpath: '//a[contains(.,"Manage assets")]')
      h2(:manage_assets_heading, xpath: '//h2[text()="Manage Assets"]')

      # Clicks the 'manage assets' link in the admin view
      def click_manage_assets_link
        wait_for_load_and_click manage_assets_link_element
        manage_assets_heading_element.when_visible Utils.short_wait
      end

      text_area(:custom_category_input, id: 'assetlibrary-manageassets-create-name')
      button(:add_custom_category_button, xpath: '//button[text()="Add"]')
      unordered_list(:custom_categories_list, xpath: '//h3[text()="Custom Categories"]/following-sibling::ul')
      elements(:custom_category, :list_item, xpath: '//h3[text()="Custom Categories"]/following-sibling::ul/li')
      elements(:custom_category_title, :span, xpath: '//h3[text()="Custom Categories"]/following-sibling::ul/li//span[@data-ng-bind="category.title"]')
      elements(:edit_category_form, :form, class: 'assetlibrary-manageassets-edit-form')
      div(:category_title_error_msg, xpath: '//div[contains(.,"Please enter a category")]')

      # Custom categories

      # Loads the asset library and adds a collection of custom categories
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      # @param category_titles [Array<String>]
      def add_custom_categories(driver, url, category_titles)
        load_page(driver, url)
        click_manage_assets_link
        category_titles.each do |category_title|
          logger.info "Adding category called #{category_title}"
          wait_for_element_and_type_js(custom_category_input_element, category_title)
          wait_for_update_and_click_js add_custom_category_button_element
        end
      end

      # Returns an array of existing custom category titles
      # @return [Array<String>]
      def custom_category_titles
        custom_categories_list_element.when_visible
        sleep 1
        custom_category_title_elements.map &:text
      end

      # Returns the index of a given custom category title in the list of titles
      # @param category_title [String]
      # @return [Integer]
      def custom_category_index(category_title)
        wait_until(Utils.short_wait) { custom_category_title_elements.any? }
        custom_category_titles.index category_title
      end

      # Returns the asset count shown for a custom category at a given index
      # @param index [Integer]
      # @return [String]
      def custom_category_asset_count(index)
        div_element(xpath: "//h3[text()='Custom Categories']/following-sibling::ul/li[#{index + 1}]//small").text
      end

      # Clicks the edit button for a custom category at a given index
      # @param index [Integer]
      def click_edit_custom_category(index)
        wait_for_update_and_click_js button_element(xpath: "//h3[text()='Custom Categories']/following-sibling::ul/li[#{index + 1}]//button[@title='Edit this category']")
      end

      # Enters a category title while editing a custom category at a given index
      # @param index [Integer]
      # @param new_title [String]
      def enter_edited_category_title(index, new_title)
        logger.debug "Entering new title '#{new_title}' for category at index #{index}"
        wait_for_element_and_type_js(text_area_element(xpath: "//h3[text()='Custom Categories']/following-sibling::ul/li[#{index + 1}]//input[@id='assetlibrary-manageassets-edit-name']"), new_title)
      end

      # Clicks the 'cancel' button when editing a custom category at a given index
      # @param index [Integer]
      def click_cancel_custom_category_edit(index)
        wait_for_update_and_click_js button_element(xpath: "//h3[text()='Custom Categories']/following-sibling::ul/li[#{index + 1}]//button[text()='Cancel']")
      end

      # Clicks the 'save' button when editing a custom category at a given index
      # @param index [Integer]
      def click_save_custom_category_edit(index)
        wait_for_update_and_click_js button_element(xpath: "//h3[text()='Custom Categories']/following-sibling::ul/li[#{index + 1}]//button[text()='Save Changes']")
      end

      # Deletes a custom category with a given title
      # @param category_title [String]
      def delete_custom_category(category_title)
        logger.info "Deleting category called #{category_title}"
        wait_until(Utils.short_wait) { custom_category_titles.include? category_title }
        delete_button = button_element(xpath: "//h3[text()='Custom Categories']/following-sibling::ul/li[#{custom_category_index(category_title) + 1}]//button[@title='Delete this category']")
        confirm(true) { wait_for_update_and_click_js delete_button }
        sleep 2
      end

      # Canvas categories

      elements(:canvas_category, :list_item, xpath: '//h3[text()="Assignments"]/following-sibling::ul/li')
      elements(:canvas_category_title, :span, xpath: '//h3[text()="Assignments"]/following-sibling::ul/li//span[@data-ng-bind="category.title"]')

      # Waits for the Canvas poller to import a Canvas assignment as a category
      # @param driver [Selenium::WebDriver]
      # @param asset_library_url [String]
      # @param assignment [Assignment]
      def wait_for_canvas_category(driver, asset_library_url, assignment)
        logger.info "Checking if the Canvas assignment #{assignment.title} has appeared on the Manage Categories page yet"
        tries ||= Utils.poller_retries
        load_page(driver, asset_library_url)
        click_manage_assets_link
        wait_until(3) { canvas_category_elements.any? && (canvas_category_title_elements.map &:text).include?(assignment.title) }
        logger.debug 'The assignment category has appeared'
      rescue
        logger.debug "The assignment category has not yet appeared, will retry in #{Utils.short_wait} seconds"
        sleep Utils.short_wait
        retry unless (tries -= 1).zero?
      end

      # Returns the checkbox element for toggling Canvas assignment sync
      # @param assignment [Assignment]
      # @return [PageObject::Elements::CheckBox]
      def assignment_sync_cbx(assignment)
        checkbox_element(xpath: "//span[text()='#{assignment.title}']/../following-sibling::div//input")
      end

      # Enables syncing for a given assignment
      # @param assignment [Assignment]
      def enable_assignment_sync(assignment)
        logger.info "Enabling Canvas assignment sync for #{assignment.title}"
        assignment_sync_cbx(assignment).when_visible Utils.short_wait
        assignment_sync_cbx(assignment).checked? ?
            logger.debug('Assignment sync is already enabled, moving on') :
            wait_for_update_and_click_js(assignment_sync_cbx assignment)
      end

      # Disables syncing for a given assignment
      # @param assignment [Assignment]
      def disable_assignment_sync(assignment)
        logger.info "Disabling Canvas assignment sync for #{assignment.title}"
        assignment_sync_cbx(assignment).when_visible Utils.short_wait
        assignment_sync_cbx(assignment).checked? ?
            wait_for_update_and_click_js(assignment_sync_cbx assignment) :
            logger.debug('Assignment sync is already disabled, moving on')
      end

      # Asset Migration

      select_list(:migrate_assets_select, id: 'assetlibrary-manageassets-migrate-coursesite')
      button(:migrate_assets_button, xpath: '//button[text()="Migrate assets"]')
      div(:migration_started_msg, xpath: '//div[contains(.,"Your migration has started. Copied assets will appear in the Asset Library of the destination course.")]')
      div(:no_courses_msg, xpath: '//h3["Migrate Assets"]/following-sibling::div/div[contains(.,"You are not an instructor in any other course sites using the Asset Library.")]')

      # Kicks off asynchronous asset migration from one asset library to another
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      # @param destination_course [Course]
      def migrate_assets(driver, url, destination_course)
        logger.info "Migrating assets to '#{destination_course.title}', ID '#{destination_course.site_id}'"
        load_page(driver, url)
        click_manage_assets_link
        wait_for_element_and_select_js(migrate_assets_select_element, destination_course.title)
        wait_for_update_and_click_js migrate_assets_button_element
        migration_started_msg_element.when_present Utils.medium_wait
      end

      # Makes a number of attempts to find an asset in an asset library following asynchronous asset migration
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      # @param asset [Asset]
      # @param user [User]
      # @return [boolean]
      def asset_migrated?(driver, url, asset, user)
        tries ||= 10
        load_page(driver, url)
        advanced_search(asset.title, nil, user, asset.type)
        verify_first_asset(user, asset)
        true
      rescue
        logger.debug "The migrated asset has not yet appeared, will retry in #{Utils.short_wait} seconds"
        sleep Utils.short_wait
        retry unless (tries -= 1).zero?
        false
      end

      # EDIT ASSET DETAILS

      link(:edit_details_link, xpath: '//span[contains(.,"Edit details")]/..')
      text_area(:title_edit_input, id: 'assetlibrary-edit-title')
      select_list(:category_edit_select, id: 'assetlibrary-edit-category')
      text_area(:description_edit_input, id: 'assetlibrary-edit-description')
      button(:save_changes, xpath: '//button[contains(.,"Save changes")]')

      # Edits the metadata of an existing asset
      # @param asset [Asset]
      def edit_asset_details(asset)
        logger.info "Entering title '#{asset.title}, category '#{asset.category}', and description '#{asset.description}'"
        wait_for_load_and_click edit_details_link_element
        wait_for_element_and_type(title_edit_input_element, asset.title)
        asset.category.nil? ?
            wait_for_element_and_select_js(category_edit_select_element, 'Which assignment or topic is this related to') :
            wait_for_element_and_select_js(category_edit_select_element, asset.category)
        wait_for_element_and_type(description_edit_input_element, asset.description)
        wait_for_update_and_click save_changes_element
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
      def open_remixed_board(driver, whiteboard)
        wait_for_update_and_click remixed_board_link_element
        shift_to_whiteboard_window(driver, whiteboard)
      end

      # DOWNLOAD

      link(:download_asset_link, xpath: '//a[contains(.,"Download")]')

      # Prepares the download directory, clicks an asset's download button, waits for a file to appear in the
      # directory, and returns the resulting file name
      # @return [String]
      def download_asset
        logger.info 'Downloading original asset'
        Utils.prepare_download_dir
        wait_for_load_and_click_js download_asset_link_element
        sleep 2
        wait_until(Utils.medium_wait) do
          Dir.entries("#{Utils.download_dir}").length == 3
          sleep 2
          wait_until(15) do
            logger.debug 'Download started, waiting for download to complete'
            !(Dir.entries("#{Utils.download_dir}")[2]).include? '.crdownload'
          end
          Dir.entries("#{Utils.download_dir}")[2]
        end
      end

      # DELETING

      button(:delete_asset_button, xpath: '//button[@data-ng-click="deleteAsset()"]')

      # Deletes an asset
      def delete_asset(asset = nil)
        logger.info "Deleting asset ID #{asset.id}" unless asset.nil?
        confirm(true) { wait_for_update_and_click delete_asset_button_element }
        delete_asset_button_element.when_not_visible Utils.short_wait rescue Selenium::WebDriver::Error::StaleElementReferenceError
        asset.visible = false unless asset.nil?
      end

      # LIKES

      # Returns an array of enabled 'like' buttons visible on the list view
      # @return [Array<PageObject::Elements::Button>]
      def enabled_like_buttons
        (list_view_asset_like_button_elements.map { |button| button if button.enabled? }).to_a
      end

      # Toggles the 'like' button on an asset's detail view
      def toggle_detail_view_item_like
        logger.info 'Clicking the like button'
        wait_for_update_and_click_js detail_view_asset_like_button_element
      end

      # PINS

      # Returns the pin button for a list view asset
      # @param asset [Asset]
      # @return [PageObject::Elements::Button]
      def list_view_pin_element(asset)
        button_element(id: "iconbar-pin-#{asset.id}")
      end

      # Pins a list view asset
      # @param asset [Asset]
      def pin_list_view_asset(asset)
        logger.info "Pinning list view asset ID #{asset.id}"
        change_asset_pinned_state(list_view_pin_element(asset), 'Pinned')
      end

      # Unpins a list view asset
      # @param asset [Asset]
      def unpin_list_view_asset(asset)
        logger.info "Un-pinning list view asset ID #{asset.id}"
        change_asset_pinned_state(list_view_pin_element(asset), 'Pin')
      end

      button(:detail_view_pin_button, class: 'assetlibrary-item-pin')

      # Pins a detail view asset
      # @param asset [Asset]
      def pin_detail_view_asset(asset)
        logger.info "Pinning detail view asset ID #{asset.id}"
        change_asset_pinned_state(detail_view_pin_button_element, 'Pinned')
      end

      # Unpins a detail view asset
      # @param asset [Asset]
      def unpin_detail_view_asset(asset)
        logger.info "Un-pinning detail view asset ID #{asset.id}"
        change_asset_pinned_state(detail_view_pin_button_element, 'Pin')
      end

      # COMMENTS

      span(:asset_detail_comment_count, xpath: '//div[@class="assetlibrary-item-metadata"]//span[@data-ng-bind="asset.comment_count | number"]')
      text_area(:comment_input, id: 'assetlibrary-item-newcomment-body')
      button(:comment_add_button, xpath: '//span[text()="Comment"]/..')
      elements(:comment, :div, class: 'assetlibrary-item-comment')

      # Adds a given comment on an asset's detail view
      # @param comment_body [String]
      def add_comment(comment_body)
        logger.info "Adding the comment '#{comment_body}'"
        scroll_to_bottom
        wait_for_element_and_type_js(comment_input_element, comment_body)
        wait_until(Utils.short_wait) { comment_add_button_element.enabled? }
        wait_for_update_and_click_js comment_add_button_element
      end

      # Returns the number of an asset's comments on list view
      # @param index [Integer]
      # @return [String]
      def asset_comment_count(index)
        list_view_asset_elements[index].span_element(xpath: '//span[@data-ng-bind="asset.comment_count | number"]').text
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

      # Enters and saves a reply at a given index in the list of comments
      # @param index [Integer]
      # @param reply_body [String]
      def reply_to_comment(index, reply_body)
        logger.info "Replying to comment at index #{index}. Reply is '#{reply_body}'"
        click_reply_button(index)
        reply_input_element(index).when_visible Utils.short_wait
        reply_input_element(index).send_keys reply_body
        wait_for_update_and_click_js reply_add_button_element(index)
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

      # Returns the 'save' button of an edited comment at a given index in the list of comments
      # @param index [Integer]
      # @return [PageObject::Elements::Button]
      def edit_save_button_element(index)
        comment_elements[index].button_element(xpath: '//button[contains(.,"Save Changes")]')
      end

      # Enters and saves a comment edit at a given index in the list of comments
      # @param index [Integer]
      # @param edited_body [String]
      def edit_comment(index, edited_body)
        logger.info "Editing comment at index #{index}. New comment is '#{edited_body}'"
        click_edit_button(index)
        wait_for_element_and_type_js(edit_input_element(index), edited_body)
        wait_for_update_and_click_js edit_save_button_element(index)
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

      # Deletes a comment at a given index in the list of comments
      # @param index [Integer]
      def delete_comment(index)
        logger.info "Deleting comment at index #{index}"
        confirm(true) { wait_for_load_and_click_js delete_button_element(index) }
        sleep 1
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
        drag_latest_drop_into_view(driver, line_node)
        wait_until(Utils.short_wait) { driver.find_element(class: 'details-popover') }
        wait_until(Utils.short_wait) do
          logger.debug "Verifying that the user in the tooltip is '#{user.full_name}'"
          link_element(xpath: '//p[@class="details-popover-description"]//a').text == user.full_name
        end
        wait_until(Utils.short_wait) do
          logger.debug "Verifying the activity type in the tooltip is '#{activity.impact_type_drop}'"
          span_element(xpath: '//p[@class="details-popover-description"]/span/span').text.include? activity.impact_type_drop
        end
      end

    end
  end
end
