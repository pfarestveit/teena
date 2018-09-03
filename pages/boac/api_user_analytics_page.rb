require_relative '../../util/spec_helper'

class ApiUserAnalyticsPage

  include PageObject
  include Logging

  def get_data(driver, user)
    logger.info "Getting data for UID #{user.uid}"
    navigate_to "#{BOACUtils.base_url}/api/student/#{user.uid}/analytics"
    wait_until(Utils.long_wait) { driver.find_element(xpath: '//pre') }
    @parsed = JSON.parse driver.find_element(xpath: '//pre').text
    if @parsed['message'] == 'Unknown student'
      logger.error "BOAC does not recognize UID #{user.uid}!"
      nil
    else
      @parsed
    end
  end

  # Canvas Profile

  def set_canvas_id(user)
    user.canvas_id = @parsed['canvasUserId']
  end

  # Athletics Profile

  def asc_profile
    @parsed['athleticsProfile']
  end

  # CoE Profile

  def coe_profile
    profile = @parsed && @parsed['coeProfile']
    {
      :advisor => (profile && profile['advisorUid']),
      :gender => (profile && profile['gender']),
      :ethnicity => (profile && profile['ethnicity']),
      :prep => (profile && profile['didPrep']),
      :prep_elig => (profile && profile['prepEligible']),
      :t_prep => (profile && profile['didTprep']),
      :t_prep_elig => (profile && profile['tprepEligible'])
    }
  end

  # SIS Profile

  def sis_profile
    @parsed && @parsed['sisProfile']
  end

  def user_sis_data
    {
      :name => (sis_profile && sis_profile['name']),
      :preferred_name => (sis_profile && sis_profile['preferredName']),
      :email => (sis_profile && sis_profile['emailAddress']),
      :phone => (sis_profile && sis_profile['phoneNumber'].to_s),
      :units_in_progress => (sis_profile && ((current_term ? formatted_units(current_term['enrolledUnits']) : '0') if terms.any?)),
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
    if units_as_int
      (units_as_int == units_as_int.floor) ? units_as_int.floor.to_s : units_as_int.to_s
    end
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

  # To support cohort search tests, returns all relevant user data for a given set of students. If a file containing the data already
  # exists, will skip collecting the data and simply parse the file. Otherwise, will collect the data and write it to a file for
  # subsequent test runs.
  # @param driver [Selenium::WebDriver]
  # @param all_students [Array<User>]
  # @param test_config [BOACTestConfig]
  # @return Array[<Hash>]
  def collect_users_searchable_data(driver, all_students, test_config = nil)
    users_data_file = BOACUtils.searchable_data
    if File.exist? users_data_file
      logger.warn 'Found a copy of searchable user data created today, skipping data collection'
      users_data = JSON.parse(File.read(users_data_file), {:symbolize_names => true})
    else
      logger.warn 'Cannot find a searchable user data file created today, collecting data and writing it to a file for reuse today'

      # Delete older searchable data files before writing the new one
      Dir.glob("#{Utils.config_dir}/boac-searchable-data*").each { |f| File.delete f }

      # Fetch all the data and write it to a file for search tests to use
      users_data = all_students.map do |user|
        # Get the squad names to use as search criteria if the students are athletes
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
          :active_asc => user.active_asc,
          :intensive_asc => user.intensive_asc,
          :gpa => (user_sis_data[:cumulative_gpa] if user_sis_data[:cumulative_gpa]),
          :level => (user_sis_data[:level] if user_sis_data[:level]),
          :units => (user_sis_data[:cumulative_units] if user_sis_data[:cumulative_units]),
          :majors => (user_sis_data[:majors] ? user_sis_data[:majors] : []),
          :advisor => (coe_profile[:advisor] if coe_profile[:advisor]),
          :gender => (coe_profile[:gender] if coe_profile[:gender]),
          :ethnicity => (coe_profile[:ethnicity] if coe_profile[:ethnicity]),
          :prep => coe_profile[:prep],
          :prep_elig => coe_profile[:prep_elig],
          :t_prep => coe_profile[:t_prep],
          :t_prep_elig => coe_profile[:t_prep_elig]
        }
      end
      File.open(users_data_file, 'w') { |f| f.write users_data.to_json }
    end
    # If special configuration exists for the test, then return only user data for the dept specified in the config; else return all.
    if test_config
      student_sids = test_config.dept_students.map &:sis_id
      users_data.select { |u| student_sids.include? u[:sid] }
    else
      users_data
    end
  end

end
