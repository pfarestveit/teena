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
      :terms_in_attendance => sis_profile['termsInAttendance'].to_s,
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
    progress && progress['requirements'] && {
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
      :midpoint => course['midtermGrade'],
      :grade => course['grade'],
      :grading_basis => course['gradingBasis']
    }
  end

  def current_enrolled_course_codes
    courses = []
    if (term = current_term)
      # Ignore courses that are dropped, as these are not displayed on the cohort page
      enrolled_courses = courses(term).select do |c|
        enrolled_sections = sections(c).select { |s| %w(E W).include? section_sis_data(s)[:status] }
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

  def site_scores(site)
    analytics(site) && analytics(site)['courseCurrentScore']
  end

  def student_data(analytics)
    analytics['student']
  end

  def course_deciles(analytics)
    analytics['courseDeciles']
  end

  def user_score(analytics)
    score = student_data(analytics) && student_data(analytics)['raw']
    # Round zero decimal to whole number
    (score && score == score.floor) ? score.floor.to_s : score.to_s
  end

  # Given a category of analytics, collects the available data for comparison to what is shown in the UI
  def site_statistics(analytics)
    {
      :graphable => analytics['boxPlottable'],
      :user_percentile => analytics['displayPercentile'],
      :user_score => user_score(analytics),
      :maximum => (course_deciles(analytics) && course_deciles(analytics)[10].to_s),
      :percentile_70 => (course_deciles(analytics) && course_deciles(analytics)[7].to_s),
      :percentile_50 => (course_deciles(analytics) && course_deciles(analytics)[5].to_s),
      :percentile_30 => (course_deciles(analytics) && course_deciles(analytics)[3].to_s),
      :minimum => (course_deciles(analytics) && course_deciles(analytics)[0].to_s)
    }
  end

  # Returns a user's Assignments on Time analytics on a course site
  def site_assignments_on_time(site)
    site_statistics(analytics(site)['assignmentsOnTime']).merge!({:type => 'Assignments on Time'})
  end

  # Returns a user's Assignment Grades analytics on a course site
  def site_grades(site)
    site_statistics(analytics(site)['courseCurrentScore']).merge!({:type => 'Assignment Grades'})
  end

  # Returns a user's Page Views analytics on a course site
  def site_page_views(site)
    site_statistics(analytics(site)['pageViews']).merge!({:type => 'Page Views'})
  end

  # Returns all user data relevant to cohort search
  def collect_users_searchable_data(driver)
    users = BOACUtils.get_athletes
    users = users.select { |u| u.status == 'active' }
    users.map do |user|
      # Get the squad names to use as search criteria
      user_squad_names = user.sports.map do |squad_code|
        squad = Squad::SQUADS.find { |s| s.code == squad_code }
        squad.name
      end
      get_data(driver, user)
      {
        :sid => user.sis_id,
        :first_name => user.first_name,
        :first_name_sortable => user.first_name.gsub('-', ' ').delete(" -'.").downcase,
        :last_name => user.last_name,
        :last_name_sortable => user.last_name.gsub('-', ' ').delete(" -'.").downcase,
        :squad_names => user_squad_names,
        :level => user_sis_data[:level],
        :majors => user_sis_data[:majors],
        :gpa => user_sis_data[:cumulative_gpa],
        :units => user_sis_data[:cumulative_units]
      }
    end
  end

end
