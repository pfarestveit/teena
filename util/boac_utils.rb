require_relative 'spec_helper'

class BOACUtils < Utils

  @config = Utils.config['boac']

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

  # Returns the UID of a CoE advisor for testing
  def self.test_coe_advisor_uid
    @config['test_coe_advisor_uid']
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

  # Returns test data and configuration specific to a cohort-driven test script run, driven primarily by the department configured
  # for testing.
  # @param team_config [String]
  # @param max_users_config [String]
  # @return [BOACTestConfig]
  def self.cohort_driven_test_config(team_config, max_users_config = nil)

    # The department determines many of the other config options
    dept = test_dept

    # Select an advisor from the department being tested
    advisor = case dept
                when BOACDepartments::ASC
                  get_dept_advisors(dept).first
                when BOACDepartments::COE
                  test_coe_advisor_uid ? (get_dept_advisors(dept).find { |a| a.uid.to_i == test_coe_advisor_uid }) : get_dept_advisors(dept).first
                else
                  logger.error 'Admin user is not supported for this test, quitting'
                  fail
              end

    # Use a team as a pre-existing cohort for ASC tests
    if dept == BOACDepartments::ASC
      all_dept_students = NessieUtils.get_all_asc_students
      cohort = NessieUtils.get_asc_teams.find { |t| t.code == team_config }
      cohort_members = NessieUtils.get_asc_team_members cohort

    # Use a 'my students' cohort for CoE tests
    else
      all_dept_students = NessieUtils.get_all_coe_students
      cohort = get_user_filtered_cohorts(advisor).find { |c| c.read_only }
      cohort_members = NessieUtils.get_coe_advisor_students advisor
    end

    cohort.member_count = cohort_members.length
    # Limit the number of students tested to avoid endless test runs
    max_cohort_members = cohort_members[0..(max_users_config - 1)] if max_users_config

    # Use a specific term for Canvas data tests
    assignments_term = @config['assignments_term']

    config = {
      :id=> get_test_id,
      :dept => dept,
      :advisor => advisor,
      :all_dept_students => all_dept_students,
      :cohort => cohort,
      :cohort_members => cohort_members,
      :max_cohort_members => max_cohort_members,
      :term => assignments_term
    }
    test_config = BOACTestConfig.new(config)
    logger.info "Test ID is #{test_config.id}, department is #{test_config.dept.code}, advisor UID is #{test_config.advisor.uid}, cohort member count is #{test_config.cohort_members.length}"
    test_config
  end

  def self.get_assignments_test_config
    cohort_driven_test_config(@config['assignments_team'], @config['assignments_max_users'])
  end

  def self.get_class_page_test_config
    cohort_driven_test_config(@config['class_page_team'], @config['class_page_max_users'])
  end

  def self.get_curated_cohort_test_config
    cohort_driven_test_config(@config['curated_cohort_team'], @config['curated_cohort_max_users'])
  end

  def self.get_last_activity_test_config
    cohort_driven_test_config(@config['last_activity_team'], @config['last_activity_max_users'])
  end

  def self.get_navigation_test_config
    cohort_driven_test_config(@config['navigation_team'])
  end

  def self.get_user_search_test_config
    cohort_driven_test_config(@config['user_search_team'], @config['user_search_max_users'])
  end

  # The advisor department to use for tests that can run with different departments
  def self.test_dept
    BOACDepartments::DEPARTMENTS.find { |d| d.code == @config['test_dept'] }
  end

  def self.sis_data_team
    @config['sis_data_team']
  end

  # The number of days that synced Canvas data is behind actual site usage data
  def self.canvas_data_lag_days
    @config['canvas_data_lag_days']
  end

  # Logs error, prints stack trace, and saves a screenshot when running headlessly
  def self.log_error_and_screenshot(driver, error, unique_id)
    log_error error
    save_screenshot(driver, unique_id) if Utils.headless?
  end

  # SEARCH TEST DATA

  # Returns the prefix for the searchable data file name. The prefix identifies the pool of students who could be returned in
  # search results, i.e., ASC students, CoE students, or all students.
  # @param dept [BOACDepartments]
  # @return [String]
  def self.searchable_data_prefix(dept = nil)
    dept ? "#{dept.code}-" : 'ALL-'
  end

  # Returns the file path containing stored searchable student data to drive cohort search tests, which is
  # department-specific if a department is given.
  # @param dept [BOACDepartments]
  # @return [String]
  def self.searchable_data(dept = nil)
    File.join(Utils.config_dir, "#{searchable_data_prefix dept}boac-searchable-data-#{Time.now.strftime('%Y-%m-%d')}.json")
  end

  # Returns a collection of search criteria to use for testing cohort search
  # @return [Array<Hash>]
  def self.get_test_search_criteria
    test_data_file = File.join(Utils.config_dir, 'test-data-boac.json')
    test_data = JSON.parse File.read(test_data_file)
    test_data['search_criteria'].map do |d|
      criteria = {
        squads: (d['teams'] && d['teams'].map { |t| Squad::SQUADS.find { |s| s.name == t['squad'] } }),
        levels: (d['levels'] && d['levels'].map { |l| l['level'] }),
        majors: (d['majors'] && d['majors'].map { |t| t['major'] }),
        gpa_ranges: (d['gpa_ranges'] && d['gpa_ranges'].map { |g| g['gpa_range'] }),
        units: (d['units'] && d['units'].map { |u| u['unit'] })
      }
      CohortSearchCriteria.new criteria
    end
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

  # DATABASE - USERS

  # Returns all authorized users
  # @return [Array<User>]
  def self.get_authorized_users
    query = 'SELECT authorized_users.uid AS uid,
                    authorized_users.is_admin AS admin
              FROM authorized_users;'
    results = query_pg_db(boac_db_credentials, query)
    results.map { |r| User.new({uid: r['uid']}) }
  end

  # Returns all the advisors associated with a department
  # @return [Array<User>]
  def self.get_dept_advisors(dept)
    query = "SELECT authorized_users.uid
              FROM authorized_users
              INNER JOIN university_dept_members ON authorized_users.id = university_dept_members.authorized_user_id
              INNER JOIN university_depts on university_dept_members.university_dept_id = university_depts.id
              WHERE university_depts.dept_code = '#{dept.code}';"
    results = query_pg_db(boac_db_credentials, query)
    results.map { |r| User.new({uid: r['uid']}) }
  end

  # DATABASE - CURATED COHORTS

  # Returns the curated cohorts belonging to a given user
  # @param user [User]
  # @return [Array<CuratedCohort>]
  def self.get_user_curated_cohorts(user)
    query = "SELECT student_groups.id AS id, student_groups.name AS name
              FROM student_groups
              JOIN authorized_users ON authorized_users.id = student_groups.owner_id
              WHERE authorized_users.uid = '#{user.uid}';"
    results = Utils.query_pg_db(boac_db_credentials, query)
    results.map { |r| CuratedCohort.new({id: r['id'], name: r['name'], owner_uid: user.uid}) }
  end

  # Obtains and sets the cohort ID given a curated cohort with a unique title
  # @param cohort [CuratedCohort]
  def self.set_curated_cohort_id(cohort)
    query = "SELECT id
              FROM student_groups
              WHERE name = '#{cohort.name}';"
    result = Utils.query_pg_db_field(boac_db_credentials, query, 'id').first
    logger.info "Curated cohort '#{cohort.name}' ID is #{result}"
    cohort.id = result
  end

  # DATABASE - FILTERED COHORTS

  # Returns the filtered cohorts belonging to a given user
  # @param user [User]
  # @return [Array<FilteredCohort>]
  def self.get_user_filtered_cohorts(user)
    query = "SELECT cohort_filters.id AS cohort_id,
                    cohort_filters.label AS cohort_name,
                    cohort_filters.filter_criteria AS criteria
              FROM cohort_filters
              JOIN cohort_filter_owners ON cohort_filter_owners.cohort_filter_id = cohort_filters.id
              JOIN authorized_users ON authorized_users.id = cohort_filter_owners.user_id
              WHERE authorized_users.uid = '#{user.uid}';"
    results = Utils.query_pg_db(boac_db_credentials, query)
    # If the filter criteria includes a non-null CoE advisor UID, then the filter is read-only (no deleting).
    results.map do |r|
      FilteredCohort.new({id: r['cohort_id'], name: r['cohort_name'], owner_uid: user.uid, read_only: (r['criteria'].to_s.include?('\\"advisorLdapUid\\"') && !r['criteria'].to_s.include?('\\"advisorLdapUid\\": null'))})
    end
  end

  # Returns all filtered cohorts. If a department is given, then returns only the cohorts associated with that department.
  # @param dept [BOACDepartments]
  # @return [Array<FilteredCohort>]
  def self.get_everyone_filtered_cohorts(dept = nil)
    query = "SELECT cohort_filters.id AS cohort_id,
                    cohort_filters.label AS cohort_name,
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
    cohorts = results.map { |r| FilteredCohort.new({id: r['cohort_id'], name: r['cohort_name'], owner_uid: r['uid'], read_only: (r['criteria'].to_s.include?('\\"advisorLdapUid\\"') && !r['criteria'].to_s.include?('\\"advisorLdapUid\\": null'))}) }
    cohorts.sort_by { |c| [c.owner_uid.to_i, c.id] }
  end

  # Obtains and sets the cohort ID given a filtered cohort with a unique title
  # @param cohort [FilteredCohort]
  # @return [Integer]
  def self.set_filtered_cohort_id(cohort)
    query = "SELECT id
             FROM cohort_filters
             WHERE label = '#{cohort.name}'"
    result = Utils.query_pg_db_field(boac_db_credentials, query, 'id').first
    logger.info "Filtered cohort '#{cohort.name}' ID is #{result}"
    cohort.id = result
  end

  # DATABASE - ALERTS

  # Given a set of students, returns all their active alerts in the current term
  # @param users [Array<User>]
  # @return [Array<Alert>]
  def self.get_students_alerts(users)
    sids = users.map(&:sis_id).to_s.delete('[]')
    query = "SELECT id, sid, alert_type, message
              FROM alerts
              WHERE sid IN (#{sids})
                AND active = true
                AND key LIKE '#{term_code}%';"
    results = Utils.query_pg_db(boac_db_credentials, query.gsub("\"", '\''))
    alerts = results.map { |r| Alert.new({id: r['id'], type: r['alert_type'], message: r['message'], user: User.new({sis_id: r['sid']})}) }
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
  # @param advisor [User]
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
  # @param advisor [User]
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
    alert = (results.map { |r| Alert.new({id: r['id'], message: r['message'], user: User.new({sis_id: r['sid']})}) }).first
    # If an alert exists and the admin tester has dismissed the alert, delete the dismissal to permit dismissal testing
    if alert
      remove_alert_dismissal(alert) if get_dismissed_alerts([alert]).any?
      logger.info "Test alert ID #{alert.id}, message '#{alert.message}', user SID #{alert.user.sis_id}"
    end
    alert
  end

end
