require_relative '../../util/spec_helper'

unless ENV['DEPS']

  describe 'BOA note templates' do

    include Logging

    before(:all) do
      @test = BOACTestConfig.new
      @test.note_templates

      @student = @test.students.last
      @user_templates = NoteTemplate.get_user_note_templates @test.advisor
      logger.debug "User templates are #{@user_templates.map &:id}"
      @template_1 = NoteTemplate.new(title: "Template #{@test.id}")
      @template_2 = NoteTemplate.new(title: "Batch template #{@test.id}")
      @attachments = @test.attachments.sort_by(&:file_size).delete_if { |a| a.file_size > 20000000 }
      @attachments = @attachments.first 10

      @driver = Utils.launch_browser 'firefox'
      @homepage = BOACHomePage.new @driver
      @student_page = BOACStudentPage.new @driver
      @cohort_page = BOACFilteredStudentsPage.new(@driver, @test.advisor)
      @curated_group_page = BOACGroupStudentsPage.new @driver

      @homepage.dev_auth @test.advisor
    end

    after(:all) { Utils.quit_browser @driver }

    it 'can be deleted' do
      if @user_templates.any?
        @homepage.click_create_note_batch
        @user_templates.each { |template| @homepage.delete_template template }
      else
        logger.warn "Skipping test for deleting all templates because UID #{@test.advisor.uid} has no templates."
      end
    end

    context 'when an advisor has no templates' do

      before do
        @student_page.load_page @student
        @student_page.click_create_new_note
        @student_page.click_templates_button
      end

      it('show a "You have no saved templates" message') { @student_page.no_templates_msg_element.when_present 2 }
    end

    context 'on the student page create-note modal' do

      context 'when an advisor creates a new template' do

        before(:all) { @note = Note.new(subject: "Note student-page-create #{@test.id}", advisor: @test.advisor) }

        it 'can be cancelled' do
          @student_page.enter_new_note_subject @note
          @student_page.click_create_template
          @student_page.click_cancel_template
          @student_page.template_title_input_element.when_not_present 1
        end

        it 'can be created' do
          @student_page.enter_note_body @note
          @student_page.add_topics(@note, [Topic::ACADEMIC_PROGRESS_RPT, Topic::DEGREE_CHECK])
          @student_page.add_attachments_to_new_note(@note, @attachments.first(6))
          @student_page.create_template(@template_1, @note)
        end

        it 'add the template to the available templates' do
          @student_page.click_create_new_note
          @student_page.click_templates_button
          @student_page.wait_until(1) { @student_page.template_option(@template_1).exists? }
        end

        it 'require a title' do
          @student_page.enter_new_note_subject @note
          @student_page.click_create_template
          expect(@student_page.create_template_confirm_button_element.disabled?).to be true
        end

        it 'require a unique title' do
          @student_page.click_cancel_template
          @student_page.enter_new_note_subject @note
          @student_page.click_create_template
          @student_page.enter_template_title @template_1
          @student_page.click_save_template
          @student_page.dupe_template_title_msg_element.when_visible 1
        end

        it 'can be applied to a new note' do
          @student_page.click_cancel_template
          @student_page.select_and_apply_template(@template_1, @note)
          @student_page.click_save_new_note
          @student_page.set_new_note_id(@note, @student)
          @student_page.verify_note(@note, @test.advisor)
        end
      end

      context 'when an advisor edits an existing template' do

        before(:all) do
          @note = Note.new(subject: "Note student-page-edit #{@test.id}", advisor: @test.advisor)
          @student_page.load_page @student
          @student_page.click_create_new_note
        end

        it 'can be cancelled' do
          @student_page.click_edit_template @template_1
          @student_page.click_cancel_new_note
          @student_page.edit_template_heading_element.when_not_visible 1
        end

        it 'can be edited' do
          @template_1.subject = "Template #{@test.id} - edited"

          new_topics = [Topic::ACADEMIC_PROGRESS_RPT, Topic::EAP]
          topics_to_remove = @template_1.topics - new_topics
          topics_to_add = new_topics - @template_1.topics

          attachments_to_remove = @template_1.attachments
          attachments_to_add = @attachments.last 4

          @student_page.click_create_new_note
          @student_page.click_edit_template @template_1
          @student_page.enter_new_note_subject @template_1
          @student_page.enter_note_body @template_1
          @student_page.remove_topics(@template_1, topics_to_remove)
          @student_page.add_topics(@template_1, topics_to_add)
          @student_page.remove_attachments_from_new_note(@template_1, attachments_to_remove)
          @student_page.add_attachments_to_new_note(@template_1, attachments_to_add)
          @student_page.click_update_template
        end

        it 'can be applied to a new note' do
          @student_page.click_create_new_note
          @student_page.select_and_apply_template(@template_1, @note)
          @student_page.click_save_new_note
          @student_page.set_new_note_id(@note, @student)
          @student_page.verify_note(@note, @test.advisor)
        end

        it 'can be renamed but cancelled' do
          @student_page.click_create_new_note
          @student_page.click_rename_template @template_1
          @student_page.click_cancel_template_rename
          @student_page.rename_template_input_element.when_not_visible 1
        end

        it 'can be renamed' do
          @template_1.title = "S T #{@test.id}"
          @student_page.rename_template @template_1
          @student_page.click_templates_button
          @student_page.template_option(@template_1).when_visible 1
        end

        it 'can be deleted but cancelled' do
          @student_page.click_delete_template @template_1
          @student_page.cancel_delete_or_discard
          @student_page.cancel_delete_or_discard_button_element.when_not_visible 1
        end

        it 'can be deleted' do
          @student_page.delete_template @template_1
          @student_page.click_templates_button
          expect(@student_page.template_options).not_to include(@template_1.title)
        end
      end
    end

    context 'on the batch note modal' do

      before(:all) do
        # Get students to add one-by-one
        @students = @test.students.select { |s| !s.uid.strip.empty? }.first 2

        # Create cohort to add
        @homepage.load_page
        @cohort_page.search_and_create_new_cohort(@test.default_cohort, default: true)
        @test.default_cohort.members = @test.cohort_members

        # Create group to add
        group_members = @test.students.shuffle.last BOACUtils.config['notes_batch_curated_group_count']
        @group = CuratedGroup.new(name: "Group 1 - #{@test.id}")
        @homepage.click_sidebar_create_student_group
        @curated_group_page.create_group_with_bulk_sids(group_members, @group)
        @curated_group_page.wait_for_sidebar_group @group
      end

      context 'when an advisor creates a new template' do

        before(:all) do
          @note_batch = NoteBatch.new(subject: "Note batch-create #{@test.id}", body: "Body #{@test.id}", advisor: @test.advisor)
          @homepage.click_create_note_batch
        end

        it 'can be cancelled' do
          @homepage.enter_new_note_subject @note_batch
          @homepage.click_create_template
          @homepage.click_cancel_template
          @homepage.template_title_input_element.when_not_present 1
        end

        it 'can be created' do
          @homepage.enter_note_body @note_batch
          @homepage.add_topics(@note_batch, [Topic::ACADEMIC_PROGRESS_RPT, Topic::DEGREE_CHECK])
          @homepage.add_attachments_to_new_note(@note_batch, @attachments.first(6))
          @homepage.create_template(@template_2, @note_batch)
        end

        it 'add the template to the available templates' do
          @homepage.click_create_note_batch
          @homepage.click_templates_button
          @homepage.wait_until(1) { @homepage.template_option @template_2 }
        end

        it 'require a title' do
          @homepage.enter_new_note_subject @note_batch
          @homepage.click_create_template
          expect(@homepage.create_template_confirm_button_element.disabled?).to be true
        end

        it 'require_a_unique_title' do
          @homepage.click_cancel_template
          @homepage.click_create_template
          @homepage.enter_template_title @template_2
          @homepage.click_save_template
          @homepage.dupe_template_title_msg_element.when_visible 1
        end

        it 'can be applied to a new note' do
          @homepage.click_cancel_template
          @homepage.add_students_to_batch(@note_batch, @students)
          @homepage.add_cohorts_to_batch(@note_batch, [@test.default_cohort])
          @homepage.add_curated_groups_to_batch(@note_batch, [@group])
          @homepage.select_and_apply_template(@template_2, @note_batch)
          @homepage.click_save_new_note
          batch_student = @students.first
          @student_page.set_new_note_id(@note_batch, batch_student)
          @student_page.load_page batch_student
          @student_page.verify_note(@note_batch, @test.advisor)
        end
      end

      context 'when an advisor edits an existing template' do

        before(:all) do
          @note_batch = NoteBatch.new(subject: "Note batch edit #{@test.id}", advisor: @test.advisor)
          @homepage.click_create_note_batch
        end

        it 'can be cancelled' do
          @homepage.click_edit_template @template_2
          @homepage.click_cancel_new_note
          @homepage.edit_template_heading_element.when_not_visible 1
        end

        it 'can be edited' do
          @template_2.subject = "Template #{@test.id} - edited"

          new_topics = [Topic::ACADEMIC_PROGRESS_RPT, Topic::EAP]
          topics_to_remove = @template_2.topics - new_topics
          topics_to_add = new_topics - @template_2.topics

          attachments_to_remove = @template_2.attachments
          attachments_to_add = @attachments.last 4

          @homepage.click_create_note_batch
          @homepage.click_edit_template @template_2
          @homepage.enter_new_note_subject @template_2
          @homepage.enter_note_body @template_2
          @homepage.remove_topics(@template_2, topics_to_remove)
          @homepage.add_topics(@template_2, topics_to_add)
          @homepage.remove_attachments_from_new_note(@template_2, attachments_to_remove)
          @homepage.add_attachments_to_new_note(@template_2, attachments_to_add)
          @homepage.click_update_template
        end

        it 'can be applied to a new note' do
          @homepage.click_create_note_batch
          @homepage.add_students_to_batch(@note_batch, @students)
          @homepage.add_cohorts_to_batch(@note_batch, [@test.default_cohort])
          @homepage.add_curated_groups_to_batch(@note_batch, [@group])
          @homepage.select_and_apply_template(@template_2, @note_batch)
          @homepage.click_save_new_note
          batch_student = @students.first
          @student_page.set_new_note_id(@note_batch, batch_student)
          @student_page.load_page batch_student
          @student_page.verify_note(@note_batch, @test.advisor)
        end

        it 'can be renamed but cancelled' do
          @homepage.click_create_note_batch
          @homepage.click_rename_template @template_2
          @homepage.click_cancel_template_rename
          @homepage.rename_template_input_element.when_not_visible 1
        end

        it 'can be renamed' do
          @template_2.title = "B T #{@test.id}"
          @homepage.rename_template @template_2
          @homepage.click_templates_button
          @homepage.template_option(@template_2).when_visible 1
        end

        it 'can be deleted but cancelled' do
          @homepage.click_delete_template @template_2
          @homepage.cancel_delete_or_discard
          @homepage.cancel_delete_or_discard_button_element.when_not_visible 1
        end

        it 'can be deleted' do
          @homepage.delete_template @template_2
          @homepage.click_templates_button
          expect(@homepage.template_options).not_to include(@template_2.title)
        end

      end
    end
  end
end
