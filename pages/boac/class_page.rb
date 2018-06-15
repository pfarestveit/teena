require_relative '../../util/spec_helper'

module Page
  module BOACPages

    class ClassPage

      include PageObject
      include Logging
      include Page
      include BOACPages

      # COURSE DATA

      def load_page(term_id, ccn)
        logger.info "Loading class page for term #{term_id} section #{ccn}"
        navigate_to "#{BOACUtils.base_url}/course/#{term_id}/#{ccn}"
        wait_for_spinner
        div_element(class: 'course-column-schedule').when_visible Utils.medium_wait
      end

      h1(:course_code, xpath: '//h1')
      span(:section_format, xpath: '//span[@data-ng-bind="section.instructionFormat"]')
      span(:section_number, xpath: '//span[@data-ng-bind="section.sectionNum"]')
      span(:section_units, xpath: '//span[@count="section.units"]')
      span(:course_title, xpath: '//span[@data-ng-bind="section.title"]')
      div(:term_name, xpath: '//div[@data-ng-bind="section.termName"]')

      # Returns the course data shown in the left header pane plus term
      # @return [Hash]
      def visible_course_data
        {
          :code => (course_code if course_code?),
          :format => (section_format if section_format?),
          :number => (section_number if section_number?),
          :units => (section_units.split.first if section_units?),
          :title => (course_title if course_title?),
          :term => (term_name if term_name?)
        }
      end

      # COURSE MEETING DATA

      # Returns the XPath of the course meeting element at a given node
      # @param node [Integer]
      # @return [String]
      def meeting_xpath(node)
        "//div[@data-ng-repeat=\"meeting in section.meetings\"][#{node}]"
      end

      # Returns the instructor names shown for a course meeting at a given node
      # @param node [Integer]
      # @return [Array<String>]
      def meeting_instructors(driver, node)
        els = driver.find_elements(xpath: "#{meeting_xpath node}//span[@data-ng-repeat=\"instructor in meeting.instructors\"]")
        els.map { |el| el.text.delete(',') }
      end

      # Returns the days shown for a course meeting at a given node
      # @param node [Integer]
      # @return [Array<String>]
      def meeting_days(node)
        el = div_element(xpath: "#{meeting_xpath node}//div[@data-ng-bind=\"meeting.days\"]")
        el.text if el.exists? && !el.text.empty?
      end

      # Returns the time shown for a course meeting at given node
      # @param node [Integer]
      # @return [Array<String>]
      def meeting_time(node)
        el = div_element(xpath: "#{meeting_xpath node}//div[@data-ng-bind=\"meeting.time\"]")
        el.text if el.exists? && !el.text.empty?
      end

      # Returns the location shown for a course meeting at a given node
      # @param node [Integer]
      # @return [Array<String>]
      def meeting_location(node)
        el = div_element(xpath: "#{meeting_xpath node}//div[@data-ng-bind=\"meeting.location\"]")
        el.text if el.exists? && !el.text.empty?
      end

      # Returns the meeting data shown for a course meeting at a given node
      # @param driver [Selenium::WebDriver]
      # @param node [Integer]
      # @return [Hash]
      def visible_meeting_data(driver, node)
        {
          :instructors => meeting_instructors(driver, node),
          :days => meeting_days(node),
          :time => meeting_time(node),
          :location => meeting_location(node)
        }
      end

      # STUDENT SIS DATA

      # Returns the midpoint grade shown for a student
      # @param student [User]
      # @return [String]
      def student_mid_point_grade(student)
        el = span_element(xpath: "#{list_view_user_xpath student}//span[@data-ng-bind=\"student.enrollment.midtermGrade\"]")
        el.text if el.exists?
      end

      # Returns the grading basis shown for a student
      # @param student [User]
      # @return [String]
      def student_grading_basis(student)
        el = span_element(xpath: "#{list_view_user_xpath student}//span[@data-ng-bind=\"student.enrollment.gradingBasis\"]")
        el.text if el.exists?
      end

      # Returns the final grade shown for a student
      # @param student [User]
      # @return [String]
      def student_final_grade(student)
        el = span_element(xpath: "#{list_view_user_xpath student}//span[@data-ng-bind=\"student.enrollment.grade\"]")
        el.text if el.exists?
      end

      # Returns the SIS and sports data shown for a student
      # @param driver [Selenium::WebDriver]
      # @param student [User]
      # @return [Hash]
      def visible_student_sis_data(driver, student)
        {
          :level => list_view_user_level(student),
          :majors => list_view_user_majors(driver, student),
          :sports => list_view_user_sports(driver, student),
          :mid_point_grade => student_mid_point_grade(student),
          :grading_basis => student_grading_basis(student),
          :final_grade => student_final_grade(student)
        }
      end

      # STUDENT SITE DATA

      # Returns a student's course site code for a site at a given node
      # @param student [User]
      # @param node [Integer]
      # @return [String]
      def site_code(student, node)
        el = div_element(xpath: "(#{list_view_user_xpath student}//span[@data-ng-bind=\"canvasSite.courseCode\"])[#{node}]")
        el.text if el.exists?
      end

      # Returns a student's assignments-submitted count for a site at a given node
      # @param student [User]
      # @param node [Integer]
      # @return [String]
      def assigns_submit_score(student, node)
        el = div_element(xpath: "(#{list_view_user_xpath student}//div[contains(@class,\"course-list-view-column-04\")]//div[@data-ng-repeat=\"canvasSite in student.enrollment.canvasSites\"])[#{node}]//strong[@data-ng-bind=\"canvasSite.analytics.assignmentsSubmitted.student.raw\"]")
        el.text if el.exists?
      end

      # Returns a student's max-assignments-submitted count for a site at a given node
      # @param student [User]
      # @param node [Integer]
      # @return [String]
      def assigns_submit_max(student, node)
        el = span_element(xpath: "(#{list_view_user_xpath student}//div[contains(@class,\"course-list-view-column-04\")]//div[@data-ng-repeat=\"canvasSite in student.enrollment.canvasSites\"])[#{node}]//span[@data-ng-bind=\"canvasSite.analytics.assignmentsSubmitted.courseDeciles[10]\"]")
        el.text if el.exists?
      end

      # Returns the 'No Data' message shown for a student's assignment-submitted count for a site at a given node
      # @param student [User]
      # @param node [Integer]
      # @return [String]
      def assigns_submit_no_data(student, node)
        el = div_element(xpath: "(#{list_view_user_xpath student}//div[contains(@class,\"course-list-view-column-04\")]//div[@data-ng-repeat=\"canvasSite in student.enrollment.canvasSites\"])[#{node}][contains(.,\"No Data\")]")
        el.text if el.exists?
      end

      # Returns the XPath to the assignment grades element
      # @param student [User]
      # @param node [Integer]
      # @return [String]
      def assigns_grade_xpath(student, node)
        "(#{list_view_user_xpath student}/div[@class=\"course-list-view-column-05 ng-scope\"]//div[@class=\"profile-boxplot-container ng-scope\"])[#{node}]"
      end

      # Returns the student's assignment total score for a site at a given node. If a boxplot exists, mouses over it to reveal the score.
      # @param driver [Selenium::WebDriver]
      # @param student [User]
      # @param node [Integer]
      # @return [String]
      def assigns_grade_score(driver, student, node)
        score_xpath = "(#{list_view_user_xpath student}/div[@class=\"course-list-view-column-05 ng-scope\"]//div[@class=\"profile-boxplot-container ng-scope\"])[#{node}]"
        has_boxplot = verify_block { mouseover(driver, driver.find_element(xpath: "#{score_xpath}//*[@class=\"highcharts-boxplot-box\"]")) }
        el = has_boxplot ?
            div_element(xpath: "#{score_xpath}//div[text()=\"User Score\"]/following-sibling::div") :
            div_element(xpath: "#{score_xpath}//strong[@data-ng-bind=\"canvasSite.analytics.currentScore.student.raw\"]")
        el.text if el.exists?
      end

      # Returns a student's assignment total score No Data message for a site at a given node
      # @param student [User]
      # @param node [Integer]
      # @return [String]
      def assigns_grade_no_data(student, node)
        msg_el = div_element(xpath: "#{assigns_grade_xpath(student, node)}[contains(.,\"No Data\")]")
        msg_el if msg_el.exists?
      end

      # Returns a student's visible analytics data for a site at a given index
      # @param driver [Selenium::WebDriver]
      # @param student [User]
      # @param index [Integer]
      # @return [Hash]
      def visible_assigns_data(driver, student, index)
        node = index + 1
        {
          :site_code => site_code(student, node),
          :assigns_submitted => assigns_submit_score(student, node),
          :assigns_submitted_max => assigns_submit_max(student, node),
          :assigns_submit_no_data => assigns_submit_no_data(student, node),
          :assigns_grade => assigns_grade_score(driver, student, node),
          :assigns_grade_no_data => assigns_grade_no_data(student, node)
        }
      end

      # Returns a student's visible last activity data for a site at a given node
      # @param student [User]
      # @param node [Integer]
      # @return [String]
      def last_activity(student, node)
        el = span_element(xpath: "(#{list_view_user_xpath student}/div[@class=\"course-list-view-column-06 ng-scope\"]//div[@class=\"profile-boxplot-container ng-scope\"])[#{node}]/span")
        el && el.text
      end

      # Returns both a course site code and a student's last activity on the site at a given index
      # @param student [User]
      # @param index [Integer]
      # @return [Hash]
      def visible_last_activity(student, index)
        node = index + 1
        {
          :site_code => site_code(student, node),
          :last_activity => last_activity(student, node)
        }
      end

    end
  end
end
