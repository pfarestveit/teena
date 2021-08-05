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

  elements(:student_link, :link, xpath: '//tr//a[contains(@href, "/student/")]')
  elements(:student_sid, :div, xpath: '//div[@class="student-sid"]')

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
    "//tr[contains(.,\"#{student.sis_id}\")]"
  end

  # Returns the level displayed for a student
  # @param student [BOACUser]
  # @return [String]
  def student_level(student)
    el = span_element(xpath: "#{student_xpath student}//div[contains(@id, '-level')]/span[@class='student-text']")
    el.text if el.exists?
  end

  # Returns inactive label, if any, shown for a student
  # @param student [BOACUser]
  # @return [String]
  def inactive_label(student)
    el = span_element(xpath: "#{student_xpath student}//div[contains(@class,\"student-sid\")]/span[contains(@id,\"-inactive\")]")
    el.text.strip if el.exists?
  end

  # Returns the major(s) displayed for a student
  # @param student [BOACUser]
  # @return [Array<String>]
  def student_majors( student)
    els = div_elements(xpath: "#{student_xpath student}//div[contains(@id, '-majors')]/div[@class='student-text']")
    els.map &:text if els.any?
  end

  # Returns the sport(s) displayed for a student
  # @param student [BOACUser]
  # @return [Array<String>]
  def student_sports( student)
    els = div_elements(xpath: "#{student_xpath student}//div[contains(@id, '-teams')]/div[@class='student-text']")
    els.map { |el| el.text.strip } if els.any?
  end

  # Returns the midpoint grade shown for a student
  # @param student [BOACUser]
  # @return [String]
  def student_mid_point_grade(student)
    el = span_element(xpath: "#{student_xpath student}/td[@data-label='Mid']//span")
    el.text if el.exists?
  end

  # Returns the grading basis shown for a student
  # @param student [BOACUser]
  # @return [String]
  def student_grading_basis(student)
    el = span_element(xpath: "#{student_xpath student}/td[@data-label='Final']//span[@class='cohort-grading-basis']")
    el.text if el.exists?
  end

  # Returns the graduation colleges shown for a student
  # @param student [BOACUser]
  # @return [String]
  def student_graduation_colleges(student)
    els = div_elements(xpath: "#{student_xpath student}//div[contains(@id, '-graduated-colleges')]/div[@class='student-text']")
    els.map { |el| el.text.strip } if els.any?
  end

  # Returns the graduation date shown for a student
  # @param student [BOACUser]
  # @return [String]
  def student_graduation_date(student)
    el = span_element(xpath: "#{student_xpath student}//div[contains(@id, '-graduated-date')]/span[@class='student-text']")
    el.text if el.exists?
  end

  # Returns the final grade shown for a student
  # @param student [BOACUser]
  # @return [String]
  def student_final_grade(student)
    el = span_element(xpath: "#{student_xpath student}/td[@data-label='Final']//span")
    el.text if el.exists?
  end

  # Returns the SIS and sports data shown for a student
  # @param student [BOACUser]
  # @return [Hash]
  def visible_student_sis_data(student)
    {
      :level => student_level(student),
      :majors => student_majors(student),
      :graduation_date => student_graduation_date(student),
      :graduation_colleges => student_graduation_colleges(student),
      :sports => student_sports(student),
      :mid_point_grade => student_mid_point_grade(student),
      :grading_basis => student_grading_basis(student),
      :final_grade => student_final_grade(student),
      :inactive => (inactive_label(student) == 'INACTIVE')
    }
  end

  # STUDENT SITE DATA

  # Returns a student's course site code for a site at a given node
  # @param student [BOACUser]
  # @param node [Integer]
  # @return [String]
  def site_code(student, node)
    el = div_element(xpath: "#{student_xpath student}/td[@data-label='Course Site(s)']/div/div/div[#{node}]/strong")
    el.text if el.exists?
  end

  # Returns the XPath to the assignment submission count element
  # @param student [BOACUser]
  # @param node [Integer]
  # @return [String]
  def assigns_submit_xpath(student, node)
    "#{student_xpath student}/td[@data-label='Assignments Submitted']/div/div/div[#{node}]"
  end

  # Returns a student's assignments-submitted count for a site at a given node
  # @param student [BOACUser]
  # @param node [Integer]
  # @return [String]
  def assigns_submit_score(student, node)
    score_xpath = "#{assigns_submit_xpath(student, node)}"
    logger.debug "Checking assignment submission score at XPath '#{score_xpath}#{boxplot_trigger_xpath}'"
    boxplot_xpath = "#{score_xpath}#{boxplot_trigger_xpath}"
    has_boxplot = verify_block { mouseover(div_element(xpath: boxplot_xpath)) }
    logger.debug "Has-boxplot is #{has_boxplot}"
    el = has_boxplot ?
             div_element(xpath: '//div[@class="highcharts-tooltip-container"][last()]//div[contains(text(), "User Score")]/following-sibling::div') :
             div_element(xpath: "#{score_xpath}//strong")
    if has_boxplot
      unless el.exists?
        logger.warn 'Shake it to the left!'
        mouseover(div_element(xpath: boxplot_xpath), -15)
      end
      unless el.exists?
        logger.warn 'Shake it to the right!'
        mouseover(div_element(xpath: boxplot_xpath), 15)
      end
    end
    el.text.split(' ').last if el.exists?
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
    "#{student_xpath student}/td[@data-label='Assignment Grades']/div/div/div[#{node}]"
  end

  # Returns the student's assignment total score for a site at a given node. If a boxplot exists, mouses over it to reveal the score.
  # @param student [BOACUser]
  # @param node [Integer]
  # @return [String]
  def assigns_grade_score(student, node)
    score_xpath = "#{assigns_grade_xpath(student, node)}"
    has_boxplot = verify_block { mouseover(div_element(xpath: "#{score_xpath}#{boxplot_trigger_xpath}")) }
    el = has_boxplot ?
             div_element(xpath: "#{score_xpath}//div[contains(text(), \"User score\")]") :
             div_element(xpath: "#{score_xpath}//strong")
    el.text.split.last if el.exists?
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
  # @param student [BOACUser]
  # @param index [Integer]
  # @return [Hash]
  def visible_assigns_data(student, index)
    node = index + 1
    {
      :site_code => site_code(student, node),
      :assigns_submitted => assigns_submit_score(student, node),
      :assigns_submit_no_data => assigns_submit_no_data(student, node),
      :assigns_grade => assigns_grade_score(student, node),
      :assigns_grade_no_data => assigns_grade_no_data(student, node)
    }
  end

  # Returns a student's visible last activity data for a site at a given node
  # @param student [BOACUser]
  # @param node [Integer]
  # @return [String]
  def last_activity(student, node)
    el = span_element(xpath: "#{student_xpath student}/td[@data-label='bCourses Activity']//div/div/div[#{node}]")
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
