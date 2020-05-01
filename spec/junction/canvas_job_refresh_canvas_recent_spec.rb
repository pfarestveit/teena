require_relative '../../util/spec_helper'

describe 'bCourses recent enrollment updates' do

  begin

    @driver = Utils.launch_browser
    @splash_page = Page::JunctionPages::SplashPage.new @driver
    @cal_net_page = Page::CalNetPage.new @driver
    @create_course_site_page = Page::JunctionPages::CanvasCreateCourseSitePage.new @driver
    @canvas_page = Page::CanvasPage.new @driver

    test_data = JunctionUtils.load_junction_test_course_data.select { |course| course['tests']['create_course_site'] }
    all_test_courses = []
    sites_created = []
    sites_to_create = []

    test_data.each do |data|

      test_course = {
          course: Course.new(data),
          teacher: User.new(course.teachers.first),
          sections: (course.sections.map { |section_data| Section.new section_data }),
          sections_for_site: (sections.select { |section| section.include_in_site }),
          site_abbreviation: nil,
          academic_data: ApiAcademicsCourseProvisionPage.new(@driver),
          roster_data: ApiAcademicsRosterPage.new(@driver),
          test_data: data
      }

      @splash_page.basic_auth(test_course[:teacher].uid, @cal_net_page)
      test_course[:academic_data].get_feed @driver
      all_test_courses << test_course

      # If a test site was already created for the course today, use that one. Otherwise, create one.
      if test_course[:course].site_id && (test_course[:course].site_created_date&.== "#{Date.today}")
        sites_created << test_course
      else
        sites_to_create << test_course
      end

    rescue => e
      it("encountered an error retrieving SIS data for #{test_course[:course].code}") { fail }
      Utils.log_error e
    ensure
      @splash_page.load_page
      @splash_page.log_out @splash_page
    end

    sites_to_create.each do |site|

      @create_course_site_page.provision_course_site(@driver, site[:course], site[:teacher], site[:sections_for_site])
      @canvas.publish_course_site site[:course]
      @canvas.load_users_page site[:course]

      # If site creation succeeded, store the site info for the rest of the tests
      if site[:course].site_id
        sites_created << site
      else
        logger.error "#{site[:course].term} #{site[:course].code} did not succeed"
      end

    rescue => e
      it("encountered an error creating the course site for #{site[:course].code}") { fail }
      Utils.log_error e
    end

    @canvas_page.log_out(@driver, @cal_net_page)

    sites_created.each do |site|
      @splash_page.load_page
      @splash_page.basic_auth(site[:teacher].uid, @cal_net_page)
      site[:roster_data].get_feed(@driver, site[:course])
    ensure
      @splash_page.load_page
      @splash_page.log_out @splash_page
    end

    roles = ['Teacher', 'Lead TA', 'TA', 'Student', 'Waitlist Student']
    actual_enrollment_counts = @canvas_page.wait_for_enrollment_import(site[:course], roles)
    actual_student_uids = @canvas_page.get_students(site[:course]).map(&:uid).sort
    expected_student_uids = site[:roster_data].all_student_uids.sort

    # wait for enrollment completion
    # add manual memberships of all roles
    #
    # get the actual membership data on the site
    # for each role represented on the site, collect a certain configurable number of them
    # generate a SIS import CSV containing all the rows for all the users for the sites
    # make most of them deletes but do an add for a different role for a few
    # upload the CSV
    #
    # log out and return to login screen. long pause awaiting manual login.
    # run script manually ** to be automated someday?
    #
    # log in to resume
    # visit each course site and verify the enrollment


  end
end
