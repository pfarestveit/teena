require_relative '../../util/spec_helper'

module Page

  module CalCentralPages

    class MyDashboardNotificationsCard < MyDashboardPage

      include PageObject
      include Logging
      include Page
      include CalCentralPages

      h2(:notifications_heading, xpath: '//h2[text()="Notifications"]')
      div(:spinner, xpath: '//div[@data-ng-include="widgets/activity_list.html"]/div[@data-cc-spinner-directive="process.isLoading"]')
      select_list(:notifications_select, xpath: '//div[@class="cc-widget cc-widget-activities ng-scope"]//select')
      unordered_list(:notifications_list, class: 'cc-widget-activities-list')
      elements(:notification, :list_item, xpath: '//ul[@class="cc-widget-activities-list"]/li')
      elements(:notification_toggle, :div, xpath: '//ul[@class="cc-widget-activities-list"]/li/div')
      elements(:notification_summary, :div, xpath: '//ul[@class="cc-widget-activities-list"]/li//strong')
      elements(:notification_source, :span, xpath: '//ul[@class="cc-widget-activities-list"]/li//span[@data-ng-bind="activity.source"]')
      elements(:notification_date, :span, xpath: '//ul[@class="cc-widget-activities-list"]/li//span[@data-ng-if="activity.date"]')
      elements(:notification_desc, :span, xpath: '//p[@data-onload="activityItem=activity"]/div/span')

      # Waits for and selects a given course on the notifications card
      # @param course [Course]
      def wait_for_notifications(course)
        notifications_select_element.when_present timeout=Utils.medium_wait
        wait_until(timeout) { notifications_select_options.include? course.code }
        self.notifications_select = course.code
      end

      # Returns the expected date format for a given date, appending the year if different from the current year
      # @param date [Date]
      # @return [String]
      def date_format(date)
        ui_date = date.strftime('%b %-d')
        ui_date << date.strftime(', %Y') if date.strftime('%Y') != Date.today.strftime('%Y')
        ui_date
      end

      # Expands a notification at a given index if it is collapsed
      # @param index [Integer]
      def expand_notification_detail(index)
        notification_elements[index].div_element.click unless notification_elements[index].paragraph_element(class: 'cc-widget-activities-summary' ).visible?
      end

      # Returns the 'more info' link element at a given index
      # @param index [Integer]
      # @return [PageObject::Elements::Link]
      def notification_more_info_link(index)
        link_element(xpath: "//ul[@class='cc-widget-activities-list']/li[#{(index + 1).to_s}]//div[@data-onload='activityItem=activity']/a")
      end

      # Expands a nested notification at a given index if it is collapsed
      # @param index [Integer]
      def expand_sub_notification_list(index)
        notification_toggle_elements[index].click unless notification_elements[index].unordered_list_element.visible?
      end

      # Returns a collection of toggles to expand nested notifications beneath a notification at a given index
      # @param index [Integer]
      # @return [Array<PageObject::Elements::Div>]
      def sub_notification_toggles(index)
        notification_elements[index].div_elements(xpath: '//ul/li/div[@class="cc-widget-list-hover cc-widget-list-hover-notriangle"]')
      end

      # Returns a collection of text displayed in a group of nested notifications beneath a notification at a given index
      # @param index [Integer]
      # @param elements [Array<PageObject::Elements::Element>]
      # @return [Array<String>]
      def sub_notification_text(index, elements)
        elements_text = []
        expand_sub_notification_list(index)
        toggles = sub_notification_toggles(index)
        toggles.each do |toggle|
          element = elements[toggles.index(toggle)]
          toggle.click
          wait_until(Utils.short_wait) { element.visible? }
          elements_text << element.text
        end
        elements_text
      end

      # Returns a collection of summary text displayed in a group of nested notifications beneath a notification at a given index
      # @param index [Integer]
      # @return [Array<String>]
      def sub_notification_summaries(index)
        summary_elements = notification_elements[index].div_elements(xpath: "//ul/li//div[contains(@class,'cc-widget-activities-sub-activity ng-binding')]")
        sub_notification_text(index, summary_elements)
      end

      # Returns a collection of description text displayed in a group of nested notifications beneath a notification at a given index
      # @param index [Integer]
      # @return [Array<String>]
      def sub_notification_descrips(index)
        descrip_elements = notification_elements[index].span_elements(xpath: '//ul/li//p[@data-onload="activityItem=subActivity"]//span')
        sub_notification_text(index, descrip_elements)
      end

    end
  end
end
