class NessieTimelineUtils < NessieUtils

  #### NOTES ####

  def self.get_external_note_count(schema)
    query = "SELECT COUNT(*)
             FROM #{schema}.advising_notes
             #{+' WHERE advisor_first_name != \'Reception\' AND advisor_last_name != \'Front Desk\'' if schema == TimelineRecordSource::E_AND_I.note_schema};"
    query_pg_db_field(NessieUtils.nessie_pg_db_credentials, query, 'count').first
  end

  # Returns ASC advising notes associated with a given student
  # @param [BOACUser] student
  # @return [Array<Note>]
  def self.get_asc_notes(student)
    query = "SELECT boac_advising_asc.advising_notes.id AS id,
                    boac_advising_asc.advising_notes.created_at AS created_date,
                    boac_advising_asc.advising_notes.updated_at AS updated_date,
                    boac_advising_asc.advising_notes.advisor_uid AS advisor_uid,
                    boac_advising_asc.advising_notes.advisor_first_name AS advisor_first_name,
                    boac_advising_asc.advising_notes.advisor_last_name AS advisor_last_name,
                    boac_advising_asc.advising_notes.subject AS subject,
                    boac_advising_asc.advising_notes.body AS body,
                    ARRAY_AGG (boac_advising_asc.advising_note_topics.topic) AS topics
             FROM boac_advising_asc.advising_notes
             LEFT JOIN boac_advising_asc.advising_note_topics
               ON boac_advising_asc.advising_notes.id = boac_advising_asc.advising_note_topics.id
             WHERE boac_advising_asc.advising_notes.sid = '#{student.sis_id}'
             GROUP BY advising_notes.id, created_date, advisor_uid, subject, body;"
    results = query_pg_db(NessieUtils.nessie_pg_db_credentials, query)

    results.map do |r|
      Note.new id: r['id'],
               advisor: BOACUser.new(uid: r['advisor_uid'], first_name: r['advisor_first_name'], last_name: r['advisor_last_name']),
               subject: r['subject'],
               body: r['body'],
               topics: (r['topics'].delete('{"}').gsub('NULL', '').split(',').sort if r['topics']),
               student: student,
               created_date: Time.parse(r['created_date']).utc.localtime,
               updated_date: Time.parse(r['updated_date']).utc.localtime,
               source: TimelineRecordSource::ASC
    end
  end

  # Returns E&I advising notes associated with a given student
  # @param [BOACUser] student
  # @return [Array<Note>]
  def self.get_e_and_i_notes(student)
    query = "SELECT boac_advising_e_i.advising_notes.id AS id,
                    boac_advising_e_i.advising_notes.advisor_uid AS advisor_uid,
                    boac_advising_e_i.advising_notes.advisor_first_name AS advisor_first_name,
                    boac_advising_e_i.advising_notes.advisor_last_name AS advisor_last_name,
                    boac_advising_e_i.advising_notes.overview AS subject,
                    boac_advising_e_i.advising_notes.note AS body,
                    boac_advising_e_i.advising_notes.created_at AS created_date,
                    boac_advising_e_i.advising_notes.updated_at AS updated_date,
                    boac_advising_e_i.advising_note_topics.topic AS topic
             FROM boac_advising_e_i.advising_notes
             LEFT JOIN boac_advising_e_i.advising_note_topics
               ON boac_advising_e_i.advising_notes.id = boac_advising_e_i.advising_note_topics.id
             WHERE boac_advising_e_i.advising_notes.sid = '#{student.sis_id}'
               AND advisor_first_name != 'Reception' AND advisor_last_name != 'Front Desk';"

    results = query_pg_db(NessieUtils.nessie_pg_db_credentials, query)
    notes_data = results.group_by { |h1| h1['id'] }.map do |k, v|
      unless v[0]['advisor_first_name'] == 'Reception' && v[0]['advisor_last_name'] == 'Front Desk'
        {
          id: k,
          advisor: BOACUser.new(uid: v[0]['advisor_uid'], first_name: "#{v[0]['advisor_first_name']}", last_name: "#{v[0]['advisor_last_name']}"),
          subject: v[0]['subject'],
          body: v[0]['body'].to_s,
          created_date: Time.parse(v[0]['created_date'].to_s).utc.localtime,
          updated_date: Time.parse(v[0]['updated_date'].to_s).utc.localtime,
          topics: (v.map { |t| t['topic'].upcase if t['topic'] }).compact.sort,
          source: TimelineRecordSource::E_AND_I
        }
      end
    end

    notes_data.compact.map { |d| Note.new d }
  end

  def self.get_data_sci_notes(student)
    query = "SELECT boac_advising_data_science.advising_notes.id AS id,
                    boac_advising_data_science.advising_notes.advisor_email AS advisor_email,
                    boac_advising_data_science.advising_notes.reason_for_appointment AS topics,
                    boac_advising_data_science.advising_notes.body AS body,
                    boac_advising_data_science.advising_notes.created_at AS created_date
             FROM boac_advising_data_science.advising_notes
             WHERE boac_advising_data_science.advising_notes.sid = '#{student.sis_id}';"
    results = query_pg_db(NessieUtils.nessie_pg_db_credentials, query)
    notes_data = results.map do |r|

      created_date = Time.parse(r['created_date'].to_s).utc.localtime
      {
        id: r['id'],
        source: TimelineRecordSource::DATA,
        body: r['body'],
        topics: (r['topics'].split(', ').map(&:upcase) if r['topics']).compact.sort,
        created_date: created_date,
        updated_date: created_date
      }
    end
    notes_data.map { |d| Note.new d }
  end

  def self.get_history_notes(student)
    sql = "SELECT boac_advising_history_dept.advising_notes.id AS id,
                  boac_advising_history_dept.advising_notes.advisor_uid AS advisor_uid,
                  boac_advising_history_dept.advising_notes.note AS body,
                  boac_advising_history_dept.advising_notes.created_at AS created_date
             FROM boac_advising_history_dept.advising_notes
            WHERE boac_advising_history_dept.advising_notes.sid = '#{student.sis_id}'"

    results = query_pg_db(NessieUtils.nessie_pg_db_credentials, sql)
    notes_data = results.map do |r|
      {
        id: r['id'],
        source: TimelineRecordSource::HISTORY,
        body: r['body'],
        advisor: (BOACUser.new uid: r['advisor_uid']),
        created_date: Time.parse(r['created_date']).localtime,
        updated_date: Time.parse(r['created_date']).localtime
      }
    end
    notes_data.map { |d| Note.new d }
  end

  # Returns SIS advising notes associated with a given student
  # @param student [BOACUser]
  # @return [Array<Note>]
  def self.get_sis_notes(student)
    query = "SELECT sis_advising_notes.advising_notes.id AS id,
                    sis_advising_notes.advising_notes.note_category AS category,
                    sis_advising_notes.advising_notes.note_subcategory AS subcategory,
                    sis_advising_notes.advising_notes.note_body AS body,
                    sis_advising_notes.advising_notes.created_by AS advisor_uid,
                    sis_advising_notes.advising_notes.advisor_sid AS advisor_sid,
                    sis_advising_notes.advising_notes.created_at AS created_date,
                    sis_advising_notes.advising_notes.updated_at AS updated_date,
                    sis_advising_notes.advising_note_topics.note_topic AS topic,
                    sis_advising_notes.advising_note_attachments.sis_file_name AS sis_file_name,
                    sis_advising_notes.advising_note_attachments.user_file_name AS user_file_name
            FROM sis_advising_notes.advising_notes
            LEFT JOIN sis_advising_notes.advising_note_topics
              ON sis_advising_notes.advising_notes.id = sis_advising_notes.advising_note_topics.advising_note_id
            LEFT JOIN sis_advising_notes.advising_note_attachments
              ON sis_advising_notes.advising_notes.id = sis_advising_notes.advising_note_attachments.advising_note_id
            WHERE sis_advising_notes.advising_notes.sid = '#{student.sis_id}';"

    results = query_pg_db(NessieUtils.nessie_pg_db_credentials, query)
    notes_data = results.group_by { |h1| h1['id'] }.map do |k, v|
      # If the note has no body, concatenate the category and subcategory as the body
      source_body_empty = (v[0]['body'].nil? || v[0]['body'].strip.empty?)
      body = source_body_empty ?
               "#{v[0]['category']}#{+', ' if v[0]['subcategory']}#{v[0]['subcategory']}" :
               Nokogiri::HTML(v[0]['body']).text.gsub('&Tab;', '')

      attachment_data = v.map do |r|
        unless r['sis_file_name'].nil? || r['sis_file_name'].empty?
          {
            :sis_file_name => r['sis_file_name'],
            :file_name => ((r['advisor_uid'] == 'UCBCONVERSION') ? r['sis_file_name'] : r['user_file_name'])
          }
        end
      end
      attachments = attachment_data.compact.uniq.map { |d| Attachment.new d }

      advisor_uid = v[0]['advisor_uid']
      created_date = v[0]['created_date']
      updated_date = (advisor_uid == 'UCBCONVERSION') ? created_date : v[0]['updated_date']
      {
        :id => k,
        :body => body,
        :source_body_empty => source_body_empty,
        :advisor => BOACUser.new({ :uid => advisor_uid }),
        :created_date => Time.parse(created_date.to_s).utc.localtime,
        :updated_date => Time.parse(updated_date.to_s).utc.localtime,
        :topics => (v.map { |t| t['topic'].upcase if t['topic'] }).compact.sort,
        :attachments => attachments,
        :source => TimelineRecordSource::SIS
      }
    end
    notes_data.map { |d| Note.new d }
  end

  # Returns all SIDs represented in a given advising note source
  # @param src [TimelineRecordSource]
  # @return [Array<String>]
  def self.get_sids_with_notes_of_src(src)
    query = "SELECT DISTINCT #{src.note_schema}.advising_notes.sid
             FROM #{src.note_schema}.advising_notes
             #{+' WHERE advisor_first_name != \'Reception\' AND advisor_last_name != \'Front Desk\'' if src == TimelineRecordSource::E_AND_I}
    #{+' INNER JOIN ' + src.note_schema + '.advising_note_attachments
                    ON ' + src.note_schema + '.advising_notes.sid = ' + src.note_schema + '.advising_note_attachments.sid' if src == TimelineRecordSource::SIS}
             ORDER BY sid ASC;"
    results = Utils.query_pg_db(NessieUtils.nessie_pg_db_credentials, query)
    results.map { |r| r['sid'] }
  end

  # Returns all SIS note authors
  # @param student [BOACUser]
  # @return [Array]
  def self.get_all_advising_note_authors
    query = "SELECT uid, sid, first_name, last_name
              FROM boac_advising_notes.advising_note_authors;"
    results = Utils.query_pg_db(NessieUtils.nessie_pg_db_credentials, query)
    results.map do |r|
      {
        :uid => r['uid'],
        :sid => r['sid'],
        :first_name => r['first_name'],
        :last_name => r['last_name']
      }
    end
  end

  # Returns basic identifying data for a SIS note author
  # @param uid [Fixnum]
  # @return [Array]
  def self.get_advising_note_author(uid)
    query = "SELECT sid, first_name, last_name
              FROM boac_advising_notes.advising_note_authors
              WHERE uid = '#{uid}';"
    results = Utils.query_pg_db(NessieUtils.nessie_pg_db_credentials, query)
    if results.any?
      {
        :sid => results[0]['sid'],
        :first_name => results[0]['first_name'],
        :last_name => results[0]['last_name']
      }
    end
  end

  def self.set_advisor_data(advisor)
    data = get_advising_note_author advisor.uid
    advisor.sis_id = data[:sid]
    advisor.first_name = data[:first_name]
    advisor.last_name = data[:last_name]
    advisor.full_name = "#{advisor.first_name} #{advisor.last_name}"
  end

  ### APPOINTMENTS ###

  def self.get_sis_appts(student)
    query = "SELECT sis_advising_notes.advising_appointments.id AS id,
                    sis_advising_notes.advising_appointments.note_body AS detail,
                    sis_advising_notes.advising_appointments.created_by AS advisor_uid,
                    sis_advising_notes.advising_appointments.advisor_sid AS advisor_sid,
                    sis_advising_notes.advising_appointments.created_at AS created_date,
                    sis_advising_notes.advising_appointments.updated_at AS updated_date,
                    sis_advising_notes.advising_appointment_advisors.first_name AS advisor_first_name,
                    sis_advising_notes.advising_appointment_advisors.last_name AS advisor_last_name,
                    sis_advising_notes.advising_note_topics.note_topic AS topic,
                    sis_advising_notes.advising_note_attachments.sis_file_name AS sis_file_name,
                    sis_advising_notes.advising_note_attachments.user_file_name AS user_file_name
             FROM sis_advising_notes.advising_appointments
             LEFT JOIN sis_advising_notes.advising_appointment_advisors
               ON sis_advising_notes.advising_appointments.advisor_sid = sis_advising_notes.advising_appointment_advisors.sid
             LEFT JOIN sis_advising_notes.advising_note_topics
               ON sis_advising_notes.advising_appointments.id = sis_advising_notes.advising_note_topics.advising_note_id
             LEFT JOIN sis_advising_notes.advising_note_attachments
               ON sis_advising_notes.advising_appointments.id = sis_advising_notes.advising_note_attachments.advising_note_id
             WHERE sis_advising_notes.advising_appointments.sid = '#{student.sis_id}'
             ORDER BY id ASC;"

    results = query_pg_db(NessieUtils.nessie_pg_db_credentials, query)
    appts_data = results.group_by { |h1| h1['id'] }.map do |k, v|
      attachment_data = v.map do |r|
        unless r['sis_file_name'].nil? || r['sis_file_name'].empty?
          {
            sis_file_name: r['sis_file_name'],
            file_name: ((r['advisor_uid'] == 'UCBCONVERSION') ? r['sis_file_name'] : r['user_file_name'])
          }
        end
      end
      attachments = attachment_data.compact.uniq.map { |d| Attachment.new d }
      advisor_uid = v[0]['advisor_uid']
      created_date = v[0]['created_date']
      updated_date = (advisor_uid == 'UCBCONVERSION') ? created_date : v[0]['updated_date']
      advisor = BOACUser.new(
        uid: v[0]['advisor_uid'],
        sis_id: v[0]['created_date'],
        first_name: v[0]['advisor_first_name'],
        last_name: v[0]['advisor_last_name']
      )
      {
        id: k,
        detail: Nokogiri::HTML(v[0]['detail']).text.strip.gsub('&Tab;', ''),
        student: student,
        advisor: advisor,
        created_date: Time.parse(created_date.to_s).utc.localtime,
        updated_date: Time.parse(updated_date.to_s).utc.localtime,
        attachments: attachments,
        topics: (v.map { |t| t['topic'].upcase if t['topic'] }).compact.sort,
        source: TimelineRecordSource::SIS
      }
    end
    appts_data.map { |d| Appointment.new d }
  end

  # Returns all SIDs represented in a given advising note source
  # @return [Array<String>]
  def self.get_sids_with_sis_appts
    query = "SELECT DISTINCT sis_advising_notes.advising_appointments.sid
             FROM sis_advising_notes.advising_appointments
             INNER JOIN sis_advising_notes.advising_note_attachments
               ON sis_advising_notes.advising_note_attachments.sid = sis_advising_notes.advising_appointments.sid
             ORDER BY sid ASC;"
    results = Utils.query_pg_db(NessieUtils.nessie_pg_db_credentials, query)
    results.map { |r| r['sid'] }
  end

  def self.get_ycbm_appts(student)
    query = "SELECT boac_advising_appointments.ycbm_advising_appointments.id AS id,
                    boac_advising_appointments.ycbm_advising_appointments.appointment_type AS type,
                    boac_advising_appointments.ycbm_advising_appointments.title AS title,
                    boac_advising_appointments.ycbm_advising_appointments.details AS detail,
                    boac_advising_appointments.ycbm_advising_appointments.advisor_name AS advisor_name,
                    boac_advising_appointments.ycbm_advising_appointments.starts_at AS start_time,
                    boac_advising_appointments.ycbm_advising_appointments.ends_at AS end_time,
                    boac_advising_appointments.ycbm_advising_appointments.cancelled AS cancelled,
                    boac_advising_appointments.ycbm_advising_appointments.cancellation_reason AS cancel_reason
             FROM boac_advising_appointments.ycbm_advising_appointments
             WHERE boac_advising_appointments.ycbm_advising_appointments.student_sid = '#{student.sis_id}'
             ORDER BY start_time ASC;"

    results = query_pg_db(NessieUtils.nessie_pg_db_credentials, query)
    appt_data = results.group_by { |h1| h1['id'] }.map do |k, v|
      advisor = BOACUser.new full_name: v[0]['advisor_name']
      cancel_reason = v[0]['cancel_reason'].to_s.strip
      cancel_reason = 'Canceled' if cancel_reason.empty?
      {
        id: k,
        type: v[0]['type'].to_s.strip,
        title: v[0]['title'].to_s.strip.gsub(/\s+/, ' '),
        detail: Nokogiri::HTML(v[0]['detail']).text.strip,
        student: student,
        advisor: advisor,
        created_date: Time.parse(v[0]['start_time'].to_s).utc.localtime,
        start_time: Time.parse(v[0]['start_time'].to_s).utc.localtime,
        end_time: Time.parse(v[0]['end_time'].to_s).utc.localtime,
        status: (AppointmentStatus::CANCELED if v[0]['cancelled'] == 't'),
        cancel_reason: cancel_reason,
        source: TimelineRecordSource::YCBM
      }
    end
    appt_data.map { |d| Appointment.new d }
  end

  def self.get_sids_with_ycbm_appts
    query = "SELECT DISTINCT student_sid
             FROM boac_advising_appointments.ycbm_advising_appointments
             WHERE student_uid IS NOT NULL"
    results = Utils.query_pg_db(NessieUtils.nessie_pg_db_credentials, query)
    results.map { |r| r['student_sid'] }
  end

  #### HOLDS ####

  # Returns a student's current holds
  # @param student [BOACUser]
  # @return [Array<Alert>]
  def self.get_student_holds(student)
    query = "SELECT sid, feed
              FROM student.student_holds
              WHERE sid = '#{student.sis_id}';"
    results = Utils.query_pg_db(NessieUtils.nessie_pg_db_credentials, query)
    results.map do |r|
      feed = JSON.parse r['feed']
      alert_data = {
        :message => "#{feed['reason']['description']}. #{feed['reason']['formalDescription']}".gsub("\n", '').gsub("\\u200b", '').gsub(/\s+/, ' '),
        :user => student
      }
      Alert.new alert_data
    end
  end

  #### eFORMS ####

  def self.get_e_form_notes(student)
    query = "SELECT id,
                    term_id,
                    section_id,
                    course_display_name,
                    course_title,
                    section_num,
                    created_at,
                    updated_at,
                    eform_id,
                    eform_status,
                    requested_action,
                    grading_basis_description,
                    requested_grading_basis_description,
                    units_taken,
                    requested_units_taken
    FROM sis_advising_notes.student_late_drop_eforms
    WHERE sid = '#{student.sis_id}'"
    results = query_pg_db(NessieUtils.nessie_pg_db_credentials, query)
    results.map do |r|
      req_action = r['requested_action']
      units = r['units_taken']
      req_units = r['requested_units_taken']
      action = case req_action
               when 'Late Grading Basis Change'
                 "#{req_action} from #{r['grading_basis_description']} to #{r['requested_grading_basis_description']}"
               when 'Unit Change'
                 "#{req_action} from #{units} unit#{+ 's' unless units == '1.0'} to #{req_units} unit#{+ 's' unless req_units == '1.0'}"
               else
                 req_action
               end
      status = r['eform_status']
      subject = "eForm: #{req_action} — #{status}"

      TimelineEForm.new id: r['id'],
                        source: TimelineRecordSource::E_FORM,
                        term: sis_code_to_term_name(r['term_id']),
                        course: "#{r['section_id']} #{r['course_display_name']} - #{r['course_title']} #{r['section_num']}",
                        created_date: Time.parse(r['created_at'].to_s).utc.localtime,
                        updated_date: Time.parse(r['updated_at'].to_s).utc.localtime,
                        subject: subject,
                        action: action,
                        form_id: r['eform_id'],
                        status: status,
                        units_taken: r['units_taken'],
                        requested_units_taken: r['requested_units_taken'],
                        grading_basis: r['grading_basis_description'],
                        requested_grading_basis: r['requested_grading_basis_description']
    end
  end

  def self.get_sids_with_e_forms
    query = "SELECT DISTINCT sid
             FROM sis_advising_notes.student_late_drop_eforms"
    results = Utils.query_pg_db(NessieUtils.nessie_pg_db_credentials, query)
    results.map { |r| r['sid'] }
  end

end
