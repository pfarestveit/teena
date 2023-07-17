require_relative 'spec_helper'

class RipleyUtils < Utils

  include Logging

  @config = Utils.config['ripley']

  def self.base_url
    @config['base_url']
  end

  def self.current_term
    Term.new code: @config['term_code'],
             name: @config['term_name'],
             sis_id: @config['term_sis_id']
  end

  def self.next_term(current_term)
    term = Term.new sis_id: next_term_sis_id(current_term),
                    name: next_term_name(current_term)
    term.code = Utils.term_name_to_hyphenated_code(term.name)
    term
  end

  def self.next_term_sis_id(current_term)
    (current_term.sis_id.to_i + ([2, 5].include?(current_term.sis_id.to_i % 10) ? 3 : 4)).to_s
  end

  def self.next_term_name(current_term)
    parts = current_term.name.split
    case parts[0]
    when 'Spring'
      "Summer #{parts[1]}"
    when 'Summer'
      "Fall #{parts[1]}"
    else
      "Spring #{parts[1].to_i + 1}"
    end
  end

  def self.mailing_list_suffix
    base_url.include?('-qa') ? '-cc-ets-qa' : '-cc-ets-dev'
  end

  def self.dev_auth_password
    @config['dev_auth_password']
  end

  def self.e_grades_site_ids
    @config['e_grades_site_ids']
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

  def self.get_test_cs_course_id_from_catalog_id(term, catalog_id_prefix)
    sql = "SELECT cs_course_id
             FROM sis_data.edo_sections
            WHERE sis_term_id = '#{term.sis_id}'
              AND sis_course_name LIKE '#{catalog_id_prefix}%'
              AND is_primary IS FALSE
         GROUP BY cs_course_id
           HAVING COUNT(*) > 1
            LIMIT 1;"
    Utils.query_pg_db_field(NessieUtils.nessie_pg_db_credentials, sql, 'cs_course_id').first
  end

  def self.get_test_cs_course_id_from_ccn(term, ccn)
    sql = "SELECT cs_course_id
             FROM sis_data.edo_sections
            WHERE sis_term_id = '#{term.sis_id}'
              AND sis_section_id = '#{ccn}';"
    Utils.query_pg_db_field(NessieUtils.nessie_pg_db_credentials, sql, 'cs_course_id').first
  end

  def self.get_test_course_section_data(term, cs_course_id)
    sql = "SELECT sis_section_id AS id,
                  is_primary,
                  sis_course_name AS code,
                  sis_course_title AS title,
                  sis_instruction_format AS format,
                  sis_section_num AS number,
                  instructor_uid,
                  instructor_role_code,
                  instruction_mode AS mode,
                  meeting_location AS location,
                  meeting_days AS days,
                  meeting_end_date AS end_date,
                  meeting_end_time AS end_time
             FROM sis_data.edo_sections
            WHERE sis_term_id = '#{term.sis_id}'
              AND cs_course_id = '#{cs_course_id}'
         ORDER BY sis_course_name ASC,
                  sis_instruction_format DESC,
                  sis_section_num ASC;"
    results = Utils.query_pg_db(NessieUtils.nessie_pg_db_credentials, sql)
    results.map do |r|
      {
        id: r['id'],
        code: r['code'],
        cs_course_id: cs_course_id,
        instruction_mode: r['mode'],
        instructor_uid: r['instructor_uid'],
        instructor_role_code: r['instructor_role_code'],
        label: "#{r['format']} #{r['number']}",
        location: r['location'],
        primary: (r['is_primary'] == 't'),
        schedule: "#{r['days']} #{r['start_time']} #{r['end_time']}",
        title: r['title']
      }
    end
  end

  def self.get_test_course_instructors(term, cs_course_id)
    sql = "SELECT DISTINCT instructor_uid,
                  instructor_name
             FROM sis_data.edo_sections
            WHERE sis_term_id = '#{term.sis_id}'
              AND cs_course_id = '#{cs_course_id}';"
    results = Utils.query_pg_db(NessieUtils.nessie_pg_db_credentials, sql)
    results.map do |r|
      User.new full_name: r['instructor_name'],
               uid: r['instructor_uid']
    end
  end

  def self.get_course(term, cs_course_id)
    instr = get_test_course_instructors(term, cs_course_id)
    section_data = get_test_course_section_data(term, cs_course_id)
    grouped = section_data.group_by { |s| s[:id] }
    sections = grouped.map do |k, v|
      instructors = []
      v.each do |u|
        instructor = instr.find { |i| i.uid.to_s == u[:instructor_uid].to_s }
        if instructor
          instructor.role_code = u[:instructor_role_code]
          instructors << instructor
        end
      end
      instructors.compact!
      Section.new id: k,
                  course: v[0][:code],
                  cs_course_id: v[0][:cs_course_id],
                  instruction_mode: v[0][:instruction_mode],
                  instructors: instructors.uniq,
                  label: v[0][:label],
                  locations: (v.map { |l| l[:location] }).uniq,
                  primary: v[0][:primary],
                  schedules: (v.map { |s| s[:schedule] }).uniq
    end
    sections.each { |s| logger.info "Section: #{s.inspect}" }
    teachers = sections.select(&:primary).map { |prim| prim.instructors }
    teachers.flatten!
    teachers.compact!
    teachers.uniq!
    codes = sections.map(&:course).uniq
    codes.sort!
    Course.new code: codes.first,
               title: (section_data[0][:title]),
               term: term,
               sections: sections,
               teachers: teachers
  end

  def self.get_test_course(term, catalog_id_prefix)
    id = get_test_cs_course_id_from_catalog_id(term, catalog_id_prefix)
    if id
      course = get_course(term, id)
      if course.teachers.any?
        course
      else
        logger.warn "Course code '#{catalog_id_prefix}' in term #{term.sis_id} has no teachers"
        nil
      end
    else
      logger.warn "No test course found matching course code '#{catalog_id_prefix}' in term #{term.sis_id}"
      nil
    end
  end

  def self.get_instructor_term_courses(instructor, term)
    sql = "SELECT DISTINCT cs_course_id
             FROM sis_data.edo_sections
            WHERE sis_term_id = '#{term.sis_id}'
              AND instructor_uid = '#{instructor.uid}'"
    ids = Utils.query_pg_db(NessieUtils.nessie_pg_db_credentials, sql).map { |r| r['cs_course_id'] }
    courses = ids.map { |id| get_course(term, id) }
    courses.each do |course|
      prims = course.sections.select(&:primary).map(&:instructors).map(&:uid).compact.uniq
      unless prims.include? instructor.uid
        course.sections.keep_if { |s| s.instructors.map(&:uid).include? instructor.uid }
      end
    end
    courses
  end

  def self.get_course_enrollment(course)
    sql = "SELECT DISTINCT sis_data.edo_enrollments.sis_section_id,
                  sis_data.edo_enrollments.ldap_uid AS uid,
                  sis_data.edo_enrollments.sis_enrollment_status AS status,
                  sis_data.edo_enrollments.grading_basis,
                  student.student_profile_index.sid,
                  student.student_profile_index.email_address
             FROM sis_data.edo_enrollments
             JOIN student.student_profile_index
               ON student.student_profile_index.uid = sis_data.edo_enrollments.ldap_uid
            WHERE sis_term_id = '#{course.term.sis_id}'
              AND sis_section_id IN (#{Utils.in_op(course.sections.map &:id)})"
    results = Utils.query_pg_db(NessieUtils.nessie_pg_db_credentials, sql)
    enrollments = results.map do |r|
      student = User.new uid: r['uid'],
                         sis_id: r['sid'],
                         email: r['email_address']
      SectionEnrollment.new user: student,
                            section_id: r['sis_section_id'],
                            grading_basis: r['grading_basis'],
                            status: r['status']
    end
    enrollments.uniq!
    course.sections.each do |section|
      section.enrollments = enrollments.select { |e| e.section_id.to_s == section.id.to_s }
    end
  end

  def self.get_users_of_affiliations(affiliations, count=nil)
    sql = "SELECT ldap_uid AS uid,
                  sid,
                  first_name,
                  last_name,
                  email_address AS email
             FROM sis_data.basic_attributes
            WHERE affiliations = '#{affiliations}'
              AND email_address IS NOT NULL
         ORDER BY first_name
         #{'LIMIT ' + count.to_s if count}"
    results = Utils.query_pg_db(NessieUtils.nessie_pg_db_credentials, sql)
    results.map do |r|
      User.new uid: r['uid'],
               sis_id: r['sid'],
               first_name: r['first_name'],
               last_name: r['last_name'],
               email: r['email']
    end
  end

  def self.get_instructor_update_uids(term, section_ids)
    sql = "SELECT DISTINCT sis_section_id, ldap_uid
                      FROM sis_data.edo_instructor_updates
                     WHERE sis_term_id = '#{term.sis_id}'
                       AND sis_section_id IN (#{in_op section_ids});"
    query_pg_db(NessieUtils.nessie_pg_db_credentials, sql).map { |r| r['ldap_uid'] }
  end

  def self.insert_instructor_update(course, section, instructor, role_code)
    sql = "INSERT INTO sis_data.edo_instructor_updates (sis_term_id, sis_course_id, sis_section_id, ldap_uid, sis_id,
                                                        role_code, is_primary, last_updated)
                SELECT '#{course.term.sis_id}', '#{section.cs_course_id}', '#{section.id}', '#{instructor.uid}',
                       '#{instructor.sis_id}', '#{role_code}', #{section.primary ? 'TRUE' : 'FALSE'}, NOW();"
    result = query_pg_db(NessieUtils.nessie_pg_db_credentials, sql)
    logger.warn "Command status: #{result.cmd_status}. Result status: #{result.result_status}"
  end

  def self.get_student_update_uids(term, section_ids)
    sql = "SELECT DISTINCT sis_section_id, ldap_uid
                      FROM sis_data.edo_enrollment_updates
                     WHERE sis_term_id = '#{term.sis_id}'
                       AND sis_section_id IN (#{in_op section_ids})"
    query_pg_db(NessieUtils.nessie_pg_db_credentials, sql).map { |r| r['ldap_uid'] }
  end

  def self.insert_enrollment_update(section_enrollment)
    sql = "INSERT INTO sis_data.edo_enrollment_updates (sis_term_id, sis_section_id, ldap_uid, sis_id,
                                                        sis_enrollment_status, course_career, last_updated)
                SELECT '#{section_enrollment.term.sis_id}', '#{section_enrollment.section_id}', #{section_enrollment.user.uid},
                       '#{section_enrollment.user.sis_id}', '#{section_enrollment.status}', 'UGRD', NOW();"
    result = query_pg_db(NessieUtils.nessie_pg_db_credentials, sql)
    logger.warn "Command status: #{result.cmd_status}. Result status: #{result.result_status}"
  end
end
