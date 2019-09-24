require_relative '../../util/spec_helper'

class BOACApiStudentPage

  include PageObject
  include Logging

  def get_data(driver, user)
    logger.info "Getting data for UID #{user.uid}"
    navigate_to "#{BOACUtils.api_base_url}/api/student/by_uid/#{user.uid}"
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
      :coe_advisor => (profile && profile['advisorUid']),
      :gender => (profile && profile['gender']),
      :ethnicity => (profile && profile['ethnicity']),
      :coe_underrepresented_minority => (profile && profile['minority']),
      :coe_prep => (profile && profile['didPrep']),
      :prep_elig => (profile && profile['prepEligible']),
      :t_prep => (profile && profile['didTprep']),
      :t_prep_elig => (profile && profile['tprepEligible'])
    }
  end

  # SIS Profile

  def sis_profile
    @parsed && @parsed['sisProfile']
  end

  def sis_profile_data
    {
      :name => (sis_profile && sis_profile['name']),
      :preferred_name => (sis_profile && sis_profile['preferredName']),
      :email => (sis_profile && sis_profile['emailAddress']),
      :phone => (sis_profile && sis_profile['phoneNumber'].to_s),
      :term_units => (sis_profile && ((current_term ? formatted_units(current_term['enrolledUnits']) : '0') if terms.any?)),
      :term_units_min => (sis_profile && sis_profile['currentTerm'] && sis_profile['currentTerm']['unitsMinOverride']),
      :term_units_max => (sis_profile && sis_profile['currentTerm'] && sis_profile['currentTerm']['unitsMaxOverride']),
      :cumulative_units => (sis_profile && ((!sis_profile['cumulativeUnits'] || sis_profile['cumulativeUnits'].zero?) ? '--' : formatted_units(sis_profile['cumulativeUnits']))),
      :cumulative_gpa => (sis_profile && (sis_profile['cumulativeGPA'].nil? ? '--' : (sprintf '%.3f', sis_profile['cumulativeGPA']).to_s)),
      :majors => majors,
      :level => (sis_profile && (sis_profile['level'] && sis_profile['level']['description'])),
      :transfer => (sis_profile && (sis_profile['transfer'])),
      :terms_in_attendance => (sis_profile && sis_profile['termsInAttendance'].to_s),
      :expected_grad_term_id => (sis_profile && sis_profile['expectedGraduationTerm'] && sis_profile['expectedGraduationTerm']['id']),
      :expected_grad_term_name => (sis_profile && sis_profile['expectedGraduationTerm'] && sis_profile['expectedGraduationTerm']['name']),
      :withdrawal => (sis_profile && withdrawal),
      :graduation => (sis_profile && graduation),
      :academic_career_status => (sis_profile && sis_profile['academicCareerStatus']),
      :reqt_writing => (sis_profile && degree_progress && degree_progress[:writing]),
      :reqt_history => (sis_profile && degree_progress && degree_progress[:history]),
      :reqt_institutions => (sis_profile && degree_progress && degree_progress[:institutions]),
      :reqt_cultures => (sis_profile && degree_progress && degree_progress[:cultures])
    }
  end

  def formatted_units(units_as_num)
    if units_as_num
      if units_as_num.zero?
        '0'
      else
        (units_as_num == units_as_num.floor) ? units_as_num.floor.to_s : units_as_num.to_s
      end
    end
  end

  def graduation
    if sis_profile['degree']
      {
        date: sis_profile['degree']['dateAwarded'],
        degree: sis_profile['degree']['description'],
        colleges: sis_profile['degree']['plans'].map { |p| p['group'] },
        majors: sis_profile['degree']['plans'].map { |p| p['plan'] }
      }
    end
  end

  def majors
    if sis_profile && sis_profile['plans']
      majors = sis_profile['plans'].map do |p|
        {
          active: p['status'] == 'Active',
          college: p['program'],
          major: p['description'],
          status: p['status']
        }
      end
      majors.sort_by { |m| m[:active] ? 0 : 1 }
    else
      []
    end
  end

  def withdrawal
    withdrawal = sis_profile['withdrawalCancel']
    withdrawal && {
      :desc => withdrawal['description'],
      :reason => withdrawal['reason'],
      :date => Time.parse(withdrawal['date']).strftime('%b %d, %Y')
    }
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

  def term_units(term)
    formatted_units term['enrolledUnits']
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

  def sis_section_data(section)
    {
      :ccn => section['ccn'],
      :number => "#{section['sectionNumber']}",
      :component => section['component'],
      :units_completed => (section['units'].floor == section['units'] ? section['units'].floor.to_s : section['units'].to_s),
      :primary => section['primary'],
      :status => section['enrollmentStatus']
    }
  end

  def sis_course_data(course)
    {
      :code => course_display_name(course),
      :title => course['title'].gsub(/\s+/, ' '),
      :units_completed => (course['units'].floor == course['units'] ? course['units'].floor.to_s : course['units'].to_s),
      :midpoint => course['midtermGrade'],
      :grade => (course['grade'] && course['grade'].gsub('-','−')),
      :grading_basis => course['gradingBasis']
    }
  end

  # Courses that are dropped don't display on the cohort page.
  def current_non_dropped_course_codes
    courses = []
    if (term = current_term)
      courses(term).each do |c|
        if sections(c).find { |s| %w(E W).include? sis_section_data(s)[:status] }
          courses << sis_course_data(c)[:code]
        end
      end
    end
    courses
  end

  def current_waitlisted_course_codes
    courses = []
    if (term = current_term)
      courses(term).each do |c|
        if sections(c).find { |s| sis_section_data(s)[:status] == 'W' }
          courses << sis_course_data(c)[:code]
        end
      end
    end
    courses
  end

  def course_section_ccns(course)
    sections(course).map { |s| sis_section_data(s)[:ccn] }
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
  # @return [Hash]
  def nessie_last_activity(site)
    site_statistics(analytics(site)['lastActivity']).merge!({:type => 'Last bCourses Activity'})
  end

end
