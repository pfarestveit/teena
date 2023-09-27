require_relative '../../util/spec_helper'

describe 'bCourses recent enrollment updates' do

  include Logging

  before(:all) do
    @driver = Utils.launch_browser
    @cal_net_page = Page::CalNetPage.new @driver
    @canvas_page = Page::CanvasPage.new @driver
    @splash_page = RipleySplashPage.new @driver
    @create_course_site_page = RipleyCreateCourseSitePage.new @driver
    @jobs_page = RipleyJobsPage.new @driver

    @test = RipleyTestConfig.new
    site = @test.get_single_test_site
    @test.set_incremental_refresh_users site
    logger.info "Teachers: #{@test.teachers.map &:uid}"
    logger.info "Students: #{@test.students.map &:uid}"

    @canvas_page.log_in(@cal_net_page, @test.admin.username, Utils.super_admin_password)
    if site.site_id
      @canvas_page.load_course_site site
    else
      @create_course_site_page.provision_course_site site
      @canvas_page.publish_course_site site
    end

    # Primary section updates
    @primary_section = site.sections.find &:primary
    @prim_stu0_enroll = SectionEnrollment.new user: @test.students[0],
                                              term: site.course.term,
                                              section_id: @primary_section.id,
                                              status: 'E'
    @prim_stu1_enroll = SectionEnrollment.new user: @test.students[1],
                                              term: site.course.term,
                                              section_id: @primary_section.id,
                                              status: 'W'
    RipleyUtils.insert_instructor_update(site.course, @primary_section, @test.teachers[0], 'PI')
    RipleyUtils.insert_instructor_update(site.course, @primary_section, @test.teachers[1], 'APRX')
    RipleyUtils.insert_instructor_update(site.course, @primary_section, @test.teachers[2], 'ICNT')
    RipleyUtils.insert_instructor_update(site.course, @primary_section, @test.teachers[3], 'INVT')
    RipleyUtils.insert_enrollment_update @prim_stu0_enroll
    RipleyUtils.insert_enrollment_update @prim_stu1_enroll

    # Secondary section updates
    @secondary_sections = site.sections.select { |s| !s.primary }
    @sec0_stu0_enroll = SectionEnrollment.new user: @test.students[0],
                                              term: site.course.term,
                                              section_id: @secondary_sections[0].id,
                                              status: 'E'
    @sec1_stu0_list = SectionEnrollment.new user: @test.students[0],
                                            term: site.course.term,
                                            section_id: @secondary_sections[1].id,
                                            status: 'W'
    @sec1_stu1_list = SectionEnrollment.new user: @test.students[1],
                                            term: site.course.term,
                                            section_id: @secondary_sections[1].id,
                                            status: 'W'
    RipleyUtils.insert_instructor_update(site.course, @secondary_sections[0], @test.teachers[4], 'TNIC')
    RipleyUtils.insert_enrollment_update @sec0_stu0_enroll
    RipleyUtils.insert_enrollment_update @sec1_stu0_list
    RipleyUtils.insert_enrollment_update @sec1_stu1_list

    # Run Ripley job
    @splash_page.load_page
    @splash_page.dev_auth @test.admin.uid
    @splash_page.click_jobs_link
    @jobs_page.run_job RipleyJob::REFRESH_INCREMENTAL

    # Get resulting Canvas enrollments
    @enrollments = @canvas_page.get_users_with_sections site.course
  end

  context 'when a PI in a primary section' do
    it 'adds a Teacher enrollment to the right section' do
      teacher_0_enroll = @enrollments.find { |e| e[:user].uid == @test.teachers[0].uid }
      expect(teacher_0_enroll[:section].label).to eql(@primary_section.label)
      expect(teacher_0_enroll[:user].role).to eql('teacher')
    end
  end

  context 'when an APRX in a primary section' do
    it 'adds a Lead TA enrollment to the right section' do
      teacher_1_enroll = @enrollments.find { |e| e[:user].uid == @test.teachers[1].uid }
      expect(teacher_1_enroll[:section].label).to eql(@primary_section.label)
      expect(teacher_1_enroll[:user].role).to eql('Lead TA')
    end
  end

  context 'when an ICNT in a primary section' do
    it 'adds a Teacher enrollment to the right section' do
      teacher_2_enroll = @enrollments.find { |e| e[:user].uid == @test.teachers[2].uid }
      expect(teacher_2_enroll[:section].label).to eql(@primary_section.label)
      expect(teacher_2_enroll[:user].role).to eql('teacher')
    end
  end

  context 'when an INVT in a primary section' do
    it 'adds a Teacher enrollment to the right section' do
      teacher_3_enroll = @enrollments.find { |e| e[:user].uid == @test.teachers[3].uid }
      expect(teacher_3_enroll[:section].label).to eql(@primary_section.label)
      expect(teacher_3_enroll[:user].role).to eql('teacher')
    end
  end

  context 'when a TNIC in a secondary section' do
    it 'adds a TA enrollment to the right section' do
      teacher_4_enroll = @enrollments.find { |e| e[:user].uid == @test.teachers[4].uid }
      expect(teacher_4_enroll[:section].label).to eql(@secondary_sections[0].label)
      expect(teacher_4_enroll[:user].role).to eql('ta')
    end
  end

  context 'when a student in a primary section' do
    it 'adds a Student enrollment to the right section' do
      prim_stu0 = @enrollments.find do |e|
        (e[:user].uid == @test.students[0].uid) && (e[:section].label == @primary_section.label)
      end
      expect(prim_stu0[:user].role).to eql('student')
    end
  end

  context 'when a student in a secondary section' do
    it 'adds a Student enrollment to the right section' do
      sec0_stu0 = @enrollments.find do |e|
        (e[:user].uid == @test.students[0].uid) && (e[:section].label == @secondary_sections[0].label)
      end
      expect(sec0_stu0[:user].role).to eql('student')
    end
  end

  context 'when a wait listed student in a primary section' do
    it 'adds a Waitlist Student enrollment to the right section' do
      prim_stu1 = @enrollments.find do |e|
        (e[:user].uid == @test.students[1].uid) && (e[:section].label == @primary_section.label)
      end
      expect(prim_stu1[:user].role).to eql('Waitlist Student')
    end
  end

  context 'when a wait listed student in a secondary section' do
    it 'adds a Waitlist Student enrollment to the right section' do
      sec1_stu1 = @enrollments.find do |e|
        (e[:user].uid == @test.students[1].uid) && (e[:section].label == @secondary_sections[1].label)
      end
      expect(sec1_stu1[:user].role).to eql('Waitlist Student')
    end
  end

  context 'when a wait listed student in a secondary section, enrolled in another section' do
    it 'adds a Waitlist Student enrollment to the right section' do
      sec1_stu0 = @enrollments.find do |e|
        (e[:user].uid == @test.students[0].uid) && (e[:section].label == @secondary_sections[1].label)
      end
      expect(sec1_stu0[:user].role).to eql('Waitlist Student')
    end
  end
end
