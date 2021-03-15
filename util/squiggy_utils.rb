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

  def SquiggyUtils.load_test_data
    test_users = File.join(Utils.config_dir, 'test-data-suitec.json')
    JSON.parse(File.read(test_users))['users']
  end

end
