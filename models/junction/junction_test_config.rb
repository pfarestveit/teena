class JunctionTestConfig < TestConfig

  include Logging

  attr_accessor :base_url,
                :courses,
                :sis_teacher,
                :manual_teacher

  CONFIG = JunctionUtils.config

  ### TEST SCRIPT CONFIGS ###

  def add_user
    test = 'course_add_user'
    set_global_configs
    set_courses test
    set_sis_teacher @courses.first
    set_manual_users test
    @courses.each { |c| c.create_site_workflow = 'self' }
  end

  def background_jobs_load_test
    set_global_configs
    @courses = set_courses 'create_course_site'
  end

  def course_capture
    set_global_configs
    test_specific_user_data 'course_capture'
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
    @courses.each { |c| c.create_site_workflow = 'self' }
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
    @courses.each { |c| c.create_site_workflow = 'self' }
  end

  def user_prov
    set_global_configs
    set_manual_users 'user_prov'
  end

  def set_global_configs
    @base_url = CONFIG['base_url']
    @admin = User.new({uid: CONFIG['admin_uid']})
    set_test_course_data junction_test_data_file
    set_test_user_data junction_test_data_file
  end

  def junction_test_data_file
    File.join(Utils.config_dir, 'test-data-bcourses.json')
  end

  ### TEST COURSES ###

  def set_courses(test)
    set_test_course_data junction_test_data_file
    @courses = @test_course_data.select { |d| d['tests'][test] }.map { |c| Course.new c }
  end

  def set_course_sections(course)
    course.sections.map { |s| Section.new s }
  end

  ### TEST USERS ###

  def set_sis_teacher(course)
    @sis_teacher = User.new course.teachers.first
  end

  def set_manual_teacher(test)
    @manual_teacher = set_user_of_role(test, 'Teacher')
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
