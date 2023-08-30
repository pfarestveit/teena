class CohortFilter

  include Logging

  attr_accessor :academic_divisions,
                :academic_standing,
                :asc_inactive,
                :asc_intensive,
                :asc_team,
                :career_statuses,
                :coe_advisor,
                :coe_ethnicity,
                :coe_gender,
                :coe_inactive,
                :coe_prep,
                :coe_probation,
                :coe_underrepresented_minority,
                :cohort_owner_academic_plans,
                :college,
                :curated_groups,
                :degree_terms,
                :degrees_awarded,
                :entering_terms,
                :ethnicity,
                :expected_grad_terms,
                :gender,
                :gpa,
                :gpa_last_term,
                :grading_basis_epn,
                :graduate_plans,
                :holds,
                :incomplete_grade,
                :incomplete_sched_grade,
                :intended_major,
                :last_name,
                :level,
                :major,
                :mid_point_deficient,
                :minor,
                :transfer_student,
                :underrepresented_minority,
                :units_completed,
                :visa_type


  # Sets cohort filters based on test data
  # @param test_data [Hash]
  # @param dept [BOACDepartments]
  def set_test_filters(test_data, dept)
    # Global
    @academic_divisions = (test_data['academic_divs'] && test_data['academic_divs'].map { |a| a['academic_div'] })
    @academic_standing = (test_data['academic_standings'] && test_data['academic_standings'].map { |a| a['academic_standing'] })
    @career_statuses = (test_data['career_statuses']&.map { |c| c['career_status'] })
    @college = (test_data['colleges'] && test_data['colleges'].map { |t| t['college'] })
    @degrees_awarded = (test_data['degrees_awarded']&.map { |d| d['degree_awarded'] })
    @degree_terms = (test_data['degree_terms']&.map { |t| t['degree_term'] })
    @entering_terms = (test_data['entering_terms'] && test_data['entering_terms'].map { |t| t['entering_term'] })
    @expected_grad_terms = ([BOACUtils.previous_term_code(BOACUtils.term_code), BOACUtils.term_code] if test_data['expected_grad_terms'])
    @gpa = (test_data['gpa_ranges'] && test_data['gpa_ranges'].map { |g| g['gpa_range'] })
    @gpa_last_term = (test_data['gpa_ranges_last_term'] && test_data['gpa_ranges_last_term'].map { |g| g['gpa_range'] })
    @grading_basis_epn = (test_data['grading_basis_epn'] && test_data['grading_basis_epn'].map { |b| b['term'] })
    @graduate_plans = (test_data['graduate_plans']&.map { |p| p['graduate_plan'] })
    @holds = test_data['holds']
    @incomplete_grade = (test_data['incomplete_grades'] && test_data['incomplete_grades'].map { |i| i['grade'] })
    @incomplete_sched_grade = if test_data['incomplete_sched_grades']&.any?
                                [{"min" => Date.today.strftime('%Y-%m-%d'), "max" => (Date.today + 30).strftime('%Y-%m-%d')}]
                              end
    @intended_major = (test_data['intended_major'] && test_data['intended_major'].map { |m| m['major'] })
    @level = (test_data['levels'] && test_data['levels'].map { |l| l['level'] })
    @major = (test_data['majors'] && test_data['majors'].map { |t| t['major'] })
    @mid_point_deficient = test_data['mid_point_deficient']
    @minor = (test_data['minors'] && test_data['minors'].map { |t| t['minor'] })
    @transfer_student = test_data['transfer_student']
    @units_completed = (test_data['units'] && test_data['units'].map { |u| u['unit'] })

    @ethnicity = (test_data['ethnicities'] && test_data['ethnicities'].map { |e| e['ethnicity'] })
    @gender = (test_data['genders'] && test_data['genders'].map { |g| g['gender'] })
    @underrepresented_minority = test_data['underrepresented_minority']
    @visa_type = (test_data['visa_types'] && test_data['visa_types'].map { |v| v['visa_type'] })
    @last_name = (test_data['last_initials'] && test_data['last_initials'].map { |l| l['last_initial'] })

    # My Students
    @cohort_owner_academic_plans = (test_data['cohort_owner_academic_plans'] && test_data['cohort_owner_academic_plans'].map { |t| t['plan'] })

    # CoE
    @coe_advisor = (test_data['coe_advisors'] && test_data['coe_advisors'].map { |a| a['advisor'] })
    @coe_ethnicity = (test_data['coe_ethnicities'] && test_data['coe_ethnicities'].map { |e| e['ethnicity'] })
    @coe_gender = (test_data['coe_genders'] && test_data['coe_genders'].map { |g| g['gender'] })
    @coe_inactive = test_data['coe_inactive']
    @coe_prep = (test_data['coe_preps'] && test_data['coe_preps'].map { |p| p['prep'] })
    @coe_probation = test_data['coe_probation']
    @coe_underrepresented_minority = test_data['coe_underrepresented_minority']

    # ASC
    @asc_inactive = test_data['asc_inactive']
    @asc_intensive = test_data['asc_intensive']
    @asc_team = (test_data['asc_teams'] && test_data['asc_teams'].map { |t| Squad::SQUADS.find { |s| s.name == t['squad'] } })

    # Remove filters that are not available to the department
    unless [BOACDepartments::ADMIN, BOACDepartments::COE].include? dept
      @coe_advisor = nil
      @coe_ethnicity = nil
      @coe_gender = nil
      @coe_underrepresented_minority = nil
      @coe_prep = nil
      @coe_inactive = nil
      @coe_probation = nil
    end

    unless [BOACDepartments::ADMIN, BOACDepartments::ASC].include? dept
      @asc_inactive = nil
      @asc_intensive = nil
      @asc_team = nil
    end

    if @grading_basis_epn&.any?
      @grading_basis_epn = [BOACUtils.term_code.to_s]
    end
  end

  # Returns the array of filter values
  # @return [Array<Object>]
  def list_filters
    instance_variables.map { |variable| instance_variable_get variable }
  end

  def self.coe_gender_per_code(code)
    case code
      when 'F'
        'Female'
      when 'M'
        'Male'
      else
        logger.error "Unknown COE gender code '#{code}'"
        nil
    end
  end

  def self.level_per_code(code)
    case code
      when '10'
        'Freshman (0-29 Units)'
      when '20'
        'Sophomore (30-59 Units)'
      when '30'
        'Junior (60-89 Units)'
      when '40'
        'Senior (90+ Units)'
      when '5'
        'Masters and/or Professional'
      when  '6'
        'Doctoral Students Not Advance to Candidacy'
      when '7'
        'Doctoral Advanced to Candidacy <= 6 Terms'
      when '8'
        'Doctoral Advanced to Candidacy > 6 Terms'
      else
        logger.error "Unknown level code '#{code}'"
        nil
    end
  end

  # CoE ethnicity code translations
  # @param code [String]
  # @return [String]
  def self.coe_ethnicity_per_code(code)
    case code
      when 'A'
        'African-American / Black'
      when 'B'
        'Japanese / Japanese-American'
      when 'C'
        'American Indian / Alaska Native'
      when 'D'
        'Other'
      when 'E'
        'Mexican / Mexican-American / Chicano'
      when 'F'
        'White / Caucasian'
      when 'G'
        'Declined to state'
      when 'H'
        'Chinese / Chinese-American'
      when 'I'
        'Other Spanish-American / Latino'
      when 'L'
        'Filipino / Filipino-American'
      when 'M'
        'Pacific Islander'
      when 'P'
        'Puerto Rican'
      when 'R'
        'East Indian / Pakistani'
      when 'T'
        'Thai / Other Asian'
      when 'V'
        'Vietnamese'
      when 'X'
        'Korean / Korean-American'
      when 'Y'
        'Other Asian'
      else
        logger.warn "Unrecognized Ethnicity (COE): '#{code}'" if code && !code.empty? && code != 'Z'
    end
  end

  # Visa type translations
  # @param code [String]
  # @return [String]
  def self.visa_type_per_code(code)
    case code
      when 'F1'
        'F-1 International Student'
      when 'J1'
        'J-1 International Student'
      when 'PR'
        'Permanent Resident'
      else
        'Other'
    end
  end

  # Sets cohort filters without using the test data file
  # @param filters_hash [Hash]
  def set_custom_filters(filters_hash)
    filters_hash.each { |k, v| public_send("#{k}=", v) }
  end

end
