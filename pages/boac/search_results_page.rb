require_relative '../../util/spec_helper'

module Page
  module BOACPages
    module UserListPages

      class SearchResultsPage

        include PageObject
        include Logging
        include Page
        include BOACPages
        include UserListPages

        # The result count displayed following a search
        # @param element [PageObject::Elements::Element]
        # @return [Integer]
        def results_count(element)
          element.when_visible Utils.short_wait
          count = element.text.include?('One') ? 1 : element.text.split(' ').first.to_i
          logger.debug "Results count: #{count}"
          count
        end

        # Returns the element containing the 'no results' message for a search
        # @param search_string [String]
        # @return [PageObject::Elements::Heading]
        def no_results_msg(search_string)
          h1_element(xpath: "//h1[text()=\"No results matching '#{search_string}'\"]")
        end

        # STUDENT SEARCH

        span(:student_results_count, xpath: '//span[@count="search.totalStudentCount"]')
        elements(:student_row, :div, xpath: '//div[contains(@data-ng-repeat,"student in students")]')
        elements(:student_row_sid, :div, xpath: '//div[contains(@data-ng-repeat,"student in students")]//span[@data-ng-bind="student.sid"]')

        # Returns the result count for a student search
        # @return [Integer]
        def student_search_results_count
          results_count student_results_count_element
        end

        # Returns all the SIDs displayed on the page
        # @return [Array<String>]
        def student_row_sids
          student_row_sid_elements.map &:text
        end

        # Checks if a given student is among search results. If more than 50 results exist, the student could be among them
        # but not displayed. In that case, returns true without further tests.
        # @param driver [Selenium::WebDriver]
        # @param student [BOACUser]
        # @return [boolean]
        def student_in_search_result?(driver, student)
          count = results_count student_results_count_element
          verify_block do
            if count > 50
              wait_until(2) { student_row_elements.length == 50 }
              logger.warn "Skipping a test with UID #{student.uid} because there are more than 50 results"
              sleep 1
            else
              wait_until(Utils.medium_wait) do
                student_row_elements.length == count
                student_row_sids.include? student.sis_id.to_s
              end
              visible_row_data = user_row_data(driver, student.sis_id)
              wait_until(2, "Expecting name #{student.last_name}, #{student.first_name}, got #{visible_row_data[:name]}") { visible_row_data[:name] == "#{student.last_name}, #{student.first_name}" }
              wait_until(2) { ![visible_row_data[:major], visible_row_data[:term_units], visible_row_data[:cumulative_units], visible_row_data[:gpa], visible_row_data[:alert_count]].any?(&:empty?) }
            end
          end
        end

        # Clicks the search results row for a given student
        # @param student [User]
        def click_student_result(student)
          wait_for_update_and_click div_element(xpath: "//div[contains(@class,'group-summary-row')][contains(.,'#{student.sis_id}')]//a")
          wait_for_spinner
        end

        # CLASS SEARCH

        span(:class_results_count, xpath: '//span[@count="search.totalCourseCount"]')
        elements(:class_row, :row, xpath: '//span[@data-ng-bind="course.courseName"]')

        # Checks if a given class is among search results. If more than 50 results exist, the class could be among them
        # but not displayed. In that case, returns true without further tests.
        # @param course_code [String]
        # @param section_number [String]
        # @return [boolean]
        def class_in_search_result?(course_code, section_number)
          count = results_count class_results_count_element
          verify_block do
            if count > 50
              wait_until(2) { class_row_elements.length == 50 }
              logger.warn "Skipping a test with #{course_code} because there are more than 50 results"
              sleep 1
            else
              wait_until(Utils.medium_wait) do
                class_row_elements.length == count
                class_link(course_code, section_number).when_visible(Utils.click_wait)
              end
            end
          end
        end

        # Returns the link to a class page
        # @param course_code [String]
        # @param section_number [String]
        # @@return [PageObject::Elements::Link]
        def class_link(course_code, section_number)
          link_element(xpath: "//a[contains(.,\"#{course_code}\")][contains(.,\"#{section_number}\")]")
        end

        # Clicks the link to a class page
        # @param course_code [String]
        # @param section_number [String]
        def click_class_result(course_code, section_number)
          wait_for_update_and_click class_link(course_code, section_number)
          wait_for_spinner
        end

        # CURATED GROUPS

        # Selects the add-to-group checkboxes for a given set of students
        # @param students [Array<User>]
        def select_students_to_add(students)
          logger.info "Adding student UIDs: #{students.map &:uid}"
          students.each { |s| wait_for_update_and_click checkbox_element(id: "#{s.uid}-curated-cohort-checkbox") }
        end

        # Adds a given set of students to an existing curated group
        # @param students [Array<User>]
        # @param group [CuratedGroup]
        def selector_add_students_to_group(students, group)
          select_students_to_add students
          select_group_and_add(students, group)
        end

        # Adds a given set of students to a new curated group, which is created as part of the process
        # @param students [Array<User>]
        # @param group [CuratedGroup]
        def selector_add_students_to_new_group(students, group)
          select_students_to_add students
          selector_create_new_group(students, group)
        end

        # Adds all the students on a page to a curated group
        # @param group [CuratedGroup]
        def selector_add_all_students_to_curated(group)
          wait_until(Utils.short_wait) { add_individual_to_curated_checkbox_elements.any? &:visible? }
          wait_for_update_and_click add_all_to_curated_checkbox_element
          logger.debug "There are #{add_individual_to_curated_checkbox_elements.length} individual checkboxes"
          students = add_individual_to_curated_checkbox_elements.map { |el| User.new({uid: el.attribute('id').split('-')[1]}) }
          select_group_and_add(students, group)
        end

      end
    end
  end
end
