class JunctionTestConfig < TestConfig

  include Logging

  attr_accessor :base_url,
                :courses,
                :admin,
                :sis_teacher,
                :manual_teacher,
                :lead_ta,
                :ta,
                :designer,
                :reader,
                :observer,
                :staff,
                :students,
                :wait_list_student

  CONFIG = JunctionUtils.config

  ### TEST SCRIPT CONFIGS ###

  def add_user
    test = 'course_add_user'
    set_global_configs
    set_courses test
    set_sis_teacher @courses.first
    set_manual_users test
  end

  def background_jobs_load_test
    set_global_configs
    @courses = set_courses 'create_course_site'
  end

  def course_capture
    set_global_configs
    test_user_data 'course_capture'
  end

  def course_site_creation
    test = 'create_course_site'
    set_global_configs
    set_courses test
    set_manual_users test
  end

  def e_grades_api
    set_global_configs
    set_courses 'e_grades_api'
  end

  def e_grades_export
    test = 'e_grades_export'
    set_global_configs
    set_courses test
    set_manual_users test
  end

  def mailing_lists
    test = 'mailing_lists'
    set_global_configs
    set_manual_users test
    set_manual_teacher test
  end

  def official_sections
    test = 'official_sections'
    set_global_configs
    set_courses test
    set_manual_users test
  end

  def projects
    set_global_configs
    set_project_site_roles 'create_project_site'
  end

  def rosters
    test = 'roster_photos'
    set_global_configs
    set_courses test
    set_manual_users test
  end

  def set_global_configs
    @base_url = CONFIG['base_url']
    @admin = User.new({uid: CONFIG['admin_uid']})
  end

  def bcourses_test_data
    File.join(Utils.config_dir, 'test-data-bcourses-load.json')
  end

  def junction_test_data_file
    File.join(Utils.config_dir, 'test-data-bcourses.json')
  end

  def load_junction_test_data
    JSON.parse File.read(junction_test_data_file)
  end

  ### TEST COURSES ###

  def test_course_data
    load_junction_test_data['courses']
  end

  def set_courses(test)
    @courses = test_course_data.select { |d| d['tests'][test] }.map do |c|
      Course.new c
    end
  end

  def set_sis_teacher(course)
    @sis_teacher = User.new course.teachers.first
  end

  def set_course_sections(course)
    course.sections.map { |s| Section.new s }
  end

  ### TEST USERS ###

  def test_user_data(test)
    load_junction_test_data['users'].select { |u| u['tests'][test] }
  end

  def set_user_of_role(test, role)
    user_data = test_user_data(test).find { |d| d['role'] == role }
    User.new user_data if user_data
  end

  def set_manual_teacher(test)
    @manual_teacher = set_user_of_role(test, 'Teacher')
  end

  def set_lead_ta(test)
    @lead_ta = set_user_of_role(test, 'Lead TA')
  end

  def set_ta(test)
    @ta = set_user_of_role(test, 'TA')
  end

  def set_designer(test)
    @designer = set_user_of_role(test, 'Designer')
  end

  def set_observer(test)
    @observer = set_user_of_role(test, 'Observer')
  end

  def set_reader(test)
    @reader = set_user_of_role(test, 'Reader')
  end

  def set_staff(test)
    @staff = set_user_of_role(test, 'Staff')
  end

  def set_students(test)
    student_data = test_user_data(test).select { |d| d['role'] == 'Student' }
    @students = student_data.map { |d| User.new d }
  end

  def set_wait_list_student(test)
    @wait_list_student = set_user_of_role(test, 'Waitlist Student')
  end

  def set_manual_users(test)
    set_manual_teacher test
    set_lead_ta test
    set_ta test
    set_designer test
    set_observer test
    set_reader test
    set_students test
    set_wait_list_student test
  end

  def set_project_site_roles(test)
    set_manual_teacher test
    set_ta test
    set_staff test
    set_students test
  end

end
