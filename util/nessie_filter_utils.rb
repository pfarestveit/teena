require_relative 'spec_helper'

class NessieFilterUtils < NessieUtils

  ###################
  ### SELECT FROM ###
  ###################

  def self.select_from(sort=nil)
    if sort && (sort[:col] != 'first_name')
      select =  sort[:select] || "#{sort[:table]}.#{sort[:col]}"
    end
    "SELECT DISTINCT student.student_academic_status.sid,
                     LOWER(student.student_academic_status.last_name),
                     LOWER(student.student_academic_status.first_name)#{+ ', ' + select if select}
     FROM student.student_academic_status"
  end

  def self.previous_term_gpa_sub_query(term)
    "(SELECT student.student_term_gpas.gpa
      FROM student.student_term_gpas
      WHERE student.student_term_gpas.sid = student_academic_status.sid
        AND student.student_term_gpas.term_id = '#{term}'
        AND student.student_term_gpas.units_taken_for_gpa != '0.0') AS gpa_last_term"
  end

  def self.units_in_prog_sub_query
    "(SELECT student.student_enrollment_terms.enrolled_units
      FROM student.student_enrollment_terms
      WHERE student.student_enrollment_terms.sid = student_academic_status.sid
        AND student.student_enrollment_terms.term_id = '#{BOACUtils.term_code}') AS units_in_progress"
  end

  #############
  ### WHERE ###
  #############

  def self.in_op(arr)
    arr.map {|i| "'#{i}'"}.join(', ')
  end

  def self.college_cond(filter, conditions_list)
    conditions_list << "student.student_majors.college IN (#{in_op filter.college})" if filter.college&.any?
  end

  def self.entering_term_cond(filter, conditions_list)
    conditions_list << "student.student_academic_status.entering_term IN (#{in_op filter.entering_terms})" if filter.entering_terms&.any?
  end

  def self.expected_grad_term_cond(filter, conditions_list)
    conditions_list << "student.student_academic_status.expected_grad_term IN (#{in_op filter.expected_grad_terms})" if filter.expected_grad_terms&.any?
  end

  def self.gpa_cond(filter, conditions_list)
    if filter.gpa&.any?
      ranges = filter.gpa.map { |range| "(student.student_academic_status.gpa BETWEEN #{range['min']} AND #{range['max']})" }
      conditions_list << "(#{ranges.join(' OR ')})"
    end
  end

  def self.gpa_last_term_cond(filter, conditions_list)
    if filter.gpa_last_term&.any?
      ranges = filter.gpa_last_term.map do |range|
        "(student.student_term_gpas.gpa BETWEEN #{range['min']} AND #{range['max']})"
      end
      cond = "student.student_term_gpas.term_id = '#{BOACUtils.previous_term_code}'
           AND student.student_term_gpas.units_taken_for_gpa != '0.0'
           AND (#{ranges.join(' OR ')})"
      conditions_list << cond
    end
  end

  def self.intended_major_cond(filter, conditions_list)
    conditions_list << "student.intended_majors.major IN (#{in_op filter.intended_major})" if filter.intended_major&.any?
  end

  def self.level_cond(filter, conditions_list)
    conditions_list << "student.student_academic_status.level IN (#{in_op filter.level})" if filter.level&.any?
  end

  def self.major_cond(filter, conditions_list)
    conditions_list << "student.student_majors.major IN (#{in_op filter.major})" if filter.major&.any?
  end

  def self.minor_cond(filter, conditions_list)
    conditions_list << "student.minors.minor IN (#{in_op filter.minor})" if filter.minor&.any?
  end

  def self.midpoint_deficient_cond(filter, conditions_list)
    conditions_list << "student.student_enrollment_terms.midpoint_deficient_grade IS TRUE
                    AND student.student_enrollment_terms.term_id = '#{BOACUtils.term_code}'" if filter.mid_point_deficient
  end

  def self.transfer_cond(filter, conditions_list)
    conditions_list << "student.student_academic_status.transfer IS TRUE" if filter.transfer_student
  end

  def self.units_completed_cond(filter, conditions_list)
    if filter.units_completed&.any?
      ranges = filter.units_completed.map do |range|
        if range.include? '+'
          "student.student_academic_status.units >= 120"
        else
          range = range.split('-').strip
          "(student.student_academic_status.units BETWEEN #{range[0]} AND #{range[1]})"
        end
      end
      conditions_list << "(#{ranges.join(' OR ')})"
    end
  end

  def self.ethnicity_cond(filter, conditions_list)
    conditions_list << "student.ethnicities.ethnicity IN (#{in_op filter.ethnicity})" if filter.ethnicity&.any?
  end

  def self.gender_cond(filter, conditions_list)
    conditions_list << "student.demographics.gender IN (#{in_op filter.gender})" if filter.gender&.any?
  end

  def self.minority_cond(filter, conditions_list)
    conditions_list << 'student.demographics.minority IS TRUE' if filter.underrepresented_minority
  end

  def self.visa_cond(filter, conditions_list)
    if filter.visa_type&.any?
      conditions_list << "student.visas.visa_status = 'G'"
      if filter.visa_type.include? 'All types'
        conditions_list << "student.visas.visa_type IS NOT NULL"
      else
        visa_conditions = []
        filter.visa_type.each do |type|
          if type == 'Other'
            visa_conditions << "student.visas.visa_type NOT IN ('F1', 'J1', 'PR')"
          else
            visa_conditions << "student.visas.visa_type = '#{type}'"
          end
        end
        visa_conditions = visa_conditions.join(" \nOR ")
        conditions_list << "(#{visa_conditions})" unless visa_conditions.empty?
      end
    end
  end

  def self.last_name_cond(filter, conditions_list)
    if filter.last_name&.any?
      ranges = filter.last_name.map do |range|
        if range['min'] == range['max']
          "LOWER(student.student_academic_status.last_name) LIKE '#{range['min']}'%"
        else
          "LOWER(student.student_academic_status.last_name) BETWEEN '#{range['min']}' AND '#{range['max']}zz'"
        end
      end
      conditions_list << "(#{ranges.join(' OR ')})"
    end
  end

  def self.my_students_cond(filter, conditions_list, test)
    if filter.cohort_owner_academic_plans&.any?
      conditions_list << "boac_advisor.advisor_students.advisor_sid = #{test.advisor.sis_id}"
      unless filter.cohort_owner_academic_plans.include? 'All'
        conditions_list << "boac_advisor.advisor_students.academic_plan_code IN (#{in_op filter.cohort_owner_academic_plans.join(', ')})"
      end
    end
  end

  def self.asc_cond(filter, conditions_list)
    conditions_list << 'boac_advising_asc.students.active IS FALSE' if filter.asc_inactive
    conditions_list << 'boac_advising_asc.students.intensive IS TRUE' if filter.asc_intensive
    conditions_list << "boac_advising_asc.students.group_code IN (#{in_op filter.asc_team.map(&:code)})" if filter.asc_team&.any?
  end

  def self.coe_cond(filter, conditions_list)
    conditions_list << "boac_advising_coe.students.advisor_ldap_uid IN (#{in_op filter.coe_advisor})" if filter.coe_advisor&.any?
    conditions_list << "boac_advising_coe.students.ethnicity IN (#{in_op filter.coe_ethnicity})" if filter.coe_ethnicity&.any?
    conditions_list << "boac_advising_coe.students.gender IN (#{in_op filter.coe_gender})" if filter.coe_gender&.any?
    conditions_list << "boac_advising_coe.students.status IN ('D', 'P', 'U', 'W', 'X', 'Z')" if filter.coe_inactive
    conditions_list << "boac_advising_coe.students.probation IS TRUE" if filter.coe_probation
    conditions_list << "boac_advising_coe.students.minority IS TRUE" if filter.coe_underrepresented_minority
    prep_conditions = []
    prep_conditions << "boac_advising_coe.students.did_prep IS TRUE" if filter.coe_prep&.include? 'PREP'
    prep_conditions << "boac_advising_coe.students.prep_eligible IS TRUE" if filter.coe_prep&.include? 'PREP eligible'
    prep_conditions << "boac_advising_coe.students.did_tprep IS TRUE" if filter.coe_prep&.include? 'T-PREP'
    prep_conditions << "boac_advising_coe.students.tprep_eligible IS TRUE" if filter.coe_prep&.include? 'T-PREP eligible'
    prep_conditions = prep_conditions.join(" \nOR ")
    conditions_list << "(#{prep_conditions})" unless prep_conditions.empty?
  end

  def self.where(test, filter)
    clause = 'WHERE '
    conditions_list = []

    # GLOBAL FILTERS
    college_cond(filter, conditions_list)
    entering_term_cond(filter, conditions_list)
    expected_grad_term_cond(filter, conditions_list)
    gpa_cond(filter, conditions_list)
    gpa_last_term_cond(filter, conditions_list)
    intended_major_cond(filter, conditions_list)
    last_name_cond(filter, conditions_list)
    level_cond(filter, conditions_list)
    major_cond(filter, conditions_list)
    minor_cond(filter, conditions_list)
    midpoint_deficient_cond(filter, conditions_list)
    transfer_cond(filter, conditions_list)
    units_completed_cond(filter, conditions_list)
    ethnicity_cond(filter, conditions_list)
    gender_cond(filter, conditions_list)
    minority_cond(filter, conditions_list)
    visa_cond(filter, conditions_list)
    my_students_cond(filter, conditions_list, test)

    # ASC
    asc_cond(filter, conditions_list)

    # CoE
    coe_cond(filter, conditions_list)

    conditions_list.compact!
    conditions_list = conditions_list.join(" \nAND ")
    clause << conditions_list
  end

  ############
  ### JOIN ###
  ############

  def self.filter_join_clauses(filter)
    joins = []
    sid = 'student.student_academic_status.sid'

    major_join = "LEFT JOIN student.student_majors ON #{sid} = student.student_majors.sid"
    joins << major_join if (filter.college&.any? || filter.major&.any?)

    intended_major_join = "LEFT JOIN student.intended_majors ON #{sid} = student.intended_majors.sid"
    joins << intended_major_join if filter.intended_major&.any?

    minor_join = "LEFT JOIN student.minors ON #{sid} = student.minors.sid"
    joins << minor_join if filter.minor&.any?

    visa_join = "LEFT JOIN student.visas ON #{sid} = student.visas.sid"
    joins << visa_join if filter.visa_type

    ethnicity_join = "LEFT JOIN student.ethnicities ON #{sid} = student.ethnicities.sid"
    joins << ethnicity_join if filter.ethnicity&.any?

    demographics_join = "LEFT JOIN student.demographics ON #{sid} = student.demographics.sid"
    joins << demographics_join if (filter.gender&.any? || filter.underrepresented_minority)

    advisor_student_join = "LEFT JOIN boac_advisor.advisor_students ON #{sid} = boac_advisor.advisor_students.student_sid"
    joins << advisor_student_join if filter.cohort_owner_academic_plans&.any?

    enroll_term_join = "LEFT JOIN student.student_enrollment_terms
                          ON #{sid} = student.student_enrollment_terms.sid
                          AND student.student_enrollment_terms.term_id = '#{BOACUtils.term_code}'"
    joins << enroll_term_join if filter.mid_point_deficient

    term_gpa_join = "LEFT JOIN student.student_term_gpas ON #{sid} = student.student_term_gpas.sid"
    joins << term_gpa_join if filter.gpa_last_term&.any?

    asc_join = "LEFT JOIN boac_advising_asc.students ON #{sid} = boac_advising_asc.students.sid"
    joins << asc_join if (filter.asc_inactive || filter.asc_intensive || filter.asc_team&.any?)

    coe_join = "LEFT JOIN boac_advising_coe.students ON #{sid} = boac_advising_coe.students.sid"
    if filter.coe_advisor&.any? || filter.coe_ethnicity&.any? || filter.coe_gender&.any? || filter.coe_inactive ||
        filter.coe_prep&.include?('PREP') || filter.coe_prep&.include?('PREP eligible') || filter.coe_prep&.include?('T-PREP') ||
        filter.coe_prep&.include?('T-PREP eligible') || filter.coe_probation || filter.coe_underrepresented_minority
      joins << coe_join
    end

    joins.uniq.compact.join(" \n")
  end

  def self.join(filter_joins, sort=nil)
    unless sort && sort[:table] == 'student.student_academic_status'
      filter_joins << " LEFT JOIN #{sort[:table]} ON student.student_academic_status.sid = #{sort[:table]}.sid" if sort
    end
    filter_joins
  end

  ################
  ### GROUP BY ###
  ################

  def self.group_by(sort=nil)
    if sort && (sort[:col] != 'first_name')
      group_by = "#{sort[:table]}.#{sort[:col]}" if sort[:group_by]
    end
    "GROUP BY student.student_academic_status.sid,
             student.student_academic_status.last_name,
             student.student_academic_status.first_name#{ + ', ' + group_by if group_by}"
  end

  ################
  ### ORDER BY ###
  ################

  def self.default_sort
    'LOWER(student.student_academic_status.last_name),
     LOWER(student.student_academic_status.first_name),
     student.student_academic_status.sid ASC'
  end

  def self.order_by(sort)
    if sort
      if sort[:col] == 'first_name'
        'ORDER BY LOWER(student.student_academic_status.first_name),
                  LOWER(student.student_academic_status.last_name),
                  student.student_academic_status.sid'
      elsif sort[:order_by]
        "ORDER BY #{sort[:order_by]}#{sort[:direction]}#{sort[:nulls]},
                  #{default_sort}"
      else
        "ORDER BY #{sort[:table]}.#{sort[:col]}#{sort[:direction]}#{sort[:nulls]},
                  #{default_sort}"
      end
    else
      "ORDER BY #{default_sort}"
    end
  end

  ##################################
  ### QUERIES - COHORT LIST VIEW ###
  ##################################

  # @param filter [CohortFilter]
  def self.get_cohort_result(test, filter, sort=nil)
    sql = "#{select_from sort}
           #{join(filter_join_clauses(filter), sort)}
           #{where(test, filter)}
           #{group_by sort}
           #{order_by sort};"
    result = NessieUtils.query_pg_db(NessieUtils.nessie_pg_db_credentials, sql)
    result.map { |r| r['sid'] }
  end

  # Last Name

  def self.cohort_by_last_name(test, filter)
    get_cohort_result(test, filter)
  end

  # First name

  def self.cohort_by_first_name(test, filter)
    sort = {
        table: 'student.student_academic_status',
        col: 'first_name'
    }
    get_cohort_result(test, filter, sort)
  end

  # Level

  def self.cohort_by_level(test, filter)
    sort = {
        table: 'student.student_academic_status',
        col: 'level',
        group_by: true
    }
    get_cohort_result(test, filter, sort)
  end

  # Major

  def self.cohort_by_major(test, filter)
    sort = {
        table: 'student.student_majors',
        col: 'major',
        nulls: ' NULLS FIRST',
        select: '(ARRAY_AGG(student.student_majors.major))[1] AS major',
        order_by: 'major',
        group_by: false
    }
    get_cohort_result(test, filter, sort)
  end

  # Entering term

  def self.cohort_by_matriculation(test, filter)
    sort = {
        table: 'student.student_academic_status',
        col: 'entering_term',
        nulls: ' NULLS LAST',
        group_by: true
    }
    get_cohort_result(test, filter, sort)
  end

  # Team

  def self.cohort_by_team(test, filter)
    sort = {
        table: 'boac_advising_asc.students',
        col: 'team_name',
        nulls: ' NULLS LAST',
        select: '(ARRAY_AGG (boac_advising_asc.students.team_name))[1] AS team',
        order_by: 'team',
        group_by: false
    }
    get_cohort_result(test, filter, sort)
  end

  # GPA - cumulative

  def self.cohort_by_gpa_sort
    {
        table: 'student.student_academic_status',
        col: 'gpa',
        group_by: true
    }
  end

  def self.cohort_by_gpa_asc(test, filter)
    sort = cohort_by_gpa_sort.merge!({direction: ' ASC', nulls: ' NULLS FIRST'})
    get_cohort_result(test, filter, sort)
  end

  def self.cohort_by_gpa_desc(test, filter)
    sort = cohort_by_gpa_sort.merge!({direction: ' DESC', nulls: ' NULLS LAST'})
    get_cohort_result(test, filter, sort)
  end

  # GPA - previous term

  def self.cohort_by_prev_term_gpa_sort(term)
    {
        table: 'student.student_term_gpas',
        col: 'gpa',
        nulls: ' NULLS LAST',
        select: previous_term_gpa_sub_query(term),
        term_id: term,
        group_by: true
    }
  end

  def self.cohort_by_gpa_last_term_asc(test, filter)
    term = BOACUtils.previous_term_code
    sort = cohort_by_prev_term_gpa_sort(term).merge!({direction: ' ASC', order_by: 'gpa_last_term'})
    get_cohort_result(test, filter, sort)
  end

  def self.cohort_by_gpa_last_term_desc(test, filter)
    term = BOACUtils.previous_term_code
    sort = cohort_by_prev_term_gpa_sort(term).merge!({direction: ' DESC', order_by: 'gpa_last_term'})
    get_cohort_result(test, filter, sort)
  end

  def self.cohort_by_gpa_last_last_term_asc(test, filter)
    term = BOACUtils.previous_term_code BOACUtils.previous_term_code
    sort = cohort_by_prev_term_gpa_sort(term).merge!({direction: ' ASC', order_by: 'gpa_last_term'})
    get_cohort_result(test, filter, sort)
  end

  def self.cohort_by_gpa_last_last_term_desc(test, filter)
    term = BOACUtils.previous_term_code BOACUtils.previous_term_code
    sort = cohort_by_prev_term_gpa_sort(term).merge!({direction: ' DESC', order_by: 'gpa_last_term'})
    get_cohort_result(test, filter, sort)
  end

  # Terms in attendance

  def self.cohort_by_terms_in_attend_sort
    {
        table: 'student.student_academic_status',
        col: 'terms_in_attendance',
        nulls: ' NULLS LAST',
        group_by: true
    }
  end

  def self.cohort_by_terms_in_attend_asc(test, filter)
    sort = cohort_by_terms_in_attend_sort.merge!({direction: ' ASC'})
    get_cohort_result(test, filter, sort)
  end

  def self.cohort_by_terms_in_attend_desc(test, filter)
    sort = cohort_by_terms_in_attend_sort.merge!({direction: ' DESC'})
    get_cohort_result(test, filter, sort)
  end

  # Units in progress

  def self.cohort_by_units_in_prog_sort
    {
        table: 'student.student_enrollment_terms',
        col: 'enrolled_units',
        nulls: ' NULLS FIRST',
        select: units_in_prog_sub_query,
        term_id: BOACUtils.term_code,
        order_by: 'units_in_progress',
        group_by: true
    }
  end

  def self.cohort_by_units_in_prog_asc(test, filter)
    sort = cohort_by_units_in_prog_sort.merge!({direction: ' ASC'})
    get_cohort_result(test, filter, sort)
  end

  def self.cohort_by_units_in_prog_desc(test, filter)
    sort = cohort_by_units_in_prog_sort.merge!({direction: ' DESC'})
    get_cohort_result(test, filter, sort)
  end

  # Units complete

  def self.cohort_by_units_complete_sort
    {
        table: 'student.student_academic_status',
        col: 'units',
        group_by: true
    }
  end

  def self.cohort_by_units_complete_asc(test, filter)
    sort = cohort_by_units_complete_sort.merge!({direction: ' ASC', nulls: ' NULLS FIRST'})
    get_cohort_result(test, filter, sort)
  end

  def self.cohort_by_units_complete_desc(test, filter)
    sort = cohort_by_units_complete_sort.merge!({direction: ' DESC', nulls: ' NULLS LAST'})
    get_cohort_result(test, filter, sort)
  end

  ############################
  ### QUERIES - USER LISTS ###
  ############################

  def self.order_by_list(sort)
    if sort
      if sort[:col] == 'last_name'
        "ORDER BY LOWER(student.student_academic_status.last_name)#{sort[:direction]}#{sort[:nulls]},
                  LOWER(student.student_academic_status.first_name),
                  student.student_academic_status.sid"
      elsif sort[:order_by]
        "ORDER BY #{sort[:order_by]}#{sort[:direction]}#{sort[:nulls]},
                  #{default_sort}"
      else
        "ORDER BY #{sort[:table]}.#{sort[:col]}#{sort[:direction]}#{sort[:nulls]},
                  #{default_sort}"
      end
    else
      "ORDER BY #{default_sort}"
    end
  end

  def self.get_list_result(sids, sort=nil)
    sid_list = sids.map {|i| "'#{i}'"}.join(', ')
    sql = "#{select_from sort}
           #{join('', sort)}
           WHERE student.student_academic_status.sid IN (#{sid_list})
           #{group_by sort}
           #{order_by_list sort}"
    result = NessieUtils.query_pg_db(NessieUtils.nessie_pg_db_credentials, sql)
    result.map { |r| r['sid'] }
  end

  # Last name

  def self.list_by_last_name_asc(sids)
    get_list_result sids
  end

  def self.list_by_last_name_desc(sids)
    sort = {
        table: 'student.student_academic_status',
        col: 'last_name',
        direction: ' DESC'
    }
    get_list_result(sids, sort)
  end

  # Major

  def self.list_by_major_sort
    {
        table: 'student.student_majors',
        col: 'major',
        select: '(ARRAY_AGG(student.student_majors.major))[1] AS major',
        order_by: 'major',
        group_by: true
    }
  end

  def self.list_by_major_asc(sids)
    sort = list_by_major_sort.merge!({nulls: ' NULLS FIRST',direction: ' ASC'})
    get_list_result(sids, sort)
  end

  def self.list_by_major_desc(sids)
    sort = list_by_major_sort.merge!({nulls: ' NULLS LAST',direction: ' DESC'})
    get_list_result(sids, sort)
  end

  # Grad term

  def self.list_by_grad_term_sort
    {
        table: 'student.student_academic_status',
        col: 'expected_grad_term',
        nulls: ' NULLS FIRST',
        select: 'student.student_academic_status.expected_grad_term AS term',
        order_by: 'term',
        group_by: true
    }
  end

  def self.list_by_grad_term_asc(sids)
    sort = list_by_grad_term_sort.merge!({direction: ' ASC'})
    get_list_result(sids, sort)
  end

  def self.list_by_grad_term_desc(sids)
    sort = list_by_grad_term_sort.merge!({direction: ' DESC'})
    get_list_result(sids, sort)
  end

  # GPA

  def self.list_by_gpa_sort
    {
        table: 'student.student_academic_status',
        col: 'gpa',
        nulls: ' NULLS FIRST',
        group_by: true
    }
  end

  def self.list_by_gpa_asc(sids)
    sort = list_by_gpa_sort.merge!({direction: ' ASC'})
    get_list_result(sids, sort)
  end

  def self.list_by_gpa_desc(sids)
    sort = list_by_gpa_sort.merge!({direction: ' DESC'})
    get_list_result(sids, sort)
  end

  # Units in progress

  def self.list_by_units_in_prog_sort
    {
        table: 'student.student_enrollment_terms',
        col: 'enrolled_units',
        nulls: ' NULLS FIRST',
        select: units_in_prog_sub_query,
        term_id: BOACUtils.term_code,
        order_by: 'units_in_progress',
        group_by: true
    }
  end

  def self.list_by_units_in_prog_asc(sids)
    sort = list_by_units_in_prog_sort.merge!({direction: ' ASC'})
    get_list_result(sids, sort)
  end

  def self.list_by_units_in_prog_desc(sids)
    sort = list_by_units_in_prog_sort.merge!({direction: ' DESC'})
    get_list_result(sids, sort)
  end

  # Units complete

  def self.list_by_units_complete_sort
    {
        table: 'student.student_academic_status',
        col: 'units',
        nulls: ' NULLS FIRST',
        group_by: true
    }
  end

  def self.list_by_units_complete_asc(sids)
    sort = list_by_units_complete_sort.merge!({direction: ' ASC'})
    get_list_result(sids, sort)
  end

  def self.list_by_units_complete_desc(sids)
    sort = list_by_units_complete_sort.merge!({direction: ' DESC'})
    get_list_result(sids, sort)
  end

end
