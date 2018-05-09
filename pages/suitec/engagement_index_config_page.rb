require_relative '../../util/spec_helper'

module Page

  module SuiteCPages

    class EngagementIndexConfigPage < EngagementIndexPage

      include PageObject
      include Logging
      include Page
      include SuiteCPages

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
