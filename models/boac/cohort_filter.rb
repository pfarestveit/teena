class CohortFilter

  include Logging

  attr_accessor :gpa_ranges,
                :levels,
                :units,
                :majors,
                :advisors,
                :ethnicities,
                :genders,
                :preps,
                :inactive_asc,
                :intensive_asc,
                :squads

  # Sets cohort filters based on test data
  # @param test_data [Hash]
  # @param dept [BOACDepartments]
  def set_test_filters(test_data, dept)
    # Global
    @gpa_ranges = (test_data['gpa_ranges'] && test_data['gpa_ranges'].map { |g| g['gpa_range'] })
    @levels = (test_data['levels'] && test_data['levels'].map { |l| l['level'] })
    @units = (test_data['units'] && test_data['units'].map { |u| u['unit'] })
    @majors = (test_data['majors'] && test_data['majors'].map { |t| t['major'] })

    # CoE
    @advisors = (test_data['advisors'] && test_data['advisors'].map { |a| a['advisor'] })
    @ethnicities = (test_data['ethnicities'] && test_data['ethnicities'].map { |e| coe_ethnicity e['ethnicity'] })
    @genders = (test_data['genders'] && test_data['genders'].map { |g| g['gender'] })
    @preps = (test_data['preps'] && test_data['preps'].map { |p| p['prep'] })

    # ASC
    @inactive_asc = test_data['inactive_asc']
    @intensive_asc = test_data['intensive_asc']
    @squads = (test_data['teams'] && test_data['teams'].map { |t| Squad::SQUADS.find { |s| s.name == t['squad'] } })

    # Remove filters that are not available to the department
    if dept == BOACDepartments::ASC
      @advisors = nil
      @ethnicities = nil
      @genders = nil
      @preps = nil
    elsif dept == BOACDepartments::COE
      @inactive_asc = nil
      @intensive_asc = nil
      @squads = nil
    end
  end

  # Returns the array of filter values
  # @return [Array<Object>]
  def list_filters
    instance_variables.map { |variable| instance_variable_get variable }
  end

  # CoE ethnicity code translations
  # @param code [String]
  # @return [String]
  def coe_ethnicity(code)
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
      when 'Z'
        'Foreign'
      else
        logger.warn "Unrecognized ethnicity '#{code}'"
    end
  end

  # Sets cohort filters without using the test data file
  # @param filters_hash [Hash]
  def set_custom_filters(filters_hash)
    filters_hash.each { |k, v| public_send("#{k}=", v) }
  end

end
