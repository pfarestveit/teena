require_relative 'spec_helper'

class BOACUtils < Utils

  @config = Utils.config['boac']

  # Returns the BOAC test environment API URL
  # @return [String]
  def self.api_base_url
    @config['api_base_url']
  end

  # Returns the BOAC test environment URL
  # @return [String]
  def self.base_url
    @config['base_url']
  end

  # Returns the BOAC dev auth password
  # @return [String]
  def self.password
    @config['password']
  end

  # Returns the current BOAC semester
  # @return [String]
  def self.term
    @config['term']
  end

  # Returns the current BOAC semester code
  def self.term_code
    @config['term_code']
  end

  # Returns the previous BOAC semester code
  # @param code [String]
  # @return [String]
  def self.previous_term_code(code = nil)
    current_code = code ? code.to_i : @config['term_code'].to_i
    previous_code = current_code - ((current_code % 10 == 2) ? 4 : 3)
    previous_code.to_s
  end

  # Returns the semester session start date for testing activity alerts
  def self.term_start_date
    @config['term_start_date']
  end

  def self.shuffle_max_users
    @config['shuffle_max_users']
  end

  # Returns the department code to use for testing drop-in appointments
  def self.appts_drop_in_dept
    @config['appts_drop_in_dept']
  end

  def self.degree_major
    @config['test_degree_progress_major']
  end

  def self.degree_templates_max
    @config['degree_templates_max']
  end

  # Returns the number of SIDs to add during bulk SID group tests
  def self.group_bulk_sids_max
    @config['group_bulk_sids_max']
  end

  # Whether or not to check tooltips during tests. Checking tooltips slows down test execution.
  def self.tooltips
    @config['tooltips']
  end

  # Whether or not to check Nessie assignment scores during tests.
  def self.nessie_scores
    @config['nessie_scores']
  end

  # Whether or not to check Nessie assignments submission counts during tests.
  def self.nessie_assignments
    @config['nessie_assignments']
  end

  # Whether or not to compare student data to fellow cohort members in Canvas prod
  def self.last_activity_context
    @config['last_activity_context']
  end

  # Returns the number of days into a session before activity alerts are generated
  def self.no_activity_alert_threshold
    @config['no_activity_alert_threshold']
  end

  # Returns the maximum number of a student's notes to use in testing note content
  def self.notes_max_notes
    @config['notes_max_notes']
  end

  # Returns the maximum number of note or appointment searches to execute for a given student
  def self.search_max_searches
    @config['search_max_searches']
  end

  # The number of words to use in a note or appointment search string
  def self.search_word_count
    @config['search_word_count']
  end

  # Logs error, prints stack trace, and saves a screenshot when running headlessly
  def self.log_error_and_screenshot(driver, error, unique_id)
    log_error error
    save_screenshot(driver, unique_id) if Utils.headless?
  end

  # SEARCH TEST DATA

  # Returns the file path containing stored searchable student data to drive cohort search tests
  # @return [String]
  def self.searchable_data
    File.join(Utils.config_dir, "boac-searchable-data-#{Time.now.strftime('%Y-%m-%d')}.json")
  end

  def self.searchable_admit_data
    File.join(Utils.config_dir, "boac-searchable-admit-data-#{Time.now.strftime('%Y-%m-%d')}.json")
  end

  # Returns the db credentials for BOAC
  # @return [Hash]
  def self.boac_db_credentials
    {
      host: @config['db_host'],
      port: @config['db_port'],
      name: @config['db_name'],
      user: @config['db_user'],
      password: @config['db_password']
    }
  end

  def self.generate_note_search_query(student, note, opts={})
    note_test_case = "UID #{student.uid} note ID #{note.id}"

    if note.source_body_empty || !note.body || note.body.empty?
      if !note.subject || note.subject.empty?
        logger.warn "Skipping search test for #{note_test_case} because the note has no body or subject."
        return nil
      elsif opts[:skip_empty_body]
        logger.warn "Skipping search test for #{note_test_case} because the note body was empty and too many results will be returned."
        return nil
      else
        note_text = note.subject
      end
    else
      note_text = Nokogiri::HTML(note.body).text
    end

    search_string = note_text.split[0..(search_word_count-1)].join(' ')
    {
      :note => note,
      :test_case => note_test_case,
      :string => search_string
    }
  end

  def self.generate_appt_search_query(student, appt)
    test_case = "UID #{student.uid} appointment ID #{appt.id}"
    # If the detail is too short, then searches are useless
    search_string = Nokogiri::HTML(appt.detail).text.split[0..(search_word_count - 1)].join(' ') if appt.detail.length >= 3
    {
      :appt => appt,
      :test_case => test_case,
      :string => search_string
    }
  end

  # ATTACHMENTS TEST DATA

  # The file path for SuiteC asset upload files
  # @param file_name [String]
  def self.test_data_file_path(file_name)
    File.join(Utils.config_dir, "boa-attachments/#{file_name}")
  end

  # DATABASE - USERS

  # Returns all admin users
  # @return [Array<BOACUser>]
  def self.get_admin_users
    query = 'SELECT authorized_users.uid AS uid
              FROM authorized_users
              WHERE authorized_users.is_admin = true;'
    results = query_pg_db(boac_db_credentials, query)
    results.map { |r| BOACUser.new({uid: r['uid']}) }
  end

  def self.get_user_login_count(user)
    query = "SELECT COUNT(*) FROM user_logins WHERE uid = '#{user.uid}';"
    query_pg_db_field(boac_db_credentials, query, 'count').first.to_i
  end

  # Returns all authorized user UIDs, non-deleted note counts, and last logins
  # @return [Array<Hash>]
  def self.get_last_login_and_note_count
    query = 'SELECT authorized_users.uid AS uid,
	                  COUNT(DISTINCT notes.id) AS note_count,
	                  MAX(user_logins.created_at) AS last_login
	           FROM authorized_users
	           LEFT JOIN notes ON authorized_users.uid = notes.author_uid
	           LEFT JOIN user_logins ON authorized_users.uid = user_logins.uid
             WHERE notes.deleted_at IS NULL
	           GROUP BY authorized_users.uid;'
    results = query_pg_db(boac_db_credentials, query)
    results.map do |r|
      {
        uid: r['uid'],
        note_count: r['note_count'],
        last_login: (Time.parse(r['last_login'].to_s).utc.localtime if r['last_login'])
      }
    end
  end

  # Creates an admin authorized user
  # @param user [BOACUser]
  def self.create_admin_auth_user(user)
    statement = "INSERT INTO authorized_users (created_at, updated_at, uid, is_admin, in_demo_mode, can_access_canvas_data, created_by, is_blocked)
                 SELECT now(), now(), '#{user.uid}', true, false, true, '#{Utils.super_admin_uid}', false
                 WHERE NOT EXISTS (SELECT id FROM authorized_users WHERE uid = '#{user.uid}');"
    result = query_pg_db(boac_db_credentials, statement)
    logger.warn "Command status: #{result.cmd_status}. Result status: #{result.result_status}"
  end

  def self.get_dept_id(dept)
    statement_0 = "SELECT id FROM university_depts WHERE dept_code = '#{dept.code}';"
    query_pg_db_field(boac_db_credentials, statement_0, 'id').first
  end

  def self.soft_delete_auth_user(user)
    statement = "UPDATE authorized_users SET deleted_at = NOW() WHERE uid = '#{user.uid}';"
    result = query_pg_db(boac_db_credentials, statement)
    logger.warn "Command status: #{result.cmd_status}. Result status: #{result.result_status}"
  end

  def self.restore_auth_user(user)
    statement = "UPDATE authorized_users SET deleted_at = NULL WHERE uid = '#{user.uid}';"
    result = query_pg_db(boac_db_credentials, statement)
    logger.warn "Command status: #{result.cmd_status}. Result status: #{result.result_status}"
  end

  # Deletes an authorized user
  # @param user [BOACUser]
  def self.hard_delete_auth_user(user)
    statement_1 = "DELETE FROM authorized_users WHERE uid = '#{user.uid}';"
    result_1 = query_pg_db(boac_db_credentials, statement_1)
    logger.warn "Command status: #{result_1.cmd_status}. Result status: #{result_1.result_status}"

    statement_2 = "DELETE FROM json_cache WHERE key = 'calnet_user_for_uid_' || '#{user.uid}';"
    result_2 = query_pg_db(boac_db_credentials, statement_2)
    logger.warn "Command status: #{result_2.cmd_status}. Result status: #{result_2.result_status}"
  end

  # Deletes a drop-in-advisor row for a given user
  # @param user [BOACUser]
  def self.delete_drop_in_advisor(user)
    statement  = "DELETE FROM drop_in_advisors WHERE authorized_user_id = (SELECT id from authorized_users WHERE uid = '#{user.uid}');"
    result = query_pg_db(boac_db_credentials, statement)
    logger.warn "Command status: #{result.cmd_status}. Result status: #{result.result_status}"
  end

  # Returns all authorized users along with any associated department advisor roles
  # @return [Array<BOACUser>]
  def self.get_authorized_users
    query = "SELECT
              authorized_users.uid AS uid,
              authorized_users.can_access_advising_data AS can_access_advising_data,
              authorized_users.can_access_canvas_data AS can_access_canvas_data,
              authorized_users.deleted_at AS deleted_at,
              authorized_users.is_admin AS is_admin,
              authorized_users.is_blocked AS is_blocked,
              authorized_users.degree_progress_permission AS deg_prog_perm,
              university_dept_members.automate_membership AS is_automated,
              university_dept_members.role AS advisor_role,
              EXISTS (SELECT drop_in_advisors.dept_code
                      FROM drop_in_advisors
                      WHERE drop_in_advisors.authorized_user_id = authorized_users.id) AS is_drop_in_advisor,
              university_depts.dept_code AS dept_code,
              drop_in_advisors.is_available AS is_drop_in_available,
              drop_in_advisors.status AS drop_in_status
            FROM authorized_users
            LEFT JOIN university_dept_members
              ON authorized_users.id = university_dept_members.authorized_user_id
            LEFT JOIN university_depts
              ON university_dept_members.university_dept_id = university_depts.id
            LEFT JOIN drop_in_advisors
              ON university_depts.dept_code = drop_in_advisors.dept_code
              AND authorized_users.id = drop_in_advisors.authorized_user_id
            ORDER BY uid ASC;"
    results = query_pg_db(boac_db_credentials, query)

    advisors = results.group_by { |r1| r1['uid'] }.map do |k,v|
      logger.info "Getting advisor role(s) for UID #{k}"
      # TODO - clarify the following definition of 'active'
      active = v[0]['deleted_at'].nil?
      can_access_advising_data = (v[0]['can_access_advising_data'] == 't')
      can_access_canvas_data = (v[0]['can_access_canvas_data'] == 't')
      is_admin = (v[0]['is_admin'] == 't')
      is_blocked = (v[0]['is_blocked'] == 't')
      degree_progress_perm = case v[0]['deg_prog_perm']
                             when 'read' then DegreeProgressPerm::READ
                             when 'read_write' then DegreeProgressPerm::WRITE
                             else nil
                             end
      roles = v.map do |role|
        DeptMembership.new(
            {
                advisor_role: (AdvisorRole::ROLES.find { |r| r.code == role['advisor_role'] }),
                dept: (BOACDepartments::DEPARTMENTS.find { |d| d.code == role['dept_code']}),
                is_automated: (role['is_automated'] && role['is_automated'] == 't'),
                is_drop_in_available: (role['is_drop_in_available'] && role['is_drop_in_available'] == 't'),
                is_drop_in_advisor: (role['is_drop_in_advisor'] && role['is_drop_in_advisor'] == 't'),
                drop_in_status: (role['drop_in_status'])
            }
        )
      end
      BOACUser.new(
         {
             uid: k,
             dept_memberships: roles,
             can_access_advising_data: can_access_advising_data,
             can_access_canvas_data: can_access_canvas_data,
             degree_progress_perm: degree_progress_perm,
             depts: roles.map(&:dept).compact,
             active: active,
             is_admin: is_admin,
             is_blocked: is_blocked
          }
      )
    end
    logger.debug "There are #{advisors.length} total advisors out of #{results.values.length} total advisor roles"
    advisors
  end

  # Returns all the advisors associated with a department, optionally limited to those with a given role
  # @param dept [BOACDepartments]
  # @param membership [DeptMembership]
  # @return [Array<BOACUser>]
  def self.get_dept_advisors(dept, membership = nil)
    # "Notes Only" isn't a real department and requires special rules.
    if dept == BOACDepartments::NOTES_ONLY
      query = "SELECT
              authorized_users.uid AS uid,
              authorized_users.can_access_advising_data AS can_access_advising_data,
              authorized_users.can_access_canvas_data AS can_access_canvas_data,
              authorized_users.degree_progress_permission AS deg_prog_perm,
              string_agg(ud.dept_code,',') AS depts
            FROM authorized_users
            JOIN university_dept_members udm
              ON authorized_users.id = udm.authorized_user_id
            JOIN university_depts ud
              ON udm.university_dept_id = ud.id
            WHERE authorized_users.deleted_at IS NULL
              AND authorized_users.can_access_canvas_data IS FALSE
              #{' AND udm.role = \'' + membership.advisor_role.code + '\'' if membership&.advisor_role}
              #{' AND EXISTS (SELECT drop_in_advisors.authorized_user_id
                          FROM drop_in_advisors
                          WHERE drop_in_advisors.authorized_user_id = authorized_users.id
                            AND ud.dept_code = drop_in_advisors.dept_code) ' if membership&.is_drop_in_advisor}
            GROUP BY authorized_users.uid, authorized_users.can_access_advising_data, authorized_users.can_access_canvas_data,
                     authorized_users.degree_progress_permission"
    else
      query = "SELECT
              authorized_users.uid AS uid,
              authorized_users.can_access_advising_data AS can_access_advising_data,
              authorized_users.can_access_canvas_data AS can_access_canvas_data,
              authorized_users.degree_progress_permission AS deg_prog_perm,
              string_agg(ud2.dept_code,',') AS depts
            FROM authorized_users
            JOIN university_dept_members udm1
              ON authorized_users.id = udm1.authorized_user_id
            JOIN university_depts ud1
              ON udm1.university_dept_id = ud1.id
              AND ud1.dept_code = '#{dept.code}'
            JOIN university_dept_members udm2
              ON authorized_users.id = udm2.authorized_user_id
            JOIN university_depts ud2
              ON udm2.university_dept_id = ud2.id
            WHERE authorized_users.deleted_at IS NULL
              #{' AND udm1.role = \'' + membership.advisor_role.code + '\'' if membership&.advisor_role}
              #{' AND EXISTS (SELECT drop_in_advisors.authorized_user_id
                              FROM drop_in_advisors
                              WHERE drop_in_advisors.authorized_user_id = authorized_users.id
                                AND drop_in_advisors.dept_code = ud1.dept_code) ' if membership&.is_drop_in_advisor}
            GROUP BY authorized_users.uid, authorized_users.can_access_advising_data, authorized_users.can_access_canvas_data,
                     authorized_users.degree_progress_permission"
    end
    results = query_pg_db(boac_db_credentials, query)
    results.map do |r|
      dept_memberships = r['depts'].split(',').map do |code|
        DeptMembership.new(dept: (BOACDepartments::DEPARTMENTS.find { |d| d.code == code }))
      end
      degree_progress_perm = case r['deg_prog_perm']
                             when 'read' then DegreeProgressPerm::READ
                             when 'read_write' then DegreeProgressPerm::WRITE
                             else nil
                             end
      BOACUser.new(
          uid: r['uid'],
          active: true,
          can_access_advising_data: (r['can_access_advising_data'] == 't'),
          can_access_canvas_data: (r['can_access_canvas_data'] == 't'),
          degree_progress_perm: degree_progress_perm,
          depts: r['depts'].split(','),
          dept_memberships: dept_memberships
      )
    end
  end

  def self.set_advisor_data(advisor)
    query = "SELECT sid, author_name
              FROM notes
              WHERE author_uid = '#{advisor.uid}';"
    results = Utils.query_pg_db(boac_db_credentials, query)
    if results.any?
      advisor.sis_id = results[0]['sid']
      advisor.full_name = results[0]['author_name']
    end
  end

  # Returns all SIDs in the manual advisee table
  # @return [Array[<String>]]
  def self.manual_advisee_sids
    query = 'SELECT sid
             FROM manually_added_advisees;'
    query_pg_db(boac_db_credentials, query).map { |r| r['sid'] }
  end

  # Returns non-current student SIDs who should have complete data feeds since they were added to the list before today
  # @return [Array<String>]
  def self.deluxe_manual_advisee_sids
    query = "SELECT sid
             FROM manually_added_advisees
             WHERE created_at < TIMESTAMP '#{Date.today.strftime('%Y-%m-%d')}';"
    query_pg_db(boac_db_credentials, query).map { |r| r['sid'] }
  end

  # Whether or not a given student is in the manually added advisee list
  # @param [BOACUser] student
  # @return [Boolean]
  def self.student_in_deluxe_list?(student)
    query = "SELECT sid
             FROM manually_added_advisees
             WHERE sid = '#{student.sis_id}';"
    query_pg_db(boac_db_credentials, query).values.any?
  end

  # DATABASE - CURATED GROUPS

  # Returns the curated groups belonging to a given user
  # @param user [BOACUser]
  # @return [Array<CuratedGroup>]
  def self.get_user_curated_groups(user)
    query = "SELECT student_groups.id AS id, student_groups.name AS name
              FROM student_groups
              JOIN authorized_users ON authorized_users.id = student_groups.owner_id
              WHERE authorized_users.uid = '#{user.uid}';"
    results = Utils.query_pg_db(boac_db_credentials, query)
    results.map { |r| CuratedGroup.new({id: r['id'], name: r['name'], owner_uid: user.uid}) }
  end

  # Obtains and sets the ID given a curated group with a unique title
  # @param group [CuratedGroup]
  def self.set_curated_group_id(group)
    query = "SELECT id
              FROM student_groups
              WHERE name = '#{group.name}';"
    result = Utils.query_pg_db_field(boac_db_credentials, query, 'id').first
    logger.info "Curated group '#{group.name}' ID is #{result}"
    group.id = result
  end

  # DATABASE - FILTERED COHORTS

  # Returns the filtered cohorts belonging to a given user
  # @param user [BOACUser]
  # @return [Array<FilteredCohort>]
  def self.get_user_filtered_cohorts(user, opts = {})
    query = "SELECT cohort_filters.id AS cohort_id,
                    cohort_filters.name AS cohort_name,
                    cohort_filters.filter_criteria AS criteria
              FROM cohort_filters
              JOIN authorized_users ON authorized_users.id = cohort_filters.owner_id
              WHERE cohort_filters.domain = #{if opts[:default]
                                                '\'default\' '
                                              elsif opts[:admits]
                                                '\'admitted_students\' '
                                              end}
                AND authorized_users.uid = '#{user.uid}';"
    results = Utils.query_pg_db(boac_db_credentials, query)
    results.map do |r|
      FilteredCohort.new({id: r['cohort_id'], name: r['cohort_name'], owner_uid: user.uid})
    end
  end

  # Returns all (default) filtered cohorts. If a department is given, then returns only the cohorts associated with that department.
  # @param dept [BOACDepartments]
  # @return [Array<FilteredCohort>]
  def self.get_everyone_filtered_cohorts(opts = {}, dept = nil)
    query = "SELECT cohort_filters.id AS cohort_id,
                    cohort_filters.name AS cohort_name,
                    cohort_filters.filter_criteria AS criteria,
                    authorized_users.uid AS uid
              FROM cohort_filters
              JOIN authorized_users
                  ON authorized_users.id = cohort_filters.owner_id
                  AND authorized_users.deleted_at IS NULL
              #{if dept
                 'JOIN university_dept_members ON university_dept_members.authorized_user_id = authorized_users.id
                  JOIN university_depts ON university_depts.id = university_dept_members.university_dept_id
                  WHERE university_depts.dept_code = \'' + dept.code + '\' '
                end}
              #{if opts[:default]
                  (dept ? 'AND ' : 'WHERE ') + 'cohort_filters.domain = \'default\' '
                elsif opts[:admits]
                  (dept ? 'AND ' : 'WHERE ') + 'cohort_filters.domain = \'admitted_students\' '
                end}
              ORDER BY uid, cohort_id ASC;"
    results = Utils.query_pg_db(boac_db_credentials, query)
    cohorts = results.map { |r| FilteredCohort.new({id: r['cohort_id'], name: r['cohort_name'].gsub(/\s+/, ' ').strip, owner_uid: r['uid']}) }
    cohorts.sort_by { |c| [c.owner_uid.to_i, c.id] }
  end

  # Returns all curated groups. If a department is given, then returns only the groups associated with that department.
  # @param dept [BOACDepartments]
  # @return [Array<CuratedGroup>]
  def self.get_everyone_curated_groups(dept = nil)
    query = "SELECT student_groups.id AS group_id,
                    student_groups.name AS group_name,
                    authorized_users.uid AS uid
              FROM student_groups
              JOIN authorized_users
                  ON authorized_users.id = student_groups.owner_id
                  AND authorized_users.deleted_at IS NULL
              #{if dept
                 'JOIN university_dept_members ON university_dept_members.authorized_user_id = authorized_users.id
                  JOIN university_depts ON university_depts.id = university_dept_members.university_dept_id
                  WHERE university_depts.dept_code = \'' + dept.code + '\' '
                end}
              ORDER BY uid, group_id ASC;"
    results = Utils.query_pg_db(boac_db_credentials, query)
    groups = results.map { |r| CuratedGroup.new({id: r['group_id'], name: r['group_name'].gsub(/\s+/, ' ').strip, owner_uid: r['uid']}) }
    groups.sort_by { |c| [c.owner_uid.to_i, c.id] }
  end

  # Obtains and sets the cohort ID given a filtered cohort with a unique title
  # @param cohort [FilteredCohort]
  # @return [Integer]
  def self.set_filtered_cohort_id(cohort)
    query = "SELECT id
             FROM cohort_filters
             WHERE name = '#{cohort.name}';"
    result = Utils.query_pg_db_field(boac_db_credentials, query, 'id').first
    logger.info "Filtered cohort '#{cohort.name}' ID is #{result}"
    cohort.id = result
  end

  # DATABASE - ALERTS, HOLDS, NOTES

  def self.get_alert_count_per_range(from_date, to_date)
    sql = "SELECT COUNT(*)
           FROM alerts
           WHERE created_at >= '#{from_date.strftime('%Y-%m-%d')}'
             AND created_at < '#{(to_date + 1).strftime('%Y-%m-%d')}';"
    Utils.query_pg_db_field(boac_db_credentials, sql, 'count').first.to_i
  end

  # Given a set of students, returns all their active alerts in the current term
  # @param users [Array<BOACUser>]
  # @return [Array<Alert>]
  def self.get_students_alerts(users)
    sids = users.map(&:sis_id).to_s.delete('[]')
    query = "SELECT id, sid, alert_type, message, created_at, updated_at
              FROM alerts
              WHERE sid IN (#{sids})
                AND deleted_at IS NULL
                AND key LIKE '#{term_code}%'
                AND alert_type != 'hold';"
    results = Utils.query_pg_db(boac_db_credentials, query.gsub("\"", '\''))
    alerts = results.map do |r|
      date = %w(midterm withdrawal).include?(r['alert_type']) ? r['created_at'] : r['updated_at']
      Alert.new(id: r['id'],
                type: r['alert_type'],
                message: r['message'].gsub("\n", ' ').gsub(/\s+/, ' '),
                user: BOACUser.new({sis_id: r['sid']}),
                date: Time.parse(date))
    end
    alerts.sort_by &:message
  end

  # Given a set of students, returns all their active alerts in the current term that have not been dismissed by an advisor. If no
  # advisor is specified, then the test admin user is the advisor by default.
  def self.get_un_dismissed_users_alerts(students, advisor = nil)
    alerts = get_students_alerts students
    dismissed_alerts = get_dismissed_alerts(alerts, advisor)
    alerts - dismissed_alerts
  end

  # Given a set of alerts, returns those that have been dismissed by an advisor. If no advisor is specificed, then the test admin user
  # is the advisor by default.
  # @param alerts [Array<Alert>]
  # @param advisor [BOACUser]
  # @return [Array<Alert>]
  def self.get_dismissed_alerts(alerts, advisor = nil)
    if alerts.any?
      alert_ids = (alerts.map &:id).join(', ')
      query = "SELECT alert_views.alert_id
                FROM alert_views
                JOIN authorized_users ON authorized_users.id = alert_views.viewer_id
                WHERE alert_views.alert_id IN (#{alert_ids})
                  AND authorized_users.uid = '#{advisor ? advisor.uid : Utils.super_admin_uid}';"
      results = Utils.query_pg_db(boac_db_credentials, query.gsub("\"", '\''))
      dismissed = results.map { |r| r['alert_id'].to_s }
      alerts.select { |a| dismissed.include? a.id }
    else
      alerts
    end
  end

  # Deletes the dismissal of an alert by a given advisor or the admin test user by default
  # @param alert [Alert]
  # @param advisor [BOACUser]
  def self.remove_alert_dismissal(alert, advisor = nil)
    query = "DELETE
              FROM alert_views
              WHERE alert_views.alert_id = '#{alert.id}'
                AND alert_views.viewer_id IN (SELECT authorized_users.id
                                              FROM authorized_users
                                              WHERE authorized_users.uid = '#{advisor ? advisor.uid : Utils.super_admin_uid}');"
    Utils.query_pg_db(boac_db_credentials, query)
  end

  # Returns an alert that has not been dismissed by the admin test user
  # @return [Alert]
  def self.get_test_alert
    # Get one active alert in the current term
    query = "SELECT alerts.id, alerts.sid, alerts.alert_type, alerts.message
              FROM alerts
              WHERE active = true
                AND key LIKE '#{term_code}%'
              LIMIT 1;"
    results = Utils.query_pg_db(boac_db_credentials, query)
    alert = (results.map { |r| Alert.new({id: r['id'], message: r['message'], user: BOACUser.new({sis_id: r['sid']})}) }).first
    # If an alert exists and the admin tester has dismissed the alert, delete the dismissal to permit dismissal testing
    if alert
      remove_alert_dismissal(alert) if get_dismissed_alerts([alert]).any?
      logger.info "Test alert ID #{alert.id}, message '#{alert.message}', user SID #{alert.user.sis_id}"
    end
    alert
  end

  # Returns the number of non-deleted notes
  # @return [String]
  def self.get_total_note_count
    query = 'SELECT COUNT(*) FROM notes WHERE deleted_at IS NULL;'
    Utils.query_pg_db_field(boac_db_credentials, query, 'count').first
  end

  # Returns the number of distinct non-deleted note authors
  # @return [String]
  def self.get_distinct_note_author_count
    query = 'SELECT COUNT(DISTINCT author_uid) FROM notes WHERE deleted_at IS NULL;'
    Utils.query_pg_db_field(boac_db_credentials, query, 'count').first
  end

  # Returns the number of non-deleted notes with non-deleted attachments
  # @return [String]
  def self.get_notes_with_attachments_count
    query = 'SELECT COUNT(DISTINCT note_attachments.note_id)
             FROM note_attachments
             JOIN notes ON notes.id = note_attachments.note_id
             WHERE note_attachments.deleted_at IS NULL
               AND notes.deleted_at IS NULL;'
    Utils.query_pg_db_field(boac_db_credentials, query, 'count').first
  end

  def self.get_note_attachments
    query = 'SELECT id
             FROM note_attachments
             WHERE deleted_at IS NULL;'
    results = Utils.query_pg_db(boac_db_credentials, query)
    results.map { |r| Attachment.new(id: r['id']) }
  end

  # Returns the number of non-deleted notes with non-deleted topics
  # @return [String]
  def self.get_notes_with_topics_count
    query = 'SELECT COUNT(DISTINCT note_topics.note_id)
             FROM note_topics
             JOIN notes ON notes.id = note_topics.note_id
             WHERE note_topics.deleted_at IS NULL
               AND notes.deleted_at IS NULL;'
    Utils.query_pg_db_field(boac_db_credentials, query, 'count').first
  end

  def self.get_sids_with_notes_of_src_boa
    query = 'SELECT DISTINCT sid FROM notes;'
    results = Utils.query_pg_db(boac_db_credentials, query)
    results.map { |r| r['sid'] }
  end

  # Returns a student's advising notes
  # @param student [BOACUser]
  # @return [Array<Note>]
  def self.get_student_notes(student)
    query = "SELECT * FROM notes WHERE sid = '#{student.sis_id}';"
    results = Utils.query_pg_db(boac_db_credentials, query)
    result_ids = results.map { |r| r['id'] }
    notes_data = []

    if result_ids.any?
      attach_query = "SELECT * FROM note_attachments WHERE note_id IN (#{result_ids.join(',')});"
      attach_results = Utils.query_pg_db(boac_db_credentials, attach_query)

      topic_query = "SELECT note_id, topic FROM note_topics WHERE note_id IN (#{result_ids.join(',')});"
      topic_results = Utils.query_pg_db(boac_db_credentials, topic_query)

      notes_data = results.map do |r|
        depts = BOACDepartments::DEPARTMENTS.select { |d| r['author_dept_codes'].include? d.code  }
        advisor_data = {
            :uid => r['author_uid'],
            :full_name => r['author_name'],
            :role => r['author_role'],
            :depts => depts.map(&:name)
        }

        note_data = {
            :id => r['id'],
            :subject => r['subject'],
            :body => (r['body'] && Nokogiri::HTML(r['body']).text),
            :advisor => BOACUser.new(advisor_data),
            :created_date => Time.parse(r['created_at'].to_s).utc.localtime,
            :updated_date => Time.parse(r['updated_at'].to_s).utc.localtime,
            :deleted_date => (Time.parse(r['deleted_at'].to_s) if r['deleted_at'])
        }

        attachments = attach_results.select { |a| a['note_id'] == note_data[:id] }.map do |a|
          file_name = a['path_to_attachment'].split('/').last
          # Boa attachment file names should be prefixed with a timestamp, but some older test file names are not
          visible_file_name = file_name[0..15].gsub(/(20)\d{6}(_)\d{6}(_)/, '').empty? ? file_name[16..-1] : file_name
          Attachment.new({:id => a['id'], :file_name => visible_file_name, :deleted_at => a['deleted_at']})
        end
        note_data.merge!(:attachments => attachments)

        topics = topic_results.select { |t| t['note_id'] == note_data[:id] }.map { |t| t['topic'] }
        note_data.merge!(:topics => topics)
      end
    end

    notes_data.map { |d| Note.new d }
  end

  def self.get_note_count_by_subject(note)
    query = "SELECT COUNT(*) FROM notes WHERE subject = '#{note.subject}';"
    result = Utils.query_pg_db(boac_db_credentials, query)
    res = result.getvalue(0, 0).to_i
    logger.info "Note count is '#{res}'"
    res
  end

  # Given a note subject, sets and returns the first matching note ID. The subject must be unique for this to be useful.
  # @param note_subject [String]
  # @return [Array<Integer>]
  def self.get_note_ids_by_subject(note_subject, student=nil)
    query = "SELECT id FROM notes WHERE subject = '#{note_subject}'#{+ ' AND sid = \'' + student.sis_id + '\'' if student};"
    Utils.query_pg_db_field(boac_db_credentials, query, 'id')
  end

  def self.get_note_sids_by_subject(note)
    query = "SELECT sid FROM notes WHERE subject = '#{note.subject}' ORDER BY sid ASC;"
    sids = Utils.query_pg_db_field(boac_db_credentials, query, 'sid')
    logger.debug "Note SIDs are #{sids}"
    sids
  end

  # Sets and returns the deleted date for a given note
  # @param note [Note]
  def self.get_note_delete_status(note)
    query = "SELECT deleted_at FROM notes WHERE id = '#{note.id}';"
    note.deleted_date = Utils.query_pg_db_field(boac_db_credentials, query, 'deleted_at').first
    logger.debug "Deleted at is #{note.deleted_date}"
    note.deleted_date
  end

  # Sets and returns an attachment ID
  # @param note [Note]
  # @param attachment [Attachment]
  # @return [Integer]
  def self.get_attachment_id_by_file_name(note, attachment)
    query = "SELECT * FROM note_attachments WHERE note_id = #{note.id} AND path_to_attachment LIKE '%#{attachment.file_name}';"
    attachment.id = Utils.query_pg_db_field(boac_db_credentials, query, 'id').last
  end

  ### APPOINTMENTS ###

  # Returns all of a given department's appointments
  # @param dept [BOACDepartments]
  # @param students [Array<BOACUser>]
  # @return [Array<Appointment>]
  def self.get_dept_drop_in_appts(dept, students)
    query = "SELECT appointments.id AS id,
                    appointments.advisor_uid AS advisor_uid,
                    appointments.advisor_name AS advisor_full_name,
                    appointments.advisor_dept_codes AS advisor_dept_codes,
                    appointments.created_at AS created_date,
                    appointments.deleted_at AS deleted_date,
                    appointments.details AS detail,
                    appointments.status AS status,
                    (SELECT MAX(appointment_events.created_at)
                     FROM appointment_events
                     WHERE appointment_id = appointments.id) AS status_date,
                    appointments.student_sid AS student_sid,
                    appointment_events.cancel_reason AS cancel_reason,
                    appointment_events.cancel_reason_explained AS cancel_detail,
                    ARRAY_AGG (appointment_topics.topic) AS topics
              FROM appointments
              JOIN appointment_topics
                ON appointments.id = appointment_topics.appointment_id
              LEFT JOIN appointment_events
              	ON appointments.id = appointment_events.appointment_id
              WHERE appointment_type = 'Drop-in'
                AND appointments.dept_code = '#{dept.code}'
              GROUP BY appointments.id, advisor_uid, advisor_full_name, advisor_dept_codes, cancel_reason, cancel_detail,
                       created_date, deleted_date, detail, status, status_date, student_sid;"
    results = query_pg_db(boac_db_credentials, query)
    result_to_appts(results, students)
  end

  # Returns all a department's drop-in appointments created today
  # @param dept [BOACDepartments]
  # @param students [Array<BOACUser>]
  # @return [Array<Appointment>]
  def self.get_today_drop_in_appts(dept, students)
    all_appts = get_dept_drop_in_appts(dept, students)
    today = Date.today.strftime('%Y-%m-%d')
    all_appts.select { |a| a.created_date.strftime('%Y-%m-%d') == today }
  end

  # Returns all of a given students's appointments
  # @param student [BOACUser]
  # @return [Array<Appointment>]
  def self.get_student_appts(student, all_students)
    query = "SELECT appointments.id AS id,
                    appointments.student_sid AS student_sid,
                    appointments.advisor_uid AS advisor_uid,
                    appointments.advisor_name AS advisor_full_name,
                    appointments.advisor_dept_codes AS advisor_dept_codes,
                    appointments.appointment_type AS type,
                    appointments.created_at AS created_date,
                    appointments.deleted_at AS deleted_date,
                    appointments.details AS detail,
                    appointments.status AS status,
                    (SELECT MAX(appointment_events.created_at)
                     FROM appointment_events
                     WHERE appointment_id = appointments.id) AS status_date,
                    appointment_events.cancel_reason AS cancel_reason,
                    appointment_events.cancel_reason_explained AS cancel_detail,
                    ARRAY_AGG (appointment_topics.topic) AS topics
              FROM appointments
              JOIN appointment_topics
                ON appointments.id = appointment_topics.appointment_id
              LEFT JOIN appointment_events
                ON appointments.id = appointment_events.appointment_id
              WHERE appointments.student_sid = '#{student.sis_id}'
              GROUP BY appointments.id, advisor_uid, advisor_full_name, advisor_dept_codes,
                type, created_date, deleted_date, detail, status, status_date, cancel_reason,
                cancel_detail;"
    results = query_pg_db(boac_db_credentials, query)
    result_to_appts(results, all_students)
  end

  # Returns the students who have BOA appointments
  # @param all_students [Array<BOACUser>]
  # @return [Array<BOACUser>]
  def self.get_students_with_appts(all_students)
    query = 'SELECT DISTINCT student_sid FROM appointments WHERE deleted_at IS NULL ORDER BY student_sid ASC;'
    results = query_pg_db(boac_db_credentials, query)
    sids = results.map { |r| r['student_sid'] }
    all_students.select { |s| sids.include? s.sis_id }
  end

  # Converts the results of an appointment query to an array of appointments
  # @param results [PG::Result]
  # @param student [Array<BOACUser>]
  # @return [Array<Appointment>]
  def self.result_to_appts(results, all_students)
    results.map do |r|
      status = r['status'] && AppointmentStatus::STATUSES.find { |s| s.code == r['status'].downcase }
      student = all_students.find { |s| s.sis_id == r['student_sid'] }
      topics = Topic::TOPICS.select { |t| r['topics'].include? t.name }
      if r['advisor_uid']
        advisor_depts = BOACDepartments::DEPARTMENTS.select { |d| r['advisor_dept_codes'].include? d.code }
        advisor = BOACUser.new(
            uid: r['advisor_uid'],
            full_name: r['advisor_full_name'],
            depts: advisor_depts
        )
      end
      Appointment.new(
          id: r['id'],
          advisor: advisor,
          detail: r['detail'],
          status: status,
          status_date: r['status_date'],
          student: student,
          topics: topics,
          type: r['type'],
          cancel_detail: r['cancel_detail'],
          cancel_reason: r['cancel_reason'],
          created_date: (r['created_date'] && Time.parse(r['created_date'].to_s).utc.localtime),
          deleted_date: (r['deleted_date'] && Time.parse(r['deleted_date'].to_s).utc.localtime)
      )
    end
  end

  # @param appt [Appointment]
  def self.get_appt_creation_data(appt)
    query = "SELECT id, created_at FROM appointments WHERE details LIKE '%#{appt.detail}%'"
    results = query_pg_db(boac_db_credentials, query)
    appt.id = results[0]['id']
    appt.created_date = Time.parse(results[0]['created_at'].to_s).utc.localtime
    logger.info "Appointment ID is #{appt.id}"
    appt.inspect
  end

  def self.delete_appts(appts)
    if appts.any?
      statement = "UPDATE appointments
             SET deleted_at = NOW()
             WHERE id IN (#{appts.map(&:id).join(',')})
               AND deleted_at IS NULL;"
      query_pg_db(boac_db_credentials, statement)
    else
      logger.warn 'There are no appointments to delete'
    end
  end

  def self.get_drop_in_advisors_and_status(dept)
    query = "SELECT authorized_users.uid,
                    drop_in_advisors.status
             FROM authorized_users
             JOIN drop_in_advisors ON authorized_users.id = drop_in_advisors.authorized_user_id
             JOIN university_dept_members ON authorized_users.id = university_dept_members.authorized_user_id
             JOIN university_depts ON university_dept_members.university_dept_id = university_depts.id
             WHERE university_depts.dept_code = '#{dept.code}'
               AND drop_in_advisors.is_available = true;"
    results = query_pg_db(boac_db_credentials, query)
    advisors = results.map do |r|
      status = r['status']
      {
        uid: r['uid'],
        status: "#{status.strip if status}"
      }
    end
    advisors.sort_by { |h| h[:uid] }
  end

  ### TOPICS/REASONS ###

  def self.get_topic_id(topic)
    sql = "SELECT id FROM topics WHERE topic = '#{topic.name}'"
    topic.id = query_pg_db_field(boac_db_credentials, sql, 'id').last
  end

  def self.hard_delete_topic(topic)
    sql = "DELETE FROM topics WHERE id = '#{topic.id}'"
    query_pg_db(boac_db_credentials, sql)
  end

end
