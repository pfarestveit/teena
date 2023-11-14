require_relative 'spec_helper'

class RipleyUtils < Utils

  include Logging

  # SETTINGS

  @config = Utils.config['ripley']

  def self.base_url
    @config['base_url']
  end

  def self.base_url_prod
    @config['base_url_prod']
  end

  def self.background_job_attempts
    @config['background_job_attempts']
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

  def self.dev_auth_password
    @config['dev_auth_password']
  end

  def self.e_grades_site_ids
    @config['e_grades_site_ids']
  end

  def self.e_grades_student_count
    @config['e_grades_student_count']
  end

  def self.grade_distribution_site_ids
    @config['newt_site_ids']
  end

  def self.mailing_list_suffix
    base_url.include?('-qa') ? '-cc-ets-qa' : '-cc-ets-dev'
  end

  def self.recent_refresh_days_past
    @config['recent_refresh_days_past']
  end

  def self.test_data_file
    File.join(Utils.config_dir, 'test-data-ripley.json')
  end

  # TERMS

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

  def self.previous_term(current_term)
    term = Term.new sis_id: previous_term_sis_id(current_term),
                    name: previous_term_name(current_term)
    term.code = Utils.term_name_to_hyphenated_code(term.name)
    term
  end

  def self.previous_term_sis_id(current_term)
    current_code = current_term.sis_id.to_i
    (current_code - ((current_code % 10 == 2) ? 4 : 3)).to_s
  end

  def self.previous_term_name(current_term)
    parts = current_term.name.split
    case parts[0]
    when 'Spring'
      "Fall #{parts[1].to_i - 1}"
    when 'Summer'
      "Spring #{parts[1]}"
    else
      "Summer #{parts[1]}"
    end
  end

  # SQL

  # Course data

  def self.get_cs_course_id_from_catalog_id(term, catalog_id_prefix)
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

  def self.get_cs_course_id_from_ccn(term, ccn)
    sql = "SELECT cs_course_id
             FROM sis_data.edo_sections
            WHERE sis_term_id = '#{term.sis_id}'
              AND sis_section_id = '#{ccn}';"
    Utils.query_pg_db_field(NessieUtils.nessie_pg_db_credentials, sql, 'cs_course_id').first
  end

  def self.get_course(term, cs_course_id)
    instr = get_course_instructors(term, cs_course_id)
    section_data = get_test_course_section_data(term, cs_course_id)
    grouped = section_data.group_by { |s| s[:id] }
    sections = grouped.map do |k, v|
      instructors = []
      v.each do |u|
        instructor = instr.find { |i| i.uid.to_s == u[:instructor_uid].to_s }
        if instructor
          instructor_role = InstructorAndRole.new(instructor, u[:instructor_role_code])
          instructors << instructor_role
        end
      end
      instructors.uniq! { |i| [i.user, i.role_code] }
      instructors.compact!
      Section.new id: k,
                  course: v[0][:code],
                  cs_course_id: v[0][:cs_course_id],
                  instruction_mode: v[0][:instruction_mode],
                  instructors_and_roles: instructors,
                  label: v[0][:label],
                  locations: (v.map { |l| l[:location] }).compact.uniq,
                  primary: v[0][:primary],
                  primary_assoc_ids: (v.map { |p| p[:primary_assoc_id] }).uniq,
                  schedules: (v.map { |s| s[:schedule] }).uniq
    end
    teachers = sections.select(&:primary).map { |prim| prim.instructors_and_roles.map &:user }
    teachers.flatten!
    teachers.compact!
    teachers.uniq!
    codes = sections.map(&:course).uniq
    codes.sort!
    logger.debug "Course #{codes.first} in #{term.name} has #{sections.length} sections"
    Course.new code: codes.first,
               sections: sections,
               teachers: teachers,
               term: term,
               title: (section_data[0][:title])
  end

  def self.get_test_course(term, catalog_id_prefix)
    id = get_cs_course_id_from_catalog_id(term, catalog_id_prefix)
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

  # Sections

  def self.get_test_course_section_data(term, cs_course_id)
    sql = "SELECT sis_section_id AS id,
                  is_primary,
                  primary_associated_section_id,
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
                  meeting_start_time AS start_time,
                  meeting_end_time AS end_time
             FROM sis_data.edo_sections
            WHERE sis_term_id = '#{term.sis_id}'
              AND cs_course_id = '#{cs_course_id}'
         ORDER BY sis_course_name ASC,
                  sis_instruction_format DESC,
                  sis_section_num ASC;"
    results = Utils.query_pg_db(NessieUtils.nessie_pg_db_credentials, sql)
    results.map do |r|
      mode = case r['mode']
             when 'EF'
               '(Flexible)'
             when 'EH'
               '(Hybrid)'
             when 'ER'
               '(Remote)'
             when 'O'
               '(Online)'
             when 'P'
               '(In Person)'
             when 'W'
               '(Web-based)'
             else
               "(#{r['mode']})"
             end
      days = r['days'] ? (r['days'].gsub('MO', 'M').gsub('WE', 'W').gsub('FR', 'F').strip) : '—'
      start = (r['start_time'] == '00:00' || !r['start_time']) ? '—' : "#{DateTime.strptime(r['start_time'], "%H:%M").strftime("%l:%M%p")[0..-2]}-"
      finish = (r['end_time'] == '00:00' || !r['end_time']) ? '—' : DateTime.strptime(r['end_time'], "%H:%M").strftime("%l:%M%p")[0..-2]
      schedule = (days == '—') ? '—' : "#{days} #{start.strip}#{finish.strip}".strip
      location = r['location'] || '—'
      {
        id: r['id'],
        code: r['code'],
        cs_course_id: cs_course_id,
        instruction_mode: mode,
        instructor_uid: r['instructor_uid'],
        instructor_role_code: r['instructor_role_code'],
        label: "#{r['format']} #{r['number']} #{mode}",
        location: location.gsub(/\s+/, ' '),
        primary: (r['is_primary'] == 't'),
        primary_assoc_id: r['primary_associated_section_id'],
        schedule: schedule,
        title: r['title']
      }
    end
  end

  def self.expected_instr_section_data(site, sections = nil)
    instructor_data = []
    site_has_primaries = site.sections.select(&:primary).any?
    secs = sections || site.sections
    secs.each do |section|
      section.instructors_and_roles.each do |instr|
        instr.user.role = if section.primary
                            if %w(PI ICNT INVT).include? instr.role_code
                              'Teacher'
                            elsif instr.role_code == 'APRX'
                              'Lead TA'
                            else
                              nil
                            end
                          else
                            if %w(PI TNIC).include? instr.role_code
                              site_has_primaries ? 'TA' : 'Teacher'
                            else
                              nil
                            end
                          end
        instructor_data << {
          uid: instr.user.uid,
          role: instr.user.role&.downcase,
          section_id: section.id
        }
      end
    end
    instructor_data.sort_by { |h| [h[:uid], h[:section_id]] }
  end

  def self.expected_student_section_data(site, sections = nil)
    student_data = []
    secs = sections || site.sections
    secs.each do |section|
      section.enrollments.each do |enroll|
        student_data << {
          uid: enroll.user.uid,
          role: (enroll.status == 'E' ? 'student' : 'waitlist student'),
          section_id: enroll.section_id
        }
      end
    end
    student_data.sort_by { |h| [h[:uid], h[:section_id]] }
  end

  # Course instructors

  def self.get_course_instructors(term, cs_course_id)
    sql = "SELECT DISTINCT sis_data.edo_sections.instructor_uid,
                  sis_data.edo_sections.instructor_name,
                  sis_data.edo_basic_attributes.email_address,
                  sis_data.edo_basic_attributes.sid
             FROM sis_data.edo_sections
             JOIN sis_data.edo_basic_attributes
               ON sis_data.edo_basic_attributes.ldap_uid = sis_data.edo_sections.instructor_uid
            WHERE sis_data.edo_sections.sis_term_id = '#{term.sis_id}'
              AND sis_data.edo_sections.cs_course_id = '#{cs_course_id}';"
    results = Utils.query_pg_db(NessieUtils.nessie_pg_db_credentials, sql)
    results.map do |r|
      User.new uid: r['instructor_uid'],
               email: r['email_address'],
               full_name: r['instructor_name'],
               sis_id: r['sid']
    end
  end

  def self.get_course_instructor_sections(course, instructor)
    course.sections.select do |section|
      section.instructors_and_roles.find { |i| i.user.uid == instructor.uid }
    end
  end

  def self.get_course_instructor_roles(course, instructor)
    instr_sections = get_course_instructor_sections(course, instructor)
    instr_roles = instr_sections.map do |section|
      section.instructors_and_roles.find { |i| i.user.uid == instructor.uid }.role_code
    end
    instr_roles.uniq
  end

  def self.get_primary_instructor(site)
    pi_role = site.sections.map(&:instructors_and_roles).flatten.find { |t| t.role_code == 'PI' }
    pi_role&.user
  end

  def self.get_instructor_term_courses(instructor, term)
    sql = "SELECT DISTINCT cs_course_id
             FROM sis_data.edo_sections
            WHERE sis_term_id = '#{term.sis_id}'
              AND instructor_uid = '#{instructor.uid}'"
    ids = Utils.query_pg_db(NessieUtils.nessie_pg_db_credentials, sql).map { |r| r['cs_course_id'] }
    courses = ids.map { |id| get_course(term, id) }
    courses.each do |course|
      roles = get_course_instructor_roles(course, instructor)
      if (roles & %w(PI APRX)).any?
        primary_ids = course.sections.select do |section|
          section.primary && (section.instructors_and_roles.map { |i| i.user.uid }.include?(instructor.uid))
        end.map &:id
        secondary_ids = course.sections.select do |section|
          !section.primary && (primary_ids & section.primary_assoc_ids).any?
        end.map &:id
        course.sections.keep_if { |section| (primary_ids + secondary_ids).include? section.id }
      else
        course.sections.keep_if do |section|
          section.instructors_and_roles.map { |i| i.user.uid }.include? instructor.uid
        end
      end
      logger.info "Term course #{course.code}, sections #{course.sections.map &:id}"
    end
    courses
  end

  # Course enrollment

  def self.get_course_enrollment(course)
    sql = "SELECT enrollment.sis_section_id,
                  enrollment.ldap_uid AS uid,
                  sis_data.edo_basic_attributes.sid,
                  sis_data.edo_basic_attributes.first_name,
                  sis_data.edo_basic_attributes.last_name,
                  enrollment.grade,
                  enrollment.sis_enrollment_status AS status,
                  sis_data.edo_basic_attributes.email_address
             FROM sis_data.edo_enrollments enrollment
             JOIN sis_data.edo_basic_attributes
               ON sis_data.edo_basic_attributes.ldap_uid = enrollment.ldap_uid
            WHERE enrollment.sis_term_id = '#{course.term.sis_id}'
              AND enrollment.sis_section_id IN (#{Utils.in_op(course.sections.map &:id)})
              AND enrollment.sis_enrollment_status IN ('E', 'W')
              AND (SELECT DISTINCT(primary_enrollment.grade)
                     FROM sis_data.edo_enrollments primary_enrollment
                     JOIN sis_data.edo_sections
                       ON primary_enrollment.ldap_uid = enrollment.ldap_uid
                      AND primary_enrollment.sis_term_id = enrollment.sis_term_id
                      AND primary_enrollment.sis_section_id = sis_data.edo_sections.primary_associated_section_id
                    WHERE sis_data.edo_sections.sis_term_id = enrollment.sis_term_id
                      AND sis_data.edo_sections.sis_section_id = enrollment.sis_section_id
                   ) != 'W';"
    results = Utils.query_pg_db(NessieUtils.nessie_pg_db_credentials, sql)
    results_to_enrollments(course, results)
  end

  def self.get_completed_enrollments(course)
    sql = "SELECT sis_data.edo_enrollments.sis_section_id,
                  sis_data.edo_enrollments.ldap_uid AS uid,
                  sis_data.edo_enrollments.grade,
                  sis_data.edo_enrollments.sis_enrollment_status AS status,
                  sis_data.edo_basic_attributes.sid,
                  sis_data.edo_basic_attributes.first_name,
                  sis_data.edo_basic_attributes.last_name,
                  sis_data.edo_basic_attributes.email_address
             FROM sis_data.edo_enrollments
             JOIN sis_data.edo_basic_attributes
               ON sis_data.edo_basic_attributes.ldap_uid = sis_data.edo_enrollments.ldap_uid
            WHERE sis_data.edo_enrollments.sis_term_id = '#{course.term.sis_id}'
              AND sis_data.edo_enrollments.sis_section_id IN (#{Utils.in_op(course.sections.map &:id)})
              AND sis_data.edo_enrollments.sis_enrollment_status = 'E'
              AND sis_data.edo_enrollments.grade != 'W';"
    results = Utils.query_pg_db(NessieUtils.nessie_pg_db_credentials, sql)
    results_to_enrollments(course, results)
  end

  def self.results_to_enrollments(course, results)
    enrollments = results.map do |r|
      student = User.new uid: r['uid'],
                         email: r['email_address'],
                         first_name: r['first_name'],
                         full_name: "#{r['first_name']} #{r['last_name']}",
                         last_name: r['last_name'],
                         sis_id: r['sid']
      SectionEnrollment.new user: student,
                            grade: r['grade'],
                            grading_basis: r['grading_basis'],
                            section_id: r['sis_section_id'],
                            status: r['status']
    end
    enrollments.uniq!
    course.sections.each do |section|
      section.enrollments = enrollments.select { |e| e.section_id.to_s == section.id.to_s }
    end
  end

  # Test users

  def self.get_users_of_affiliations(affiliations, count = nil)
    sql = "SELECT ldap_uid AS uid,
                  sid,
                  first_name,
                  last_name,
                  email_address AS email
             FROM sis_data.edo_basic_attributes
            WHERE affiliations = '#{affiliations}'
              AND email_address IS NOT NULL
         ORDER BY ldap_uid DESC
         #{'LIMIT ' + count.to_s if count}"
    results = Utils.query_pg_db(NessieUtils.nessie_pg_db_credentials, sql)
    results.map do |r|
      User.new uid: r['uid'],
               email: r['email'],
               first_name: r['first_name'],
               last_name: r['last_name'],
               sis_id: r['sid']
    end
  end

  # Incremental updates

  def self.set_last_sync_timestamps
    sql = "UPDATE canvas_synchronization
              SET last_enrollment_sync = NOW() - INTERVAL '#{recent_refresh_days_past} DAY',
                  last_instructor_sync = NOW() - INTERVAL '#{recent_refresh_days_past} DAY';"
    Utils.query_pg_db(db_credentials, sql)
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

  # Mailing lists

  def self.drop_existing_mailing_lists
    Utils.query_pg_db(db_credentials, 'DELETE FROM canvas_site_mailing_lists')
  end

  def self.set_mailing_list_member_email(member, email_address)
    sql = "UPDATE canvas_site_mailing_list_members
              SET email_address = '#{email_address}'
            WHERE CONCAT(first_name, ' ', last_name) = '#{member.full_name}'
              AND deleted_at IS NULL;"
    result = query_pg_db(db_credentials, sql)
    logger.warn "Command status: #{result.cmd_status}. Result status: #{result.result_status}"
  end

  def self.get_mailing_list_member_email(member)
    sql = "SELECT email_address
             FROM canvas_site_mailing_list_members
            WHERE CONCAT(first_name, ' ', last_name) = '#{member.full_name}'
              AND deleted_at IS NULL;"
    query_pg_db_field(db_credentials, sql, 'email_address').first
  end
end
