class BOACTestConfig < TestConfig

  include Logging

  attr_accessor :dept, :advisor, :term, :dept_students, :searches, :default_cohort, :cohort_members, :max_cohort_members

  CONFIG = BOACUtils.config

  # Basic settings for department, advisor, and student population under test. Specifying a department will override the
  # department in the settings file.
  # @param all_students [Array<BOACUser>]
  # @param dept [BOACDepartments]
  def set_global_configs(all_students, dept = nil)
    @dept = dept ? dept : BOACUtils.test_dept
    advisors = BOACUtils.get_dept_advisors @dept

    case @dept
      when BOACDepartments::ADMIN
        @advisor = BOACUser.new({:uid => Utils.super_admin_uid})
      when BOACDepartments::ASC
        @advisor = advisors.first
      when BOACDepartments::COE
        uid = BOACUtils.test_coe_advisor_uid
        @advisor = uid ? (advisors.find { |a| a.uid.to_i == uid }) : advisors.first
      else
        logger.error 'What kinda department is that??'
        fail
    end

    @dept_students = if @dept == BOACDepartments::ADMIN
                       all_students
                     else
                       all_students.select do |s|
                         (s.depts.select { |d| d == @dept }).any?
                       end
                     end
  end

  # Sets an existing cohort to use for testing, e.g., a team for ASC and admin or My Students for CoE
  def set_default_cohort(team_config, max_users_config = nil)
    case @dept
      when BOACDepartments::COE
        @default_cohort = BOACUtils.get_user_filtered_cohorts(@advisor).find { |c| c.read_only }
        @cohort_members = NessieUtils.get_coe_advisor_students(@advisor, @dept_students)
      else
        @default_cohort = NessieUtils.get_asc_teams.find { |t| t.code == team_config }
        logger.debug "Default cohort is #{@default_cohort.name}"
        @cohort_members = NessieUtils.get_asc_team_members(@default_cohort, @dept_students)
    end

    @default_cohort.member_count = @cohort_members.length if @cohort_members
    @max_cohort_members = @cohort_members[0..(max_users_config - 1)] if max_users_config
    @term = BOACUtils.assignments_term
  end

  # Configures a set of cohorts to use for filtered cohort testing
  def set_search_cohorts
    test_data_file = File.join(Utils.config_dir, 'test-data-boac.json')
    test_data = JSON.parse File.read(test_data_file)
    filters = test_data['filters'].map do |data|
      filter = CohortFilter.new
      filter.set_test_filters(data, @dept)
      filter
    end
    # Get rid of empty filter sets (e.g., filtering only for teams but the advisor is CoE)
    filters.delete_if do |f|
      filter_options = f.instance_variables.map { |variable| f.instance_variable_get variable }
      filter_options.delete_if { |value| value.nil? || value.empty? }
      filter_options.empty?
    end
    @searches = filters.map { |c| FilteredCohort.new({:name => "Test Cohort #{filters.index c} #{@id}", :search_criteria => c}) }
  end

  # Config for assignments testing
  def assignments(all_students)
    set_global_configs all_students
    set_default_cohort(CONFIG['assignments_team'], CONFIG['assignments_max_users'])
  end

  # Config for class page testing
  def class_pages(all_students)
    set_global_configs all_students
    set_default_cohort(CONFIG['class_page_team'], CONFIG['class_page_max_users'])
  end

  # Config for curated cohort testing
  def curated_cohorts(all_students)
    set_global_configs all_students
    set_default_cohort(CONFIG['curated_cohort_team'], CONFIG['curated_cohort_max_users'])
    if @dept == BOACDepartments::COE
      @cohort_members = test.cohort_members[0..49]
      @default_cohort.name = 'My Students'
    elsif @dept == BOACDepartments::ASC
      @cohort_members.keep_if &:active_asc
    end
  end

  # Config for filtered cohort testing
  def filtered_cohorts(all_students)
    set_global_configs all_students
    set_search_cohorts
  end

  # Config for last activity testing
  def last_activity(all_students)
    set_global_configs all_students
    set_default_cohort(CONFIG['last_activity_team'], CONFIG['last_activity_max_users'])
  end

  # Config for navigation testing
  def navigation(all_students)
    set_global_configs all_students
    set_default_cohort(CONFIG['navigation_team'])
    set_search_cohorts
  end

  # Config for SIS data testing, currently only for ASC students
  def team_sis_data(all_students)
    set_global_configs(all_students, BOACDepartments::ASC)
    set_default_cohort(CONFIG['sis_data_team'])
  end

  # Config for admin user role testing
  def user_role_admin(all_students)
    set_global_configs(all_students, BOACDepartments::ADMIN)
    set_search_cohorts
  end

  # Config for ASC user role testing
  def user_role_asc(all_students)
    set_global_configs(all_students, BOACDepartments::ASC)
    set_search_cohorts
  end

  # Config for CoE user role testing
  def user_role_coe(all_students)
    set_global_configs(all_students, BOACDepartments::COE)
    set_default_cohort nil
    set_search_cohorts
  end

  # Config for user search testing
  def user_search
    set_global_configs
    set_default_cohort(CONFIG['user_search_team'], CONFIG['user_search_max_users'])
  end

end
