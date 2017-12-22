require_relative '../../util/spec_helper'

class ApiUserAnalyticsPage

  include PageObject
  include Logging

  def get_data(driver, user)
    logger.info "Getting data for UID #{user.uid}"
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

  def user_sis_data
    {
      :email => sis_profile['emailAddress'],
      :phone => sis_profile['phoneNumber'].to_s,
      :units_in_progress => (current_term ? formatted_units(current_term['enrolledUnits']) : '0') ,
      :cumulative_units => formatted_units(sis_profile['cumulativeUnits']),
      :cumulative_gpa => (sis_profile['cumulativeGPA'] == 0 ? '--' : sis_profile['cumulativeGPA'].to_s),
      :majors => majors,
      :colleges => colleges,
      :level => (sis_profile['level'] && sis_profile['level']['description']),
      :term_in_attendance => sis_profile['termsInAttendance'],
      :reqt_writing => (degree_progress && degree_progress[:writing]),
      :reqt_history => (degree_progress && degree_progress[:history]),
      :reqt_institutions => (degree_progress && degree_progress[:institutions]),
      :reqt_cultures => (degree_progress && degree_progress[:cultures])
    }
  end

  def majors
    sis_profile['plans'] && sis_profile['plans'].map { |p| p['description'] }
  end

  def colleges
    colleges = sis_profile['plans'] && sis_profile['plans'].map { |p| p['program'] }
    colleges.compact if colleges
  end

  def formatted_units(units_as_int)
    (units_as_int == units_as_int.floor) ? units_as_int.floor.to_s : units_as_int.to_s
  end

  def degree_progress
    progress = sis_profile['degreeProgress']
    progress && {
      :date => progress['reportDate'],
      :writing => progress['requirements']['entryLevelWriting']['status'],
      :cultures => progress['requirements']['americanCultures']['status'],
      :history => progress['requirements']['americanHistory']['status'],
      :institutions => progress['requirements']['americanInstitutions']['status']
    }
  end

  # COURSES

  def terms
    @parsed['enrollmentTerms']
  end

  def term_name(term)
    term['termName']
  end

  def current_term
    terms.find { |t| term_name(t) == BOACUtils.term }
  end

  def courses(term)
    term['enrollments']
  end

  def sections(course)
    course['sections']
  end

  def section_sis_data(section)
    {
      :ccn => section['ccn'],
      :number => "#{section['sectionNumber']}",
      :component => section['component'],
      :status => section['enrollmentStatus']
    }
  end

  def course_sis_data(course)
    {
      :code => course['displayName'],
      :title => course['title'].gsub(/\s+/, ' '),
      :units => course['units'].to_s,
      :grade => course['grade'],
      :grading_basis => course['gradingBasis']
    }
  end

  def current_enrolled_course_codes
    courses = []
    if (term = current_term)
      # Ignore courses that are waitlisted or dropped, as these are not displayed on the cohort page
      enrolled_courses = courses(term).select do |c|
        enrolled_sections = sections(c).select { |s| section_sis_data(s)[:status] == 'E' }
        enrolled_sections.any?
      end
      courses = enrolled_courses.map { |c| course_sis_data(c)[:code] }
    end
    courses
  end

  def dropped_sections(term)
    sections = term['droppedSections']
    sections && sections.map do |section|
      {
        :title => section['displayName'],
        :component => section['component'],
        :number => section['number']
      }
    end
  end

  # COURSE SITES

  def course_sites(course)
    course['canvasSites']
  end

  def unmatched_sites(term)
    term['unmatchedCanvasSites']
  end

  def site_metadata(site)
    {
      :code => site['courseCode'],
      :title => site['courseName'],
      :site_id => site['canvasCourseId']
    }
  end

  def analytics(site)
    site['analytics']
  end

  def site_page_views(site)
    analytics(site) && analytics(site)['pageViews']
  end

  def site_assignments_on_time(site)
    analytics(site) && analytics(site)['assignmentsOnTime']
  end

  def site_participations(site)
    analytics(site) && analytics(site)['participations']
  end

  def site_scores(site)
    analytics(site) && analytics(site)['courseCurrentScore']
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
