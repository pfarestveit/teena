require_relative '../../util/spec_helper'

module Page
  module BOACPages
    module ClassPages

      class ClassListViewPage

        include PageObject
        include Logging
        include Page
        include BOACPages
        include ClassPages

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
          el.text if el.exists?
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
end
