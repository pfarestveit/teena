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

  # Returns the minimum number of a type of course activities required for individual stats to have meaning
  # @return [Integer]
  def self.meaningful_minimum
    @config['meaningful_minimum']
  end

  # Returns the db credentials for BOAC Shared
  # @return [Hash]
  def self.boac_shared_db_credentials
    {
      host: @config['db_host'],
      port: @config['db_port'],
      name: @config['db_name'],
      user: @config['db_user'],
      password: @config['db_password']
    }
  end

  # Returns an array of Users stored in the cohorts table
  # @return [Array<User>]
  def self.get_athletes
    query = 'SELECT member_uid, member_csid, first_name, last_name, asc_sport_code
             FROM team_members
             ORDER BY id ASC;'
    results = Utils.query_db(boac_shared_db_credentials, query)

    # Users with multiple sports have multiple rows; combine them
    athletes = results.group_by { |h1| h1['member_uid'] }.map do |k,v|
      {member_uid: k, member_csid: v[0]['member_csid'], first_name: v[0]['first_name'], last_nem: v[0]['last_name'], asc_sport_code: v.map { |h2| h2['asc_sport_code'] }.join(' ')}
    end

    # Convert to Users
    athletes.map do |a|
      User.new({uid: a[:member_uid], sis_id: a[:member_csid], full_name: "#{a[:first_name]} #{a[:last_name]}", sports: a[:asc_sport_code].split.uniq})
    end
  end

  # TODO - add a sample test data file when search filters are available
  # Returns a collection of search criteria to use for testing cohort search
  # @return [Array<Hash>]
  def self.get_test_search_criteria
    test_data_file = File.join(ENV['HOME'], '/.webdriver-config/test-data-boac.json')
    test_data = JSON.parse File.read(test_data_file)
    test_data['search_criteria'].map do |d|
      criteria = {
          squads: d['teams'] && d['teams'].map { |t| Squad::SQUADS.find { |s| s.name == t['squad'] } },
          levels: d['levels'] && d['levels'].map { |l| l['level'] },
          terms: d['terms'] && d['terms'].map { |t| t['term'] },
          gpa: d['gpa'],
          units: d['units']
      }
      CohortSearchCriteria.new criteria
    end
  end

  # Returns all the distinct teams associated with team members
  # @return [Array<Team>]
  def self.get_teams
    query = 'SELECT DISTINCT code
             FROM team_members
             ORDER BY code ASC;'
    results = Utils.query_db_field(boac_shared_db_credentials, query, 'code')
    teams = Team::TEAMS.select { |team| results.include? team.code }
    logger.info "Teams are #{teams.map &:name}"
    teams.sort_by { |t| t.name }
  end

  # Returns all the distinct team squads associated with team members
  # @return [Array<Squad>]
  def self.get_squads
    query = 'SELECT DISTINCT asc_sport_code
             FROM team_members
             ORDER BY asc_sport_code;'
    results = Utils.query_db_field(boac_shared_db_credentials, query, 'asc_sport_code')
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

  # Returns all the users associated with a given collection of squads
  # @param squads [Array<Squad>]
  # @return [Array<User>]
  def self.get_squad_members(squads)
    squad_codes = squads.map &:code
    get_athletes.select { |u| (u.sports & squad_codes).any? }
  end

  # Returns the custom cohorts belonging to a given user
  # @param user [User]
  # @return [Array<Cohort>]
  def self.get_user_custom_cohorts(user)
    query = "SELECT cohort_filters.id AS cohort_id, cohort_filters.label AS cohort_name
              FROM cohort_filters
              JOIN cohort_filter_owners ON cohort_filter_owners.cohort_filter_id = cohort_filters.id
              JOIN authorized_users ON authorized_users.id = cohort_filter_owners.user_id
              WHERE authorized_users.uid = '#{user.uid}';"
    results = Utils.query_db(boac_shared_db_credentials, query)
    results.map { |r| Cohort.new({id: r['cohort_id'], name: r['cohort_name'], owner_uid: user.uid}) }
  end

  # Returns all custom cohorts
  # @return [Array<Cohort>]
  def self.get_everyone_custom_cohorts
    query = 'SELECT cohort_filters.id AS cohort_id,
                    cohort_filters.label AS cohort_name,
                    authorized_users.uid AS uid
              FROM cohort_filters
              JOIN cohort_filter_owners ON cohort_filter_owners.cohort_filter_id = cohort_filters.id
              JOIN authorized_users ON authorized_users.id = cohort_filter_owners.user_id
              ORDER BY uid, cohort_id ASC;'
    results = Utils.query_db(boac_shared_db_credentials, query)
    results.map { |r| Cohort.new({id: r['cohort_id'], name: r['cohort_name'], owner_uid: r['uid']}) }
  end

  # Obtains and sets the cohort ID given a cohort with a unique title
  # @param cohort [Cohort]
  # @return [Integer]
  def self.get_custom_cohort_id(cohort)
    query = "SELECT id
             FROM cohort_filters
             WHERE label = '#{cohort.name}'"
    result = Utils.query_db_field(boac_shared_db_credentials, query, 'id').first
    logger.info "Cohort '#{cohort.name}' ID is #{result}"
    cohort.id = result
  end

end
