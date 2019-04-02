require_relative '../../util/spec_helper'

class BOACClassListViewPage

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACListViewPages
  include BOACClassPages
  include BOACGroupModalPages
  include BOACAddGroupSelectorPages

  elements(:student_link, :link, xpath: '//tr[contains(@class,"course-list-view-row")]//a')
  elements(:student_sid, :div, xpath: '//*[@class="student-sid demo-mode-blur"]')

  # Returns all the SIDs shown on list view
  # @return [Array<String>]
  def class_list_view_sids
    wait_until(Utils.medium_wait) { student_link_elements.any? }
    sleep Utils.click_wait
    student_sid_elements.map { |el| el.text.gsub(/(INACTIVE)/, '').gsub(/(WAITLISTED)/, '').strip }
  end

  # STUDENT SIS DATA

  # Returns the XPath for a student row in the class page table
  # @param student [BOACUser]
  # @return [String]
  def student_xpath(student)
    "//tr[contains(@class,\"course-list-view-row\")][contains(.,\"#{student.sis_id}\")]"
  end

  # Returns the level displayed for a student
  # @param student [BOACUser]
  # @return [String]
  def student_level(student)
    el = span_element(xpath: "#{student_xpath student}//span[@class='student-text']")
    el.text if el.exists?
  end

  # Returns the major(s) displayed for a student
  # @param driver [Selenium::WebDriver]
  # @param student [BOACUser]
  # @return [Array<String>]
  def student_majors(driver, student)
    els = driver.find_elements(xpath: "#{student_xpath student}//div[@class='student-text']")
    els.map &:text if els.any?
  end

  # Returns the sport(s) displayed for a student
  # @param driver [Selenium::WebDriver]
  # @param student [BOACUser]
  # @return [Array<String>]
  def student_sports(driver, student)
    els = driver.find_elements(xpath: "#{student_xpath student}//div[@class='student-teams']")
    els.map { |el| el.text.strip } if els.any?
  end

  # Returns the midpoint grade shown for a student
  # @param student [BOACUser]
  # @return [String]
  def student_mid_point_grade(student)
    el = span_element(xpath: "#{student_xpath student}/td[8]/span")
    el.text if el.exists?
  end

  # Returns the grading basis shown for a student
  # @param student [BOACUser]
  # @return [String]
  def student_grading_basis(student)
    el = span_element(xpath: "#{student_xpath student}/td[9]/span[@class='cohort-grading-basis']")
    el.text if el.exists?
  end

  # Returns the final grade shown for a student
  # @param student [BOACUser]
  # @return [String]
  def student_final_grade(student)
    el = span_element(xpath: "#{student_xpath student}/td[9]/span[@class='cohort-grade']")
    el.text if el.exists?
  end

  # Returns the SIS and sports data shown for a student
  # @param driver [Selenium::WebDriver]
  # @param student [BOACUser]
  # @return [Hash]
  def visible_student_sis_data(driver, student)
    {
      :level => student_level(student),
      :majors => student_majors(driver, student),
      :sports => student_sports(driver, student),
      :mid_point_grade => student_mid_point_grade(student),
      :grading_basis => student_grading_basis(student),
      :final_grade => student_final_grade(student)
    }
  end

  # STUDENT SITE DATA

  # Returns a student's course site code for a site at a given node
  # @param student [BOACUser]
  # @param node [Integer]
  # @return [String]
  def site_code(student, node)
    el = div_element(xpath: "#{student_xpath student}/td[4]//div[@class=\"course-list-view-column-canvas-sites-border\"][#{node}]/strong")
    el.text if el.exists?
  end

  # Returns the XPath to the assignment submission count element
  # @param student [BOACUser]
  # @param node [Integer]
  # @return [String]
  def assigns_submit_xpath(student, node)
    "#{student_xpath student}/td[5]/div[@class=\"course-list-view-column-canvas-sites\"]/div[#{node}]"
  end

  # Returns a student's assignments-submitted count for a site at a given node
  # @param student [BOACUser]
  # @param node [Integer]
  # @return [String]
  def assigns_submit_score(student, node)
    el = div_element(xpath: "#{assigns_submit_xpath(student, node)}/div/strong")
    el.text if el.exists?
  end

  # Returns a student's max-assignments-submitted count for a site at a given node
  # @param student [BOACUser]
  # @param node [Integer]
  # @return [String]
  def assigns_submit_max(student, node)
    el = span_element(xpath: "#{assigns_submit_xpath(student, node)}/div/div")
    el.text.split(' ')[1].delete(')') if el.exists?
  end

  # Returns the 'No Data' message shown for a student's assignment-submitted count for a site at a given node
  # @param student [BOACUser]
  # @param node [Integer]
  # @return [String]
  def assigns_submit_no_data(student, node)
    el = div_element(xpath: "#{assigns_submit_xpath(student, node)}/div[contains(.,\"No Data\")]")
    el.text if el.exists?
  end

  # Returns the XPath to the assignment grades element
  # @param student [BOACUser]
  # @param node [Integer]
  # @return [String]
  def assigns_grade_xpath(student, node)
    "#{student_xpath student}/td[6]/div[@class=\"course-list-view-column-canvas-sites\"]/div[#{node}]"
  end

  # Returns the student's assignment total score for a site at a given node. If a boxplot exists, mouses over it to reveal the score.
  # @param driver [Selenium::WebDriver]
  # @param student [BOACUser]
  # @param node [Integer]
  # @return [String]
  def assigns_grade_score(driver, student, node)
    score_xpath = "#{assigns_grade_xpath(student, node)}"
    has_boxplot = verify_block { mouseover(driver, driver.find_element(xpath: "#{score_xpath}#{boxplot_trigger_xpath}")) }
    el = has_boxplot ?
        div_element(xpath: "#{score_xpath}//div[text()=\"User Score\"]/following-sibling::div") :
        div_element(xpath: "#{score_xpath}//strong")
    el.text if el.exists?
  end

  # Returns a student's assignment total score No Data message for a site at a given node
  # @param student [BOACUser]
  # @param node [Integer]
  # @return [String]
  def assigns_grade_no_data(student, node)
    el = div_element(xpath: "#{assigns_grade_xpath(student, node)}[contains(.,\"No Data\")]")
    el.text.strip if el.exists?
  end

  # Returns a student's visible analytics data for a site at a given index
  # @param driver [Selenium::WebDriver]
  # @param student [BOACUser]
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
  # @param student [BOACUser]
  # @param node [Integer]
  # @return [String]
  def last_activity(student, node)
    el = span_element(xpath: "#{student_xpath student}/td[7]//div[@class=\"profile-boxplot-container\"][#{node}]")
    el.text.split(' ')[0] if el.exists?
  end

  # Returns both a course site code and a student's last activity on the site at a given index
  # @param student [BOACUser]
  # @param index [Integer]
  # @return [Hash]
  def visible_last_activity(student, index)
    node = index + 1
    wait_until(Utils.short_wait) { site_code(student, node) }
    {
      :site_code => site_code(student, node),
      :days => last_activity(student, node)
    }
  end

end
