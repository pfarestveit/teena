require_relative '../../util/spec_helper'

include Logging

test = BOACTestConfig.new
test.degree_progress

students = test.students.last BOACUtils.config['notes_batch_students_count']
students_manual = students[0..1]
students_bulk = students[2..-1]
cohorts = []
curated_groups = []
curated_group_members = test.students.shuffle.last BOACUtils.config['notes_batch_curated_group_count']
curated_group_1 = CuratedGroup.new name: "Group 1 - #{test.id}"
curated_group_2 = CuratedGroup.new name: "Group 2 - #{test.id}"
degree_template = test.degree_templates.first
batch_degree_check_1 = DegreeProgressBatch.new degree_template

describe 'A BOA degree check batch' do

  before(:all) do
    @driver = Utils.launch_browser
    @homepage = BOACHomePage.new @driver
    @cohort_page = BOACFilteredCohortPage.new(@driver, test.advisor)
    @curated_group_page = BOACGroupPage.new @driver
    @student_page = BOACStudentPage.new @driver
    @search_results_page = BOACSearchResultsPage.new @driver
    @degree_templates_mgmt_page = BOACDegreeTemplateMgmtPage.new @driver
    @degree_template_page = BOACDegreeTemplatePage.new @driver
    @degree_batch_page = BOACDegreeCheckBatchPage.new @driver
    @degree_check_page = BOACDegreeCheckPage.new @driver

    @homepage.dev_auth test.advisor
    @homepage.click_degree_checks_link
    @degree_templates_mgmt_page.create_new_degree degree_template
    @degree_template_page.complete_template degree_template
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'advisor' do

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

        @batch_1_expected_students = @homepage.unique_students_in_batch(students, cohorts, curated_groups)
        logger.debug "Expected batch SIDs #{(@batch_1_expected_students.map &:sis_id).sort}"

        @homepage.click_degree_checks_link
        @degree_templates_mgmt_page.click_batch_degree_checks
      end

      it 'can add students individually' do
        students_manual.each { |student| @degree_batch_page.add_student_to_batch(batch_degree_check_1, student) }
      end

      it 'can add students via bulk SID entry' do
        @degree_batch_page.add_sids_to_batch(batch_degree_check_1, students_bulk)
      end

      it('can add cohorts') { @degree_batch_page.add_cohorts_to_batch(batch_degree_check_1, cohorts) }

      it('can add groups') { @degree_batch_page.add_curated_groups_to_batch(batch_degree_check_1, curated_groups) }

      it('can remove students') { @degree_batch_page.remove_students_from_batch(batch_degree_check_1, students) }

      it('can remove cohorts') { @degree_batch_page.remove_cohorts_from_batch(batch_degree_check_1, cohorts) }

      it('can remove groups') { @degree_batch_page.remove_groups_from_batch(batch_degree_check_1, curated_groups) }

      it('can select a degree template') { @degree_batch_page.select_degree degree_template }

      it 'sees how many degree checks will be created' do
        students_manual.each { |student| @degree_batch_page.add_student_to_batch(batch_degree_check_1, student) }
        @degree_batch_page.add_sids_to_batch(batch_degree_check_1, students_bulk)
        @degree_batch_page.add_cohorts_to_batch(batch_degree_check_1, cohorts)
        @degree_batch_page.add_curated_groups_to_batch(batch_degree_check_1, curated_groups)
        expected_student_count = @batch_1_expected_students.length
        @degree_batch_page.student_count_msg_element.when_present Utils.short_wait
        expect(@degree_batch_page.student_count_msg).to include(expected_student_count.to_s)
      end

      it 'can save a new degree check' do
        @degree_batch_page.click_save_batch_degree_check
        @degree_templates_mgmt_page.batch_degree_check_link_element.when_present Utils.short_wait
      end

      it 'creates degree checks for all the right students' do
        expected_sids = @batch_1_expected_students.map(&:sis_id).sort
        name = batch_degree_check_1.template.name
        @homepage.wait_until(Utils.short_wait,
                             "Missing: #{expected_sids - BOACUtils.get_degree_sids_by_degree_name(name)}, Unexpected: #{BOACUtils.get_degree_sids_by_degree_name(name) - expected_sids}") do
          BOACUtils.get_degree_sids_by_degree_name(name) == expected_sids
        end
      end

      it 'creates degree checks for each student' do
        student = @batch_1_expected_students.first
        student_degree_check = DegreeProgressChecklist.new(degree_template, student)
        @student_page.set_new_degree_id(student_degree_check, student)
        student_degree_check.set_degree_check_ids
        @degree_check_page.load_page student_degree_check
      end

      degree_template.unit_reqts&.each do |u_req|
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

      degree_template.categories&.each do |cat|
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
        @degree_batch_page.add_student_to_batch(batch_degree_check_1, student)
        @degree_batch_page.select_degree batch_degree_check_1.template
        @degree_batch_page.dupe_degree_check_msg_element.when_present Utils.short_wait
      end
    end
  end
end
