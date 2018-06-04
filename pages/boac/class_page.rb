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
      span(:section_units, xpath: '//span[@data-ng-bind="section.units"]')
      span(:course_title, xpath: '//span[@data-ng-bind="section.title"]')
      div(:term_name, xpath: '//div[@data-ng-bind="section.termName"]')

      # Returns the course data shown in the left header pane plus term
      # @return [Hash]
      def visible_course_data
        {
          :code => (course_code if course_code?),
          :format => (section_format if section_format?),
          :number => (section_number if section_number?),
          :units => (section_units if section_units?),
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
      def student_site_code(student, node)
        el = div_element(xpath: "(#{list_view_user_xpath student}//span[@data-ng-bind=\"canvasSite.courseCode\"])[#{node}]")
        el.text if el.exists?
      end

      # Returns the XPath to the assignment grades element
      # @return [String]
      def assigns_score_xpath
        '//*[@data-ng-if="canvasSite.analytics.currentScore"]'
      end

      # Returns a student's assignments-submitted count for a site at a given node
      # @param student [User]
      # @param node [Integer]
      # @return [String]
      def student_assigns_submit(student, node)
        el = div_element(xpath: "(#{list_view_user_xpath student}//strong[@data-ng-bind=\"canvasSite.analytics.assignmentsSubmitted.student.raw\"])[#{node}]")
        el.text if el.exists?
      end

      # Returns the 'No Data' message shown for a student's assignment-submitted count for a site at a given node
      # @param student [User]
      # @param node [Integer]
      # @return [String]
      def student_assigns_submit_no_data(student, node)
        el = div_element(xpath: "(#{list_view_user_xpath student}//div[contains(@class,\"course-list-view-column-04\")]//div[@data-ng-repeat=\"canvasSite in student.enrollment.canvasSites\"])[#{node}][contains(.,\"No Data\")]")
        el.text if el.exists?
      end

      # Returns a student's max-assignments-submitted count for a site at a given node
      # @param student [User]
      # @param node [Integer]
      # @return [String]
      def student_assigns_submit_max(student, node)
        el = span_element(xpath: "(#{list_view_user_xpath student}//span[@data-ng-bind=\"canvasSite.analytics.assignmentsSubmitted.courseDeciles[10]\"])[#{node}]")
        el.text if el.exists?
      end

      # Returns a student's assignment total score for a site at a given node
      # @param student [User]
      # @param node [Integer]
      # @return [String]
      def student_assigns_score_no_data(driver, student, node)
        msg_el_xpath = "(#{list_view_user_xpath student}#{assigns_score_xpath})[#{node}][contains(.,\"No Data\")]"
        msg_el_exists = verify_block { driver.find_element(xpath: msg_el_xpath) }
        driver.find_element(xpath: msg_el_xpath).text if msg_el_exists
      end

      # Mouses over an assignment grades boxplot if it exists and returns the student's assignment total score for a site at a given node
      # @param driver [Selenium::WebDriver]
      # @param student [User]
      # @param node [Integer]
      # @return [String]
      def student_assigns_boxplot_score(driver, student, node)
        score_xpath = "(#{list_view_user_xpath student}#{assigns_score_xpath})[#{node}]//div[text()=\"User Score\"]/following-sibling::div"
        boxplot_exists = verify_block do
          mouseover(driver, driver.find_element(:xpath => "(#{list_view_user_xpath student}#{assigns_score_xpath})[#{node}]//*[@class=\"highcharts-boxplot-box\"]"))
          driver.find_element(:xpath => "#{score_xpath}")
        end
        driver.find_element(:xpath => "#{score_xpath}").text if boxplot_exists
      end

      # Returns a student's visible analytics data for a site at a given index
      # @param student [User]
      # @param index [Integer]
      # @return [Hash]
      def visible_student_site_data(driver, student, index)
        node = index + 1
        {
          :site_code => student_site_code(student, node),
          :assigns_submitted => student_assigns_submit(student, node),
          :assigns_submitted_max => student_assigns_submit_max(student, node),
          :assigns_submit_no_data => student_assigns_submit_no_data(student, node),
          :assigns_boxplot_score => student_assigns_boxplot_score(driver, student, node),
          :assigns_score_no_data => student_assigns_score_no_data(driver, student, node)
          # TODO - :last_activity
        }
      end

    end
  end
end
