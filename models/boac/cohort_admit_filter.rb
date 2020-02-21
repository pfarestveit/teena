class CohortAdmitFilter

  attr_accessor :college,
                :current_sir,
                :family_dependents,
                :family_single_parent,
                :fee_waiver,
                :first_gen_student,
                :foster_care,
                :freshman_or_transfer,
                :hispanic,
                :last_school_lcff_plus,
                :re_entry_status,
                :special_program_cep,
                :student_dependents,
                :student_single_parent,
                :urem,
                :xethnic

  # Sets cohort admit filters based on test data
  # @param test_data [Hash]
  def set_test_filters(test_data)
    @college = (test_data['colleges'].&map { |t| t['college'] })
    @current_sir = test_data['current_sir']
    @family_dependents = (test_data['family_dependents'].&map { |d| d['num'] })
    @family_single_parent = test_data['family_single_parent']
    @fee_waiver = test_data['fee_waiver']
    @first_gen_student = test_data['first_gen_student']
    @foster_care = test_data['foster_care']
    @freshman_or_transfer = (test_data['freshman_or_transfer'].&map { |f| f['fresh_or_trans'] })
    @hispanic = test_data['hispanic']
    @last_school_lcff_plus = test_data['last_school_lcff_plus']
    @re_entry_status = test_data['re_entry_status']
    @special_program_cep = test_data['special_program_cep']
    @student_dependents = (test_data['student_dependents'].&map { |d| d['num'] })
    @student_single_parent = test_data['student_single_parent']
    @urem = test_data['urem']
    @xethnic = test_data['xethnic']
  end

  # Returns the array of filter values
  # @return [Array<Object>]
  def list_filters
    instance_variables.map { |variable| instance_variable_get variable }
  end

end