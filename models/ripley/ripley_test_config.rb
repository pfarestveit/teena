class RipleyTestConfig < TestConfig

  include Logging

  attr_accessor :base_url,
                :course_sites,
                :courses,
                :current_term,
                :manual_teacher,
                :next_term

  CONFIG = RipleyUtils.config

  def initialize(test_name = nil)
    super
    @base_url = RipleyUtils.base_url
    @current_term = RipleyUtils.current_term
    @next_term = RipleyUtils.next_term @current_term
  end

  def add_user
    global_configs
    get_single_test_site
    # TODO set_manual_users
    @courses.each { |c| c.create_site_workflow = 'self' }
  end

  def course_site_creation
    global_configs
    get_multiple_test_sites
    # TODO set_manual_users
  end

  def e_grades_export
    global_configs
    get_e_grades_test_sites
    # TODO set_manual_users
  end

  def e_grades_validation
    global_configs
    get_e_grades_test_sites
    # TODO set_manual_users
  end

  def mailing_lists
    global_configs
    # TODO set_manual_users
  end

  def official_sections
    global_configs
    get_single_test_site
    # TODO set_manual_users
  end

  def projects
    global_configs
    # TODO set_project_site_roles 'create_project_site'
  end

  def roster_photos
    global_configs
    get_single_test_site
    # TODO set_manual_users
  end

  def user_provisioning
    global_configs
    # TODO set_manual_users
  end

  ### GLOBAL CONFIG ###

  def global_configs
    @admin = User.new uid: CONFIG['admin_uid']
    @base_url = CONFIG['base_url']
  end

  # COURSE SITES

  def get_multiple_test_sites
    set_sis_courses
    @course_sites = @courses.map do |c|
      workflow = (c.sections.select(&:primary).length > 1) ? 'ccn' : 'uid'
      CourseSite.new site_id: "#{@id} #{c.term.name} #{c.code}",
                     abbreviation: "#{@id} #{c.term.name} #{c.code}",
                     course: c,
                     create_site_workflow: workflow,
                     sections: c.sections
    end
  end

  def get_single_test_site
    get_multiple_test_sites
    course_site = @course_sites.find { |site| site.course.sections(&:primary).length > 1 && (site.course.sections.select { |s| !s.primary }).any? }
    primary = course_site.course.sections.find &:primary
    course_site.course.sections.select { |s| s.course == primary.course }.each { |s| s.include_in_site = true }
    course_site.create_site_workflow = 'self'
    course_site
  end

  def get_e_grades_test_sites
    @course_sites = RipleyUtils.e_grades_site_ids.map { |id| CourseSite.new site_id: id }
  end

  def set_e_grades_test_site_data(site, sis_section_ids)
    term_code = sis_section_ids.first.split('-')[0..1].join('-')
    term_name = Utils.term_code_to_term_name term_code
    term = Term.new code: term_code,
                    name: term_name,
                    sis_id: Utils.term_name_to_sis_code(term_name)
    ccns = sis_section_ids.map { |s| s.split('-').last }
    cs_course_id = Utils.get_test_cs_course_id_from_ccn(term, ccns.first)
    site.course = RipleyUtils.get_course(term, cs_course_id)
    RipleyUtils.get_course_enrollment site.course
    site.sections = site.course.sections.select { |s| ccns.include? s.id }
  end

  # Courses

  def set_sis_courses
    prefixes = CONFIG['course_prefixes']
    current_term_courses = prefixes.map { |p| RipleyUtils.get_test_course(@current_term, p) }
    next_term_courses = prefixes.map { |p| RipleyUtils.get_test_course(@next_term, p) }
    @courses = current_term_courses + next_term_courses
    @courses.compact!

    # Test site with only secondary sections
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

    @courses.each { |c| RipleyUtils.get_course_enrollment c }

    # Test site with multiple courses
    prim = @courses.select { |c| c.sections.any?(&:primary) && c.term == @current_term }
    primaries = prim.map(&:sections).flatten.select(&:primary)
    primaries.sort_by! { |p| p.enrollments.length }
    logger.info "#{primaries.map &:course}"
    instructors = (primaries[0].instructors + primaries[1].instructors).uniq
    multi_course = Course.new code: primaries[0].course,
                              title: primaries[0].course,
                              term: @current_term,
                              sections: primaries[0..1],
                              teachers: instructors
    @courses << multi_course
  end

  ### USERS ###

  def set_sis_teacher(site)
    @sis_teacher = site.course.teachers.first
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
