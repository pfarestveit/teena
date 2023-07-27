unless ENV['STANDALONE']

  require_relative '../../util/spec_helper'

  describe 'bCourses E-Grades Export' do

    include Logging

    test = RipleyTestConfig.new
    site = test.get_e_grades_export_site
    teacher = site.course.teachers.first
    non_teachers = [
      test.lead_ta,
      test.ta,
      test.designer,
      test.reader,
      test.observer,
      test.students.first,
      test.wait_list_student
    ]

    before(:all) do
      @driver = Utils.launch_browser
      @cal_net = Page::CalNetPage.new @driver
      @canvas_api = CanvasAPIPage.new @driver
      @canvas = Page::CanvasGradesPage.new @driver
      @canvas_assignments_page = Page::CanvasAssignmentsPage.new @driver
      @splash_page = RipleySplashPage.new @driver
      @e_grades_export_page = RipleyEGradesPage.new @driver
      @course_add_user_page = RipleyAddUserPage.new @driver

      @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
      section_ids = @canvas_api.get_course_site_sis_section_ids site
      test.get_existing_site_data(site, section_ids)
      @primary_section = site.sections.find &:primary
      @prim_sec_sids = @primary_section.enrollments.map &:sid
      @secondary_section = site.sections.reject(&:primary).first
      @sec_sec_sids = @secondary_section.enrollments.map(&:sid) if @secondary_section
      @canvas.set_canvas_ids([teacher] + site.manual_members)

      # Create an ungraded assignment to use for testing manual grading policy

      @canvas.masquerade_as teacher
      @ungraded_assignment = Assignment.new title: test.id
      @canvas.set_grade_policy_manual site
      @canvas_assignments_page.create_assignment(site, @ungraded_assignment)
    end

    after(:all) { Utils.quit_browser @driver }

    it 'offers an E-Grades Export button on the Gradebook' do
      @canvas.load_gradebook site
      @canvas.click_e_grades_export_button
      @e_grades_export_page.wait_until(Utils.medium_wait) { @e_grades_export_page.title == 'Download E-Grades' }
      expect(@e_grades_export_page.i_frame_form_element? test.base_url).to be true
    end

    context 'when no grading scheme is enabled and an assignment is un-posted' do

      before(:all) { @canvas.disable_grading_scheme site }

      before(:each) { @e_grades_export_page.load_embedded_tool site }

      it('offers a "Course Settings" link') { @e_grades_export_page.click_course_settings_button site }

      it 'offers a "How do I post grades for an assignment?" link' do
        title = 'How do I post grades for an assignment'
        expect(@e_grades_export_page.external_link_valid?(@e_grades_export_page.how_to_post_grades_link_element, title)).to be true
      end

      it('allows the user to Cancel') { @e_grades_export_page.click_cancel site }

      it 'prevents the user continuing' do
        @e_grades_export_page.continue_button_element.when_visible Utils.medium_wait
        expect(@e_grades_export_page.continue_button_element.attribute('disabled')).to eql('true')
      end
    end

    context 'when a grading scheme is enabled and an assignment is un-posted' do

      before(:all) { @canvas.enable_grading_scheme course }

      before(:each) { @e_grades_export_page.load_embedded_tool site }

      it('offers a "Course Settings" link') { @e_grades_export_page.click_course_settings_button site }

      it 'offers a "How do I post grades for an assignment?" link' do
        title = 'How do I post grades for an assignment'
        expect(@e_grades_export_page.external_link_valid?(@e_grades_export_page.how_to_post_grades_link_element, title)).to be true
      end

      it('allows the user to Cancel') { @e_grades_export_page.click_cancel site }

      it 'allows the user to Continue' do
        @e_grades_export_page.click_continue
        @e_grades_export_page.download_final_grades_element.when_visible Utils.medium_wait
      end
    end

    context 'when no assignment is muted and a grading scheme is enabled' do

      before(:all) do
        @e_grades_export_page.load_embedded_tool site
        @e_grades_export_page.click_continue
      end

      it 'allows the user the select any section on the course site' do
        # Parenthetical in section labels isn't shown on e-grades tool
        expected_options = site.sections.map { |s| "#{s.course} #{s.label}" }
        visible_options = @e_grades_export_page.sections_select_options.map &:strip
        if expected_options.length > 1
          expect(visible_options.sort).to eql(expected_options.sort)
        end
      end

      it 'requires the user to select a pass / no pass cutoff grade' do
        expect(@e_grades_export_page.download_current_grades_element.enabled?).to be false
        expect(@e_grades_export_page.download_current_grades_element.enabled?).to be false
      end

      shared_examples 'CSV downloads' do |cutoff|

        it 'allows the user to download current grades for a primary section' do
          csv = @e_grades_export_page.download_current_grades(site, @primary_section, cutoff)
          if site.course.term == test.current_term.name
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
          if @secondary_section
            csv = @e_grades_export_page.download_current_grades(site, @secondary_section, cutoff)
            if site.course.term.name == test.current_term.name
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
          csv = @e_grades_export_page.download_final_grades(site, @primary_section, cutoff)
          if site.course.term == test.current_term.name
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
          if @secondary_section
            csv = @e_grades_export_page.download_final_grades(site, @secondary_section, cutoff)
            if site.course.term == test.current_term.name
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
        ccn = @primary_section.id.to_s
        @students = site.sections.enrollments
        @e_grades = @e_grades_export_page.download_final_grades(site, @primary_section, 'C-')
      end

      it 'has the right column headers' do
        expected_header = %w(id name grade grading_basis comments).map { |h| h.to_sym }
        actual_header = (@e_grades.map { |h| h.keys }).flatten.uniq
        logger.debug "Expecting #{expected_header} and got #{actual_header}"
        expect(actual_header).to eql(expected_header)
      end

      it 'has the right SIDs' do
        expected_sids = '' # TODO
        actual_sids = @e_grades.map { |s| s[:id] }.sort
        logger.debug "Expecting #{expected_sids} and got #{actual_sids}"
        expect(actual_sids.any? &:empty?).to be false
        @e_grades_export_page.wait_until(1,  "Missing: #{expected_sids - actual_sids}. Unexpected: #{actual_sids - expected_sids}") do
          expected_sids == actual_sids
        end
      end

      it 'has the right names' do
        # Compare last names only, since preferred names can cause mismatches
        expected_names = '' # TODO
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
        expected_grading_bases = %w(CPN DPN EPN ESU FRZ GRD)
        actual_grading_bases = @e_grades.map { |b| b[:grading_basis] }
        logger.debug "Expecting #{expected_grading_bases} and got #{actual_grading_bases.uniq}"
        expect(actual_grading_bases.any? &:empty?).to be false
        expect(actual_grading_bases - expected_grading_bases).to be_empty
      end
    end

    describe 'final grade' do

      before(:all) do
        students = @canvas.get_students(site, @primary_section)
        @canvas.enable_grading_scheme site
        @canvas.load_gradebook site
        @grades_are_final = @canvas.grades_final?
        logger.info "Grades are final is #{@grades_are_final}"
        @canvas.hit_escape

        # Get actual grade data for one student
        gradebook_grade_data = students.map do |user|
          user.sis_id = '' # TODO
          user.full_name = '' # TODO
          user.sis_id.nil? ? nil : @canvas.student_score(user)
        end
        gradebook_grade_data.compact!
        test_data = gradebook_grade_data.find { |d| d.instance_of? Hash }
        logger.debug "Test data: #{test_data}"

        @test_student = test_data[:student]
        @test_grade = test_data[:grade]
        @override_grade = %w(A A- B+ B B- C+ C C- D+ D D- F).find { |g| g != @test_grade }
      end

      context 'when override is enabled' do

        before(:all) do
          @canvas.load_gradebook site
          @canvas.allow_grade_override
          @canvas.enter_override_grade(site, @test_student, @override_grade)
        end

        it 'downloads the override grade rather than the calculated grade in current grades' do
          e_grades = @e_grades_export_page.download_current_grades(site, @primary_section)
          e_grades_row = e_grades.find { |r| r[:id] == @test_student.sis_id }
          expect(e_grades_row[:grade]).to eql(@override_grade)
        end

        it 'downloads the override grade rather than the calculated grade in final grades' do
          e_grades = @e_grades_export_page.download_final_grades(site, @primary_section)
          e_grades_row = e_grades.find { |r| r[:id] == @test_student.sis_id }
          expect(e_grades_row[:grade]).to eql(@override_grade)
        end
      end

      context 'when override is disabled' do

        before(:all) do
          @canvas.load_gradebook site
          @canvas.disallow_grade_override
        end

        it 'downloads the calculated grade rather than the override grade' do
          e_grades = if @grades_are_final
                       @e_grades_export_page.download_final_grades(site, @primary_section)
                     else
                       @e_grades_export_page.download_current_grades(site, @primary_section)
                     end

          e_grades_row = e_grades.find { |r| r[:id] == @test_student.sis_id }
          expect(e_grades_row[:grade]).to eql(@test_grade)
        end
      end
    end

    describe 'user role restrictions' do

      before(:all) do
        primary_sec_opt = "#{@primary_section.course} #{@primary_section.label}"
        non_teachers.each do |user|
          @course_add_user_page.load_embedded_tool site
          @course_add_user_page.search(user.uid, 'CalNet UID')
          @course_add_user_page.add_user_by_uid(user, primary_sec_opt)
        end
      end

      [test.lead_ta, test.ta, test.reader].each do |user|
        it "denies #{user.role} #{user.uid} access to the tool" do
          @canvas.masquerade_as(user, site)
          @canvas.load_gradebook site
          @canvas.click_e_grades_export_button
          @e_grades_export_page.switch_to_canvas_iframe
          @e_grades_export_page.not_auth_msg_element.when_visible Utils.medium_wait
        end
      end

      it "denies #{test.designer.role} #{test.designer.uid} access to the tool" do
        @canvas.masquerade_as(test.designer, site)
        @e_grades_export_page.load_embedded_tool site
        @e_grades_export_page.not_auth_msg_element.when_visible Utils.medium_wait
      end

      [test.observer, test.students.first, test.wait_list_student].each do |user|
        it "denies #{user.role} #{user.uid} access to the tool" do
          @canvas.masquerade_as(user, site)
          @e_grades_export_page.hit_embedded_tool_url site
          @canvas.wait_for_error(@canvas.access_denied_msg_element, @e_grades_export_page.not_auth_msg_element)
        end
      end
    end
  end
end
