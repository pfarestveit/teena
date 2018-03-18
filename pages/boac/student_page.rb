require_relative '../../util/spec_helper'

module Page

  module BOACPages

    class StudentPage

      include PageObject
      include Logging
      include Page
      include BOACPages

      link(:return_to_cohort, xpath: '//a[contains(.,"Return to cohort")]')

      h1(:name, class: 'profile-header-name')
      h2(:preferred_name, class: 'profile-header-name-preferred')
      span(:phone, xpath: '//span[@data-ng-bind="student.sisProfile.phoneNumber"]')
      link(:email, xpath: '//a[@data-ng-bind="student.sisProfile.emailAddress"]')
      div(:cumulative_units, xpath: '//div[@data-ng-bind="student.sisProfile.cumulativeUnits"]')
      div(:cumulative_gpa, xpath: '//div[contains(@data-ng-bind,"student.sisProfile.cumulativeGPA")]')
      h4(:inactive_flag, xpath: '//h4[text()="INACTIVE"]')
      elements(:major, :h4, xpath: '//div[@data-ng-repeat="plan in student.sisProfile.plans"]/h4')
      elements(:college, :div, xpath: '//div[@data-ng-bind="plan.program"]')
      h4(:level, xpath: '//h4[@data-ng-bind="student.sisProfile.level.description"]')
      span(:terms_in_attendance, xpath: '//div[@data-ng-if="student.sisProfile.termsInAttendance"]')
      span(:expected_graduation, xpath: '//span[@data-ng-bind="student.sisProfile.expectedGraduationTerm.name"]')

      cell(:writing_reqt, xpath: '//td[text()="Entry Level Writing"]/following-sibling::td')
      cell(:history_reqt, xpath: '//td[text()="American History"]/following-sibling::td')
      cell(:institutions_reqt, xpath: '//td[text()="American Institutions"]/following-sibling::td')
      cell(:cultures_reqt, xpath: '//td[text()="American Cultures"]/following-sibling::td')

      elements(:course_site_code, :h3, xpath: '//h3[@data-ng-bind="course.courseCode"]')

      # Loads a student page directly
      # @param user [User]
      def load_page(user)
        logger.info "Loading student page for UID #{user.uid}"
        navigate_to "#{BOACUtils.base_url}/student/#{user.uid}"
      end

      # Clicks the 'return to cohort' link
      def click_return_to_cohort
        logger.debug 'Returning to cohort'
        wait_for_load_and_click return_to_cohort_element
      end

      # Returns a user's SIS data visible on the student page
      # @return [Hash]
      def visible_sis_data
        {
          :name => name,
          :preferred_name => (preferred_name if preferred_name?),
          :email => email_element.text,
          :phone => phone,
          :cumulative_units => cumulative_units,
          :cumulative_gpa => cumulative_gpa,
          :majors => (major_elements.map &:text),
          :colleges => (college_elements.map &:text),
          :level => level,
          :terms_in_attendance => (terms_in_attendance if terms_in_attendance?),
          :expected_graduation => expected_graduation,
          :reqt_writing => (writing_reqt.strip if writing_reqt_element.exists?),
          :reqt_history => (history_reqt.strip if history_reqt_element.exists?),
          :reqt_institutions => (institutions_reqt.strip if institutions_reqt_element.exists?),
          :reqt_cultures => (cultures_reqt.strip if cultures_reqt_element.exists?)
        }
      end

      # COURSES

      button(:view_more_button, :xpath => '//button[contains(.,"View Previous Semesters")]')

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
        "//h3[text()=\"#{term_name}\"]/following-sibling::*[name()='uib-accordion']//div[@data-ng-repeat=\"course in term.enrollments\"][contains(.,\"#{course_code}\")]"
      end

      # Returns the SIS data shown for a course with a given course code
      # @param term_name [String]
      # @param course_code [String]
      # @return [Hash]
      def visible_course_sis_data(term_name, course_code)
        course_xpath = course_data_xpath(term_name, course_code)
        title_xpath = "#{course_xpath}//h5"
        units_xpath = "#{course_xpath}//span[@count='course.units']"
        grading_basis_xpath = "#{course_xpath}//span[contains(@class, 'profile-class-grading-basis')]"
        mid_point_grade_xpath = "#{course_xpath}//span[contains(@data-ng-bind,'course.midtermGrade')]"
        grade_xpath = "#{course_xpath}//span[contains(@data-ng-bind, 'course.grade')]"
        wait_list_xpath = "#{course_xpath}//div[@data-ng-if='course.waitlisted']"
        {
          :title => (h4_element(:xpath => title_xpath).text if h4_element(:xpath => title_xpath).exists?),
          :units => (div_element(:xpath => units_xpath).text.delete('Units').strip if div_element(:xpath => units_xpath).exists?),
          :grading_basis => (span_element(:xpath => grading_basis_xpath).text if (span_element(:xpath => grading_basis_xpath).exists? && !span_element(:xpath => grade_xpath).exists?)),
          :mid_point_grade => (span_element(:xpath => mid_point_grade_xpath).text if span_element(:xpath => mid_point_grade_xpath).exists?),
          :grade => (span_element(:xpath => grade_xpath).text if span_element(:xpath => grade_xpath).exists?),
          :wait_list => (div_element(:xpath => wait_list_xpath).exists?)
        }
      end

      # Returns the XPath to the SIS data shown for a given section in a course with a specific component type (e.g., LEC, DIS)
      # @param term_name [String]
      # @param course_code [String]
      # @param index [Integer]
      # @return [String]
      def section_data_xpath(term_name, course_code, index)
        "#{course_data_xpath(term_name, course_code)}//div[@data-ng-repeat='section in course.sections'][#{index + 1}]"
      end

      # Returns the SIS data shown for a given section in a course at a specific index
      # @param term_name [String]
      # @param course_code [String]
      # @param index [Integer]
      # @return [Hash]
      def visible_section_sis_data(term_name, course_code, index)
        section_xpath = section_data_xpath(term_name, course_code, index)
        number_xpath = "#{section_xpath}//span[@data-ng-bind='section.sectionNumber']"
        {
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
        div_element(:xpath => "//h2[text()=\"#{term_name}\"]/following-sibling::div//div[@class='student-profile-dropped-section-title'][contains(.,\"#{course_code}\")][contains(.,\"#{component}\")][contains(.,\"#{number}\")]")
      end

      # COURSE SITES

      # Returns the element for expanding or collapsing course data
      # @param term_name [String]
      # @param course_code [String]
      # @return [PageObject::Elements::Link]
      def course_data_toggle(term_name, course_code)
        link_element(:xpath => "#{course_data_xpath(term_name, course_code)}//a")
      end

      # Expands course data
      # @param term_name [String]
      # @param course_code [String]
      def expand_course_data(term_name, course_code)
        wait_for_update_and_click_js course_data_toggle(term_name, course_code)
      end

      # Returns the XPath to a course site associated with a course in a term
      # @param term_name [String]
      # @param course_code [String]
      # @param index [Integer]
      # @return [String]
      def course_site_xpath(term_name, course_code, index)
        "#{course_data_xpath(term_name, course_code)}//div[@data-ng-repeat='canvasSite in course.canvasSites'][#{index + 1}]"
      end

      # Returns the XPath to a course site in a term not matched to a SIS enrollment
      # @param term_name [String]
      # @param site_code [String]
      # @return [String]
      def unmatched_site_xpath(term_name, site_code)
        "//h2[text()=\"#{term_name}\"]/following-sibling::div[@data-ng-repeat='canvasSite in term.unmatchedCanvasSites']//h3[text()=\"#{site_code}\"]/following-sibling::*[name()='course-site-metrics']"
      end

      # Returns the XPath to the user percentile analytics data for a given category, for example 'page views'
      # @param site_xpath [String]
      # @param label [String]
      # @return [String]
      def site_analytics_percentile_xpath(site_xpath, label)
        "#{site_xpath}//td[text()='#{label}']/following-sibling::td[1]"
      end

      # Returns the XPath to the detailed score and percentile analytics data for a given category, for example 'page views'
      # @param site_xpath [String]
      # @param label [String]
      # @return [String]
      def site_analytics_score_xpath(site_xpath, label)
        "#{site_xpath}//td[text()='#{label}']/following-sibling::td[2]"
      end

      # Returns the XPath to the boxplot graph for a particular set of analytics data for a given site, for example 'page views'
      # @param site_xpath [String]
      # @param label [String]
      # @return [String]
      def site_boxplot_xpath(site_xpath, label)
        "#{site_analytics_score_xpath(site_xpath, label)}/div[contains(@class,'student-profile-boxplot')]//*[local-name()='svg']/*[name()='g'][@class='highcharts-series-group']"
      end

      # Returns the element that triggers the analytics tooltip for a particular set of analytics data for a given site, for example 'page views'
      # @param driver [Selenium::WebDriver]
      # @param site_xpath [String]
      # @param label [String]
      # @return [Selenium::WebDriver::Element]
      def analytics_trigger_element(driver, site_xpath, label)
        driver.find_element(:xpath => "#{site_boxplot_xpath(site_xpath, label)}/*[name()='g']/*[name()='g']/*[name()='path'][3]")
      end

      # Checks the existence of a 'no data' message for a particular set of analytics for a given site, for example 'page views'
      # @param site_xpath [String]
      # @param label [String]
      # @return [boolean]
      def no_data?(site_xpath, label)
        cell_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}[contains(.,'No Data')]").exists?
      end

      # Returns the user's percentile displayed for a particular set of analytics data for a given site
      # @param site_xpath [String]
      # @param label [String]
      # @return [String]
      def perc_round(site_xpath, label)
        cell_element(:xpath => "#{site_analytics_percentile_xpath(site_xpath, label)}/strong").text
      end

      # When a boxplot is shown for a set of analytics, returns the user score shown on the tooltip
      # @param site_xpath [String]
      # @param label [String]
      # @return [String]
      def graphable_user_score(site_xpath, label)
        el = div_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}//div[@class='student-profile-tooltip-header']/div[2]")
        el && el.text
      end

      # When no boxplot is shown for a set of analytics, returns the user score shown
      # @param site_xpath [String]
      # @param label [String]
      # @return [String]
      def non_graphable_user_score(site_xpath, label)
        el = cell_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}/strong")
        el && el.text
      end

      # When no boxplot is shown for a set of analytics, returns the maximum score shown
      # @param site_xpath [String]
      # @param label [String]
      # @return [String]
      def non_graphable_maximum(site_xpath, label)
        el = cell_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}/span/span")
        el && el.text
      end

      # Returns all the analytics data shown for a given category, whether with boxplot or without
      # @param driver [Selenium::WebDriver]
      # @param site_xpath [String]
      # @param label [String]
      # @param api_analytics [Hash]
      # @return [Hash]
      def visible_analytics(driver, site_xpath, label, api_analytics)
        # If a boxplot should be present, hover over it to reveal the tooltip detail
        if api_analytics[:graphable]
          wait_until(Utils.short_wait) { analytics_trigger_element(driver, site_xpath, label) }
          mouseover(driver, analytics_trigger_element(driver, site_xpath, label))
          div_element(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}//div[contains(@class,'highcharts-tooltip')]").when_visible Utils.short_wait
        end
        tool_tip_detail_elements = driver.find_elements(:xpath => "#{site_analytics_score_xpath(site_xpath, label)}//div[@class='student-profile-tooltip-content']//div[@class='student-profile-tooltip-value']")
        tool_tip_detail = []
        tool_tip_detail = tool_tip_detail_elements.map &:text if tool_tip_detail_elements.any?
        {
          :perc_round => perc_round(site_xpath, label),
          :score => (api_analytics[:graphable] ? graphable_user_score(site_xpath, label) : non_graphable_user_score(site_xpath, label)),
          :max => (api_analytics[:graphable] ? tool_tip_detail[0] : non_graphable_maximum(site_xpath, label)) ,
          :perc_70 => tool_tip_detail[1],
          :perc_50 => tool_tip_detail[2],
          :perc_30 => tool_tip_detail[3],
          :minimum => tool_tip_detail[4]
        }
      end

      # Returns the assignments-on-time analytics data shown for a given site
      # @param driver [Selenium::WebDriver]
      # @param site_xpath [String]
      # @param api_analytics [Hash]
      # @return [Hash]
      def visible_assignment_analytics(driver, site_xpath, api_analytics)
        visible_analytics(driver, site_xpath, 'Assignments on Time', api_analytics)
      end

      # Returns the assignments-grades analytics data shown for a given site
      # @param driver [Selenium::WebDriver]
      # @param site_xpath [String]
      # @param api_analytics [Hash]
      # @return [Hash]
      def visible_grades_analytics(driver, site_xpath, api_analytics)
        visible_analytics(driver, site_xpath, 'Assignment Grades', api_analytics)
      end

      # Returns the page-views analytics data shown for a given site
      # @param driver [Selenium::WebDriver]
      # @param site_xpath [String]
      # @param api_analytics [Hash]
      # @return [Hash]
      def visible_page_view_analytics(driver, site_xpath, api_analytics)
        visible_analytics(driver, site_xpath, 'Page Views', api_analytics)
      end

      # Returns the participations analytics data shown for a given site
      # @param driver [Selenium::WebDriver]
      # @param site_xpath [String]
      # @param api_analytics [Hash]
      # @return [Hash]
      def visible_participation_analytics(driver, site_xpath, api_analytics)
        visible_analytics(driver, site_xpath, 'Participations', api_analytics)
      end

    end
  end
end
