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
        activity_event_drops_element.when_visible Utils.medium_wait rescue Selenium::WebDriver::Error::StaleElementReferenceError
      end

      # IDENTITY

      image(:avatar, class: 'profile-summary-avatar')
      h1(:name, xpath: '//h1[@data-ng-bind="user.canvas_full_name"]')
      div(:profile_desc, class: 'profile-user-description')
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
      span(:engagement_index_rank_ttl, xpath: '//span[@data-ng-bind="leaderboardCount"]')

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

      text_area(:search_input, xpath: '//input[@placeholder="Search for other people"]')
      button(:browse_previous, xpath: '//button[@data-ng-if="browse.previous"]')
      button(:browse_next, xpath: '//button[@data-ng-if="browse.next"]')

      # Searches for a given user and loads its Impact Studio profile page. Makes two attempts since sometimes the first click does not
      # trigger the select options.
      # @param user [User]
      def search_for_user(user)
        logger.info "Searching for #{user.full_name} UID #{user.uid}"
        tries ||= 2
        begin
          wait_for_load_and_click name_element
          wait_for_update_and_click search_input_element
          (option = list_item_element(xpath: "//div[contains(@class,'select-dropdown')]//li[contains(.,'#{user.full_name}')]")).when_present Utils.short_wait
          js_click option
          wait_until(Utils.medium_wait) { name == user.full_name }
        rescue
          (tries -= 1).zero? ? fail : retry
        end
      end

      # Given a user who should be next on profile pagination, clicks the next button and waits for that user's profile to load
      # @param user [User]
      def browse_next_user(user)
        logger.info "Browsing for next user #{user.full_name}"
        wait_until(1) { browse_next_element.text == user.full_name }
        browse_next
        wait_until(Utils.short_wait) { name == user.full_name }
      end

      # Given a user who should be previous on profile pagination, clicks the previous button and waits for that user's profile to load
      # @param user [User]
      def browse_previous_user(user)
        logger.info "Browsing for previous user #{user.full_name}"
        wait_until(1) { browse_previous_element.text == user.full_name }
        browse_previous
        wait_until(Utils.short_wait) { name == user.full_name }
      end

      # ACTIVITY

      # Initializes a hash of all a user's activities.  Key is the activity type and value is both the activity label shown on the activity bars and a zero count
      # @return [Hash]
      def init_user_activities
        (Activity::ACTIVITIES.map { |a| [a.type.to_sym, {type: a.impact_type_bar, count: 0}] }).to_h
      end

      # Given a hash of user activities and an array of Activities of a certain type (i.e., contributions vs impacts), returns a new hash containing
      # only that type of the user's activities
      # @param user_activities [Hash]
      # @param eligible_activities [Array<Activity>]
      # @return [Hash]
      def activities_by_type(user_activities, eligible_activities)
        types = eligible_activities.map { |a| a.type }
        user_activities.select { |k, _| types.include? k.to_s }
      end

      # Given a hash of user activities, returns a hash of those considered 'contributions'
      # @param user_activities [Hash]
      # @return [Hash]
      def contrib_activities(user_activities)
        contrib_activities = [Activity::VIEW_ASSET, Activity::LIKE, Activity::COMMENT, Activity::ADD_DISCUSSION_TOPIC, Activity::ADD_DISCUSSION_ENTRY, Activity::PIN_ASSET,
                              Activity::ADD_ASSET_TO_LIBRARY, Activity::EXPORT_WHITEBOARD, Activity::ADD_ASSET_TO_WHITEBOARD, Activity::REMIX_WHITEBOARD]
        activities_by_type(user_activities, contrib_activities)
      end

      # Given a hash of activities, returns a hash of those considered 'impactful'
      # @param user_activities [Hash]
      # @return [Hash]
      def impact_activities(user_activities)
        impact_activities = [Activity::GET_VIEW_ASSET, Activity::GET_LIKE, Activity::GET_COMMENT, Activity::GET_DISCUSSION_REPLY, Activity::GET_PIN_ASSET,
                             Activity::GET_REMIX_WHITEBOARD, Activity::GET_ADD_ASSET_TO_WHITEBOARD]
        activities_by_type(user_activities, impact_activities)
      end

      # ACTIVITY EVENT DROPS

      element(:activity_event_drops, xpath: '//h3[contains(.,"Activity Timeline")]/following-sibling::div[@class="col-flex"]//*[name()="svg"]')

      # Given a user activity hash, returns a hash with the activity counts that should appear on the six user event drops lines.
      # @param user_activity_count [Hash]
      # @return [Hash]
      def expected_event_drop_count(user_activity_count)
        event_drop_counts = {
          engage_contrib: (user_activity_count[:view_asset][:count] + user_activity_count[:like][:count]),
          interact_contrib: (user_activity_count[:comment][:count] + user_activity_count[:discussion_topic][:count] + user_activity_count[:discussion_entry][:count] + user_activity_count[:pin_asset][:count]),
          create_contrib: (user_activity_count[:add_asset][:count] + user_activity_count[:export_whiteboard][:count] + user_activity_count[:whiteboard_add_asset][:count] + user_activity_count[:remix_whiteboard][:count]),
          engage_impact: (user_activity_count[:get_view_asset][:count] + user_activity_count[:get_like][:count]),
          interact_impact: (user_activity_count[:get_comment][:count] + user_activity_count[:get_discussion_entry_reply][:count] + user_activity_count[:get_pin_asset][:count]),
          create_impact: (user_activity_count[:get_remix_whiteboard][:count] + user_activity_count[:get_whiteboard_add_asset][:count])
        }
        logger.debug "Expected user event drop counts are #{event_drop_counts}"
        event_drop_counts
      end

      # Returns the activity labels on the user event drops
      # @param driver [Selenium::WebDriver]
      # @return [Array<String>]
      def visible_event_drop_count(driver)
        # Pause a couple times to allow a complete DOM update
        sleep 2
        activity_event_drops_element.when_visible Utils.short_wait
        sleep 1
        elements = driver.find_elements(xpath: '//h3[contains(.,"Activity Timeline")]/following-sibling::div[@class="col-flex"]//*[local-name()="svg"]/*[name()="g"]/*[name()="text"]')
        labels = elements.map &:text
        event_drop_counts = {
          engage_contrib: activity_type_count(labels, 0),
          interact_contrib: activity_type_count(labels, 1),
          create_contrib: activity_type_count(labels, 2),
          engage_impact: activity_type_count(labels, 3),
          interact_impact: activity_type_count(labels, 4),
          create_impact: activity_type_count(labels, 5)
        }
        logger.debug "Visible user event drop counts are #{event_drop_counts}"
        event_drop_counts
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
          wait_until(3) { visible_event_drop_count(driver) == expected_event_count }
        rescue
          if (tries -= 1).zero?
            fail
          else
            sleep Utils.short_wait
            retry
          end
        end
      end

      # Given the position of an event drop in the HTML, zooms in very close, drags the drop into view, hovers over it,
      # and verifies the content of the tool-tip that appears.
      # @param driver [Selenium::WebDriver]
      # @param user [User]
      # @param asset [Asset] will be nil if the activity is a Canvas discussion
      # @param activity [Activity]
      # @param line_node [Integer]
      def verify_latest_event_drop(driver, user, asset, activity, line_node)
        drag_latest_drop_into_view(driver, line_node)
        wait_until(Utils.short_wait) { driver.find_element(xpath: '//div[@class="details-popover-container"]//h3') }
        unless asset.nil?
          wait_until(Utils.short_wait, "Expected tooltip asset title '#{asset.title}' but got '#{link_element(xpath: '//div[@class="details-popover-container"]//h3/a').text}'") do
            link_element(xpath: '//div[@class="details-popover-container"]//h3/a').text == asset.title
          end
        end
        wait_until(Utils.short_wait, "Expected tooltip activity type '#{activity.impact_type_drop}' but got '#{span_element(xpath: '//div[@class="details-popover-container"]//p/span/span').text}'") do
          span_element(xpath: '//div[@class="details-popover-container"]//p//span').text.include? activity.impact_type_drop
        end
        wait_until(Utils.short_wait, "Expected tooltip user name '#{user.full_name}' but got '#{link_element(xpath: '//div[@class="details-popover-container"]//p//a').text}'") do
          link_element(xpath: '//div[@class="details-popover-container"]//p//a').text == user.full_name
        end
      end

      # ACTIVITY BARS

      # The activity bar combines certain activities into a single segment of the bar and sums their activity counts.
      # Given a hash of user activities, returns a new hash that combines those with the same activity bar label into one with a summed activity count
      # @param user_activities [Hash]
      # @return [Hash]
      def user_bar_activities(user_activities)
        # Convert activities hash to array of hashes, keeping only the activity 'type' and 'count' portion of each
        activity_type_and_count = user_activities.to_a.map { |a| a[1] }
        # Create a new array with each 'type' and 'count' hash converted to its own array
        activity_type_and_count_to_a = activity_type_and_count.map { |item| [item[:type], item[:count]] if item }
        # Convert the array back into a hash with identical types combined and their counts summed
        activity_type_and_count_to_a.each_with_object(Hash.new(0)) { |(type, count), h| h[type] += count }
      end

      # Used to check 'Everyone' activity bars. Given an array of user activity hashes, converts them into hashes containing only
      # the data shown on the activity bars. Merges them into one hash with activity counts summed. Activities with zero counts
      # are removed, and the sums are converted to rounded averages for all users enrolled in the course.
      # @param users_activities [Array<Hash>]
      # @param users [Array<User>]
      # @return [Hash]
      def everyone_bar_activities(users_activities, users)
        bar_data = users_activities.map { |a| user_bar_activities a }
        # Merge the user activities, combining the count of each
        summed_bar_data = bar_data.inject do |a, b|
          a.merge(b) { |_, x, y| x + y if x.instance_of? Fixnum }
        end
        # Toss out activities with zero count
        non_zero_bar_data = summed_bar_data.select { |_, v| !v.zero? }
        # Average the activity counts
        non_zero_bar_data.each_with_object({}) do |(k,v), h|
          avg = (v.to_f / users.length)
          h[k] = (avg.round == 0) ? 1 : avg.round
        end
      end

      # Returns the button element for the 'Contributions' activity bar filter
      # @return [PageObject::Elements::Button]
      def contribs_filter_button
        button_element(id: 'total-activities-by-contributions')
      end

      # Returns the button element for the 'Impacts' activity bar filter
      # @return [PageObject::Elements::Button]
      def impacts_filter_button
        button_element(id: 'total-activities-by-impacts')
      end

      # Given a filter button element, makes sure the activity bars are filtered correctly
      # @param button [PageObject::Elements::Button]
      def filter_activity_bar(button)
        if button.exists?
          logger.debug 'Clicking activity filter'
          scroll_to_element button
          js_click button unless button.attribute('disabled')
        end
      end

      # Given the activity bar's label, returns the element containing the 'no activity' message
      # @param bar_label [String]
      def no_activity_msg_element(bar_label)
        div_element(xpath: "//div[contains(@class,'profile-activity-breakdown-label')][contains(text(),'#{bar_label}')]/following-sibling::div[contains(.,'Currently no')]")
      end

      # Given the activity bar's label, returns the elements containing the various activity types
      # @param driver [Selenium::WebDriver]
      # @param bar_label [String]
      # @return [Array<Selenium::WebDriver::Element>]
      def activity_bar_elements(driver, bar_label)
        driver.find_elements(xpath: "//div[contains(@class,'profile-activity-breakdown-label')][contains(text(),'#{bar_label}')]/following-sibling::div/div[@data-ng-repeat='segment in segments']")
      end

      # Given the activity bar's label, returns the text shown on each segment of the bar
      # @param driver [Selenium::WebDriver]
      # @param bar_label [String]
      # @return [Array<String>]
      def visible_bar_activity(driver, bar_label)
        activity_bar_elements(driver, bar_label).map &:text
      end

      # Given the activity bar's label and a user's or users' bar activities, verifies that the bar activities match those shown in the UI
      # @param driver [Selenium::WebDriver]
      # @param bar_activities [Hash]
      # @param bar_label [String]
      def verify_activity_bar(driver, bar_activities, bar_label)
        if bar_activities.any?
          scroll_to_element activity_bar_elements(driver, bar_label).first
          # Check the visible activity on the bar
          expected_bar_activity_desc = bar_activities.map { |k, _| k.to_s }
          wait_until(Utils.short_wait, "Expected '#{expected_bar_activity_desc}' but got '#{visible_bar_activity(driver, bar_label)}'") do
            logger.debug "Waiting for '#{bar_label}' '#{expected_bar_activity_desc}', and they are currently '#{visible_bar_activity(driver, bar_label)}'"
            expected_bar_activity_desc == visible_bar_activity(driver, bar_label)
          end
          # Check the popover for each activity segment
          bar_activities.each_pair do |k, v|
            segment = activity_bar_elements(driver, bar_label).find { |el| el.text.include? k.to_s }
            driver.action.move_to(segment).perform
            driver.action.click_and_hold(segment).release.perform
            sleep 2
            (activity_count = span_element(xpath: '//div[contains(@class,"profile-activity-breakdown-popover-details")]/span[contains(@data-ng-bind-html, "segment.activityDescription")]/strong')).when_visible 2
            wait_until(2, "Expected '#{k} #{v}' but got '#{activity_count.text}'") do
              logger.debug "Waiting for '#{bar_label}' '#{k}' '#{v}', and it is currently '#{k}' '#{activity_count.text}'"
              activity_count.text.include? "#{v}"
            end
          end
        else
          no_activity_msg_element(bar_label).when_visible Utils.short_wait
        end
      end

      # Given a hash of user activities and the expected label for the user contributions bar element, verifies that the
      # contributions activity count shown matches expectations.
      # @param driver [Selenium::WebDriver]
      # @param user_activities [Hash]
      # @param bar_label [String]
      def verify_user_contributions(driver, user_activities, bar_label)
        non_zero = user_activities.select { |_, v| !v[:count].zero? }
        expected_bar_activities = user_bar_activities contrib_activities(non_zero)
        filter_activity_bar contribs_filter_button
        logger.info "Expecting user contributions to be '#{expected_bar_activities}'"
        verify_activity_bar(driver, expected_bar_activities, bar_label)
      end

      # Given a hash of user activities and the expected label for the user impacts bar element, verifies that the
      # impacts activity count shown matches expectations.
      # @param driver [Selenium::WebDriver]
      # @param user_activities [Hash]
      # @param bar_label [String]
      def verify_user_impacts(driver, user_activities, bar_label)
        non_zero = user_activities.select { |_, v| !v[:count].zero? }
        expected_bar_activities = user_bar_activities impact_activities(non_zero)
        filter_activity_bar impacts_filter_button
        logger.info "Expecting user impacts to be '#{expected_bar_activities}'"
        verify_activity_bar(driver, expected_bar_activities, bar_label)
      end

      # Given a hash of all users' activities and the expected label for the 'everyone' contributions bar element, verifies that the
      # contributions activity count shown matches expectations.
      # @param driver [Selenium::WebDriver]
      # @param all_activities [Hash]
      # @param users [Array<User>]
      def verify_everyone_contributions(driver, all_activities, users)
        contrib_activities = all_activities.map { |a| contrib_activities a }
        expected_bar_activities = everyone_bar_activities(contrib_activities, users)
        filter_activity_bar contribs_filter_button
        logger.info "Expecting everyone's contributions to be '#{expected_bar_activities}"
        verify_activity_bar(driver, expected_bar_activities, 'Compared to Everyone')
      end

      # Given a hash of all users' activities and the expected label for the 'everyone' impacts bar element, verifies that the
      # impacts activity count shown matches expectations.
      # @param driver [Selenium::WebDriver]
      # @param all_activities [Hash]
      # @param users [Array<User>]
      def verify_everyone_impacts(driver, all_activities, users)
        impact_activities = all_activities.map { |a| impact_activities a }
        expected_bar_activities = everyone_bar_activities(impact_activities, users)
        filter_activity_bar impacts_filter_button
        logger.info "Expecting everyone's impacts to be '#{expected_bar_activities}"
        verify_activity_bar(driver, expected_bar_activities, 'Compared to Everyone')
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
        if element.exists?
          scroll_to_element element
          js_click element
        end
      end

      # Given a set of asset IDs, a 'show more' link element, and the expected asset library sort/filter combination, verifies that
      # it is possible to show more if it should be and that the resulting asset library advanced search options and results are correct
      # @param driver [Selenium::WebDriver]
      # @param expected_asset_ids [Array<String>]
      # @param show_more_element [PageObject::Elements::Link]
      # @param search_filter_blk block that verifies the asset library search filters and results
      def verify_show_more(driver, expected_asset_ids, show_more_element, &search_filter_blk)
        if expected_asset_ids.length > 4
          sleep 1
          wait_for_update_and_click_js show_more_element
          wait_until(Utils.short_wait) { title == 'Asset Library' }
          switch_to_canvas_iframe driver
          begin
            return yield
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
      elements(:user_asset_link, :link, xpath: '//div[@id="user-assets"]//ul//a')
      div(:no_user_assets_msg, xpath: '//div[@id="user-assets"]/div[contains(.,"No matching assets were found.")]')

      # Clicks an asset detail link on the user Assets swim lane
      # @param driver [Selenium::WebDriver]
      # @param asset [Asset]
      def click_user_asset_link(driver, asset)
        logger.info "Clicking thumbnail for Asset ID #{asset.id}"
        wait_for_update_and_click_js link_element(xpath: "//div[@id='user-assets']//ul//a[contains(@href,'_id=#{asset.id}&')]")
        switch_to_canvas_iframe driver
      end

      # Returns the pin button for an asset on the user Assets lane
      # @param asset [Asset]
      # @return [PageObject::Elements::Button]
      def user_assets_pin_element(asset)
        button_element(xpath: "//div[@id='user-assets']//button[@id='iconbar-pin-#{asset.id}']")
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
          sleep 2
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
          sleep 2
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
          sleep 2
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
      div(:no_everyone_assets_msg, xpath: '//div[@id="community-assets"]/div[contains(.,"No matching assets were found.")]')
      elements(:everyone_asset_link, :link, xpath: '//div[@id="community-assets"]//ul//a')
      link(:everyone_assets_show_more_link, xpath: '//a[@data-id="community.assets.advancedSearchId"]')

      # Returns the pin button for an asset on the Everyone's Assets lane
      # @param asset [Asset]
      # @return [PageObject::Elements::Button]
      def everyone_assets_pin_element(asset)
        button_element(xpath: "//div[@id='community-assets']//button[@id='iconbar-pin-#{asset.id}']")
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
          sleep 2
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
          sleep 2
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
