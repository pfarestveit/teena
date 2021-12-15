require_relative '../../util/spec_helper'

module BOACFilteredStudentsPageResults

  include PageObject
  include Logging
  include Page

  # Waits for a search to complete and returns the count of results.
  # @return [Integer]
  def wait_for_search_results
    wait_for_spinner
    results_count
  end

  ### ADMIT FILTERS

  # Returns the admits that match a Freshman or Transfer filter
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_fresh_or_trans_admits(test, search_criteria)
    students = []
    search_criteria.freshman_or_transfer.each do |matric|
      if matric == 'Freshman'
        students << test.searchable_data.select { |u| u[:freshman_or_transfer] == 'Freshman' }
      else
        students << test.searchable_data.select { |u| u[:freshman_or_transfer] == 'Transfer' }
      end
    end
    students.flatten
  end

  # Returns the admits that match a Current SIR filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_sir_admits(test)
    test.searchable_data.select { |u| u[:current_sir] == 'Yes' }
  end

  # Returns the admits that match a College filter
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_college_admits(test, search_criteria)
    students = []
    search_criteria.college.each do |college|
      students << test.searchable_data.select { |u| u[:college] == college }
    end
    students.flatten
  end

  # Returns the admits that match an XEthnic filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_xethnic_admits(test, search_criteria)
    students = []
    search_criteria.xethnic.each do |ethnic|
      students << test.searchable_data.select { |u| u[:xethnic] == ethnic }
    end
    students.flatten
  end

  # Returns the admits that match a Hispanic filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_hispanic_admits(test)
    test.searchable_data.select { |u| u[:hispanic] == 'T' }
  end

  # Returns the admits that match a UREM filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_urem_admits(test)
    test.searchable_data.select { |u| u[:urem] == 'Yes' }
  end

  # Returns the admits that match a First Generation College filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_first_gen_admits(test)
    test.searchable_data.select { |u| u[:first_gen_college] == 'Yes' }
  end

  # Returns the admits that match an Application Fee Waiver filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_fee_waiver_admits(test)
    test.searchable_data.select { |u| u[:fee_waiver] == 'Fee' }
  end

  def matching_residency_admits(test, search_criteria)
    students = []
    search_criteria.residency.each do |cat|
      students << test.searchable_data.select { |u| u[:intl] == cat }
    end
    students.flatten
  end

  # Returns the admits that match a Foster Care filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_foster_care_admits(test)
    test.searchable_data.select { |u| u[:foster_care] == 'Y' }
  end

  # Returns the admits that match a Family Single Parent filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_fam_single_parent_admits(test)
    test.searchable_data.select { |u| u[:family_single_parent] == 'Y' }
  end

  # Returns the admits that match a Student Single Parent filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_stu_single_parent_admits(test)
    test.searchable_data.select { |u| u[:student_single_parent] == 'Y' }
  end

  # Returns the admits that match a Family Dependents filter
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_family_depends_admits(test, search_criteria)
    students = []
    search_criteria.family_dependents.each do |depends|
      min = depends['min'].to_i
      max = depends['max'].to_i
      students << test.searchable_data.select do |u|
        num = u[:family_dependents] ? u[:family_dependents].to_i : 0
        num >= min && num <= max
      end
    end
    students.flatten
  end

  # Returns the admits that match a Student Dependents filter
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_student_depends_admits(test, search_criteria)
    students = []
    search_criteria.student_dependents.each do |depends|
      min = depends['min'].to_i
      max = depends['max'].to_i
      students << test.searchable_data.select do |u|
        num = u[:student_dependents] ? u[:student_dependents].to_i : 0
        num >= min && num <= max
      end
    end
    students.flatten
  end

  # Returns the admits that match a Re-entry Status filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_re_entry_admits(test)
    test.searchable_data.select { |u| u[:re_entry_status] == 'Yes' }
  end

  # Returns the admits that match a Last School LCFF+ filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_lcff_plus_admits(test)
    test.searchable_data.select { |u| u[:last_school_lcff_plus_flag] && u[:last_school_lcff_plus_flag] == '1' }
  end

  # Returns the admits that match a Special Program CEP filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_special_pgm_cep_admits(test, search_criteria)
    students = []
    search_criteria.special_program_cep.each do |prog|
      students << test.searchable_data.select { |u| u[:special_program_cep] == prog }
    end
    students.flatten
  end

  ### EXPECTED RESULTS

  # Filters an array of user data hashes according to search criteria and returns the admits that should be present in the UI after
  # the search completes
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def expected_admit_search_results(test, search_criteria)
    matches = []
    matches << matching_fresh_or_trans_admits(test, search_criteria) if search_criteria.freshman_or_transfer&.any?
    matches << matching_sir_admits(test) if search_criteria.current_sir
    matches << matching_college_admits(test, search_criteria) if search_criteria.college&.any?
    matches << matching_xethnic_admits(test, search_criteria) if search_criteria.xethnic
    matches << matching_hispanic_admits(test) if search_criteria.hispanic
    matches << matching_urem_admits(test) if search_criteria.urem
    matches << matching_first_gen_admits(test) if search_criteria.first_gen_college
    matches << matching_fee_waiver_admits(test) if search_criteria.fee_waiver
    matches << matching_residency_admits(test, search_criteria) if search_criteria.residency&.any?
    matches << matching_foster_care_admits(test) if search_criteria.foster_care
    matches << matching_fam_single_parent_admits(test) if search_criteria.family_single_parent
    matches << matching_stu_single_parent_admits(test) if search_criteria.student_single_parent
    matches << matching_family_depends_admits(test, search_criteria) if search_criteria.family_dependents&.any?
    matches << matching_student_depends_admits(test, search_criteria) if search_criteria.student_dependents&.any?
    matches << matching_re_entry_admits(test) if search_criteria.re_entry_status
    matches << matching_lcff_plus_admits(test) if search_criteria.last_school_lcff_plus
    matches << matching_special_pgm_cep_admits(test, search_criteria) if search_criteria.special_program_cep&.any?
    matches.any?(&:empty?) ? [] : matches.inject(:'&')
  end

  # Sets a cohort's membership based on expected results, rather than actual results
  # @param cohort [FilteredCohort]
  # @param test [BOACTestConfig]
  # @return [Array<BOACUser>]
  def set_cohort_members(cohort, test)
    expected_sids = NessieFilterUtils.cohort_by_last_name(test, cohort.search_criteria)
    cohort.members = test.students.select { |u| expected_sids.include? u.sis_id }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by first name
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_first_name(expected_results)
    sorted_results = expected_results.sort_by { |u| [u[:first_name_sortable_cohort].downcase, u[:last_name_sortable_cohort].downcase, u[:sid]] }
    sorted_results.map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by last name
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_last_name(expected_results)
    sorted_results = expected_results.sort_by { |u| [u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]] }
    sorted_results.map { |u| u[:sid] }
  end

end
