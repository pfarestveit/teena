class CohortFilter

  attr_accessor :levels,
                :majors,
                :gpa_ranges,
                :units,
                :squads,
                :inactive_asc,
                :intensive_asc,
                :advisor

  # Sets cohort filters based on test data
  # @param test_data [Hash]
  def set_test_filters(test_data, dept)
    @levels = (test_data['levels'] && test_data['levels'].map { |l| l['level'] })
    @majors = (test_data['majors'] && test_data['majors'].map { |t| t['major'] })
    @gpa_ranges = (test_data['gpa_ranges'] && test_data['gpa_ranges'].map { |g| g['gpa_range'] })
    @units = (test_data['units'] && test_data['units'].map { |u| u['unit'] })
    @squads = (test_data['teams'] && test_data['teams'].map { |t| Squad::SQUADS.find { |s| s.name == t['squad'] } })

    # Remove filters that are not available to the department
    case dept
      when BOACDepartments::ADMIN
        @squads = nil
      when BOACDepartments::ASC
        @advisor = nil
      when BOACDepartments::COE
        @squads = nil
        @inactive_asc = nil
        @intensive_asc = nil
      else
        logger.error "Invalid department '#{dept.name}'"
    end
  end

  # Sets cohort filters without using the test data file
  # @param filters_hash [Hash]
  def set_custom_filters(filters_hash)
    filters_hash.each { |k, v| public_send("#{k}=", v) }
  end

end
