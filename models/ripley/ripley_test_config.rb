class RipleyTestConfig < TestConfig

  include Logging

  attr_accessor :base_url,
                :course_sites,
                :current_term,
                :manual_teacher,
                :next_term,
                :previous_term

  CONFIG = RipleyUtils.config

  def initialize(test_name = nil)
    super
    @base_url = RipleyUtils.base_url
    @current_term = RipleyUtils.current_term
    @next_term = RipleyUtils.next_term @current_term
    @previous_term = RipleyUtils.previous_term @current_term
  end

  # TEST SCRIPT CONFIGURATION

  def add_user
    set_real_test_course_users
  end

  def course_site_creation
    get_multiple_test_sites
    set_real_test_course_users
  end

  def e_grades_export
    get_e_grades_test_sites
    @course_sites.first
  end

  def e_grades_validation
    get_e_grades_test_sites
  end

  def grade_distribution
    @course_sites = RipleyUtils.grade_distribution_site_ids.map { |id| CourseSite.new site_id: id }
    set_real_test_course_users @course_sites.last
  end

  def mailing_lists
    test_users = CONFIG['test_users'].map { |user| User.new user }
    @canvas_admin = User.new role: 'Canvas Admin'
    @course_sites = [
      (
        CourseSite.new abbreviation: "Admin #{@id}",
                       manual_members: (test_users.select { |user| !%w(Owner Maintainer Member).include? user.role }),
                       term: @current_term,
                       title: "List 1 #{@id}"
      ),
      (
        CourseSite.new abbreviation: "Admin #{@id}",
                       manual_members: (test_users.select { |user| user.role == 'Teacher' }),
                       term: @current_term,
                       title: "List 2 #{@id}"
      ),
      (
        CourseSite.new abbreviation: "Instructor #{@id}",
                       manual_members: (test_users.select { |user| !%w(Owner Maintainer Member).include? user.role }),
                       title: "List 3 #{@id}"
      ),
      (
        CourseSite.new abbreviation: "Old List #{@id}",
                       manual_members: (test_users.select { |user| user.role == 'Teacher' }),
                       term: RipleyUtils.previous_term(@previous_term),
                       title: "Old List 4 #{@id}"
      ),
      (
        CourseSite.new abbreviation: "Project List #{@id}",
                       manual_members: (test_users.select { |user| %w(Owner Maintainer Member).include? user.role }),
                       title: "Project List 5 #{@id}"
      )
    ]
  end

  def official_sections
    set_real_test_course_users
  end

  def projects
    site = CourseSite.new title: "Project #{@id}"
    set_real_test_project_users site
    site
  end

  def refresh_canvas_recent
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
      site = CourseSite.new course: course,
                            sections: course.sections,
                            site_id: d['site_id']
      set_real_test_course_users site
      logger.info "Course site: #{site.inspect}"
      site
    end
  end

  def rosters
    set_real_test_course_users
  end

  def user_provisioning
    set_real_test_course_users
  end

  def welcome_email
    test_users = CONFIG['test_users'].map { |user| User.new user }
    CourseSite.new abbreviation: "#{@id} Welcome Email",
                   manual_members: (test_users.select { |user| %w(Teacher Student).include? user.role }),
                   title: "#{@id} Welcome"
  end

  ### GLOBAL CONFIG ###

  def ripley_test_data_file
    File.join(Utils.config_dir, 'test-data-bcourses.json')
  end

  # SIS COURSE DATA

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
      ta_section = secondaries.find { |s| s.instructors_and_roles.any? && (c.teachers & s.instructors_and_roles).empty? }
      if ta_section
        ta = ta_section.instructors_and_roles.first.user
        sections = secondaries.select { |s| s.instructors_and_roles.map(&:user).include? ta }
        ta_course = Course.new code: ta_section.course,
                               sections: sections,
                               teachers: [ta],
                               term: c.term,
                               title: c.title
      end
    end
    courses << ta_course if ta_course

    courses.each { |c| RipleyUtils.get_course_enrollment c }

    # Test site with multiple courses
    prim = courses.select { |c| c.sections.any?(&:primary) && c.term == @current_term }
    primaries = prim.map(&:sections).flatten.select(&:primary)
    primaries.select! { |s| s.instructors_and_roles&.any? }
    primaries.sort_by! { |p| p.enrollments.length }
    instructors = (primaries[0].instructors_and_roles.map(&:user) + primaries[1].instructors_and_roles.map(&:user)).uniq
    multi_course = Course.new code: primaries[0].course,
                              multi_course: true,
                              sections: primaries[0..1],
                              teachers: instructors,
                              term: @current_term
    courses << multi_course
    courses
  end

  # COURSE SITES

  def get_multiple_test_sites
    courses = set_sis_courses
    @course_sites = courses.map do |c|
      primaries = c.sections.select &:primary
      workflow = if (primaries.length > 1 || primaries.empty?) && !c.multi_course
                   'uid'
                 else
                   'ccn'
                 end
      CourseSite.new abbreviation: "#{@id} #{c.term.name} #{c.code}",
                     course: c,
                     create_site_workflow: workflow,
                     sections: c.sections,
                     title: "#{@id} #{c.term.name} #{c.code}"
    end
    instructor_workflow_sites = @course_sites.select { |s| s.create_site_workflow == 'uid' }
    instructor_workflow_sites.each_with_index { |s, i| s.create_site_workflow = 'self' if i.odd? }
    @course_sites.each do |site|
      # Only use a primary section instructor if testing primary sections
      if instructor_workflow_sites.include?(site) && site.sections.find(&:primary)
        site.course.teachers = [RipleyUtils.get_primary_instructors(site).first]
      end
      # Ditch sections not associated with the instructor since they shouldn't appear
      if instructor_workflow_sites.include?(site) && site.sections.find(&:primary)
        primary_ids = site.course.sections.select do |s|
          s.primary && s.instructors_and_roles.map(&:user).include?(site.course.teachers.first)
        end.map &:id
        site.course.sections.keep_if do |s|
          primary_ids.include?(s.id) || (primary_ids & s.primary_assoc_ids).any?
        end
      end
    end

    @course_sites.each do |site|
      logger.info "#{site.course.term.name} #{site.course.code} workflow #{site.create_site_workflow}, instructor UID #{site.course.teachers.first.uid}"
      logger.info "Course sections: #{site.course.sections.map &:id}"
      logger.info "Site sections: #{site.sections.map &:id}"
    end
  end

  def get_single_test_site(section_ids = nil)
    course_site = if ENV['SITE']
                    CourseSite.new site_id: ENV['SITE'].to_s
                  else
                    get_multiple_test_sites
                    @course_sites.find do |site|
                      site.course.sections.select(&:primary).length > 1 && (site.course.sections.select { |s| !s.primary }).any?
                    end
                  end
    get_existing_site_data(course_site, section_ids) if section_ids
    course_site.course.sections.select(&:primary).each { |s| s.include_in_site = true }
    course_site.create_site_workflow = 'self'
    course_site.course.teachers = [RipleyUtils.get_primary_instructors(course_site).first]
    course_site
  end

  def get_existing_site_data(site, sis_section_ids, newt=false)
    term_code = sis_section_ids.first.split('-')[0..1].join('-')
    term_name = Utils.term_code_to_term_name term_code
    term = Term.new code: term_code,
                    name: term_name,
                    sis_id: Utils.term_name_to_sis_code(term_name)

    ccns = sis_section_ids.map { |s| s.split('-')[2] }
    cs_course_id = RipleyUtils.get_cs_course_id_from_ccn(term, ccns.first)

    site.term = term
    site.course = RipleyUtils.get_course(term, cs_course_id)
    site.sections = site.course.sections.select { |s| ccns.include? s.id }
    if term.sis_id.to_i < @current_term.sis_id.to_i
      RipleyUtils.get_completed_enrollments site.course
    elsif newt
      RipleyUtils.get_newt_enrollments site.course
    else
      RipleyUtils.get_course_enrollment site.course
    end
  end

  def get_e_grades_test_sites
    @course_sites = RipleyUtils.e_grades_site_ids.map { |id| CourseSite.new site_id: id }
    @course_sites.each { |s| set_real_test_course_users s }
  end

  def configure_single_site(canvas_page, canvas_api_page, non_teachers, site = nil)
    canvas_page.add_ripley_tools RipleyTool::TOOLS.select(&:account)
    site_id = ENV['SITE'] || site&.site_id
    section_ids = canvas_api_page.get_course_site_sis_section_ids site_id if site_id
    if site
      get_existing_site_data(site, section_ids)
    else
      site = get_single_test_site section_ids
    end
    teacher = RipleyUtils.get_primary_instructors(site).first || site.course.teachers.first
    canvas_page.set_canvas_ids([teacher] + non_teachers)
    canvas_api_page.get_support_admin_canvas_id @canvas_admin
    return site, teacher
  end

  # USERS

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

  def set_real_test_course_users(site = nil)
    teachers = RipleyUtils.get_users_of_affiliations('EMPLOYEE-TYPE-ACADEMIC', 1)
    @manual_teacher = teachers[0]
    @manual_teacher.role = 'Teacher'

    tas = RipleyUtils.get_users_of_affiliations('EMPLOYEE-TYPE-ACADEMIC,STUDENT-TYPE-REGISTERED', 2)
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

    @canvas_admin = User.new role: 'Canvas Admin'

    site.manual_members = (teachers + tas + staff + students) if site
  end

  def set_real_test_project_users(site = nil)
    @manual_teacher = RipleyUtils.get_users_of_affiliations('EMPLOYEE-TYPE-ACADEMIC', 1)[0]
    @manual_teacher.role = 'Teacher'
    @staff = RipleyUtils.get_users_of_affiliations('EMPLOYEE-TYPE-STAFF', 1)[0]
    @staff.role = 'Staff'
    @ta = RipleyUtils.get_users_of_affiliations('EMPLOYEE-TYPE-ACADEMIC,STUDENT-TYPE-REGISTERED', 1)[0]
    @ta.role = 'TA'
    @students = RipleyUtils.get_users_of_affiliations('STUDENT-TYPE-REGISTERED', 1)
    @students.each { |s| s.role = 'Student' }
    @canvas_admin = User.new role: 'Canvas Admin'

    site.manual_members = ([@manual_teacher, @staff, @ta] + @students) if site
  end
end
