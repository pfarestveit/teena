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

  def set_identity(user)
    user.uid = @parsed['uid']
    user.first_name = @parsed['firstName']
    user.last_name = @parsed['lastName']
    user.full_name = @parsed['name']
  end

  # Canvas Profile

  def set_canvas_id(user)
    user.canvas_id = @parsed['canvasUserId']
  end

  # Athletics Profile

  def asc_profile
    @parsed['athleticsProfile']
  end

  def asc_teams
    asc_profile && asc_profile['athletics'].map { |a| a['groupName'] }
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
      :email_alternate => (sis_profile && sis_profile['emailAddressAlternate']),
      :phone => (sis_profile && (sis_profile['phoneNumber'].to_s if sis_profile['phoneNumber'])),
      :cumulative_units => (sis_profile && ((!sis_profile['cumulativeUnits'] || sis_profile['cumulativeUnits'].zero?) ? '--' : formatted_units(sis_profile['cumulativeUnits']))),
      :cumulative_gpa => (sis_profile && (sis_profile['cumulativeGPA'].nil? ? '--' : (sprintf '%.3f', sis_profile['cumulativeGPA']).to_s)),
      :majors => majors,
      :minors => minors,
      :level => (sis_profile && (sis_profile['level'] && sis_profile['level']['description'])),
      :transfer => (sis_profile && (sis_profile['transfer'])),
      :terms_in_attendance => (sis_profile && sis_profile['termsInAttendance'].to_s),
      :entered_term => (sis_profile && sis_profile['matriculation']),
      :intended_majors => (((sis_profile && sis_profile['intendedMajors']) || []).map { |m| m['description'] }).reject(&:empty?),
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
        colleges: (sis_profile['degree']['plans'].map { |p| p['group'].to_s }).uniq,
        majors: (sis_profile['degree']['plans'].map { |p| p['plan'] if p['type'] == 'MAJ' }).compact,
        minors: (sis_profile['degree']['plans'].map { |p| p['plan'].gsub('Minor in ', '') if p['type'] == 'MIN'}).compact
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

  def sub_plans
    sis_profile && sis_profile['subplans']
  end

  def minors
    if sis_profile && sis_profile['plansMinor']
      sis_profile['plansMinor'].map do |p|
        {
          active: p['status'] == 'Active',
          college: p['program'],
          minor: p['description'],
          status: p['status']
        }
      end
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

  def academic_standing
    standing = @parsed && @parsed['academicStanding']&.map do |st|
      AcademicStanding.new({
                               code: st['status'],
                               descrip: (AcademicStanding::STATUSES.find { |s| s.code == st['status'] }).descrip,
                               term_id: st['termId'],
                               term_name: st['termName'],
                               date: st['actionDate']
                           })
    end
    if standing
      standing.group_by { |s| s.term_id }.transform_values { |v| v.sort_by(&:date).last }.values
    end
  end

  def degree_progress
    progress = sis_profile['degreeProgress']
    progress && progress['requirements'] && {
      :date => progress['reportDate'],
      :writing => "#{progress['requirements']['entryLevelWriting']['name']} #{progress['requirements']['entryLevelWriting']['status']}",
      :cultures => "#{progress['requirements']['americanCultures']['name']} #{progress['requirements']['americanCultures']['status']}",
      :history => "#{progress['requirements']['americanHistory']['name']} #{progress['requirements']['americanHistory']['status']}",
      :institutions => "#{progress['requirements']['americanInstitutions']['name']} #{progress['requirements']['americanInstitutions']['status']}"
    }
  end

  # Demographics

  def demographics
    @parsed && @parsed['demographics']
  end

  def demographics_data
    {
      visa: visa
    }
  end


  def visa
    if (visa_feed = (demographics && demographics['visa']))
      {
        status: visa_feed['status'],
        type: visa_feed['type']
      }
    end
  end

  # Advisors

  def advisors
    ((@parsed && @parsed['advisors']) || []).map do |a|
      {
        email: a['email'],
        name: "#{a['firstName']} #{a['lastName']}",
        plan: a['plan']
      }
    end
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

  def term_gpa(term)
    term['termGpa'] && term['termGpa']['gpa']
  end

  def term_gpa_units(term)
    term['termGpa'] && term['termGpa']['unitsTakenForGpa']
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
      :ccn => section['ccn'].to_s,
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
      :midpoint => (course['midtermGrade'] && course['midtermGrade'].gsub('-','−')),
      :grade => (course['grade'] && course['grade'].gsub('-','−')),
      :grading_basis => course['gradingBasis']
    }
  end

  # Courses that are dropped don't display on the cohort page.
  def current_non_dropped_course_codes(term)
    courses = []
    courses(term).each do |c|
      if sections(c).find { |s| %w(E W).include? sis_section_data(s)[:status] }
        courses << sis_course_data(c)[:code]
      end
    end
    courses
  end

  def current_waitlisted_course_codes(term)
    courses = []
    courses(term).each do |c|
      if sections(c).find { |s| sis_section_data(s)[:status] == 'W' }
        courses << sis_course_data(c)[:code]
      end
    end
    courses
  end

  def course_section_ccns(course)
    sections(course).map { |s| sis_section_data(s)[:ccn] }
  end

  def course_primary_section(course)
    sections(course).find { |s| sis_section_data(s)[:primary] }
  end

  def dropped_sections(term)
    sections = term['droppedSections']
    sections && sections.map do |section|
      {
        :title => section['displayName'],
        :component => section['component'],
        :number => section['sectionNumber'],
        :date => section['dropDate']
      }
    end
  end

  # REGISTRATIONS

  def term_registration
    registration = sis_profile['currentRegistration']
    registration && {
      term_id: registration['term']['id'],
      career: registration['academicCareer']['code'],
      begin_term: (registration['academicLevels']&.find { |l| l['type']['code'] == 'BOT' })['level']['description'],
      end_term: (registration['academicLevels']&.find { |l| l['type']['code'] == 'EOT' })['level']['description']
    } unless registration.empty?
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

  def last_activity_day(site)
    epoch = site_statistics(analytics(site)['lastActivity'])[:score]
    if epoch.empty? || epoch.to_i.zero?
      'Never'
    else
      time = Time.strptime(epoch, '%s').getlocal
      date = Date.parse time.to_s
      if date == Date.today
        'Today'
      elsif  date == Date.today - 1
        'Yesterday'
      else
        "#{(Date.today - date).to_i} days ago"
      end
    end
  end

  # DEGREE PROGRESS

  def degree_progress_courses(degree_check)
    courses = []
    terms.each do |term|
      term_id = term_id term
      courses(term).each do |course|
        if course['grade'] && !course['grade'].empty?
          data = sis_course_data course
          primary_section = sis_section_data course_primary_section(course)
          unless data[:units_completed].to_f.zero?
            courses << DegreeCompletedCourse.new(ccn: primary_section[:ccn],
                                                 degree_check: degree_check,
                                                 term_id: term_id,
                                                 name: data[:code],
                                                 units: data[:units_completed],
                                                 units_orig: data[:units_completed],
                                                 grade: data[:grade].gsub('−', '-'))
          end
        end
      end
    end
    courses.sort_by &:name
  end

  # TIMELINE

  def notifications
    @parsed['notifications']
  end

  def alerts
    notifications && notifications['alert']&.map { |a| a['message'] }
  end

  def holds
    notifications && notifications['hold']&.map { |h| h['message'] }
  end

  def notes
    notifications && notifications['note']&.map do |n|

      advisor = n['author'] && BOACUser.new(
        uid: n['author']['uid'],
        full_name: n['author']['name'],
        email: n['author']['email'],
        depts: (n['author']['departments'].map { |d| d['name']})
      )

      Note.new id: n['id'].to_s,
               advisor: advisor,
               subject: n['subject'].to_s,
               body: n['body'].to_s,
               topics: (n['topics'] && n['topics'].sort),
               attachments: (n['attachments'] && n['attachments'].map{ |f| f['filename'] || f['sisFilename'] }.compact),
               created_date: n['createdAt'],
               updated_date: n['updatedAt']
    end
  end

  def appointments
    notifications && notifications['appointment']&.map do |a|

      advisor = a['advisor'] && BOACUser.new(
        uid: a['advisor']['uid'],
        full_name: a['advisor']['name'],
        depts: a['advisor']['departments']
      )

      Appointment.new id: a['id'].to_s,
                      advisor: advisor,
                      subject: a['appointmentTitle'].to_s,
                      detail: a['details'].to_s,
                      attachments: (a['attachments'] && a['attachments'].map{ |f| f['filename'] || f['sisFilename'] }.compact),
                      created_date: a['createdAt'],
                      updated_date: a['updatedAt']
    end
  end

end
