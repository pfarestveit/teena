require_relative '../../util/spec_helper'

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

  describe 'A BOAC', order: :defined do

    include Logging

    before(:all) do
      @driver = Utils.launch_browser
      @homepage = BOACHomePage.new @driver
      @cohort_page = BOACFilteredCohortPage.new @driver
      @curated_group_page = BOACGroupPage.new @driver
      @student_page = BOACStudentPage.new @driver
    end

    after(:all) {Utils.quit_browser @driver}

    describe 'advisor' do

      before(:all) do
        @homepage.dev_auth test.advisor
        # Create a default cohort
        @homepage.load_page
        @cohort_page.search_and_create_new_cohort(test.default_cohort, test)
      end

      after(:all) do
        @homepage.load_page
        @homepage.log_out
      end

      context 'creating a new batch of notes' do

        it 'cannot create a batch of notes without a subject' do
          @homepage.click_create_note_batch
          @homepage.new_note_save_button_element.when_present 1
          expect(@homepage.new_note_save_button_element.disabled?).to be true
        end

        it 'can cancel an unsaved batch of notes' do
          @homepage.click_create_note_batch
          @homepage.wait_for_element_and_type(@homepage.note_body_text_area_elements[0], 'Discard me!')
          @homepage.click_cancel_new_note
          @homepage.confirm_delete_or_discard
          @homepage.note_body_text_area_elements[0].when_not_visible 1
        end

        it 'can create batch of notes with a list of students, cohorts, and curated groups' do
          # Create curated group
          @homepage.click_sidebar_create_curated_group
          students_in_curated_group = test.dept_students.last(3)
          curated_group = CuratedGroup.new({:name => "Curated Group #{test.id}, batch notes test"})
          @curated_group_page.create_group_with_bulk_sids(students_in_curated_group, curated_group)
          @curated_group_page.wait_for_sidebar_group curated_group

          students_for_auto_complete = test.dept_students.first(3)

          @homepage.create_batch_of_notes(
              batch_note_1,
              [ Topic::PROBATION ],
              test.attachments[0..1],
              students_for_auto_complete,
              [ test.default_cohort ],
              [ curated_group ]
          )
          # Give a moment for batch note creation to finish
          sleep Utils.short_wait
          # A sample set of students, per grouping, is all we need to verify
          students_impacted = students_in_curated_group.first(2) | students_for_auto_complete.first(2) | test.cohort_members.first(2)

          students_impacted.each do |student|
            @student_page.load_page(student)
            @student_page.expand_note_by_subject(batch_note_1.subject)
          end
        end

        it 'immediately shows new note on student profile if student is in curated group of batch note creation' do
          @homepage.click_sidebar_create_curated_group
          students_in_curated_group = test.dept_students.first(5)
          curated_group = CuratedGroup.new({:name => "Curated Group #{test.id}, batch notes test"})
          @curated_group_page.create_group_with_bulk_sids(students_in_curated_group, curated_group)
          @curated_group_page.wait_for_sidebar_group curated_group

          # Load profile of an arbitrary student in the curated group
          student = students_in_curated_group.last
          @student_page.load_page(student)

          @homepage.create_batch_of_notes(batch_note_2, [], [], [], [],[ curated_group ])

          # Give a moment for batch note creation to finish
          sleep Utils.short_wait
          @student_page.expand_note_by_subject(batch_note_2.subject)
        end

      end
    end
  end
end
