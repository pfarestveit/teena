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

  def self.get_all_students
    query = 'SELECT student_profile_index.uid AS uid,
                    student_profile_index.sid AS sid,
                    student_profile_index.first_name AS first_name,
                    student_profile_index.last_name AS last_name,
                    student_profile_index.email_address AS email,
                    student_profile_index.academic_career_status AS status
             FROM student.student_profile_index
             ORDER BY uid;'
    results = Utils.query_pg_db(nessie_pg_db_credentials, query)

    results.map do |r|
      attributes = {
        :uid => r['uid'],
        :sis_id => r['sid'],
        :status => r['status'],
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
    query = 'SELECT sid FROM student.student_profile_index ORDER BY sid ASC;'
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

  # Returns the SIDs of non-current students with a given academic career status
  # @param status [String]
  # @return [Array<String>]
  def self.hist_profile_sids_of_career_status(status)
    query = "SELECT sid
             FROM student.student_profiles_hist_enr
             WHERE profile LIKE '%\"academicCareerStatus\": \"#{status}\"%';"
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
           HAVING COUNT(boac_advisor.advisor_students.student_uid) > 75
           ORDER BY count DESC LIMIT 1;"
    results = Utils.query_pg_db(nessie_pg_db_credentials, sql)
    results.map { |r| BOACUser.new sis_id: r['sid'], uid: r['uid'] }.first
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

end
