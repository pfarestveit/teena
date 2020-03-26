require_relative '../../util/spec_helper'

module Page

  module SuiteCPages

    class AssetLibraryListViewPage

      include PageObject
      include Logging
      include Page
      include SuiteCPages

      # Loads the Asset Library tool and switches browser focus to the tool iframe
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      # @param event [Event]
      def load_page(driver, url, event = nil)
        navigate_to url
        wait_until(Utils.medium_wait) { title == "#{LtiTools::ASSET_LIBRARY.name}" }
        hide_canvas_footer_and_popup
        switch_to_canvas_iframe
        add_event(event, EventType::NAVIGATE)
        add_event(event, EventType::VIEW)
        add_event(event, EventType::LAUNCH_ASSET_LIBRARY)
        add_event(event, EventType::LIST_ASSETS)
      end

      # CANVAS SYNC

      button(:resume_sync_button, xpath: '//button[contains(.,"Resume syncing")]')
      div(:resume_sync_success, xpath: '//div[contains(.,"Syncing has been resumed for this course. There may be a short delay before SuiteC tools are updated.")]')

      # Checks if Canvas sync is disabled. If so, adds an asset to create new activity and resumes sync.
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      # @param event [Event]
      def ensure_canvas_sync(driver, url, event = nil)
        load_page(driver, url, event)
        add_site_link_element.when_visible Utils.short_wait
        if resume_sync_button?
          add_site(Asset.new({url: 'www.google.com', title: 'resume sync asset'}), event)
          logger.info 'Syncing is disabled for this course site, re-enabling'
          wait_for_update_and_click_js resume_sync_button_element
          resume_sync_success_element.when_visible Utils.short_wait
          sleep Utils.medium_wait
        else
          logger.info 'Syncing is still enabled for this course site'
        end
      end

      # ASSETS

      link(:manage_assets_link, xpath: '//a[contains(.,"Manage assets")]')
      h2(:manage_assets_heading, xpath: '//h2[text()="Manage Assets"]')

      # Clicks the 'manage assets' link in the admin view
      def click_manage_assets_link
        wait_for_load_and_click_js manage_assets_link_element
        manage_assets_heading_element.when_visible Utils.short_wait
      end

      elements(:list_view_asset, :list_item, xpath: '//li[contains(@data-ng-repeat,"asset")]')
      elements(:list_view_asset_title, :span, xpath: '//li[contains(@data-ng-repeat,"asset")]//div[@class="col-list-item-metadata"]/div[1]')
      elements(:list_view_asset_owner_name, :element, xpath: '//li[contains(@data-ng-repeat,"asset")]//small')
      elements(:list_view_asset_like_button, :button, xpath: '//button[@data-ng-click="like(asset)"]')

      # Returns an array of list view asset titles
      # @return [Array<String>]
      def list_view_asset_titles
        wait_until(Utils.short_wait) { list_view_asset_title_elements.any? }
        list_view_asset_title_elements.map &:text
      end

      # Returns the expected asset title for an asset derived from a Canvas assignment submission
      # @param asset [Asset]
      # @return [String]
      def get_canvas_submission_title(asset)
        # For Canvas submissions, the file name or the URL are used as the asset title
        asset.title = (asset.type == 'File') ? asset.file_name.sub(/\..*/, '') : asset.url
      end

      # Loads the list view and scrolls down until a given asset appears
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      # @param asset [Asset]
      # @param event [Event]
      def load_list_view_asset(driver, url, asset, event = nil)
        load_page(driver, url, event)
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
        span_element(xpath: "#{list_view_asset_elements[index].locator[:xpath]}[#{index + 1}]//span[@data-ng-bind='asset.views | number']").text
      end

      # Clicks the list view asset link containing a given asset ID
      # @param asset [Asset]
      def click_asset_link_by_id(asset)
        logger.info "Clicking thumbnail for asset ID #{asset.id}"
        wait_for_update_and_click_js link_element(xpath: "//a[contains(@href,'/assetlibrary/#{asset.id}')]")
      end

      # LIKES, PINS, COMMENTS

      # Returns an array of enabled 'like' buttons visible on the list view
      # @return [Array<PageObject::Elements::Button>]
      def enabled_like_buttons
        list_view_asset_like_button_elements.map { |button| button if button.enabled? }
      end

      # Returns the pin button for a list view asset
      # @param asset [Asset]
      # @return [PageObject::Elements::Button]
      def list_view_pin_element(asset)
        button_element(xpath: "//button[@id='iconbar-pin-#{asset.id}']")
      end

      # Pins a list view asset
      # @param asset [Asset]
      # @param event [Event]
      def pin_list_view_asset(asset, event = nil)
        logger.info "Pinning list view asset ID #{asset.id}"
        change_asset_pinned_state(list_view_pin_element(asset), 'Pinned')
        add_event(event, EventType::PIN_ASSET_LIST, asset.id)
      end

      # Unpins a list view asset
      # @param asset [Asset]
      def unpin_list_view_asset(asset)
        logger.info "Un-pinning list view asset ID #{asset.id}"
        change_asset_pinned_state(list_view_pin_element(asset), 'Pin')
      end

      # Returns the number of an asset's comments on list view
      # @param index [Integer]
      # @return [String]
      def asset_comment_count(index)
        span_element(xpath: "#{list_view_asset_elements[index].locator[:xpath]}//span[@data-ng-bind='asset.comment_count | number']").text
      end

    end
  end
end
