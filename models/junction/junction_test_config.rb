class JunctionTestConfig < TestConfig

  include Logging

  attr_accessor :base_url, :canvas_base_url, :admin

  CONFIG = JunctionUtils.config

  # Sets config common to all Junction tests
  def set_global_configs
    @base_url = CONFIG['base_url']
    @admin = User.new({uid: CONFIG['admin_uid']})
  end

  # Returns the path to the bCourses test data file
  # @return [String]
  def bcourses_test_data
    File.join(Utils.config_dir, 'test-data-bcourses-load.json')
  end

  # Sets config for background job testing
  def background_jobs_load_test
    set_global_configs
    @test_course_data = parse_test_data(bcourses_test_data)['courses']
  end

end
