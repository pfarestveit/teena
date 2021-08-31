require_relative 'spec_helper'

class NessieUtils < Utils

  @config = Utils.config['nessie']

  def self.nessie_redshift_db_credentials
    {
      :host => @config['redshift_db_host'],
      :port => @config['redshift_db_port'],
      :name => @config['redshift_db_name'],
      :user => @config['redshift_db_user'],
      :password => @config['redshift_db_password']
    }
  end

  def self.nessie_pg_db_credentials
    {
      :host => @config['pg_db_host'],
      :port => @config['pg_db_port'],
      :name => @config['pg_db_name'],
      :user => @config['pg_db_user'],
      :password => @config['pg_db_password']
    }
  end

  # The number of hours that synced Canvas data is behind actual site usage data
  def self.canvas_data_lag_hours
    @config['canvas_data_lag_hours']
  end

  # Whether or not to test Caliper last activity data
  def self.include_caliper_tests
    @config['include_caliper_tests']
  end

  # The number of seconds that is the max acceptable diff between last activity shown in Canvas vs Caliper
  def self.caliper_time_margin
    @config['caliper_time_margin']
  end

  # Whether or not to include L&S students and advisors
  def self.include_l_and_s?
    @config['include_l_and_s']
  end

  #### ASSIGNMENTS ####

  # Returns the assignments associated with a user in a course site
  # @param user [User]
  # @param course [Course]
  # @return [Array<Assignment>]
  def self.get_assignments(user, course)
    query = "SELECT assignment_id, due_at, submitted_at, assignment_status
              FROM boac_analytics.assignment_submissions_scores
              WHERE course_id = #{course.site_id}
                AND canvas_user_id = #{user.canvas_id}
              ORDER BY assignment_id;"
    results = query_redshift_db(nessie_redshift_db_credentials, query)
    results.map do |r|
      submitted = %w(on_time late submitted graded).include? r['assignment_status']
      Assignment.new({:id => r['assignment_id'], :due_date => r['due_at'], :submission_date => r['submitted_at'], :submitted => submitted})
    end
  end

  # Returns the Caliper last activity metric for a user in a course site
  # @param user [BOACUser]
  # @param site_id [String]
  # @return [Time]
  def self.get_caliper_last_activity(user, site_id)
    query = "SELECT last_activity
              FROM lrs_caliper_analytics.last_activity_caliper
              WHERE canvas_course_id = #{site_id}
                AND canvas_user_id = #{user.canvas_id};"
    results = query_redshift_db(nessie_redshift_db_credentials, query)
    activities = results.map { |r| Time.parse(r['last_activity'][0..18] += ' UTC') }
    activities.max
  end

  #### ALL STUDENTS ####

  # Returns an array of students who have current academic status
  # @return [Array<BOACUser>]
  def self.get_all_students
    query = 'SELECT student_academic_status.uid AS uid,
                    student_academic_status.sid AS sid,
                    student_academic_status.first_name AS first_name,
                    student_academic_status.last_name AS last_name,
                    student_academic_status.email_address AS email
             FROM student.student_academic_status
             ORDER BY uid;'
    results = Utils.query_pg_db(nessie_pg_db_credentials, query)

    results.map do |r|
      attributes = {
        :uid => r['uid'],
        :sis_id => r['sid'],
        :first_name => r['first_name'],
        :last_name => r['last_name'],
        :full_name => "#{r['first_name']} #{r['last_name']}",
        :email => r['email']
      }
      BOACUser.new attributes
    end
  end

  # Returns all SIDs present on the student_academic_status table
  # @return [Array<String>]
  def self.get_all_sids
    query = 'SELECT sid FROM student.student_academic_status ORDER BY sid ASC;'
    results = Utils.query_pg_db(nessie_pg_db_credentials, query)
    results.map { |r| r['sid'] }
  end

  #### ASC ####

  # Returns all the distinct teams associated with team members
  # @return [Array<Team>]
  def self.get_asc_teams
    # Get the squads associated with ASC students
    query = 'SELECT DISTINCT group_code
              FROM boac_advising_asc.students;'
    results = Utils.query_pg_db(nessie_pg_db_credentials, query)
    results = results.map { |r| r['group_code'] }
    squads = Squad::SQUADS.select { |squad| results.include? squad.code }
    squads.sort_by { |s| s.name }

    # Get the teams associated with the squads
    teams = squads.map &:parent_team
    teams.uniq!
    logger.info "Teams are #{teams.map &:name}"
    teams.sort_by { |t| t.name }
  end

  #### CoE ####

  # Returns all the CoE students associated with a given advisor
  # @param advisor [User]
  # @param all_coe_students [Array<User>]
  # @return [Array<User>]
  def self.get_coe_advisor_students(advisor, all_coe_students)
    query = "SELECT students.sid
              FROM boac_advising_coe.students
              WHERE students.advisor_ldap_uid = '#{advisor.uid}'
              ORDER BY students.sid;"
    result = Utils.query_pg_db(nessie_pg_db_credentials, query)
    result = result.map { |r| r['sid'] }
    all_coe_students.select { |s| result.include? s.sis_id }
  end

  #### HISTORICAL STUDENTS ####

  # Returns the number of non-current students with a given academic career status
  # @param status [String]
  # @return [Integer]
  def self.hist_career_status_count(status)
    query = "SELECT COUNT(*)
             FROM student.student_profiles_hist_enr
             WHERE profile LIKE '%\"academicCareerStatus\": \"#{status}\"%';"
    result = query_pg_db_field(nessie_pg_db_credentials, query, 'count').last.to_i
    logger.info "Count of historical students with academic career status '#{status}' is #{result}"
    result
  end

  # Returns the number of non-current students with a null academic career status
  # @return [Integer]
  def self.null_hist_career_status_count
    query = "SELECT COUNT(*)
             FROM student.student_profiles_hist_enr
             WHERE profile NOT LIKE '%\"academicCareerStatus\": %';"
    result = query_pg_db_field(nessie_pg_db_credentials, query, 'count').last.to_i
    logger.info "Count of historical students with NULL academic career status is #{result}"
    result
  end

  # Returns the number of non-current students with an unexpected academic career status
  # @return [Integer]
  def self.unexpected_hist_career_status_count
    query = "SELECT COUNT(*)
             FROM student.student_profiles_hist_enr
             WHERE profile LIKE '%\"academicCareerStatus\": %'
               AND profile NOT LIKE '%\"academicCareerStatus\": \"Active\"%'
               AND profile NOT LIKE '%\"academicCareerStatus\": \"Inactive\"%'
               AND profile NOT LIKE '%\"academicCareerStatus\": \"Completed\"%'
               AND profile NOT LIKE '%\"academicCareerStatus\": \"Created In Error\"%'
               AND profile NOT LIKE'%\"academicCareerStatus\": null%';"
    result = query_pg_db_field(nessie_pg_db_credentials, query, 'count').last.to_i
    logger.info "Count of historical students with unexpected academic career status is #{result}"
    result
  end

  # Returns the number of non-current students with a given program status
  # @param status [String]
  # @return [Integer]
  def self.hist_prog_status_count(status)
    query = "SELECT COUNT(*)
             FROM student.student_profiles_hist_enr
             WHERE profile LIKE '%\"status\": \"#{status}\"%';"
    result = query_pg_db_field(nessie_pg_db_credentials, query, 'count').last.to_i
    logger.info "Count of historical students with academic program status '#{status}' is #{result}"
    result
  end

  # Returns the number of non-current students with an unexpected program status
  # @return [Integer]
  def self.unexpected_hist_prog_status_count
    query = "SELECT COUNT(*)
             FROM student.student_profiles_hist_enr
             WHERE profile LIKE '%\"status\": %'
               AND profile NOT LIKE '%\"status\": \"Active\"%'
               AND profile NOT LIKE '%\"status\": \"Cancelled\"%'
               AND profile NOT LIKE '%\"status\": \"Completed Program\"%'
               AND profile NOT LIKE '%\"status\": \"Deceased\"%'
               AND profile NOT LIKE '%\"status\": \"Discontinued\"%'
               AND profile NOT LIKE '%\"status\": \"Dismissed\"%'
               AND profile NOT LIKE '%\"status\": \"Leave of Absence\"%'
               AND profile NOT LIKE '%\"status\": \"Suspended\"%'
               AND profile NOT LIKE '%\"status\": {\"code\": \"PRO\", \"description\": \"Probation\"}%'
               AND profile NOT LIKE '%\"status\": {\"code\": \"GST\", \"description\": \"Good Standing\"}%'
               AND profile NOT LIKE '%\"status\": {\"code\": \"DIS\", \"description\": \"Dismissed\"}%';"
    result = query_pg_db_field(nessie_pg_db_credentials, query, 'count').last.to_i
    logger.info "Count of historical students with unexpected academic program status is #{result}"
    result
  end

  # Returns the SIDs of non-current students in the profiles table
  # @return [Array<String>]
  def self.hist_profile_sids
    query = 'SELECT sid
             FROM student.student_profiles_hist_enr
             ORDER BY sid ASC;'
    query_pg_db(nessie_pg_db_credentials, query).map { |r| r['sid'] }
  end

  # Returns the SIDs of non-current students with a given academic career status
  # @param status [String]
  # @return [Array<String>]
  def self.hist_profile_sids_of_career_status(status)
    query = "SELECT sid
             FROM student.student_profiles_hist_enr
             WHERE profile LIKE '%\"academicCareerStatus\": \"#{status}\"%';"
    query_pg_db(nessie_pg_db_credentials, query).map { |r| r['sid'] }
  end

  # Returns the SIDs of non-current students with null academic career status
  # @return [Array<String>]
  def self.null_hist_career_status_sids
    query = "SELECT sid
             FROM student.student_profiles_hist_enr
             WHERE profile NOT LIKE '%\"academicCareerStatus\": %';"
    query_pg_db(nessie_pg_db_credentials, query).map { |r| r['sid'] }
  end

  # Returns the SIDs of non-current students in the enrollments table
  # @return [Array<String>]
  def self.hist_enrollment_sids
    query = 'SELECT DISTINCT sid
             FROM student.student_enrollment_terms_hist_enr
             ORDER BY sid ASC;'
    query_pg_db(nessie_pg_db_credentials, query).map { |r| r['sid'] }
  end

  # Returns a non-current student with a given SID
  # @param sid [String]
  # @return [BOACUser]
  def self.get_hist_student(sid)
    query = "SELECT uid
             FROM student.student_profiles_hist_enr
             WHERE sid = '#{sid}';"
    uid = query_pg_db_field(nessie_pg_db_credentials, query, 'uid').last
    BOACUser.new(sis_id: sid, uid: uid)
  end

  #### ADMITS ####

  def self.get_admits
    query = 'SELECT cs_empl_id AS sid,
                    first_name AS first_name,
                    last_name AS last_name,
                    campus_email_1 AS email,
                    current_sir AS is_sir
             FROM boac_advising_oua.student_admits
             ORDER BY sid;'
    results = Utils.query_pg_db(nessie_pg_db_credentials, query)
    results.map { |r| BOACUser.new sis_id: r['sid'], first_name: r['first_name'], last_name: r['last_name'], email: r['email'], is_sir: (r['is_sir'] == 'Yes') }
  end

  def self.get_admit_page_data
    query = 'SELECT *
             FROM boac_advising_oua.student_admits;'
    results = Utils.query_pg_db(nessie_pg_db_credentials, query)
    results = results.map { |r| r.transform_keys &:to_sym }
    results.map { |r| r.transform_values &:to_s }
  end

  def self.get_admit_data_update_date
    query = 'SELECT MAX(updated_at) FROM boac_advising_oua.student_admits;'
    result = query_pg_db_field(nessie_pg_db_credentials, query, 'max').first
    Time.parse(result).strftime('%b %-d, %Y')
  end

  # Get all academic plans associated with a given advisor and current students
  # @param advisor [User]
  # @return [Array<String>]
  def self.get_academic_plans(advisor)
    query = "SELECT DISTINCT boac_advisor.advisor_students.academic_plan_code AS plan_code
              FROM boac_advisor.advisor_students
              JOIN boac_advising_notes.advising_note_authors
                ON boac_advising_notes.advising_note_authors.uid = '#{advisor.uid}'
                AND boac_advising_notes.advising_note_authors.sid = boac_advisor.advisor_students.advisor_sid
              JOIN student.student_profiles
              ON student.student_profiles.sid = boac_advisor.advisor_students.student_sid
              ORDER BY boac_advisor.advisor_students.academic_plan_code;"
    Utils.query_pg_db(nessie_pg_db_credentials, query).map { |r| r['plan_code'] }
  end

  # Get a mapping of academic plan codes to human-readable descriptions
  # @return [Hash]
  def self.get_academic_plan_codes
    plan_map = {'*': 'All plans'}
    query = "SELECT DISTINCT academic_plan_code, academic_plan FROM boac_advisor.advisor_students"
    Utils.query_pg_db(nessie_pg_db_credentials, query).each do |r|
      plan_map[r['academic_plan_code']] = r['academic_plan']
    end
    plan_map
  end

  #### SEARCHABLE ADMIT DATA ####

  # Obtains searchable admit data and saves it unless it is already saved
  # @return [Array<Hash>]
  def self.searchable_admit_data
    users_data_file = BOACUtils.searchable_admit_data
    if File.exist? users_data_file
      JSON.parse(File.read(users_data_file), symbolize_names: true)

    else
      logger.warn 'Cannot find a searchable admit data file created today, collecting data and writing it to a file for reuse today'

      # Delete older searchable data files before writing the new one
      Dir.glob("#{Utils.config_dir}/boac-searchable-admit-data*").each { |f| File.delete f }

      query = "SELECT first_name,
                      last_name,
                      cs_empl_id,
                      freshman_or_transfer,
                      current_sir,
                      college,
                      xethnic,
                      hispanic,
                      urem,
                      first_generation_college,
                      application_fee_waiver_flag,
                      foster_care_flag,
                      family_is_single_parent,
                      student_is_single_parent,
                      family_dependents_num,
                      student_dependents_num,
                      reentry_status,
                      last_school_lcff_plus_flag,
                      special_program_cep,
                      residency_category
               FROM boac_advising_oua.student_admits
               ORDER BY cs_empl_id;"

      results = query_pg_db(nessie_pg_db_credentials, query)
      admit_data = results.map do |r|
        {
          first_name_sortable_cohort: (r['first_name'].split(' ').map { |s| s.gsub(/\W/, '').downcase }).join,
          last_name_sortable_cohort: (r['last_name'].empty? ? ' ' : (r['last_name'].split(' ').map { |s| s.gsub(/\W/, '').downcase }).join),
          sid: r['cs_empl_id'],
          freshman_or_transfer: r['freshman_or_transfer'],
          current_sir: r['current_sir'],
          college: r['college'],
          xethnic: r['xethnic'],
          hispanic: r['hispanic'],
          urem: r['urem'],
          first_gen_college: r['first_generation_college'],
          fee_waiver: (r['application_fee_waiver_flag'] && r['application_fee_waiver_flag'].gsub('Waiver', '')),
          foster_care: r['foster_care_flag'],
          family_single_parent: r['family_is_single_parent'],
          student_single_parent: r['student_is_single_parent'],
          family_dependents: r['family_dependents_num'],
          student_dependents: r['student_dependents_num'],
          re_entry_status: r['reentry_status'],
          last_school_lcff_plus_flag: r['last_school_lcff_plus_flag'],
          special_program_cep: r['special_program_cep'],
          intl: r['residency_category']
        }
      end

      # Write the data to a file for reuse.
      File.open(BOACUtils.searchable_admit_data, 'w') { |f| f.write admit_data.to_json }
      admit_data
    end
  end

  #### NOTES ####

  def self.get_external_note_count(schema)
    query = "SELECT COUNT(*)
             FROM #{schema}.advising_notes
             #{+ ' WHERE advisor_first_name != \'Reception\' AND advisor_last_name != \'Front Desk\'' if schema == TimelineRecordSource::E_AND_I.note_schema};"
    query_pg_db_field(nessie_pg_db_credentials, query, 'count').first
  end

  # Returns ASC advising notes associated with a given student
  # @param [BOACUser] student
  # @return [Array<Note>]
  def self.get_asc_notes(student)
    query = "SELECT boac_advising_asc.advising_notes.id AS id,
                    boac_advising_asc.advising_notes.created_at AS created_date,
                    boac_advising_asc.advising_notes.updated_at AS updated_date,
                    boac_advising_asc.advising_notes.advisor_uid AS advisor_uid,
                    boac_advising_asc.advising_notes.advisor_first_name AS advisor_first_name,
                    boac_advising_asc.advising_notes.advisor_last_name AS advisor_last_name,
                    boac_advising_asc.advising_notes.subject AS subject,
                    boac_advising_asc.advising_notes.body AS body,
                    ARRAY_AGG (boac_advising_asc.advising_note_topics.topic) AS topics
             FROM boac_advising_asc.advising_notes
             LEFT JOIN boac_advising_asc.advising_note_topics
               ON boac_advising_asc.advising_notes.id = boac_advising_asc.advising_note_topics.id
             WHERE boac_advising_asc.advising_notes.sid = '#{student.sis_id}'
             GROUP BY advising_notes.id, created_date, advisor_uid, subject, body;"
    results = query_pg_db(nessie_pg_db_credentials, query)

    results.map do |r|
      Note.new id: r['id'],
               advisor: BOACUser.new(uid: r['advisor_uid'], first_name: r['advisor_first_name'], last_name: r['advisor_last_name']),
               subject: r['subject'],
               body: r['body'],
               topics: (r['topics'].delete('{"}').gsub('NULL', '').split(',').sort if r['topics']),
               student: student,
               created_date: Time.parse(r['created_date']).utc.localtime,
               updated_date: Time.parse(r['updated_date']).utc.localtime,
               note_source: TimelineRecordSource::ASC
    end
  end

  # Returns E&I advising notes associated with a given student
  # @param [BOACUser] student
  # @return [Array<Note>]
  def self.get_e_and_i_notes(student)
    query = "SELECT boac_advising_e_i.advising_notes.id AS id,
                    boac_advising_e_i.advising_notes.advisor_uid AS advisor_uid,
                    boac_advising_e_i.advising_notes.advisor_first_name AS advisor_first_name,
                    boac_advising_e_i.advising_notes.advisor_last_name AS advisor_last_name,
                    boac_advising_e_i.advising_notes.overview AS subject,
                    boac_advising_e_i.advising_notes.note AS body,
                    boac_advising_e_i.advising_notes.created_at AS created_date,
                    boac_advising_e_i.advising_notes.updated_at AS updated_date,
                    boac_advising_e_i.advising_note_topics.topic AS topic
             FROM boac_advising_e_i.advising_notes
             LEFT JOIN boac_advising_e_i.advising_note_topics
               ON boac_advising_e_i.advising_notes.id = boac_advising_e_i.advising_note_topics.id
             WHERE boac_advising_e_i.advising_notes.sid = '#{student.sis_id}'
               AND advisor_first_name != 'Reception' AND advisor_last_name != 'Front Desk';"

    results = query_pg_db(nessie_pg_db_credentials, query)
    notes_data = results.group_by { |h1| h1['id'] }.map do |k,v|
      unless v[0]['advisor_first_name'] == 'Reception' && v[0]['advisor_last_name'] == 'Front Desk'
        {
          id: k,
          advisor: BOACUser.new(uid: v[0]['advisor_uid'], first_name: "#{v[0]['advisor_first_name']}", last_name: "#{v[0]['advisor_last_name']}"),
          subject: v[0]['subject'],
          body: v[0]['body'].to_s,
          created_date: Time.parse(v[0]['created_date'].to_s).utc.localtime,
          updated_date: Time.parse(v[0]['updated_date'].to_s).utc.localtime,
          topics: (v.map { |t| t['topic'].upcase if t['topic'] }).compact.sort,
          note_source: TimelineRecordSource::E_AND_I
        }
      end
    end

    notes_data.compact.map { |d| Note.new d }
  end

  def self.get_data_sci_notes(student)
    query = "SELECT boac_advising_data_science.advising_notes.id AS id,
                    boac_advising_data_science.advising_notes.advisor_email AS advisor_email,
                    boac_advising_data_science.advising_notes.reason_for_appointment AS topics,
                    boac_advising_data_science.advising_notes.body AS body,
                    boac_advising_data_science.advising_notes.created_at AS created_date
             FROM boac_advising_data_science.advising_notes
             WHERE boac_advising_data_science.advising_notes.sid = '#{student.sis_id}';"
    results = query_pg_db(nessie_pg_db_credentials, query)
    notes_data = results.map do |r|

      created_date = Time.parse(r['created_date'].to_s).utc.localtime
      {
          id: r['id'],
          note_source: TimelineRecordSource::DATA,
          body: r['body'],
          topics: (r['topics'].split(', ').map(&:upcase) if r['topics']).compact.sort,
          created_date: created_date,
          updated_date: created_date
      }
    end
    notes_data.map { |d| Note.new d }
  end

  # Returns SIS advising notes associated with a given student
  # @param student [BOACUser]
  # @return [Array<Note>]
  def self.get_sis_notes(student)
    query = "SELECT sis_advising_notes.advising_notes.id AS id,
                    sis_advising_notes.advising_notes.note_category AS category,
                    sis_advising_notes.advising_notes.note_subcategory AS subcategory,
                    sis_advising_notes.advising_notes.note_body AS body,
                    sis_advising_notes.advising_notes.created_by AS advisor_uid,
                    sis_advising_notes.advising_notes.advisor_sid AS advisor_sid,
                    sis_advising_notes.advising_notes.created_at AS created_date,
                    sis_advising_notes.advising_notes.updated_at AS updated_date,
                    sis_advising_notes.advising_note_topics.note_topic AS topic,
                    sis_advising_notes.advising_note_attachments.sis_file_name AS sis_file_name,
                    sis_advising_notes.advising_note_attachments.user_file_name AS user_file_name
            FROM sis_advising_notes.advising_notes
            LEFT JOIN sis_advising_notes.advising_note_topics
              ON sis_advising_notes.advising_notes.id = sis_advising_notes.advising_note_topics.advising_note_id
            LEFT JOIN sis_advising_notes.advising_note_attachments
              ON sis_advising_notes.advising_notes.id = sis_advising_notes.advising_note_attachments.advising_note_id
            WHERE sis_advising_notes.advising_notes.sid = '#{student.sis_id}';"

    results = query_pg_db(nessie_pg_db_credentials, query)
    notes_data = results.group_by { |h1| h1['id'] }.map do |k,v|
      # If the note has no body, concatenate the category and subcategory as the body
      source_body_empty = (v[0]['body'].nil? || v[0]['body'].strip.empty?)
      body = source_body_empty ?
                "#{v[0]['category']}#{+', ' if v[0]['subcategory']}#{v[0]['subcategory']}" :
                 Nokogiri::HTML(v[0]['body']).text.gsub('&Tab;', '')

      attachment_data = v.map do |r|
        unless r['sis_file_name'].nil? || r['sis_file_name'].empty?
          {
            :sis_file_name => r['sis_file_name'],
            :file_name => ((r['advisor_uid'] == 'UCBCONVERSION') ? r['sis_file_name'] : r['user_file_name'])
          }
        end
      end
      attachments = attachment_data.compact.uniq.map { |d| Attachment.new d }

      advisor_uid = v[0]['advisor_uid']
      created_date = v[0]['created_date']
      updated_date = (advisor_uid == 'UCBCONVERSION') ? created_date : v[0]['updated_date']
      {
        :id => k,
        :body => body,
        :source_body_empty => source_body_empty,
        :advisor => BOACUser.new({:uid => advisor_uid}),
        :created_date => Time.parse(created_date.to_s).utc.localtime,
        :updated_date => Time.parse(updated_date.to_s).utc.localtime,
        :topics => (v.map { |t| t['topic'].upcase if t['topic'] }).compact.sort,
        :attachments => attachments,
        :note_source => TimelineRecordSource::SIS
      }
    end
    notes_data.map { |d| Note.new d }
  end

  # Returns all SIDs represented in a given advising note source
  # @param src [TimelineRecordSource]
  # @return [Array<String>]
  def self.get_sids_with_notes_of_src(src)
    query = "SELECT DISTINCT #{src.note_schema}.advising_notes.sid
             FROM #{src.note_schema}.advising_notes
             #{+ ' WHERE advisor_first_name != \'Reception\' AND advisor_last_name != \'Front Desk\'' if src == TimelineRecordSource::E_AND_I}
             #{+ ' INNER JOIN ' + src.note_schema + '.advising_note_attachments
                    ON ' + src.note_schema + '.advising_notes.sid = ' + src.note_schema + '.advising_note_attachments.sid' if src == TimelineRecordSource::SIS}
             ORDER BY sid ASC;"
    results = Utils.query_pg_db(nessie_pg_db_credentials, query)
    results.map { |r| r['sid'] }
  end

  # Returns all SIS note authors
  # @param student [BOACUser]
  # @return [Array]
  def self.get_all_advising_note_authors
    query = "SELECT uid, sid, first_name, last_name
              FROM boac_advising_notes.advising_note_authors;"
    results = Utils.query_pg_db(nessie_pg_db_credentials, query)
    results.map do |r|
      {
        :uid => r['uid'],
        :sid => r['sid'],
        :first_name => r['first_name'],
        :last_name => r['last_name']
      }
    end
  end

  # Returns basic identifying data for a SIS note author
  # @param uid [Fixnum]
  # @return [Array]
  def self.get_advising_note_author(uid)
    query = "SELECT sid, first_name, last_name
              FROM boac_advising_notes.advising_note_authors
              WHERE uid = '#{uid}';"
    results = Utils.query_pg_db(nessie_pg_db_credentials, query)
    if results.any?
      {
        :sid => results[0]['sid'],
        :first_name => results[0]['first_name'],
        :last_name => results[0]['last_name']
      }
    end
  end

  def self.set_advisor_data(advisor)
    data = get_advising_note_author advisor.uid
    advisor.sis_id = data[:sid]
    advisor.first_name = data[:first_name]
    advisor.last_name = data[:last_name]
    advisor.full_name = "#{advisor.first_name} #{advisor.last_name}"
  end

  ### APPOINTMENTS ###

  def self.get_sis_appts(student)
    query = "SELECT sis_advising_notes.advising_appointments.id AS id,
                    sis_advising_notes.advising_appointments.note_body AS detail,
                    sis_advising_notes.advising_appointments.created_by AS advisor_uid,
                    sis_advising_notes.advising_appointments.advisor_sid AS advisor_sid,
                    sis_advising_notes.advising_appointments.created_at AS created_date,
                    sis_advising_notes.advising_appointments.updated_at AS updated_date,
                    sis_advising_notes.advising_appointment_advisors.first_name AS advisor_first_name,
                    sis_advising_notes.advising_appointment_advisors.last_name AS advisor_last_name,
                    sis_advising_notes.advising_note_topics.note_topic AS topic,
                    sis_advising_notes.advising_note_attachments.sis_file_name AS sis_file_name,
                    sis_advising_notes.advising_note_attachments.user_file_name AS user_file_name
             FROM sis_advising_notes.advising_appointments
             LEFT JOIN sis_advising_notes.advising_appointment_advisors
               ON sis_advising_notes.advising_appointments.advisor_sid = sis_advising_notes.advising_appointment_advisors.sid
             LEFT JOIN sis_advising_notes.advising_note_topics
               ON sis_advising_notes.advising_appointments.id = sis_advising_notes.advising_note_topics.advising_note_id
             LEFT JOIN sis_advising_notes.advising_note_attachments
               ON sis_advising_notes.advising_appointments.id = sis_advising_notes.advising_note_attachments.advising_note_id
             WHERE sis_advising_notes.advising_appointments.sid = '#{student.sis_id}'
             ORDER BY id ASC;"

    results = query_pg_db(nessie_pg_db_credentials, query)
    appts_data = results.group_by { |h1| h1['id'] }.map do |k,v|
      attachment_data = v.map do |r|
        unless r['sis_file_name'].nil? || r['sis_file_name'].empty?
          {
            sis_file_name: r['sis_file_name'],
            file_name: ((r['advisor_uid'] == 'UCBCONVERSION') ? r['sis_file_name'] : r['user_file_name'])
          }
        end
      end
      attachments = attachment_data.compact.uniq.map { |d| Attachment.new d }
      advisor_uid = v[0]['advisor_uid']
      created_date = v[0]['created_date']
      updated_date = (advisor_uid == 'UCBCONVERSION') ? created_date : v[0]['updated_date']
      advisor = BOACUser.new(
          uid: v[0]['advisor_uid'],
          sis_id: v[0]['created_date'],
          first_name: v[0]['advisor_first_name'],
          last_name: v[0]['advisor_last_name']
      )
      {
        id: k,
        detail: Nokogiri::HTML(v[0]['detail']).text.strip.gsub('&Tab;', ''),
        student: student,
        advisor: advisor,
        created_date: Time.parse(created_date.to_s).utc.localtime,
        updated_date: Time.parse(updated_date.to_s).utc.localtime,
        attachments: attachments,
        topics: (v.map { |t| t['topic'].upcase if t['topic'] }).compact.sort,
        source: TimelineRecordSource::SIS
      }
    end
    appts_data.map { |d| Appointment.new d }
  end

  # Returns all SIDs represented in a given advising note source
  # @return [Array<String>]
  def self.get_sids_with_sis_appts
    query = "SELECT DISTINCT sis_advising_notes.advising_appointments.sid
             FROM sis_advising_notes.advising_appointments
             INNER JOIN sis_advising_notes.advising_note_attachments
               ON sis_advising_notes.advising_note_attachments.sid = sis_advising_notes.advising_appointments.sid
             ORDER BY sid ASC;"
    results = Utils.query_pg_db(nessie_pg_db_credentials, query)
    results.map { |r| r['sid'] }
  end

  def self.get_ycbm_appts(student)
    query = "SELECT boac_advising_appointments.ycbm_advising_appointments.id AS id,
                    boac_advising_appointments.ycbm_advising_appointments.appointment_type AS type,
                    boac_advising_appointments.ycbm_advising_appointments.title AS title,
                    boac_advising_appointments.ycbm_advising_appointments.details AS detail,
                    boac_advising_appointments.ycbm_advising_appointments.advisor_name AS advisor_name,
                    boac_advising_appointments.ycbm_advising_appointments.starts_at AS start_time,
                    boac_advising_appointments.ycbm_advising_appointments.ends_at AS end_time,
                    boac_advising_appointments.ycbm_advising_appointments.cancelled AS cancelled,
                    boac_advising_appointments.ycbm_advising_appointments.cancellation_reason AS cancel_reason
             FROM boac_advising_appointments.ycbm_advising_appointments
             WHERE boac_advising_appointments.ycbm_advising_appointments.student_sid = '#{student.sis_id}'
             ORDER BY start_time ASC;"

    results = query_pg_db(nessie_pg_db_credentials, query)
    appt_data = results.group_by { |h1| h1['id'] }.map do |k,v|
      advisor = BOACUser.new full_name: v[0]['advisor_name']
      {
        id: k,
        type: v[0]['type'].to_s.strip,
        title: v[0]['title'].to_s.strip.gsub(/\s+/, ' '),
        detail: Nokogiri::HTML(v[0]['detail']).text.strip,
        student: student,
        advisor: advisor,
        created_date: Time.parse(v[0]['start_time'].to_s).utc.localtime,
        start_time: Time.parse(v[0]['start_time'].to_s).utc.localtime,
        end_time: Time.parse(v[0]['end_time'].to_s).utc.localtime,
        status: (AppointmentStatus::CANCELED if v[0]['cancelled'] == 't'),
        cancel_reason: v[0]['cancel_reason'].to_s.strip,
        source: TimelineRecordSource::YCBM
      }
    end
    appt_data.map { |d| Appointment.new d }
  end

  def self.get_sids_with_ycbm_appts
    query = "SELECT DISTINCT student_sid
             FROM boac_advising_appointments.ycbm_advising_appointments
             WHERE student_uid IS NOT NULL"
    results = Utils.query_pg_db(nessie_pg_db_credentials, query)
    results.map { |r| r['student_sid'] }
  end

  #### HOLDS ####

  # Returns a student's current holds
  # @param student [BOACUser]
  # @return [Array<Alert>]
  def self.get_student_holds(student)
    query = "SELECT sid, feed
              FROM student.student_holds
              WHERE sid = '#{student.sis_id}';"
    results = Utils.query_pg_db(nessie_pg_db_credentials, query)
    results.map do |r|
      feed = JSON.parse r['feed']
      alert_data = {
        :message => "#{feed['reason']['description']}. #{feed['reason']['formalDescription']}".gsub("\n", '').gsub("\\u200b", '').gsub(/\s+/, ' '),
        :user => student
      }
      Alert.new alert_data
    end
  end

  # Returns all SIDs with a given academic standing in a given term
  # @param standing [AcademicStanding]
  # @param term_id [String]
  # @return [Array<String>]
  def self.get_sids_with_standing(standing, term_id)
    sql = "SELECT DISTINCT student.academic_standing.sid
           FROM student.academic_standing
           WHERE student.academic_standing.acad_standing_status = '#{standing.code}'
             AND student.academic_standing.term_id = '#{term_id}';"
    results = Utils.query_pg_db(nessie_pg_db_credentials, sql)
    sids = results.map { |r| r['sid'] }
    logger.info "There are #{sids.length} students with academic standing '#{standing.descrip}' in term #{term_id}"
    sids
  end

  ### ADVISORS ###

  def self.get_my_students_test_advisor(academic_plan_code)
    sql = "SELECT DISTINCT boac_advisor.advisor_students.advisor_sid AS sid,
	                COUNT(boac_advisor.advisor_students.student_uid) AS count,
	                boac_advisor.advisor_roles.uid AS uid
           FROM boac_advisor.advisor_students
           JOIN boac_advisor.advisor_roles
	           ON boac_advisor.advisor_students.advisor_sid = boac_advisor.advisor_roles.sid
           WHERE boac_advisor.advisor_students.academic_plan_code = '#{academic_plan_code}'
           GROUP BY boac_advisor.advisor_students.advisor_sid, boac_advisor.advisor_roles.uid
           HAVING COUNT(boac_advisor.advisor_students.student_uid) > 200
           ORDER BY count ASC LIMIT 1;"
    results = Utils.query_pg_db(nessie_pg_db_credentials, sql)
    results.map { |r| BOACUser.new sis_id: r['sid'], uid: r['uid'] }.first
  end

end
