require_relative 'spec_helper'

class NessieUtils < Utils

  @config = Utils.config['nessie']

  def self.nessie_db_credentials
    {
      :host => @config['db_host'],
      :port => @config['db_port'],
      :name => @config['db_name'],
      :user => @config['db_user'],
      :password => @config['db_password']
    }
  end

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
    results = query_redshift_db(nessie_db_credentials, query)
    results.map do |r|
      submitted = %w(on_time late submitted graded).include? r['assignment_status']
      Assignment.new({:id => r['assignment_id'], :due_date => r['due_at'], :submission_date => r['submitted_at'], :submitted => submitted})
    end
  end

  def self.nessie_rds_credentials
    {
      :host => @config['rds_host'],
      :port => @config['rds_port'],
      :name => @config['rds_name'],
      :user => @config['rds_user'],
      :password => @config['rds_password']
    }
  end

  # DATABASE - ASC STUDENTS

  # Returns all ASC students
  # @return [PG::Result]
  def self.query_all_asc_students
    query = 'SELECT students.sid AS sid,
                    students.intensive AS intensive,
                    students.active AS status,
                    students.group_code AS group_code,
                    persons.ldap_uid AS uid,
                    persons.first_name AS first_name,
                    persons.last_name AS last_name
             FROM boac_advising_asc.students
             JOIN calnet_ext_dev.persons ON calnet_ext_dev.persons.sid = boac_advising_asc.students.sid
             ORDER BY students.sid;'
    Utils.query_redshift_db(nessie_db_credentials, query)
  end

  # Converts a students result object to an array of users
  # @param athletes [PG::Result]
  # @return [Array<User>]
  def self.asc_students_to_users(athletes)
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
  def self.get_all_asc_students
    asc_students_to_users query_all_asc_students
  end

  # Returns an array of users for intensive students only
  # @return [Array<User>]
  def self.get_intensive_asc_students
    results = query_all_asc_students.select { |a| a['intensive'] == 'TRUE' }
    asc_students_to_users results
  end

  # Returns all the distinct teams associated with team members
  # @return [Array<Team>]
  def self.get_asc_teams
    # Get the squads associated with ASC students
    query = 'SELECT DISTINCT group_code
              FROM boac_advising_asc.students;'
    results = Utils.query_redshift_db(nessie_db_credentials, query)
    results = results.map { |r| r['group_code'] }
    squads = Squad::SQUADS.select { |squad| results.include? squad.code }
    squads.sort_by { |s| s.name }

    # Get the teams associated with the squads
    teams = squads.map &:parent_team
    teams.uniq!
    logger.info "Teams are #{teams.map &:name}"
    teams.sort_by { |t| t.name }
  end

  # Returns all the users associated with a team. If the full set of athlete users is already available,
  # will use that. Otherwise, obtains the full set too.
  # @param team [Team]
  # @param all_athletes [Array<User>]
  # @return [Array<User>]
  def self.get_asc_team_members(team, all_athletes = nil)
    team_squads = Squad::SQUADS.select { |s| s.parent_team == team }
    squad_codes = team_squads.map &:code
    athletes = all_athletes ? all_athletes : get_all_asc_students
    team_members = athletes.select { |u| (u.sports & squad_codes).any? }
    logger.info "#{team.name} members are UIDs #{team_members.map &:uid}"
    team_members
  end

end
