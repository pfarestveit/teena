require_relative '../../util/spec_helper'

module Page

  module SuiteCPages

    class ImpactStudioPage

      include PageObject
      include Logging
      include Page
      include SuiteCPages

      # Loads the LTI tool
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      def load_page(driver, url)
        navigate_to url
        wait_until { title == "#{SuiteCTools::IMPACT_STUDIO.name}" }
        hide_canvas_footer
        switch_to_canvas_iframe driver
        name_element.when_visible Utils.medium_wait
      end

      # IDENTITY

      image(:avatar, class: 'profile-summary-avatar')
      h1(:name, xpath: '//h1[@data-ng-bind="user.canvas_full_name"]')
      div(:profile_desc, xpath: '//div[@data-ng-bind-html="user.personal_bio | linky:\'_blank\' | toolHrefHashtag:\'dashboard\':user.id"]')
      link(:edit_profile_link, text: 'Edit Profile')
      text_area(:edit_profile_input, id: 'profile-edit-description')
      span(:char_limit_msg, xpath: '//span[contains(.,"255 character limit")]')
      button(:update_profile_button, xpath: '//button[text()="Update Profile"]')
      link(:cancel_edit_profile, text: 'Cancel')
      elements(:section, xpath: '//span[@data-ng-repeat="section in user.canvasCourseSections"]')
      span(:last_activity, xpath: '//div[contains(.,"Last activity:")]/span')
      link(:engagement_index_link, xpath: '//div[contains(@class,"profile-summary")]//a[contains(.,"Engagement Index")]')
      link(:turn_on_sharing_link, text: 'Turn on?')
      div(:engagement_index_score, class: 'profile-engagement-score')
      span(:engagement_index_rank, xpath: '//span[@data-ng-bind="userRank"]')
      span(:engagement_index_rank_ttl, xpath: '//span[@data-ng-bind="courseUserCount"]')

      # Returns the visible sections
      def sections
        section_elements.map &:text
      end

      # Clicks the Edit link for user profile
      def click_edit_profile
        wait_for_update_and_click edit_profile_link_element
      end

      # Enters text in the profile description input
      # @param desc [String]
      def enter_profile_desc(desc)
        wait_for_element_and_type(edit_profile_input_element, desc)
      end

      # Clicks the 'Cancel' link for a profile edit
      def cancel_profile_edit
        wait_for_update_and_click cancel_edit_profile_element
      end

      # Edits and saves a profile description
      # @param desc [String]
      def edit_profile(desc)
        logger.info "Adding user description '#{desc}'"
        click_edit_profile
        enter_profile_desc desc
        wait_for_update_and_click update_profile_button_element
      end

      # Clicks the Engagement Index link
      def click_engagement_index
        wait_for_update_and_click engagement_index_link_element
      end

      # Clicks the "Turn on?" link
      def click_turn_on
        wait_for_update_and_click turn_on_sharing_link_element
      end

      # SEARCH

      # Searches for a given user and loads its Impact Studio profile page. Makes two attempts since sometimes the first click does not
      # trigger the select options.
      # @param user [User]
      def search_for_user(user)
        logger.info "Searching for #{user.full_name} UID #{user.uid}"
        tries ||= 2
        begin
          wait_for_load_and_click text_area_element(xpath: '//input[@placeholder="Search for other people"]')
          (option = list_item_element(xpath: "//div[contains(@class,'select-dropdown')]//li[contains(.,'#{user.full_name}')]")).when_present Utils.short_wait
          option.click
          wait_until(Utils.medium_wait) { name == user.full_name }
        rescue
          (tries -= 1).zero? ? fail : retry
        end
      end

      # ACTIVITY EVENT DROPS

      element(:my_activity_event_drops, xpath: '//h3[contains(.,"My Activity")]/following-sibling::div[@class="col-flex"]//*[local-name()="svg"]')
      element(:activity_event_drops, xpath: '//h3[contains(.,"Activity")]/following-sibling::div[@class="col-flex"]//*[name()="svg"]')

      # Returns the activity labels on the user event drops
      # @param driver [Selenium::WebDriver]
      # @return [Array<String>]
      def activity_event_counts(driver)
        # Pause a couple times to allow a complete DOM update
        sleep 2
        activity_event_drops_element.when_visible Utils.short_wait
        sleep 1
        elements = driver.find_elements(xpath: '//h3[contains(.,"Activity")]/following-sibling::div[@class="col-flex"]//*[local-name()="svg"]/*[name()="g"]/*[name()="text"]')
        labels = elements.map &:text
        logger.debug "Visible user event drop counts are #{event_drop_counts labels}"
        event_drop_counts labels
      end

      # Waits for the Canvas poller to update discussion activities so that they appear in the counts of event drops
      # @param driver [Selenium::WebDriver]
      # @param studio_url [String]
      # @param expected_event_count [Array<String>]
      def wait_for_canvas_event(driver, studio_url, expected_event_count)
        logger.info "Waiting until the Canvas poller updates the activity event counts to #{expected_event_count}"
        tries ||= Utils.poller_retries
        begin
          load_page(driver, studio_url)
          wait_until(3) { activity_event_counts(driver) == expected_event_count }
        rescue
          if (tries -= 1).zero?
            fail
          else
            sleep Utils.short_wait
            retry
          end
        end
      end

      # Given an array of activity timeline labels in the UI, returns a hash of event type counts
      # @param labels [Array<String>]
      # @return [Hash]
      def event_drop_counts(labels)
        {
          engage_contrib: activity_type_count(labels, 0),
          interact_contrib: activity_type_count(labels, 1),
          create_contrib: activity_type_count(labels, 2),
          engage_impact: activity_type_count(labels, 3),
          interact_impact: activity_type_count(labels, 4),
          create_impact: activity_type_count(labels, 5)
        }
      end

      # Given the position of an event drop in the HTML, zooms in very close, drags the drop into view, hovers over it,
      # and verifies the content of the tool-tip that appears.
      # @param driver [Selenium::WebDriver]
      # @param user [User]
      # @param asset [Asset] will be nil if the activity is a Canvas discussion
      # @param activity [Activity]
      # @param line_node [Integer]
      def verify_latest_event_drop(driver, user, asset, activity, line_node)
        drag_drop_into_view(driver, line_node, 'last()')
        wait_until(Utils.short_wait) { driver.find_element(xpath: '//div[@class="event-details-container"]//h3') }
        unless asset.nil?
          wait_until(Utils.short_wait, "Expected tooltip asset title '#{asset.title}' but got '#{link_element(xpath: '//div[@class="event-details-container"]//h3/a').text}'") do
            link_element(xpath: '//div[@class="event-details-container"]//h3/a').text == asset.title
          end
        end
        wait_until(Utils.short_wait, "Expected tooltip activity type '#{activity.impact_type}' but got '#{span_element(xpath: '//div[@class="event-details-container"]//p//strong').text}'") do
          span_element(xpath: '//div[@class="event-details-container"]//p//strong').text.include? activity.impact_type
        end
        wait_until(Utils.short_wait, "Expected tooltip user name '#{user.full_name}' but got '#{link_element(xpath: '//div[@class="event-details-container"]//p[2]//a').text}'") do
          link_element(xpath: '//div[@class="event-details-container"]//p[2]//a').text == user.full_name
        end
      end

      # ASSETS

      # Given an array of list view asset link elements in a swim lane, returns the corresponding asset IDs
      # @param link_elements [Array<PageObject::Element::Link>]
      # @return [Array<String>]
      def swim_lane_asset_ids(link_elements)
        # Extract ID from first param in asset link URL
        link_elements.map { |link| link.attribute('href').split('?')[1].split('&')[0][4..-1] }
      end

      # Given an array of asset IDs, returns a maximum of the first four
      # @param ids [Array<String>]
      # @return [Array<String>]
      def max_asset_ids(ids)
        (ids.length > 4) ? ids[0..3] : ids
      end

      # Given an array of assets, returns the four most recent asset IDs
      # @param assets [Array<Asset>]
      # @return [Array<String>]
      def recent_studio_asset_ids(assets)
        max_asset_ids recent_asset_ids(assets)
      end

      # Given an array of assets, returns the asset IDs of the four assets with the highest impact scores
      # @param assets [Array<Asset>]
      # @return [Array<String>]
      def impactful_studio_asset_ids(assets)
        max_asset_ids impactful_asset_ids(assets)
      end

      # Given an array of pinned assets, returns the asset IDs of the first four
      # @param pinned_assets [Array<Asset>]
      # @return [Array<String>]
      def pinned_studio_asset_ids(pinned_assets)
        ids = pinned_assets.map { |a| a.id }
        max_asset_ids ids
      end

      # Adds a link asset to the Asset Library via the Impact Studio
      # @param driver [Selenium::WebDriver]
      # @param asset [Asset]
      def add_site(driver, asset)
        wait_for_update_and_click_js add_site_link_element
        switch_to_canvas_iframe driver
        enter_and_submit_url asset
        asset.id = list_view_asset_ids.first
      end

      # Adds a file asset to the Asset Library via the Impact Studio
      # @param driver [Selenium::WebDriver]
      # @param asset [Asset]
      def add_file(driver, asset)
        wait_for_update_and_click_js upload_link_element
        switch_to_canvas_iframe driver
        enter_and_upload_file asset
        asset.id = list_view_asset_ids.first
      end

      # Given a swim lane filter link element, clicks the element unless it is disabled
      # @param element [PageObject::Elements::Link]
      def click_swim_lane_filter(element)
        element.when_visible Utils.short_wait
        sleep 2
        scroll_to_element element
        js_click(element) unless element.attribute('disabled')
      end

      # Given a set of asset IDs, a 'show more' link element, and the expected asset library sort/filter combination, verifies that
      # it is possible to show more if it should be and that the resulting asset library advanced search options and results are correct
      # @param driver [Selenium::WebDriver]
      # @param expected_asset_ids [Array<String>]
      # @param show_more_element [PageObject::Elements::Link]
      # @param search_filter_blk block that verifies the asset library search filters and results
      def verify_show_more(driver, expected_asset_ids, show_more_element, &search_filter_blk)
        if expected_asset_ids.length > 4
          wait_for_update_and_click_js show_more_element
          switch_to_canvas_iframe driver
          begin
            search_filter_blk
          ensure
            go_back_to_impact_studio driver
          end
        else
          show_more_element.when_not_visible Utils.short_wait rescue Selenium::WebDriver::Error::StaleElementReferenceError
        end
      end

      # USER ASSETS - mine or another user's

      button(:user_recent_link, id: 'user-assets-by-recent')
      link(:user_impactful_link, id: 'user-assets-by-impact')
      button(:user_pinned_link, id: 'user-assets-by-pins')
      link(:user_assets_show_more_link, xpath: '//a[@data-id="user.assets.advancedSearchId"]')
      elements(:user_asset_link, :link, xpath: '//h3[contains(text(),"Assets")]/../following-sibling::div/ul//a')
      div(:no_user_assets_msg, xpath: '//h3[contains(text(),"Assets")]/../following-sibling::div/div[contains(.,"No matching assets were found.")]')

      # Clicks an asset detail link on the user Assets swim lane
      # @param driver [Selenium::WebDriver]
      # @param asset [Asset]
      def click_user_asset_link(driver, asset)
        logger.info "Clicking thumbnail for Asset ID #{asset.id}"
        wait_for_update_and_click_js link_element(xpath: "//h3[contains(.,'Assets')]/../following-sibling::div/ul//a[contains(@href,'_id=#{asset.id}&')]")
        switch_to_canvas_iframe driver
      end

      # Returns the pin button for an asset on the user Assets lane
      # @param asset [Asset]
      # @return [PageObject::Elements::Button]
      def user_assets_pin_element(asset)
        button_element(xpath: "//h3[contains(text(),'Assets')]/../following-sibling::div//button[@id='iconbar-pin-#{asset.id}']")
      end

      # Pins an asset on the user Assets lane
      # @param asset [Asset]
      def pin_user_asset(asset)
        logger.info "Pinning Assets asset ID #{asset.id}"
        change_asset_pinned_state(user_assets_pin_element(asset), 'Pinned')
      end

      # Unpins an asset on the user Assets lane
      # @param asset [Asset]
      def unpin_user_asset(asset)
        logger.info "Unpinning Assets asset ID #{asset.id}"
        change_asset_pinned_state(user_assets_pin_element(asset), 'Pin')
      end

      # Given a set of assets and their owner, verifies that the list of the user's recent assets contains the four most recent asset IDs and that
      # the "show more" option appears if necessary and directs to the right filtered view of the asset library
      # @param driver [Selenium::WebDriver]
      # @param assets [Array<Asset>]
      # @param user [User]
      def verify_user_recent_assets(driver, assets, user)
        recent_studio_ids = recent_studio_asset_ids assets
        all_recent_ids = recent_asset_ids assets
        logger.info "Verifying that user Recent assets are #{recent_studio_ids} on the Impact Studio and #{all_recent_ids} on the Asset Library"
        click_swim_lane_filter user_recent_link_element
        wait_until(Utils.short_wait, "Expected user Recent list to include asset IDs #{recent_studio_ids}, but they were #{swim_lane_asset_ids user_asset_link_elements}") do
          sleep 1
          swim_lane_asset_ids(user_asset_link_elements) == recent_studio_ids
          recent_studio_ids.empty? ? no_user_assets_msg_element.visible? : !no_user_assets_msg_element.exists?
        end
        verify_show_more(driver, recent_studio_ids, user_assets_show_more_link_element) do
          wait_until(Utils.short_wait, "User filter should be #{user.full_name}, but it is currently #{uploader_select}") { uploader_select == user.full_name }
          wait_until(Utils.short_wait, "Sort by filter should be 'Most recent', but it is currently #{sort_by_select}") { sort_by_select == 'Most recent' }
          wait_until(Utils.short_wait, "List view asset IDs should be #{all_recent_ids}, but they are currently #{list_view_asset_ids}") { list_view_asset_ids == recent_asset_ids(assets) }
        end
      end

      # Given a set of assets and their owner, verifies that the list of the user's impactful assets contains the four most impactful asset IDs and that
      # the "show more" option appears if necessary and directs to the right filtered view of the asset library
      # @param driver [Selenium::WebDriver]
      # @param assets [Array<Asset>]
      # @param user [User]
      def verify_user_impactful_assets(driver, assets, user)
        impactful_studio_ids = impactful_studio_asset_ids assets
        all_impactful_ids = impactful_asset_ids assets
        logger.info "Verifying that user Impactful assets are #{impactful_studio_ids} on the Impact Studio and #{all_impactful_ids} on the Asset Library"
        click_swim_lane_filter user_impactful_link_element
        wait_until(Utils.short_wait, "Expected user Impactful list to include asset IDs #{impactful_studio_ids}, but they were #{swim_lane_asset_ids user_asset_link_elements}") do
          sleep 1
          swim_lane_asset_ids(user_asset_link_elements) == impactful_studio_ids
          impactful_studio_ids.empty? ? no_user_assets_msg_element.visible? : !no_user_assets_msg_element.exists?
        end
        verify_show_more(driver, all_impactful_ids, user_assets_show_more_link_element) do
          wait_until(Utils.short_wait, "User filter should be #{user.full_name}, but it is currently #{uploader_select}") { uploader_select == user.full_name }
          wait_until(Utils.short_wait, "Sort by filter should be 'Most impactful', but it is currently #{sort_by_select}") { sort_by_select == 'Most impactful' }
          wait_until(Utils.short_wait, "List view IDs should be '#{all_impactful_ids[0..9]}', but they are currently #{list_view_asset_ids}") { list_view_asset_ids == all_impactful_ids }
        end
      end

      # Given a set of pinned assets and their owner, verifies that the list of the user's pinned assets contains the four most recently pinned asset IDs and that
      # the "show more" option appears if necessary and directs to the right filtered view of the asset library
      # @param driver [Selenium::WebDriver]
      # @param assets [Array<Asset>]
      # @param user [User]
      def verify_user_pinned_assets(driver, assets, user)
        pinned_studio_ids = pinned_studio_asset_ids assets
        all_pinned_ids = pinned_asset_ids assets
        logger.info "Verifying that user Pinned assets are #{pinned_studio_ids} on the Impact Studio and #{all_pinned_ids} on the Asset Library"
        click_swim_lane_filter user_pinned_link_element
        wait_until(Utils.short_wait, "Expected user Pinned list to include asset IDs #{pinned_studio_ids}, but they were #{swim_lane_asset_ids user_asset_link_elements}") do
          sleep 1
          swim_lane_asset_ids(user_asset_link_elements) == pinned_studio_ids
          pinned_studio_ids.empty? ? no_user_assets_msg_element.visible? : !no_user_assets_msg_element.exists?
        end
        verify_show_more(driver, all_pinned_ids, user_assets_show_more_link_element) do
          wait_until(Utils.short_wait, "User filter should be #{user.full_name}, but it is currently #{uploader_select}") { uploader_select == user.full_name }
          wait_until(Utils.short_wait, "Sort by filter should be 'Pinned', but it is currently #{sort_by_select}") { sort_by_select == 'Pinned' }
          wait_until(Utils.short_wait, "List view IDs should be '#{all_pinned_ids[0..9]}', but they are currently #{list_view_asset_ids}") { list_view_asset_ids == all_pinned_ids }
        end
      end

      # EVERYONE'S ASSETS

      h3(:everyone_assets_heading, xpath: '//h3[contains(text(),"Everyone\'s Assets:")]')
      button(:everyone_recent_link, id: 'community-assets-by-recent')
      button(:trending_link, id: 'community-assets-by-trending')
      button(:everyone_impactful_link, id: 'community-assets-by-impact')
      div(:no_everyone_assets_msg, xpath: '//h3[contains(text(),"Everyone\'s Assets")]/../following-sibling::div/div[contains(.,"No matching assets were found.")]')
      elements(:everyone_asset_link, :link, xpath: '//h3[contains(text(),"Everyone\'s Assets")]/../following-sibling::div/ul//a')
      link(:everyone_assets_show_more_link, xpath: '//a[@data-id="community.assets.advancedSearchId"]')

      # Returns the pin button for an asset on the Everyone's Assets lane
      # @param asset [Asset]
      # @return [PageObject::Elements::Button]
      def everyone_assets_pin_element(asset)
        button_element(xpath: "//h3[contains(text(), 'Everyone')]/../following-sibling::div//button[@id='iconbar-pin-#{asset.id}']")
      end

      # Pins an asset on the Everyone's Assets lane
      # @param asset [Asset]
      def pin_everyone_asset(asset)
        logger.info "Pinning Everyone's Assets asset ID #{asset.id}"
        change_asset_pinned_state(everyone_assets_pin_element(asset), 'Pinned')
      end

      # Unpins an asset on the Everyone's Assets lane
      # @param asset [Asset]
      def unpin_everyone_asset(asset)
        logger.info "Unpinning Everyone's Assets asset ID #{asset.id}"
        change_asset_pinned_state(everyone_assets_pin_element(asset), 'Pin')
      end

      # Given a set of assets, verifies that the list of everyone's recent assets contains the four most recent asset IDs and that
      # the "show more" option appears if necessary and directs to the right filtered view of the asset library
      # @param driver [Selenium::WebDriver]
      # @param assets [Array<Asset>]
      def verify_all_recent_assets(driver, assets)
        recent_studio_ids = recent_studio_asset_ids assets
        all_recent_ids = recent_asset_ids assets
        logger.info "Verifying that Everyone's Recent assets are #{recent_studio_ids} on the Impact Studio and #{all_recent_ids} on the Asset Library"
        click_swim_lane_filter everyone_recent_link_element
        wait_until(Utils.short_wait, "Expected Everyone's Recent list to include asset IDs #{recent_studio_ids}, but they were #{swim_lane_asset_ids everyone_asset_link_elements}") do
          sleep 1
          swim_lane_asset_ids(everyone_asset_link_elements) == recent_studio_ids
          recent_studio_ids.empty? ? no_everyone_assets_msg_element.visible? : !no_everyone_assets_msg_element.exists?
        end
        verify_show_more(driver, all_recent_ids, everyone_assets_show_more_link_element) do
          wait_until(Utils.short_wait, 'Gave up waiting for advanced search button') { advanced_search_button_element.when_visible Utils.short_wait }
          wait_until(Utils.short_wait, "List view IDs should be '#{all_recent_ids[0..9]}', but they are currently #{list_view_asset_ids}") { list_view_asset_ids == recent_asset_ids(assets)[0..9] }
        end
      end

      # Given a set of assets, verifies that the list of everyone's impactful assets contains the four most impactful asset IDs and that
      # the "show more" option appears if necessary and directs to the right filtered view of the asset library
      # @param driver [Selenium::WebDriver]
      # @param assets [Array<Asset>]
      def verify_all_impactful_assets(driver, assets)
        impactful_studio_ids = impactful_studio_asset_ids assets
        all_impactful_ids = impactful_asset_ids assets
        logger.info "Verifying that Everyone's Impactful assets are #{impactful_studio_ids} on the Impact Studio and #{all_impactful_ids} on the Asset Library"
        click_swim_lane_filter everyone_impactful_link_element
        wait_until(Utils.short_wait, "Expected Everyone's Impactful list to include asset IDs #{impactful_studio_ids}, but they were #{swim_lane_asset_ids everyone_asset_link_elements}") do
          sleep 1
          swim_lane_asset_ids(everyone_asset_link_elements) == impactful_studio_ids
          impactful_studio_ids.empty? ? no_everyone_assets_msg_element.visible? : !no_everyone_assets_msg_element.exists?
        end
        verify_show_more(driver, all_impactful_ids, everyone_assets_show_more_link_element) do
          wait_until(Utils.short_wait, "User filter should be 'User', but it is currently #{uploader_select}") { uploader_select == 'User' }
          wait_until(Utils.short_wait, "Sort by filter should be 'Most impactful', but it is currently #{sort_by_select}") { sort_by_select == 'Most impactful' }
          wait_until(Utils.short_wait, "List view IDs should be '#{impactful_asset_ids(assets)[0..9]}', but they are currently #{list_view_asset_ids}") { list_view_asset_ids == all_impactful_ids[0..9] }
        end
      end

    end
  end
end
