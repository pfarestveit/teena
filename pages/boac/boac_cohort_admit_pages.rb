module BOACCohortAdmitPages

  include PageObject
  include Logging
  include Page
  include BOACPages
  include BOACListViewAdmitPages
  include BOACCohortPages

  button(:export_ferpa_confirm_button, id: 'ferpa-reminder-confirm')
  button(:export_ferpa_cancel_button, id: 'ferpa-reminder-cancel')

  def sort_by_cs_id
    sort_by 'cs_empl_id'
  end

  def click_export_ferpa_confirm
    wait_for_update_and_click export_ferpa_confirm_button_element
  end

  def click_export_ferpa_cancel
    wait_for_update_and_click export_ferpa_cancel_button_element
  end

  def export_admit_list(cohort)
    logger.info "Exporting admit list with default columns for #{cohort.instance_of?(FilteredCohort) ? 'cohort' : 'group'} ID '#{cohort.id}'"
    Utils.prepare_download_dir
    click_export_list
    click_export_ferpa_confirm
    csv_file_path = "#{Utils.download_dir}/#{cohort.name + '-' if cohort.id}students-#{Time.now.strftime('%Y-%m-%d')}_*.csv"
    wait_until(20) { Dir[csv_file_path].any? }
    CSV.table Dir[csv_file_path].first
  end

  def verify_admits_present_in_export(all_admit_data, cohort_member_data, parsed_csv)
    cohort_member_data.each do |admit|
      admit_data = all_admit_data.find { |d| d[:cs_empl_id] == admit[:sid] }
      wait_until(1, "Unable to find CS ID #{admit_data[:cs_empl_id]}") do
        parsed_csv.find do |r|
          (r.dig(:first_name) == admit_data[:first_name]) &&
            (r.dig(:last_name) == admit_data[:last_name]) &&
            (r.dig(:cs_empl_id) == admit_data[:cs_empl_id].to_i)
        end
      end
    end
  end

  def verify_no_email_in_export(parsed_csv)
    wait_until(1, "Found email header(s)") { (parsed_csv.headers & [:email, :campus_email_1]).empty?  }
  end

  def verify_mandatory_data_in_export(parsed_csv)
    parsed_csv.by_col!
    errors = []
    check_export_for_data(parsed_csv, :middle_name, errors)
    check_export_for_data(parsed_csv, :applyuc_cpid, errors)
    check_export_for_data(parsed_csv, :birthdate, errors)
    check_export_for_data(parsed_csv, :freshman_or_transfer, errors)
    check_export_for_data(parsed_csv, :admit_status, errors)
    check_export_for_data(parsed_csv, :current_sir, errors)
    check_export_for_data(parsed_csv, :college, errors)
    check_export_for_data(parsed_csv, :admit_term, errors)
    check_export_for_data(parsed_csv, :permanent_street_1, errors)
    check_export_for_data(parsed_csv, :permanent_city, errors)
    check_export_for_data(parsed_csv, :permanent_region, errors)
    check_export_for_data(parsed_csv, :permanent_postal, errors)
    check_export_for_data(parsed_csv, :permanent_country, errors)
    check_export_for_data(parsed_csv, :xethnic, errors)
    check_export_for_data(parsed_csv, :hispanic, errors)
    check_export_for_data(parsed_csv, :urem, errors)
    check_export_for_data(parsed_csv, :parent_1_education_level, errors)
    check_export_for_data(parsed_csv, :parent_2_education_level, errors)
    check_export_for_data(parsed_csv, :highest_parent_education_level, errors)
    check_export_for_data(parsed_csv, :hs_unweighted_gpa, errors)
    check_export_for_data(parsed_csv, :hs_weighted_gpa, errors)
    check_export_for_data(parsed_csv, :family_dependents_num, errors)
    check_export_for_data(parsed_csv, :family_income, errors)
    check_export_for_data(parsed_csv, :reentry_status, errors)
    check_export_for_data(parsed_csv, :us_citizenship_status, errors)
    check_export_for_data(parsed_csv, :citizenship_country, errors)
    check_export_for_data(parsed_csv, :residency_category, errors)
    wait_until(1, "Expected mandatory data columns with no data #{errors} to be empty") { errors.empty? }
  end

  def verify_optional_data_in_export(parsed_csv)
    parsed_csv.by_col!
    warnings = []
    check_export_for_data(parsed_csv, :uid, warnings)
    check_export_for_data(parsed_csv, :permanent_street_2, warnings)
    check_export_for_data(parsed_csv, :first_generation_college, warnings)
    check_export_for_data(parsed_csv, :transfer_gpa, warnings)
    check_export_for_data(parsed_csv, :application_fee_waiver_flag, warnings)
    check_export_for_data(parsed_csv, :foster_care_flag, warnings)
    check_export_for_data(parsed_csv, :family_is_single_parent, warnings)
    check_export_for_data(parsed_csv, :student_is_single_parent, warnings)
    check_export_for_data(parsed_csv, :student_dependents_num, warnings)
    check_export_for_data(parsed_csv, :student_income, warnings)
    check_export_for_data(parsed_csv, :is_military_dependent, warnings)
    check_export_for_data(parsed_csv, :military_status, warnings)
    check_export_for_data(parsed_csv, :athlete_status, warnings)
    check_export_for_data(parsed_csv, :summer_bridge_status, warnings)
    check_export_for_data(parsed_csv, :last_school_lcff_plus_flag, warnings)
    check_export_for_data(parsed_csv, :special_program_cep, warnings)
    check_export_for_data(parsed_csv, :us_non_citizen_status, warnings)
    check_export_for_data(parsed_csv, :permanent_residence_country, warnings)
    check_export_for_data(parsed_csv, :non_immigrant_visa_current, warnings)
    check_export_for_data(parsed_csv, :non_immigrant_visa_planned, warnings)
    wait_until(1, "Columns #{warnings} have no data, which might or might not be a problem.") { warnings.empty? }
  end

  private

  def check_export_for_data(parsed_csv, column, errors)
    errors << column.to_s unless parsed_csv.dig(column).compact.any?
  end

end
