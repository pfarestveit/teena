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
      elements(:major, :h3, xpath: '//h3[@data-ng-bind="plan.description"]')
      elements(:college, :div, xpath: '//div[@data-ng-bind="plan.program"]')
      h3(:level, xpath: '//h3[@data-ng-bind="student.sisProfile.level.description"]')

      cell(:writing_reqt, xpath: '//td[text()="Entry Level Writing"]/following-sibling::td')
      cell(:history_reqt, xpath: '//td[text()="American History"]/following-sibling::td')
      cell(:institutions_reqt, xpath: '//td[text()="American Institutions"]/following-sibling::td')
      cell(:cultures_reqt, xpath: '//td[text()="American Cultures"]/following-sibling::td')

      elements(:course_site_code, :h3, xpath: '//h3[@data-ng-bind="course.courseCode"]')

      # Returns a user's SIS data visible on the student page
      # @return [Hash]
      def visible_sis_data
        {
          :name => name,
          :email => email_element.text,
          :phone => phone,
          :cumulative_units => cumulative_units,
          :cumulative_gpa => cumulative_gpa,
          :majors => (major_elements.map &:text),
          :colleges => (college_elements.map &:text),
          :level => level,
          :reqt_writing => writing_reqt.strip,
          :reqt_history => history_reqt.strip,
          :reqt_institutions => institutions_reqt.strip,
          :reqt_cultures => cultures_reqt.strip
        }
      end

      # COURSES

      button(:view_more_button, :class => 'student-profile-view-previous-semesters')

      # Clicks the button to expand previous semester data
      def click_view_previous_semesters
        logger.debug 'Expanding previous semesters'
        wait_for_load_and_click view_more_button_element
      end

      # Returns the XPath to the SIS data shown for a given course in a term
      # @param term_name [String]
      # @param course_code [String]
      # @return [String]
      def course_data_xpath(term_name, course_code)
        "//h2[text()=\"#{term_name}\"]/following-sibling::div[@data-ng-repeat=\"course in term.enrollments\"][contains(.,\"#{course_code}\")]"
      end

      # Returns the SIS data shown for a course with a given course code
      # @param term_name [String]
      # @param course_code [String]
      # @return [Hash]
      def visible_course_sis_data(term_name, course_code)
        course_xpath = course_data_xpath(term_name, course_code)
        title_xpath = "#{course_xpath}//h4"
        units_xpath = "#{course_xpath}//div[contains(@class, 'student-profile-class-units')]"
        grading_basis_xpath = "#{course_xpath}//div[contains(@class, 'student-profile-class-grading-basis')]"
        grade_xpath = "#{course_xpath}//div[contains(@class, 'student-profile-class-grade')]"
        {
          :title => (h4_element(:xpath => title_xpath).text if h4_element(:xpath => title_xpath).exists?),
          :units => (div_element(:xpath => units_xpath).text.delete('Units').strip if div_element(:xpath => units_xpath).exists?),
          :grading_basis => (div_element(:xpath => grading_basis_xpath).text if (div_element(:xpath => grading_basis_xpath).exists? && !div_element(:xpath => grade_xpath).exists?)),
          :grade => (div_element(:xpath => grade_xpath).text if div_element(:xpath => grade_xpath).exists?)
        }
      end

      # Returns the XPath to the SIS data shown for a given section in a course with a specific component type (e.g., LEC, DIS)
      # @param term_name [String]
      # @param course_code [String]
      # @param component [String]
      # @return [String]
      def section_data_xpath(term_name, course_code, component)
        "#{course_data_xpath(term_name, course_code)}//div[@class='student-profile-class-sections']/div[contains(.,'#{component}')]"
      end

      # Returns the SIS data shown for a given section in a course with a specific component type (e.g., LEC, DIS)
      # @param term_name [String]
      # @param course_code [String]
      # @param component [String]
      # @return [Hash]
      def visible_section_sis_data(term_name, course_code, component)
        section_xpath = section_data_xpath(term_name, course_code, component)
        status_xpath = "#{section_xpath}//span[contains(@data-ng-if,'section.enrollmentStatus')]"
        number_xpath = "#{section_xpath}//span[@data-ng-bind='section.sectionNumber']"
        {
          :status => (span_element(:xpath => status_xpath).text if span_element(:xpath => status_xpath).exists?),
          :number => (span_element(:xpath => number_xpath).text if span_element(:xpath => number_xpath).exists?)
        }
      end

      # Returns the element containing a dropped section
      # @param term_name [String]
      # @param course_code [String]
      # @param component [String]
      # @param number [String]
      # @return [PageObject::Elements::Div]
      def visible_dropped_section_data(term_name, course_code, component, number)
        div_element(:xpath => "//h2[text()=\"#{term_name}\"]/following-sibling::div//div[@class=\"student-profile-dropped-section-title\"][contains(.,\"#{course_code}\")][contains(.,\"#{component}\")][contains(.,\"#{number}\")]")
      end

      # COURSE SITES

      # Returns the XPath to the first course site associated with a course in a term
      # @param term_name [String]
      # @param course_code [String]
      # @param site_title [String]
      # @return [String]
      def course_site_xpath(term_name, course_code, site_title)
        "#{course_data_xpath(term_name, course_code)}/div[@data-ng-repeat='canvasSite in course.canvasSites'][contains(.,\"#{site_title}\")]"
      end

      # Returns the XPath to a course site in a term not matched to a SIS enrollment
      # @param term_name [String]
      # @param site_title [String]
      # @param index [Integer]
      # @return [String]
      def unmatched_site_xpath(term_name, site_title, index)
        "//h2[text()=\"#{term_name}\"]/following-sibling::div[@data-ng-if='term.unmatchedCanvasSites.length']/div[@data-ng-repeat='canvasSite in term.unmatchedCanvasSites'][#{index + 1}]//h3[text()=\"#{site_title}\"]/following-sibling::*[name()='course-site-metrics']/ul"
      end

      # Returns the XPath to a particular set of analytics data for a site, for example 'page views'
      # @param site_xpath [String]
      # @param label [String]
      # @return [String]
      def site_analytics_data_xpath(site_xpath, label)
        "#{site_xpath}/li[contains(.,'#{label}:')]"
      end

      # Returns the XPath to the boxplot graph for a particular set of analytics data for a given site, for example 'page views'
      # @param site_xpath [String]
      # @param label [String]
      # @return [String]
      def site_boxplot_xpath(site_xpath, label)
        "#{site_analytics_data_xpath(site_xpath, label)}/div[contains(@class,'boxplot-container')]//*[local-name()='svg']/*[name()='g'][@class='highcharts-series-group']"
      end

      # Returns the element that triggers the analytics tooltip for a particular set of analytics data for a given site, for example 'page views'
      # @param driver [Selenium::WebDriver]
      # @param site_xpath [String]
      # @param label [String]
      # @return [Selenium::WebDriver::Element]
      def analytics_trigger_element(driver, site_xpath, label)
        driver.find_element(xpath: "#{site_boxplot_xpath(site_xpath, label)}/*[name()='g']/*[name()='g']/*[name()='path'][3]")
      end

      # Returns the element containing the analytics tooltip for a particular set of analytics data for a given site, for example 'page views'
      # @param site_xpath [String]
      # @param label [String]
      # @return [PageObject::Elements::Div]
      def analytics_tooltip_element(site_xpath, label)
        div_element(:xpath => "#{site_analytics_data_xpath(site_xpath, label)}//div[contains(@class,'highcharts-tooltip')]")
      end

      # Checks the existence of a 'no data' message for a particular set of analytics for a given site, for example 'page views'
      # @param site_xpath [String]
      # @param label [String]
      # @return [boolean]
      def no_data?(site_xpath, label)
        span_element(:xpath => "#{site_analytics_data_xpath(site_xpath, label)}/span[text()='No data']").exists?
      end

      # Checks the existence of a 'no data' message for assignments on time analytics for a given site
      # @param site_xpath [String]
      # @return [boolean]
      def no_assignment_data?(site_xpath)
        no_data?(site_xpath, 'Assignments on time')
      end

      # Checks the existence of a 'no data' message for page view analytics for a given site
      # @param site_xpath [String]
      # @return [boolean]
      def no_page_view_data?(site_xpath)
        no_data?(site_xpath, 'Page views')
      end

      # Checks the existence of a 'no data' message for participations analytics for a given site
      # @param site_xpath [String]
      # @return [boolean]
      def no_participations_data?(site_xpath)
        no_data?(site_xpath, 'Participations')
      end

      # Mouses over a boxplot for a particular set of analytics data for a given site, for example 'page views', and returns
      # the analytics data that appears
      # @param driver [Selenium::WebDriver]
      # @param site_xpath [String]
      # @param label [String]
      # @return [Array<String>]
      def get_tooltip_text(driver, site_xpath, label)
        wait_until(Utils.short_wait) { analytics_trigger_element(driver, site_xpath, label) }
        # Add a vertical offset to the mouseover in case the user score tooltip trigger is bang on top of the analytics tooltip trigger
        mouseover(driver, analytics_trigger_element(driver, site_xpath, label), 0, 5)
        analytics_tooltip_element(site_xpath, label).when_visible Utils.short_wait
        analytics_tooltip_element(site_xpath, label).text.split "\n"
      end

      # Returns the 'page views' tooltip analytics for a given site
      # @param driver [Selenium::WebDriver]
      # @param site_xpath [String]
      # @return [Array<String>]
      def page_view_tooltip(driver, site_xpath)
        get_tooltip_text(driver, site_xpath, 'Page views')
      end

      # Returns the 'assignments on time' tooltip analytics for a given site
      # @param driver [Selenium::WebDriver]
      # @param site_xpath [String]
      # @return [Array<String>]
      def assignments_tooltip(driver, site_xpath)
        get_tooltip_text(driver, site_xpath, 'Assignments on time')
      end

      # Returns the 'participations' tooltip analytics for a given site
      # @param driver [Selenium::WebDriver]
      # @param site_xpath [String]
      # @return [Array<String>]
      def participations_tooltip(driver, site_xpath)
        get_tooltip_text(driver, site_xpath, 'Participations')
      end

      # Returns the element containing the user score tooltip for a particular set of analytics data for a given site, for example 'page views'
      # @param driver [Selenium::WebDriver]
      # @param site_xpath [String]
      # @param label [String]
      # @return
      def user_score_trigger_element(driver, site_xpath, label)
        driver.find_element(xpath: "#{site_boxplot_xpath(site_xpath, label)}/*[name()='g'][last()]")
      end

      # Mouses over a boxplot for a particular set of analytics data for a given site, for example 'page views', and returns
      # the user score that appears
      # @param driver [Selenium::WebDriver]
      # @param site_xpath [String]
      # @param label [String]
      # @return [String]
      def get_user_score(driver, site_xpath, label)
        wait_until(Utils.short_wait) { user_score_trigger_element(driver, site_xpath, label) }
        mouseover(driver, user_score_trigger_element(driver, site_xpath, label))
        analytics_tooltip_element(site_xpath, label).when_visible Utils.short_wait
        analytics_tooltip_element(site_xpath, label).text
      end

      # Returns the user's percentile displayed for a particular set of analytics data for a given site, removing
      # the ordinal and 'percentile'
      # @param site_xpath [String]
      # @param label [String]
      # @return [String]
      def user_percentile(site_xpath, label)
        span_element(:xpath => "#{site_analytics_data_xpath(site_xpath, label)}//span").text[0..-14]
      end

      # Returns the analytics data shown for a particular set of analytics data for a given site
      # @param driver [Selenium::WebDriver]
      # @param site_xpath [String]
      # @param label [String]
      # @return [Hash]
      def visible_analytics(driver, site_xpath, label)
        tooltip_analytics = get_tooltip_text(driver, site_xpath, label)
        user_score = get_user_score(driver, site_xpath, label).delete('User score: ')
        {
          :minimum => tooltip_analytics[4].delete('Minimum: '),
          :maximum => tooltip_analytics[0].delete('Maximum: '),
          :percentile_30 => tooltip_analytics[3][17..-1],
          :percentile_50 => tooltip_analytics[2][17..-1],
          :percentile_70 => tooltip_analytics[1][17..-1],
          :user_score => user_score,
          :user_percentile => user_percentile(site_xpath, label)
        }
      end

      # Returns the assignments-on-time analytics data shown for a given site
      # @param driver [Selenium::WebDriver]
      # @param site_xpath [String]
      # @return [Hash]
      def visible_assignment_analytics(driver, site_xpath)
        visible_analytics(driver, site_xpath, 'Assignments on time')
      end

      # Returns the page-views analytics data shown for a given site
      # @param driver [Selenium::WebDriver]
      # @param site_xpath [String]
      # @return [Hash]
      def visible_page_view_analytics(driver, site_xpath)
        visible_analytics(driver, site_xpath, 'Page views')
      end

      # Returns the participations analytics data shown for a given site
      # @param driver [Selenium::WebDriver]
      # @param site_xpath [String]
      # @return [Hash]
      def visible_participation_analytics(driver, site_xpath)
        visible_analytics(driver, site_xpath, 'Participations')
      end

    end
  end
end
