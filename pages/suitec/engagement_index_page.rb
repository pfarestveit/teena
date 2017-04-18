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
      def load_page(driver, url)
        navigate_to url
        wait_until { title == "#{SuiteCTools::ENGAGEMENT_INDEX.name}" }
        hide_canvas_footer
        switch_to_canvas_iframe driver
      end

      # USER INFO

      span(:user_info_rank, xpath: '//span[@data-ng-bind="me.rank"]')
      span(:user_info_points, xpath: '//span[@data-ng-bind="me.points"]')
      div(:user_info_boxplot, id: 'leaderboard-userinfo-boxplot')

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

      # Loads the engagement index leaderboard
      # @param driver [Selenium::WebDriver]
      # @param url [String]
      def load_scores(driver, url)
        load_page(driver, url)
        users_table_element.when_visible Utils.medium_wait
      end

      # Searches for a user on the leaderboard
      # @param user [User]
      def search_for_user(user)
        wait_for_element_and_type(text_area_element(class: 'leaderboard-list-search'), user.full_name)
      end

      # Clicks the user name link to open the Impact Studio page
      # @param driver [Selenium::WebDriver]
      # @param user [User]
      def click_user_dashboard_link(driver, user)
        logger.info "Clicking the Impact Studio link for UID #{user.uid}"
        wait_until(Utils.medium_wait) do
          scroll_to_bottom
          sleep 1
          link_element(xpath: "//a[contains(.,'#{user.full_name}')]").exists?
        end
        link_element(xpath: "//a[contains(.,'#{user.full_name}')]").click
        switch_to_canvas_iframe driver
      end

      # Returns the score of a given user on the leaderboard
      # @param user [User]
      def user_score(user)
        score = '0'
        users_table_element.when_present Utils.short_wait
        search_for_user user
        sleep 1
        users_table_element.each { |row| score = row[3].text if row[1].text == user.full_name }
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
        tries ||= Utils.poller_retries
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
      def sort_by_rank_asc
        logger.info 'Sorting by "Rank" ascending'
        wait_for_update_and_click_js sort_by_rank_element
        sort_by_rank unless sort_asc?
      end

      # Sorts the leaderboard by rank descending
      def sort_by_rank_desc
        logger.info 'Sorting by "Rank" descending'
        wait_for_update_and_click_js sort_by_rank_element
        sort_by_rank if sort_asc?
      end

      # Sorts the leaderboard by name ascending
      def sort_by_name_asc
        logger.info 'Sorting by "Name" ascending'
        wait_for_update_and_click_js sort_by_name_element
        sort_by_name unless sort_asc?
      end

      # Sorts the leaderboard by name descending
      def sort_by_name_desc
        logger.info 'Sorting by "Name" descending'
        wait_for_update_and_click_js sort_by_name_element
        sort_by_name if sort_asc?
      end

      # Sorts the leaderboard by sharing preference ascending
      def sort_by_share_asc
        logger.info 'Sorting by "Share" ascending'
        wait_for_update_and_click_js sort_by_share_element
        sort_by_share unless sort_asc?
      end

      # Sorts the leaderboard by sharing preference descending
      def sort_by_share_desc
        logger.info 'Sorting by "Share" descending'
        wait_for_update_and_click_js sort_by_share_element
        sort_by_share if sort_asc?
      end

      # Sorts the leaderboard by point totals ascending
      def sort_by_points_asc
        logger.info 'Sorting by "Points" ascending'
        wait_for_update_and_click_js sort_by_points_element
        sort_by_points unless sort_asc?
      end

      # Sorts the leaderboard by point totals descending
      def sort_by_points_desc
        logger.info 'Sorting by "Points" descending'
        wait_for_update_and_click_js sort_by_points_element
        sort_by_points if sort_asc?
      end

      # Sorts the leaderboard by last activity dates ascending
      def sort_by_activity_asc
        logger.info 'Sorting by "Last Activity" ascending'
        wait_for_update_and_click_js sort_by_activity_element
        sort_by_activity unless sort_asc?
      end

      # Sorts the leaderboard by last activity dates descending
      def sort_by_activity_desc
        logger.info 'Sorting by "Last Activity" descending'
        wait_for_update_and_click_js sort_by_activity_element
        sort_by_activity if sort_asc?
      end

      # SHARING

      h3(:share_score_heading, xpath: '//h3[text()="Share my score"]')
      checkbox(:share_score_cbx, id: 'engagementindex-share')
      button(:continue_button, xpath: '//button[text()="Continue"]')

      # Opts to share a user's score on the leaderboard
      def share_score
        scroll_to_bottom
        share_score_cbx_element.when_visible Utils.short_wait
        logger.info 'Sharing score'
        share_score_cbx_checked? ? logger.warn('Score is already shared') : check_share_score_cbx
        continue_button if continue_button?
        users_table_element.when_visible Utils.short_wait
      end

      # Opts not to share a user's score on the leaderboard
      def un_share_score
        scroll_to_bottom
        share_score_cbx_element.when_visible Utils.short_wait
        logger.info 'Un-sharing score'
        share_score_cbx_checked? ? uncheck_share_score_cbx : logger.warn('Score is already un-shared')
        continue_button if continue_button?
        users_table_element.when_not_visible Utils.short_wait rescue Selenium::WebDriver::Error::StaleElementReferenceError
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
      # @return [Array<String>]
      def download_csv(driver, course, url)
        logger.info 'Downloading activities CSV'
        sleep 1
        Utils.prepare_download_dir
        load_scores(driver, url)
        window = driver.window_handle
        window_count = driver.window_handles.length
        wait_for_load_and_click_js download_csv_link_element
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
      def click_points_config
        wait_for_update_and_click points_config_link_element
        wait_until(Utils.short_wait) { enabled_activity_title_elements.any? }
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
        cell_element(xpath: "//td[text()='#{activity.title}']/following-sibling::td").text.to_i
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
      def click_back_to_index
        wait_for_update_and_click_js back_to_engagement_index_element
      end

    end
  end
end
