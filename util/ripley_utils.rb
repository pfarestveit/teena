require_relative 'spec_helper'

class RipleyUtils < Utils

  include Logging

  @config = Utils.config['ripley']

  def self.base_url
    @config['base_url']
  end

  def self.term_name
    @config['term_name']
  end

  def self.term_code
    @config['term']
  end

  def self.mailing_list_suffix
    base_url.include?('-qa') ? '-cc-ets-qa' : '-cc-ets-dev'
  end

  def self.dev_auth_password
    @config['dev_auth_password']
  end

  def self.test_data_file
    File.join(Utils.config_dir, 'test-data-ripley.json')
  end

  def self.background_job_attempts
    @config['background_job_attempts']
  end

  def self.sis_update_date
    Time.parse @config['sis_update_date']
  end

  def self.load_test_data
    JSON.parse File.read(test_data_file)
  end

  def self.set_ripley_test_course_id(course)
    logger.info "Updating Ripley test data with course site ID #{course.site_id} for #{course.term} #{course.code}"
    parsed = load_test_data
    course_test_data = parsed['courses'].find { |data| data['code'] == course.code && data['term'] == course.term }
    course_test_data['site_id'] = course.site_id
    course_test_data['site_created_date'] = Date.today.to_s

    Dir.glob("#{Utils.config_dir}/test-data-ripley.json").each { |f| File.delete f }
    File.open(test_data_file, 'w') { |f| f.write JSON.pretty_generate(parsed) }
  end

  def self.clear_cache
    # TODO
  end

  def self.initialize_test_output(spec, column_headers)
    output_file = "#{Utils.get_test_script_name spec}.csv"
    logger.info "Initializing test output CSV named #{output_file}"
    test_output = File.join(Utils.initialize_test_output_dir, output_file)
    CSV.open(test_output, 'wb') { |heading| heading << column_headers }
    test_output
  end

  def self.add_user_tool_id
    Utils.config['canvas']['course_add_user_tool']
  end

  def self.create_site_tool_id
    Utils.config['canvas']['create_site_tool']
  end

  def self.course_captures_tool_id
    Utils.config['canvas']['course_captures_tool']
  end

  def self.e_grades_export_tool_id
    Utils.config['canvas']['e_grades_export_tool']
  end

  def self.mailing_list_tool_id
    Utils.config['canvas']['mailing_list_tool']
  end

  def self.mailing_lists_tool_id
    Utils.config['canvas']['mailing_lists_tool']
  end

  def self.official_sections_tool_id
    Utils.config['canvas']['official_sections_tool']
  end

  def self.roster_photos_tool_id
    Utils.config['canvas']['rosters_tool']
  end

  def self.user_prov_tool_id
    Utils.config['canvas']['user_prov_tool']
  end

  def self.db_credentials
    {
      host: @config['db_host'],
      port: @config['db_port'],
      name: @config['db_name'],
      user: @config['db_user'],
      password: @config['db_password']
    }
  end

  def self.drop_existing_mailing_lists
    sql_1 = 'DELETE FROM canvas_site_mailing_lists'
    sql_2 = 'DELETE FROM canvas_site_mailing_list_members'
    Utils.query_pg_db(db_credentials, sql_1)
    Utils.query_pg_db(db_credentials, sql_2)
  end
end
