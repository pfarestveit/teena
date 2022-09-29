require_relative '../../util/spec_helper'

unless ENV['DEPS']

  include Logging

  test = BOACTestConfig.new
  test.degree_progress
  template = test.degree_templates.find { |t| t.name.include? 'Course Workflows' }

  describe 'A manual BOA degree check course' do

    before(:all) do

      # TEST DATA

      @student = test.cohort_members.shuffle.first
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

      logger.debug "Top level category course reqs '#{@course_req_1.name}' and '#{@course_req_2.name}'"
      logger.debug "Top level category with no subcategories and no courses '#{@cat_no_subs_no_courses.name}'"
      logger.debug "Top level category with no subcategories but with courses '#{@cat_with_courses_no_subs.name}'"
      logger.debug "Top level category with subcategory '#{@cat_with_subs.name}'"
      logger.debug "Subcategory with no courses '#{@sub_cat_no_courses.name}'"
      logger.debug "Subcategory with courses '#{@sub_cat_with_courses.name}'"

      @manual_course_0 = DegreeCompletedCourse.new manual: true,
                                                   name: "TEENA 101 #{test.id}",
                                                   units: '0.5',
                                                   grade: 'A++',
                                                   color: 'green',
                                                   units_reqts: [@degree_check.unit_reqts[0]],
                                                   note: "Course level note #{test.id}"
      @manual_course_1 = DegreeCompletedCourse.new manual: true,
                                                   name: "TEENA 1A #{test.id}",
                                                   units: '4.35'
      @manual_course_2 = DegreeCompletedCourse.new manual: true,
                                                   name: "TEENA 1B #{test.id}",
                                                   units: '4'
      @manual_course_3 = DegreeCompletedCourse.new manual: true,
                                                   name: "TEENA 1C #{test.id}",
                                                   units: '4'
      @manual_course_4 = DegreeCompletedCourse.new manual: true,
                                                   name: "TEENA COPIES 1A #{test.id}",
                                                   units: '4'
      @manual_course_5 = DegreeCompletedCourse.new manual: true,
                                                   name: "TEENA COPIES 1B #{test.id}",
                                                   units: '4'

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
      @degree_check_page.load_page @degree_check

      @transfer_course = @degree_check.completed_courses.find &:transfer_course
      BOACUtils.set_degree_manual_course_id(@degree_check, @transfer_course)
    end

    after(:all) { Utils.quit_browser @driver }

    context 'when a transfer course' do

      it 'is created automatically when the degree check is created' do
        @degree_check_page.wait_until(Utils.short_wait) do
          @degree_check_page.assigned_course_name(@transfer_course) == @transfer_course.name
        end
        expect(@degree_check_page.assigned_course_units(@transfer_course)).to eql(@transfer_course.units)
        expect(@degree_check_page.assigned_course_grade(@transfer_course)).to eql(@transfer_course.grade)
      end

      it 'can be edited' do
        @transfer_course.grade = 'A'
        @transfer_course.note = "Note #{test.id}"
        @transfer_course.units = '6'
        @degree_check_page.edit_assigned_course @transfer_course
        expect(@degree_check_page.assigned_course_grade @transfer_course).to eql(@transfer_course.grade)
        expect(@degree_check_page.assigned_course_note @transfer_course).to eql(@transfer_course.note)
        expect(@degree_check_page.assigned_course_units @transfer_course).to eql(@transfer_course.units)
      end

      it 'is reflected in the unit requirements' do
        @transfer_course.units_reqts.each do |req|
          expect(@degree_check_page.unit_req_course_units(req, @transfer_course)).to eql(@transfer_course.units.to_s)
        end
      end

      it('can be unassigned') { @degree_check_page.unassign_course @transfer_course }
    end

    context 'when created' do

      it 'can be canceled' do
        @degree_check_page.click_create_course @sub_cat_with_courses
        @degree_check_page.click_cancel_course_create
      end

      it 'requires a name' do
        @degree_check_page.click_create_course @sub_cat_with_courses
        @degree_check_page.enter_course_units @manual_course_0.units
        expect(@degree_check_page.create_course_save_button_element.enabled?).to be false
      end

      it 'does not require units' do
        @degree_check_page.enter_course_units ''
        @degree_check_page.enter_course_name @manual_course_0.name
        expect(@degree_check_page.create_course_save_button_element.enabled?).to be true
      end

      it 'can be saved' do
        @degree_check_page.click_cancel_course_create
        @degree_check_page.create_manual_course(@degree_check, @manual_course_0, @sub_cat_with_courses)
      end

      it 'shows the right course name' do
        expect(@degree_check_page.assigned_course_name(@manual_course_0)).to eql(@manual_course_0.name)
      end

      it 'shows the right course units' do
        expect(@degree_check_page.assigned_course_units(@manual_course_0)).to eql(@manual_course_0.units)
      end

      it 'shows the right course grade' do
        expect(@degree_check_page.assigned_course_grade(@manual_course_0)).to eql(@manual_course_0.grade)
      end

      it 'shows the right course note' do
        expect(@degree_check_page.assigned_course_note(@manual_course_0)).to eql(@manual_course_0.note)
      end
    end

    context 'when edited' do

      after(:each) { @degree_check_page.click_cancel_course_edit if @degree_check_page.course_cancel_button? }

      it 'can be canceled' do
        @degree_check_page.click_edit_assigned_course @manual_course_0
        @degree_check_page.click_cancel_course_edit
      end

      it 'requires a name' do
        @degree_check_page.click_edit_assigned_course @manual_course_0
        @degree_check_page.enter_course_name ''
        expect(@degree_check_page.course_update_button_element.enabled?).to be false
      end

      it 'does not require units' do
        @degree_check_page.click_edit_assigned_course @manual_course_0
        @degree_check_page.enter_course_name @manual_course_0.name
        @degree_check_page.enter_course_units ''
        expect(@degree_check_page.course_update_button_element.enabled?).to be true
      end

      it 'allows a user to edit the units' do
        @manual_course_0.units = ''
        @degree_check_page.edit_assigned_course @manual_course_0
        expect(@degree_check_page.assigned_course_units @manual_course_0).to eql('—')
      end

      it 'allows a user to edit the grade' do
        @manual_course_0.grade = 'F?'
        @degree_check_page.edit_assigned_course @manual_course_0
        expect(@degree_check_page.assigned_course_grade @manual_course_0).to eql(@manual_course_0.grade)
      end

      it 'allows a user to edit the color code' do
        @manual_course_0.color = 'blue'
        @degree_check_page.edit_assigned_course @manual_course_0
      end

      it 'allows a user to edit the note' do
        @manual_course_0.note = "EDITED - #{@manual_course_0.note}"
        @degree_check_page.edit_assigned_course @manual_course_0
        expect(@degree_check_page.assigned_course_note @manual_course_0).to eql(@manual_course_0.note)
      end
    end

    context 'when unassigned' do

      before(:all) { @degree_check_page.unassign_course(@manual_course_0, @sub_cat_with_courses) }

      context 'and edited' do

        after(:each) { @degree_check_page.click_cancel_course_edit if @degree_check_page.course_cancel_button? }

        it 'can be canceled' do
          @degree_check_page.click_edit_unassigned_course @manual_course_0
          @degree_check_page.click_cancel_course_edit
        end

        it 'requires a name' do
          @degree_check_page.click_edit_unassigned_course @manual_course_0
          @degree_check_page.enter_course_name ''
          expect(@degree_check_page.course_update_button_element.enabled?).to be false
        end

        it 'does not require units' do
          @degree_check_page.click_edit_unassigned_course @manual_course_0
          @degree_check_page.enter_course_name @manual_course_0.name
          @degree_check_page.enter_course_units ''
          expect(@degree_check_page.course_update_button_element.enabled?).to be true
        end

        it 'allows a user to edit the name' do
          @degree_check_page.click_edit_unassigned_course @manual_course_0
          @manual_course_0.name = "AGAIN #{@manual_course_0.name}"
          @degree_check_page.enter_course_name @manual_course_0.name
          @degree_check_page.click_save_course_edit
          expect(@degree_check_page.unassigned_course_code @manual_course_0).to eql(@manual_course_0.name)
        end

        it 'allows a user to edit the units' do
          @manual_course_0.units = '0.35'
          @degree_check_page.edit_unassigned_course @manual_course_0
          expect(@degree_check_page.unassigned_course_units @manual_course_0).to eql(@manual_course_0.units)
        end

        it 'allows a user to edit the grade' do
          @manual_course_0.grade = 'C#'
          @degree_check_page.edit_unassigned_course @manual_course_0
          expect(@degree_check_page.unassigned_course_grade @manual_course_0).to eql(@manual_course_0.grade)
        end

        it 'allows a user to edit the color code' do
          @manual_course_0.color = 'purple'
          @degree_check_page.edit_unassigned_course @manual_course_0
        end

        it 'allows a user to edit the unit fulfillment' do
          @manual_course_0.units_reqts = [@degree_check.unit_reqts[1]]
          @degree_check_page.edit_unassigned_course @manual_course_0
        end

        it 'allows a user to edit the note' do
          @manual_course_0.note = "AGAIN #{@manual_course_0.note}"
          @degree_check_page.edit_unassigned_course @manual_course_0
          expect(@degree_check_page.unassigned_course_note @manual_course_0).to eql(@manual_course_0.note)
        end
      end
    end

    context 'when assigned' do

      it 'can be moved to a category' do
        @degree_check_page.assign_completed_course(@manual_course_0, @cat_no_subs_no_courses)
      end

      it 'can be moved from a category to a subcategory' do
        @degree_check_page.reassign_course(@manual_course_0, @cat_no_subs_no_courses, @sub_cat_no_courses)
      end

      it 'can be moved from a subcategory to category' do
        @degree_check_page.reassign_course(@manual_course_0, @sub_cat_no_courses, @cat_no_subs_no_courses)
      end

      it 'can be moved from a category to a course requirement' do
        @degree_check_page.reassign_course(@manual_course_0, @cat_no_subs_no_courses, @course_req_1)
      end

      it 'can be moved from a course requirement to a subcategory' do
        @degree_check_page.reassign_course(@manual_course_0, @course_req_1, @sub_cat_no_courses)
      end

      it 'can be moved from a subcategory to a course requirement' do
        @degree_check_page.reassign_course(@manual_course_0, @sub_cat_no_courses, @course_req_2)
      end

      it 'can be unassigned' do
        @degree_check_page.unassign_course(@manual_course_0, @course_req_2)
      end

      it 'can be moved to the junk drawer' do
        @degree_check_page.wish_to_cornfield @manual_course_0
      end
    end

    context 'when deleted' do

      before(:all) do
        @degree_check_page.create_manual_course(@degree_check, @manual_course_1, @sub_cat_with_courses)
        @degree_check_page.unassign_course(@manual_course_1, @sub_cat_with_courses)

        @degree_check_page.create_manual_course(@degree_check, @manual_course_2, @sub_cat_with_courses)
        @degree_check_page.wish_to_cornfield(@manual_course_2, @sub_cat_with_courses)

        @degree_check_page.create_manual_course(@degree_check, @manual_course_3, @sub_cat_with_courses)
        @degree_check_page.reassign_course(@manual_course_3, @sub_cat_with_courses, @course_req_2)
      end

      it 'can be deleted from the unassigned list' do
        @degree_check_page.delete_unassigned_course @manual_course_1
        expect(@degree_check_page.unassigned_course_row(@manual_course_1).exists?).to be false
      end

      it 'can be deleted from the junk drawer' do
        @degree_check_page.delete_junk_course @manual_course_2
        expect(@degree_check_page.junk_course_row(@manual_course_2).exists?).to be false
      end

      it 'can be deleted from a requirement' do
        @degree_check_page.delete_assigned_course @manual_course_3
        expect(@degree_check_page.assigned_course_row(@manual_course_3).exists?).to be false
      end
    end

    context 'when copied' do

      before(:all) do
        @degree_check_page.create_manual_course(@degree_check, @manual_course_4, @sub_cat_with_courses)
        @degree_check_page.create_manual_course(@degree_check, @manual_course_5, @sub_cat_with_courses)
        @degree_check_page.reassign_course(@manual_course_4, @sub_cat_with_courses, @cat_no_subs_no_courses)
        @degree_check_page.reassign_course(@manual_course_5, @sub_cat_with_courses, @sub_cat_no_courses)
      end

      context 'to a category' do

        before(:all) do
          @degree_check_page.unassign_course(@manual_course_5, @sub_cat_with_courses)
          @cat_copy = @degree_check_page.copy_course(@manual_course_5, @cat_no_subs_no_courses)
        end

        it 'shows the copied course units' do
          expect(@degree_check_page.assigned_course_units @cat_copy).to eql(@cat_copy.units.to_s)
        end

        it 'shows the copied course grades' do
          expect(@degree_check_page.assigned_course_grade @cat_copy).to eql(@cat_copy.grade)
        end

        it 'shows the copied course note' do
          expect(@degree_check_page.assigned_course_note @cat_copy).to eql( @cat_copy.note || '—')
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

        before(:all) { @sub_cat_copy = @degree_check_page.copy_course(@manual_course_4, @sub_cat_no_courses) }

        it 'creates a row with the course units' do
          expect(@degree_check_page.assigned_course_units @sub_cat_copy).to eql(@sub_cat_copy.units.to_s)
        end

        it 'creates a row with the course grade' do
          expect(@degree_check_page.assigned_course_grade @sub_cat_copy).to eql(@sub_cat_copy.grade)
        end

        it 'creates a row with the course note' do
          expect(@degree_check_page.assigned_course_note @sub_cat_copy).to eql(@sub_cat_copy.note || '—')
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

          it 'allows a user to edit the name' do
            @degree_check_page.click_edit_assigned_course @sub_cat_copy
            @sub_cat_copy.name = "EDITED #{@sub_cat_copy.name}"
            @degree_check_page.enter_course_name @sub_cat_copy.name
            @degree_check_page.click_save_course_edit
            expect(@degree_check_page.assigned_course_name @sub_cat_copy).to eql("#{@sub_cat_copy.name}\nCourse satisfies multiple requirements.")
          end

          it 'allows a user to edit the units' do
            @sub_cat_copy.units = ''
            @degree_check_page.edit_assigned_course @sub_cat_copy
            expect(@degree_check_page.assigned_course_units @sub_cat_copy).to eql('—')
          end

          it 'allows a user to edit the grade' do
            @sub_cat_copy.grade = '£5'
            @degree_check_page.edit_assigned_course @sub_cat_copy
            expect(@degree_check_page.assigned_course_grade @sub_cat_copy).to eql(@sub_cat_copy.grade)
          end

          it 'allows a user to edit the color code' do
            @sub_cat_copy.color = 'blue'
            @degree_check_page.edit_assigned_course @sub_cat_copy
          end

          it 'allows a user to edit the unit fulfillment' do
            @sub_cat_copy.units_reqts = [@degree_check.unit_reqts[0]]
            @degree_check_page.edit_assigned_course @sub_cat_copy
          end

          it 'allows a user to edit the note' do
            @sub_cat_copy.note = "EDITED #{@sub_cat_copy.note}"
            @degree_check_page.edit_assigned_course @sub_cat_copy
            expect(@degree_check_page.assigned_course_note @sub_cat_copy).to eql(@sub_cat_copy.note.strip)
          end

          it 'does not affect the original course row' do
            expect(@degree_check_page.assigned_course_name @manual_course_4).to eql(@manual_course_4.name)
            expect(@degree_check_page.assigned_course_units @manual_course_4).to eql(@manual_course_4.units.to_s)
            expect(@degree_check_page.assigned_course_note @manual_course_4).to eql(@manual_course_4.note || '—')
            expect(@degree_check_page.assigned_course_grade @manual_course_4).to eql(@manual_course_4.grade.to_s)
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
            expect(@degree_check_page.assigned_course_name @manual_course_4).to eql(@manual_course_4.name)
          end
        end

        context 'and its original is unassigned' do

          before(:all) do
            @degree_check_page.copy_course(@manual_course_4, @sub_cat_no_courses)
            @degree_check_page.unassign_course(@manual_course_4, @cat_no_subs_no_courses)
          end

          it 'is deleted automatically' do
            expect(@degree_check_page.assigned_course_row(@sub_cat_copy).exists?).to be false
          end
        end
      end
    end
  end
end
