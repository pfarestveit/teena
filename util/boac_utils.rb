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

  # Returns the semester session start date for testing activity alerts
  def self.term_start_date
    @config['term_start_date']
  end

  def self.shuffle_max_users
    @config['shuffle_max_users']
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

  # Returns all the advisors associated with a department
  # @return [Array<BOACUser>]
  def self.get_dept_advisors(dept)
    query = "SELECT authorized_users.uid
              FROM authorized_users
              INNER JOIN university_dept_members ON authorized_users.id = university_dept_members.authorized_user_id
              INNER JOIN university_depts on university_dept_members.university_dept_id = university_depts.id
              WHERE university_depts.dept_code = '#{dept.code}';"
    results = query_pg_db(boac_db_credentials, query)
    results.map { |r| BOACUser.new({uid: r['uid']}) }
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
  def self.get_user_filtered_cohorts(user)
    query = "SELECT cohort_filters.id AS cohort_id,
                    cohort_filters.name AS cohort_name,
                    cohort_filters.filter_criteria AS criteria
              FROM cohort_filters
              JOIN cohort_filter_owners ON cohort_filter_owners.cohort_filter_id = cohort_filters.id
              JOIN authorized_users ON authorized_users.id = cohort_filter_owners.user_id
              WHERE authorized_users.uid = '#{user.uid}';"
    results = Utils.query_pg_db(boac_db_credentials, query)
    results.map do |r|
      FilteredCohort.new({id: r['cohort_id'], name: r['cohort_name'], owner_uid: user.uid})
    end
  end

  # Returns all filtered cohorts. If a department is given, then returns only the cohorts associated with that department.
  # @param dept [BOACDepartments]
  # @return [Array<FilteredCohort>]
  def self.get_everyone_filtered_cohorts(dept = nil)
    query = "SELECT cohort_filters.id AS cohort_id,
                    cohort_filters.name AS cohort_name,
                    cohort_filters.filter_criteria AS criteria,
                    authorized_users.uid AS uid
              FROM cohort_filters
              JOIN cohort_filter_owners ON cohort_filter_owners.cohort_filter_id = cohort_filters.id
              JOIN authorized_users ON authorized_users.id = cohort_filter_owners.user_id
              #{if dept
                 'JOIN university_dept_members ON university_dept_members.authorized_user_id = authorized_users.id
                  JOIN university_depts ON university_depts.id = university_dept_members.university_dept_id
                  WHERE university_depts.dept_code = \'' + dept.code + '\' '
                end}
              ORDER BY uid, cohort_id ASC;"
    results = Utils.query_pg_db(boac_db_credentials, query)
    cohorts = results.map { |r| FilteredCohort.new({id: r['cohort_id'], name: r['cohort_name'].strip, owner_uid: r['uid']}) }
    cohorts.sort_by { |c| [c.owner_uid.to_i, c.id] }
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

  # Given a set of students, returns all their active alerts in the current term
  # @param users [Array<BOACUser>]
  # @return [Array<Alert>]
  def self.get_students_alerts(users)
    sids = users.map(&:sis_id).to_s.delete('[]')
    query = "SELECT id, sid, alert_type, message
              FROM alerts
              WHERE sid IN (#{sids})
                AND active = true
                AND key LIKE '#{term_code}%'
                AND alert_type != 'hold';"
    results = Utils.query_pg_db(boac_db_credentials, query.gsub("\"", '\''))
    alerts = results.map { |r| Alert.new({id: r['id'], type: r['alert_type'], message: r['message'].gsub("\n", ' ').gsub(/\s+/, ' '), user: BOACUser.new({sis_id: r['sid']})}) }
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

  # Returns a student's advising notes
  # @param student [BOACUser]
  # @return [Array<Note>]
  def self.get_student_notes(student)
    query = "SELECT * FROM notes WHERE sid = '#{student.sis_id}';"
    results = Utils.query_pg_db(boac_db_credentials, query)
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
        :body => r['body'].gsub(/<("[^"]*"|'[^']*'|[^'">])*>/, '').gsub('&nbsp;', ''),
        :advisor => BOACUser.new(advisor_data),
        :created_date => Time.parse(r['created_at'].to_s).utc.localtime,
        :updated_date => Time.parse(r['updated_at'].to_s).utc.localtime,
        :deleted_date => (Time.parse(r['deleted_at'].to_s) if r['deleted_at'])
      }

      attach_query = "SELECT * FROM note_attachments WHERE note_id = #{note_data[:id]};"
      attach_results = Utils.query_pg_db(boac_db_credentials, attach_query)
      attachments = attach_results.map do |a|
        file_name = a['path_to_attachment'].split('/').last
        # Boa attachment file names should be prefixed with a timestamp, but some older test file names are not
        visible_file_name = file_name[0..15].gsub(/(20)\d{6}(_)\d{6}(_)/, '').empty? ? file_name[16..-1] : file_name
        Attachment.new({:id => a['id'], :file_name => visible_file_name, :deleted_at => a['deleted_at']})
      end
      note_data.merge!(:attachments => attachments)

      topic_query = "SELECT topic FROM note_topics WHERE note_id = #{note_data[:id]};"
      topic_results = Utils.query_pg_db(boac_db_credentials, topic_query)
      topics = topic_results.map { |t| t['topic'] }
      note_data.merge!(:topics => topics)
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

  # Creates an admin authorized user
  # @param user [BOACUser]
  def self.create_auth_user(user)
    statement = "INSERT INTO authorized_users (uid, is_admin, created_at, updated_at)
                 SELECT '#{user.uid}', true, now(), now()
                 WHERE NOT EXISTS (SELECT id FROM authorized_users WHERE uid = '#{user.uid}');"
    result = query_pg_db(boac_db_credentials, statement)
    logger.warn "Command status: #{result.cmd_status}. Result status: #{result.result_status}"
  end

  # Deletes an authorized user
  # @param user [BOACUser]
  def self.delete_auth_user(user)
    statement_1 = "DELETE FROM authorized_users WHERE uid = '#{user.uid}';"
    result_1 = query_pg_db(boac_db_credentials, statement_1)
    logger.warn "Command status: #{result_1.cmd_status}. Result status: #{result_1.result_status}"

    statement_2 = "DELETE FROM json_cache WHERE key = 'calnet_user_for_uid_' || '#{user.uid}';"
    result_2 = query_pg_db(boac_db_credentials, statement_2)
    logger.warn "Command status: #{result_2.cmd_status}. Result status: #{result_2.result_status}"
  end

end
