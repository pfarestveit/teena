require_relative '../../util/spec_helper'

unless ENV['DEPS']

  include Logging

  test = BOACTestConfig.new
  test.degree_progress({enrolled: true})
  template = test.degree_templates.find { |t| t.name.include? 'Course Workflows' }

  describe 'A BOA degree check course' do

    before(:all) do

      # TEST DATA

      @student = ENV['UIDS'] ? (test.students.find { |s| s.uid == ENV['UIDS'] }) : test.cohort_members.shuffle.first
      @degree_check = DegreeProgressChecklist.new(template, @student)

      @cats_with_courses = @degree_check.categories.select { |cat| cat.course_reqs.any? }
      @course_req_1 = @cats_with_courses.first.course_reqs.first
      @course_req_2 = @cats_with_courses.last.course_reqs.last
      @cat_no_subs_no_courses = @degree_check.categories.find { |cat| !cat.sub_categories && cat.course_reqs.empty? }
      @cat_with_courses_no_subs = @degree_check.categories.find { |cat| !cat.sub_categories && cat.course_reqs.any? }
      cats_with_subs = @degree_check.categories.select { |cat| cat.sub_categories&.any? }
      @cat_with_subs = cats_with_subs.first
      cats_with_subs.find do |cat|
        @sub_cat_no_courses = cat.sub_categories.find { |sub| sub.course_reqs.empty? }
      end
      cats_with_subs.find do |cat|
        @sub_cat_with_courses = cat.sub_categories.find { |sub| sub.course_reqs.any? }
      end
      @course_req_3 = @sub_cat_with_courses.course_reqs.last

      logger.debug "Top level category course reqs '#{@course_req_1.name}' and '#{@course_req_2.name}'"
      logger.debug "Top level category with no subcategories and no courses '#{@cat_no_subs_no_courses.name}'"
      logger.debug "Top level category with no subcategories but with courses '#{@cat_with_courses_no_subs.name}'"
      logger.debug "Top level category with subcategory '#{@cat_with_subs.name}'"
      logger.debug "Subcategory with no courses '#{@sub_cat_no_courses.name}'"
      logger.debug "Subcategory with courses '#{@sub_cat_with_courses.name}'"

      @driver = Utils.launch_browser
      @homepage = BOACHomePage.new @driver
      @pax_manifest = BOACPaxManifestPage.new @driver
      @degree_templates_mgmt_page = BOACDegreeTemplateMgmtPage.new @driver
      @degree_template_page = BOACDegreeTemplatePage.new @driver
      @student_page = BOACStudentPage.new @driver
      @student_api_page = BOACApiStudentPage.new @driver
      @degree_check_create_page = BOACDegreeCheckCreatePage.new @driver
      @degree_check_page = BOACDegreeCheckPage.new @driver

      unless test.advisor.degree_progress_perm == DegreeProgressPerm::WRITE
        @homepage.dev_auth
        @pax_manifest.load_page
        @pax_manifest.set_deg_prog_perm(test.advisor, BOACDepartments::COE, DegreeProgressPerm::WRITE)
        @pax_manifest.log_out
      end

      # Create template
      @homepage.dev_auth test.advisor
      @homepage.click_degree_checks_link
      @degree_templates_mgmt_page.create_new_degree template
      @degree_template_page.complete_template template

      # Create student degree check
      @degree_check_create_page.load_page @student
      @degree_check_create_page.create_new_degree_check(@degree_check)

      # Find student course data
      @student_api_page.get_data(@driver, @student)
      @in_progress_courses = @student_api_page.degree_progress_in_prog_courses @degree_check
      @unassigned_courses = @student_api_page.degree_progress_courses @degree_check
      @completed_course_0 = @unassigned_courses[0]
      @completed_course_1 = @unassigned_courses[1]
      @completed_course_2 = @unassigned_courses[2]
      @completed_course_3 = @unassigned_courses[3]
      @completed_course_4 = @unassigned_courses[4]
      logger.info "Completed courses: #{@unassigned_courses[0..4].map &:name}"

      @degree_check_page.load_page @degree_check
    end

    after(:all) { Utils.quit_browser @driver }

    context 'requirement' do

      it 'can be marked ignored or completed' do
        @degree_check_page.click_edit_course_req @course_req_3
        @degree_check_page.click_ignore_reqt
        @degree_check_page.click_save_req_edit
        expect(@degree_check_page.visible_course_req_name_struck? @course_req_3).to be true
      end

      it 'can be unmarked ignored or completed' do
        @degree_check_page.click_edit_course_req @course_req_3
        @degree_check_page.click_ignore_reqt
        @degree_check_page.click_save_req_edit
        expect(@degree_check_page.visible_course_req_name_struck? @course_req_3).to be false
      end
    end

    context 'when in progress' do

      it 'appears in the in progress section' do
        @degree_check_page.wait_until(Utils.short_wait) { @degree_check_page.in_progress_course_elements.any? }
        expected = @in_progress_courses.map { |c| "#{c.term_id}-#{c.ccn}" }
        actual = @degree_check_page.in_progress_course_ccns
        @degree_check_page.wait_until(1, "Missing: #{expected - actual}. Unexpected: #{actual - expected}") do
          actual.sort == expected.sort
        end
      end

      it 'shows the right course name' do
        @in_progress_courses.each do |course|
          name = "#{course.name}#{ + '(WAITLISTED)' if course.waitlisted}".gsub(' ', '')
          logger.debug "Checking for #{course.name}"
          expect(@degree_check_page.in_progress_course_code(course).gsub(/\s+/, '')).to eql(name)
        end
      end

      it 'shows the right course units' do
        @in_progress_courses.each do |course|
          logger.debug "Checking for #{course.units}"
          expect(@degree_check_page.in_progress_course_units(course)).to eql(course.units)
        end
      end
    end

    context 'when unassigned' do

      it 'appears in the unassigned section' do
        @degree_check_page.wait_until(Utils.short_wait) { @degree_check_page.unassigned_course_elements.any? }
        expected = @unassigned_courses.map { |c| "#{c.term_id}-#{c.ccn}" }
        actual = @degree_check_page.unassigned_course_ccns
        @degree_check_page.wait_until(1, "Missing: #{expected - actual}. Unexpected: #{actual - expected}") do
          actual.sort == expected.sort
        end
      end

      it 'shows the right course name' do
        @unassigned_courses.each do |course|
          logger.debug "Checking for #{course.name}"
          expect(@degree_check_page.unassigned_course_code(course)).to eql(course.name)
        end
      end

      it 'shows the right course units' do
        @unassigned_courses.each do |course|
          logger.debug "Checking for #{course.units}"
          expect(@degree_check_page.unassigned_course_units(course)).to eql(course.units)
        end
      end

      it 'shows the right course grade' do
        @unassigned_courses.each do |course|
          logger.debug "Checking for #{course.grade}"
          expect(@degree_check_page.unassigned_course_grade(course)).to eql(course.grade)
        end
      end

      it 'shows the right course term' do
        @unassigned_courses.each do |course|
          term = Utils.sis_code_to_term_name(course.term_id)
          logger.debug "Checking for #{term}"
          expect(@degree_check_page.unassigned_course_term(course)).to eql(term)
        end
      end

      context 'and edited' do

        after(:each) { @degree_check_page.click_cancel_course_edit if @degree_check_page.course_cancel_button? }

        it 'can be canceled' do
          @degree_check_page.click_edit_unassigned_course @completed_course_0
          @degree_check_page.click_cancel_course_edit
        end

        it 'allows a user to add a note' do
          @completed_course_0.note = "Teena wuz here #{test.id}" * 10
          @degree_check_page.edit_unassigned_course @completed_course_0
          expect(@degree_check_page.unassigned_course_note @completed_course_0).to eql(@completed_course_0.note)
        end

        it('allows a user to expand a note') { @degree_check_page.expand_unassigned_course_note @completed_course_0 }
        it('allows a user to hide a note') { @degree_check_page.click_hide_note }

        it 'allows a user to edit a note' do
          @completed_course_0.note = "EDITED - #{@completed_course_0.note}"
          @degree_check_page.edit_unassigned_course @completed_course_0
          expect(@degree_check_page.unassigned_course_note @completed_course_0).to eql(@completed_course_0.note)
        end

        it 'allows a user to remove a note' do
          @completed_course_0.note = ''
          @degree_check_page.edit_unassigned_course @completed_course_0
          expect(@degree_check_page.unassigned_course_note @completed_course_0).to eql('—')
        end

        it 'allows a user to change units to another integer' do
          @completed_course_0.units = (@completed_course_0.units.to_i + 1).to_s
          @degree_check_page.edit_unassigned_course @completed_course_0
          expect(@degree_check_page.unassigned_course_units @completed_course_0).to eql(@completed_course_0.units)
        end

        it 'shows an indicator if the user has edited the course units' do
          expect(@degree_check_page.unassigned_course_units_flag? @completed_course_0).to be true
        end

        it 'does not allow a user to change units to a non-number' do
          @degree_check_page.click_edit_unassigned_course @completed_course_0
          @degree_check_page.enter_course_units 'A'
          @degree_check_page.col_req_course_units_error_msg_element.when_visible 1
          expect(@degree_check_page.course_update_button_element.enabled?).to be false
        end

        it 'allows a user to change units to a decimal number' do
          @completed_course_0.units = (@completed_course_0.units.to_i + 0.53).round(2).to_s
          @degree_check_page.edit_unassigned_course @completed_course_0
          expect(@degree_check_page.unassigned_course_units @completed_course_0).to eql(@completed_course_0.units)
        end

        it 'does not allow a user to change units to a integer greater than two digits' do
          @degree_check_page.click_edit_unassigned_course @completed_course_0
          @degree_check_page.enter_course_units '100'
          @degree_check_page.col_req_course_units_error_msg_element.when_visible 1
          expect(@degree_check_page.course_update_button_element.enabled?).to be false
        end
      end
    end

    context 'when assigned to a course requirement' do

      before(:all) do
        @completed_course_0.note = "Teena wuz here again #{test.id}" * 10
        @degree_check_page.edit_unassigned_course @completed_course_0
      end

      it 'updates the requirement row with the course name' do
        @degree_check_page.assign_completed_course(@completed_course_0, @course_req_1)
      end

      it 'updates the requirement row with the course units' do
        expect(@degree_check_page.assigned_course_units(@completed_course_0)).to eql(@completed_course_0.units)
      end

      it 'updates the requirement row with the course grade' do
        expect(@degree_check_page.assigned_course_grade(@completed_course_0)).to eql(@completed_course_0.grade)
      end

      it 'updates the requirement row with the course note' do
        expect(@degree_check_page.assigned_course_note(@completed_course_0)).to eql(@completed_course_0.note)
      end

      it 'removes the course from the unassigned courses list' do
        expect(@degree_check_page.unassigned_course_ccns).not_to include("#{@completed_course_0.term_id}-#{@completed_course_0.ccn}")
      end

      it 'prevents another course being assigned to the same requirement' do
        @degree_check_page.click_unassigned_course_select @unassigned_courses.last
        expect(@degree_check_page.unassigned_course_req_option(@unassigned_courses.last, @course_req_1).exists?).to be false
      end

      it 'cannot by assigned to a campus requirement' do
        opts = @degree_check_page.unassigned_course_req_options(@unassigned_courses.last)
        reqts = ['Entry Level Writing', 'American History', 'American Institutions', 'American Cultures']
        opts.each do |o|
          expect(reqts.any? { |reqt| o.include?(reqt) }).to be false
        end
      end

      context 'and edited' do

        after(:each) { @degree_check_page.click_cancel_course_edit if @degree_check_page.course_cancel_button? }

        it 'can be canceled' do
          @degree_check_page.click_edit_assigned_course @completed_course_0
          @degree_check_page.click_cancel_course_edit
        end

        it 'allows a user to remove a note' do
          @completed_course_0.note = ''
          @degree_check_page.edit_assigned_course @completed_course_0
          expect(@degree_check_page.assigned_course_note(@completed_course_0).to_s).to eql('—')
        end

        it 'allows a user to add a note' do
          @completed_course_0.note = "Nota bene #{test.id}"
          @degree_check_page.edit_assigned_course @completed_course_0
          expect(@degree_check_page.assigned_course_note @completed_course_0).to eql(@completed_course_0.note)
        end

        it('allows a user to expand a note') { @degree_check_page.expand_assigned_course_note @completed_course_0 }
        it('allows a user to hide a note') { @degree_check_page.click_hide_note }

        it 'allows a user to edit a note' do
          @completed_course_0.note = "EDITED - #{@completed_course_0.note}"
          @degree_check_page.edit_assigned_course @completed_course_0
          expect(@degree_check_page.assigned_course_note @completed_course_0).to eql(@completed_course_0.note)
        end

        it 'allows a user to change units to another integer' do
          @completed_course_0.units = (@completed_course_0.units.to_i + 1).to_s
          @degree_check_page.edit_assigned_course @completed_course_0
          expect(@degree_check_page.assigned_course_units @completed_course_0).to eql(@completed_course_0.units)
        end

        it 'allows a user to change units to a decimal number' do
          @completed_course_0.units = (@completed_course_0.units.to_f + 0.53).to_s
          @degree_check_page.edit_assigned_course @completed_course_0
          expect(@degree_check_page.assigned_course_units @completed_course_0).to eql(@completed_course_0.units)
        end

        it 'shows an indicator if the user has edited the course units' do
          expect(@degree_check_page.assigned_course_units_flag? @completed_course_0).to be true
        end

        it 'does not allow a user to change units to a non-number' do
          @degree_check_page.click_edit_assigned_course @completed_course_0
          @degree_check_page.enter_course_units 'A'
          @degree_check_page.col_req_course_units_error_msg_element.when_visible 1
          expect(@degree_check_page.course_update_button_element.enabled?).to be false
        end

        it 'does not allow a user to change units to a integer greater than two digits' do
          @degree_check_page.click_edit_assigned_course @completed_course_0
          @degree_check_page.enter_course_units '100'
          @degree_check_page.col_req_course_units_error_msg_element.when_visible 1
          expect(@degree_check_page.course_update_button_element.enabled?).to be false
        end
      end

      context 'and the course grade has been updated' do

        before { BOACUtils.update_degree_course_grade(@completed_course_0, @student, 'F+') }

        it 'shows the most current SIS grade' do
          @degree_check_page.load_page @degree_check
          @degree_check_page.assigned_course_row(@completed_course_0).when_visible Utils.short_wait
          expect(@degree_check_page.assigned_course_grade(@completed_course_0)).to eql(@completed_course_0.grade)
        end
      end
    end

    context 'when unassigned from a course requirement' do

      it 'reverts the requirement row course name' do
        @degree_check_page.unassign_course(@completed_course_0, @course_req_1)
      end

      it 'reverts the requirement row course units' do
        expect(@degree_check_page.visible_course_req_units @course_req_1).to eql(@course_req_1.units || '—')
      end

      it 'removes the requirement row course grade' do
        expect(@degree_check_page.visible_course_req_grade @course_req_1).to be_empty
      end

      it 'removes the requirement row course note' do
        expect(@degree_check_page.visible_course_req_note @course_req_1).to be_nil
      end

      it 'restores the course to the unassigned courses list' do
        expect(@degree_check_page.unassigned_course_row(@completed_course_0).exists?).to be true
      end
    end

    context 'when sent to the junk drawer' do

      it 'shows the right course name' do
        @degree_check_page.wish_to_cornfield @completed_course_0
      end

      it 'shows the right course units' do
        expect(@degree_check_page.junk_course_units(@completed_course_0)).to eql(@completed_course_0.units.to_s)
      end

      it 'shows the right course grade' do
        expect(@degree_check_page.junk_course_grade(@completed_course_0)).to eql(@completed_course_0.grade)
      end

      it 'can be edited but canceled' do
        @degree_check_page.click_edit_junk_course @completed_course_0
        @degree_check_page.click_cancel_course_edit
      end

      it 'allows a user to add a note' do
        @completed_course_0.note = "This course no longer sparks joy #{test.id}"
        @degree_check_page.edit_junk_course @completed_course_0
        expect(@degree_check_page.junk_course_note @completed_course_0).to eql(@completed_course_0.note)
      end

      it('allows a user to expand a note') { @degree_check_page.expand_junk_course_note @completed_course_0 }
      it('allows a user to hide a note') { @degree_check_page.click_hide_note }

      it 'allows a user to change units to another integer' do
        @completed_course_0.units = 6
        @degree_check_page.edit_junk_course @completed_course_0
        expect(@degree_check_page.junk_course_units @completed_course_0).to eql(@completed_course_0.units.to_s)
      end

      it 'shows an indicator if the user has edited the course units' do
        expect(@degree_check_page.junk_course_units_flag? @completed_course_0).to be true
      end

      it 'can be assigned to a course requirement' do
        @degree_check_page.assign_completed_course(@completed_course_0, @course_req_1)
      end

      it 'can be returned to the junk drawer from a course requirement' do
        @degree_check_page.wish_to_cornfield(@completed_course_0, @course_req_1)
      end

      it 'can be unassigned from the junk drawer' do
        @degree_check_page.unassign_course(@completed_course_0)
      end
    end

    context 'when reassigned from one course requirement to another' do

      before(:all) { @degree_check_page.assign_completed_course(@completed_course_0, @course_req_1) }

      it 'updates the requirement row with the course name' do
        @degree_check_page.reassign_course(@completed_course_0, @course_req_1, @course_req_2)
      end

      it 'updates the requirement row with the course units' do
        expect(@degree_check_page.assigned_course_units(@completed_course_0)).to eql(@completed_course_0.units.to_s)
      end

      it 'removes the course from the unassigned courses list' do
        expect(@degree_check_page.unassigned_course_ccns).not_to include("#{@completed_course_0.term_id}-#{@completed_course_0.ccn}")
      end
    end

    context 'when assigned to a category' do

      before(:all) do
        @completed_course_1.note = "Teena wuz here too #{test.id}"
        @degree_check_page.edit_unassigned_course @completed_course_1
      end

      it 'creates a new course row when the category has no subcategory and no course' do
        @degree_check_page.assign_completed_course(@completed_course_1, @cat_no_subs_no_courses)
        expect(@degree_check_page.assigned_course_units @completed_course_1).to eql(@completed_course_1.units)
        expect(@degree_check_page.assigned_course_grade @completed_course_1).to eql(@completed_course_1.grade)
        expect(@degree_check_page.assigned_course_note @completed_course_1).to eql(@completed_course_1.note.to_s)
        expect(@degree_check_page.unassigned_course_ccns).not_to include("#{@completed_course_1.term_id}-#{@completed_course_1.ccn}")
      end

      it 'creates a new course row when the category has no subcategory but does have a course' do
        @degree_check_page.assign_completed_course(@completed_course_2, @cat_with_courses_no_subs)
        expect(@degree_check_page.assigned_course_units @completed_course_2).to eql(@completed_course_2.units)
        expect(@degree_check_page.assigned_course_grade @completed_course_2).to eql(@completed_course_2.grade)
        expect(@degree_check_page.assigned_course_note @completed_course_2).to eql('—')
        expect(@degree_check_page.unassigned_course_ccns).not_to include("#{@completed_course_2.term_id}-#{@completed_course_2.ccn}")
      end

      it 'cannot be added to a category with a subcategory' do
        @degree_check_page.click_unassigned_course_select @completed_course_3
        @degree_check_page.wait_until(2) { @degree_check_page.unassigned_course_option_els(@completed_course_3).any? }
        el = @degree_check_page.unassigned_course_option_els(@completed_course_3).find { |el| el.attribute('id') == "assign-course-to-option-#{@cat_with_subs.id}" }
        expect(el.attribute('aria-disabled')).to eql('true')
      end

      it 'creates a new course row when the category is a subcategory without courses' do
        @degree_check_page.hit_escape
        @degree_check_page.assign_completed_course(@completed_course_3, @sub_cat_no_courses)
        expect(@degree_check_page.assigned_course_units @completed_course_3).to eql(@completed_course_3.units)
        expect(@degree_check_page.assigned_course_grade @completed_course_3).to eql(@completed_course_3.grade)
        expect(@degree_check_page.assigned_course_note @completed_course_3).to eql('—')
        expect(@degree_check_page.unassigned_course_ccns).not_to include("#{@completed_course_3.term_id}-#{@completed_course_3.ccn}")
      end

      it 'creates a new course row when the category is a subcategory with courses' do
        @degree_check_page.assign_completed_course(@completed_course_4, @sub_cat_with_courses)
        expect(@degree_check_page.assigned_course_units @completed_course_4).to eql(@completed_course_4.units)
        expect(@degree_check_page.assigned_course_grade @completed_course_4).to eql(@completed_course_4.grade)
        expect(@degree_check_page.assigned_course_note @completed_course_4).to eql('—')
        expect(@degree_check_page.unassigned_course_ccns).not_to include("#{@completed_course_4.term_id}-#{@completed_course_4.ccn}")
      end
    end

    context 'and reassigned' do

      it 'can be moved from a category to a subcategory' do
        @degree_check_page.reassign_course(@completed_course_1, @cat_no_subs_no_courses, @sub_cat_no_courses)
      end

      it 'can be moved from a subcategory to category' do
        @degree_check_page.reassign_course(@completed_course_1, @sub_cat_no_courses, @cat_no_subs_no_courses)
      end

      it 'can be moved from a category to a course requirement' do
        @degree_check_page.reassign_course(@completed_course_1, @cat_no_subs_no_courses, @course_req_1)
      end

      it 'can be moved from a course requirement to a subcategory' do
        @degree_check_page.reassign_course(@completed_course_1, @course_req_1, @sub_cat_no_courses)
      end

      it 'can be moved from a subcategory to a course requirement' do
        @degree_check_page.reassign_course(@completed_course_1, @sub_cat_no_courses, @course_req_1)
      end

      it 'can be moved from a course requirement to a category' do
        @degree_check_page.reassign_course(@completed_course_1, @course_req_1, @cat_no_subs_no_courses)
      end
    end

    context 'and unassigned from a category' do

      it 'deletes the row from the category' do
        @degree_check_page.unassign_course(@completed_course_1, @cat_no_subs_no_courses)
      end

      it 'restores the course to the unassigned courses list' do
        expect(@degree_check_page.unassigned_course_ccns).to include("#{@completed_course_1.term_id}-#{@completed_course_1.ccn}")
      end
    end

    context 'when copied' do

      it 'must already be assigned elsewhere but not in the same category' do
        @degree_check_page.click_copy_course_button @cat_with_courses_no_subs
        expected = [@completed_course_0, @completed_course_3, @completed_course_4].map &:name
        actual = @degree_check_page.copy_course_options
        expect(actual).to eql(expected.sort)
      end

      context 'to a category' do
        before(:all) do
          @completed_course_4.units = @completed_course_4.units.to_i + 1
          @completed_course_4.note = 'I\'ll give you fish, I\'ll give you candy'
          @degree_check_page.hit_escape
          @degree_check_page.click_cancel_course_copy
          @degree_check_page.edit_assigned_course @completed_course_4
          @cat_copy = @degree_check_page.copy_course(@completed_course_4, @cat_no_subs_no_courses)
        end

        it 'creates a row with the unedited course units' do
          expect(@degree_check_page.assigned_course_units @cat_copy).to eql(@cat_copy.units.to_s)
        end

        it 'creates a row with the course grade' do
          expect(@degree_check_page.assigned_course_grade @cat_copy).to eql(@cat_copy.grade)
        end

        it 'creates a row with the an unedited course note' do
          expect(@degree_check_page.assigned_course_note @cat_copy).to eql('—')
        end

        it 'displays an icon identifying itself as a copy' do
          expect(@degree_check_page.assigned_course_copy_flag? @cat_copy).to be true
        end

        it 'offers a delete button' do
          expect(@degree_check_page.assigned_course_delete_button(@cat_copy).exists?).to be true
        end

        it 'can be reassigned' do
          expect(@degree_check_page.assigned_course_select(@cat_copy).exists?).to be true
        end
      end

      context 'to a subcategory' do

        before(:all) { @sub_cat_copy = @degree_check_page.copy_course(@completed_course_4, @sub_cat_no_courses) }

        it 'creates a row with the unedited course units' do
          expect(@degree_check_page.assigned_course_units @sub_cat_copy).to eql(@sub_cat_copy.units.to_s)
        end

        it 'creates a row with the course grade' do
          expect(@degree_check_page.assigned_course_grade @sub_cat_copy).to eql(@sub_cat_copy.grade)
        end

        it 'creates a row with the an unedited course note' do
          expect(@degree_check_page.assigned_course_note @sub_cat_copy).to eql('—')
        end

        it 'displays an icon identifying itself as a copy' do
          expect(@degree_check_page.assigned_course_copy_flag? @sub_cat_copy).to be true
        end

        it 'offers a delete button' do
          expect(@degree_check_page.assigned_course_delete_button(@sub_cat_copy).exists?).to be true
        end

        it 'can be reassigned' do
          expect(@degree_check_page.assigned_course_select(@sub_cat_copy).exists?).to be true
        end

        context 'and edited' do

          it 'can be canceled' do
            @degree_check_page.click_edit_assigned_course @sub_cat_copy
            @degree_check_page.click_cancel_course_edit
          end

          it 'allows a user to add a note' do
            @sub_cat_copy.note = "I believe you, Mr Wilson"
            @degree_check_page.edit_assigned_course @sub_cat_copy
            expect(@degree_check_page.assigned_course_note @sub_cat_copy).to eql(@sub_cat_copy.note)
          end

          it 'allows a user to edit a note' do
            @sub_cat_copy.note = "I believe you anyway"
            @degree_check_page.edit_assigned_course @sub_cat_copy
            expect(@degree_check_page.assigned_course_note @sub_cat_copy).to eql(@sub_cat_copy.note)
          end

          it 'allows a user to remove a note' do
            @sub_cat_copy.note = ''
            @degree_check_page.edit_assigned_course @sub_cat_copy
            expect(@degree_check_page.assigned_course_note @sub_cat_copy).to eql('—')
          end

          it 'allows a user to change units to another integer' do
            @sub_cat_copy.units = 9
            @degree_check_page.edit_assigned_course @sub_cat_copy
            expect(@degree_check_page.assigned_course_units @sub_cat_copy).to eql(@sub_cat_copy.units.to_s)
          end

          it 'does not affect the original course row' do
            expect(@degree_check_page.assigned_course_note @completed_course_4).to eql(@completed_course_4.note.to_s)
            expect(@degree_check_page.assigned_course_units @completed_course_4).to eql(@completed_course_4.units.to_s)
          end
        end

        context 'and the course copy grade has been updated' do

          before { BOACUtils.update_degree_course_grade(@completed_course_4, @student, 'F+') }

          it 'shows the most current SIS grade' do
            @degree_check_page.load_page @degree_check
            @degree_check_page.assigned_course_row(@sub_cat_copy).when_visible Utils.short_wait
            expect(@degree_check_page.assigned_course_grade(@sub_cat_copy)).to eql(@completed_course_4.grade)
          end
        end

        context 'and deleted' do

          it 'can be canceled' do
            @degree_check_page.click_delete_assigned_course @sub_cat_copy
            @degree_check_page.wait_for_update_and_click @degree_check_page.cancel_delete_or_discard_button_element
          end

          it 'can be deleted' do
            @degree_check_page.delete_assigned_course @sub_cat_copy
          end

          it 'does not affect the original course row' do
            expect(@degree_check_page.assigned_course_name @completed_course_4).to eql(@completed_course_4.name)
          end
        end

        context 'and its original is unassigned' do

          before(:all) do
            @degree_check_page.copy_course(@completed_course_4, @sub_cat_no_courses)
            @degree_check_page.unassign_course(@completed_course_4, @sub_cat_with_courses)
          end

          it 'is deleted automatically' do
            expect(@degree_check_page.assigned_course_row(@sub_cat_copy).exists?).to be false
          end
        end
      end
    end
  end
end
