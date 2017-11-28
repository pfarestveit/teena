require_relative '../../util/spec_helper'

class ApiUserAnalyticsPage

  include PageObject
  include Logging

  def get_data(driver, user)
    navigate_to "#{BOACUtils.base_url}/api/user/#{user.uid}/analytics"
    wait_until(Utils.long_wait) { driver.find_element(xpath: '//pre') }
    @parsed = JSON.parse driver.find_element(xpath: '//pre').text
  end

  # Canvas Profile

  def set_canvas_id(user)
    user.canvas_id = @parsed['canvasProfile']['id']
  end

  # SIS Profile

  def sis_profile
    @parsed['sisProfile']
  end

  def plan
    sis_profile['plan'] && sis_profile['plan']['description']
  end

  def level
    sis_profile['level'] && sis_profile['level']['description']
  end

  def cumulative_units
    units = sis_profile['cumulativeUnits']
    (units == units.floor) ? units.floor.to_s : units.to_s
  end

  def cumulative_gpa
    sis_profile['cumulativeGPA'] == 0 ? '--' : sis_profile['cumulativeGPA'].to_s
  end

  def degree_progress
    sis_profile['degreeProgress']
  end

  def writing_reqt
    degree_progress && degree_progress['entryLevelWriting']
  end

  def history_reqt
    degree_progress && degree_progress['americanHistory']
  end

  def cultures_reqt
    degree_progress && degree_progress['americanCultures']
  end

  def institutions_reqt
    degree_progress && degree_progress['americanInstitutions']
  end

  def language_reqt
    degree_progress && degree_progress['foreignLanguage']
  end

  def email
    sis_profile['emailAddress']
  end

  def phone
    sis_profile['phoneNumber'].to_s
  end

  # COURSES

  def courses
    @parsed['courses']
  end

  def course_site_name(course)
    course['courseName']
  end

  def course_site_code(course)
    course['courseCode']
  end

  def course_site_sis_sections(course)
    course['sisEnrollments'] && course['sisEnrollments'].map do |section|
      {
        :status => section['enrollmentStatus'],
        :number => section['sectionNumber'],
        :units => section['units'].to_s,
        :grading_basis => section['gradingBasis'],
        :ccn => section['ccn'],
        :grade => section['grade']
      }
    end
  end

  def site_page_views(course)
    course['analytics'] && course['analytics']['pageViews']
  end

  def site_assignments_on_time(course)
    course['analytics'] && course['analytics']['assignmentsOnTime']
  end

  def site_participations(course)
    course['analytics'] && course['analytics']['participations']
  end

  def student_percentile(analytics)
    analytics['student'] && analytics['student']['percentile']
  end

  def site_statistics(analytics)
    {
      :minimum => analytics['courseDeciles'][0].round.to_s,
      :maximum => analytics['courseDeciles'][10].round.to_s,
      :percentile_30 => analytics['courseDeciles'][3].round.to_s,
      :percentile_50 => analytics['courseDeciles'][5].round.to_s,
      :percentile_70 => analytics['courseDeciles'][7].round.to_s,
      :user_score => analytics['student']['raw'].round.to_s,
      :user_percentile => student_percentile(analytics) && student_percentile(analytics).round.to_s
    }
  end

end
