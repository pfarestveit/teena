class RipleyTestConfig < TestConfig

  include Logging

  attr_accessor :base_url,
                :courses,
                :sis_teacher,
                :manual_teacher

  CONFIG = RipleyUtils.config

  def add_user
    test = 'course_add_user'
    set_global_configs
    set_courses
    set_sis_teacher @courses.first
    set_manual_users test
    @courses.each { |c| c.create_site_workflow = 'self' }
  end

  def course_site_creation
    test = 'create_course_site'
    set_global_configs
    set_courses
    set_manual_users test
  end

  def e_grades_export
    test = 'e_grades_export'
    set_global_configs
    set_courses
    set_manual_users test
  end

  def e_grades_validation
    set_global_configs
    set_courses
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
    set_courses
    set_manual_users test
    course = @courses.first
    course.create_site_workflow = 'self'
    course.sections = course.sections.map { |s| Section.new s }
    set_sis_teacher course
  end

  def projects
    set_global_configs
    set_project_site_roles 'create_project_site'
  end

  def roster_photos
    test = 'roster_photos'
    set_global_configs
    set_courses
    set_manual_users test
    @courses.each { |c| c.create_site_workflow = 'self' }
  end

  def user_provisioning
    set_global_configs
    set_manual_users 'user_prov'
  end

  def set_global_configs
    @base_url = CONFIG['base_url']
    @admin = User.new({uid: CONFIG['admin_uid']})
    set_test_user_data junction_test_data_file
  end

  ### COURSES ###

  def set_courses
    prefixes = CONFIG['course_prefixes']
    current_term = Utils.term_name_to_sis_code RipleyUtils.term_name
    current_term_courses = prefixes.map { |p| RipleyUtils.get_test_course(current_term, p) }
    next_term = RipleyUtils.next_term_code current_term
    next_term_courses = prefixes.map { |p| RipleyUtils.get_test_course(next_term, p) }
    @courses = current_term_courses + next_term_courses
    @courses.compact!

    ta_course = nil
    @courses.find do |c|
      secondaries = c.sections.reject &:primary
      ta_section = secondaries.find { |s| s.instructors.any? && (c.teachers & s.instructors).empty? }
      if ta_section
        ta = ta_section.instructors.first
        sections = secondaries.select { |s| s.instructors.include? ta }
        ta_course = Course.new code: ta_section.course,
                               title: c.title,
                               term: c.term,
                               sections: sections,
                               teachers: [ta]
      end
    end
    @courses << ta_course if ta_course
  end

  def set_course_sections(course)
    course.sections = course.sections.map { |s| Section.new s }
  end

  ### USERS ###

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
