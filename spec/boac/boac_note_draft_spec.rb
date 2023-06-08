require_relative '../../util/spec_helper'

# TODO - force a browser session timeout

include Logging

describe 'BOA draft note' do

  before(:all) do
    @test = BOACTestConfig.new
    @test.note_drafts

    @director = BOACUtils.get_authorized_users.find do |a|
      a.dept_memberships.find { |m| m.advisor_role == AdvisorRole::DIRECTOR }
    end
    @other_advisor = BOACUtils.get_dept_advisors(@test.dept).find do |a|
      a.can_access_advising_data && a.uid != @test.advisor.uid
    end
    logger.info "Advisor UID #{@test.advisor.uid}"
    logger.info "Director UID #{@director.uid}"
    logger.info "Other advisor UID #{@other_advisor.uid}"

    @test.test_students.shuffle!
    @test_student = @test.test_students.first
    @notes = []
    @notes << (@note_0 = Note.new advisor: @test.advisor, is_draft: true)
    @notes << (@note_1 = Note.new advisor: @test.advisor, is_draft: true)
    @notes << (@note_2 = NoteBatch.new advisor: @other_advisor, is_draft: true)
    @notes << (@note_3 = NoteBatch.new advisor: @test.advisor, is_draft: true)
    @notes << (@note_4 = NoteBatch.new advisor: @test.advisor, is_draft: true)
    @notes << (@note_5 = NoteBatch.new advisor: @test.advisor, is_draft: true)
    @notes << (@note_6 = NoteBatch.new advisor: @test.advisor, is_draft: true)

    @attachments = @test.attachments.sort_by(&:file_size).first(10)
    @topics = Topic::TOPICS[0..2]

    @test.students.shuffle!
    @students = @test.students.first BOACUtils.config['notes_batch_students_count']
    @curated_group_members = @test.students.last BOACUtils.config['notes_batch_curated_group_count']
    @curated_group = CuratedGroup.new({ :name => "Group 1 - #{@test.id}" })
    @cohort = @test.default_cohort

    @driver = Utils.launch_browser
    @cohort_page = BOACFilteredStudentsPage.new(@driver, @test.advisor)
    @curated_group_page = BOACGroupStudentsPage.new @driver
    @drafts_page = BOACDraftNotesPage.new @driver
    @fdr_page = BOACFlightDataRecorderPage.new @driver
    @homepage = BOACHomePage.new @driver
    @pax_manifest_page = BOACPaxManifestPage.new @driver
    @search_results_page = BOACSearchResultsPage.new @driver
    @student_page = BOACStudentPage.new @driver
    @api_admin_page = BOACApiAdminPage.new @driver
    @api_notes_page = BOACApiNotesPage.new @driver
    @api_student_page = BOACApiStudentPage.new @driver
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'creation' do

    context 'when canceled' do
      before(:all) do
        @homepage.load_page
        @homepage.dev_auth @test.advisor

        pre_existing_cohorts = BOACUtils.get_user_filtered_cohorts @test.advisor, default: true
        pre_existing_cohorts.each do |c|
          @cohort_page.load_cohort c
          @cohort_page.delete_cohort c
        end

        pre_existing_groups = BOACUtils.get_user_curated_groups @test.advisor
        pre_existing_groups.each do |g|
          @curated_group_page.load_page g
          @curated_group_page.delete_cohort g
        end

        @homepage.load_page
        @cohort_page.search_and_create_new_cohort(@cohort, default: true)
        @cohort.members = @test.cohort_members
        @cohort.member_count = @test.cohort_members.length

        @homepage.click_sidebar_create_student_group
        @curated_group_page.create_group_with_bulk_sids(@curated_group_members, @curated_group)
        @curated_group_page.wait_for_sidebar_group @curated_group

        @homepage.click_draft_notes
        @drafts_page.delete_all_drafts
      end

      it 'deletes the draft' do
        @student_page.load_page @test_student
        @student_page.click_create_new_note
        @note_0.subject = "Draft note 0 #{@test.id} subject"
        @student_page.enter_new_note_subject @note_0
        saved_note = @student_page.wait_for_draft_note @note_0
        expect(saved_note).to be_truthy
        @student_page.click_cancel_new_note
        @student_page.confirm_delete_or_discard
        @student_page.show_notes
        expect(@student_page.visible_collapsed_note_ids).not_to include(@note_0.id)
      end
    end

    context 'on the student page' do
      before(:all) do
        @student_page.click_create_new_note
      end

      it 'saves the subject and creation date' do
        @note_1.subject = "Draft note 1 #{@test.id} subject"
        @student_page.enter_new_note_subject @note_1
        saved_note = @student_page.wait_for_draft_note @note_1
        expect(saved_note).to be_truthy
      end

      it 'deletes the subject and substitutes a placeholder' do
        @note_1.subject = nil
        @student_page.enter_new_note_subject @note_1
        @student_page.wait_for_draft_note_update @note_1
      end

      it 'saves the body' do
        @note_1.subject = "Draft note 1 #{@test.id} subject"
        @note_1.body = "Draft note 1 #{@test.id} body"
        @student_page.enter_new_note_subject @note_1
        @student_page.enter_note_body @note_1
        @student_page.click_save_as_draft
        @student_page.wait_for_draft_note_update(@note_1, manual_update=true)
      end

      it 'removes the body' do
        @note_1.body = nil
        @student_page.expand_item @note_1
        @student_page.click_edit_note_button @note_1
        @student_page.enter_note_body @note_1
        @student_page.click_update_note_draft
        @student_page.wait_for_draft_note_update(@note_1, manual_update=true)
      end

      it 'saves attachments' do
        @student_page.add_attachments_to_existing_note(@note_1, @attachments[0..1])
        @student_page.wait_for_draft_note_update @note_1
      end

      it 'removes attachments' do
        @student_page.remove_attachments_from_existing_note(@note_1, [@note_1.attachments.last])
        @student_page.wait_for_draft_note_update @note_1
      end

      it 'saves topics' do
        @student_page.expand_item @note_1
        @student_page.click_edit_note_button @note_1
        @student_page.add_topics(@note_1, @topics)
        @student_page.click_update_note_draft
        @student_page.wait_for_draft_note_update(@note_1, manual_update=true)
      end

      it 'removes topics' do
        @student_page.expand_item @note_1
        @student_page.click_edit_note_button @note_1
        @student_page.remove_topics(@note_1, @topics)
        @student_page.wait_for_draft_note_update @note_1
      end

      it 'saves the set date' do
        @note_1.set_date = Time.now - 86400
        @student_page.enter_set_date @note_1
        @student_page.wait_for_draft_note_update @note_1
      end

      it 'removes the set date' do
        @note_1.set_date = nil
        @student_page.enter_set_date @note_1
        @student_page.wait_for_draft_note_update @note_1
      end

      it 'saves the contact method' do
        @note_1.type = 'Phone'
        @student_page.select_contact_type @note_1
        @student_page.click_update_note_draft
        @student_page.wait_for_draft_note_update(@note_1, manual_update=true)
      end

      it 'removes the contact method' do
        @note_1.type = nil
        @student_page.expand_item @note_1
        @student_page.click_edit_note_button @note_1
        @student_page.select_contact_type @note_1
        @student_page.wait_for_draft_note_update @note_1
      end

      it 'saves the privacy setting' do
        @note_1.is_private = true
        @student_page.set_note_privacy @note_1
        @student_page.wait_for_draft_note_update @note_1
      end
    end

    context 'on the batch note modal' do
      before(:all) do
        @student_page.log_out
        @homepage.dev_auth @other_advisor
        @homepage.click_create_note_batch
      end

      it 'saves the subject' do
        @note_2.subject = "Draft note 2 #{@test.id} subject"
        @homepage.enter_new_note_subject @note_2
        saved_note = @homepage.wait_for_draft_note @note_2
        expect(saved_note).to be_truthy
      end

      it 'adds a single student' do
        @homepage.add_students_to_batch(@note_2, [@test_student])
        @homepage.click_save_as_draft
        @homepage.wait_for_draft_note_update(@note_2, manual_update = true)
      end

      it 'removes the subject and substitutes a placeholder' do
        @note_2.subject = nil
        @homepage.click_draft_notes
        @drafts_page.click_subject @note_2
        @drafts_page.enter_new_note_subject @note_2
        @drafts_page.wait_for_draft_note_update @note_2
      end

      it 'saves the body' do
        @note_2.subject = "Draft note 2 #{@test.id} subject"
        @note_2.body = "Draft note 2 #{@test.id} body"
        @homepage.enter_new_note_subject @note_2
        @drafts_page.enter_note_body @note_2
        @drafts_page.wait_for_draft_note_update @note_2
      end

      it 'saves attachments' do
        @drafts_page.add_attachments_to_new_note(@note_2, @attachments[1..2])
        @drafts_page.click_save_as_draft
        @drafts_page.wait_for_draft_note_update(@note_2, manual_update=true)
      end

      it 'removes attachments' do
        @drafts_page.click_subject @note_2
        @drafts_page.remove_attachments_from_new_note(@note_2, [@note_2.attachments.last])
        @drafts_page.wait_for_draft_note_update @note_2
      end

      it 'adds topics' do
        @drafts_page.add_topics(@note_2, @topics)
        @drafts_page.click_save_as_draft
        @drafts_page.wait_for_draft_note_update(@note_2, manual_update = true)
      end

      it 'removes topics' do
        @drafts_page.click_subject @note_2
        @drafts_page.remove_topics(@note_2, [@topics[0]])
        @drafts_page.wait_for_draft_note_update @note_2
      end

      it 'adds the set date' do
        @note_2.set_date = Time.now - 86400
        @drafts_page.click_subject @note_2
        @drafts_page.enter_set_date @note_2
        @drafts_page.click_save_as_draft
        @drafts_page.wait_for_draft_note_update(@note_2, manual_update = true)
      end

      it 'removes the set date' do
        @note_2.set_date = nil
        @drafts_page.click_subject @note_2
        @drafts_page.enter_set_date @note_2
        @drafts_page.wait_for_draft_note_update @note_2
      end

      it 'adds the contact method' do
        @note_2.type = 'Phone'
        @drafts_page.select_contact_type @note_2
        @drafts_page.wait_for_draft_note_update @note_2
      end

      it 'removes the contact method' do
        @note_2.type = nil
        @drafts_page.select_contact_type @note_2
        @drafts_page.click_save_as_draft
        @drafts_page.wait_for_draft_note_update(@note_2, manual_update = true)
      end

      it 'adds the privacy setting' do
        @note_2.is_private = true
        @drafts_page.click_subject @note_2
        @drafts_page.set_note_privacy @note_2
        @drafts_page.click_save_as_draft
        @drafts_page.wait_for_draft_note_update(@note_2, manual_update = true)
      end

      it 'removes the privacy setting' do
        @note_2.is_private = false
        @drafts_page.click_subject @note_2
        @drafts_page.set_note_privacy @note_2
        @drafts_page.wait_for_draft_note_update @note_2
      end

      it 'removes a single student' do
        @drafts_page.remove_students_from_batch(@note_2, [@test_student])
        @drafts_page.click_save_as_draft
        @drafts_page.wait_for_draft_note_update(@note_2, manual_update = true)
      end

      it 'will not save multiple student records' do
        students = @test.students[0..1]
        @drafts_page.click_subject @note_2
        @drafts_page.add_students_to_batch(@note_2, students)
        @drafts_page.batch_note_draft_student_warning_element.when_visible Utils.short_wait
        @drafts_page.remove_students_from_batch(@note_2, students)
        @drafts_page.click_save_as_draft
        @drafts_page.wait_for_draft_note_update(@note_2, manual_update = true)
      end
    end
  end

  describe 'view access' do

    context 'when an admin' do
      before(:all) do
        @homepage.load_page
        @drafts_page.log_out
        @homepage.dev_auth
      end

      it 'is permitted on the draft notes page' do
        @homepage.click_draft_notes
        @drafts_page.wait_for_draft_note_row @note_1
        @drafts_page.wait_for_draft_note_row @note_2
      end

      it 'is permitted on the student page' do
        @drafts_page.click_student_link @note_1
        @student_page.collapsed_item_el(@note_1).when_visible Utils.short_wait
        visible = @student_page.visible_collapsed_note_data @note_1
        expect(visible[:subject]).to eql(@note_1.subject)
        expect(visible[:is_draft]).to be true
      end
    end

    context 'when an advisor who is not the author' do

      before(:all) do
        @student_page.log_out
        @homepage.dev_auth @other_advisor
      end

      it 'is denied on the draft notes page' do
        @homepage.click_draft_notes
        @drafts_page.wait_for_draft_note_row @note_2
        expect(@drafts_page.draft_note_row(@note_1).exists?).to be false
      end

      it 'is denied on the student page' do
        @student_page.load_page @test_student
        @student_page.notes_button_element.when_present Utils.short_wait
        expect(@student_page.collapsed_item_el(@note_1).exists?).to be false
      end

      it 'is denied on the student endpoint' do
        @api_student_page.get_data @test_student
        expect(@api_student_page.notes.map &:id).not_to include(@note_1.id)
      end

      it 'is denied on the attachment download endpoint' do
        id = BOACUtils.get_attachment_id_by_file_name(@note_1, @note_1.attachments.first)
        @api_notes_page.load_attachment_page id
        @api_notes_page.attach_not_found_msg_element.when_visible Utils.short_wait
      end
    end

    context 'when an advisor who is the author' do

      before(:all) do
        @homepage.load_page
        @homepage.log_out
        @homepage.dev_auth @test.advisor
      end

      it 'is permitted on the draft notes page' do
        @homepage.click_draft_notes
        @drafts_page.wait_for_draft_note_row @note_1
        expect(@drafts_page.draft_note_row(@note_2).exists?).to be false
      end

      it 'is permitted on the student page' do
        @drafts_page.click_student_link @note_1
        @student_page.collapsed_item_el(@note_1).when_visible Utils.short_wait
        visible = @student_page.visible_collapsed_note_data @note_1
        expect(visible[:subject]).to eql(@note_1.subject)
        expect(visible[:is_draft]).to be true
      end
    end
  end

  describe 'search' do

    before(:all) do
      @note_3.subject = "Draft note 3 #{@test.id} subject"
      @note_3.body = "Draft note 3 #{@test.id} body"
      @student_page.load_page @test_student
      @student_page.click_create_new_note
      @student_page.enter_new_note_subject @note_3
      @student_page.enter_note_body @note_3
      @student_page.add_topics(@note_3, @topics)
      @student_page.click_save_as_draft
      @student_page.wait_for_draft_note(@note_3, manual_update = true)
      @student_page.log_out
      @homepage.dev_auth
      @api_admin_page.reindex_notes
      @homepage.load_page
      @homepage.log_out
      @homepage.dev_auth @test.advisor
    end

    it 'by subject yields no result' do
      @homepage.close_adv_search_if_open
      @homepage.enter_simple_search_and_hit_enter @note_3.subject
      @search_results_page.wait_for_no_results
    end

    it 'by body yields no result' do
      @search_results_page.enter_simple_search_and_hit_enter @note_3.body
      @search_results_page.wait_for_no_results
    end

    it 'by topic yields no result' do
      @homepage.reopen_and_reset_adv_search
      @homepage.select_note_topic @note_3.topics.first
      @homepage.enter_adv_search_and_hit_enter @note_3.subject
      @search_results_page.wait_for_no_results
    end

    it 'by date yields no result' do
      date = Date.parse @note_3.created_date.to_s
      @homepage.reopen_and_reset_adv_search
      @homepage.set_notes_date_range(date - 1, date)
      @homepage.enter_adv_search_and_hit_enter @note_3.subject
      @search_results_page.wait_for_no_results
    end

    it 'by author yields no result' do
      @homepage.reopen_and_reset_adv_search
      @homepage.set_notes_author @test.advisor.full_name
      @homepage.enter_adv_search_and_hit_enter @note_3.subject
      @search_results_page.wait_for_no_results
    end

    it 'by student yields no result' do
      @homepage.reopen_and_reset_adv_search
      @homepage.set_notes_student @test_student
      @homepage.enter_adv_search_and_hit_enter @note_3.subject
      @search_results_page.wait_for_no_results
    end
  end

  describe 'list view' do

    before(:all) do
      @search_results_page.click_create_note_batch
      @note_4.subject = "Draft note 4 #{@test.id} subject"
      @homepage.enter_new_note_subject @note_4
      @homepage.click_save_as_draft
      @homepage.wait_for_draft_note(@note_4, manual_update = true)

      @homepage.click_create_note_batch
      @note_5.subject = "Draft note 5 #{@test.id} subject"
      @note_5.body = "Draft note 5 #{@test.id} body"
      @note_5.set_date = Time.now - 86400
      @homepage.enter_new_note_subject @note_5
      @homepage.enter_note_body @note_5
      @homepage.add_students_to_batch(@note_5, [@test_student])
      @homepage.enter_set_date @note_5
      @homepage.click_save_as_draft
      @homepage.wait_for_draft_note @note_5
      @homepage.click_draft_notes
      @drafts_page.click_subject @note_5
      @note_5.subject = nil
      @drafts_page.enter_new_note_subject @note_5
      @drafts_page.click_save_as_draft
      @drafts_page.wait_for_draft_note_update(@note_5, manual_update = true)

      @homepage.click_create_note_batch
      @note_6.subject = "Draft note 6 #{@test.id} subject"
      @homepage.enter_new_note_subject @note_6
      @homepage.add_students_to_batch(@note_6, [@test_student])
      @homepage.add_attachments_to_new_note(@note_6, @attachments[1..2])
      @homepage.click_save_as_draft
      @homepage.wait_for_draft_note(@note_6, manual_update = true)
    end

    context 'when an advisor' do

      before(:all) do
        @my_drafts = BOACUtils.get_advisor_note_drafts @test.advisor
        @homepage.click_draft_notes
        @visible_ids = @drafts_page.visible_draft_note_ids
        @visible_note_4 = @drafts_page.draft_note_row_data @note_4
        @visible_note_5 = @drafts_page.draft_note_row_data @note_5
        @visible_note_6 = @drafts_page.draft_note_row_data @note_6
      end

      it 'shows only the advisor\'s drafts' do
        expect(@visible_ids).to include(@note_1.id)
        expect(@visible_ids).not_to include(@note_2.id)
        expect(@visible_ids).to include(@note_3.id)
        expect(@visible_ids).to include(@note_4.id)
        expect(@visible_ids).to include(@note_5.id)
        expect(@visible_ids).to include(@note_6.id)
      end

      it 'shows the drafts in the right order' do
        expect(@visible_ids).to eql(@my_drafts.sort_by(&:updated_date).reverse.map(&:id))
      end

      it 'shows the name of the student or a placeholder' do
        expect(@visible_note_4[:student]).to eql('—')
        expect(@visible_note_5[:student]).to eql("#{@test_student.first_name} #{@test_student.last_name}")
        expect(@visible_note_6[:student]).to eql("#{@test_student.first_name} #{@test_student.last_name}")
      end

      it 'shows the SID of the student or a placeholder' do
        expect(@visible_note_4[:sid]).to eql('—')
        expect(@visible_note_5[:sid]).to eql("#{@test_student.sis_id}")
        expect(@visible_note_6[:sid]).to eql("#{@test_student.sis_id}")
      end

      it 'shows the subject snippet or a placeholder' do
        expect(@visible_note_4[:subject]).to eql(@note_4.subject)
        expect(@visible_note_5[:subject]).to eql('[DRAFT NOTE]')
        expect(@visible_note_6[:subject]).to include(@note_6.subject)
      end

      it 'shows the draft updated date' do
        expect(@visible_note_4[:date]).to include(Date.today.strftime('%b %-d'))
        expect(@visible_note_5[:date]).to include(Date.today.strftime('%b %-d'))
        expect(@visible_note_6[:date]).to include(Date.today.strftime('%b %-d'))
      end

      it 'shows a link to student pages' do
        @drafts_page.click_student_link @note_5
        @student_page.wait_for_spinner
        @student_page.wait_for_title "#{@test_student.first_name} #{@test_student.last_name}"
      end

      it 'shows a link to open the note editing modal on the list view page' do
        @student_page.click_draft_notes
        @drafts_page.wait_for_draft_note_row @note_4
        @drafts_page.click_subject @note_4
        @drafts_page.edit_draft_heading_element.when_visible 3
        @drafts_page.click_save_as_draft
      end
    end

    context 'when an admin' do

      before(:all) do
        @all_drafts = BOACUtils.get_advisor_note_drafts
        @homepage.log_out
        @homepage.dev_auth
        @homepage.click_draft_notes

        @visible_ids = @drafts_page.visible_draft_note_ids
        @visible_note_4 = @drafts_page.draft_note_row_data @note_4
        @visible_note_5 = @drafts_page.draft_note_row_data @note_5
        @visible_note_6 = @drafts_page.draft_note_row_data @note_6
      end

      it 'shows all drafts' do
        expect(@visible_ids).to include(@note_1.id)
        expect(@visible_ids).to include(@note_2.id)
        expect(@visible_ids).to include(@note_3.id)
        expect(@visible_ids).to include(@note_4.id)
        expect(@visible_ids).to include(@note_5.id)
        expect(@visible_ids).to include(@note_6.id)
      end

      it 'shows the draft author\'s name' do
        expect(@visible_note_4[:author]).to eql(@test.advisor.full_name)
      end

      it 'shows the drafts in the right order (newest first)' do
        expect(@visible_ids).to eql(@all_drafts.sort_by(&:updated_date).reverse.map(&:id))
      end

      it 'shows the name of the student or a placeholder' do
        expect(@visible_note_4[:student]).to eql('—')
        expect(@visible_note_5[:student]).to eql("#{@test_student.first_name} #{@test_student.last_name}")
        expect(@visible_note_6[:student]).to eql("#{@test_student.first_name} #{@test_student.last_name}")
      end

      it 'shows a link to student pages' do
        @drafts_page.click_student_link @note_5
        @student_page.wait_for_spinner
        @student_page.wait_for_title "#{@test_student.first_name} #{@test_student.last_name}"
      end

      it 'shows the SID of the student or a placeholder' do
        @student_page.click_draft_notes
        expect(@visible_note_4[:sid]).to eql('—')
        expect(@visible_note_5[:sid]).to eql("#{@test_student.sis_id}")
        expect(@visible_note_6[:sid]).to eql("#{@test_student.sis_id}")
      end

      it 'shows the subject snippet or a placeholder' do
        expect(@visible_note_4[:subject]).to eql(@note_4.subject)
        expect(@visible_note_5[:subject]).to eql('[DRAFT NOTE]')
        expect(@visible_note_6[:subject]).to include(@note_6.subject)
      end

      it 'shows no link to open the note editing modal on the list view page' do
        expect(@drafts_page.subject_button(@note_4).exists?).to be false
      end

      it 'shows the draft date (set, updated, created)' do
        expect(@visible_note_4[:date]).to include(Date.today.strftime('%b %-d'))
        expect(@visible_note_5[:date]).to include(Date.today.strftime('%b %-d'))
        expect(@visible_note_6[:date]).to include(Date.today.strftime('%b %-d'))
      end
    end
  end

  describe 'admin functions' do

    before(:all) do
      @other_advisor.dept_memberships = [
        (DeptMembership.new dept: BOACDepartments::L_AND_S,
                            advisor_role: AdvisorRole::DIRECTOR,
                            is_automated: true)
      ]
      @pax_manifest_page.load_page
      @pax_manifest_page.search_for_advisor @other_advisor
      @pax_manifest_page.edit_user @other_advisor
      @homepage.log_out
    end

    after(:all) do
      @other_advisor.dept_memberships = [
        (DeptMembership.new dept: BOACDepartments::ZCEEE,
                            advisor_role: AdvisorRole::ADVISOR,
                            is_automated: true)
      ]
      @pax_manifest_page.load_page
      @pax_manifest_page.search_for_advisor @other_advisor
      @pax_manifest_page.edit_user @other_advisor
    end

    it 'do not allow a director to see drafts' do
      @homepage.dev_auth @other_advisor
      @student_page.load_page @test_student
      @student_page.show_notes
      visible_ids = @student_page.visible_collapsed_note_ids
      expect(visible_ids).not_to include(@note_5.id)
    end

    it 'do not allow a director to download drafts' do
      @student_page.download_notes @test_student
      csv = @student_page.parse_note_export_csv_to_table @test_student
      expect(csv.find { |r| r[:subject] == @note_5.subject }).to be_nil
      expect(csv.find { |r| r[:subject] == @note_6.subject }).to be_nil
    end

    it 'do not allow an admin to download drafts' do
      @student_page.log_out
      @homepage.dev_auth
      @student_page.load_page @test_student
      @student_page.show_notes
      @student_page.download_notes @test_student
      csv = @student_page.parse_note_export_csv_to_table @test_student
      expect(csv.find { |r| r[:subject] == @note_5.subject }).to be_nil
      expect(csv.find { |r| r[:subject] == @note_6.subject }).to be_nil
    end
  end

  describe 'editing' do

    it 'cannot be done by an admin user' do
      @student_page.load_page @test_student
      @student_page.show_notes
      @student_page.expand_item @note_5
      expect(@student_page.edit_note_button(@note_5).exists?).to be false
    end

    context 'on the student page' do

      before(:all) do
        @student_page.log_out
        @homepage.dev_auth @test.advisor
        @student_page.load_page @test_student
        @student_page.show_notes
        @student_page.expand_item @note_5

        @note_5.subject = "#{@note_5.subject} EDITED"
        @note_5.body = "#{@note_5.body} EDITED"
        @note_5.set_date = Time.now
        @note_5.type = 'Phone'
        @note_5.is_private = true

        @student_page.click_edit_note_button @note_5
        @student_page.enter_edit_note_subject @note_5
        @student_page.enter_note_body @note_5
        @student_page.enter_set_date @note_5
        @student_page.select_contact_type @note_5
        @student_page.set_note_privacy @note_5
        @student_page.add_topics(@note_5, [Topic::ACADEMIC_PROGRESS])
        @student_page.click_update_note_draft
        @student_page.add_attachments_to_existing_note(@note_5, [@attachments[0]])
        @visible_expanded = @student_page.visible_expanded_note_data @note_5
        @student_page.collapse_item @note_5
        @visible_collapsed = @student_page.visible_collapsed_note_data @note_5
      end

      it('saves as a draft') { expect(@visible_collapsed[:is_draft]).to be true }
      it('saves the subject') { expect(@visible_collapsed[:subject]).to eql(@note_5.subject) }
      it('saves the body') { expect(@visible_expanded[:body]).to eql(@note_5.body) }
      it('saves attachments') { expect(@visible_expanded[:attachments]).to eql(@note_5.attachments.map &:file_name) }
      it('saves topics') { expect(@visible_expanded[:topics]).to eql(@note_5.topics.map { |t| t.name.upcase }) }
      it('saves the set date') { expect(@visible_expanded[:set_date]).to eql(@student_page.expected_item_short_date_format @note_5.set_date) }
      it('saves the contact method') { expect(@visible_expanded[:contact_type]).to eql(@note_5.type) }
    end

    context 'on the batch note modal' do
      before(:all) do
        @student_page.click_draft_notes
        @drafts_page.wait_for_draft_note_row @note_4
        @drafts_page.click_subject @note_4

        @note_4.subject = "#{@note_4.subject} EDITED"
        @note_4.body = "Draft note 4 #{@test.id} body"
        @note_4.set_date = Time.now - 172800
        @note_4.type = 'Admin'
        @note_4.is_private = true

        @drafts_page.add_students_to_batch(@note_4, [@test_student])
        @drafts_page.enter_new_note_subject @note_4
        @drafts_page.enter_note_body @note_4
        @drafts_page.enter_set_date @note_4
        @drafts_page.select_contact_type @note_4
        @drafts_page.set_note_privacy @note_4
        @drafts_page.add_topics(@note_4, [Topic::CHANGE_OF_COLLEGE])
        @drafts_page.add_attachments_to_new_note(@note_4, [@attachments[0]])
        @drafts_page.click_save_as_draft
        @drafts_page.wait_for_draft_note_row @note_4
        @drafts_page.click_student_link @note_4
        @student_page.show_notes
        @visible_collapsed = @student_page.visible_collapsed_note_data @note_4
        @student_page.expand_item @note_4
        @visible_expanded = @student_page.visible_expanded_note_data @note_4
      end

      it('saves as a draft') { expect(@visible_collapsed[:is_draft]).to be true }
      it('saves the subject') { expect(@visible_collapsed[:subject]).to eql(@note_4.subject) }
      it('saves the body') { expect(@visible_expanded[:body]).to eql(@note_4.body) }
      it('saves attachments') { expect(@visible_expanded[:attachments]).to eql(@note_4.attachments.map &:file_name) }
      it('saves topics') { expect(@visible_expanded[:topics]).to eql(@note_4.topics.map { |t| t.name.upcase }) }
      it('saves the set date') { expect(@visible_expanded[:set_date]).to eql(@student_page.expected_item_short_date_format @note_4.set_date) }
      it('saves the contact method') { expect(@visible_expanded[:contact_type]).to eql(@note_4.type) }
    end
  end

  describe 'conversion to a note' do

    context 'on a student page' do

      it 'saves the new note' do
        @student_page.click_edit_note_button @note_4
        @student_page.click_save_note_edit
        @note_4.is_draft = false
        @student_page.verify_note(@note_4, @test.advisor)
      end

      it 'removes the draft from list view' do
        @student_page.click_draft_notes
        @drafts_page.wait_for_draft_note_row @note_5
        expect(@drafts_page.draft_note_row(@note_4).exists?).to be false
      end
    end

    context 'on the batch note modal' do

      before(:all) do
        @drafts_page.click_subject @note_5
        @note_5.subject = "Draft note 5 #{@test.id} subject"
        @drafts_page.enter_new_note_subject @note_5
        @drafts_page.add_cohorts_to_batch(@note_5, [@cohort])
        @drafts_page.add_curated_groups_to_batch(@note_5, [@curated_group])
        @drafts_page.click_save_new_note
        @note_5.is_draft = false
        @batch_students = @drafts_page.unique_students_in_batch([@test_student], [@cohort], [@curated_group])
      end

      it 'saves the new note with multiple students' do
        expected_sids = @batch_students.map(&:sis_id).sort
        actual_sids = BOACUtils.get_note_sids_by_subject @note_5
        missing = expected_sids - actual_sids
        unexpected = actual_sids - expected_sids
        @drafts_page.wait_until(Utils.short_wait, "Missing: #{missing}, unexpected: #{unexpected}") do
          missing.empty?
          unexpected.empty?
        end
      end

      it 'removes the draft from list view' do
        expect(@drafts_page.draft_note_row(@note_5).exists?).to be false
      end

      it 'saves the new note with the right content' do
        @batch_students.first(2).each do |student|
          @student_page.set_new_note_id(@note_5, student)
          @student_page.load_page student
          @student_page.expand_item @note_5
          @student_page.verify_note(@note_5, @test.advisor)
        end
      end
    end
  end

  describe 'deletion' do

    context 'by the author' do

      it 'can be done on the student page' do
        @student_page.load_page @test_student
        @student_page.show_notes
        @student_page.expand_item @note_6
        expect(@student_page.delete_note_button(@note_6).visible?).to be true
      end

      it 'can be done but canceled on the note drafts page' do
        @student_page.click_draft_notes
        @drafts_page.wait_for_draft_note_row @note_6
        @drafts_page.click_delete_draft @note_6
        @drafts_page.cancel_delete_draft
      end

      it 'can be done and confirmed on the note drafts page' do
        @drafts_page.click_delete_draft @note_6
        @drafts_page.confirm_delete_draft
        expect(@drafts_page.visible_draft_note_ids).not_to include(@note_6.id)
      end
    end

    context 'by an admin user' do

      before(:all) do
        @drafts_page.log_out
        @homepage.dev_auth
      end

      it 'can be done on the student page' do
        @student_page.load_page @test_student
        @student_page.show_notes
        @student_page.expand_item @note_1
        @student_page.delete_note @note_1
        expect(@student_page.visible_collapsed_note_ids).not_to include(@note_1.id)
      end

      it 'can be done but canceled on the note drafts page' do
        @student_page.click_draft_notes
        @drafts_page.wait_for_draft_note_row @note_3
        @drafts_page.click_delete_draft @note_3
        @drafts_page.cancel_delete_draft
      end

      it 'can be done and confirmed on the note drafts page' do
        @drafts_page.click_delete_draft @note_3
        @drafts_page.confirm_delete_draft
        expect(@drafts_page.visible_draft_note_ids).not_to include(@note_3.id)
      end
    end
  end
end
