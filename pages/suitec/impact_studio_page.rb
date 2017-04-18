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
      span(:last_activity, xpath: '//div[contains(.,"Last activity:")]/span')
      link(:engagement_index_link, xpath: '//a[contains(.,"Engagement Index")]')
      link(:turn_on_sharing_link, text: 'Turn on?')
      div(:engagement_index_score, class: 'profile-engagement-score')
      span(:engagement_index_rank, xpath: '//span[@data-ng-bind="userRank"]')
      span(:engagement_index_rank_ttl, xpath: '//span[@data-ng-bind="courseUserCount"]')

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

      # MY ASSETS

      link(:recent_link, xpath: '//span[text()="My Assets:"]/following-sibling::a[text()="Recent"]')
      link(:impactful_link, xpath: '//span[text()="My Assets:"]/following-sibling::a[text()="Most Impactful"]')
      div(:no_my_assets_msg, xpath: '//h3[contains(.,"My Assets")]/following-sibling::div/div[contains(.,"No matching assets were found.")]')
      elements(:my_asset_link, :link, xpath: '//h3[contains(.,"My Assets")]/following-sibling::div//li/a')

      link(:trending_link, xpath: '//span[text()="Everyone\'s Assets:"]/following-sibling::a[text()="Trending"]')
      link(:discussed_link, xpath: '//span[text()="Everyone\'s Assets:"]/following-sibling::a[text()="Most Discussed"]')
      link(:liked_link, xpath: '//span[text()="Everyone\'s Assets:"]/following-sibling::a[text()="Most Liked"]')
      link(:pinned_link, xpath: '//span[text()="Everyone\'s Assets:"]/following-sibling::a[text()="Pinned"]')
      div(:no_everyone_assets_msg, xpath: '//h3[contains(.,"Everyone\'s Assets")]/following-sibling::div/div[contains(.,"No matching assets were found.")]')
      elements(:everyone_asset_link, :link, xpath: '//h3[contains(.,"Everyone\'s Assets")]/following-sibling::div//li/a')

      # Given an array of list view asset link elements in a swim lane, returns the corresponding asset IDs
      # @param link_elements [Array<PageObject::Element::Link>]
      # @return [Array<String>]
      def swim_lane_asset_ids(link_elements)
        # Extract ID from first param in asset link URL
        link_elements.map { |link| link.attribute('href').split('?')[1].split('&')[0][4..-1] }
      end

    end
  end
end
