require_relative '../../util/spec_helper'

include Logging

test = BOACTestConfig.new
test.degree_progress
template = test.degree_templates.find { |t| t.name.include? BOACUtils.degree_major.first }

describe 'A BOA degree check course' do

  before(:all) do
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

    @homepage.dev_auth test.advisor
    @homepage.click_degree_checks_link
    @degree_templates_mgmt_page.create_new_degree template
    @degree_template_page.complete_template template

    @student = ENV['UIDS'] ? (test.students.find { |s| s.uid == ENV['UIDS'] }) : test.cohort_members.shuffle.first
    @degree_check = DegreeProgressChecklist.new(template, @student)
    @student_api_page.get_data(@driver, @student)
    @unassigned_courses = @student_api_page.degree_progress_courses
    @completed_course = @unassigned_courses.first

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

    @degree_check_create_page.load_page @student
    @degree_check_create_page.create_new_degree_check(@degree_check)
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when unassigned' do

    it 'appears in the unassigned section' do
      expect(@degree_check_page.unassigned_course_ccns).to eql(@unassigned_courses.map { |c| "#{c.term_id}-#{c.ccn}" })
    end

    it 'shows the right course name' do
      @unassigned_courses.each do |course|
        logger.debug "Checking for #{course.name}"
        expect(@degree_check_page.unassigned_course_code(course)).to eql(course.name)
      end
    end

    it 'show the right course units' do
      @unassigned_courses.each do |course|
        logger.debug "Checking for #{course.units}"
        expect(@degree_check_page.unassigned_course_units(course)).to eql(course.units)
      end
    end

    it 'show the right course grade' do
      @unassigned_courses.each do |course|
        logger.debug "Checking for #{course.grade}"
        expect(@degree_check_page.unassigned_course_grade(course)).to eql(course.grade)
      end
    end

    it 'show the right course term' do
      @unassigned_courses.each do |course|
        term = Utils.sis_code_to_term_name(course.term_id)
        logger.debug "Checking for #{term}"
        expect(@degree_check_page.unassigned_course_term(course)).to eql(term)
      end
    end

    context 'and edited' do

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

      it 'does not allow a user to change units to a non-integer number' do
        @degree_check_page.click_edit_unassigned_course @completed_course
        @degree_check_page.enter_course_units '9.5'
        @degree_check_page.col_req_course_units_error_msg_element.when_visible 1
        expect(@degree_check_page.course_update_button_element.enabled?).to be false
      end

      it 'does not allow a user to change units to a integer greater than a single digit' do
        @degree_check_page.enter_course_units '10'
        @degree_check_page.col_req_course_units_error_msg_element.when_visible 1
        expect(@degree_check_page.course_update_button_element.enabled?).to be false
      end

      it 'does not allow a user to remove all units' do
        @degree_check_page.enter_course_units ''
        expect(@degree_check_page.course_update_button_element.enabled?).to be false
      end
    end
  end

  context 'when assigned to a course requirement' do

    before(:all) do
      @degree_check_page.click_cancel_course_edit
      @completed_course.note = "Teena wuz here again #{test.id}" * 10
      @degree_check_page.edit_unassigned_course @completed_course
    end

    it 'updates the requirement row with the course name' do
      @degree_check_page.assign_completed_course(@completed_course, @course_req_1)
    end

    it 'updates the requirement row with the course units' do
      expect(@degree_check_page.visible_assigned_course_units(@completed_course)).to eql(@completed_course.units)
    end

    it 'updates the requirement row with the course grade' do
      expect(@degree_check_page.visible_assigned_course_grade(@completed_course)).to eql(@completed_course.grade)
    end

    it 'updates the requirement row with the course note' do
      expect(@degree_check_page.visible_assigned_course_note(@completed_course)).to eql(@completed_course.note)
    end

    it 'removes the course from the unassigned courses list' do
      expect(@degree_check_page.unassigned_course_ccns).not_to include("#{@completed_course.term_id}-#{@completed_course.ccn}")
    end

    it 'prevents another course being assigned to the same requirement' do
      @degree_check_page.click_unassigned_course_select @unassigned_courses.last
      expect(@degree_check_page.unassigned_course_req_option(@unassigned_courses.last, @course_req_1).attribute('aria-disabled')).to eql('true')
    end

    context 'and edited' do

      it 'can be canceled' do
        @degree_check_page.click_edit_cat @completed_course.req_course
        @degree_check_page.click_cancel_course_edit
      end

      it 'allows a user to remove a note' do
        @completed_course.note = ''
        @degree_check_page.edit_assigned_course @completed_course
        expect(@degree_check_page.visible_assigned_course_note(@completed_course).to_s).to eql(@completed_course.note)
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

      it 'allows a user to change units to another integer' do
        @completed_course.units = '1'
        @degree_check_page.edit_assigned_course @completed_course
        expect(@degree_check_page.visible_assigned_course_units @completed_course).to eql(@completed_course.units)
      end

      # TODO it 'shows an indicator if the user has edited the course units'

      it 'does not allow a user to change units to a non-integer number' do
        @degree_check_page.click_edit_assigned_course @completed_course
        @degree_check_page.enter_course_units '9.5'
        @degree_check_page.col_req_course_units_error_msg_element.when_visible 1
        expect(@degree_check_page.course_update_button_element.enabled?).to be false
      end

      it 'does not allow a user to change units to a integer greater than a single digit' do
        @degree_check_page.enter_course_units '10'
        @degree_check_page.col_req_course_units_error_msg_element.when_visible 1
        expect(@degree_check_page.course_update_button_element.enabled?).to be false
      end

      it 'does not allow a user to remove all units' do
        @degree_check_page.enter_course_units ''
        expect(@degree_check_page.course_update_button_element.enabled?).to be false
      end
    end
  end

  context 'when unassigned from a course requirement' do

    it 'reverts the requirement row course name' do
      @degree_check_page.unassign_course(@completed_course, @course_req_1)
    end

    it 'reverts the requirement row course units' do
      expect(@degree_check_page.visible_course_req_units @course_req_1).to eql(@course_req_1.units || '—')
    end

    it 'removes the requirement row course grade' do
      expect(@degree_check_page.visible_course_req_grade @course_req_1).to be_empty
    end

    it 'removes the requirement row course note' do
      expect(@degree_check_page.visible_course_req_note @course_req_1).to be_empty
    end

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

    it 'creates a new course row when the category has no subcategory and no course' do
        @degree_check_page.assign_completed_course(@completed_course_top_cat, @cat_no_subs_no_courses)
        expect(@degree_check_page.visible_assigned_course_units @completed_course_top_cat).to eql(@completed_course_top_cat.units)
        expect(@degree_check_page.visible_assigned_course_grade @completed_course_top_cat).to eql(@completed_course_top_cat.grade)
        # TODO it 'shows the course note on the requirement row'
        expect(@degree_check_page.unassigned_course_ccns).not_to include("#{@completed_course_top_cat.term_id}-#{@completed_course_top_cat.ccn}")
    end

    it 'creates a new course row when the category has no subcategory but does have a course'

    it 'cannot be added to a category with a subcategory' do
      @degree_check_page.click_unassigned_course_select @completed_course_sub_cat
      el = @degree_check_page.unassigned_course_option_els(@completed_course_sub_cat).find { |el| el.text.strip == @cat_with_subs.name }
      expect(el.attribute('aria-disabled')).to eql('true')
    end

    it 'creates a new course row when the category is a subcategory without courses' do
        @degree_check_page.assign_completed_course(@completed_course_sub_cat, @sub_cat_with_courses)
        expect(@degree_check_page.visible_assigned_course_units @completed_course_sub_cat).to eql(@completed_course_sub_cat.units)
        expect(@degree_check_page.visible_assigned_course_grade @completed_course_sub_cat).to eql(@completed_course_sub_cat.grade)
        # TODO it 'shows the course note on the requirement row'
        expect(@degree_check_page.unassigned_course_ccns).not_to include("#{@completed_course_sub_cat.term_id}-#{@completed_course_sub_cat.ccn}")
    end

    it 'creates a new course row when the category is a subcategory with courses'
  end

  context 'when reassigned' do
    it 'can be moved from a category to a subcategory'
    it 'can be moved from a subcategory to category'
    it 'can be moved from a category to a course requirement'
    it 'can be moved from a course requirement to a subcategory'
    it 'can be moved from a subcategory to a course requirement'
    it 'can be moved from a course requirement to a category'
  end

  context 'when unassigned from a category' do
    it 'deletes the row from the category'
    it 'restores the course to the unassigned courses list'
  end

  context 'when copied' do

    it 'must already be assigned elsewhere'

    context 'to a category' do
      before(:all) # edit the units and note
      it 'creates a row with the course name'
      it 'creates a row with the unedited course units'
      it 'creates a row with the course grade'
      it 'creates a row with the an unedited course note'
      it 'displays an icon identifying itself as a copy'
      it 'offers a delete button'
      it 'cannot be reassigned'
    end

    context 'to a subcategory' do
      before(:all) # edit the units and note
      it 'creates a row with the course name'
      it 'creates a row with the unedited course units'
      it 'creates a row with the course grade'
      it 'creates a row with the an unedited course note'
      it 'displays an icon identifying itself as a copy'
      it 'offers a delete button'
      it 'cannot be reassigned'
    end

    context 'to a course requirement' do
      before(:all) # edit the units and note
      it 'creates a row with the course name'
      it 'creates a row with the unedited course units'
      it 'creates a row with the course grade'
      it 'creates a row with the an unedited course note'
      it 'displays an icon identifying itself as a copy'
      it 'offers a delete button'
      it 'cannot be reassigned'
    end

    context 'and edited' do
      it 'can be canceled'
      it 'allows a user to remove a note'
      it 'allows a user to add a note'
      it 'allows a user to edit a note'
      it 'allows a user to change units to another integer'
      it 'shows an indicator if the user has edited the course units'
      it 'does not allow a user to change units to a non-integer number'
      it 'does not allow a user to change units to a integer greater than a single digit'
      it 'does not allow a user to remove all units'
      it 'does not affect the original course row'
    end

    context 'and deleted' do
      it 'can be canceled'
      it 'can be deleted'
      it 'does not affect the original course row'
    end

    context 'and its original is unassigned' do
      it 'is deleted automatically'
    end
  end
end
