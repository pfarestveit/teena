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
      link(:edit_profile_link, text: 'Edit Profile')
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
        wait_for_load_and_click div_element(class: 'select-search')
        (option = list_item_element(xpath: "//div[@class='select-dropdown']//li[contains(.,'#{user.full_name}')]")).when_present Utils.short_wait
        option.click
        wait_until(Utils.medium_wait) { name == user.full_name }
      end

      # ACTIVITY EVENT DROPS

      element(:my_activity_event_drops, xpath: "//h3[contains(.,'My Activity')]/following-sibling::div/*[local-name()='svg']")
      element(:my_classmates_event_drops, xpath: "//h3[contains(.,'My Classmates')]/following-sibling::div/*[local-name()='svg']")

      # Returns the activity labels on the My Activity event drops
      # @param driver [Selenium::WebDriver]
      # @return [Array<String>]
      def my_activity_events(driver)
        elements = driver.find_elements(xpath: '//h3[contains(.,"My Activity")]/following-sibling::div/*[name()="svg"]/*[name()="g"]/*[name()="text"]')
        elements.map &:text
      end

      # Returns the activity labels on the My Classmates event drops
      # @param driver [Selenium::WebDriver]
      # @return [Array<String>]
      def my_classmates_events(driver)
        elements = driver.find_elements(xpath: '//h3[contains(.,"My Classmates")]/following-sibling::div/*[name()="svg"]/*[name()="g"]/*[name()="text"]')
        elements.map &:text
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

      h3(:my_assets_heading, xpath: '//span[text()="My Assets:"]/../..')
      link(:my_recent_link, xpath: '//span[text()="My Assets:"]/following-sibling::span[1]/a[contains(.,"Recent")]')
      link(:my_impactful_link, xpath: '//span[text()="My Assets:"]/following-sibling::span[2]/a[contains(.,"Most Impactful")]')
      link(:my_pinned_link, xpath: '//span[text()="My Assets:"]/following-sibling::span[3]/a[contains(.,"Pinned")]')
      div(:no_my_assets_msg, xpath: '//span[text()="My Assets"]/../following-sibling::div/div[contains(.,"No matching assets were found.")]')
      elements(:my_asset_link, :link, xpath: '//span[text()="My Assets:"]/../../following-sibling::div//li/a')

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
        wait_for_update_and_click_js link_element(xpath: "//h3[contains(.,'My Assets')]/following-sibling::div//li/a[contains(@href,'_id=#{asset.id}&')]")
        switch_to_canvas_iframe driver
      end

      # Given an array of assets, waits until the list of My Recent Assets contains the four most recent asset IDs
      # @param assets [Array<Asset>]
      def verify_my_recent_assets(assets)
        logger.debug "Expecting My Recent list to include asset IDs '#{recent_studio_asset_ids assets}'"
        scroll_to_bottom
        click_my_recent if my_recent_link?
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
        click_my_most_impactful if my_impactful_link?
        sleep 2
        logger.debug "My Impactful list currently includes asset IDs '#{swim_lane_asset_ids my_asset_link_elements}'"
        wait_until(Utils.short_wait) { swim_lane_asset_ids(my_asset_link_elements) == impactful_studio_asset_ids(assets) }
        no_my_assets_msg_element.when_visible 1 if impactful_studio_asset_ids(assets).empty?
      end

      # YOUR ASSETS

      h3(:assets_heading, xpath: '//span[text()="Assets:"]/../..')
      link(:recent_link, xpath: '//span[text()="Assets:"]/following-sibling::span[1]/a[contains(.,"Recent")]')
      link(:impactful_link, xpath: '//span[text()="Assets:"]/following-sibling::span[2]/a[contains(.,"Most Impactful")]')
      div(:no_assets_msg, xpath: '//span[text()="Assets"]/../following-sibling::div/div[contains(.,"No matching assets were found.")]')
      elements(:asset_link, :link, xpath: '//span[text()="Assets:"]/../../following-sibling::div//li/a')

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
        click_your_recent if recent_link?
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
        click_your_impactful if impactful_link?
        sleep 2
        logger.debug "The other user's Impactful list currently includes asset Ids '#{swim_lane_asset_ids asset_link_elements}"
        wait_until(Utils.short_wait) { swim_lane_asset_ids(asset_link_elements) == impactful_studio_asset_ids(assets) }
        no_assets_msg_element.when_visible 1 if impactful_studio_asset_ids(assets).empty?
      end

      # EVERYONE'S ASSETS

      h3(:everyone_assets_heading, xpath: '//div[contains(text(),"Everyone\'s Assets:")]')
      link(:trending_link, xpath: '//div[contains(text(),"Everyone\'s Assets:")]//a[contains(.,"Trending")]')
      link(:everyone_impactful_link, xpath: '//div[contains(text(),"Everyone\'s Assets:")]//a[contains(.,"Most Impactful")]')
      div(:no_everyone_assets_msg, xpath: '//span[text()="Everyone\'s Assets"]/../following-sibling::div/div[contains(.,"No matching assets were found.")]')
      elements(:everyone_asset_link, :link, xpath: '//div[contains(text(),"Everyone\'s Assets:")]/../following-sibling::div//li/a')

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
        wait_for_update_and_click_js link_element(xpath: "//h3[contains(.,'Everyone's Assets')]/following-sibling::div//li/a[contains(@href,'_id=#{asset.id}&')]")
        switch_to_canvas_iframe driver
      end

      # Given an array of assets, waits until the list of everyone's Trending assets contains the four most impactful recent asset IDs
      # @param assets [Array<Asset>]
      def verify_all_trending_assets(assets)
        # TODO - insert a pause prior to loading the trending assets so that "trending" can be recalculated
        logger.debug "Expecting Everyone's Trending list to include asset IDs '#{impactful_studio_asset_ids assets}"
        scroll_to_bottom
        click_all_trending if trending_link?
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
        click_all_impactful if everyone_impactful_link?
        sleep 2
        logger.debug "Everyone's Impactful list currently includes asset IDs '#{swim_lane_asset_ids everyone_asset_link_elements}"
        wait_until(Utils.short_wait) { swim_lane_asset_ids(everyone_asset_link_elements) == impactful_studio_asset_ids(assets) }
        no_everyone_assets_msg_element.when_visible 1 if impactful_studio_asset_ids(assets).empty?
      end

    end
  end
end
