require_relative '../../util/spec_helper'

include Logging

test = BOACTestConfig.new
test.degree_progress
template = test.degree_templates.find { |t| t.name.include? BOACUtils.degree_major.first }

describe 'A BOA degree check' do

  before(:all) do
    @driver = Utils.launch_browser
    @homepage = BOACHomePage.new @driver
    @pax_manifest = BOACPaxManifestPage.new @driver
    @degree_templates_mgmt_page = BOACDegreeCheckMgmtPage.new @driver
    @degree_template_page = BOACDegreeCheckTemplatePage.new @driver
    @student_page = BOACStudentPage.new @driver
    @student_api_page = BOACApiStudentPage.new @driver
    @degree_check_create_page = BOACDegreeCheckCreatePage.new @driver
    @degree_check_page = BOACDegreeCheckPage.new @driver

    unless test.advisor.degree_progress_perm == DegreeProgressPerm::WRITE && test.read_only_advisor.degree_progress_perm == DegreeProgressPerm::READ
      @homepage.dev_auth
      @pax_manifest.load_page
      @pax_manifest.set_deg_prog_perm(test.advisor, BOACDepartments::COE, DegreeProgressPerm::WRITE)
      @pax_manifest.set_deg_prog_perm(test.read_only_advisor, BOACDepartments::COE, DegreeProgressPerm::READ)
      @pax_manifest.log_out
    end

    @homepage.dev_auth test.advisor
    @homepage.click_degree_checks_link
    @degree_templates_mgmt_page.create_new_degree template
    @degree_template_page.complete_template template

    @student = ENV['UIDS'] ? (test.students.find { |s| s.uid == ENV['UIDS'] }) : test.cohort_members.shuffle.first
    @degree_check = DegreeProgressChecklist.new(template, @student)
    @student_api_page.get_data(@driver, @student)
    @unassigned_courses = @student_api_page.degree_progress_courses

    # TEST DATA

    # Top level categories with course requirements
    @cats_with_courses = @degree_check.categories.select { |cat| cat.course_reqs&.any? }
    @course_req_1 = @cats_with_courses.first.course_reqs.first
    @course_req_2 = @cats_with_courses.last.course_reqs.last

    # Top level category with a subcategory
    cats_with_subs = @degree_check.categories.select { |cat| cat.sub_categories&.any? }
    @cat_with_subs = cats_with_subs.first

    # Top level category with no subcategories or course requirements
    @cat_no_subs_no_courses = @degree_check.categories.find { |cat| !cat.sub_categories && !cat.course_reqs }

    # Subcategory with course requirements
    cat_with_sub_and_courses = cats_with_subs.find { |cat| cat.sub_categories.find { |sub| sub.course_reqs&.any? } }
    @sub_cat_with_courses = cat_with_sub_and_courses.sub_categories.find { |sub| sub.course_reqs&.any? }

    @student_page.load_page @student
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when created' do

    it 'can be selected from a list of degree check templates' do
      @degree_check_create_page.load_page @student
      @degree_check_create_page.select_template template
    end

    it 'can be canceled' do
      @degree_check_create_page.click_cancel_degree
      @student_page.toggle_personal_details_element.when_visible Utils.short_wait
    end

    it 'can be created' do
      @degree_check_create_page.load_page @student
      @degree_check_create_page.create_new_degree_check(@degree_check)
    end

    template.unit_reqts&.each do |u_req|
      it "shows units requirement #{u_req.name} name" do
        @degree_check_page.wait_until(1, "Expected #{u_req.name}, got #{@degree_check_page.visible_unit_req_name u_req}") do
          @degree_check_page.visible_unit_req_name(u_req) == u_req.name
        end
      end

      it "shows units requirement #{u_req.name} unit count #{u_req.unit_count}" do
        @degree_check_page.wait_until(1, "Expected #{u_req.unit_count}, got #{@degree_check_page.visible_unit_req_num u_req}") do
          @degree_check_page.visible_unit_req_num(u_req) == u_req.unit_count
        end
      end
    end

    template.categories&.each do |cat|
      it "shows category #{cat.id} name #{cat.name}" do
        @degree_check_page.wait_until(1, "Expected #{cat.name}, got #{@degree_check_page.visible_cat_name cat}") do
          @degree_check_page.visible_cat_name(cat) == cat.name
        end
      end

      it "shows category #{cat.name} description #{cat.desc}" do
        if cat.desc && !cat.desc.empty?
          @degree_check_page.wait_until(1, "Expected #{cat.desc}, got #{@degree_check_page.visible_cat_desc cat}") do
            "#{@degree_check_page.visible_cat_desc(cat)}" == "#{cat.desc}"
          end
        end
      end

      cat.sub_categories&.each do |sub_cat|
        it "shows subcategory #{sub_cat.name} name" do
          @degree_check_page.wait_until(1, "Expected #{sub_cat.name}, got #{@degree_check_page.visible_cat_name(sub_cat)}") do
            @degree_check_page.visible_cat_name(sub_cat) == sub_cat.name
          end
        end

        it "shows subcategory #{sub_cat.name} description #{sub_cat.desc}" do
          @degree_check_page.wait_until(1, "Expected #{sub_cat.desc}, got #{@degree_check_page.visible_cat_desc(sub_cat)}") do
            @degree_check_page.visible_cat_desc(sub_cat) == sub_cat.desc
          end
        end

        sub_cat.course_reqs&.each do |req_course|
          it "shows subcategory #{sub_cat.name} course #{req_course.name} name" do
            @degree_check_page.wait_until(1, "Expected #{req_course.name}, got #{@degree_check_page.visible_course_req_name req_course}") do
              @degree_check_page.visible_course_req_name(req_course) == req_course.name
            end
          end

          it "shows subcategory #{sub_cat.name} course #{req_course.name} units #{req_course.units}" do
            @degree_check_page.wait_until(1, "Expected #{req_course.units}, got #{@degree_check_page.visible_course_req_units req_course}") do
              req_course.units ? (@degree_check_page.visible_course_req_units(req_course) == req_course.units) : (@degree_check_page.visible_course_req_units(req_course) == '—')
            end
          end
        end
      end

      cat.course_reqs&.each do |course|
        it "shows category #{cat.name} course #{course.name} name" do
          @degree_check_page.wait_until(1, "Expected #{course.name}, got #{@degree_check_page.visible_course_req_name course}") do
            @degree_check_page.visible_course_req_name(course) == course.name
          end
        end

        it "shows category #{cat.name} course #{course.name} units #{course.units}" do
          @degree_check_page.wait_until(1, "Expected #{course.units}, got #{@degree_check_page.visible_course_req_units course}") do
            course.units ? (@degree_check_page.visible_course_req_units(course) == course.units) : (@degree_check_page.visible_course_req_units(course) == '—')
          end
        end
      end
    end
  end

  context 'note section' do

    before(:all) { @note_str = "Teena wuz here #{test.id} " * 10 }

    it('offers a create button for a note') { @degree_check_page.click_create_or_edit_note }
    it('allows the user to cancel a note') { @degree_check_page.click_cancel_note }
    it('allows the user to save a note') { @degree_check_page.create_or_edit_note @note_str }
    it('shows the note content') { expect(@degree_check_page.visible_note_body).to eql(@note_str.strip) }
    it 'shows the note creating advisor' do
      @degree_check_page.wait_until(2) do
        @degree_check_page.note_update_advisor? && !@degree_check_page.note_update_advisor.empty?
      end
    end
    it('shows the note creation date') { expect(@degree_check_page.note_update_date).to include('today') }
    it('offers an edit button for a note') { @degree_check_page.click_create_or_edit_note }
    it('allows the user to cancel a note edit') { @degree_check_page.click_cancel_note }
    it('allows the user to save a note edit') { @degree_check_page.create_or_edit_note("EDITED - #{@note_str}") }
    it('shows the edited note content') { expect(@degree_check_page.visible_note_body).to eql("EDITED - #{@note_str}".strip) }
    it('shows the note edit advisor') { expect(@degree_check_page.note_update_advisor).not_to be_empty }
    it('shows the note edit date') { expect(@degree_check_page.note_update_date).to include('today') }
  end

  context 'unassigned' do

    context 'courses' do

      it 'show the right courses' do
        expect(@degree_check_page.unassigned_course_ccns).to eql(@unassigned_courses.map { |c| "#{c.term_id}-#{c.ccn}" })
      end

      it 'show the right course name on each row' do
        @unassigned_courses.each do |course|
          logger.debug "Checking for #{course.name}"
          expect(@degree_check_page.unassigned_course_code(course)).to eql(course.name)
        end
      end

      it 'show the right course units on each row' do
        @unassigned_courses.each do |course|
          logger.debug "Checking for #{course.units}"
          expect(@degree_check_page.unassigned_course_units(course)).to eql(course.units)
        end
      end

      it 'show the right course grade on each row' do
        @unassigned_courses.each do |course|
          logger.debug "Checking for #{course.grade}"
          expect(@degree_check_page.unassigned_course_grade(course)).to eql(course.grade)
        end
      end

      it 'show the right course term on each row' do
        @unassigned_courses.each do |course|
          term = Utils.sis_code_to_term_name(course.term_id)
          logger.debug "Checking for #{term}"
          expect(@degree_check_page.unassigned_course_term(course)).to eql(term)
        end
      end
    end

    context 'course' do

      before(:all) { @completed_course = @unassigned_courses[0] }

      context 'edit' do

        it 'can be canceled' do
          @degree_check_page.click_edit_unassigned_course @completed_course
          @degree_check_page.click_cancel_course_edit
        end

        it 'allows a user to add a note' do
          @completed_course.note = "Teena wuz here #{test.id}" * 10
          @degree_check_page.edit_unassigned_course @completed_course
          expect(@degree_check_page.unassigned_course_note @completed_course).to eql(@completed_course.note)
        end

        it 'allows a user to edit a note' do
          @completed_course.note = "EDITED - #{@completed_course.note}"
          @degree_check_page.edit_unassigned_course @completed_course
          expect(@degree_check_page.unassigned_course_note @completed_course).to eql(@completed_course.note)
        end

        it 'allows a user to remove a note' do
          @completed_course.note = ''
          @degree_check_page.edit_unassigned_course @completed_course
          expect(@degree_check_page.unassigned_course_note @completed_course).to eql('—')
        end

        it 'allows a user to change units to another integer' do
          @completed_course.units = '6'
          @degree_check_page.edit_unassigned_course @completed_course
          expect(@degree_check_page.unassigned_course_units @completed_course).to eql(@completed_course.units)
        end

        # TODO it 'does not allow a user to change units to a non-integer'

        it 'does not allow a user to remove all units' do
          @degree_check_page.click_edit_unassigned_course @completed_course
          @degree_check_page.enter_course_units ''
          expect(@degree_check_page.course_update_button_element.enabled?).to be false
        end
      end

      context 'when assigned to a course requirement' do

        it 'updates the requirement row with the course name' do
          @degree_check_page.click_cancel_course_edit
          @degree_check_page.assign_completed_course(@completed_course, @course_req_1)
        end

        it 'updates the requirement row with the course units' do
          expect(@degree_check_page.visible_assigned_course_units(@completed_course)).to eql(@completed_course.units)
        end

        it 'removes the course from the unassigned courses list' do
          expect(@degree_check_page.unassigned_course_ccns).not_to include("#{@completed_course.term_id}-#{@completed_course.ccn}")
        end

        it 'prevents another course being assigned to the same requirement' do
          @degree_check_page.click_unassigned_course_select @unassigned_courses.last
          expect(@degree_check_page.unassigned_course_req_option(@unassigned_courses.last, @course_req_1).attribute('aria-disabled')).to eql('true')
        end

        # TODO it 'updates the requirement row with the course grade'
        # TODO it 'updates the requirement row with the course note'
        # TODO it 'shows the requirement row\'s pre-existing unit fulfillment(s)'

        context 'and edited' do

          it 'can be canceled' do
            @degree_check_page.click_edit_cat @completed_course.req_course
            @degree_check_page.click_cancel_course_edit
          end

          it 'allows a user to add a note' do
            @completed_course.note = "Nota bene #{test.id}"
            @degree_check_page.edit_assigned_course @completed_course
            expect(@degree_check_page.visible_assigned_course_note @completed_course).to eql(@completed_course.note)
          end

          it 'allows a user to edit a note' do
            @completed_course.note = "EDITED - #{@completed_course.note}"
            @degree_check_page.edit_assigned_course @completed_course
            expect(@degree_check_page.visible_assigned_course_note @completed_course).to eql(@completed_course.note)
          end

          it 'allows a user to remove a note' do
            @completed_course.note = ''
            @degree_check_page.edit_assigned_course @completed_course
            expect(@degree_check_page.visible_assigned_course_note(@completed_course).to_s).to eql(@completed_course.note)
          end

          it 'allows a user to change units to another integer' do
            @completed_course.units = '1'
            @degree_check_page.edit_assigned_course @completed_course
            expect(@degree_check_page.visible_assigned_course_units @completed_course).to eql(@completed_course.units)
          end

          # TODO it 'does not allow a user to change units to a non-integer'

          it 'does not allow a user to remove all units' do
            @degree_check_page.click_edit_assigned_course @completed_course
            @degree_check_page.enter_course_units ''
            expect(@degree_check_page.course_update_button_element.enabled?).to be false
          end
          # TODO it 'shows an indicator if the user has edited the course units'

          # TODO it 'allows the user to edit the course unit fulfillment(s)'
          # TODO it 'shows an indicator if the user has edited the course unit fulfillment(s)'
        end
      end

      context 'when unassigned from a course requirement' do

        it 'reverts the requirement row course name' do
          @degree_check_page.click_cancel_course_edit
          @degree_check_page.unassign_course(@completed_course, @course_req_1)
        end

        it 'reverts the requirement row course units' do
          if @course_req_1.units
            (@degree_template_page.visible_course_req_units(@course_req_1) == @course_req_1.units)
          else
            (@degree_template_page.visible_course_req_units(@course_req_1) == '—')
          end
        end

        # TODO it 'removes the requirement row course grade'
        # TODO it 'removes the requirement row course note'
        # TODO it 'reverts the requirement row course units'
        # TODO it 'reverts the requirement row unit fufillment(s)'

        it 'restores the course to the unassigned courses list' do
          expect(@degree_check_page.unassigned_course_row_el(@completed_course).exists?).to be true
        end
      end

      context 'when reassigned from one course requirement to another' do

        before(:all) { @degree_check_page.assign_completed_course(@completed_course, @course_req_1) }

        it 'updates the requirement row with the course name' do
          @degree_check_page.reassign_course(@completed_course, @course_req_1, @course_req_2)
        end

        it 'updates the requirement row with the course units' do
          expect(@degree_check_page.visible_assigned_course_units(@completed_course)).to eql(@completed_course.units)
        end

        it 'removes the course from the unassigned courses list' do
          expect(@degree_check_page.unassigned_course_ccns).not_to include("#{@completed_course.term_id}-#{@completed_course.ccn}")
        end

        it 'prevents another course being assigned to the same requirement' do
          @degree_check_page.click_unassigned_course_select @unassigned_courses.last
          expect(@degree_check_page.unassigned_course_req_option(@unassigned_courses.last, @course_req_2).attribute('aria-disabled')).to eql('true')
        end
      end

      context 'when assigned to a category' do

        before(:all) do
          @completed_course_top_cat = @unassigned_courses[1]
          @completed_course_sub_cat = @unassigned_courses[2]

          @completed_course_sub_cat.note = "Teena wuz here too #{test.id}"
          @degree_check_page.edit_unassigned_course @completed_course_sub_cat
        end

        it 'cannot be added to a category with a subcategory' do
          @degree_check_page.click_unassigned_course_select @completed_course_sub_cat
          el = @degree_check_page.unassigned_course_option_els(@completed_course_sub_cat).find { |el| el.text.strip == @cat_with_subs.name }
          expect(el.attribute('aria-disabled')).to eql('true')
        end

        it 'can be added to a category without a subcategory' do
          @degree_check_page.assign_completed_course(@completed_course_top_cat, @cat_no_subs_no_courses)
        end

        it 'can be added to a subcategory' do
          @degree_check_page.assign_completed_course(@completed_course_sub_cat, @sub_cat_with_courses)
        end

        # TODO it 'creates a requirement row with the course name'
        # TODO it 'shows the course units on the requirement row'
        # TODO it 'shows the course grade on the requirement row'
        # TODO it 'shows the course note on the requirement row'

        it 'removes the course from the unassigned courses list' do
          ccn_top_cat = "#{@completed_course_top_cat.term_id}-#{@completed_course_top_cat.ccn}"
          ccn_sub_cat = "#{@completed_course_sub_cat.term_id}-#{@completed_course_sub_cat.ccn}"
          expect(@degree_check_page.unassigned_course_ccns & [ccn_top_cat, ccn_sub_cat]).to be_empty
        end
      end

      context 'when unassigned from a category' do
        it 'deletes the row from the category'
        it 'restores the course to the unassigned courses list'
      end
    end
  end
end
