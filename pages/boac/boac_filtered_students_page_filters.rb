require_relative '../../util/spec_helper'

module BOACFilteredStudentsPageFilters

  include PageObject
  include Logging
  include Page

  # NEW FILTERED COHORTS

  select_list(:new_filter_select, id: 'filter-select-primary-new')
  elements(:new_filter_option, :option, xpath: '//option[starts-with(@id, "primary-")]')
  select_list(:new_sub_filter_select, xpath: '//select[contains(@id, "filter-select-secondary-")]')
  elements(:new_sub_filter_option, :option, xpath: '//option[starts-with(@id, "secondary-")]')
  text_field(:filter_range_min_input, xpath: '//input[contains(@id, "filter-range-min")]')
  text_field(:filter_range_max_input, xpath: '//input[contains(@id, "filter-range-max")]')
  button(:unsaved_filter_add_button, id: 'unsaved-filter-add')
  button(:unsaved_filter_cancel_button, id: 'unsaved-filter-reset')
  button(:unsaved_filter_apply_button, id: 'unsaved-filter-apply')
  span(:gpa_filter_range_error, xpath: '//span[text()="GPA must be a number in the range 0 to 4."]')
  span(:gpa_filter_logical_error, xpath: '//span[text()="GPA inputs must be in ascending order."]')
  span(:last_name_filter_logical_error, xpath: '//span[text()="Requires letters in ascending order."]')

  # Clicks the new filter button, making two attempts in case of a DOM update
  def click_new_filter_select
    wait_for_update_and_click new_filter_select_element
  rescue Selenium::WebDriver::Error::StaleElementReferenceError
    wait_for_update_and_click new_filter_select_element
  end

  def filter_options
    wait_until(Utils.short_wait) { new_filter_option_elements.any? }
    new_filter_option_elements.map { |el| el.text.strip }
  end

  def select_new_filter_option(filter_option)
    logger.info "Selecting filter '#{filter_option}'"
    wait_for_element_and_select_js(new_filter_select_element, filter_option)
  end

  def filter_sub_option_identifier(filter_option, filter_sub_option)
    case filter_option
    when 'Ethnicity (COE)'
      CohortFilter.coe_ethnicity_per_code filter_sub_option
    when 'Gender (COE)'
      CohortFilter.coe_gender_per_code filter_sub_option
    when 'Visa Type'
      if filter_sub_option == 'All types'
        filter_sub_option
      else
        CohortFilter.visa_type_per_code filter_sub_option
      end
    when 'Level'
      CohortFilter.level_per_code filter_sub_option
    when 'Entering Term'
      filter_sub_option.split.reverse.join(' ')
    else
      filter_sub_option
    end
  end

  def select_new_filter_sub_option(filter_option, filter_sub_option)
    filter_sub_option = filter_sub_option_identifier(filter_option, filter_sub_option)
    logger.info "Selecting sub-option '#{filter_sub_option}'"
    # GPA and Last Name require input
    if ['GPA (Cumulative)', 'GPA (Last Term)', 'Last Name', 'Family Dependents', 'Student Dependents'].include? filter_option
      wait_for_element_and_type(filter_range_min_input_element, filter_sub_option['min'])
      wait_for_element_and_type(filter_range_max_input_element, filter_sub_option['max'])

    # All others require a selection
    else
      wait_for_element_and_select_js(new_sub_filter_select_element, filter_sub_option)
    end
  end

  # Selects, adds, and applies a filter
  # @param filter_option [String]
  # @param filter_sub_option [String]
  def select_new_filter(filter_option, filter_sub_option = nil)
    select_new_filter_option filter_option
    # Some have no sub-options
    no_options = ['Midpoint Deficient Grade', 'Transfer Student', 'Underrepresented Minority', 'Inactive (ASC)', 'Intensive (ASC)',
                  'Inactive (COE)', 'Underrepresented Minority (COE)', 'Probation (COE)', 'Current SIR', 'Hispanic', 'UREM',
                  'First Generation College', 'Application Fee Waiver', 'Foster Care', 'Family Is Single Parent',
                  'Student Is Single Parent', 'Re-entry Status', 'Last School LCFF+', 'Holds']
    select_new_filter_sub_option(filter_option, filter_sub_option) unless no_options.include? filter_option
    wait_for_update_and_click unsaved_filter_add_button_element
    unsaved_filter_apply_button_element.when_present Utils.short_wait
  end

  # Compares given an array of search criteria with available filter sub-options and returns missing sub-options
  # @param criteria [Array<String>]
  # @param filter_option [String]
  # @return [Array<String>]
  def unavailable_test_data(criteria, filter_option)
    select_new_filter_option filter_option
    sleep Utils.click_wait
    missing_options = []
    criteria.each do |criterion|
      criterion = criterion.code if criterion.instance_of? Squad
      criterion = filter_sub_option_identifier(filter_option, criterion)
      expected_opt = filter_sub_option_identifier(filter_option, criterion)
      missing_options << criterion unless matching_option(new_sub_filter_select_element, expected_opt)
    end
    hit_escape
    wait_for_update_and_click unsaved_filter_cancel_button_element
    logger.debug "The options #{missing_options} are not present and will need to be removed from search criteria" if missing_options.any?
    missing_options
  end

  # Executes a custom student cohort search using search criteria associated with a cohort and stores the result count
  # @param cohort [FilteredCohort]
  def perform_student_search(cohort)

    # The squads and majors lists can change over time. Avoid test failures if the search criteria is out of sync
    # with actual squads or majors. Advisors might also change, but fail if this happens for now.
    if cohort.search_criteria.intended_major&.any?
      missing_options = unavailable_test_data(cohort.search_criteria.intended_major, 'Intended Major')
      missing_options.each { |f| cohort.search_criteria.intended_major.delete f }
    end

    if cohort.search_criteria.major&.any?
      missing_options = unavailable_test_data(cohort.search_criteria.major, 'Major')
      missing_options.each { |f| cohort.search_criteria.major.delete f }
    end

    if cohort.search_criteria.minor&.any?
      missing_options = unavailable_test_data(cohort.search_criteria.minor, 'Minor')
      missing_options.each { |f| cohort.search_criteria.minor.delete f }
    end

    if cohort.search_criteria.asc_team&.any?
      missing_options = unavailable_test_data(cohort.search_criteria.asc_team, 'Team (ASC)')
      missing_options.each { |f| cohort.search_criteria.asc_team.delete f }
    end

    # Global
    cohort.search_criteria.academic_standing.each { |a| select_new_filter('Academic Standing', a) } if cohort.search_criteria.academic_standing
    cohort.search_criteria.college.each { |m| select_new_filter('College', m) } if cohort.search_criteria.college
    cohort.search_criteria.entering_terms.each { |term| select_new_filter('Entering Term', term.to_s) } if cohort.search_criteria.entering_terms
    cohort.search_criteria.gpa.each { |gpa| select_new_filter('GPA (Cumulative)', gpa) } if cohort.search_criteria.gpa
    cohort.search_criteria.gpa_last_term.each { |gpa| select_new_filter('GPA (Last Term)', gpa) } if cohort.search_criteria.gpa_last_term
    cohort.search_criteria.grading_basis_epn.each { |g| select_new_filter('EPN/CPN Grading Option', g.to_s) } if cohort.search_criteria.grading_basis_epn
    select_new_filter 'Holds' if cohort.search_criteria.holds
    cohort.search_criteria.intended_major.each { |m| select_new_filter('Intended Major', m) } if cohort.search_criteria.intended_major
    cohort.search_criteria.level.each { |l| select_new_filter('Level', l) } if cohort.search_criteria.level
    cohort.search_criteria.units_completed.each { |u| select_new_filter('Units Completed', u) } if cohort.search_criteria.units_completed
    cohort.search_criteria.major.each { |m| select_new_filter('Major', m) } if cohort.search_criteria.major
    select_new_filter 'Midpoint Deficient Grade' if cohort.search_criteria.mid_point_deficient
    cohort.search_criteria.minor.each { |m| select_new_filter('Minor', m) } if cohort.search_criteria.minor
    select_new_filter 'Transfer Student' if cohort.search_criteria.transfer_student
    cohort.search_criteria.expected_grad_terms.each { |t| select_new_filter('Expected Graduation Term', t.to_s) } if cohort.search_criteria.expected_grad_terms
    cohort.search_criteria.last_name.each { |n| select_new_filter('Last Name', n) } if cohort.search_criteria.last_name
    cohort.search_criteria.gender.each { |g| select_new_filter('Gender', g) } if cohort.search_criteria.gender
    cohort.search_criteria.cohort_owner_academic_plans.each { |e| select_new_filter('My Students', e) } if cohort.search_criteria.cohort_owner_academic_plans
    select_new_filter 'Underrepresented Minority' if cohort.search_criteria.underrepresented_minority
    cohort.search_criteria.ethnicity.each { |e| select_new_filter('Ethnicity', e) } if cohort.search_criteria.ethnicity
    cohort.search_criteria.visa_type.each { |v| select_new_filter('Visa Type', v) } if cohort.search_criteria.visa_type
    cohort.search_criteria.curated_groups.each { |g| select_new_filter('My Curated Groups', g) } if cohort.search_criteria.curated_groups

    # CoE
    cohort.search_criteria.coe_advisor.each { |a| select_new_filter('Advisor (COE)', a) } if cohort.search_criteria.coe_advisor
    cohort.search_criteria.coe_ethnicity.each { |e| select_new_filter('Ethnicity (COE)', e) } if cohort.search_criteria.coe_ethnicity
    select_new_filter 'Underrepresented Minority (COE)' if cohort.search_criteria.coe_underrepresented_minority
    cohort.search_criteria.coe_gender.each { |g| select_new_filter('Gender (COE)', g) } if cohort.search_criteria.coe_gender
    cohort.search_criteria.coe_prep.each { |p| select_new_filter('PREP (COE)', p) } if cohort.search_criteria.coe_prep
    select_new_filter 'Probation (COE)' if cohort.search_criteria.coe_probation
    select_new_filter 'Inactive (COE)' if cohort.search_criteria.coe_inactive

    # ASC
    select_new_filter 'Inactive (ASC)' if cohort.search_criteria.asc_inactive
    select_new_filter 'Intensive (ASC)' if cohort.search_criteria.asc_intensive
    cohort.search_criteria.asc_team.each { |s| select_new_filter('Team (ASC)', s.name) } if cohort.search_criteria.asc_team

    execute_search cohort
  end

  # Executes a custom admit cohort search using search criteria associated with a cohort and stores the result count
  # @param cohort [FilteredCohort]
  def perform_admit_search(cohort)

    if cohort.search_criteria.freshman_or_transfer&.any?
      missing_options = unavailable_test_data(cohort.search_criteria.freshman_or_transfer, 'Freshman or Transfer')
      missing_options.each { |f| cohort.search_criteria.freshman_or_transfer.delete f }
    end

    if cohort.search_criteria.special_program_cep&.any?
      missing_options = unavailable_test_data(cohort.search_criteria.special_program_cep, 'Special Program CEP')
      missing_options.each { |f| cohort.search_criteria.special_program_cep.delete f }
    end

    if cohort.search_criteria.residency&.any?
      missing_options = unavailable_test_data(cohort.search_criteria.residency, 'Residency')
      missing_options.each { |f| cohort.search_criteria.residency.delete f }
    end

    cohort.search_criteria.freshman_or_transfer.each { |f| select_new_filter('Freshman or Transfer', f) } if cohort.search_criteria.freshman_or_transfer
    select_new_filter 'Current SIR' if cohort.search_criteria.current_sir
    cohort.search_criteria.college.each { |c| select_new_filter('College', c) } if cohort.search_criteria.college
    cohort.search_criteria.xethnic.each { |x| select_new_filter('XEthnic', x) } if cohort.search_criteria.xethnic
    select_new_filter 'Hispanic' if cohort.search_criteria.hispanic
    select_new_filter 'UREM' if cohort.search_criteria.urem
    select_new_filter 'First Generation College' if cohort.search_criteria.first_gen_college
    select_new_filter 'Application Fee Waiver' if cohort.search_criteria.fee_waiver
    cohort.search_criteria.residency.each { |r| select_new_filter('Residency', r) } if cohort.search_criteria.residency
    select_new_filter 'Foster Care' if cohort.search_criteria.foster_care
    select_new_filter 'Family Is Single Parent' if cohort.search_criteria.family_single_parent
    select_new_filter 'Student Is Single Parent' if cohort.search_criteria.student_single_parent
    cohort.search_criteria.family_dependents.each { |f| select_new_filter('Family Dependents', f) } if cohort.search_criteria.family_dependents
    cohort.search_criteria.student_dependents.each { |s| select_new_filter('Student Dependents', s) } if cohort.search_criteria.student_dependents
    select_new_filter 'Re-entry Status' if cohort.search_criteria.re_entry_status
    select_new_filter 'Last School LCFF+' if cohort.search_criteria.last_school_lcff_plus
    cohort.search_criteria.special_program_cep.each { |s| select_new_filter('Special Program CEP', s) } if cohort.search_criteria.special_program_cep

    execute_search cohort
  end

  # Executes a search
  # @param cohort [FilteredCohort]
  def execute_search(cohort)
    # If there are any search criteria left, execute search and log time search took to complete
    if cohort.search_criteria.list_filters.flatten.compact.any?
      wait_for_update_and_click unsaved_filter_apply_button_element
      cohort.member_count = wait_for_search_results
      logger.warn "No results found for #{cohort.search_criteria.list_filters}" if cohort.member_count.zero?

    # If no search criteria remain, do not try to search
    else
      logger.warn 'None of the search criteria are available in the UI'
      cohort.member_count = 0
    end
  end

  # EXISTING FILTERED COHORTS - Viewing

  button(:show_filters_button, xpath: "//button[contains(.,'Show Filters')]")
  elements(:cohort_filter_row, :div, class: 'filter-row')

  # Ensures that cohort filters are visible
  def show_filters
    button_element(id: 'show-hide-details-button').when_visible Utils.medium_wait
    show_filters_button if show_filters_button?
  end

  # Returns the XPath to the filter name on a filter row
  # @param filter_name [String]
  # @return [String]
  def existing_filter_xpath(filter_name)
    if ['Ethnicity', 'Gender', 'Underrepresented Minority'].include? filter_name
      "//div[contains(@class,\"filter-row\")]/div[contains(.,\"#{filter_name}\") and not(contains(.,\"COE\"))]"
    elsif filter_name == 'Major'
      "//div[contains(@class,\"filter-row\")]/div[contains(.,\"#{filter_name}\") and not(contains(.,\"Intended\"))]"
    else
      "//div[contains(@class,\"filter-row\")]/div[contains(.,\"#{filter_name}\")]"
    end
  end

  # Returns the element containing an added cohort filter
  # @param filter_option [String]
  # @return [Element]
  def existing_filter_element(filter_name, filter_option = nil)
    filter_option_xpath = "#{existing_filter_xpath filter_name}/following-sibling::div"

    if ['Inactive', 'Inactive (ASC)', 'Inactive (COE)', 'Intensive (ASC)', 'Probation (COE)', 'Transfer Student', 'Underrepresented Minority',
        'Underrepresented Minority (COE)', 'Current SIR', 'Hispanic', 'UREM', 'First Generation College', 'Holds',
        'Application Fee Waiver', 'Foster Care', 'Family Is Single Parent', 'Student Is Single Parent', 'Re-entry Status',
        'Last School LCFF+'].include? filter_name
      div_element(xpath: existing_filter_xpath(filter_name))

    elsif filter_name == 'Last Name'
      div_element(xpath: "#{filter_option_xpath}[contains(text(),\"#{filter_option['min'] + ' through ' + filter_option['max']}\")]")

    elsif ['GPA (Cumulative)', 'GPA (Last Term)'].include? filter_name
      div_element(xpath: "#{filter_option_xpath}[contains(text(),\"#{sprintf('%.3f', filter_option['min']) + ' - ' + sprintf('%.3f', filter_option['max'])}\")]")

    elsif ['Family Dependents', 'Student Dependents'].include? filter_name
      div_element(xpath: "#{filter_option_xpath}[contains(text(),\"#{filter_option['min'] + ' - ' + filter_option['max']}\")]")

    elsif %w(Ethnicity Gender).include? filter_name
      div_element(xpath: "#{filter_option_xpath}[contains(text(),\"#{filter_option}\") and not(contains(.,\"COE\"))]")

    else
      div_element(xpath: "#{filter_option_xpath}[contains(.,\"#{filter_option}\")]")
    end
  end

  # Verifies that a student cohort's filters are visibly selected
  # @param cohort [FilteredCohort]
  def verify_student_filters_present(cohort)
    filters = cohort.search_criteria
    verify_filters(cohort) do
      wait_until(1) do
        logger.debug 'Verify Academic Standing filter'
        filters.academic_standing.each { |a| existing_filter_element('academicStandings', a).exists? } if filters.academic_standing&.any?
        logger.debug 'Verifying College filter'
        filters.college.each { |m| existing_filter_element('College', m).exists? } if filters.college&.any?
        logger.debug 'Verifying Entering Term filter'
        filters.entering_terms.each { |term| existing_filter_element('Entering Term', term).exists? } if filters.entering_terms&.any?
        logger.debug 'Verifying Expected Graduation Term filter'
        filters.expected_grad_terms.each { |t| existing_filter_element('Expected Graduation Term', t).exists? } if filters.expected_grad_terms&.any?
        logger.debug 'Verifying GPA (Cumulative) filter'
        filters.gpa.each { |g| existing_filter_element('GPA (Cumulative)', g).exists? } if filters.gpa&.any?
        logger.debug 'Verifying Holds filter'
        existing_filter_element('Holds').exists? if filters.holds
        logger.debug 'Verifying GPA (Last Term) filter'
        filters.gpa_last_term.each { |g| existing_filter_element('GPA (Last Term)', g).exists? } if filters.gpa_last_term&.any?
        logger.debug 'Verifying Grading Basis EPN filter'
        filters.grading_basis_epn.each { |g| existing_filter_element('EPN/CPN Grading Option', g).exists? } if filters.grading_basis_epn&.any?
        logger.debug 'Verifying Intended Major filter'
        filters.intended_major.each { |m| existing_filter_element('Intended Major', m).exists? } if filters.intended_major&.any?
        logger.debug 'Verifying Level filter'
        filters.level.each { |l| existing_filter_element('Level', l).exists? } if filters.level&.any?
        logger.debug 'Verifying Major filter'
        filters.major.each { |m| existing_filter_element('Major', m).exists? } if filters.major&.any?
        logger.debug 'Verifying Midpoint Deficient Grade filter'
        existing_filter_element('Midpoint Deficient Grade').exists? if filters.mid_point_deficient
        logger.debug 'Verifying Minor filter'
        filters.minor.each { |m| existing_filter_element('Minor', m).exists? } if filters.minor&.any?
        logger.debug 'Verifying Transfer Student filter'
        existing_filter_element('Transfer Student').exists? if filters.transfer_student
        logger.debug 'Verifying Units Completed filter'
        filters.units_completed.each { |u| existing_filter_element('Units Completed', u).exists? } if filters.units_completed&.any?

        logger.debug 'Verifying Ethnicity filter'
        filters.ethnicity.each { |e| existing_filter_element('Ethnicity', e).exists? } if filters.ethnicity&.any?
        logger.debug 'Verifying Gender filter'
        filters.gender.each { |g| existing_filter_element('Gender', g).exists? } if filters.gender&.any?
        logger.debug 'Verifying Underrepresented Minority filter'
        existing_filter_element('Underrepresented Minority').exists? if filters.underrepresented_minority
        logger.debug 'Verifying Visa Type filter'
        filters.visa_type.each { |v| existing_filter_element('Visa Type', v).exists? } if filters.visa_type&.any?

        logger.debug 'Verifying Inactive (ASC) filter'
        existing_filter_element('Inactive (ASC)').exists? if filters.asc_inactive
        logger.debug 'Verifying Intensive (ASC) filter'
        existing_filter_element('Intensive (ASC)').exists? if filters.asc_intensive
        logger.debug 'Verifying Team (ASC) filter'
        filters.asc_team.each { |t| existing_filter_element('Team (ASC)', t.name).exists? } if filters.asc_team&.any?

        # TODO - advisors COE
        logger.debug 'Verifying Ethnicity (COE) filter'
        filters.coe_ethnicity.each { |e| existing_filter_element('Ethnicity (COE)', e).exists? } if filters.coe_ethnicity&.any?
        logger.debug 'Verifying Gender (COE) filter'
        filters.coe_gender.each { |g| existing_filter_element('Gender (COE)', g).exists? } if filters.coe_gender&.any?
        logger.debug 'Verifying Inactive (COE) filter'
        existing_filter_element('Inactive (COE)').exists? if filters.coe_inactive

        logger.debug 'Verifying Last Name filter'
        filters.last_name.each { |n| existing_filter_element('Last Name', n).exists? } if filters.last_name&.any?
        logger.debug 'Verifying My Students filter'
        filters.cohort_owner_academic_plans.each { |g| existing_filter_element('My Students', g).exists? } if filters.cohort_owner_academic_plans&.any?
        # TODO - curated groups

        logger.debug 'Verifying Underrepresented Minority filter (COE)'
        existing_filter_element('Underrepresented Minority (COE)').exists? if filters.coe_underrepresented_minority
        logger.debug 'Verifying PREP (COE) filter'
        filters.coe_prep.each { |p| existing_filter_element('PREP (COE)', p).exists? } if filters.coe_prep&.any?
        logger.debug 'Verifying Probation (COE) filter'
        existing_filter_element('Probation (COE)').exists? if filters.coe_probation
        logger.debug 'Found \'em all!'
      end
    end
  end

  # Verifies that an admit cohort's filters are visibly selected
  # @param cohort [FilteredCohort]
  def verify_admit_filters_present(cohort)
    filters = cohort.search_criteria
    verify_filters(cohort) do
      logger.debug 'Checking Freshman / Transfer filter'
      filters.freshman_or_transfer.each { |f| existing_filter_element('Freshman or Transfer', f).exists? } if filters.freshman_or_transfer
      logger.debug 'Checking Current SIR filter'
      existing_filter_element('Current SIR').exists? if filters.current_sir
      logger.debug 'Checking College filter'
      filters.college.each { |m| existing_filter_element('College', m).exists? } if filters.college
      logger.debug 'Checking XEthnic filter'
      filters.xethnic.each { |e| existing_filter_element('XEthnic', e).exists? } if filters.xethnic
      logger.debug 'Checking Hispanic filter'
      existing_filter_element('Hispanic').exists? if filters.hispanic
      logger.debug 'Checking UREM filter'
      existing_filter_element('UREM').exists? if filters.urem
      logger.debug 'Checking First Generation College filter'
      existing_filter_element('First Generation College').exists? if filters.first_gen_college
      logger.debug 'Checking Application Fee Waiver filter'
      existing_filter_element('Application Fee Waiver').exists? if filters.fee_waiver
      filters.residency.each { |r| existing_filter_element('Residency', r).exists? } if filters.residency
      logger.debug 'Checking Foster Care filter'
      existing_filter_element('Foster Care').exists? if filters.foster_care
      logger.debug 'Checking Family Is Single Parent filter'
      existing_filter_element('Family is Single Parent').exists? if filters.family_single_parent
      logger.debug 'Checking Student Is Single Parent filter'
      existing_filter_element('Student is Single Parent').exists? if filters.student_single_parent
      logger.debug 'Checking Family Dependents filter'
      filters.family_dependents.each { |f| existing_filter_element('Family Dependents', f).exists? } if filters.family_dependents
      logger.debug 'Checking Student Dependents filter'
      filters.student_dependents.each { |f| existing_filter_element('Student Dependents', f).exists? } if filters.student_dependents
      logger.debug 'Checking Re-entry Status filter'
      existing_filter_element('Re-entry Status').exists? if filters.re_entry_status
      logger.debug 'Checking Last School LCFF+ filter'
      existing_filter_element('Last School LCFF+').exists? if filters.last_school_lcff_plus
      logger.debug 'Checking Special Program CEP filter'
      filters.special_program_cep.each { |p| existing_filter_element('Special Program CEP', p).exists? } if filters.special_program_cep
      logger.debug 'Found \'em all!'
    end
  end

  # Verifies a student or admit cohort's filters with a given block of checks
  # @param cohort [FilteredCohort]
  def verify_filters(cohort, &blk)
    if cohort.search_criteria.list_filters.flatten.compact.any?
      show_filters
      wait_until(Utils.short_wait) { cohort_filter_row_elements.any? }
      wait_until(5) { yield }
    else
      unsaved_filter_apply_button_element.when_not_visible Utils.short_wait
      wait_until(1) { cohort_filter_row_elements.empty? }
    end
  end

  # EXISTING FILTERED COHORTS - Editing

  elements(:cohort_edit_button, :button, xpath: '//button[contains(@id, "edit-added-filter")]')
  button(:cohort_update_button, xpath: '//button[contains(text(), "Update")]')
  button(:cohort_update_cancel_button, xpath: '//button[contains(text(), "Cancel")]')

  def filter_controls_xpath(filter_option)
    "#{existing_filter_xpath filter_option}/following-sibling::div[2]"
  end

  def filter_edit_button(filter_option)
    button_element(xpath: "#{filter_controls_xpath filter_option}//button[contains(.,'Edit')]")
  end

  def filter_edit_cancel_button(filter_option)
    button_element(xpath: "#{filter_controls_xpath filter_option}//button[contains(.,'Cancel')]")
  end

  def filter_edit_update_button(filter_option)
    button_element(xpath: "#{filter_controls_xpath filter_option}//button[contains(.,'Update')]")
  end

  def filter_remove_button(filter_option)
    button_element(xpath: "#{filter_controls_xpath filter_option}//button[contains(.,'Remove')]")
  end

  def edit_filter(filter_option, filter_sub_option)
    logger.info "Changing '#{filter_option}' to '#{filter_sub_option}'"
    wait_for_update_and_click filter_edit_button(filter_option)
    select_new_filter_sub_option(filter_option, filter_sub_option)
    wait_for_update_and_click filter_edit_update_button(filter_option)
    filter_edit_update_button(filter_option).when_not_present 2
  end

  def remove_filter_of_type(filter_option)
    logger.info "Removing '#{filter_option}'"
    row_count = cohort_filter_row_elements.length
    wait_for_update_and_click filter_remove_button(filter_option)
    wait_until(Utils.short_wait) { cohort_filter_row_elements.length == row_count - 1 }
  end

end
