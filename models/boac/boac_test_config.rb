class BOACTestConfig < TestConfig

  include Logging

  CONFIG = BOACUtils.config

  attr_accessor :admits,
                :advisor,
                :attachments,
                :cohort_members,
                :default_cohort,
                :degree_templates,
                :dept,
                :drop_in_advisor,
                :drop_in_scheduler,
                :read_only_advisor,
                :test_students,
                :searchable_data,
                :searches,
                :students,
                :term

  # If a test requires a specific dept, sets that one. Otherwise, sets the globally configured dept.
  # @param dept [BOACDepartments]
  def set_dept(dept)
    @dept = dept ? dept : (BOACDepartments::DEPARTMENTS.find { |d| d.code == CONFIG['test_dept'] })
  end

  # Sets the advisor to use for the dept being tested
  def set_advisor(uid = nil)
    role = DeptMembership.new advisor_role: AdvisorRole::ADVISOR
    advisors = BOACUtils.get_dept_advisors(@dept, role)
    case @dept
      when BOACDepartments::ADMIN
        @advisor = BOACUser.new({:uid => Utils.super_admin_uid})
      when BOACDepartments::ASC, BOACDepartments::COE, BOACDepartments::L_AND_S
        @advisor = if uid
                     (advisors.find { |a| (a.uid.to_i == uid) && NessieTimelineUtils.get_advising_note_author(a.uid)})
                   else
                     advisors.find { |a| (a.depts == [@dept.code]) && NessieTimelineUtils.get_advising_note_author(a.uid) }
                   end
      else
        if block_given?
          @advisor = advisors.find { |a| yield a }
        else
          @advisor = advisors.find { |a| a.depts == [@dept.code] }
        end
    end
    if uid && (user_data = NessieTimelineUtils.get_advising_note_author(uid))
      @advisor.sis_id = user_data[:sid]
      @advisor.first_name = user_data[:first_name]
      @advisor.last_name = user_data[:last_name]
    end
    logger.warn "Advisor is UID #{@advisor.uid}"
  end

  # Sets the three user roles for testing drop-in appointments
  # @param auth_users [Array<BOACUser>]
  def set_drop_in_appt_advisors(auth_users)
    dept_advisors = auth_users.select { |u| u.depts.include?(@dept) && (u.uid.length > 1) && (!u.degree_progress_perm) }
    @advisor = dept_advisors[0]
    @advisor.dept_memberships = [DeptMembership.new(dept: @dept, advisor_role: AdvisorRole::ADVISOR)]

    @drop_in_advisor = dept_advisors[1]
    @drop_in_advisor.dept_memberships = [DeptMembership.new(dept: @dept, advisor_role: AdvisorRole::ADVISOR)]

    @drop_in_scheduler = dept_advisors[2]
    @drop_in_scheduler.dept_memberships = [DeptMembership.new(dept: @dept, advisor_role: AdvisorRole::SCHEDULER)]

    logger.warn "Advisor-only UID #{@advisor.uid}, drop-in advisor UID #{@drop_in_advisor.uid}, scheduler UID #{@drop_in_scheduler.uid}"
  end

  def set_read_only_advisor
    dept_advisors = BOACUtils.get_dept_advisors(@dept).select { |u| u.uid.length > 1 }
    @read_only_advisor = dept_advisors.find { |a| (a.uid.to_s != @advisor.uid.to_s) && NessieTimelineUtils.get_advising_note_author(a.uid) }
  end

  # Sets the complete list of potentially visible students
  def set_students(students = nil)
    @students = students || NessieUtils.get_all_students
  end

  # Basic settings for department, advisor, and student population under test. Specifying a department will override the
  # department in the settings file.
  # @param dept [BOACDepartments]
  def set_base_configs(dept = nil)
    set_dept dept
    set_advisor
    set_students
  end

  # Sets the complete list of potentially visible admits
  def set_admits
    @admits = NessieUtils.get_admits
  end

  # Returns all searchable admit data. Unless a current file containing all student data already exists, obtain
  # the current data from RDS.
  # @return [Array<Hash>]
  def set_admit_searchable_data
    @searchable_data = NessieUtils.searchable_admit_data
  end

  # Sets a cohort to use as a default group of students for testing
  def set_default_cohort(filter = nil)
    @default_cohort = FilteredCohort.new({})
    unless filter
      filter = CohortFilter.new
      filter.major = CONFIG['test_default_cohort_major']
    end
    @default_cohort.search_criteria = filter
    filtered_sids = NessieFilterUtils.get_cohort_result(self, filter)
    @cohort_members = @students.select { |s| filtered_sids.include? s.sis_id }
    @default_cohort.name = "Cohort #{@id}"
    @default_cohort.member_count = @cohort_members.length
  end

  # Selects only the first n cohort members for testing. If shuffle setting is true, different students will be in each
  # test run; otherwise the same ones.
  # @param config [Integer]
  def set_test_students(config, opts = {})
    @test_students = if (uids = ENV['UIDS'])
                       # Running tests against a specific set of students
                       uids = uids.split
                       @students.select { |s| uids.include? s.uid }

                     elsif @cohort_members
                       # Running tests against a cohort of students (i.e., a list presented in the UI)
                       BOACUtils.shuffle_max_users ? @cohort_members.shuffle! : @cohort_members.sort_by(&:last_name)
                       @cohort_members[0..(config - 1)]

                     elsif opts[:with_notes]
                       # Running tests against a set of students who represent different note sources
                       boa_sids = NessieUtils.get_all_sids
                       asc_note_sids = boa_sids & NessieTimelineUtils.get_sids_with_notes_of_src(TimelineRecordSource::ASC)
                       logger.info "There are #{asc_note_sids.length} students with ASC notes"
                       boa_note_sids = boa_sids & BOACUtils.get_sids_with_notes_of_src_boa
                       logger.info "There are #{boa_note_sids.length} students with BOA notes"
                       data_note_sids = boa_sids & NessieTimelineUtils.get_sids_with_notes_of_src(TimelineRecordSource::DATA)
                       logger.info "There are #{data_note_sids.length} students with Data Science notes"
                       e_and_i_note_sids = boa_sids & NessieTimelineUtils.get_sids_with_notes_of_src(TimelineRecordSource::E_AND_I)
                       logger.info "There are #{e_and_i_note_sids.length} students with E&I notes"
                       e_form_sids = boa_sids & NessieTimelineUtils.get_sids_with_e_forms
                       logger.info "There are #{e_form_sids.length} students with eForms"
                       sis_note_sids = boa_sids & NessieTimelineUtils.get_sids_with_notes_of_src(TimelineRecordSource::SIS)
                       logger.info "There are #{sis_note_sids.length} students with SIS notes that have attachments"
                       [asc_note_sids, boa_note_sids, data_note_sids, e_and_i_note_sids, sis_note_sids].each { |s| s.shuffle! } if BOACUtils.shuffle_max_users
                       range = 0..(config - 1)
                       test_sids = (asc_note_sids[range] + boa_note_sids[range] + data_note_sids[range] +
                         e_and_i_note_sids[range] + e_form_sids[range] + sis_note_sids[range]).uniq
                       @students.select { |s| test_sids.include? s.sis_id }

                     elsif opts[:with_appts]
                       boa_sids = NessieUtils.get_all_sids
                       sis_appts_sids = boa_sids & NessieTimelineUtils.get_sids_with_sis_appts
                       logger.info "There are #{sis_appts_sids.length} students with SIS appointments"
                       ycbm_appts_sids = boa_sids & NessieTimelineUtils.get_sids_with_ycbm_appts
                       logger.info "There are #{ycbm_appts_sids.length} students with YCBM appointments"
                       [sis_appts_sids, ycbm_appts_sids].each { |a| a.shuffle! } if BOACUtils.shuffle_max_users
                       test_sids = (sis_appts_sids[0..(config - 1)] + ycbm_appts_sids[0..(config - 1)]).uniq
                       @students.select { |s| test_sids.include? s.sis_id }
                     else
                       # Running tests against a random set of students, plus optional selected students
                       students = @students.shuffle[0..(config - 1)]
                       if opts[:with_standing]
                         test_sids = []
                         AcademicStanding::STATUSES.each { |s| test_sids << NessieUtils.get_sids_with_standing(s, BOACUtils.term_code).first }
                         test_sids = test_sids.compact & NessieUtils.get_all_sids
                         test_students = @students.select { |s| test_sids.include? s.sis_id }
                         students = students + test_students
                       end
                       students.uniq
                     end
    logger.warn "Test UIDs: #{@test_students.map &:uid}"
  end

  # Determines the set of admits to use for testing
  # @param config [Integer]
  def set_test_admits(config)
    @test_students = if (sids = ENV['SIDS'])
                       # Running tests against a specific set of admits
                       @admits.select { |s| sids.split.include? s.sis_id }
                     else
                       # Running tests against a random set of admits
                       @admits.shuffle[0..(config - 1)]
                     end
  end

  def get_test_data
    test_data_file_name = 'test-data-boac.json'
    override_test_data = File.exist?(override_path = File.join(Utils.config_dir, test_data_file_name))
    test_data_file = override_test_data ? override_path : File.expand_path("test_data/#{test_data_file_name}", Dir.pwd)
    JSON.parse File.read(test_data_file)
  end

  # Configures a set of cohorts to use for filtered cohort testing. If a test data override file exists in the config override dir,
  # then uses that to create the filters. Otherwise, uses the default test data.
  def set_search_cohorts(opts = {})

    test_data = get_test_data['filters']

    if opts[:students]
      filters = test_data['students'].map do |data|
        filter = CohortFilter.new
        filter.set_test_filters(data, @dept)
        filter
      end
    elsif opts[:admits]
      filters = test_data['admits'].map do |data|
        filter = CohortAdmitFilter.new
        filter.set_test_filters data
        filter
      end
    else
      logger.error 'Unable to determine search cohorts'
      fail
    end

    # Get rid of empty filter sets (e.g., filtering only for teams but the advisor is CoE)
    filters.delete_if do |f|
      filter_options = f.instance_variables.map { |variable| f.instance_variable_get variable }
      filter_options.delete_if { |value| value.nil? || (value.instance_of?(Array) && value.empty?) }
      filter_options.empty?
    end
    @searches = filters.map { |c| FilteredCohort.new({:name => "Test Cohort #{filters.index c} #{@id}", :search_criteria => c}) }
  end

  def set_degree_templates
    test_data = get_test_data['degree_checks']
    @degree_templates = test_data.map do |data|
      template = DegreeProgressTemplate.new data
      template.set_template_content @id
      template
    end
  end

  def set_note_attachments
    attachment_filenames = Dir.entries(Utils.assets_dir).reject { |f| %w(. .. .DS_Store).include? f }
    @attachments = attachment_filenames.map do |f|
      file = File.new Utils.asset_file_path(f)
      Attachment.new({:file_name => f, :file_size => file.size})
    end
  end

  # Uses the secondary Chrome profile if config set to true
  # @return [String]
  def chrome_profile
    if Utils.use_optional_chrome_profile?
      logger.warn 'Using the secondary Chrome profile'
      Utils.optional_chrome_profile_dir
    end
  end


  ### CONFIGURATION FOR SPECIFIC TEST SCRIPTS ###

  # Config for admit page testing
  def admit_pages
    set_dept BOACDepartments::ZCEEE
    set_advisor
    set_admits
    set_test_admits CONFIG['sis_data_max_users']
  end

  # Config for advising note content testing
  def appts_content
    set_base_configs
    set_test_students(CONFIG['notes_max_users'], {with_appts: true})
  end

  # Config for assignments testing
  def assignments
    set_base_configs
    set_test_students CONFIG['assignments_max_users']
    @term = CONFIG['assignments_term']
  end

  # Config for class page testing
  def class_pages
    set_base_configs
    set_test_students CONFIG['class_page_max_users']
  end

  # Config for curated group testing
  def curated_groups
    set_base_configs
    set_default_cohort
    set_test_students 50
  end

  def degree_progress
    set_base_configs BOACDepartments::COE
    NessieTimelineUtils.set_advisor_data @advisor
    filter = CohortFilter.new
    filter.major = BOACUtils.degree_major
    filter.units_completed = ['90 - 119']
    set_default_cohort filter
    set_read_only_advisor
    NessieTimelineUtils.set_advisor_data @read_only_advisor
    set_degree_templates
  end

  # Config for drop-in appointment testing
  def drop_in_appts(auth_users, dept)
    set_dept dept
    set_drop_in_appt_advisors auth_users
    set_students
  end

  # Config for filtered admit cohort testing
  def filtered_admits
    set_dept BOACDepartments::ZCEEE
    set_advisor
    set_search_cohorts admits: true
    set_admit_searchable_data
  end

  # Config for filtered cohort testing
  def filtered_cohorts
    set_base_configs BOACDepartments::ADMIN
    set_search_cohorts students: true

    # Set a default cohort with all possible filters to exercise editing and removing filters
    filters = {
        :academic_standing => ['2208-DIS'],
        :college => ((@dept == BOACDepartments::COE) ? ['Undergrad Engineering'] : ['Undergrad Letters & Science']),
        :gpa => [JSON.parse("{\"min\": \"3.50\", \"max\": \"4\"}")],
        :gpa_last_term => [JSON.parse("{\"min\": \"2\", \"max\": \"3.80\"}")],
        :grading_basis_epn => [CONFIG['term_code']],
        :level => %w(40 10),
        :units_completed => ['90 - 119'],
        :holds => true,
        :intended_major => ['English BA'],
        :major => ['Electrical Eng & Comp Sci BS', 'Letters & Sci Undeclared UG'],
        :minor => ['French UG'],
        :transfer_student => true,
        :entering_terms => [CONFIG['assignments_term']],
        :expected_grad_terms => [CONFIG['term_code']],
        :gender => ['Male', 'Decline to State'],
        :last_name => [JSON.parse("{\"min\": \"A\", \"max\": \"Z\"}")],
        :underrepresented_minority => true,
        :ethnicity => ['Puerto Rican', 'Not Specified'],
        :visa_type => ['Other'],
        :asc_inactive => true,
        :asc_intensive => true,
        :asc_team => [Squad::MCR],
        :coe_advisor => [BOACUtils.get_dept_advisors(BOACDepartments::COE).first.uid.to_s],
        :coe_ethnicity => %w(H V),
        :coe_gender => ['F'],
        :coe_underrepresented_minority => true,
        :coe_prep => ['PREP', 'T-PREP eligible'],
        :coe_inactive => true,
        :coe_probation => true
    }

    advisor_plans = NessieUtils.get_academic_plans(@advisor)
    if advisor_plans.any?
      filters[:cohort_owner_academic_plans] = [advisor_plans.first]
    else
      logger.warn "Couldn't find any current academic plans for advisor #{@advisor.uid}; skipping the 'My Students' filter"
    end

    editing_test_search_criteria = CohortFilter.new
    editing_test_search_criteria.set_custom_filters(filters)
    @default_cohort = FilteredCohort.new({:name => "Default cohort #{@id}", :search_criteria => editing_test_search_criteria})
  end

  # Config for curated-groups-as-cohort-filter testing
  def filtered_groups
    set_base_configs
    set_search_cohorts students: true
  end

  # Config for filtered cohort history testing
  def filtered_history
    set_base_configs
  end

  # Config for non-current student testing
  def inactive_students
    set_base_configs
  end

  # Config for last activity testing
  def last_activity
    set_base_configs
    set_test_students CONFIG['last_activity_max_users']
  end

  # Config for advising note content testing
  def note_content
    set_base_configs
    set_test_students(CONFIG['notes_max_users'], {with_notes: true})
  end

  # Config for page navigation testing
  def navigation
    set_base_configs
    set_test_students CONFIG['class_page_max_users']
  end

  # Config for note management testing (create, edit, delete)
  def note_management
    set_note_attachments
    set_base_configs
    BOACUtils.set_advisor_data @advisor
  end

  # Config for testing batch note creation
  def batch_note_management
    set_note_attachments
    set_base_configs
    set_default_cohort
    BOACUtils.set_advisor_data @advisor
  end

  # Config for testing note templates
  def note_templates
    set_base_configs BOACDepartments::L_AND_S
    set_default_cohort
    set_note_attachments
    BOACUtils.set_advisor_data @advisor
  end

  # Config for admit search tests
  def search_admits
    set_dept BOACDepartments::ZCEEE
    set_advisor
    set_admits
    set_test_admits CONFIG['search_max_users']
    set_admit_searchable_data
  end

  # Config for appointment search tests
  def search_appointments
    set_base_configs
    set_test_students(CONFIG['search_max_users'], {with_appts: true})
    logger.warn "Test UIDS: #{@test_students.map &:uid}"
  end

  # Config for class search tests
  def search_classes
    set_base_configs
    set_test_students CONFIG['search_max_users']
  end

  # Config for note search tests
  def search_notes
    set_base_configs
    set_test_students(CONFIG['search_max_users'], {with_notes: true})
  end

  # Config for student search tests
  def search_students
    set_base_configs
    set_test_students CONFIG['search_max_users']
  end

  # Config for SIS student data testing
  def sis_student_data
    set_base_configs
    set_test_students(CONFIG['sis_data_max_users'], with_standing: true)
  end

  # Config for SIS admit data testing
  def sis_admit_data
    set_base_configs
    set_admits
    set_test_admits CONFIG['sis_data_max_users']
  end

  def topic_mgmt
    set_base_configs BOACDepartments::L_AND_S
  end

  # Config for user management tests on the admin page
  def user_mgmt
    set_dept BOACDepartments::ADMIN
    set_advisor
    set_students
  end

  # Config for admin user role testing
  def user_role_admin
    set_base_configs BOACDepartments::ADMIN
    set_search_cohorts students: true
  end

  # Config for advisor user role testing
  def user_role_advisor
    set_students
  end

  # Config for ASC user role testing
  # @param user_role_config [BOACTestConfig]
  def user_role_asc(user_role_config)
    set_dept BOACDepartments::ASC
    set_advisor
    set_students user_role_config.students
  end

  # Config for CoE user role testing
  # @param user_role_config [BOACTestConfig]
  def user_role_coe(user_role_config)
    set_dept BOACDepartments::COE
    set_advisor
    set_students user_role_config.students
  end

  # Config for director user role testing
  def user_role_director
    @advisor = BOACUtils.get_authorized_users.find { |u| u.dept_memberships.find { |m| m.advisor_role == AdvisorRole::DIRECTOR } }
    set_students
    set_test_students(CONFIG['notes_max_users'], with_notes: true)
  end

  # Config for L&S user role testing
  # @param user_role_config [BOACTestConfig]
  def user_role_l_and_s(user_role_config)
    set_dept BOACDepartments::L_AND_S
    set_advisor
    set_students user_role_config.students
  end

  def user_role_notes_only
    set_dept BOACDepartments::NOTES_ONLY
    set_students
    set_test_students(1, {with_notes: true})
  end

end
