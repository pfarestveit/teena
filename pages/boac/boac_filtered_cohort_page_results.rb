require_relative '../../util/spec_helper'

module BOACFilteredCohortPageResults

  include PageObject
  include Logging
  include Page

  # Waits for a search to complete and returns the count of results.
  # @return [Integer]
  def wait_for_search_results
    wait_for_spinner
    results_count
  end

  ### GLOBAL FILTERS

  # Returns the student hashes that match a set of college filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_college_students(test, search_criteria)
    students = []
    students << test.searchable_data.select { |u| (u[:college] & search_criteria.college).any? }
    students.uniq.flatten.compact
  end

  # Returns the student hashes that match a set of entering term filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_entering_term_students(test, search_criteria)
    test.searchable_data.select do |u|
      search_criteria.entering_terms.find { |search_term| search_term == u[:entering_term] }
    end
  end

  # Returns the student hashes that match a set of expected graduation term filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_grad_term_students(test, search_criteria)
    test.searchable_data.select do |u|
      search_criteria.expected_grad_terms.find { |search_term| search_term == u[:expected_grad_term] }
    end
  end

  # Returns the student hashes that match a set of GPA filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_gpa_students(test, search_criteria)
    students = []
    search_criteria.gpa.each do |range|
      low_end = range['min']
      high_end = range['max']
      students << test.searchable_data.select do |u|
        if u[:gpa]
          gpa = u[:gpa].to_f
          gpa >= low_end.to_f && gpa <= high_end.to_f
        end
      end
    end
    students.flatten
  end

  # Returns the student hashes that match a set of term-specific GPA filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_gpa_last_term_students(test, search_criteria)
    students = []
    search_criteria.gpa_last_term.each do |range|
      low_end = range['min']
      high_end = range['max']
      students << test.searchable_data.select do |u|
        if u[:gpa_last_term]
          term_gpa = u[:gpa_last_term].to_f
          term_gpa >= low_end.to_f && term_gpa <= high_end.to_f
        end
      end
    end
    students.flatten
  end

  # Returns the student hashes that match a set of level filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_level_students(test, search_criteria)
    test.searchable_data.select do |u|
      search_criteria.level.find { |search_level| search_level.include? u[:level] } if u[:level]
    end
  end

  # Returns the student hashes that match a set of major filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_major_students(test, search_criteria)
    students = []
    students << test.searchable_data.select { |u| (u[:major] & search_criteria.major).any? }
    students.uniq.flatten.compact
  end

  # Returns the student hashes that match a midpoint deficient grade filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_mid_point_students(test)
    test.searchable_data.select { |u| u[:mid_point_deficient] }
  end

  # Returns the student hashes that match a transfer student filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_transfer_students(test)
    test.searchable_data.select { |u| u[:transfer_student] }
  end

  # Returns the student hashes that match a set of units filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_units_students(test, search_criteria)
    students = []
    search_criteria.units_completed.each do |units|
      if units.include?('+')
        students << test.searchable_data.select { |u| u[:units_completed].to_f >= 120 if u[:units_completed] }
      else
        range = units.split(' - ')
        low_end = range[0].to_f
        high_end = range[1].to_f
        students << test.searchable_data.select { |u| (u[:units_completed].to_f >= low_end) && (u[:units_completed].to_f < high_end.round(-1)) }
      end
    end
    students.flatten
  end

  # Returns the student hashes that match a last name range filter
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_last_name_students(test, search_criteria)
    students = []
    search_criteria.last_name.each do |range|
      low_end = range['min'].downcase
      high_end = range['max'].downcase
      students << test.searchable_data.select do |u|
        u[:last_name_sortable_cohort][0] >= low_end && u[:last_name_sortable_cohort][0] <= high_end unless u[:last_name_sortable_cohort].empty?
      end
    end
    students.flatten
  end

  # Returns the student hashes that match a set of ethnicity filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_ethnicity_students(test, search_criteria)
    students = []
    students << test.searchable_data.select { |u| (u[:ethnicity] & search_criteria.ethnicity).any? if u[:ethnicity] }
    students.uniq.flatten.compact
  end

  # Returns the student hashes that match a set of gender filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_gender_students(test, search_criteria)
    students = []
    students << test.searchable_data.select { |u| search_criteria.gender.include? u[:gender] }
    students.flatten
  end

  # Returns the student hashes that match an underrepresented minority filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_minority_students(test)
    test.searchable_data.select { |u| u[:underrepresented_minority] }
  end

  # Returns the student hashes that match a visa type filter
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_visa_type_students(test, search_criteria)
    students = []
    search_criteria.visa_type.each do |visa|
      if visa == 'All types'
        students << test.searchable_data.select { |u| u[:visa_type] }
      else
        students << test.searchable_data.select { |u| search_criteria.visa_type_per_code(u[:visa_type]) == visa }
      end
    end
    students.flatten
  end

  # Returns the student hashes that match a set of academic plan filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_acad_plan_students(test, search_criteria)
    test.searchable_data.select do |u|
      u[:advisors].find do |a|
        a[:sid] == @advisor.sis_id && (search_criteria.cohort_owner_academic_plans.include?(a['plan_code']) || search_criteria.cohort_owner_academic_plans.include?('*'))
      end
    end
  end

  ### ASC-SPECIFIC FILTERS

  # Returns the student hashes that match an ASC inactive filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_asc_inactive_students(test)
    test.searchable_data.reject { |u| u[:asc_active] }
  end

  # Returns the student hashes that match an ASC intensive filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_asc_intensive_students(test)
    test.searchable_data.select { |u| u[:asc_intensive] }
  end

  # Returns the student hashes that match a set of ASC team filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_asc_team_students(test, search_criteria)
    test.searchable_data.select { |u| (u[:asc_sports] & (search_criteria.asc_team.map &:name)).any? }
  end

  # COE-SPECIFIC FILTERS

  # Returns the student hashes that match a set of COE advisor filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_coe_advisor_students(test, search_criteria)
    test.searchable_data.select { |u| search_criteria.coe_advisor.include? u[:coe_advisor] }
  end

  # Returns the student hashes that match a set of COE ethnicity filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_coe_ethnicity_students(test, search_criteria)
    students = []
    search_criteria.coe_ethnicity.each do |coe_ethnicity|
      students << test.searchable_data.select { |u| search_criteria.coe_ethnicity_per_code(u[:coe_ethnicity]) == coe_ethnicity }
    end
    students.flatten
  end

  # Returns the student hashes that match a set of COE gender filters
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_coe_gender_students(test, search_criteria)
    students = []
    search_criteria.coe_gender.each do |coe_gender|
      if coe_gender == 'Male'
        students << test.searchable_data.select { |u| %w(M m).include? u[:coe_gender] }
      elsif coe_gender == 'Female'
        students << test.searchable_data.select { |u| %w(F f).include? u[:coe_gender] }
      else
        logger.error "Test data has an unrecognized COE gender '#{coe_gender}'"
        fail
      end
    end
    students.flatten
  end

  # Returns the student hashes that match a COE inactive filters
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_coe_inactive_students(test)
    test.searchable_data.select { |u| u[:coe_inactive] }
  end

  # Returns the student hashes that match a COE underrepresented minority filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_coe_minority_students(test)
    test.searchable_data.select { |u| u[:coe_underrepresented_minority] }
  end

  # Returns the student hashes that match a COE probation filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_coe_probation_students(test)
    test.searchable_data.select { |u| u[:coe_probation] }
  end

  # Returns the student hashes that match a COE PREP filter
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_coe_prep_students(test, search_criteria)
    students = []
    search_criteria.coe_prep.each do |prep|
      students << test.searchable_data.select { |u| u[:coe_prep] } if prep == 'PREP'
      students << test.searchable_data.select { |u| u[:prep_elig] } if prep == 'PREP eligible'
      students << test.searchable_data.select { |u| u[:t_prep] } if prep == 'T-PREP'
      students << test.searchable_data.select { |u| u[:t_prep_elig] } if prep == 'T-PREP eligible'
    end
    students.flatten
  end

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
    test.searchable_data.select { |u| u[:current_sir] }
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
  def matching_xethnic_admits(test)
    test.searchable_data.select { |u| u[:xethnic] }
  end

  # Returns the admits that match a Hispanic filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_hispanic_admits(test)
    test.searchable_data.select { |u| u[:hispanic] }
  end

  # Returns the admits that match a UREM filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_urem_admits(test)
    test.searchable_data.select { |u| u[:urem] }
  end

  # Returns the admits that match a First Generation Student filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_first_gen_admits(test)
    test.searchable_data.select { |u| u[:first_gen_student] }
  end

  # Returns the admits that match an Application Fee Waiver filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_fee_waiver_admits(test)
    test.searchable_data.select { |u| u[:matching_fee_waiver_admits] }
  end

  # Returns the admits that match a Foster Care filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_foster_care_admits(test)
    test.searchable_data.select { |u| u[:foster_care] }
  end

  # Returns the admits that match a Family Single Parent filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_fam_single_parent_admits(test)
    test.searchable_data.select { |u| u[:family_single_parent] }
  end

  # Returns the admits that match a Student Single Parent filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_stu_single_parent_admits(test)
    test.searchable_data.select { |u| u[:student_single_parent] }
  end

  # Returns the admits that match a Family Dependents filter
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def matching_family_depends_admits(test, search_criteria)
    students = []
    search_criteria.family_dependents.each do |depends|
      range = depends.split(' - ')
      low_end = range[0].to_i
      high_end = range[1].to_i
      students << test.searchable_data.select { |u| (u[:family_dependents].to_i >= low_end) && (u[:family_dependents].to_i < high_end) }
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
      range = depends.split(' - ')
      low_end = range[0].to_i
      high_end = range[1].to_i
      students << test.searchable_data.select { |u| (u[:student_dependents].to_i >= low_end) && (u[:student_dependents].to_i < high_end) }
    end
    students.flatten
  end

  # Returns the admits that match a Re-entry Status filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_re_entry_admits(test)
    test.searchable_data.select { |u| u[:re_entry_status] }
  end

  # Returns the admits that match a Last School LCFF+ filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_lcff_plus_admits(test)
    test.searchable_data.select { |u| u[:last_school_lcff_plus] }
  end

  # Returns the admits that match a Special Program CEP filter
  # @param test [BOACTestConfig]
  # @return [Array<Hash>]
  def matching_special_pgm_cep_admits(test)
    test.searchable_data.select { |u| u[:special_program_cep] }
  end

  ### EXPECTED RESULTS

  # Filters an array of user data hashes according to search criteria and returns the students that should be present in the UI after
  # the search completes
  # @param test [BOACTestConfig]
  # @param search_criteria [CohortFilter]
  # @return [Array<Hash>]
  def expected_student_search_results(test, search_criteria)
    matches = []
    matches << matching_college_students(test, search_criteria) if search_criteria.college&.any?
    matches << matching_entering_term_students(test, search_criteria) if search_criteria.entering_terms&.any?
    matches << matching_grad_term_students(test, search_criteria) if search_criteria.expected_grad_terms&.any?
    matches << matching_gpa_students(test, search_criteria) if search_criteria.gpa&.any?
    matches << matching_gpa_last_term_students(test, search_criteria) if search_criteria.gpa_last_term&.any?
    matches << matching_level_students(test, search_criteria) if search_criteria.level&.any?
    matches << matching_major_students(test, search_criteria) if search_criteria.major&.any?
    matches << matching_mid_point_students(test) if search_criteria.mid_point_deficient
    matches << matching_transfer_students(test) if search_criteria.transfer_student
    matches << matching_units_students(test, search_criteria) if search_criteria.units_completed&.any?
    matches << matching_last_name_students(test, search_criteria) if search_criteria.last_name&.any?
    matches << matching_ethnicity_students(test, search_criteria) if search_criteria.ethnicity&.any?
    matches << matching_gender_students(test, search_criteria) if search_criteria.gender&.any?
    matches << matching_minority_students(test) if search_criteria.underrepresented_minority
    matches << matching_visa_type_students(test, search_criteria) if search_criteria.visa_type&.any?
    matches << matching_acad_plan_students(test, search_criteria) if search_criteria.cohort_owner_academic_plans&.any?
    matches << matching_asc_inactive_students(test)if search_criteria.asc_inactive
    matches << matching_asc_intensive_students(test) if search_criteria.asc_intensive
    matches << matching_asc_team_students(test, search_criteria) if search_criteria.asc_team&.any?
    matches << matching_coe_advisor_students(test, search_criteria) if search_criteria.coe_advisor&.any?
    matches << matching_coe_ethnicity_students(test, search_criteria) if search_criteria.coe_ethnicity&.any?
    matches << matching_coe_gender_students(test, search_criteria) if search_criteria.coe_gender&.any?
    matches << matching_coe_inactive_students(test) if search_criteria.coe_inactive
    matches << matching_coe_minority_students(test) if search_criteria.coe_underrepresented_minority
    matches << matching_coe_probation_students(test) if search_criteria.coe_probation
    matches << matching_coe_prep_students(test, search_criteria) if search_criteria.coe_prep&.any?

    matches.any?(&:empty?) ? [] : matches.inject(:'&')
  end

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
    matches << matching_xethnic_admits(test) if search_criteria.xethnic
    matches << matching_hispanic_admits(test) if search_criteria.hispanic
    matches << matching_urem_admits(test) if search_criteria.urem
    matches << matching_first_gen_admits(test) if search_criteria.first_gen_student
    matches << matching_fee_waiver_admits(test) if search_criteria.fee_waiver
    matches << matching_foster_care_admits(test) if search_criteria.foster_care
    matches << matching_fam_single_parent_admits(test) if search_criteria.family_single_parent
    matches << matching_stu_single_parent_admits(test) if search_criteria.student_single_parent
    matches << matching_family_depends_admits(test, search_criteria) if search_criteria.family_dependents&.any?
    matches << matching_student_depends_admits(test, search_criteria) if search_criteria.student_dependents&.any?
    matches << matching_re_entry_admits(test) if search_criteria.re_entry_status
    matches << matching_lcff_plus_admits(test) if search_criteria.last_school_lcff_plus
    matches << matching_special_pgm_cep_admits(test) if search_criteria.special_program_cep
    matches.any?(&:empty?) ? [] : matches.inject(:'&')
  end

  # Sets a cohort's membership based on expected results, rather than actual results
  # @param cohort [FilteredCohort]
  # @param test [BOACTestConfig]
  # @return [Array<BOACUser>]
  def set_cohort_members(cohort, test)
    expected_sids = expected_student_search_results(test, cohort.search_criteria).map { |k| k[:sid] }
    cohort.members = test.students.select { |s| expected_sids.include? s.sis_id }
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

  # Returns the sequence of SIDs that should be present when search results are sorted by team
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_team(expected_results)
    sorted_results = expected_results.sort_by do |u|
      team = u[:asc_sports].empty? ? 'zzz' : u[:asc_sports].sort.first.gsub(' (AA)', '') .gsub(/\W+/, '')
      [team, u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]]
    end
    sorted_results.map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by GPA, ascending
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_gpa(expected_results)
    sorted_results = expected_results.sort_by { |u| [u[:gpa].to_f, u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]] }
    sorted_results.map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by GPA, descending
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_gpa_desc(expected_results)
    results_with_gpa = expected_results.select { |u| u[:gpa] }.sort do |a, b|
      [b[:gpa].to_f, a[:last_name_sortable_cohort].downcase, a[:first_name_sortable_cohort].downcase, a[:sid]] <=>
          [a[:gpa].to_f, b[:last_name_sortable_cohort].downcase, b[:first_name_sortable_cohort].downcase, b[:sid]]
    end
    results_without_gpa = expected_results.reject { |u| u[:gpa] }.sort_by do |u|
      [u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]]
    end
    (results_without_gpa + results_with_gpa).map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by the previous term GPA, ascending
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_gpa_last_term(expected_results)
    results_with_term = expected_results.select { |u| u[:gpa_last_term] }.sort_by do |u|
      [u[:gpa_last_term], u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]]
    end
    results_without_term = expected_results.reject { |u| u[:gpa_last_term] }.sort_by do |u|
      [u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]]
    end
    (results_with_term + results_without_term).map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by the previous term GPA, descending
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_gpa_last_term_desc(expected_results)
    results_with_term = expected_results.select { |u| u[:gpa_last_term] }.sort do |a, b|
      [b[:gpa_last_term], a[:last_name_sortable_cohort].downcase, a[:first_name_sortable_cohort].downcase, a[:sid]] <=>
          [a[:gpa_last_term], b[:last_name_sortable_cohort].downcase, b[:first_name_sortable_cohort].downcase, b[:sid]]
    end
    results_without_term = expected_results.reject { |u| u[:gpa_last_term] }.sort_by do |u|
      [u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]]
    end
    (results_with_term + results_without_term).map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by the term GPA before the previous term,
  # ascending
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_gpa_last_last_term(expected_results)
    results_with_term = expected_results.select { |u| u[:gpa_last_last_term] }.sort_by do |u|
      [u[:gpa_last_last_term], u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]]
    end
    results_without_term = expected_results.reject { |u| u[:gpa_last_last_term] }.sort_by do |u|
      [u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]]
    end
    (results_with_term + results_without_term).map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by the term GPA before the previous term,
  # descending
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_gpa_last_last_term_desc(expected_results)
    results_with_term = expected_results.select { |u| u[:gpa_last_last_term] }.sort do |a, b|
      [b[:gpa_last_last_term], a[:last_name_sortable_cohort].downcase, a[:first_name_sortable_cohort].downcase, a[:sid]] <=>
          [a[:gpa_last_last_term], b[:last_name_sortable_cohort].downcase, b[:first_name_sortable_cohort].downcase, b[:sid]]
    end
    results_without_term = expected_results.reject { |u| u[:gpa_last_last_term] }.sort_by do |u|
      [u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]]
    end
    (results_with_term + results_without_term).map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by level
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_level(expected_results)
    # Sort first by the secondary sort order
    results_by_first_name = expected_results.sort_by { |u| [u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]] }
    # Then arrange by the sort order for level
    results_by_level = []
    %w(Freshman Sophomore Junior Senior Graduate).each do |level|
      results_by_level << results_by_first_name.select do |u|
        u[:level] == level
      end
    end
    results_by_level.flatten.map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by major
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_major(expected_results)
    sorted_results = expected_results.sort_by do |u|
      major = u[:major].empty? ? 'aaa' : u[:major].sort.first.gsub(/\W/, '').downcase
      [major, u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]]
    end
    sorted_results.map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by entering term
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_matriculation(expected_results)
    sorted_results = expected_results.sort_by do |u|
      term = u[:entering_term].nil? ? '9999' : u[:entering_term]
      [term, u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]]
    end
    sorted_results.map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by terms in attendance, ascending
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_terms_in_attend(expected_results)
    results_with_term = expected_results.select { |u| u[:terms_completed] }.sort_by do |u|
      [u[:terms_completed], u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]]
    end
    results_without_term = expected_results.reject { |u| u[:terms_completed] }.sort_by do |u|
      [u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]]
    end
    (results_with_term + results_without_term).map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by terms in attendance, descending
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_terms_in_attend_desc(expected_results)
    results_with_term = expected_results.select { |u| u[:terms_completed] }.sort do |a, b|
      [b[:terms_completed], a[:last_name_sortable_cohort].downcase, a[:first_name_sortable_cohort].downcase, a[:sid]] <=>
          [a[:terms_completed], b[:last_name_sortable_cohort].downcase, b[:first_name_sortable_cohort].downcase, b[:sid]]
    end
    results_without_term = expected_results.reject { |u| u[:terms_completed] }.sort_by do |u|
      [u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]]
    end
    (results_with_term + results_without_term).map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by units in progress, ascending
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_units_in_prog(expected_results)
    sorted_results = expected_results.sort_by { |u| [u[:units_in_progress].to_f, u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]] }
    sorted_results.map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by units in progress, descending
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_units_in_prog_desc(expected_results)
    results_with_units = expected_results.select { |u| u[:units_in_progress].to_f > 0 }.sort do |a, b|
      [b[:units_in_progress].to_f, a[:last_name_sortable_cohort].downcase, a[:first_name_sortable_cohort].downcase, a[:sid]] <=>
          [a[:units_in_progress].to_f, b[:last_name_sortable_cohort].downcase, b[:first_name_sortable_cohort].downcase, b[:sid]]
    end
    results_without_units = expected_results.select { |u| u[:units_in_progress].to_f.zero? }.sort_by do |u|
      [u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]]
    end
    (results_without_units + results_with_units).map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by cumulative units, ascending
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_units_completed(expected_results)
    sorted_results = expected_results.sort_by { |u| [u[:units_completed].to_f, u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]] }
    sorted_results.map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when search results are sorted by cumulative units, descending
  # @param expected_results [Array<Hash>]
  # @return [Array<String>]
  def expected_sids_by_units_completed_desc(expected_results)
    results_with_units = expected_results.select { |u| u[:units_completed] }.sort do |a, b|
      [b[:units_completed].to_f, a[:last_name_sortable_cohort].downcase, a[:first_name_sortable_cohort].downcase, a[:sid]] <=>
          [a[:units_completed].to_f, b[:last_name_sortable_cohort].downcase, b[:first_name_sortable_cohort].downcase, b[:sid]]
    end
    results_without_units = expected_results.reject { |u| u[:units_completed] }.sort_by do |u|
      [u[:last_name_sortable_cohort].downcase, u[:first_name_sortable_cohort].downcase, u[:sid]]
    end
    (results_without_units + results_with_units).map { |u| u[:sid] }
  end

end
