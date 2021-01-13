require_relative '../../util/spec_helper'

if (ENV['DEPS'] || ENV['DEPS'].nil?) && !ENV['NO_DEPS']

  include Logging

  test = BOACTestConfig.new
  test.batch_note_management

  # TODO - get real array of advisor dept mappings when we have them
  test.advisor.depts = [test.dept.name]

  if test.dept == BOACDepartments::ADMIN

    logger.error 'Tests cannot be run for the Admin dept'

  else

    batch_notes = []
    batch_notes << (batch_note_1 = NoteBatch.new({advisor: test.advisor, subject: "Batch note 1 subject #{Utils.get_test_id}"}))
    batch_notes << (batch_note_2 = NoteBatch.new({advisor: test.advisor, subject: "Batch note 2 subject #{Utils.get_test_id}"}))

    students = test.students.first BOACUtils.config['notes_batch_students_count']
    cohorts = []
    curated_groups = []
    curated_group_members = test.students.shuffle.last BOACUtils.config['notes_batch_curated_group_count']
    curated_group_1 = CuratedGroup.new({:name => "Group 1 - #{test.id}"})
    curated_group_2 = CuratedGroup.new({:name => "Group 2 - #{test.id}"})

    describe 'A BOAC', order: :defined do

      include Logging

      before(:all) do
        @driver = Utils.launch_browser
        @homepage = BOACHomePage.new @driver
        @cohort_page = BOACFilteredCohortPage.new(@driver, test.advisor)
        @curated_group_page = BOACGroupPage.new @driver
        @student_page = BOACStudentPage.new @driver
        @search_results_page = BOACSearchResultsPage.new @driver

        @homepage.dev_auth test.advisor
      end

      after(:all) { Utils.quit_browser @driver }

      describe 'advisor' do

        context 'with no cohorts or groups' do

          before(:all) do
            pre_existing_cohorts = BOACUtils.get_user_filtered_cohorts test.advisor, default: true
            pre_existing_cohorts.each do |c|
              @cohort_page.load_cohort c
              @cohort_page.delete_cohort c
            end

            pre_existing_groups = BOACUtils.get_user_curated_groups test.advisor
            pre_existing_groups.each do |g|
              @curated_group_page.load_page g
              @curated_group_page.delete_cohort g
            end
            @homepage.click_create_note_batch
            @homepage.batch_note_add_student_input_element.when_visible Utils.short_wait
          end

          it('sees no cohort button on the batch note modal') { expect(@homepage.batch_note_add_cohort_button_element.visible?).to be false }
          it('sees no group button on the batch note modal') { expect(@homepage.batch_note_add_curated_group_button_element.visible?).to be false }
        end

        context 'creating a new batch of notes' do

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
          end

          it 'cannot create a batch of notes without a subject' do
            @homepage.click_create_note_batch
            @homepage.new_note_save_button_element.when_present 1
            expect(@homepage.new_note_save_button_element.disabled?).to be true
          end

          it('can cancel an unsaved batch of notes') { @homepage.click_cancel_new_note }

          it 'can add students' do
            @homepage.click_create_note_batch
            @homepage.add_students_to_batch(batch_note_1, students)
          end

          it('can add cohorts') { @homepage.add_cohorts_to_batch(batch_note_1, cohorts) }

          it('can add groups') { @homepage.add_curated_groups_to_batch(batch_note_1, curated_groups) }

          it('can remove students') { @homepage.remove_students_from_batch(batch_note_1, students) }

          it('can remove cohorts') { @homepage.remove_cohorts_from_batch(batch_note_1, cohorts) }

          it('can remove groups') { @homepage.remove_groups_from_batch(batch_note_1, curated_groups) }

          it 'requires at least one student' do
            @homepage.enter_new_note_subject batch_note_1
            expect(@homepage.new_note_save_button_element.disabled?).to be true
          end

          it 'sees how many notes will be created' do
            @homepage.add_students_to_batch(batch_note_1, students)
            @homepage.add_cohorts_to_batch(batch_note_1, cohorts)
            @homepage.add_curated_groups_to_batch(batch_note_1, curated_groups)
            expected_student_count = @batch_1_expected_students.length
            @homepage.wait_until(1, "Expected #{expected_student_count} notes, got #{@homepage.batch_note_student_count_alert}") do
              @homepage.batch_note_student_count_alert.include? "Note will be added to #{expected_student_count}"
            end
          end

          it 'can save a new note' do
            @homepage.click_cancel_new_note
            @homepage.confirm_delete_or_discard
            @homepage.wait_until(1) { @homepage.note_body_text_area_elements.empty? }
            @homepage.create_batch_of_notes(batch_note_1, [Topic::PROBATION, Topic::ACADEMIC_PROGRESS], test.attachments[0..1], students, cohorts, curated_groups)
          end

          it 'creates notes for all the right students' do
            expected_sids = @batch_1_expected_students.map(&:sis_id).sort
            @homepage.wait_until(Utils.short_wait, "Expected by not present: #{expected_sids - BOACUtils.get_note_sids_by_subject(batch_note_1)}, present but not expected: #{BOACUtils.get_note_sids_by_subject(batch_note_1) - expected_sids}") do
              BOACUtils.get_note_sids_by_subject(batch_note_1) == expected_sids
            end
          end

          it 'creates notes with the right content for each student' do
            @homepage.unique_students_in_batch(students, cohorts, curated_groups).first(5).each do |student|
              @student_page.set_new_note_id(batch_note_1, student)
              @student_page.load_page student
              @student_page.expand_item batch_note_1
              @student_page.verify_note batch_note_1
            end
          end

          it 'immediately shows new note on student profile if student is in curated group of batch note creation' do
            student = curated_groups[0].members.last
            @student_page.load_page student
            @homepage.create_batch_of_notes(batch_note_2, [], [], [], [], curated_groups)
            @student_page.expand_note_by_subject batch_note_2.subject
          end

        end

        context 'searching for newly created batch notes' do

          it 'can find them by student and subject' do
            student = @homepage.unique_students_in_batch(students, cohorts, curated_groups).last
            @homepage.set_new_note_id(batch_note_1, student)
            @homepage.set_notes_student student
            @homepage.enter_string_and_hit_enter batch_note_1.subject
            expect(@search_results_page.note_in_search_result? batch_note_1).to be true
          end
        end

      end
    end
  end
end
