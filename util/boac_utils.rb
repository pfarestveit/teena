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

  def self.degree_major
    @config['test_degree_progress_major']
  end

  # Returns the number of SIDs to add during bulk SID group tests
  def self.group_bulk_sids_max
    @config['group_bulk_sids_max']
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

    if note.source_body_empty || !note.body || note.body.to_s.empty? || note.body.include?('http')
      if !note.subject || note.subject.empty?
        logger.warn "Skipping search test for #{note_test_case} because the note has no body or subject."
        return nil
      elsif opts[:skip_empty_body]
        logger.warn "Skipping search test for #{note_test_case} because the note body was empty and too many results will be returned."
        return nil
      else
        note_text = note.subject
      end
    elsif note.is_private
      logger.warn "Skipping search test for #{note_test_case} because the note is private."
      return nil
    else
      note_text = note.body
    end

    search_phrases = note_text.split(/(<\w+>|<\/\w+>)/)
    search_string = search_phrases.find { |p| p.length > 24 }
    {
      :note => note,
      :test_case => note_test_case,
      :string => (search_string[0..23].strip if search_string)
    }
  end

  def self.generate_appt_search_query(student, appt)
    test_case = "UID #{student.uid} appointment ID #{appt.id}"
    return nil unless appt.detail
    search_phrases = appt.detail.split(/(<\w+>|<\/\w+>)/)
    search_string = search_phrases.find { |p| p.length > 24 }
    {
      :appt => appt,
      :test_case => test_case,
      :string => (search_string[0..23].strip if search_string)
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
               AND notes.is_draft IS FALSE
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
              authorized_users.automate_degree_progress_permission AS deg_prog_automated,
              university_dept_members.automate_membership AS is_automated,
              university_dept_members.role AS advisor_role,
              university_depts.dept_code AS dept_code
            FROM authorized_users
            LEFT JOIN university_dept_members
              ON authorized_users.id = university_dept_members.authorized_user_id
            LEFT JOIN university_depts
              ON university_dept_members.university_dept_id = university_depts.id
            ORDER BY uid ASC;"
    results = query_pg_db(boac_db_credentials, query)

    advisors = results.group_by { |r1| r1['uid'] }.map do |k,v|
      logger.info "Getting advisor role(s) for UID #{k}"
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
      degree_progress_automated = v[0]['deg_prog_automated']
      roles = v.map do |role|
        DeptMembership.new(
            {
                advisor_role: (AdvisorRole::ROLES.find { |r| r.code == role['advisor_role'] }),
                dept: (BOACDepartments::DEPARTMENTS.find { |d| d.code == role['dept_code']}),
                is_automated: (role['is_automated'] && role['is_automated'] == 't')
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
             degree_progress_automated: degree_progress_automated,
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
      depts = r['depts'].split(',').map { |code| BOACDepartments::DEPARTMENTS.find { |d| d.code == code } }
      BOACUser.new(
          uid: r['uid'],
          active: true,
          can_access_advising_data: (r['can_access_advising_data'] == 't'),
          can_access_canvas_data: (r['can_access_canvas_data'] == 't'),
          degree_progress_perm: degree_progress_perm,
          depts: depts,
          dept_memberships: dept_memberships
      )
    end
  end

  def self.get_advisor_names(advisor)
    query = "SELECT author_name, created_at
               FROM notes
              WHERE author_uid = '#{advisor.uid}'
           ORDER BY created_at DESC;"
    results = Utils.query_pg_db(boac_db_credentials, query)
    names = results.map { |row| row['author_name'] }
    names.uniq!
    if names.any?
      advisor.full_name = names.first
      advisor.alt_names = names[1..-1]
    end
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
    query = 'SELECT COUNT(*) FROM notes WHERE deleted_at IS NULL AND is_draft IS FALSE;'
    Utils.query_pg_db_field(boac_db_credentials, query, 'count').first
  end

  # Returns the number of distinct non-deleted note authors
  # @return [String]
  def self.get_distinct_note_author_count
    query = 'SELECT COUNT(DISTINCT author_uid) FROM notes WHERE deleted_at IS NULL AND is_draft IS FALSE;'
    Utils.query_pg_db_field(boac_db_credentials, query, 'count').first
  end

  # Returns the number of non-deleted notes with non-deleted attachments
  # @return [String]
  def self.get_notes_with_attachments_count
    query = 'SELECT COUNT(DISTINCT note_attachments.note_id)
             FROM note_attachments
             JOIN notes ON notes.id = note_attachments.note_id
             WHERE note_attachments.deleted_at IS NULL
               AND notes.deleted_at IS NULL
               AND notes.is_draft IS FALSE;'
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
               AND notes.deleted_at IS NULL
               AND notes.is_draft IS FALSE;'
    Utils.query_pg_db_field(boac_db_credentials, query, 'count').first
  end

  def self.get_sids_with_notes_of_src_boa(drafts=false)
    query = "SELECT DISTINCT sid
             FROM notes
             WHERE body NOT LIKE '%QA Test%'
               AND deleted_at IS NULL
               AND is_private IS FALSE
               AND is_draft IS #{drafts ? 'TRUE' : 'FALSE'}"
    results = Utils.query_pg_db(boac_db_credentials, query)
    results.map { |r| r['sid'] }
  end

  def self.get_student_notes(student)
    query = "SELECT * FROM notes WHERE sid = '#{student.sis_id}';"
    result = Utils.query_pg_db(boac_db_credentials, query)
    get_notes_from_pg_db_result result
  end

  def self.get_notes_by_ids(ids)
    query = "SELECT * FROM notes WHERE id IN (#{ids.join(',')})"
    result = Utils.query_pg_db(boac_db_credentials, query)
    get_notes_from_pg_db_result result
  end

  def self.get_note_ids_by_subject(note_subject, student=nil)
    query = "SELECT id FROM notes WHERE subject = '#{note_subject}'#{+ ' AND sid = \'' + student.sis_id + '\'' if student} AND deleted_at IS NULL;"
    Utils.query_pg_db_field(boac_db_credentials, query, 'id')
  end

  def self.get_note_sids_by_subject(note)
    query = "SELECT sid FROM notes WHERE subject = '#{note.subject}' AND deleted_at IS NULL ORDER BY sid ASC;"
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

  def self.get_advisor_note_drafts(advisor=nil)
    query = "SELECT * FROM notes WHERE is_draft IS TRUE AND deleted_at IS NULL#{' AND author_uid = \'' + advisor.uid + '\'' if advisor};"
    result = Utils.query_pg_db(boac_db_credentials, query)
    get_notes_from_pg_db_result result
  end

  # Sets and returns an attachment ID
  # @param note [Note]
  # @param attachment [Attachment]
  # @return [Integer]
  def self.get_attachment_id_by_file_name(note, attachment)
    query = "SELECT * FROM note_attachments WHERE note_id = #{note.id} AND path_to_attachment LIKE '%#{attachment.file_name}';"
    attachment.id = Utils.query_pg_db_field(boac_db_credentials, query, 'id').last
  end

  def self.is_note_private?(note)
    query = "SELECT is_private FROM notes WHERE id = '#{note.id}'"
    result = Utils.query_pg_db_field(boac_db_credentials, query, 'is_private').last
    logger.debug "Result is '#{result}'"
    result == 't'
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

  ### DEGREE CHECKS

  def self.get_degree_templates
    query = "SELECT degree_progress_templates.id,
                    degree_progress_templates.degree_name,
                    degree_progress_templates.created_at
               FROM degree_progress_templates
              WHERE degree_progress_templates.deleted_at IS NULL
                AND degree_progress_templates.student_sid IS NULL
           ORDER BY degree_progress_templates.id ASC;"
    results = Utils.query_pg_db(BOACUtils.boac_db_credentials, query)
    templates = results.map do |r|
      DegreeProgressTemplate.new id: r['id'], name: r['degree_name'], created_date: Time.parse(r['created_at']).utc.localtime
    end
    logger.info "All template IDs: #{templates.map &:id}"
    templates
  end

  def self.get_student_degrees(student)
    query = "SELECT degree_progress_templates.id,
                    degree_progress_templates.degree_name,
	                  degree_progress_templates.updated_at,
	                  authorized_users.uid
               FROM degree_progress_templates
               JOIN authorized_users
                 ON authorized_users.id = degree_progress_templates.updated_by
              WHERE student_sid = '#{student.sis_id}'
           ORDER BY degree_progress_templates.updated_at DESC;"
    results = Utils.query_pg_db(BOACUtils.boac_db_credentials, query)
    degrees = results.map do |r|
      DegreeProgressTemplate.new id: r['id'], name: r['degree_name'], updated_by: r['uid'], updated_date: Time.parse(r['updated_at']).localtime
    end
    logger.info "SID #{student.sis_id} degree IDs: #{degrees.map &:id}"
    degrees
  end

  def self.get_degree_sids_by_degree_name(degree_name)
    query = "SELECT student_sid
             FROM degree_progress_templates
             WHERE degree_name = '#{degree_name}'
               AND student_sid IS NOT NULL
             ORDER BY student_sid ASC;"
    sids = Utils.query_pg_db(boac_db_credentials, query).map { |r| r['student_sid'].to_s }
    logger.debug "Degree SIDs are #{sids}"
    sids
  end

  def self.get_degree_id_by_name(degree, student)
    query = "SELECT id
             FROM degree_progress_templates
             WHERE degree_name = '#{degree.name}'
               AND student_sid = '#{student.sis_id}';"
    Utils.query_pg_db_field(boac_db_credentials, query, 'id')
  end

  def self.set_degree_manual_course_id(degree, course)
    query = "SELECT max(id) AS id
             FROM degree_progress_courses
             WHERE degree_check_id = '#{degree.id}'
               AND display_name = '#{course.name}';"
    id = Utils.query_pg_db_field(boac_db_credentials, query, 'id').first
    logger.debug "Manual course '#{course.name}' id is #{id}"
    course.id = id
  end

  def self.set_degree_sis_course_id(degree, course)
    query = "SELECT id
               FROM degree_progress_courses
              WHERE degree_check_id = '#{degree.id}'
                AND term_id = '#{course.term_id}'
                AND section_id = '#{course.ccn}'"
    id = Utils.query_pg_db_field(boac_db_credentials, query, 'id').first
    logger.debug "Completed course '#{course.name}' id is #{id}"
    course.id = id
  end

  def self.set_degree_sis_course_copy_id(degree, course)
    query = "SELECT max(id) AS id
               FROM degree_progress_courses
              WHERE degree_check_id = '#{degree.id}'
                AND term_id = '#{course.course_orig.term_id}'
                AND section_id = '#{course.course_orig.ccn}'"
    id = Utils.query_pg_db_field(boac_db_credentials, query, 'id').first
    logger.debug "Completed course '#{course.name}' copy id is #{id}"
    course.id = id
  end

  def self.update_degree_course_grade(course, student, grade)
    statement = "UPDATE degree_progress_courses
                 SET grade = '#{grade}'
                 WHERE section_id = #{course.ccn}
                   AND sid = '#{student.sis_id}'
                   AND term_id = '#{course.term_id}';"
    query_pg_db(boac_db_credentials, statement)
  end

  private

  def self.get_notes_from_pg_db_result(pg_result)
    notes_data = []
    result_ids = pg_result.map { |r| r['id'] }
    if result_ids.any?
      attach_query = "SELECT * FROM note_attachments WHERE note_id IN (#{result_ids.join(',')}) AND deleted_at IS NULL;"
      attach_results = Utils.query_pg_db(boac_db_credentials, attach_query)

      topic_query = "SELECT note_id, topic FROM note_topics WHERE note_id IN (#{result_ids.join(',')}) AND deleted_at IS NULL;"
      topic_results = Utils.query_pg_db(boac_db_credentials, topic_query)

      notes_data = pg_result.map do |r|
        depts = BOACDepartments::DEPARTMENTS.select { |d| r['author_dept_codes'].include? d.code }
        advisor_data = {
          uid: r['author_uid'],
          full_name: r['author_name'],
          role: r['author_role'],
          depts: depts.map(&:name)
        }

        note_data = {
          id: r['id'],
          subject: r['subject'],
          body: (r['body'] && Nokogiri::HTML(r['body']).text).to_s.strip,
          advisor: BOACUser.new(advisor_data),
          created_date: Time.parse(r['created_at'].to_s).utc.localtime,
          updated_date: Time.parse(r['updated_at'].to_s).utc.localtime,
          deleted_date: (Time.parse(r['deleted_at'].to_s) if r['deleted_at']),
          set_date: (Time.parse(r['set_date'].to_s).utc.localtime if r['set_date']),
          is_draft: (r['is_draft'] == 't'),
          is_private: (r['is_private'] == 't'),
          student: (BOACUser.new(sis_id: r['sid']) if r['sid'])
        }

        attachments = attach_results.select { |a| a['note_id'] == note_data[:id] }.map do |a|
          file_name = a['path_to_attachment'].split('/').last
          # Boa attachment file names should be prefixed with a timestamp, but some older test file names are not
          visible_file_name = file_name[0..15].gsub(/(20)\d{6}(_)\d{6}(_)/, '').empty? ? file_name[16..-1] : file_name
          Attachment.new id: a['id'],
                         file_name: visible_file_name,
                         deleted_at: a['deleted_at']
        end
        note_data.merge! attachments: attachments

        topics = topic_results.select { |t| t['note_id'] == note_data[:id] }.map { |t| t['topic'] }
        note_data.merge! topics: topics
      end
    end

    notes_data.map { |d| NoteBatch.new d }
  end
end
