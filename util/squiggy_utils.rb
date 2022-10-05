class SquiggyUtils < Utils

  include Logging

  @config = Utils.config

  def SquiggyUtils.squiggy_config
    config['squiggy']
  end

  def SquiggyUtils.base_url
    squiggy_config['base_url']
  end

  def SquiggyUtils.password
    squiggy_config['password']
  end

  def SquiggyUtils.db_credentials
    {
      host: squiggy_config['db_host'],
      port: squiggy_config['db_port'],
      name: squiggy_config['db_name'],
      user: squiggy_config['db_user'],
      password: squiggy_config['db_password']
    }
  end

  def SquiggyUtils.lti_credentials
    {
      key: squiggy_config['lti_key'],
      secret: squiggy_config['lti_secret']
    }
  end

  def self.poller_retries
    @config['squiggy']['poller_retries']
  end

  def SquiggyUtils.set_user_id(user, course)
    sql = "SELECT users.id
             FROM users
             JOIN courses
               ON users.course_id = courses.id
            WHERE users.canvas_user_id = '#{user.canvas_id}'
              AND courses.name = '#{course.title}'"
    id = Utils.query_pg_db_field(db_credentials, sql, 'id').first
    logger.info "Squiggy user ID is #{id}"
    user.squiggy_id = id.to_s
  end

  def SquiggyUtils.set_asset_id(asset, assignment_id = nil)
    query = "SELECT id FROM assets WHERE title = '#{asset.title}'#{ + ' AND canvas_assignment_id = \'' + assignment_id + '\'' if assignment_id}"
    id = Utils.query_pg_db_field(db_credentials, query, 'id').first
    logger.info "Asset ID is #{id}"
    asset.id = id.to_s
  end

  def SquiggyUtils.set_assignment_id(assignment)
    query = "SELECT id FROM categories WHERE canvas_assignment_name = '#{assignment.title}'"
    id = Utils.query_pg_db_field(db_credentials, query, 'id').first
    logger.info "Squiggy's assignment ID is #{id}"
    assignment.squiggy_id = id.to_s
  end

end
