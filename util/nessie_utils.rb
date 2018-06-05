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
    logger.info "Sending query: '#{query}'"
    results = NessieUtils.query_redshift_db(nessie_db_credentials, query)
    results.map do |r|
      submitted = %w(on_time late submitted graded).include? r['assignment_status']
      Assignment.new({:id => r['assignment_id'], :due_date => r['due_at'], :submission_date => r['submitted_at'], :submitted => submitted})
    end
  end

end
