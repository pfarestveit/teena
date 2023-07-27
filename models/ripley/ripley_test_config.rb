class RipleyTestConfig < TestConfig

  include Logging

  attr_accessor :base_url,
                :course_sites,
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

  def course_site_creation
    get_multiple_test_sites
  end

  def e_grades_validation
    get_e_grades_test_sites
  end

  def mailing_lists
    get_mailing_list_sites
  end

  def refresh_canvas_recent
    get_refresh_recent_sites
  end

  def user_provisioning
    set_manual_members
  end

  ### GLOBAL CONFIG ###

  def ripley_test_data_file
    File.join(Utils.config_dir, 'test-data-bcourses.json')
  end

  # COURSE SITES

  def get_multiple_test_sites
    courses = set_sis_courses
    @course_sites = courses.map do |c|
      workflow = (c.sections.select(&:primary).length > 1) ? 'ccn' : 'uid'
      CourseSite.new title: "#{@id} #{c.term.name} #{c.code}",
                     abbreviation: "#{@id} #{c.term.name} #{c.code}",
                     course: c,
                     create_site_workflow: workflow,
                     sections: c.sections
    end
  end

  def get_single_test_site
    course_site = if ENV['SITE']
                    test_data = JSON.parse(File.read(File.join(Utils.config_dir, 'test-data-bcourses.json')))['courses']
                    course = Course.new(test_data.find { |d| d['site_id'] == ENV['SITE'] })
                    course.sections.map! { |s| Section.new s }
                    course.teachers.map! { |u| User.new u }
                    course.term = Term.new code: Utils.term_name_to_hyphenated_code(course.term),
                                           name: course.term,
                                           sis_id: Utils.term_name_to_sis_code(course.term)
                    RipleyUtils.get_course_enrollment course
                    CourseSite.new site_id: ENV['SITE'],
                                   abbreviation: "#{@id} #{course.term} #{course.code}",
                                   course: course,
                                   sections: course.sections
                  else
                    get_multiple_test_sites
                    @course_sites.find do |site|
                      site.course.sections.select(&:primary).length > 1 && (site.course.sections.select { |s| !s.primary }).any?
                    end
                  end
    course_site.course.sections.select(&:primary).each { |s| s.include_in_site = true }
    course_site.create_site_workflow = 'self'
    set_manual_members course_site
    course_site
  end

  def get_existing_site_data(site, sis_section_ids)
    term_code = sis_section_ids.first.split('-')[0..1].join('-')
    term_name = Utils.term_code_to_term_name term_code
    term = Term.new code: term_code,
                    name: term_name,
                    sis_id: Utils.term_name_to_sis_code(term_name)
    ccns = sis_section_ids.map { |s| s.split('-').last }
    cs_course_id = RipleyUtils.get_test_cs_course_id_from_ccn(term, ccns.first)
    site.course = RipleyUtils.get_course(term, cs_course_id)
    RipleyUtils.get_course_enrollment site.course
    site.sections = site.course.sections.select { |s| ccns.include? s.id }
  end

  def get_e_grades_test_sites
    @course_sites = RipleyUtils.e_grades_site_ids.map { |id| CourseSite.new site_id: id }
    @course_sites.each { |s| set_manual_members s }
  end

  def get_e_grades_export_site
    get_e_grades_test_sites
    @course_sites.first
  end

  def get_mailing_list_sites
    @course_sites = [
      (
        CourseSite.new title: "List 1 #{@id}",
                       abbreviation: "Admin #{@id}",
                       term: @current_term
      ),
      (
        CourseSite.new title: "List 2 #{@id}",
                       abbreviation: "Admin #{@id}",
                       term: @current_term
      ),
      (
        CourseSite.new title: "List 3 #{@id}",
                       abbreviation: "Instructor #{@id}"
      )
    ]
    set_test_user_data ripley_test_data_file
    @course_sites.each { |s| set_manual_mailing_list_members s }
    @course_sites[1].manual_members = [@teachers.first]
  end

  def get_project_site
    site = CourseSite.new title: "Project #{@id}"
    set_manual_members site
    site
  end

  def get_refresh_recent_sites
    # TODO - replace the info from the test data file with Nessie + newly created course site data
    test_data = JSON.parse(File.read(File.join(Utils.config_dir, 'test-data-bcourses.json')))['courses']
    test_data.keep_if { |d| d['tests']['refresh_recent'] }
    @course_sites = test_data.map do |d|
      course = Course.new d
      course.sections.map! { |s| Section.new s }
      course.teachers.map! { |u| User.new u }
      course.term = Term.new code: Utils.term_name_to_hyphenated_code(course.term),
                             name: course.term,
                             sis_id: Utils.term_name_to_sis_code(course.term)
      site = CourseSite.new site_id: d['site_id'],
                            course: course,
                            sections: course.sections
      set_manual_members site
      logger.info "Course site: #{site.inspect}"
      site
    end
  end

  def get_welcome_email_site
    site = CourseSite.new title: "#{@id} Welcome",
                          code: "#{@id} Welcome Email"
    set_manual_members site
    site
  end

  # Courses

  def set_sis_courses
    prefixes = CONFIG['course_prefixes']
    current_term_courses = prefixes.map { |p| RipleyUtils.get_test_course(@current_term, p) }
    next_term_courses = prefixes.map { |p| RipleyUtils.get_test_course(@next_term, p) }
    courses = current_term_courses + next_term_courses
    courses.compact!

    # Test site with only secondary sections
    ta_course = nil
    courses.find do |c|
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
    courses << ta_course if ta_course

    courses.each { |c| RipleyUtils.get_course_enrollment c }

    # Test site with multiple courses
    prim = courses.select { |c| c.sections.any?(&:primary) && c.term == @current_term }
    primaries = prim.map(&:sections).flatten.select(&:primary)
    primaries.sort_by! { |p| p.enrollments.length }
    logger.info "#{primaries.map &:course}"
    instructors = (primaries[0].instructors + primaries[1].instructors).uniq
    multi_course = Course.new code: primaries[0].course,
                              title: primaries[0].course,
                              term: @current_term,
                              sections: primaries[0..1],
                              teachers: instructors
    courses << multi_course
    courses
  end

  def set_incremental_refresh_users(site)
    teachers = RipleyUtils.get_users_of_affiliations 'EMPLOYEE-TYPE-ACADEMIC'
    used_teacher_uids = RipleyUtils.get_instructor_update_uids(site.course.term, site.sections.map(&:id))
    site_teacher_uids = site.course.teachers.map &:uid
    @teachers = teachers.reject do |t|
      (used_teacher_uids + site_teacher_uids).include?(t.uid) || t.first_name.count('a-zA-Z').zero?
    end.shuffle[0..4]

    students = RipleyUtils.get_users_of_affiliations 'STUDENT-TYPE-REGISTERED'
    used_student_uids = RipleyUtils.get_student_update_uids(site.course.term, site.sections.map(&:id))
    site_student_uids = site.sections.map { |s| s.enrollments.map { |e| e.user.uid } }.flatten.uniq
    @students = students.reject do |s|
      (used_student_uids + site_student_uids).include? s.uid || s.first_name.count('a-zA-Z').zero?
    end.shuffle[0..1]
  end

  def set_manual_members(site = nil)
    teachers = RipleyUtils.get_users_of_affiliations('EMPLOYEE-TYPE-ACADEMIC', 1)
    @manual_teacher = teachers[0]
    @manual_teacher.role = 'Teacher'

    tas = RipleyUtils.get_users_of_affiliations('EMPLOYEE-TYPE-ACADEMIC, STUDENT-TYPE-REGISTERED', 2)
    @lead_ta = tas[0]
    @lead_ta.role = 'Lead TA'
    @ta = tas[1]
    @ta.role = 'TA'

    staff = RipleyUtils.get_users_of_affiliations('EMPLOYEE-TYPE-STAFF', 3)
    @designer = staff[0]
    @designer.role = 'Designer'
    @reader = staff[1]
    @reader.role = 'Reader'
    @observer = staff[2]
    @observer.role = 'Observer'

    students = RipleyUtils.get_users_of_affiliations('STUDENT-TYPE-REGISTERED', 3)
    @students = students[0..1]
    @students.each { |s| s.role = 'Student' }
    @wait_list_student = students[2]
    @wait_list_student.role = 'Waitlist Student'

    site.manual_members = (teachers + tas + staff + students) if site
  end

  def set_manual_mailing_list_members(site)
    site.manual_members = set_test_users 'mailing_lists'
  end

  def set_manual_project_members(site = nil)
    @manual_teacher = RipleyUtils.get_users_of_affiliations('EMPLOYEE-TYPE-ACADEMIC', 1)[0]
    @manual_teacher.role = 'Teacher'
    @staff = RipleyUtils.get_users_of_affiliations('EMPLOYEE-TYPE-STAFF', 1)[0]
    @staff.role = 'Staff'
    @ta = RipleyUtils.get_users_of_affiliations('EMPLOYEE-TYPE-ACADEMIC, STUDENT-TYPE-REGISTERED', 1)[0]
    @ta.role = 'TA'
    @students = RipleyUtils.get_users_of_affiliations('STUDENT-TYPE-REGISTERED', 1)
    @students.each { |s| s.role = 'Student' }
    site.manual_members = ([@staff, @ta] + @students) if site
  end
end
