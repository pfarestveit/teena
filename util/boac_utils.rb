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

  # Returns the semester to use for testing Data Loch analytics
  # @return [String]
  def self.analytics_term
    @config['analytics_term']
  end

  # Whether or not to check tooltips during tests. Checking tooltips slows down test execution.
  def self.tooltips
    @config['tooltips']
  end

  # Whether or not to take screenshots of pages.
  def self.screenshots
    @config['screenshots']
  end

  # Whether or not to check Data Loch scores during tests.
  def self.loch_scores
    @config['loch_scores']
  end

  # Whether or not to check Data Loch assignments-on-time during tests.
  def self.loch_assignments
    @config['loch_assignments']
  end

  # Whether or not to check Data Loch page views during tests.
  def self.loch_page_views
    @config['loch_page_views']
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

  # Returns all authorized users
  # @return [Array<User>]
  def self.get_authorized_users
    query = 'SELECT authorized_users.uid AS uid,
                    authorized_users.is_admin AS admin
              FROM authorized_users;'
    results = query_db(boac_db_credentials, query)
    results.map { |r| User.new({uid: r['uid']}) }
  end

  # SEARCH TEST DATA

  # Returns the file path containing stored searchable student data to drive cohort search tests
  # @return [String]
  def self.searchable_data
    File.join(Utils.config_dir, 'boac-searchable-data.json')
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

  # DATABASE - ATHLETES

  # Returns all students
  # @return [PG::Result]
  def self.query_all_athletes
    query = 'SELECT students.uid AS uid,
                    students.sid AS sid,
                    students.first_name AS first_name,
                    students.last_name AS last_name,
                    students.is_active_asc AS status,
                    students.in_intensive_cohort AS intensive,
                    student_athletes.group_code AS group_code
             FROM students
             JOIN student_athletes ON student_athletes.sid = students.sid
             ORDER BY students.uid;'
    Utils.query_db(boac_db_credentials, query)
  end

  # Returns students where 'intensive' is true
  # @return [PG::Result]
  def self.query_intensive_athletes
    query_all_athletes.select { |a| a['intensive'] == 't' }
  end

  # Converts a students result object to an array of users
  # @param athletes [PG::Result]
  # @return [Array<User>]
  def self.athletes_to_users(athletes)
    # Users with multiple sports have multiple rows; combine them
    athletes = athletes.group_by { |h1| h1['uid'] }.map do |k,v|
      {uid: k, sid: v[0]['sid'], status: (v[0]['status'] == 't' ? 'active' : 'inactive'), first_name: v[0]['first_name'], last_name: v[0]['last_name'], group_code: v.map { |h2| h2['group_code'] }.join(' ')}
    end

    # Convert to Users
    athletes.map do |a|
      User.new({uid: a[:uid], sis_id: a[:sid], status: a[:status], first_name: a[:first_name], last_name: a[:last_name], full_name: "#{a[:first_name]} #{a[:last_name]}", sports: a[:group_code].split.uniq})
    end
  end

  # Returns an array of users for all students
  # @return [Array<User>]
  def self.get_all_athletes
    athletes_to_users query_all_athletes
  end

  # Returns an array of users for intensive students only
  # @return [Array<User>]
  def self.get_intensive_athletes
    athletes_to_users query_intensive_athletes
  end

  # Returns all the distinct teams associated with team members
  # @return [Array<Team>]
  def self.get_teams
    query = 'SELECT DISTINCT team_code
             FROM athletics
             ORDER BY team_code;'
    results = Utils.query_db_field(boac_db_credentials, query, 'team_code')
    teams = Team::TEAMS.select { |team| results.include? team.code }
    logger.info "Teams are #{teams.map &:name}"
    teams.sort_by { |t| t.name }
  end

  # Returns all the distinct team squads associated with team members
  # @return [Array<Squad>]
  def self.get_squads
    query = 'SELECT DISTINCT group_code
             FROM athletics
             ORDER BY group_code;'
    results = Utils.query_db_field(boac_db_credentials, query, 'group_code')
    squads = Squad::SQUADS.select { |squad| results.include? squad.code }
    logger.info "Squads are #{squads.map &:name}"
    squads.sort_by { |s| s.name }
  end

  # Returns all the users associated with a team
  # @param team [Team]
  # @return [Array<User>]
  def self.get_team_members(team)
    team_squads = Squad::SQUADS.select { |s| s.parent_team == team }
    team_members = get_squad_members team_squads
    logger.info "#{team.name} members are UIDs #{team_members.map &:uid}"
    team_members
  end

  # Returns all the users associated with a given collection of squads. If the full set of athlete users is already available,
  # will use that. Otherwise, obtains the full set too.
  # @param squads [Array<Squad>]
  # @param athletes [Array<User>]
  # @return [Array<User>]
  def self.get_squad_members(squads, all_athletes = nil)
    squad_codes = squads.map &:code
    athletes = all_athletes ? all_athletes : get_all_athletes
    athletes.select { |u| (u.sports & squad_codes).any? }
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
    results = Utils.query_db(boac_db_credentials, query)
    results.map { |r| CuratedCohort.new({id: r['id'], name: r['name'], owner_uid: user.uid}) }
  end

  # Obtains and sets the cohort ID given a curated cohort with a unique title
  # @param cohort [CuratedCohort]
  def self.set_curated_cohort_id(cohort)
    query = "SELECT id
              FROM student_groups
              WHERE name = '#{cohort.name}';"
    result = Utils.query_db_field(boac_db_credentials, query, 'id').first
    logger.info "Curated cohort '#{cohort.name}' ID is #{result}"
    cohort.id = result
  end

  # DATABASE - FILTERED COHORTS

  # Returns the filtered cohorts belonging to a given user
  # @param user [User]
  # @return [Array<FilteredCohort>]
  def self.get_user_filtered_cohorts(user)
    query = "SELECT cohort_filters.id AS cohort_id, cohort_filters.label AS cohort_name
              FROM cohort_filters
              JOIN cohort_filter_owners ON cohort_filter_owners.cohort_filter_id = cohort_filters.id
              JOIN authorized_users ON authorized_users.id = cohort_filter_owners.user_id
              WHERE authorized_users.uid = '#{user.uid}';"
    results = Utils.query_db(boac_db_credentials, query)
    results.map { |r| FilteredCohort.new({id: r['cohort_id'], name: r['cohort_name'], owner_uid: user.uid}) }
  end

  # Returns all filtered cohorts
  # @return [Array<FilteredCohort>]
  def self.get_everyone_filtered_cohorts
    query = 'SELECT cohort_filters.id AS cohort_id,
                    cohort_filters.label AS cohort_name,
                    authorized_users.uid AS uid
              FROM cohort_filters
              JOIN cohort_filter_owners ON cohort_filter_owners.cohort_filter_id = cohort_filters.id
              JOIN authorized_users ON authorized_users.id = cohort_filter_owners.user_id
              ORDER BY uid, cohort_id ASC;'
    results = Utils.query_db(boac_db_credentials, query)
    cohorts = results.map { |r| FilteredCohort.new({id: r['cohort_id'], name: r['cohort_name'], owner_uid: r['uid']}) }
    cohorts.sort_by { |c| [c.owner_uid.to_i, c.id] }
  end

  # Obtains and sets the cohort ID given a filtered cohort with a unique title
  # @param cohort [FilteredCohort]
  # @return [Integer]
  def self.set_filtered_cohort_id(cohort)
    query = "SELECT id
             FROM cohort_filters
             WHERE label = '#{cohort.name}'"
    result = Utils.query_db_field(boac_db_credentials, query, 'id').first
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
    results = Utils.query_db(boac_db_credentials, query.gsub("\"", '\''))
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
      results = Utils.query_db(boac_db_credentials, query.gsub("\"", '\''))
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
    Utils.query_db(boac_db_credentials, query)
  end

  # Returns an alert that has not been dismissed by the admin test user
  # @return [Alert]
  def self.get_test_alert
    # Get one active alert in the current term
    query = "SELECT alerts.id, alerts.alert_type, alerts.message, students.uid, students.first_name, students.last_name
              FROM alerts
              JOIN students ON alerts.sid = students.sid
              WHERE active = true
                AND key LIKE '#{term_code}%'
              LIMIT 1;"
    results = Utils.query_db(boac_db_credentials, query)
    alert = (results.map { |r| Alert.new({id: r['id'], message: r['message'], user: User.new({uid: r['uid'], full_name: "#{r['first_name']} #{r['last_name']}"})}) }).first
    # If the admin tester has dismissed the alert, delete the dismissal to permit dismissal testing
    remove_alert_dismissal(alert) if get_dismissed_alerts([alert]).any?
    logger.info "Test alert ID #{alert.id}, message '#{alert.message}', user UID #{alert.user.uid}, name #{alert.user.full_name}"
    alert
  end

end
