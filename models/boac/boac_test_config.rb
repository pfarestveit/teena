class BOACTestConfig < TestConfig

  include Logging

  attr_accessor :dept, :advisor, :term, :dept_students, :searches, :default_cohort, :cohort_members, :max_cohort_members

  CONFIG = BOACUtils.config

  # Basic settings for department, advisor, and student population under test
  def set_global_configs
    @dept = BOACUtils.test_dept
    advisors = BOACUtils.get_dept_advisors @dept
    asc_students = NessieUtils.get_all_asc_students

    if @dept == BOACDepartments::ASC
      @advisor = advisors.first
      @dept_students = asc_students
    elsif @dept == BOACDepartments::COE
      uid = BOACUtils.test_coe_advisor_uid
      @advisor = uid ? (advisors.find { |a| a.uid.to_i == uid }) : advisors.first
      @dept_students = NessieUtils.get_all_coe_students asc_students
    end
  end

  # Sets an existing cohort to use for testing, e.g., a team for ASC or My Students for CoE
  def set_default_cohort(team_config, max_users_config = nil)
    if @dept == BOACDepartments::ASC
      @default_cohort = NessieUtils.get_asc_teams.find { |t| t.code == team_config }
      @cohort_members = NessieUtils.get_asc_team_members(@default_cohort, @dept_students)

    elsif @dept == BOACDepartments::COE
      @default_cohort = BOACUtils.get_user_filtered_cohorts(@advisor).find { |c| c.read_only }
      @cohort_members = NessieUtils.get_coe_advisor_students(@advisor, @dept_students)
    end

    @default_cohort.member_count = @cohort_members.length if @cohort_members
    @max_cohort_members = @cohort_members[0..(max_users_config - 1)] if max_users_config
    @term = BOACUtils.assignments_term
  end

  # Configures a set of cohorts to use for filtered cohort testing
  def set_search_cohorts
    test_search_criteria = BOACUtils.get_test_search_criteria
    unless @dept == BOACDepartments::ASC
      test_search_criteria.each { |c| c.squads = nil }
      test_search_criteria.keep_if { |c| [c.levels, c.majors, c.gpa_ranges, c.units].compact.any? }
    end
    @searches = test_search_criteria.map { |c| FilteredCohort.new({:name => "Test Cohort #{test_search_criteria.index c} #{@id}", :search_criteria => c}) }
  end

  # Config for assignments testing
  def assignments
    set_global_configs
    set_default_cohort(CONFIG['assignments_team'], CONFIG['assignments_max_users'])
  end

  # Config for class page testing
  def class_pages
    set_global_configs
    set_default_cohort(CONFIG['class_page_team'], CONFIG['class_page_max_users'])
  end

  # Config for curated cohort testing
  def curated_cohorts
    set_global_configs
    set_default_cohort(CONFIG['curated_cohort_team'], CONFIG['curated_cohort_max_users'])
  end

  # Config for filtered cohort testing
  def filtered_cohorts
    set_global_configs
    set_search_cohorts
  end

  # Config for last activity testing
  def last_activity
    set_global_configs
    set_default_cohort(CONFIG['last_activity_team'], CONFIG['last_activity_max_users'])
  end

  # Config for navigation testing
  def navigation
    set_global_configs
    set_default_cohort(CONFIG['navigation_team'])
    set_search_cohorts
  end

  # Config for user search testing
  def user_search
    set_global_configs
    set_default_cohort(CONFIG['user_search_team'], CONFIG['user_search_max_users'])
  end

end
