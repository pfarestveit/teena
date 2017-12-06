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
    query = 'SELECT member_uid, member_csid, member_name, asc_sport_code
             FROM team_members
             ORDER BY id ASC;'
    results = Utils.query_db(boac_shared_db_credentials, query)

    # Users with multiple sports have multiple rows; combine them
    athletes = results.group_by { |h1| h1['member_uid'] }.map do |k,v|
      {member_uid: k, member_csid: v[0]['member_csid'], member_name: v[0]['member_name'], asc_sport_code: v.map { |h2| h2['asc_sport_code'] }.join(' ')}
    end

    # Convert to Users
    athletes.map do |a|
      User.new({uid: a[:member_uid], sis_id: a[:member_csid], full_name: a[:member_name], sports: a[:asc_sport_code].split.uniq})
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
    teams
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
    squads
  end

  # Returns all the users associated with a team
  # @param team [Team]
  # @param users [Array<User>]
  # @return [Array<User>]
  def self.get_team_members(team, users)
    team_squads = Squad::SQUADS.select { |s| s.team == team }
    squad_codes = team_squads.map &:code
    team_members = users.select { |u| (u.sports & squad_codes).any? }
    logger.info "#{team.name} members are UIDs #{team_members.map &:uid}"
    team_members
  end

end
