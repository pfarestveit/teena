require_relative '../../util/spec_helper'

include Logging

test = BOACTestConfig.new
test.degree_progress
template = test.degree_templates.find { |t| t.name.include? 'Course Workflows' }

batch_students = test.students.last BOACUtils.config['notes_batch_students_count']
cohorts = []
curated_groups = []
curated_group_members = test.students.shuffle.last BOACUtils.config['notes_batch_curated_group_count']
curated_group_1 = CuratedGroup.new name: "Group 1 - #{test.id}"
curated_group_2 = CuratedGroup.new name: "Group 2 - #{test.id}"
batch_degree_check_1 = DegreeProgressBatch.new template

describe 'A BOA degree' do

  before(:all) do
    @driver = Utils.launch_browser
    @homepage = BOACHomePage.new @driver
    @cohort_page = BOACFilteredCohortPage.new(@driver, test.advisor)
    @curated_group_page = BOACGroupPage.new @driver

    @degree_templates_mgmt_page = BOACDegreeTemplateMgmtPage.new @driver
    @degree_template_page = BOACDegreeTemplatePage.new @driver
    @degree_batch_page = BOACDegreeCheckBatchPage.new @driver

    @degree_check_create_page = BOACDegreeCheckCreatePage.new @driver
    @degree_check_page = BOACDegreeCheckPage.new @driver
    @degree_check_history_page = BOACDegreeCheckHistoryPage.new @driver

    @pax_manifest = BOACPaxManifestPage.new @driver
    @search_results_page = BOACSearchResultsPage.new @driver
    @student_page = BOACStudentPage.new @driver
    @student_api_page = BOACApiStudentPage.new @driver

    logger.warn "Read/write advisor is UID #{test.advisor.uid}, and read-only advisor is UID #{test.read_only_advisor.uid}"

    unless test.advisor.degree_progress_perm == DegreeProgressPerm::WRITE && test.read_only_advisor.degree_progress_perm == DegreeProgressPerm::READ
      @homepage.dev_auth
      @pax_manifest.load_page
      @pax_manifest.set_deg_prog_perm(test.advisor, BOACDepartments::COE, DegreeProgressPerm::WRITE)
      @pax_manifest.set_deg_prog_perm(test.read_only_advisor, BOACDepartments::COE, DegreeProgressPerm::READ)
      @pax_manifest.log_out
    end

    @student = ENV['UIDS'] ? (test.students.find { |s| s.uid == ENV['UIDS'] }) : batch_students.shuffle.first
    @degree_check = DegreeProgressChecklist.new(template, @student)
    @note_str = "Teena wuz here #{test.id} " * 10

    # Find student course data
    @homepage.dev_auth test.advisor
    @student_api_page.get_data(@driver, @student)
    @unassigned_courses = @student_api_page.degree_progress_courses @degree_check
    @completed_course_0 = @unassigned_courses[0]

    @homepage.load_page
    @homepage.click_degree_checks_link
    @degree_templates_mgmt_page.create_new_degree template
    @degree_template_page.complete_template template

    @student_page.load_page @student
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'check' do

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

          sub_cat.course_reqs.each do |req_course|
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

        cat.course_reqs.each do |course|
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

    context 'when a course requirement is edited' do

      before(:all) { @reqt = template.categories.find {|cat| cat.course_reqs.any? }.course_reqs.first }

      it 'allows a big dot to be added' do
        @degree_check_page.click_edit_course_req @reqt
        @degree_check_page.toggle_course_req_dot
        @degree_check_page.click_save_req_edit
        @degree_check_page.is_recommended(@reqt).when_present Utils.short_wait
      end

      it 'allows a big dot to be removed' do
        @degree_check_page.click_edit_course_req @reqt
        @degree_check_page.toggle_course_req_dot
        @degree_check_page.click_save_req_edit
        @degree_check_page.is_recommended(@reqt).when_not_present Utils.short_wait
      end

      it 'allows units (range) to be added' do
        @degree_check_page.click_edit_course_req @reqt
        @degree_check_page.enter_col_req_units '4-5'
        @degree_check_page.click_save_req_edit
        expect(@degree_check_page.visible_course_req_units @reqt).to eql('4-5')
      end

      it 'allows units to be removed' do
        @degree_check_page.click_edit_course_req @reqt
        @degree_check_page.enter_col_req_units ''
        @degree_check_page.click_save_req_edit
        expect(@degree_check_page.visible_course_req_units @reqt).to eql('—')
      end

      it 'allows a grade to be added' do
        @degree_check_page.click_edit_course_req @reqt
        @degree_check_page.enter_reqt_grade '>B'
        @degree_check_page.click_save_req_edit
        expect(@degree_check_page.visible_course_req_grade @reqt).to eql('>B')
      end

      it 'allows a grade to be removed' do
        @degree_check_page.click_edit_course_req @reqt
        @degree_check_page.enter_reqt_grade ''
        @degree_check_page.click_save_req_edit
        expect(@degree_check_page.visible_course_req_grade(@reqt).to_s).to be_empty
      end

      it 'allows a note to be added' do
        @degree_check_page.click_edit_course_req @reqt
        @degree_check_page.enter_recommended_note 'affen schlafen in lederhosen'
        @degree_check_page.click_save_req_edit
        expect(@degree_check_page.visible_course_req_note(@reqt)).to eql('affen schlafen in lederhosen')
      end

      it 'allows a note to be removed' do
        @degree_check_page.click_edit_course_req @reqt
        @degree_check_page.enter_recommended_note ''
        @degree_check_page.click_save_req_edit
        expect(@degree_check_page.visible_course_req_note(@reqt).to_s).to be_empty
      end

      it 'allows a color to be added' do
        @degree_check_page.click_edit_course_req @reqt
        @degree_check_page.select_color_option 'red'
        @degree_check_page.click_save_req_edit
      end

      context 'and a completed course is assigned' do

        before(:all) do
          @degree_check_page.click_edit_course_req @reqt
          @degree_check_page.toggle_course_req_dot
          @degree_check_page.enter_col_req_units '4-5'
          @degree_check_page.enter_reqt_grade '>B'
          @degree_check_page.enter_recommended_note 'affen schlafen in lederhosen'
          @degree_check_page.click_save_req_edit

          @degree_check_page.assign_completed_course(@completed_course_0, @reqt)
        end

        it 'overwrites a big dot' do
          @degree_check_page.is_recommended(@reqt).when_not_present Utils.short_wait
        end

        it 'overwrites requirement units' do
          expect(@degree_check_page.assigned_course_units @completed_course_0).to eql(@completed_course_0.units)
        end

        it 'overwrites a requirement grade' do
          expect(@degree_check_page.assigned_course_grade @completed_course_0).to eql(@completed_course_0.grade)
        end

        it 'overwrites a requirement note' do
          expect(@degree_check_page.assigned_course_note(@completed_course_0).to_s).to be_empty
        end
      end

      context 'and a completed course is unassigned' do

        before(:all) { @degree_check_page.unassign_course(@completed_course_0, @reqt) }

        it 'restores a big dot' do
          @degree_check_page.is_recommended(@reqt).when_present Utils.short_wait
        end

        it 'restores requirement units' do
          expect(@degree_check_page.visible_course_req_units @reqt).to eql('4-5')
        end

        it 'restores a requirement grade' do
          expect(@degree_check_page.visible_course_req_grade @reqt).to eql('>B')
        end

        it 'restores a requirement note' do
          expect(@degree_check_page.visible_course_req_note @reqt).to eql('affen schlafen in lederhosen')
        end
      end
    end

    context 'when its parent template has been edited' do

      before(:all) do
        new_req = DegreeUnitReqt.new name: "Another Unit Reqt #{test.id}",
                                     unit_count: '12'
        @degree_check_page.click_degree_checks_link
        @degree_templates_mgmt_page.click_degree_link template
        @degree_template_page.create_unit_req(new_req, template)
      end

      it 'shows an updated-template message on the degree check page' do
        @degree_check_page.load_page @degree_check
        @degree_check_page.template_updated_msg_element.when_present Utils.short_wait
      end

      it 'offers a link to the parent' do
        expect(@degree_check_page.external_link_valid?(@degree_check_page.template_link_element, template.name)).to be true
      end

      it 'shows an updated-template message on the degree history page' do
        @degree_check_page.click_view_degree_history
        @degree_check_history_page.template_updated_alert(@degree_check).when_present Utils.short_wait
      end
    end

    describe 'note section' do

      before(:all) { @degree_check_page.load_page @degree_check }

      it('offers a create button for a note') { @degree_check_page.click_create_or_edit_note }
      it('allows the user to cancel a note') { @degree_check_page.click_cancel_note }
      it('allows the user to save a note') { @degree_check_page.create_or_edit_note @note_str }
      it('shows the note content') { expect(@degree_check_page.visible_note_body).to eql(@note_str.strip) }
      it('shows the note creating advisor') { expect(@degree_check_page.visible_note_update_advisor).to eql(test.advisor.full_name) }
      it('shows the note creation date') { expect(@degree_check_page.note_update_date).to include('today') }
      it('offers an edit button for a note') { @degree_check_page.click_create_or_edit_note }
      it('allows the user to cancel a note edit') { @degree_check_page.click_cancel_note }
      it('allows the user to save a note edit') { @degree_check_page.create_or_edit_note("EDITED - #{@note_str}") }
      it('shows the edited note content') { expect(@degree_check_page.visible_note_body).to eql("EDITED - #{@note_str}".strip) }
      it('shows the note edit advisor') { expect(@degree_check_page.note_update_advisor).to eql(test.advisor.full_name) }
      it('shows the note edit date') { expect(@degree_check_page.note_update_date).to include('today') }
    end

    describe 'campus requirements' do

      it 'can be selected' do
        @degree_check_page.click_campus_reqt_cbx 'American History'
        expect(@degree_check_page.campus_reqt_satisfied? 'American History').to be true
      end

      it 'can be deselected' do
        @degree_check_page.click_campus_reqt_cbx 'American History'
        expect(@degree_check_page.campus_reqt_satisfied? 'American History').to be false
      end

      it 'can include a note' do
        @degree_check_page.enter_campus_reqt_note('American History', "#{test.id} note")
      end
    end

    describe 'create button' do

      it 'allows the user to create a newer degree check' do
        @degree_check_page.click_create_new_degree
        @degree_check_create_page.degree_template_select_element.when_present Utils.short_wait
      end
    end

    describe 'print button' do

      it 'includes the degree notes by default' do
        @degree_check_create_page.go_back
        @degree_check_page.print_note_toggle_element.when_present Utils.short_wait
        expect(@degree_check_page.print_note_selected_option).to eql('Yes')
      end

      it 'allows the user to exclude the degree notes' do
        @degree_check_page.click_print_note_toggle
        expect(@degree_check_page.print_note_selected_option).to eql('No')
      end
    end

    describe 'history page' do

      before(:all) do
        @degree_check_page.click_view_degree_history
        @degrees = BOACUtils.get_student_degrees @student
      end

      it 'shows all degree checks by last updated descending' do
        @degree_check_history_page.wait_until(Utils.short_wait) { @degree_check_history_page.visible_degree_names.any? }
        expect(@degree_check_history_page.visible_degree_names).to eql(@degrees.map &:name)
      end

      it 'shows all degree check updated dates' do
        expect(@degree_check_history_page.visible_degree_update_dates).to eql(@degrees.map { |d| d.updated_date.strftime('%b %-d, %Y') })
      end

      it 'shows the updated by advisor' do
        expect(@degree_check_history_page.visible_degree_updated_by(@degree_check)).to eql(test.advisor.full_name)
      end

      it 'offers a create-new-degree button' do
        expect(@degree_check_history_page.create_new_degree_link?).to be true
      end
    end

    describe 'advisor with read-only permissions' do

      before(:all) do
        @degree_check_history_page.log_out
        @templates = BOACUtils.get_degree_templates
        @templates.sort_by! &:name
        @homepage.dev_auth test.read_only_advisor
      end

      it 'can view a list of all degree template names' do
        @homepage.click_degree_checks_link
        @degree_templates_mgmt_page.wait_until(Utils.short_wait) { @degree_templates_mgmt_page.template_link_elements.any? }
        expected = @templates.map &:name
        visible = @degree_templates_mgmt_page.visible_template_names
        @degree_templates_mgmt_page.wait_until(1, "Missing #{expected - visible}, Unexpected #{visible - expected}") do
          expected.sort == visible.sort
        end
      end

      it 'can view a list of all degree template dates' do
        expected = @templates.map { |t| t.created_date.strftime('%b %-d, %Y') }
        visible = @degree_templates_mgmt_page.visible_template_create_dates
        @degree_templates_mgmt_page.wait_until(1, "Missing #{expected - visible}, Unexpected #{visible - expected}") do
          expected.sort == visible.sort
        end
      end

      it 'can print a degree template' # TODO download file and verify name

      it 'can view a degree template' do
        view_template = @templates.first
        @degree_templates_mgmt_page.click_degree_link view_template
        @degree_template_page.template_heading(view_template).when_visible Utils.short_wait
      end

      it 'cannot edit a degree template' do
        expect(@degree_template_page.unit_req_add_button?).to be false
        expect(@degree_template_page.add_col_req_button(1).exists?).to be false
        expect(@degree_template_page.cat_edit_button_elements).to be_empty
        expect(@degree_template_page.cat_delete_button_elements).to be_empty
      end

      it 'can view a degree check' do
        @student_page.load_page @student
        @student_page.click_degree_checks_button
        @degree_check_page.degree_check_heading(@degree_check).when_visible Utils.short_wait
      end

      it('cannot edit degree notes') { expect(@degree_check_page.create_or_edit_note_button?).to be false }
      it 'can print a degree check with notes' # TODO download file and verify name
      it 'can print a degree check without notes' # TODO download file and verify name
      it('cannot create a new degree check') { expect(@degree_check_page.create_new_degree_link?).to be false }
      it('cannot assign courses') { expect(@degree_check_page.assign_course_button_elements).to be_empty }
      it('cannot edit courses') { expect(@degree_check_page.cat_edit_button_elements).to be_empty }
      it('cannot copy courses') { expect(@degree_check_page.copy_course_button_elements).to be_empty }
      it('cannot drag and drop courses') # TODO
      it('cannot click campus requirements checkboxes') { expect(@degree_check_page.campus_reqt_selectable? 'American History').to be false }

      context 'on the degree history page' do

        before(:all) do
          @degree_check_page.click_view_degree_history
          @degrees = BOACUtils.get_student_degrees @student
        end

        it 'can view a list of student degree check names by last updated descending' do
          @degree_check_history_page.wait_until(Utils.short_wait) { @degree_check_history_page.visible_degree_names.any? }
          expect(@degree_check_history_page.visible_degree_names).to eql(@degrees.map &:name)
        end

        it 'can view a list of student degree check updated dates' do
          expected = @degrees.map { |d| d.updated_date.strftime('%b %-d, %Y') }
          @degree_check_history_page.wait_until(2, "Expected #{expected}, got #{@degree_check_history_page.visible_degree_update_dates}") do
            @degree_check_history_page.visible_degree_update_dates == expected
          end
        end

        it 'can view a student degree check updated-by advisor' do
          expected = test.advisor.full_name
          @degree_check_history_page.wait_until(2, "Expected #{expected}, got #{@degree_check_history_page.visible_degree_updated_by(@degree_check)}") do
            @degree_check_history_page.visible_degree_updated_by(@degree_check) == expected
          end
        end

        it('sees no create-new-degree button') { expect(@degree_check_history_page.create_new_degree_link?).to be false }
      end
    end
  end

  describe 'batch' do

    describe 'advisor' do

      before(:all) do
        @degree_check_history_page.log_out
        @homepage.dev_auth test.advisor
      end

      context 'with no cohorts or groups' do

        before(:all) do
          BOACUtils.get_user_filtered_cohorts(test.advisor, default: true).each do |c|
            @cohort_page.load_cohort c
            @cohort_page.delete_cohort c
          end
          BOACUtils.get_user_curated_groups(test.advisor).each do |g|
            @curated_group_page.load_page g
            @curated_group_page.delete_cohort g
          end
          @homepage.click_degree_checks_link
          @degree_templates_mgmt_page.click_batch_degree_checks
          @degree_batch_page.student_input_element.when_present Utils.short_wait
        end

        it('sees no cohort select on the batch degree page') { expect(@degree_batch_page.select_cohort_button_element.visible?).to be false }
        it('sees no group select on the batch degree page') { expect(@degree_batch_page.select_group_button_element.visible?).to be false }
        it('cannot create a degree check batch with nothing selected') { expect(@degree_batch_page.batch_degree_check_save_button_element.disabled?).to be true }

        it 'can cancel a degree check batch' do
          @degree_batch_page.click_cancel_batch_degree_check
          @degree_templates_mgmt_page.batch_degree_check_link_element.when_present Utils.short_wait
        end
      end

      context 'creating a degree check batch' do

        before(:all) do

          @homepage.click_degree_checks_link
          @degree_templates_mgmt_page.click_rename_button template
          @degree_templates_mgmt_page.enter_new_name(template.name = "#{template.name} - Edited")
          @degree_templates_mgmt_page.click_save_new_name
          @degree_templates_mgmt_page.degree_check_link(template).when_visible Utils.short_wait

          # Create cohort
          @homepage.load_page
          @cohort_page.search_and_create_new_cohort(test.default_cohort, default: true)
          test.default_cohort.members = test.cohort_members
          test.default_cohort.member_count = test.cohort_members.length
          cohorts << test.default_cohort

          # Create curated_groups
          [curated_group_1, curated_group_2].each do |curated_group|
            @homepage.click_sidebar_create_curated_group
            @curated_group_page.create_group_with_bulk_sids(curated_group_members, curated_group)
            @curated_group_page.wait_for_sidebar_group curated_group
            curated_groups << curated_group
          end

          batch_students.delete @student
          @batch_1_expected_students = @homepage.unique_students_in_batch(batch_students, cohorts, curated_groups)
          logger.debug "Expected batch SIDs #{(@batch_1_expected_students.map &:sis_id).sort}"

          @homepage.click_degree_checks_link
          @degree_templates_mgmt_page.click_batch_degree_checks
        end

        it('can add students via bulk SID entry') { @degree_batch_page.add_sids_to_batch(batch_degree_check_1, batch_students) }

        it('can add cohorts') { @degree_batch_page.add_cohorts_to_batch(batch_degree_check_1, cohorts) }

        it('can add groups') { @degree_batch_page.add_curated_groups_to_batch(batch_degree_check_1, curated_groups) }

        it('can remove students') { @degree_batch_page.remove_students_from_batch(batch_degree_check_1, batch_students) }

        it('can remove cohorts') { @degree_batch_page.remove_cohorts_from_batch(batch_degree_check_1, cohorts) }

        it('can remove groups') { @degree_batch_page.remove_groups_from_batch(batch_degree_check_1, curated_groups) }

        it('can select a degree template') { @degree_batch_page.select_degree template }

        it 'sees how many degree checks will be created' do
          @degree_batch_page.add_sids_to_batch(batch_degree_check_1, batch_students)
          @degree_batch_page.add_cohorts_to_batch(batch_degree_check_1, cohorts)
          @degree_batch_page.add_curated_groups_to_batch(batch_degree_check_1, curated_groups)
          expected_student_count = @batch_1_expected_students.length
          @degree_batch_page.student_count_msg_element.when_present Utils.short_wait
          expect(@degree_batch_page.student_count_msg).to include(expected_student_count.to_s)
        end

        it 'can save a new degree check' do
          @degree_batch_page.click_save_batch_degree_check
          expected_student_count = @batch_1_expected_students.length
          expected_msg = "Degree check #{template.name} added to #{expected_student_count} student profiles"
          @degree_templates_mgmt_page.batch_success_msg_element.when_visible Utils.medium_wait
          expect(@degree_templates_mgmt_page.batch_success_msg).to include(expected_msg)
          @degree_templates_mgmt_page.batch_degree_check_link_element.when_present Utils.long_wait
        end

        it 'creates degree checks for all the right students' do
          expected_sids = @batch_1_expected_students.map(&:sis_id).sort
          name = batch_degree_check_1.template.name
          @homepage.wait_until(Utils.short_wait,
                               "Missing: #{expected_sids - BOACUtils.get_degree_sids_by_degree_name(name)},
                                   Unexpected: #{BOACUtils.get_degree_sids_by_degree_name(name) - expected_sids}") do
            BOACUtils.get_degree_sids_by_degree_name(name) == expected_sids
          end
        end

        it 'creates degree checks for each student' do
          student = @batch_1_expected_students.first
          student_degree_check = DegreeProgressChecklist.new(template, student)
          @student_page.set_new_degree_id(student_degree_check, student)
          student_degree_check.set_degree_check_ids
          @degree_check_page.load_page student_degree_check
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

            sub_cat.course_reqs.each do |req_course|
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

          cat.course_reqs.each do |course|
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

        it 'will not create duplicate degree checks' do
          student = @batch_1_expected_students.first
          @degree_check_page.click_degree_checks_link
          @degree_templates_mgmt_page.click_batch_degree_checks
          @degree_batch_page.add_sids_to_batch(batch_degree_check_1, [student])
          @degree_batch_page.select_degree batch_degree_check_1.template
          @degree_batch_page.dupe_degree_check_msg_element.when_present Utils.short_wait
        end
      end
    end
  end
end
