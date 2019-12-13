class BOACTestConfig < TestConfig

  include Logging

  CONFIG = BOACUtils.config

  attr_accessor :advisor,
                :attachments,
                :cohort_members,
                :default_cohort,
                :dept,
                :drop_in_advisor,
                :drop_in_scheduler,
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
    role = AdvisorRole.new is_advisor: true
    advisors = BOACUtils.get_dept_advisors(@dept, role)
    case @dept
      when BOACDepartments::ADMIN
        @advisor = BOACUser.new({:uid => Utils.super_admin_uid})
      when BOACDepartments::ASC, BOACDepartments::COE, BOACDepartments::L_AND_S
        @advisor = uid ? (advisors.find { |a| a.uid.to_i == uid }) : advisors.find { |a| a.depts == [@dept.code] }
        dept_id = BOACUtils.get_dept_id @dept
        BOACUtils.convert_user_to_advisor(@dept, dept_id, @advisor)
      else
        if block_given?
          @advisor = advisors.find { |a| yield a }
        else
          @advisor = advisors.find { |a| a.depts == [@dept.code] }
        end
    end
    if uid && (user_data = NessieUtils.get_advising_note_author(uid))
      @advisor.sis_id = user_data[:sid]
      @advisor.first_name = user_data[:first_name]
      @advisor.last_name = user_data[:last_name]
    end
    logger.warn "Advisor is UID #{@advisor.uid}"
  end

  # Sets the three user roles for testing drop-in appointments
  # @param auth_users [Array<BOACUser>]
  def set_drop_in_appt_advisors(auth_users)
    dept_advisors = auth_users.select { |u| u.depts.include? @dept }
    @advisor = dept_advisors[0]
    @drop_in_advisor = dept_advisors[1]
    @drop_in_scheduler = dept_advisors[2]

    dept_id = BOACUtils.get_dept_id @dept
    BOACUtils.convert_user_to_advisor(@dept, dept_id, @advisor)
    BOACUtils.convert_user_to_available_drop_in(@dept, dept_id, @drop_in_advisor)
    BOACUtils.convert_user_to_scheduler(@dept, dept_id, @drop_in_scheduler)
    logger.warn "Advisor-only UID #{@advisor.uid}, drop-in advisor UID #{@drop_in_advisor.uid}, scheduler UID #{@drop_in_scheduler.uid}"
  end

  # Sets the complete list of potentially visible students
  def set_students(students = nil)
    @students = students || NessieUtils.get_all_students
  end

  # Returns all searchable student data. Unless a current file containing all student data already exists, obtain
  # the current data from Redshift.
  # @param all_students [Array<BOACUser>]
  # @return [Array<Hash>]
  def set_student_searchable_data(all_students)
    # Get the searchable data for all students.
    student_sids = @students.map &:sis_id
    @searchable_data = NessieUtils.searchable_student_data(all_students).select { |u| student_sids.include? u[:sid] }
  end

  # Basic settings for department, advisor, and student population under test. Specifying a department will override the
  # department in the settings file.
  # @param dept [BOACDepartments]
  def set_global_configs(dept = nil)
    set_dept dept
    set_advisor
    set_students
    set_student_searchable_data @students
  end

  # Sets a cohort to use as a default group of students for testing
  def set_default_cohort
    @default_cohort = FilteredCohort.new({})
    filter = CohortFilter.new
    filter.major = CONFIG['test_default_cohort_major']
    @default_cohort.search_criteria = filter
    student_sids = @students.map &:sis_id
    filtered_searchable_data = @searchable_data.select { |d| (filter.major & d[:major]).any? }
    filtered_searchable_sids = filtered_searchable_data.map { |d| d[:sid] }

    @cohort_members = @students.select { |s| student_sids.include?(s.sis_id) && filtered_searchable_sids.include?(s.sis_id) }
    @default_cohort.name = "Cohort #{@id}"
    @default_cohort.member_count = @cohort_members.length
  end

  # Selects only the first n cohort members for testing. If shuffle setting is true, different students will be in each
  # test run; otherwise the same ones.
  # @param config [Integer]
  def set_test_students(config)
    @test_students = if (uids = ENV['UIDS'])
                       @students.select { |s| uids.split.include? s.uid }
                     else
                       BOACUtils.shuffle_max_users ? @cohort_members.shuffle! : @cohort_members.sort_by(&:last_name)
                       @cohort_members[0..(config - 1)]
                     end
    logger.warn "Test UIDs: #{@test_students.map &:uid}"
  end

  # Configures a set of cohorts to use for filtered cohort testing. If a test data override file exists in the config override dir,
  # then uses that to create the filters. Otherwise, uses the default test data.
  def set_search_cohorts

    test_data_file_name = 'test-data-boac.json'
    override_test_data = File.exist?(override_path = File.join(Utils.config_dir, test_data_file_name))
    test_data_file = override_test_data ? override_path : File.expand_path("test_data/#{test_data_file_name}", Dir.pwd)
    test_data = JSON.parse File.read(test_data_file)

    filters = test_data['filters'].map do |data|
      filter = CohortFilter.new
      filter.set_test_filters(data, @dept)
      filter
    end
    # Get rid of empty filter sets (e.g., filtering only for teams but the advisor is CoE)
    filters.delete_if do |f|
      filter_options = f.instance_variables.map { |variable| f.instance_variable_get variable }
      filter_options.delete_if { |value| value.nil? || (value.instance_of?(Array) && value.empty?) }
      filter_options.empty?
    end
    @searches = filters.map { |c| FilteredCohort.new({:name => "Test Cohort #{filters.index c} #{@id}", :search_criteria => c}) }
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

  # Config for assignments testing
  def assignments
    set_global_configs
    set_default_cohort
    set_test_students CONFIG['assignments_max_users']
    @term = CONFIG['assignments_term']
  end

  # Config for class page testing
  def class_pages
    set_global_configs
    set_default_cohort
    set_test_students CONFIG['class_page_max_users']
  end

  # Config for curated group testing
  def curated_groups
    set_global_configs
    set_default_cohort
    set_test_students 50
  end

  # Config for drop-in appointment testing
  def drop_in_appts(auth_users, dept)
    set_dept dept
    set_drop_in_appt_advisors auth_users
    set_students
  end

  # Config for filtered cohort testing
  def filtered_cohorts
    set_global_configs BOACDepartments::ADMIN
    set_search_cohorts

    # Set a default cohort with all possible filters to exercise editing and removing filters
    filters = {
        :gpa => [JSON.parse("{\"min\": \"3.50\", \"max\": \"4\"}")],
        :gpa_last_term => [JSON.parse("{\"min\": \"2\", \"max\": \"3.80\"}")],
        :level => ['Senior (90+ Units)'],
        :units_completed => ['90 - 119'],
        :major => ((@dept == BOACDepartments::COE) ? ['Electrical Eng & Comp Sci BS'] : ['Letters & Sci Undeclared UG']),
        :transfer_student => true,
        :entering_terms => [CONFIG['term_code']],
        :expected_grad_terms => [CONFIG['term_code']],
        :gender => ['Male'],
        :last_name => [JSON.parse("{\"min\": \"A\", \"max\": \"Z\"}")],
        :underrepresented_minority => true,
        :ethnicity => ['Puerto Rican'],
        :asc_inactive => true,
        :asc_intensive => true,
        :asc_team => [Squad::MCR],
        :coe_advisor => [BOACUtils.get_dept_advisors(BOACDepartments::COE).first.uid.to_s],
        :coe_ethnicity => ['Chinese / Chinese-American'],
        :coe_gender => ['Female'],
        :coe_underrepresented_minority => true,
        :coe_prep => ['PREP'],
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

  # Config for non-current student testing
  def inactive_students
    set_global_configs
  end

  # Config for last activity testing
  def last_activity
    set_global_configs
    set_default_cohort
    set_test_students CONFIG['last_activity_max_users']
  end

  # Config for advising note content testing
  def note_content
    set_global_configs
    set_default_cohort
    @test_students = if (uids = ENV['UIDS'])
                       @students.select { |s| uids.split.include? s.uid.to_s }
                     else
                       boa_sids = NessieUtils.get_all_sids
                       asc_note_sids = boa_sids & NessieUtils.get_sids_with_notes_of_src(NoteSource::ASC)
                       logger.info "There are #{asc_note_sids.length} students with ASC notes"
                       e_and_i_note_sids = boa_sids & NessieUtils.get_sids_with_notes_of_src(NoteSource::E_AND_I)
                       logger.info "There are #{e_and_i_note_sids.length} students with E&I notes"
                       sis_note_sids = boa_sids & NessieUtils.get_sids_with_notes_of_src(NoteSource::SIS)
                       logger.info "There are #{sis_note_sids.length} students with SIS notes"
                       [asc_note_sids, e_and_i_note_sids, sis_note_sids].each { |s| s.shuffle! } if BOACUtils.shuffle_max_users
                       max = CONFIG['notes_max_users']
                       test_sids = (asc_note_sids[0..(max - 1)] + e_and_i_note_sids[0..(max - 1)] + sis_note_sids[0..(max - 1)]).uniq
                       @students.select { |s| test_sids.include? s.sis_id }
                     end
    logger.warn "Test UIDS: #{@test_students.map &:uid}"
  end

  # Config for page navigation testing
  def navigation
    set_global_configs
    set_default_cohort
    set_test_students CONFIG['class_page_max_users']
  end

  # Config for note management testing (create, edit, delete)
  def note_management
    set_note_attachments
    set_global_configs
  end

  # Config for testing batch note creation
  def batch_note_management
    set_note_attachments
    set_global_configs
    set_default_cohort
  end

  # Config for testing note templates
  def note_templates
    set_global_configs BOACDepartments::L_AND_S
    set_default_cohort
    set_note_attachments
  end

  # Config for user search testing
  def search
    set_global_configs
    set_default_cohort
    set_test_students CONFIG['search_max_users']
  end

  # Config for SIS data testing
  def sis_data
    set_global_configs
    set_default_cohort
    set_test_students CONFIG['sis_data_max_users']
  end

  # Config for user management tests on the admin page
  def user_mgmt
    set_dept BOACDepartments::ADMIN
    set_advisor
  end

  # Config for admin user role testing
  def user_role_admin
    set_global_configs BOACDepartments::ADMIN
    set_search_cohorts
  end

  # Config for advisor user role testing
  def user_role_advisor
    set_students
    set_student_searchable_data @students
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

  # Config for L&S user role testing
  # @param user_role_config [BOACTestConfig]
  def user_role_l_and_s(user_role_config)
    set_dept BOACDepartments::L_AND_S
    set_advisor
    set_students user_role_config.students
  end

  def user_role_notes_only
    set_dept BOACDepartments::NOTES_ONLY
    set_advisor { |advisor| advisor.can_access_canvas_data == 'f' && advisor.depts.length == 1 }
    set_students
  end

end
