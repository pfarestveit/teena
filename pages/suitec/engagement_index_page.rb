require_relative '../../util/spec_helper'

module Page

  module SuiteCPages

    class EngagementIndexPage

      include PageObject
      include Logging
      include Page
      include SuiteCPages

      # Loads the Engagement Index tool and switches browser focus to the tool iframe
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      # @param event [Event]
      def load_page(driver, url, event = nil)
        navigate_to url
        wait_until { title == "#{LtiTools::ENGAGEMENT_INDEX.name}" }
        hide_canvas_footer_and_popup
        switch_to_canvas_iframe driver
        add_event(event, EventType::NAVIGATE)
        add_event(event, EventType::LAUNCH_ENGAGEMENT_INDEX)
      end

      # USER INFO

      span(:user_info_rank, xpath: '//span[@data-ng-bind="me.rank"]')
      span(:user_info_points, xpath: '//span[@data-ng-bind="me.points"]')
      div(:user_info_boxplot, id: 'leaderboard-userinfo-boxplot')

      # Waits for the Canvas poller to sync course data, which is defined by the block executed.
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      # @param blk - the block to execute
      def wait_for_poller_sync(driver, url, &blk)
        tries ||= SuiteCUtils.poller_retries
        begin
          return yield
        end
      rescue
        sleep Utils.short_wait
        (tries -= 1).zero? ? fail : retry
      end

      # Waits for the Canvas poller to sync new course site members so that they appear on the Engagement Index, and then sets to user's SuiteC ID.
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      # @param course [Course]
      # @param users [Array<User>]
      # @param event [Event]
      def wait_for_new_user_sync(driver, url, course, users, event = nil)
        wait_for_poller_sync(driver, url) do
          load_scores(driver, url, event)
          users.each do |u|
            logger.debug "Checking if #{u.full_name} has been added to the course"
            wait_until(1) { visible_names.include? u.full_name }
            u.suitec_id = SuiteCUtils.get_user_suitec_id(u, course)
          end
        end
      end

      # Waits for the Canvas poller to sync removed course site members so that they disappear from the Engagement Index
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      # @param users [Array<User>]
      # @param event [Event]
      def wait_for_removed_user_sync(driver, url, users, event = nil)
        wait_for_poller_sync(driver, url) do
          load_scores(driver, url, event)
          users.each do |u|
            logger.debug "Checking if #{u.full_name} has been removed from the course"
            wait_until(1) { !visible_names.include? u.full_name }
          end
        end
      end

      # LEADERBOARD

      table(:users_table, class: 'leaderboard-list-table')
      link(:sort_by_rank, xpath: '//th[@data-ng-click="sort(\'rank\')"]')
      link(:sort_by_name, xpath: '//th[@data-ng-click="sort(\'canvas_full_name\')"]')
      link(:sort_by_share, xpath: '//th[@data-ng-click="sort(\'share_points\')"]')
      link(:sort_by_points, xpath: '//th[@data-ng-click="sort(\'points\')"]')
      link(:sort_by_activity, xpath: '//th[@data-ng-click="sort(\'last_activity\')"]')
      span(:sort_asc, xpath: '//th[contains(@class,"dropup")]/span[@class="caret ng-scope"]')
      elements(:name, :span, xpath: '//span[@data-ng-bind="user.canvas_full_name"]')
      elements(:sharing, :span, xpath: '//span[@data-ng-if="user.share_points"]')
      elements(:last_activity, :span, xpath: '//span[@data-ng-if="user.last_activity"]')

      # Waits for the leaderboard to load
      # @param event [Event]
      def wait_for_scores(event = nil)
        users_table_element.when_visible Utils.medium_wait
        add_event(event, EventType::GET_ENGAGEMENT_INDEX)
      end

      # Loads the engagement index leaderboard
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      # @param event [Event]
      def load_scores(driver, url, event = nil)
        load_page(driver, url, event)
        wait_for_scores event
        add_event(event, EventType::VIEW, 'Leaderboard')
      end

      # Searches for a user on the leaderboard
      # @param user [User]
      # @param event [Event]
      def search_for_user(user, event = nil)
        wait_for_element_and_type(text_area_element(class: 'leaderboard-list-search'), user.full_name)
        add_event(event, EventType::SEARCH)
        # Search events are fired for all but whitespace in the search string
        (user.full_name.gsub(' ', '').length).times { add_event(event, EventType::SEARCH_ENGAGEMENT_INDEX, user.full_name) }
      end

      # Returns the Impact Studio link for a given user
      # @param user [User]
      # @return [PageObject::Elements::Link]
      def user_profile_link(user)
        link_element(xpath: "//a[contains(.,'#{user.full_name}')]")
      end

      # Clicks the user name link to open the Impact Studio page
      # @param driver [Selenium::WebDriver]
      # @param user [User]
      # @param event [Event]
      def click_user_dashboard_link(driver, user, event = nil)
        logger.info "Clicking the Impact Studio link for UID #{user.uid}"
        wait_until(Utils.medium_wait) do
          scroll_to_bottom
          sleep 1
          user_profile_link(user).exists?
        end
        scroll_to_element user_profile_link(user)
        user_profile_link(user).click
        wait_until { title == "#{LtiTools::IMPACT_STUDIO.name}" }
        add_event(event, EventType::LAUNCH_IMPACT_STUDIO)
        add_event(event, EventType::VIEW_PROFILE, user.uid)
        hide_canvas_footer_and_popup
        switch_to_canvas_iframe driver
      end

      # Returns the score of a given user on the leaderboard
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      # @param user [User]
      # @param event [Event]
      def user_score(driver, url, user, event = nil)
        load_scores(driver, url, event)
        score = '0'
        search_for_user(user, event)
        sleep 1
        users_table_element.each do |row|
          if row[1].text == user.full_name
            # If the Impact Studio is enabled, then an additional 'Collaborate' column will be present.
            score = row.columns == 5 ? row[3].text : row[4].text
          end
        end
        logger.debug "#{user.full_name}'s score is currently '#{score}'"
        score
      end

      # Checks if a user's score has reached a given number of points
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      # @param user [User]
      # @param expected_score [String]
      # @return [boolean]
      def user_score_updated?(driver, url, user, expected_score)
        tries ||= SuiteCUtils.poller_retries
        logger.info("Checking if #{user.full_name} has an updated score of #{expected_score}")
        load_scores(driver, url)
        wait_until(3) { user_score(user) == expected_score }
        true
      rescue
        logger.warn 'Score is not yet updated, retrying'
        sleep Utils.short_wait
        retry unless (tries -= 1).zero?
        false
      end

      # Returns an array of all user ranks on the leaderboard
      # @return [Array<Integer>]
      def visible_ranks
        ranks = (users_table_element.map { |row| row[0].text.to_i }).to_a
        # Drop header row
        ranks.drop 1 if ranks.any?
      end

      # Returns an array of all user names on the leaderboard
      # @return [Array<String>]
      def visible_names
        (name_elements.map &:text).to_a
      end

      # Returns an array of all user sharing preferences on the leaderboard
      # @return [Array<String>]
      def visible_sharing
        (sharing_elements.map &:text).to_a
      end

      # Returns an array of all user point totals on the leaderboard
      # @return [Array<Integer>]
      def visible_points
        points = (users_table_element.map { |row| row[3].text.to_i }).to_a
        # Drop header row
        points.drop 1 if points.any?
      end

      # Returns an array of all last user activity dates on the leaderboard
      # @return [Array<Date>]
      def visible_activity_dates
        (last_activity_elements.map { |date| Date.strptime(date.text, '%m/%d/%Y %l:%M %p') }).to_a
      end

      # Sorts the leaderboard by rank ascending
      # @param event [Event]
      def sort_by_rank_asc(event = nil)
        logger.info 'Sorting by "Rank" ascending'
        wait_for_update_and_click_js sort_by_rank_element
        add_event(event, EventType::SORT_ENGAGEMENT_INDEX, 'rank asc')
        unless sort_asc?
          sort_by_rank
          add_event(event, EventType::SORT_ENGAGEMENT_INDEX, 'rank desc')
        end
      end

      # Sorts the leaderboard by rank descending
      # @param event [Event]
      def sort_by_rank_desc(event = nil)
        logger.info 'Sorting by "Rank" descending'
        wait_for_update_and_click_js sort_by_rank_element
        add_event(event, EventType::SORT_ENGAGEMENT_INDEX, 'rank desc')
        if sort_asc?
          sort_by_rank
          add_event(event, EventType::SORT_ENGAGEMENT_INDEX, 'rank asc')
        end
      end

      # Sorts the leaderboard by name ascending
      # @param event [Event]
      def sort_by_name_asc(event = nil)
        logger.info 'Sorting by "Name" ascending'
        wait_for_update_and_click_js sort_by_name_element
        add_event(event, EventType::SORT_ENGAGEMENT_INDEX, 'name asc')
        unless sort_asc?
          sort_by_name
          add_event(event, EventType::SORT_ENGAGEMENT_INDEX, 'name desc')
        end
      end

      # Sorts the leaderboard by name descending
      # @param event [Event]
      def sort_by_name_desc(event = nil)
        logger.info 'Sorting by "Name" descending'
        wait_for_update_and_click_js sort_by_name_element
        add_event(event, EventType::SORT_ENGAGEMENT_INDEX, 'name desc')
        if sort_asc?
          sort_by_name
          add_event(event, EventType::SORT_ENGAGEMENT_INDEX, 'name asc')
        end
      end

      # Sorts the leaderboard by sharing preference ascending
      # @param event [Event]
      def sort_by_share_asc(event = nil)
        logger.info 'Sorting by "Share" ascending'
        wait_for_update_and_click_js sort_by_share_element
        add_event(event, EventType::SORT_ENGAGEMENT_INDEX, 'share asc')
        unless sort_asc?
          sort_by_share
          add_event(event, EventType::SORT_ENGAGEMENT_INDEX, 'share desc')
        end
      end

      # Sorts the leaderboard by sharing preference descending
      # @param event [Event]
      def sort_by_share_desc(event = nil)
        logger.info 'Sorting by "Share" descending'
        wait_for_update_and_click_js sort_by_share_element
        add_event(event, EventType::SORT_ENGAGEMENT_INDEX, 'share desc')
        if sort_asc?
          sort_by_share
          add_event(event, EventType::SORT_ENGAGEMENT_INDEX, 'share asc')
        end
      end

      # Sorts the leaderboard by point totals ascending
      # @param event [Event]
      def sort_by_points_asc(event = nil)
        logger.info 'Sorting by "Points" ascending'
        wait_for_update_and_click_js sort_by_points_element
        add_event(event, EventType::SORT_ENGAGEMENT_INDEX, 'points asc')
        unless sort_asc?
          sort_by_points
          add_event(event, EventType::SORT_ENGAGEMENT_INDEX, 'points desc')
        end
      end

      # Sorts the leaderboard by point totals descending
      # @param event [Event]
      def sort_by_points_desc(event = nil)
        logger.info 'Sorting by "Points" descending'
        wait_for_update_and_click_js sort_by_points_element
        add_event(event, EventType::SORT_ENGAGEMENT_INDEX, 'points desc')
        if sort_asc?
          sort_by_points
          add_event(event, EventType::SORT_ENGAGEMENT_INDEX, 'points asc')
        end
      end

      # Sorts the leaderboard by last activity dates ascending
      # @param event [Event]
      def sort_by_activity_asc(event = nil)
        logger.info 'Sorting by "Last Activity" ascending'
        wait_for_update_and_click_js sort_by_activity_element
        add_event(event, EventType::SORT_ENGAGEMENT_INDEX, 'last activity asc')
        unless sort_asc?
          sort_by_activity
          add_event(event, EventType::SORT_ENGAGEMENT_INDEX, 'last activity desc')
        end
      end

      # Sorts the leaderboard by last activity dates descending
      # @param event [Event]
      def sort_by_activity_desc(event = nil)
        logger.info 'Sorting by "Last Activity" descending'
        wait_for_update_and_click_js sort_by_activity_element
        add_event(event, EventType::SORT_ENGAGEMENT_INDEX, 'last activity desc')
        if sort_asc?
          sort_by_activity
          add_event(event, EventType::SORT_ENGAGEMENT_INDEX, 'last activity asc')
        end
      end

      # SHARING

      h3(:share_score_heading, xpath: '//h3[text()="Share my score"]')
      checkbox(:share_score_cbx, id: 'engagementindex-share')
      button(:continue_button, xpath: '//button[text()="Continue"]')

      # Opts to share a user's score on the leaderboard
      # @param event [Event]
      def share_score(event = nil)
        scroll_to_bottom
        share_score_cbx_element.when_visible Utils.short_wait
        logger.info 'Sharing score'
        js_click(share_score_cbx_element) unless share_score_cbx_checked?
        continue_button if continue_button?
        wait_for_scores event
        add_event(event, EventType::SHOW)
        add_event(event, EventType::VIEW, 'Leaderboard')
        add_event(event, EventType::EDIT_SCORE_SHARING, 'share')
      end

      # Opts not to share a user's score on the leaderboard
      # @param event [Event]
      def un_share_score(event = nil)
        scroll_to_bottom
        share_score_cbx_element.when_visible Utils.short_wait
        logger.info 'Un-sharing score'
        share_score_cbx_checked? ? js_click(share_score_cbx_element) : logger.warn('Score is already un-shared')
        continue_button if continue_button?
        users_table_element.when_not_visible Utils.short_wait rescue Selenium::WebDriver::Error::StaleElementReferenceError
        add_event(event, EventType::HIDE)
        add_event(event, EventType::VIEW, 'Leaderboard') if event && event.actor && !%w(Student Observer).include?(event.actor.role)
        add_event(event, EventType::EDIT_SCORE_SHARING, 'unshare')
      end

      # Returns the current sharing preference of a user
      # @param user [User]
      # @return [String]
      def sharing_preference(user)
        # Retry once to avoid collision with DOM update
        tries = 2
        span_element(xpath: "//span[text()='#{user.full_name}']/../../../following-sibling::td/span").text
      rescue Selenium::WebDriver::Error::StaleElementReferenceError
        retry unless (tries -= 1).zero?
      end

      link(:download_csv_link, text: 'Download CSV')

      # Downloads the activity export CSV; parses it; creates a string for each row containing the user name, action, score, and
      # running_total values in that row; and returns an array of those strings
      # @param driver [Selenium::WebDriver]
      # @param course [Course]
      # @param url [String]
      # @param event [Event]
      # @return [Array<String>]
      def download_csv(driver, course, url, event = nil)
        logger.info 'Downloading activities CSV'
        sleep 1
        Utils.prepare_download_dir
        load_scores(driver, url, event)
        window = driver.window_handle
        window_count = driver.window_handles.length
        wait_for_load_and_click_js download_csv_link_element
        Utils.save_screenshot(driver, "#{Time.now}")
        date = Time.now.strftime('%Y_%m_%d')
        # Hour and minute in the file name are globbed to avoid test failures due to clock sync issues
        csv_file_path = "#{Utils.download_dir}/engagement_index_activities_#{course.site_id}_#{date}_*.csv"
        wait_until { Dir[csv_file_path].any? }
        csv = Dir[csv_file_path].first
        activities = []
        CSV.foreach(csv, { headers: true }) do |column|
          # user_name, action, score, running_total
          activities << "#{column[1]}, #{column[2]}, #{column[4]}, #{column[5]}"
        end
        new_window_count = driver.window_handles.length
        if new_window_count > window_count
          driver.switch_to.window driver.window_handles.last
          driver.close
          driver.switch_to.window window
        end
        activities
      end

      # COLLABORATION

      # Returns the element containing a user's collaboration 'looking' status
      # @param user [User]
      # @return [PageObject::Elements::Span]
      def collaboration_status_element(user)
        span_element(xpath: "//span[contains(.,'#{user.full_name}')]/ancestor::td/following-sibling::td[1]//span")
      end

      def collaboration_toggle_element(user)
        label_element(xpath: "//span[contains(.,'#{user.full_name}')]/ancestor::td/following-sibling::td[1]//label")
      end

      # Returns a user's 'collaborate' button element
      # @param user [User]
      # @return [PageObject::Elements::Button]
      def collaboration_button_element(user)
        button_element(xpath: "//span[contains(.,'#{user.full_name}')]/ancestor::td/following-sibling::td//button[@title='Looking for Collaborators']")
      end

      def set_collaboration_true(user)
        collaboration_status_element(user).when_visible Utils.short_wait
        if collaboration_status_element(user).text.include? 'Not'
          wait_for_update_and_click collaboration_toggle_element(user)
          sleep 1
          wait_until(Utils.short_wait) { !collaboration_status_element.text.include?('Not') rescue Selenium::WebDriver::Error::StaleElementReferenceError }
        else
          logger.debug '"Looking for collaborators" is already true, doing nothing'
        end
      end

      def set_collaboration_false(user)
        collaboration_status_element(user).when_visible Utils.short_wait
        if collaboration_status_element(user).text.include? 'Not'
          logger.debug '"Looking for collaborators" is already false, doing nothing'
        else
          wait_for_update_and_click collaboration_toggle_element(user)
          sleep 1
          wait_until(Utils.short_wait) { collaboration_status_element.text.include?('Not') rescue Selenium::WebDriver::Error::StaleElementReferenceError }
        end
      end

      def click_collaborate_button(user)
        logger.debug "Clicking 'Collaborate' button for #{user.full_name}"
        collaboration_button_element(user).when_visible Utils.short_wait
        scroll_to_element collaboration_button_element(user)
        wait_for_update_and_click collaboration_button_element(user)
      end

      # POINTS CONFIG

      link(:points_config_link, text: 'Points configuration')
      table(:points_config_table, xpath: '//h2[text9)="Points Configuration"]/following-sibling::form[@name="activityTypeConfigurationForm"]/table')
      elements(:enabled_activity_title, :td, xpath: '//tr[@data-ng-repeat="activityType in activityTypeConfiguration | filter:{enabled: true}"]/td[@data-ng-bind="activityType.title"]')
      elements(:disabled_activity_title, :td, xpath: '//tr[@data-ng-repeat="activityType in activityTypeConfiguration | filter:{enabled: false}"]/td[@data-ng-bind="activityType.title"]')

      button(:edit_points_config_button, xpath: '//button[text()="Edit"]')
      elements(:activity_edit, :text_area, id: 'points-edit-points')
      button(:cancel_button, xpath: '//button[text()="Cancel"]')
      button(:save_button, xpath: '//button[text()="Save"]')
      link(:back_to_engagement_index, xpath: '//a[contains(.,"Back to Engagement Index")]')

      # Clicks the points configuration button
      # @param event [Event]
      def click_points_config(event = nil)
        wait_for_update_and_click points_config_link_element
        wait_until(Utils.short_wait) { enabled_activity_title_elements.any? }
        add_event(event, EventType::VIEW, 'Points config')
        add_event(event, EventType::GET_POINTS_CONFIG)
        sleep 2
      end

      # Returns an array of titles of enabled activities
      # @return [Array<String>]
      def enabled_activity_titles
        enabled_activity_title_elements.map &:text
      end

      # Returns an array of titles of disabled activities
      # @return [Array<String>]
      def disabled_activity_titles
        disabled_activity_title_elements.map &:text
      end

      # Returns the current point value assigned to an activity
      # @param activity [String]
      # @return [Integer]
      def activity_points(activity)
        cell_element(xpath: "//td[text()=\"#{activity.title}\"]/following-sibling::td").text.to_i
      end

      # Clicks the 'edit' button on the points configuration page
      def click_edit_points_config
        wait_for_update_and_click_js edit_points_config_button_element
        wait_until(Utils.short_wait) { activity_edit_elements.any? }
      end

      # Clicks the button to disable a given activity
      # @param activity [Activity]
      def click_disable_activity(activity)
        wait_for_update_and_click_js button_element(xpath: "//td[text()='#{activity.title}']/following-sibling::td[2]/button[text()='Disable']")
        wait_until(Utils.short_wait) { cell_element(xpath: "//div[@data-ng-show='hasDisabledActivities()']//tr[contains(.,'#{activity.title}')]") }
      end

      # Clicks the button to enable a given activity
      # @param activity [Activity]
      def click_enable_activity(activity)
        wait_for_update_and_click_js button_element(xpath: "//h3[text()='Disabled Activities']/following-sibling::table//td[text()='#{activity.title}']/following-sibling::td[2]/button[text()='Enable']")
      end

      # Clicks the 'cancel' button on the points config edit page
      def click_cancel_config_edit
        wait_for_update_and_click_js cancel_button_element
      end

      # Clicks the 'save' button on the points config edit page
      def click_save_config_edit
        wait_for_update_and_click_js save_button_element
      end

      # Disables a given activity
      # @param activity [Activity]
      def disable_activity(activity)
        click_edit_points_config if edit_points_config_button?
        click_disable_activity activity
        wait_until(Utils.short_wait) { cell_element(xpath: "//div[@data-ng-show='hasDisabledActivities()']//tr[contains(.,'#{activity.title}')]") }
        click_save_config_edit
      end

      # Enables a given activity
      # @param activity [Activity]
      def enable_activity(activity)
        click_edit_points_config if edit_points_config_button?
        click_enable_activity activity
        wait_until(Utils.short_wait) { button_element(xpath: "//td[text()='#{activity.title}']/following-sibling::td[2]/button[text()='Disable']") }
        click_save_config_edit
      end

      # Sets to points awarded for an activity to a give new point value
      # @param activity [Activity]
      # @param new_points [String]
      def change_activity_points(activity, new_points)
        click_edit_points_config if edit_points_config_button?
        input = text_area_element(xpath: "//td[text()='#{activity.title}']/following-sibling::td//input")
        wait_for_element_and_type_js(input, new_points)
        click_save_config_edit
      end

      # Clicks the 'back to engagement index' link
      # @param event [Event]
      def click_back_to_index(event = nil)
        wait_for_update_and_click_js back_to_engagement_index_element
        add_event(event, EventType::GET_ENGAGEMENT_INDEX)
      end

    end
  end
end
