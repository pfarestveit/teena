require_relative '../../util/spec_helper'

include Logging

test = BOACTestConfig.new
test.degree_progress
template = test.degree_templates.find { |t| t.name.include? 'Unit Fulfillment' }
logger.debug "Template: #{template.inspect}"

describe 'A BOA degree check' do

  before(:all) do
    @student = ENV['UIDS'] ? (test.students.find { |s| s.uid == ENV['UIDS'] }) : test.cohort_members.shuffle.first
    @degree_check = DegreeProgressChecklist.new(template, @student)

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

    # Find student course data
    @student_api_page.get_data(@driver, @student)
    @unassigned_courses = @student_api_page.degree_progress_courses
    logger.info "Completed courses: #{@unassigned_courses[0..4].map &:name}"

    # Create student degree check
    @degree_check_create_page.load_page @student
    @degree_check_create_page.create_new_degree_check(@degree_check)

    @course = @unassigned_courses[0]

    @cat_0 = @degree_check.categories[0]

    @cat_1 = @degree_check.categories[1]
    @sub_cat_1 = @cat_1.sub_categories[0]
    @req_course_1 = @sub_cat_1.course_reqs[0]

    @cat_2 = @degree_check.categories[2]

    @cat_3 = @degree_check.categories[3]
    @sub_cat_3 = @cat_3.sub_categories[0]
    @req_course_3 = @sub_cat_3.course_reqs[0]
  end

  describe 'unassigned course' do

    it 'cannot have unit requirements edited' do
      @degree_check_page.click_edit_unassigned_course @unassigned_courses[0]
      @degree_check_page.course_note_input_element.when_present 1
      expect(@degree_check_page.col_req_course_units_req_select?).to be false
    end
  end

  describe 'course' do

    before(:all) do
      @degree_check_page.click_cancel_course_edit if @degree_check_page.course_cancel_button?
    end

    context 'that is assigned to a category with unit fulfillment' do

      before(:all) { @degree_check_page.assign_completed_course(@course, @cat_0, { drag: true }) }
      before(:each) { @degree_check_page.click_cancel_course_edit if @degree_check_page.course_cancel_button? }

      it 'inherits the category\'s unit fulfillment' do
        @degree_check_page.verify_assigned_course_fulfillment @course
      end

      it 'shows no indicator that its unit fulfillment differs from the category\'s' do
        expect(@degree_check_page.visible_assigned_course_fulfill_flag? @course).to be false
      end

      it 'updates the unit fulfillment totals' do
        # TODO
      end

      it 'can have unit fulfillment edited and totals updated' do
        @course.units_reqts = [@degree_check.unit_reqts[2]]
        @degree_check_page.edit_assigned_course @course
        # TODO - totals updated
      end

      it 'shows an indicator if its unit fulfillment has been edited' do
        expect(@degree_check_page.visible_assigned_course_fulfill_flag? @course).to be true
      end

      it 'can have unit fulfillment added and totals updated' do
        @course.units_reqts = @degree_check.unit_reqts
        @degree_check_page.edit_assigned_course @course
        # TODO - totals updated
      end

      it 'shows an indicator if its unit fulfillment has been added' do
        expect(@degree_check_page.visible_assigned_course_fulfill_flag? @course).to be true
      end

      it 'can have unit fulfillment removed and totals updated' do
        @course.units.reqts = []
        @degree_check_page.edit_assigned_course @course
        # TODO - totals updated
      end

      it 'shows an indicator if its unit fulfillment has been removed' do
        expect(@degree_check_page.visible_assigned_course_fulfill_flag? @course).to be true
      end
    end

    context 'that is unassigned from a category' do

      before(:all) { @degree_check_page.unassign_course(@course, @cat_0, { drag: true }) }
      before(:each) { @degree_check_page.click_cancel_course_edit if @degree_check_page.course_cancel_button? }

      it 'updates the unit fulfillment totals' do
        # TODO
      end
    end

    context 'that is assigned to a subcategory that inherits unit fulfillment from a category' do

      before(:all) { @degree_check_page.assign_completed_course(@course, @sub_cat_1, { drag: true }) }
      before(:each) { @degree_check_page.click_cancel_course_edit if @degree_check_page.course_cancel_button? }

      it 'shows the subcategory\'s parent\'s unit fulfillment rather than its own' do
        @degree_check_page.verify_assigned_course_fulfillment @course
      end

      it 'shows no indicator that its unit fulfillment differs from the subcategory\'s' do
        expect(@degree_check_page.visible_assigned_course_fulfill_flag? @course).to be false
      end

      it 'updates the unit fulfillment totals' do
        # TODO
      end

      it 'can have unit fulfillment removed and totals updated' do
        @course.units_reqts = []
        @degree_check_page.edit_assigned_course @course
        # TODO - totals updated
      end

      it 'shows an indicator if its unit fulfillment has been removed' do
        expect(@degree_check_page.visible_assigned_course_fulfill_flag? @course).to be true
      end

      it 'can have unit fulfillment added and totals updated' do
        @course.units_reqts = @degree_check.unit_reqts
        @degree_check_page.edit_assigned_course @course
        # TODO - totals updated
      end

      it 'shows an indicator if its unit fulfillment has been added' do
        expect(@degree_check_page.visible_assigned_course_fulfill_flag? @course).to be true
      end

      it 'can have unit fulfillment edited and totals updated' do
        @course.units_reqts = [@degree_check.unit_reqts[2]]
        @degree_check_page.edit_assigned_course @course
        # TODO - totals updated
      end

      it 'shows an indicator if its unit fulfillment has been edited' do
        expect(@degree_check_page.visible_assigned_course_fulfill_flag? @course).to be true
      end
    end

    context 'that is reassigned to a course requirement that inherits unit fulfillment' do

      before(:all) { @degree_check_page.assign_completed_course(@course, @req_course_1, { drag: true }) }
      before(:each) { @degree_check_page.click_cancel_course_edit if @degree_check_page.course_cancel_button? }

      it 'shows the course requirements\'s unit fulfillment rather than its own' do
        @degree_check_page.verify_assigned_course_fulfillment @course
      end

      it 'shows no indicator that its unit fulfillment differs from the course requirement\'s' do
        expect(@degree_check_page.visible_assigned_course_fulfill_flag? @course).to be false
      end

      it 'updates the unit fulfillment totals' do
        # TODO
      end

      it 'can have unit fulfillment edited and totals updated' do
        @course.units_reqts = [@degree_check.unit_reqts[0]]
        @degree_check_page.edit_assigned_course @course
        # TODO - totals updated
      end

      it 'shows an indicator if its unit fulfillment has been edited' do
        expect(@degree_check_page.visible_assigned_course_fulfill_flag? @course).to be true
      end

      it 'can have unit fulfillment removed and totals updated' do
        @course.units.reqts = []
        @degree_check_page.edit_assigned_course @course
        # TODO - totals updated
      end

      it 'shows an indicator if its unit fulfillment has been removed' do
        expect(@degree_check_page.visible_assigned_course_fulfill_flag? @course).to be true
      end

      it 'can have unit fulfillment added and totals updated' do
        @course.units_reqts = @degree_check.unit_reqts
        @degree_check_page.edit_assigned_course @course
        # TODO - totals updated
      end

      it 'shows an indicator if its unit fulfillment has been added' do
        expect(@degree_check_page.visible_assigned_course_fulfill_flag? @course).to be true
      end
    end
  end

  describe 'course copied from a course with unit fulfillment' do

    context 'that is assigned to a category without unit fulfillment' do

      before(:all) do
        @degree_check_page.copy_course(@course, @cat_2)
        @course_copy = @course.course_copies[0]
      end

      before(:each) { @degree_check_page.click_cancel_course_edit if @degree_check_page.course_cancel_button? }

      it 'shows the category\'s unit fulfillment' do
        @degree_check_page.verify_assigned_course_fulfillment @course_copy
      end

      it 'shows no indicator that its unit fulfillment differs from the category\'s' do
        expect(@degree_check_page.visible_assigned_course_fulfill_flag? @course_copy).to be false
      end

      it 'updates the unit fulfillment totals' do
        # TODO
      end

      it 'can have unit fulfillment edited and totals updated' do
        @course_copy.units_reqts = [@degree_check.unit_reqts[2]]
        @degree_check_page.edit_assigned_course @course_copy
        # TODO - totals updated
      end

      it 'shows an indicator if its unit fulfillment has been edited' do
        expect(@degree_check_page.visible_assigned_course_fulfill_flag? @course).to be true
      end

      it 'can have unit fulfillment added and totals updated' do
        @course_copy.units_reqts = @degree_check.unit_reqts
        @degree_check_page.edit_assigned_course @course_copy
        # TODO - totals updated
      end

      it 'shows an indicator if its unit fulfillment has been added' do
        expect(@degree_check_page.visible_assigned_course_fulfill_flag? @course_copy).to be true
      end

      it 'can have unit fulfillment removed and totals updated' do
        @course_copy.units.reqts = []
        @degree_check_page.edit_assigned_course @course_copy
        # TODO - totals updated
      end

      it 'shows no indicator that its unit fulfillment differs from the category\'s' do
        expect(@degree_check_page.visible_assigned_course_fulfill_flag? @course_copy).to be false
      end
    end

    context 'that is assigned to a subcategory with unit fulfillment that does not inherit unit fulfillment from a category' do

      before(:all) do
        @degree_check_page.copy_course(@course, @sub_cat_3)
        @course_copy = @course.course_copies[1]
      end

      it 'shows the subcategory\'s unit fulfillment' do
        @degree_check_page.verify_assigned_course_fulfillment @course_copy
      end

      it 'shows no indicator that its unit fulfillment differs from the subcategory\'s' do
        expect(@degree_check_page.visible_assigned_course_fulfill_flag? @course_copy).to be false
      end

      it 'updates the unit fulfillment totals' do
        # TODO
      end

      it 'can have unit fulfillment edited and totals updated' do
        @course_copy.units_reqts = [@degree_check.unit_reqts[0]]
        @degree_check_page.edit_assigned_course @course_copy
        # TODO - totals updated
      end

      it 'shows an indicator if its unit fulfillment has been edited' do
        expect(@degree_check_page.visible_assigned_course_fulfill_flag? @course_copy).to be true
      end

      it 'can have unit fulfillment removed and totals updated' do
        @course_copy.units.reqts = []
        @degree_check_page.edit_assigned_course @course_copy
        # TODO - totals updated
      end

      it 'shows an indicator if its unit fulfillment has been removed' do
        expect(@degree_check_page.visible_assigned_course_fulfill_flag? @course_copy).to be true
      end

      it 'can have unit fulfillment added and totals updated' do
        @course_copy.units_reqts = @degree_check.unit_reqts
        @degree_check_page.edit_assigned_course @course_copy
        # TODO - totals updated
      end

      it 'shows an indicator if its unit fulfillment has been added' do
        expect(@degree_check_page.visible_assigned_course_fulfill_flag? @course_copy).to be true
      end

      context 'and deleted from the subcategory' do

        before(:all) { @degree_check_page.delete_assigned_course @course_copy }

        it 'updates the unit fulfillment totals' do
          # TODO
        end
      end
    end
  end
end
