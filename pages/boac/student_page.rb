require_relative '../../util/spec_helper'

module Page

  module BOACPages

    class StudentPage

      include PageObject
      include Logging
      include Page
      include BOACPages

      h1(:name, xpath: '//h1[@data-ng-bind="student.sisProfile.primaryName"]')
      div(:phone, xpath: '//div[@data-ng-bind="student.sisProfile.phoneNumber"]')
      link(:email, xpath: '//a[@data-ng-bind="student.sisProfile.emailAddress"]')
      div(:cumulative_units, xpath: '//div[@data-ng-bind="student.sisProfile.cumulativeUnits"]')
      div(:cumulative_gpa, xpath: '//div[contains(@data-ng-bind,"student.sisProfile.cumulativeGPA")]')
      h3(:plan, xpath: '//h3[@data-ng-bind="student.sisProfile.plan.description"]')
      h3(:level, xpath: '//h3[@data-ng-bind="student.sisProfile.level.description"]')

      cell(:writing_reqt, xpath: '//td[text()="Entry Level Writing"]/following-sibling::td')
      cell(:history_reqt, xpath: '//td[text()="American History"]/following-sibling::td')
      cell(:institutions_reqt, xpath: '//td[text()="American Institutions"]/following-sibling::td')
      cell(:cultures_reqt, xpath: '//td[text()="American Cultures"]/following-sibling::td')
      cell(:language_reqt, xpath: '//td[text()="Foreign Language"]/following-sibling::td')

      elements(:course_site_code, :h3, xpath: '//h3[@data-ng-bind="course.courseCode"]')

      # Returns all the visible course site codes
      # @return [Array<String>]
      def visible_course_site_codes
        (course_site_code_elements.map &:text).gsub(/\s+/, ' ')
      end

      # Returns the XPath to the SIS data shown for a given course site section
      # @param course_site_code [String]
      # @param site_index [Integer]
      # @return [String]
      def site_sis_data_xpath(course_site_code, site_index)
        "//h3[text()=\"#{course_site_code}\"]/following-sibling::div[#{site_index + 1}]"
      end

      # Returns a hash of visible course section data
      # @param course_site_code [String]
      # @param site_index [Integer]
      # @return [Hash]
      def visible_site_sis_data(course_site_code, site_index)
        logger.debug "Checking #{course_site_code}"
        site_xpath = site_sis_data_xpath(course_site_code, site_index)
        {
          :status => span_element(:xpath => "#{site_xpath}/span[@data-ng-switch='enrolledSection.enrollmentStatus']/span").text,
          :number => span_element(:xpath => "#{site_xpath}/span[@data-ng-bind='enrolledSection.sectionNumber']").text,
          :units => span_element(:xpath => "#{site_xpath}/span[@data-ng-bind='enrolledSection.units']").text,
          :grading_basis => span_element(:xpath => "#{site_xpath}/span[@data-ng-bind='enrolledSection.gradingBasis']").text
        }
      end

      # Returns the XPath to the boxplot graph for a particular set of analytics data for a given course site, for example 'page views'
      # @param course_site_code [String]
      # @param label [String]
      # @return [String]
      def site_boxplot_xpath(course_site_code, label)
        "#{site_analytics_data_xpath(course_site_code, label)}/div[contains(@class,'boxplot-container')]//*[local-name()='svg']/*[name()='g'][@class='highcharts-series-group']"
      end

      # Returns the element containing the boxplot graph for a particular set of analytics data for a given course site, for example 'page views'
      # @param driver [Selenium::WebDriver]
      # @param course_site_code [String]
      # @param label [String]
      # @return [Selenium::WebDriver::Element]
      def boxplot_element(driver, course_site_code, label)
        driver.find_element(xpath: "#{site_boxplot_xpath(course_site_code, label)}/*[name()='g']/*[name()='g']/*[name()='path'][3]")
      end

      # Returns the XPath to a particular set of analytics data for a given course site, for example 'page views'
      # @param course_site_code [String]
      # @param label [String]
      # @return [String]
      def site_analytics_data_xpath(course_site_code, label)
        "//h3[text()=\"#{course_site_code}\"]/following-sibling::ul/li[contains(.,'#{label}:')]"
      end

      # Returns the element containing the analytics tooltip for a particular set of analytics data for a given course site, for example 'page views'
      # @param course_site_code [String]
      # @param label [String]
      # @return [PageObject::Elements::Div]
      def analytics_tooltip_element(course_site_code, label)
        div_element(:xpath => "#{site_analytics_data_xpath(course_site_code, label)}//div[contains(@class,'highcharts-tooltip')]")
      end

      # Checks the existence of a 'no data' message for a particular set of analytics for a given course site, for example 'page views'
      # @param course_site_code [String]
      # @param label [String]
      # @return [boolean]
      def no_data?(course_site_code, label)
        span_element(:xpath => "#{site_analytics_data_xpath(course_site_code, label)}/span[text()='No data']").exists?
      end

      # Checks the existence of a 'no data' message for assignments on time analytics for a given course site
      # @param course_site_code [String]
      # @return [boolean]
      def no_assignment_data?(course_site_code)
        no_data?(course_site_code, 'Assignments on time')
      end

      # Checks the existence of a 'no data' message for page view analytics for a given course site
      # @param course_site_code [String]
      # @return [boolean]
      def no_page_view_data?(course_site_code)
        no_data?(course_site_code, 'Page views')
      end

      # Checks the existence of a 'no data' message for participations analytics for a given course site
      # @param course_site_code [String]
      # @return [boolean]
      def no_participations_data?(course_site_code)
        no_data?(course_site_code, 'Participations')
      end

      # Mouses over a boxplot for a particular set of analytics data for a given course site, for example 'page views', and returns
      # the analytics data that appears
      # @param driver [Selenium::WebDriver]
      # @param course_site_code [String]
      # @param label [String]
      # @return [Array<String>]
      def get_tooltip_text(driver, course_site_code, label)
        wait_until(Utils.short_wait) { boxplot_element(driver, course_site_code, label) }
        # Add a vertical offset to the mouseover in case the user score tooltip trigger is bang on top of the analytics tooltip trigger
        mouseover(driver, boxplot_element(driver, course_site_code, label), 0, 5)
        analytics_tooltip_element(course_site_code, label).when_visible Utils.short_wait
        analytics_tooltip_element(course_site_code, label).text.split "\n"
      end

      # Returns the element containing the user score tooltip for a particular set of analytics data for a given course site, for example 'page views'
      # @param driver [Selenium::WebDriver]
      # @param course_site_code [String]
      # @param label [String]
      # @return
      def user_score_tooltip_element(driver, course_site_code, label)
        driver.find_element(xpath: "#{site_boxplot_xpath(course_site_code, label)}/*[name()='g'][last()]")
      end

      # Mouses over a boxplot for a particular set of analytics data for a given course site, for example 'page views', and returns
      # the user score that appears
      # @param driver [Selenium::WebDriver]
      # @param course_site_code [String]
      # @param label [String]
      # @return [String]
      def get_user_score(driver, course_site_code, label)
        wait_until(Utils.short_wait) { user_score_tooltip_element(driver, course_site_code, label) }
        mouseover(driver, user_score_tooltip_element(driver, course_site_code, label))
        analytics_tooltip_element(course_site_code, label).when_visible Utils.short_wait
        analytics_tooltip_element(course_site_code, label).text
      end

      # Returns the 'page views' tooltip analytics for a given course site
      # @param driver [Selenium::WebDriver]
      # @param course_site_code [String]
      # @return [Array<String>]
      def page_view_tooltip(driver, course_site_code)
        get_tooltip_text(driver, course_site_code, 'Page views')
      end

      # Returns the 'assignments on time' tooltip analytics for a given course site
      # @param driver [Selenium::WebDriver]
      # @param course_site_code [String]
      # @return [Array<String>]
      def assignments_tooltip(driver, course_site_code)
        get_tooltip_text(driver, course_site_code, 'Assignments on time')
      end

      # Returns the 'participations' tooltip analytics for a given course site
      # @param driver [Selenium::WebDriver]
      # @param course_site_code [String]
      # @return [Array<String>]
      def participations_tooltip(driver, course_site_code)
        get_tooltip_text(driver, course_site_code, 'Participations')
      end

      # Returns the user's percentile displayed for a particular set of analytics data for a given course site, removing
      # the ordinal and 'percentile'
      # @param course_site_code [String]
      # @param label [String]
      # @return [String]
      def user_percentile(course_site_code, label)
        span_element(:xpath => "#{site_analytics_data_xpath(course_site_code, label)}//span").text[0..-14]
      end

      # Returns the analytics data shown for a particular set of analytics data for a given course site
      # @param driver [Selenium::WebDriver]
      # @param course_site_code [String]
      # @param label [String]
      # @return [Hash]
      def visible_analytics(driver, course_site_code, label)
        tooltip_analytics = get_tooltip_text(driver, course_site_code, label)
        user_score = get_user_score(driver, course_site_code, label).delete('User score: ')
        {
          :minimum => tooltip_analytics[4].delete('Minimum: '),
          :maximum => tooltip_analytics[0].delete('Maximum: '),
          :percentile_30 => tooltip_analytics[3][17..-1],
          :percentile_50 => tooltip_analytics[2][17..-1],
          :percentile_70 => tooltip_analytics[1][17..-1],
          :user_score => user_score,
          :user_percentile => user_percentile(course_site_code, label)
        }
      end

      # Returns the assignments-on-time analytics data shown for a given course site
      # @param driver [Selenium::WebDriver]
      # @param course_site_code [String]
      # @return [Hash]
      def visible_assignment_analytics(driver, course_site_code)
        visible_analytics(driver, course_site_code, 'Assignments on time')
      end

      # Returns the page-views analytics data shown for a given course site
      # @param driver [Selenium::WebDriver]
      # @param course_site_code [String]
      # @return [Hash]
      def visible_page_view_analytics(driver, course_site_code)
        visible_analytics(driver, course_site_code, 'Page views')
      end

      # Returns the participations analytics data shown for a given course site
      # @param driver [Selenium::WebDriver]
      # @param course_site_code [String]
      # @return [Hash]
      def visible_participation_analytics(driver, course_site_code)
        visible_analytics(driver, course_site_code, 'Participations')
      end

    end
  end
end
