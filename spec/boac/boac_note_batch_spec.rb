require_relative '../../util/spec_helper'

include Logging

test = BOACTestConfig.new
test.batch_note_management NessieUtils.get_all_students

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

        it 'can create batch of notes with a list of student names and/or SIDs' do
          @homepage.create_batch_of_notes(batch_note_1, [ Topic::PROBATION ], [], %w(Johnso 26 Elizabe), [], [])
        end

        it 'can create a batch of notes for a cohort of students' do
          @homepage.create_batch_of_notes(batch_note_2, [Topic::SAT_ACAD_PROGRESS_APPEAL, Topic::PASS_NO_PASS], [], [], [ test.default_cohort ], [])
        end

      end
    end
  end
end
