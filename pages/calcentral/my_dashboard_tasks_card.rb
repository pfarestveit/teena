require_relative '../../util/spec_helper'

module Page

  module CalCentralPages

    class MyDashboardTasksCard < MyDashboardPage

      include PageObject
      include Logging
      include Page
      include CalCentralPages

      button(:scheduled_tasks_tab, xpath: '//button[contains(.,"scheduled")]')
      button(:unsched_tasks_tab, xpath: '//button[contains(.,"unscheduled")]')
      button(:completed_tasks_tab, xpath: '//div[@class="cc-widget-tasks-container"]//li[3]/button')

      span(:overdue_task_count, xpath: '//span[@data-ng-bind="overdueTasks.length"]')
      elements(:overdue_task, :list_item, xpath: '//li[contains(@data-ng-repeat,"overdueTasks")]')
      elements(:overdue_task_toggle, :div, xpath: '//li[contains(@data-ng-repeat,"overdueTasks")]//span[contains(.,"Show")]/..')
      elements(:overdue_task_title, :div, xpath: '//li[contains(@data-ng-repeat,"overdueTasks")]//strong[@data-ng-bind="task.title"]')
      elements(:overdue_task_course, :span, xpath: '//li[contains(@data-ng-repeat,"overdueTasks")]//span[@data-ng-bind="task.course_code"]')
      elements(:overdue_task_date, :div, xpath: '//li[contains(@data-ng-repeat,"overdueTasks")]//div[@class="cc-widget-tasks-col cc-widget-tasks-col-date"]/span')
      elements(:overdue_task_time, :div, xpath: '//li[contains(@data-ng-repeat,"overdueTasks")]//div[@data-ng-if="task.emitter==\'bCourses\' && task.dueDate.hasTime"]')
      elements(:overdue_task_bcourses_link, :link, xpath: '//li[contains(@data-ng-repeat,"overdueTasks")]//a[contains(.,"View in bCourses")]')

      span(:today_task_count, xpath: '//span[@data-ng-bind="dueTodayTasks.length"]')
      elements(:today_task, :list_item, xpath: '//li[contains(@data-ng-repeat,"dueTodayTasks")]')
      elements(:today_task_toggle, :div, xpath: '//li[contains(@data-ng-repeat,"dueTodayTasks")]//span[contains(.,"Show")]/..')
      elements(:today_task_title, :div, xpath: '//li[contains(@data-ng-repeat,"dueTodayTasks")]//strong[@data-ng-bind="task.title"]')
      elements(:today_task_course, :span, xpath: '//li[contains(@data-ng-repeat,"dueTodayTasks")]//span[@data-ng-bind="task.course_code"]')
      elements(:today_task_date, :div, xpath: '//li[contains(@data-ng-repeat,"dueTodayTasks")]//div[@class="cc-widget-tasks-col cc-widget-tasks-col-date"]/span')
      elements(:today_task_time, :div, xpath: '//li[contains(@data-ng-repeat,"dueTodayTasks")]//div[@data-ng-if="task.emitter==\'bCourses\' && task.dueDate.hasTime"]')
      elements(:today_task_bcourses_link, :link, xpath: '//li[contains(@data-ng-repeat,"dueTodayTasks")]//a[contains(.,"View in bCourses")]')

      span(:future_task_count, xpath: '//span[@data-ng-bind="futureTasks.length"]')
      elements(:future_task, :list_item, xpath: '//li[contains(@data-ng-repeat,"futureTasks")]')
      elements(:future_task_toggle, :div, xpath: '//li[contains(@data-ng-repeat,"futureTasks")]//span[contains(.,"Show")]/..')
      elements(:future_task_title, :div, xpath: '//li[contains(@data-ng-repeat,"futureTasks")]//strong[@data-ng-bind="task.title"]')
      elements(:future_task_course, :span, xpath: '//li[contains(@data-ng-repeat,"futureTasks")]//span[@data-ng-bind="task.course_code"]')
      elements(:future_task_date, :div, xpath: '//li[contains(@data-ng-repeat,"futureTasks")]//div[@class="cc-widget-tasks-col cc-widget-tasks-col-date"]/span')
      elements(:future_task_time, :div, xpath: '//li[contains(@data-ng-repeat,"futureTasks")]//div[@data-ng-if="task.emitter==\'bCourses\' && task.dueDate.hasTime"]')
      elements(:future_task_bcourses_link, :link, xpath: '//li[contains(@data-ng-repeat,"futureTasks")]//a[contains(.,"View in bCourses")]')

      span(:completed_task_count, xpath: '//span[@data-ng-bind="completedTasks.length"]')
      elements(:completed_task, :list_item, xpath: '//li[contains(@data-ng-repeat,"completedTasks")]')
      elements(:completed_task_toggle, :div, xpath: '//li[contains(@data-ng-repeat,"completedTasks")]//span[contains(.,"Show")]/..')
      elements(:completed_task_title, :div, xpath: '//li[contains(@data-ng-repeat,"completedTasks")]//strong[@data-ng-bind="task.title"]')

      # Clicks the scheduled tasks tab and waits for overdue tasks to appear
      def wait_for_overdue_tasks
        wait_for_update_and_click_js scheduled_tasks_tab_element
        wait_until(Utils.short_wait) { overdue_task_elements.any? }
      end

      # Expands an overdue task at the given index
      # @param index [Integer]
      def show_overdue_task_detail(index)
        overdue_task_toggle_elements[index].click unless overdue_task_bcourses_link_elements[index].visible?
      end

      # Clicks the scheduled tasks tab and waits for today tasks to appear
      def wait_for_today_tasks
        wait_for_update_and_click_js scheduled_tasks_tab_element
        wait_until(Utils.short_wait) { today_task_elements.any? }
      end

      # Expands a today task at the given index
      # @param index [Integer]
      def show_today_task_detail(index)
        today_task_toggle_elements[index].click unless today_task_bcourses_link_elements[index].visible?
      end

      # Clicks the scheduled tasks tab and waits for future tasks to appear
      def wait_for_future_tasks
        wait_for_update_and_click_js scheduled_tasks_tab_element
        wait_until(Utils.short_wait) { future_task_elements.any? }
      end

      # Expands a future task at the given index
      # @param index [Integer]
      def show_future_task_detail(index)
        future_task_toggle_elements[index].click unless future_task_bcourses_link_elements[index].visible?
      end

      # Clicks the completed tasks tab and waits for completed tasks to appear
      def wait_for_completed_tasks
        wait_for_update_and_click_js completed_tasks_tab_element
        wait_until(Utils.short_wait) { completed_task_elements.any? }
      end

      # The date format of tasks, with the year appended if not the current year
      # @param date [Date]
      # @return [String]
      def date_format(date)
        # Shows the year only if it is not the same as the current year
        (date.strftime("%Y") == Date.today.strftime("%Y")) ? date.strftime("%m/%d") : date.strftime("%m/%d/%Y")
      end

    end
  end
end
