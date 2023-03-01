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

  def self.next_term_code(current_term_code)
    (current_term_code.to_i + ([2, 5].include?(current_term_code.to_i % 10) ? 3 : 4)).to_s
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

  def self.get_test_cs_course_id(term_id, catalog_id_prefix)
    sql = "SELECT cs_course_id
             FROM sis_data.edo_sections
            WHERE sis_term_id = '#{term_id}'
              AND sis_course_name LIKE '#{catalog_id_prefix}%'
              AND is_primary IS FALSE
         GROUP BY cs_course_id
           HAVING COUNT(*) > 1
            LIMIT 1;"
    Utils.query_pg_db_field(NessieUtils.nessie_pg_db_credentials, sql, 'cs_course_id').first
  end

  def self.get_test_course_section_data(term_id, cs_course_id)
    sql = "  SELECT sis_section_id AS ccn,
                    is_primary,
                    sis_course_name AS code,
                    sis_course_title AS title,
                    sis_instruction_format AS format,
                    sis_section_num AS number,
                    instructor_uid AS uid,
                    instructor_name AS full_name,
                    instructor_role_code AS role_code,
                    meeting_location AS location,
                    meeting_days AS days,
                    meeting_start_time AS start_time,
                    meeting_end_time AS end_time
               FROM sis_data.edo_sections
              WHERE sis_term_id = '#{term_id}'
                AND cs_course_id = '#{cs_course_id}'
           ORDER BY sis_course_name ASC,
                    sis_instruction_format DESC,
                    sis_section_num ASC;"
    results = Utils.query_pg_db(NessieUtils.nessie_pg_db_credentials, sql)
    results.map do |r|
      {
        ccn: r['ccn'],
        primary: (r['is_primary'] == 't'),
        code: r['code'],
        title: r['title'],
        label: "#{r['format']} #{r['number']}",
        location: r['location'],
        role_code: r['role_code'],
        schedule: "#{r['days']} #{r['start_time']} #{r['end_time']}",
        uid: r['uid']
      }
    end
  end

  def self.get_test_course_instructors(term_id, cs_course_id)
    sql = "SELECT DISTINCT instructor_uid,
                  instructor_name
             FROM sis_data.edo_sections
            WHERE sis_term_id = '#{term_id}'
              AND cs_course_id = '#{cs_course_id}';"
    results = Utils.query_pg_db(NessieUtils.nessie_pg_db_credentials, sql)
    results.map do |r|
      User.new full_name: r['instructor_name'],
               uid: r['instructor_uid']
    end
  end

  def self.get_test_course(term_id, catalog_id_prefix)
    id = get_test_cs_course_id(term_id, catalog_id_prefix)
    if id
      instr = get_test_course_instructors(term_id, id)
      section_data = get_test_course_section_data(term_id, id)
      grouped = section_data.group_by { |s| s[:ccn] }
      sections = grouped.map do |k, v|
        instructors = []
        v.each do |u|
          instructor = instr.find { |i| i.uid.to_s == u[:uid].to_s }
          if instructor
            instructor.role_code = u[:role_code]
            instructors << instructor
          end
        end
        instructors.compact!
        Section.new id: k,
                    course: v[0][:code],
                    instructors: instructors.uniq,
                    label: v[0][:label],
                    locations: (v.map { |l| l[:location] }).uniq,
                    primary: v[0][:primary],
                    schedules: (v.map {|s| s[:schedule] }).uniq
      end
      teachers = sections.select(&:primary).map { |prim| prim.instructors }
      teachers.flatten!
      teachers.compact!
      teachers.uniq!
      codes = sections.map(&:course).uniq
      codes.sort!
      if teachers.any?
        Course.new code: codes.first,
                   title: (section_data[0][:title]),
                   term: sis_code_to_term_name(term_id),
                   sections: sections,
                   teachers: teachers
      else
        logger.warn "Course code '#{catalog_id_prefix}' in term #{term_id} has no teachers"
        nil
      end
    else
      logger.warn "No test course found matching course code '#{catalog_id_prefix}' in term #{term_id}"
      nil
    end
  end
end
