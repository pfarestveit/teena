require_relative '../../util/spec_helper'

class ApiSectionPage

  include PageObject
  include Logging

  def get_data(driver, term_id, ccn)
    logger.info "Getting data for section #{ccn}"
    navigate_to "#{BOACUtils.base_url}/api/section/#{term_id}/#{ccn}"
    wait_until(Utils.long_wait) { driver.find_element(xpath: '//pre') }
    @parsed = JSON.parse driver.find_element(xpath: '//pre').text
  end

  def meetings
    @parsed['meetings'] && @parsed['meetings'].map do |meet|
      {
        :instructors => (meet['instructors'].map { |i| i.gsub(/\s+/, ' ') }),
        :days => meet['days'],
        :time => meet['time'],
        :location => (meet['location'] && meet['location'].gsub(/\s+/, ' '))
      }
    end
  end

  def students
    @parsed['students']
  end

  def student_sids
    students && students.map { |s| s['sid'] }
  end

  def student_uids
    students && students.map { |s| s['uid'] }
  end

  def student_enrollment(student)
    student['enrollment']
  end

  def student_sites(student)
    student_enrollment(student) && student_enrollment(student)['canvasSites']
  end

  def site_id(site)
    site['canvasCourseId']
  end

  def student_site_ids(student)
    api_student = students.find { |s| s['uid'] == student.uid }
    api_student && student_sites(api_student).map { |site| site_id site }
  end

end
