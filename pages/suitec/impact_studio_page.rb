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

      # Clicks the 'Update Profile' button for a profile edit
      def save_profile_edit
        wait_for_update_and_click update_profile_button_element
      end

      # Edits and saves a profile description
      # @param desc [String]
      def edit_profile(desc)
        logger.info "Adding user description '#{desc}'"
        click_edit_profile
        enter_profile_desc desc
        save_profile_edit
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

      # Searches for a given user and loads its Impact Studio profile page
      # @param user [User]
      def search_for_user(user)
        logger.info "Searching for #{user.full_name} UID #{user.uid}"
        wait_for_load_and_click text_area_element(xpath: '//input[@placeholder="Search for other people"]')
        (option = list_item_element(xpath: "//div[contains(@class,'select-dropdown')]//li[contains(.,'#{user.full_name}')]")).when_present Utils.short_wait
        js_click option
        wait_until(Utils.medium_wait) { name == user.full_name }
      end

      # ACTIVITY EVENT DROPS

      element(:my_activity_event_drops, xpath: '//h3[contains(.,"My Activity")]/following-sibling::div[@class="col-flex"]//*[local-name()="svg"]')
      element(:activity_event_drops, xpath: '//h3[contains(.,"Activity")]/following-sibling::div[@class="col-flex"]//*[name()="svg"]')

      # Returns a hash of event type counts on the My Activity event drops
      # @param driver [Selenium::WebDriver]
      # @return [Hash]
      def my_activity_event_counts(driver)
        # Pause a couple times to allow a complete DOM update
        sleep 1
        my_activity_event_drops_element.when_visible Utils.short_wait
        sleep 1
        elements = driver.find_elements(xpath: '//h3[contains(.,"My Activity")]/following-sibling::div[@class="col-flex"]//*[local-name()="svg"]/*[name()="g"]/*[name()="text"]')
        labels = elements.map &:text
        event_drop_counts labels
      end

      # Returns the activity labels on the My Classmates event drops
      # @param driver [Selenium::WebDriver]
      # @return [Array<String>]
      def activity_event_counts(driver)
        # Pause a couple times to allow a complete DOM update
        sleep 1
        activity_event_drops_element.when_visible Utils.short_wait
        sleep 1
        elements = driver.find_elements(xpath: '//h3[contains(.,"Activity")]/following-sibling::div[@class="col-flex"]//*[local-name()="svg"]/*[name()="g"]/*[name()="text"]')
        labels = elements.map &:text
        event_drop_counts labels
      end

      # Determines the count of drops from the activity type label
      # @param labels [Array<String>]
      # @param index [Integer]
      # @return [Integer]
      def activity_type_count(labels, index)
        ((type = labels[index]).include? ' (') ? type.split(' ')[1].delete('()').to_i : 0
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

      # ASSETS

      # Given an array of list view asset link elements in a swim lane, returns the corresponding asset IDs
      # @param link_elements [Array<PageObject::Element::Link>]
      # @return [Array<String>]
      def swim_lane_asset_ids(link_elements)
        # Extract ID from first param in asset link URL
        link_elements.map { |link| link.attribute('href').split('?')[1].split('&')[0][4..-1] }
      end

      # Given an array of assets, returns the four most recent asset IDs
      # @param assets [Array<Asset>]
      # @return [Array<String>]
      def recent_studio_asset_ids(assets)
        ids = recent_asset_ids assets
        (ids.length > 4) ? ids[0..3] : ids
      end

      # Given an array of assets, returns the asset IDs of the four assets with the highest impact scores
      # @param assets [Array<Asset>]
      # @return [Array<String>]
      def impactful_studio_asset_ids(assets)
        ids = impactful_asset_ids assets
        (ids.length > 4) ? ids[0..3] : ids
      end

      def trending_asset_ids(assets)
        # TODO
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

      # MY ASSETS

      h3(:my_assets_heading, xpath: '//h3[contains(text(),"My Assets")]')
      button(:my_recent_link, id: 'user-assets-filter-by-recent')
      button(:my_impactful_link, id: 'user-assets-filter-by-impact')
      div(:no_my_assets_msg, xpath: '//h3[contains(text(),"My Assets")]/../following-sibling::div/div[contains(.,"No matching assets were found.")]')
      elements(:my_asset_link, :link, xpath: '//h3[contains(text(),"My Assets")]/../following-sibling::div/ul//a')

      # Clicks the My Assets swim lane link for My Recent assets
      def click_my_recent
        wait_for_update_and_click_js my_recent_link_element
      end

      # Clicks the My Assets swim lane link for My Impactful assets
      def click_my_most_impactful
        wait_for_update_and_click_js my_impactful_link_element
      end

      # Clicks an asset detail link on the My Assets swim lane
      # @param driver [Selenium::WebDriver]
      # @param asset [Asset]
      def click_my_asset_link(driver, asset)
        logger.info "Clicking thumbnail for My Asset ID #{asset.id}"
        wait_for_update_and_click_js link_element(xpath: "//h3[contains(.,'My Assets')]/../following-sibling::div/ul//a[contains(@href,'_id=#{asset.id}&')]")
        switch_to_canvas_iframe driver
      end

      # Given an array of assets, waits until the list of My Recent Assets contains the four most recent asset IDs
      # @param assets [Array<Asset>]
      def verify_my_recent_assets(assets)
        logger.debug "Expecting My Recent list to include asset IDs '#{recent_studio_asset_ids assets}'"
        scroll_to_bottom
        click_my_recent unless my_recent_link_element.attribute('disabled')
        sleep 2
        logger.debug "My Recent list currently includes asset IDs '#{swim_lane_asset_ids my_asset_link_elements}'"
        wait_until(Utils.short_wait) { swim_lane_asset_ids(my_asset_link_elements) == recent_studio_asset_ids(assets) }
        no_my_assets_msg_element.when_visible 1 if recent_studio_asset_ids(assets).empty?
      end

      # Given an array of assets, waits until the list of My Impactful Assets contains the four most impactful asset IDs
      # @param assets [Array<Asset>]
      def verify_my_impactful_assets(assets)
        logger.debug "Expecting My Impactful list to include asset IDs '#{impactful_studio_asset_ids assets}'"
        scroll_to_bottom
        click_my_most_impactful unless my_impactful_link_element.attribute('disabled')
        sleep 2
        logger.debug "My Impactful list currently includes asset IDs '#{swim_lane_asset_ids my_asset_link_elements}'"
        wait_until(Utils.short_wait) { swim_lane_asset_ids(my_asset_link_elements) == impactful_studio_asset_ids(assets) }
        no_my_assets_msg_element.when_visible 1 if impactful_studio_asset_ids(assets).empty?
      end

      # YOUR ASSETS

      h3(:assets_heading, xpath: '//h3[contains(text(),"Assets")]')
      link(:recent_link, id: 'user-assets-filter-by-recent')
      link(:impactful_link, id: 'user-assets-filter-by-impact')
      div(:no_assets_msg, xpath: '//h3[contains(text(),"Assets")]/../following-sibling::div/div[contains(.,"No matching assets were found.")]')
      elements(:asset_link, :link, xpath: '//h3[contains(text(),"Assets")]/../following-sibling::div/ul//a')

      # Clicks the Recent swim lane link when viewing another user's profile
      def click_your_recent
        wait_for_update_and_click_js recent_link_element
      end

      # Clicks the Impactful swim lane link when viewing another user's profile
      def click_your_impactful
        wait_for_update_and_click_js impactful_link_element
      end

      # Given an array of assets, waits until the list of another user's Recent Assets contains the four most recent asset IDs
      # @param assets [Array<Asset>]
      def verify_your_recent_assets(assets)
        logger.debug "Expecting the other user's Recent list to include asset IDs '#{recent_studio_asset_ids assets}"
        scroll_to_bottom
        click_your_recent unless recent_link_element.attribute('disabled')
        sleep 2
        logger.debug "The other user's Recent list currently includes asset IDs '#{swim_lane_asset_ids asset_link_elements}"
        wait_until(Utils.short_wait) { swim_lane_asset_ids(asset_link_elements) == recent_studio_asset_ids(assets) }
        no_assets_msg_element.when_visible 1 if recent_studio_asset_ids(assets).empty?
      end

      # Given an array of assets, waits until the list of another user's Impactful Assets contains the four most impactful asset IDs
      # @param assets [Array<Asset>]
      def verify_your_impactful_assets(assets)
        logger.debug "Expecting the other user's Impactful list to include asset IDs '#{impactful_studio_asset_ids assets}"
        scroll_to_bottom
        click_your_impactful unless impactful_link_element.attribute('disabled')
        sleep 2
        logger.debug "The other user's Impactful list currently includes asset Ids '#{swim_lane_asset_ids asset_link_elements}"
        wait_until(Utils.short_wait) { swim_lane_asset_ids(asset_link_elements) == impactful_studio_asset_ids(assets) }
        no_assets_msg_element.when_visible 1 if impactful_studio_asset_ids(assets).empty?
      end

      # EVERYONE'S ASSETS

      h3(:everyone_assets_heading, xpath: '//h3[contains(text(),"Everyone\'s Assets:")]')
      button(:trending_link, id: 'community-assets-filter-by-recent')
      button(:everyone_impactful_link, id: 'community-assets-filter-by-impact')
      div(:no_everyone_assets_msg, xpath: '//h3[contains(text(),"Everyone\'s Assets")]/../following-sibling::div/div[contains(.,"No matching assets were found.")]')
      elements(:everyone_asset_link, :link, xpath: '//h3[contains(text(),"Everyone\'s Assets")]/../following-sibling::div/ul//a')

      # Clicks the Everyone's Assets swim lane link for Trending assets
      def click_all_trending
        wait_for_update_and_click_js trending_link_element
      end

      # Clicks the Everyone's Assets swim lane link for Impactful assets
      def click_all_impactful
        wait_for_update_and_click_js everyone_impactful_link_element
      end

      # Clicks an asset detail link on the Everyone's Assets swim lane
      # @param driver [Selenium::WebDriver]
      # @param asset [Asset]
      def click_everyone_asset_link(driver, asset)
        logger.info "Clicking thumbnail for Everyone's Asset ID #{asset.id}"
        wait_for_update_and_click_js link_element(xpath: "//h3[contains(.,'Everyone's Assets')]/../following-sibling::div/ul//a[contains(@href,'_id=#{asset.id}&')]")
        switch_to_canvas_iframe driver
      end

      # Given an array of assets, waits until the list of everyone's Trending assets contains the four most impactful recent asset IDs
      # @param assets [Array<Asset>]
      def verify_all_trending_assets(assets)
        # TODO - insert a pause prior to loading the trending assets so that "trending" can be recalculated
        logger.debug "Expecting Everyone's Trending list to include asset IDs '#{impactful_studio_asset_ids assets}"
        scroll_to_bottom
        click_all_trending unless trending_link_element.attribute('disabled')
        sleep 2
        logger.debug "Everyone's Trending list currently includes asset IDs '#{swim_lane_asset_ids everyone_asset_link_elements}"
        wait_until(Utils.short_wait) { swim_lane_asset_ids(everyone_asset_link_elements) == impactful_studio_asset_ids(assets) }
        no_everyone_assets_msg_element.when_visible 1 if impactful_studio_asset_ids(assets).empty?
      end

      # Given an array of assets, waits until the list of everyone's Impactful assets contains the four most impactful asset IDs
      # @param assets [Array<Asset>]
      def verify_all_impactful_assets(assets)
        logger.debug "Expecting Everyone's Impactful list to include asset IDs '#{impactful_studio_asset_ids assets}'"
        scroll_to_bottom
        click_all_impactful unless everyone_impactful_link_element.attribute('disabled')
        sleep 2
        logger.debug "Everyone's Impactful list currently includes asset IDs '#{swim_lane_asset_ids everyone_asset_link_elements}"
        wait_until(Utils.short_wait) { swim_lane_asset_ids(everyone_asset_link_elements) == impactful_studio_asset_ids(assets) }
        no_everyone_assets_msg_element.when_visible 1 if impactful_studio_asset_ids(assets).empty?
      end

    end
  end
end
