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

  def self.lti_credentials
    {
      key: squiggy_config['lti_key'],
      secret: squiggy_config['lti_secret']
    }
  end

end
