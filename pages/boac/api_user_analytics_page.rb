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
    user.canvas_id = @parsed['canvasProfile']['canvas_id']
  end

  # SIS Profile

  def sis_profile
    @parsed['sisProfile']
  end

  def user_sis_data
    {
      :email => (sis_profile && sis_profile['emailAddress']),
      :phone => (sis_profile && sis_profile['phoneNumber'].to_s),
      :units_in_progress => (current_term ? formatted_units(current_term['enrolledUnits']) : '0') ,
      :cumulative_units => (sis_profile && formatted_units(sis_profile['cumulativeUnits'])),
      :cumulative_gpa => (sis_profile && (sis_profile['cumulativeGPA'] == 0 ? '--' : sis_profile['cumulativeGPA'].to_s)),
      :majors => (sis_profile && majors),
      :colleges => (sis_profile && colleges),
      :level => (sis_profile && (sis_profile['level'] && sis_profile['level']['description'])),
      :terms_in_attendance => (sis_profile && sis_profile['termsInAttendance'].to_s),
      :expected_graduation => (sis_profile && sis_profile['expectedGraduationTerm'] && sis_profile['expectedGraduationTerm']['name']),
      :reqt_writing => (sis_profile && degree_progress && degree_progress[:writing]),
      :reqt_history => (sis_profile && degree_progress && degree_progress[:history]),
      :reqt_institutions => (sis_profile && degree_progress && degree_progress[:institutions]),
      :reqt_cultures => (sis_profile && degree_progress && degree_progress[:cultures])
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

  def term_id(term)
    term['termId']
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

  def course_display_name(course)
    course['displayName']
  end

  def section_sis_data(section)
    {
      :ccn => section['ccn'],
      :number => "#{section['sectionNumber']}",
      :component => section['component'],
      :units => (section['units'].floor == section['units'] ? section['units'].floor.to_s : section['units'].to_s),
      :primary => section['primary'],
      :status => section['enrollmentStatus']
    }
  end

  def course_sis_data(course)
    {
      :code => course_display_name(course),
      :title => course['title'].gsub(/\s+/, ' '),
      :units => (course['units'].floor == course['units'] ? course['units'].floor.to_s : course['units'].to_s),
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

  def score(analytics)
    score = student_data(analytics) && student_data(analytics)['raw']
    # Round zero decimal to whole number
    (score && score == score.floor) ? score.floor.to_s : score.to_s
  end

  # Given a category of analytics, collects the available data for comparison to what is shown in the UI
  def site_statistics(analytics)
    {
      :graphable => analytics['boxPlottable'],
      :perc => student_data(analytics) && student_data(analytics)['percentile'],
      :perc_round => student_data(analytics) && student_data(analytics)['roundedUpPercentile'],
      :score => score(analytics),
      :max => (course_deciles(analytics) && course_deciles(analytics)[10].to_s),
      :perc_70 => (course_deciles(analytics) && course_deciles(analytics)[7].to_s),
      :perc_50 => (course_deciles(analytics) && course_deciles(analytics)[5].to_s),
      :perc_30 => (course_deciles(analytics) && course_deciles(analytics)[3].to_s),
      :min => (course_deciles(analytics) && course_deciles(analytics)[0].to_s)
    }
  end

  # Returns a user's Nessie Assignments Submitted analytics on a course site
  # @param site [Hash]
  # @return [Hash]
  def nessie_assigns_submitted(site)
    site_statistics(analytics(site)['assignmentsSubmitted']).merge!({:type => 'Assignments Submitted'})
  end

  # Returns a user's Nessie Current Scores analytics on a course site
  # @param site [Hash]
  # @return [Hash]
  def nessie_grades(site)
    site_statistics(analytics(site)['currentScore']).merge!({:type => 'Assignment Grades'})
  end

  # Returns a user's Nessie Last Activity analytics on a course site
  # @param site [Hash]
  # @return [Integer]
  def nessie_last_activity(site)
    analytics(site)['lastActivity'] && analytics(site)['lastActivity']['student'] && analytics(site)['lastActivity']['student']['daysSinceLastActivity']
  end

  # To support cohort search tests, returns all relevant user data. If a file containing the data already
  # exists, will skip collecting the data and simply parse the file. Otherwise, will collect the data and
  # write it to a file for subsequent test runs.
  # @param driver [Selenium::WebDriver]
  # @return Array[<Hash>]
  def collect_users_searchable_data(driver)
    users_data_file = BOACUtils.searchable_data
    if File.exist? users_data_file
      logger.warn 'Found a copy of searchable user data created today, skipping data collection'
      users_data = JSON.parse(File.read(users_data_file), {:symbolize_names => true})
    else
      logger.warn 'Cannot find a searchable user data file created today, collecting data and writing it to a file for reuse today'
      # Delete searchable data file from previous days before writing the new one
      Dir.glob("#{Utils.config_dir}/boac-searchable-data*").each { |f| File.delete f }
      users = BOACUtils.get_all_athletes
      users_data = users.map do |user|
        # Get the squad names to use as search criteria
        user_squad_names = user.sports.map do |squad_code|
          squad = Squad::SQUADS.find { |s| s.code == squad_code }
          squad.name
        end
        get_data(driver, user)
        {
          :sid => user.sis_id,
          :first_name => user.first_name,
          :first_name_sortable => user.first_name.gsub(/\W/, '').downcase,
          :last_name => user.last_name,
          :last_name_sortable => user.last_name.gsub(/\W/, '').downcase,
          :squad_names => user_squad_names,
          :level => (user_sis_data[:level] if user_sis_data[:level]),
          :majors => (user_sis_data[:majors] ? user_sis_data[:majors] : []),
          :gpa => (user_sis_data[:cumulative_gpa] if user_sis_data[:cumulative_gpa]),
          :units => (user_sis_data[:cumulative_units] if user_sis_data[:cumulative_units])
        }
      end
      File.open(users_data_file, 'w') { |f| f.write users_data.to_json }
    end
    users_data
  end
end
