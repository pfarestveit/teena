require_relative '../../util/spec_helper'

describe 'bCourses E-Grades Export', order: :defined do

  include Logging

  # Load test course data
  test_course_data = JunctionUtils.load_junction_test_course_data.find { |course| course['tests']['e_grades_export'] }
  course = Course.new test_course_data
  teacher = User.new course.teachers.first
  sections = course.sections.map { |section_data| Section.new section_data }
  sections_for_site = sections.select { |section| section.include_in_site }
  primary_section = sections_for_site.first
  secondary_section = sections_for_site.last if sections_for_site.length > 1

  # Load test user data
  test_user_data = JunctionUtils.load_junction_test_user_data.select { |user| user['tests']['e_grades_export'] }
  lead_ta = User.new test_user_data.find { |data| data['role'] == 'Lead TA' }
  ta = User.new test_user_data.find { |data| data['role'] == 'TA' }
  designer = User.new test_user_data.find { |data| data['role'] == 'Designer' }
  observer = User.new test_user_data.find { |data| data['role'] == 'Observer' }
  reader = User.new test_user_data.find { |data| data['role'] == 'Reader' }
  student = User.new test_user_data.find { |data| data['role'] == 'Student' }
  waitlist = User.new test_user_data.find { |data| data['role'] == 'Waitlist Student' }

  before(:all) do
    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasGradesPage.new @driver
    @canvas_assignments_page = Page::CanvasAssignmentsPage.new @driver
    @splash_page = Page::JunctionPages::SplashPage.new @driver
    @e_grades_export_page = Page::JunctionPages::CanvasEGradesExportPage.new @driver
    @course_add_user_page = Page::JunctionPages::CanvasCourseAddUserPage.new @driver
    @rosters_api = ApiAcademicsRosterPage.new @driver
    @academics_api = ApiAcademicsCourseProvisionPage.new @driver

    # Get roster and section data for the site
    @splash_page.load_page
    @splash_page.basic_auth(teacher.uid, @cal_net)
    @rosters_api.get_feed(@driver, course)
    @academics_api.get_feed(@driver)

    @prim_sec_sids = @rosters_api.student_ids(@rosters_api.section_students("#{primary_section.course} #{primary_section.label}"))
    if secondary_section
      @sec_sec_sids = @rosters_api.student_ids(@rosters_api.section_students("#{secondary_section.course} #{secondary_section.label}"))
    end

    @current_semester = @academics_api.current_semester @academics_api.all_teaching_semesters
    @current_semester_name = @academics_api.semester_name @current_semester if @current_semester
    @driver.manage.delete_all_cookies

    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.masquerade_as teacher

    # Create an ungraded assignment to use for testing manual grading policy
    @ungraded_assignment = Assignment.new(title: Utils.get_test_id)
    @canvas.set_grade_policy_manual course
    @canvas_assignments_page.create_assignment(course, @ungraded_assignment)

    # Ensure final grade override feature is enabled on the course for override tests
    @canvas.enable_final_grade_override course
  end

  after(:all) do
    @canvas.stop_masquerading
    assignments = @canvas_assignments_page.get_list_view_assignments course
    @canvas_assignments_page.delete_test_assignments assignments
  ensure
    Utils.quit_browser @driver
  end

  it 'offers an E-Grades Export button on the Gradebook' do
    @canvas.load_gradebook course
    @canvas.click_e_grades_export_button
    @e_grades_export_page.wait_until(Utils.medium_wait) { @e_grades_export_page.title == 'Download E-Grades' }
    @e_grades_export_page.wait_until(1, 'Wrong Junction environment is configured') do
      @e_grades_export_page.i_frame_form_element? JunctionUtils.junction_base_url
    end
  end

  context 'when no grading scheme is enabled and an assignment is un-posted' do

    before(:all) { @canvas.disable_grading_scheme course }

    before(:each) { @e_grades_export_page.load_embedded_tool(@driver, course) }

    it 'offers a "Course Settings" link' do
      @e_grades_export_page.click_course_settings_button_disabled
      @canvas.wait_until(Utils.medium_wait) { @canvas.current_url.include? "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings" }
    end

    it 'offers a "How do I post grades for an assignment?" link' do
      title = 'How do I post grades for an assignment in the G... | Canvas LMS Community'
      expect(@e_grades_export_page.external_link_valid?(@e_grades_export_page.how_to_post_grades_link_element, title)).to be true
    end

    it 'allows the user to Cancel' do
      @e_grades_export_page.click_cancel
      @canvas.wait_until(Utils.medium_wait) { @canvas.current_url == "#{Utils.canvas_base_url}/courses/#{course.site_id}/gradebook" }
    end

    it 'prevents the user continuing' do
      @e_grades_export_page.continue_button_element.when_visible Utils.medium_wait
      expect(@e_grades_export_page.continue_button_element.attribute('disabled')).to eql('true')
    end
  end

  context 'when a grading scheme is enabled and an assignment is un-posted' do

    before(:all) { @canvas.enable_grading_scheme course }

    before(:each) { @e_grades_export_page.load_embedded_tool(@driver, course) }

    it 'offers a "Course Settings" link' do
      @e_grades_export_page.click_course_settings_button_enabled
      @canvas.wait_until(Utils.medium_wait) { @canvas.current_url.include? "#{Utils.canvas_base_url}/courses/#{course.site_id}/settings" }
    end

    it 'offers a "How do I post grades for an assignment?" link' do
      title = 'How do I mute or unmute an assignment in the Gradebook? | Canvas Instructor Guide | Canvas Guides'
      expect(@e_grades_export_page.external_link_valid?(@e_grades_export_page.how_to_post_grades_link_element, title)).to be true
    end

    it 'allows the user to Cancel' do
      @e_grades_export_page.click_cancel
      @canvas.wait_until(Utils.medium_wait) { @canvas.current_url == "#{Utils.canvas_base_url}/courses/#{course.site_id}/gradebook" }
    end

    it 'allows the user to Continue' do
      @e_grades_export_page.click_continue
      @e_grades_export_page.download_final_grades_element.when_visible Utils.medium_wait
    end
  end

  # Canvas and BCS test environments are on different refresh schedules, so their enrollment data can differ in the current term.
  # Only compare their enrollment data if the term is in the past and no longer changing.

  context 'when no assignment is muted and a grading scheme is enabled' do

    before(:all) do
      @e_grades_export_page.load_embedded_tool(@driver, course)
      @e_grades_export_page.click_continue
    end

    it 'allows the user the select any section on the course site' do
      expected_options = @rosters_api.section_names.sort
      if expected_options.length > 1
        expect(@e_grades_export_page.sections_select_options.sort).to eql(expected_options)
      end
    end

    it 'requires the user to select a pass / no pass cutoff grade' do
      expect(@e_grades_export_page.download_current_grades_element.enabled?).to be false
      expect(@e_grades_export_page.download_current_grades_element.enabled?).to be false
    end

    shared_examples 'CSV downloads' do |cutoff|

      it 'allows the user to download current grades for a primary section' do
        csv = @e_grades_export_page.download_current_grades(@driver, course, primary_section, cutoff)
        if @current_semester && course.term == @current_semester_name
          expect(csv.any?).to be true
        else
          expected_sids = @prim_sec_sids.sort
          actual_sids = csv.map { |k| k[:id] }.sort
          @e_grades_export_page.wait_until(1,  "Missing: #{expected_sids - actual_sids}. Unexpected: #{actual_sids - expected_sids}") do
            expected_sids == actual_sids
          end
        end
      end

      it 'allows the user to download current grades for a secondary section' do
        if secondary_section
          csv = @e_grades_export_page.download_current_grades(@driver, course, secondary_section, cutoff)
          if @current_semester && course.term == @current_semester_name
            expect(csv.any?).to be true
          else
            expected_sids = @sec_sec_sids.sort
            actual_sids = csv.map { |k| k[:id] }.sort
            @e_grades_export_page.wait_until(1,  "Missing: #{expected_sids - actual_sids}. Unexpected: #{actual_sids - expected_sids}") do
              expected_sids == actual_sids
            end
          end
        end
      end

      it 'allows the user to download final grades for a primary section' do
        csv = @e_grades_export_page.download_final_grades(@driver, course, primary_section, cutoff)
        if @current_semester && course.term == @current_semester_name
          expect(csv.any?).to be true
        else
          expected_sids = @prim_sec_sids.sort
          actual_sids = csv.map { |k| k[:id] }.sort
          @e_grades_export_page.wait_until(1,  "Missing: #{expected_sids - actual_sids}. Unexpected: #{actual_sids - expected_sids}") do
            expected_sids == actual_sids
          end
        end
      end

      it 'allows the user to download final grades for a secondary section' do
        if secondary_section
          csv = @e_grades_export_page.download_final_grades(@driver, course, secondary_section, cutoff)
          if @current_semester && course.term == @current_semester_name
            expect(csv.any?).to be true
          else
            expected_sids = @sec_sec_sids.sort
            actual_sids = csv.map { |k| k[:id] }.sort
            @e_grades_export_page.wait_until(1,  "Missing: #{expected_sids - actual_sids}. Unexpected: #{actual_sids - expected_sids}") do
              expected_sids == actual_sids
            end
          end
        end
      end
    end

    context 'and the user selects a pass / no pass cutoff' do

      include_examples 'CSV downloads', 'C-'

    end

    context 'and the user does not select a pass / no pass cutoff' do

      include_examples 'CSV downloads', nil

    end
  end

  describe 'CSV export' do

    before(:all) do
      section_name = "#{primary_section.course} #{primary_section.label}"
      @roster_students = @rosters_api.section_students section_name
      @e_grades = @e_grades_export_page.download_final_grades(@driver, course, primary_section, 'C-')
    end

    it 'has the right column headers' do
      expected_header = %w(id name grade grading_basis comments).map { |h| h.to_sym }
      actual_header = (@e_grades.map { |h| h.keys }).flatten.uniq
      logger.debug "Expecting #{expected_header} and got #{actual_header}"
      expect(actual_header).to eql(expected_header)
    end

    it 'has the right SIDs' do
      expected_sids = @rosters_api.student_ids(@roster_students).sort
      actual_sids = @e_grades.map { |s| s[:id] }.sort
      logger.debug "Expecting #{expected_sids} and got #{actual_sids}"
      expect(actual_sids.any? &:empty?).to be false
      @e_grades_export_page.wait_until(1,  "Missing: #{expected_sids - actual_sids}. Unexpected: #{actual_sids - expected_sids}") do
        expected_sids == actual_sids
      end
    end

    it 'has the right names' do
      # Compare last names only, since preferred names can cause mismatches
      expected_names = @rosters_api.student_last_names(@roster_students).sort
      actual_names = @e_grades.map { |n| n[:name].split(',')[0].strip.downcase }.sort
      logger.debug "Expecting #{expected_names} and got #{actual_names}"
      expect(actual_names.any? &:empty?).to be false
      @e_grades_export_page.wait_until(1,  "Missing: #{expected_names - actual_names}. Unexpected: #{actual_names - expected_names}") do
        expected_names == actual_names
      end
    end

    it 'has reasonable grades' do
      expected_grades = %w(A+ A A- B+ B B- C+ C C- D+ D D- F P NP S U)
      actual_grades = @e_grades.map { |g| g[:grade] }
      logger.debug "Expecting #{expected_grades} and got #{actual_grades.uniq}"
      expect(actual_grades.any? &:empty?).to be false
      expect((actual_grades - expected_grades).any?).to be false
    end

    it 'has reasonable grading bases' do
      expected_grading_bases = %w(DPN EPN ESU GRD)
      actual_grading_bases = @e_grades.map { |b| b[:grading_basis] }
      logger.debug "Expecting #{expected_grading_bases} and got #{actual_grading_bases.uniq}"
      expect(actual_grading_bases.any? &:empty?).to be false
      expect((actual_grading_bases - expected_grading_bases).any?).to be false
    end
  end

  describe 'final grade' do

    before(:all) do
      students = @canvas.get_students(course, primary_section)
      @canvas.enable_grading_scheme course
      @canvas.load_gradebook course
      @grades_are_final = @canvas.grades_final?
      logger.info "Grades are final is #{@grades_are_final}"
      @canvas.hit_escape

      # Get actual grade data for one student
      gradebook_grade_data = students.map do |user|
        user.sis_id = @rosters_api.sid_from_uid user.uid
        @canvas.student_score user unless user.sis_id.nil?
      end
      gradebook_grade_data.compact!
      test_data = gradebook_grade_data.first
      logger.debug "Test data: #{test_data}"

      @test_student = BOACUser.new(uid: test_data[:uid],
                                   sis_id: test_data[:sis_id],
                                   canvas_id: test_data[:canvas_id])
      @test_grade = test_data[:grade]
      @override_grade = %w(A A- B+ B B- C+ C C- D+ D D- F).find { |g| g != @test_grade }
    end

    context 'when override is enabled' do

      before(:all) do
        @canvas.load_gradebook course
        @canvas.allow_grade_override
        @canvas.enter_override_grade(course, @test_student, @override_grade)
      end

      it 'downloads the override grade rather than the calculated grade in current grades' do
        e_grades = @e_grades_export_page.download_current_grades(@driver, course, primary_section)
        e_grades_row = e_grades.find { |r| r[:id] == @test_student.sis_id }
        expect(e_grades_row[:grade]).to eql(@override_grade)
      end

      it 'downloads the override grade rather than the calculated grade in final grades' do
        e_grades = @e_grades_export_page.download_final_grades(@driver, course, primary_section)
        e_grades_row = e_grades.find { |r| r[:id] == @test_student.sis_id }
        expect(e_grades_row[:grade]).to eql(@override_grade)
      end
    end

    context 'when override is disabled' do

      before(:all) do
        @canvas.load_gradebook course
        @canvas.disallow_grade_override
      end

      it 'downloads the calculated grade rather than the override grade' do
        e_grades = if @grades_are_final
                     @e_grades_export_page.download_final_grades(@driver, course, primary_section)
                   else
                     @e_grades_export_page.download_current_grades(@driver, course, primary_section)
                   end

        e_grades_row = e_grades.find { |r| r[:id] == @test_student.sis_id }
        expect(e_grades_row[:grade]).to eql(@test_grade)
      end
    end
  end

  describe 'user role restrictions' do

    before(:all) do
      [lead_ta, ta, designer, reader, student, waitlist, observer].each do |user|
        @course_add_user_page.load_embedded_tool(@driver, course)
        @course_add_user_page.search(user.uid, 'CalNet UID')
        @course_add_user_page.add_user_by_uid(user, primary_section)
      end
    end

    [lead_ta, ta, designer, reader, student, waitlist, observer].each do |user|
      it "allows a course #{user.role} to access the tool if permitted to do so" do
        @canvas.masquerade_as(user, course)
        logger.debug "Checking a #{user.role}'s access to the tool"
        @e_grades_export_page.load_embedded_tool(@driver, course)

        if ['Lead TA', 'TA', 'Reader'].include? user.role
          @canvas.load_gradebook course
          @canvas.click_e_grades_export_button
          @e_grades_export_page.switch_to_canvas_iframe
          @e_grades_export_page.not_auth_msg_element.when_visible Utils.medium_wait

        elsif ['Designer', 'Student', 'Waitlist Student', 'Observer'].include? user.role
          @e_grades_export_page.load_embedded_tool(@driver, course)
          @e_grades_export_page.not_auth_msg_element.when_visible Utils.medium_wait
        end
      end
    end
  end
end
