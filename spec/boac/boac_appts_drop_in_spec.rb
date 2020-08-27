require_relative '../../util/spec_helper'

include Logging

describe 'BOA' do

  before(:all) do
    dept = BOACDepartments::DEPARTMENTS.find { |d| d.code == BOACUtils.appts_drop_in_dept }
    @other_dept = BOACDepartments::DEPARTMENTS.find { |d| ![dept, BOACDepartments::ADMIN].include? d }
    authorized_users = BOACUtils.get_authorized_users
    @test = BOACTestConfig.new
    @test.drop_in_appts(authorized_users, dept)

    @students = @test.students.shuffle[0..20]
    inactive_sid = (NessieUtils.hist_profile_sids_of_career_status('Inactive') - BOACUtils.manual_advisee_sids).first
    @inactive_student = NessieUtils.get_hist_student inactive_sid
    completed_sid = (NessieUtils.hist_profile_sids_of_career_status('Completed') - BOACUtils.manual_advisee_sids).first
    @completed_student = NessieUtils.get_hist_student completed_sid

    @appts = []
    @appt_0 = Appointment.new(student: @students[0], topics: [Topic::COURSE_ADD, Topic::COURSE_DROP], detail: "Drop-in advisor appointment creation #{@test.id}")
    @appt_1 = Appointment.new(student: @students[1], reserve_advisor: @test.drop_in_advisor, topics: [Topic::RETROACTIVE_ADD, Topic::RETROACTIVE_DROP], detail: "Drop-in appointment details #{@test.id}")
    @appt_2 = Appointment.new(student: @students[2], topics: [Topic::PROBATION], detail: "Scheduler check-in 1 #{@test.id}")
    @appt_3 = Appointment.new(student: @students[3], topics: [Topic::PROBATION], detail: "Drop-in advisor waiting list check-in 1 #{@test.id}")
    @appt_4 = Appointment.new(student: @students[4], topics: [Topic::READMISSION], detail: "Scheduler cancel #{@test.id}")
    @appt_5 = Appointment.new(student: @students[5], topics: [Topic::WITHDRAWAL], detail: "Drop-in advisor waiting list cancel #{@test.id}")
    @appt_6 = Appointment.new(student: @students[6], topics: [Topic::OTHER], detail: "Drop-in advisor student page cancel #{@test.id}")
    @appt_7 = Appointment.new(student: @students[7], topics: [Topic::COURSE_ADD, Topic::COURSE_DROP], detail: "Scheduler no-reservation appointment creation #{@test.id} detail")
    @appt_8 = Appointment.new(student: @inactive_student, reserve_advisor: @test.drop_in_advisor, topics: [Topic::COURSE_ADD], detail: "Scheduler reservation appointment creation #{@test.id} detail")
    @appt_9 = Appointment.new(student: @completed_student, detail: 'Some detail')
    @appt_10 = Appointment.new(student: @students[8], topics: [Topic::COURSE_DROP], detail: "Reserved 1 #{@test.id}", reserve_advisor: @test.drop_in_advisor)
    @appt_11 = Appointment.new(student: @students[9], topics: [Topic::COURSE_DROP], detail: "Reserved 2 #{@test.id}", reserve_advisor: @test.drop_in_advisor)
    @resolved_issue = Appointment.new(student: @students[10], topics: [Topic::COURSE_ADD], detail: "A resolved issue #{@test.id}")

    @driver_scheduler = Utils.launch_browser
    @scheduler_homepage = BOACHomePage.new @driver_scheduler
    @scheduler_intake_desk = BOACApptIntakeDeskPage.new @driver_scheduler
    @scheduler_flight_deck = BOACFlightDeckPage.new @driver_scheduler

    @driver_advisor = Utils.launch_browser
    @pax_manifest = BOACPaxManifestPage.new @driver_advisor
    @advisor_homepage = BOACHomePage.new @driver_advisor
    @advisor_appt_desk = BOACApptIntakeDeskPage.new @driver_advisor
    @advisor_student_page = BOACStudentPage.new @driver_advisor
    @search_results_page = BOACSearchResultsPage.new @driver_advisor
    @advisor_flight_deck = BOACFlightDeckPage.new @driver_advisor

    # Configure users
    [@test.advisor, @test.drop_in_advisor].each { |u| BOACUtils.delete_drop_in_advisor u }
    @advisor_homepage.dev_auth
    @pax_manifest.load_page
    @pax_manifest.filter_mode_select_element.when_visible Utils.medium_wait
    @pax_manifest.search_for_and_edit_user @test.advisor
    @pax_manifest.search_for_and_edit_user @test.drop_in_advisor
    @pax_manifest.search_for_and_edit_user @test.drop_in_scheduler
    @pax_manifest.log_out

    @drop_in_advisors = BOACUtils.get_authorized_users.select do |a|
      a.dept_memberships.find { |r| r.dept == @test.dept && r.is_drop_in_advisor }
    end
  end

  after(:all) do
    Utils.quit_browser @driver_scheduler
    Utils.quit_browser @driver_advisor
  end

  ### PERMISSIONS - SCHEDULER

  context 'when the user is a scheduler' do

    before(:all) { @scheduler_homepage.dev_auth @test.drop_in_scheduler }

    it 'drops the user onto the drop-in intake desk at login' do
      expect(@scheduler_homepage.title).to include('Drop-in Appointments Desk')
      @scheduler_intake_desk.new_appt_button_element.when_visible Utils.short_wait
    end

    it 'prevents the user from accessing a drop-in intake desk belonging to another department' do
      @scheduler_intake_desk.load_page @other_dept
      @scheduler_intake_desk.wait_for_title 'Not Found'
    end

    it 'prevents the user from accessing a page other than the drop-in intake desk' do
      @scheduler_intake_desk.navigate_to "#{BOACUtils.base_url}/student/#{@students.first.uid}"
      @scheduler_intake_desk.wait_for_title 'Not Found'
    end

    # TODO user cannot get to any boa API endpoints other than drop-in endpoints
  end

  ### PERMISSIONS - DROP-IN ADVISOR

  context 'when the user is a drop-in advisor' do

    before(:all) do
      @advisor_homepage.dev_auth @test.drop_in_advisor
      @advisor_flight_deck.load_advisor_page
      @advisor_flight_deck.disable_drop_in_advising_role @test.drop_in_advisor.dept_memberships.first
      @advisor_flight_deck.enable_drop_in_advising_role @test.drop_in_advisor.dept_memberships.first
      @drop_in_advisors << @test.drop_in_advisor unless @drop_in_advisors.map(&:uid).include? @test.drop_in_advisor.uid
    end

    after(:all) { @advisor_homepage.log_out }

    it 'drops the user onto the homepage at login with a waiting list' do
      @advisor_homepage.load_page
      expect(@advisor_homepage.title).to include('Home')
      @advisor_homepage.new_appt_button_element.when_visible Utils.short_wait
    end

    it 'prevents the user from accessing the department drop-in intake desk' do
      @advisor_appt_desk.load_page @test.dept
      @advisor_appt_desk.wait_for_title 'Page not found'
    end

    it 'prevents the user from accessing a drop-in intake desk belonging to another department' do
      @advisor_appt_desk.load_page @other_dept
      @advisor_appt_desk.wait_for_title 'Page not found'
    end
  end

  ### PERMISSIONS - NON-DROP-IN ADVISOR

  context 'when the user is a non-drop-in advisor' do

    before(:all) { @advisor_homepage.dev_auth @test.advisor }
    after(:all) { @advisor_homepage.log_out }

    it 'drops the user onto the homepage at login with no waiting list' do
      expect(@advisor_homepage.title).to include('Home')
      sleep 2
      expect(@advisor_homepage.new_appt_button?).to be false
    end

    it 'prevents the user from accessing the department drop-in intake desk' do
      @advisor_appt_desk.load_page @test.dept
      @advisor_appt_desk.wait_for_title 'Page not found'
    end
  end

  ### PERMISSIONS - ADMIN

  context 'when the user is an admin' do

    before(:all) { @advisor_homepage.dev_auth }
    after(:all) { @advisor_homepage.log_out }

    it 'drops the user onto the homepage at login with no waiting list' do
      expect(@advisor_homepage.title).to include('Home')
      sleep 2
      expect(@advisor_homepage.new_appt_button?).to be false
    end

    it 'allows the user to access any department\'s drop-in intake desk' do
      @advisor_appt_desk.load_page @test.dept
      @advisor_appt_desk.wait_for_title 'Drop-in Appointments Desk'
      @advisor_appt_desk.load_page @other_dept
      @advisor_appt_desk.wait_for_title 'Drop-in Appointments Desk'
    end
  end

  ### ADVISOR AVAILABILITY ###

  describe 'drop-in advisor availability' do

    context 'on the intake desk' do

      before(:all) { @scheduler_intake_desk.load_page @test.dept }
      after(:all) { @scheduler_intake_desk.hit_escape }

      it 'is shown for only drop-in advisors' do
        @scheduler_intake_desk.new_appt_button_element.when_visible Utils.short_wait
        expect(@scheduler_intake_desk.drop_in_advisor_uids.sort).to eql(@drop_in_advisors.map(&:uid).sort)
      end

      it('allows a scheduler to set a drop-in advisor to "unavailable"') { @scheduler_intake_desk.set_advisor_unavailable @test.drop_in_advisor }

      it 'shows no unavailable advisors when making an appointment with a reservation' do
        @scheduler_intake_desk.click_new_appt
        expect(@scheduler_intake_desk.available_appt_advisor_uids).not_to include(@test.drop_in_advisor.uid)
      end

      it 'allows a scheduler to set a drop-in advisor to "available"' do
        @scheduler_intake_desk.hit_escape
        @scheduler_intake_desk.set_advisor_available @test.drop_in_advisor
      end

      it 'shows available advisors when making an appointment with a reservation' do
        @scheduler_intake_desk.click_new_appt
        @scheduler_intake_desk.wait_for_poller { @scheduler_intake_desk.available_appt_advisor_uids.include? @test.drop_in_advisor.uid }
      end
    end

    context 'on the waiting list' do

      before(:all) { @advisor_homepage.dev_auth @test.drop_in_advisor }

      it 'is shown for the logged-in drop-in advisor' do
        @advisor_homepage.new_appt_button_element.when_visible Utils.short_wait
        @advisor_homepage.wait_for_poller { @advisor_homepage.self_available? }
      end

      it('allows a drop-in advisor to set itself "unavailable"') { @advisor_homepage.set_self_unavailable }
      it('allows a drop-in advisor to set itself "available"') { @advisor_homepage.set_self_available }

      it 'is shown for only drop-in advisors' do
        @advisor_homepage.new_appt_button_element.when_visible Utils.short_wait
        expect(@advisor_homepage.visible_drop_in_advisors_and_status).to eql(BOACUtils.get_drop_in_advisors_and_status(@test.dept))
      end

      it 'does not allow a drop-in advisor to toggle another advisor\'s availability' do
        expect(@advisor_homepage.availability_toggle_button_elements.length).to eql(1)
      end
    end
  end

  ### ADVISOR STATUS ###

  describe 'drop-in advisor status' do

    context 'on the intake desk' do

      it 'cannot be set' do
        expect(@scheduler_intake_desk.status_clear_button?).to be false
        expect(@scheduler_intake_desk.status_save_button?).to be false
      end
    end

    context 'on the waiting list' do

      it 'can be set' do
        @advisor_homepage.create_status(@test.drop_in_advisor.dept_memberships.first, ("#{@test.id} drop-in advisor status" * 6))
        @advisor_homepage.wait_until(2) { @advisor_homepage.status == @test.drop_in_advisor.dept_memberships.first.drop_in_status }
      end

      it 'updates the intake desk when set' do
        @scheduler_intake_desk.wait_for_poller do
          @scheduler_intake_desk.intake_desk_advisor_status(@test.drop_in_advisor)&.include? @test.drop_in_advisor.dept_memberships.first.drop_in_status
        end
      end

      it 'can be cleared' do
        @advisor_homepage.clear_status @test.drop_in_advisor.dept_memberships.first
      end

      it 'updates the intake desk when cleared' do
        @scheduler_intake_desk.wait_for_poller { @scheduler_intake_desk.intake_desk_advisor_status(@test.advisor) == @test.advisor.dept_memberships.first.drop_in_status }
      end
    end
  end

  ### DROP-IN APPOINTMENT CREATION

  describe 'drop-in appointment creation' do

    # Scheduler

    context 'on the intake desk' do

      before(:all) do
        existing_appts = BOACUtils.get_today_drop_in_appts(@test.dept, @test.students).select { |a| !a.deleted_date }
        BOACUtils.delete_appts existing_appts
      end

      before(:each) { @scheduler_intake_desk.hit_escape }

      it 'shows a No Appointments message when there are no appointments' do
        @scheduler_intake_desk.empty_wait_list_msg_element.when_visible Utils.medium_wait
        expect(@scheduler_intake_desk.empty_wait_list_msg.strip).to eql('No appointments yet')
      end

      it 'allows a scheduler to create but cancel a new appointment' do
        @scheduler_intake_desk.click_new_appt
        @scheduler_intake_desk.click_cancel_new_appt
      end

      it 'requires a scheduler to select a student for a new appointment' do
        appt = Appointment.new(detail: 'Some detail')
        @scheduler_intake_desk.click_new_appt
        @scheduler_intake_desk.add_reasons(appt, [Topic::OTHER])
        @scheduler_intake_desk.enter_detail appt
        expect(@scheduler_intake_desk.make_appt_button_element.disabled?).to be true
        @scheduler_intake_desk.choose_appt_student @test.students.first
        expect(@scheduler_intake_desk.make_appt_button_element.disabled?).to be false
      end

      it 'requires a scheduler to select a reason for a new appointment' do
        appt = Appointment.new(detail: 'Some detail')
        @scheduler_intake_desk.click_new_appt
        @scheduler_intake_desk.choose_appt_student @test.students.first
        @scheduler_intake_desk.enter_detail appt
        expect(@scheduler_intake_desk.make_appt_button_element.disabled?).to be true
        @scheduler_intake_desk.add_reasons(appt,[Topic::OTHER])
        @scheduler_intake_desk.wait_until(2) { !@scheduler_intake_desk.make_appt_button_element.disabled? }
      end

      it 'allows a scheduler to select an available advisor for a new reserved appointment' do
        @scheduler_intake_desk.click_new_appt
        @scheduler_intake_desk.wait_until(1) { @scheduler_intake_desk.available_appt_advisor_uids.sort.include? @test.drop_in_advisor.uid }
      end

      it 'shows a scheduler the right reasons for a new appointment' do
        @scheduler_intake_desk.click_new_appt
        expected_topics = Topic::TOPICS.select(&:for_appts).map &:name
        @scheduler_intake_desk.wait_until(1, "Expected #{expected_topics}, got #{@scheduler_intake_desk.available_appt_reasons}") do
          @scheduler_intake_desk.available_appt_reasons == expected_topics
        end
      end

      it 'requires a scheduler to enter details for a new appointment' do
        @scheduler_intake_desk.click_new_appt
        @scheduler_intake_desk.choose_appt_student @test.students.first
        @scheduler_intake_desk.add_reasons(@appt_9, [Topic::OTHER])
        expect(@scheduler_intake_desk.make_appt_button_element.disabled?).to be true
        @scheduler_intake_desk.enter_detail @appt_9
        @scheduler_intake_desk.wait_until(3) { !@scheduler_intake_desk.make_appt_button_element.disabled? }
      end

      it 'allows a scheduler to create a new unreserved appointment' do
        @scheduler_intake_desk.click_new_appt
        @scheduler_intake_desk.create_appt @appt_7
        expect(@appt_7.id).not_to be_nil
      end

      it 'allows a scheduler to create a new reserved apppointment' do
        @scheduler_intake_desk.click_new_appt
        @scheduler_intake_desk.create_appt @appt_8
        expect(@appt_8.id).not_to be_nil
        expect(@scheduler_intake_desk.visible_list_view_appt_data(@appt_8)[:reserved_by]).not_to be_nil
      end

      it 'prevents a scheduler from creating a new appointment for a student with an existing pending appointment' do
        @scheduler_intake_desk.wait_for_poller { @scheduler_intake_desk.visible_appt_ids.include? @appt_8.id }
        @scheduler_intake_desk.click_new_appt
        @scheduler_intake_desk.choose_appt_student @appt_8.student
        @scheduler_intake_desk.student_double_booking_msg_element.when_visible 3
      end
    end

    # Drop-in Advisor

    context 'on the waiting list' do

      before(:all) do
        existing_appts = BOACUtils.get_today_drop_in_appts(@test.dept, @test.students)
        BOACUtils.delete_appts existing_appts
      end

      before(:each) { @advisor_homepage.hit_escape }

      it 'shows a No Appointments message when there are no appointments' do
        @advisor_homepage.empty_wait_list_msg_element.when_visible Utils.medium_wait
        expect(@advisor_homepage.empty_wait_list_msg.strip).to eql('No appointments yet')
      end

      it 'updates the scheduler appointment desk with a No Appointments message when there are no appointments' do
        @scheduler_intake_desk.wait_for_poller { @scheduler_intake_desk.empty_wait_list_msg? }
      end

      it 'allows a drop-in advisor to create but cancel a new appointment' do
        @advisor_homepage.click_new_appt
        @advisor_homepage.click_cancel_new_appt
      end

      it 'requires a drop-in advisor to select a student for a new appointment' do
        appt = Appointment.new(detail: 'Some detail')
        @advisor_homepage.click_new_appt
        @advisor_homepage.add_reasons(appt,[Topic::OTHER])
        @advisor_homepage.enter_detail appt
        expect(@advisor_homepage.make_appt_button_element.disabled?).to be true
        @advisor_homepage.choose_appt_student @test.students.first
        expect(@advisor_homepage.make_appt_button_element.disabled?).to be false
      end

      it 'requires a drop-in advisor to select a reason for a new appointment' do
        appt = Appointment.new(detail: 'Some detail')
        @advisor_homepage.click_new_appt
        @advisor_homepage.choose_appt_student @test.students.first
        @advisor_homepage.enter_detail appt
        expect(@advisor_homepage.make_appt_button_element.disabled?).to be true
        @advisor_homepage.add_reasons(appt, [Topic::OTHER])
        expect(@advisor_homepage.make_appt_button_element.disabled?).to be false
      end

      it 'shows a drop-in advisor the right reasons for a new appointment' do
        @advisor_homepage.click_new_appt
        expected_topics = Topic::TOPICS.select(&:for_appts).map &:name
        @advisor_homepage.wait_until(1, "Expected #{expected_topics}, got #{@advisor_homepage.available_appt_reasons}") do
          @advisor_homepage.available_appt_reasons == expected_topics
        end
      end

      it 'requires a drop-in advisor to enter details for a new appointment' do
        appt = Appointment.new(detail: 'Some detail')
        @advisor_homepage.click_new_appt
        @advisor_homepage.choose_appt_student @test.students.first
        @advisor_homepage.add_reasons(appt, [Topic::OTHER])
        expect(@advisor_homepage.make_appt_button_element.disabled?).to be true
        @advisor_homepage.enter_detail appt
        @advisor_homepage.wait_until(Utils.short_wait) { !@advisor_homepage.make_appt_button_element.disabled? }
      end

      it 'allows a drop-in advisor to create a new appointment' do
        @advisor_homepage.click_new_appt
        @advisor_homepage.create_appt @appt_0
        expect(@appt_0.id).not_to be_nil
        @appts << @appt_0
      end

      it 'updates the scheduler appointment desk when a new appointment is created' do
        @scheduler_intake_desk.wait_for_poller { @scheduler_intake_desk.visible_appt_ids.include? @appt_0.id }
      end

      it 'prevents a drop-in advisor from creating a new appointment for a student with an existing pending appointment' do
        @advisor_homepage.click_new_appt
        @advisor_homepage.choose_appt_student @appt_0.student
        @advisor_homepage.student_double_booking_msg_element.when_visible 3
      end
    end
  end

  describe 'appointment search' do

    before(:all) do
      @advisor_homepage.hit_escape
      @advisor_homepage.expand_search_options
      @advisor_homepage.uncheck_include_students_cbx
      @advisor_homepage.uncheck_include_classes_cbx
    end

    it 'can find a newly created appointment by its description' do
      @advisor_homepage.type_note_appt_string_and_enter @appt_0.detail
      @search_results_page.wait_for_appt_search_result_rows
      expect(@search_results_page.appt_link(@appt_0).exists?).to be true
    end

    it 'cannot find a deleted appointment by its description' do
      @advisor_homepage.type_note_appt_string_and_enter @appt_7.detail
      expect(@search_results_page.appt_results_count).to be_zero
    end
  end

  ### DROP-IN APPOINTMENT DETAILS

  describe '"waiting" drop-in appointment details' do

    # Scheduler

    context 'on the appointment intake desk' do

      before(:all) do
        @scheduler_intake_desk.hit_escape
        @scheduler_intake_desk.click_new_appt
        @scheduler_intake_desk.create_appt @appt_1
        @appts << @appt_1
        @scheduler_intake_desk.wait_until(Utils.short_wait) { @scheduler_intake_desk.visible_appt_ids.include? @appt_1.id }
        @visible_list_view_appt_data = @scheduler_intake_desk.visible_list_view_appt_data @appt_1
      end

      after(:all) { @scheduler_intake_desk.hit_escape }

      it('show the arrival time') { expect(@visible_list_view_appt_data[:created_date]).to eql(@scheduler_intake_desk.appt_time_created_format(@appt_1.created_date).strip) }
      it('show the student name') { expect(@visible_list_view_appt_data[:student_non_link_name]).to eql(@appt_1.student.full_name) }
      it('show no link to the student page') { expect(@visible_list_view_appt_data[:student_link_name]).to be_nil }
      it('show the student SID') { expect(@visible_list_view_appt_data[:student_sid]).to eql(@appt_1.student.sis_id) }
      it('show the appointment reason(s)') { expect(@visible_list_view_appt_data[:topics]).to eql(@appt_1.topics.map { |t| t.name.downcase }.sort) }

      it('allow the scheduler to expand an appointment\'s details') { @scheduler_intake_desk.view_appt_details @appt_1 }
      it('show the student name') { expect(@scheduler_intake_desk.details_student_name).to eql(@appt_1.student.full_name) }
      it('show the appointment reason(s)') { expect(@scheduler_intake_desk.appt_reasons.sort).to eql(@appt_1.topics.map { |t| t.name.downcase }.sort) }
      it('show the arrival time') { expect(@scheduler_intake_desk.modal_created_at).to eql(@scheduler_intake_desk.appt_time_created_format(@appt_1.created_date).strip) }
    end

    # Drop-in Advisor

    context 'on the waiting list' do

      before(:all) do
        @advisor_homepage.load_page
        @advisor_homepage.wait_until(Utils.short_wait) { @scheduler_homepage.visible_appt_ids.any? }
        @visible_list_view_appt_data = @advisor_homepage.visible_list_view_appt_data @appt_1
      end

      after(:all) { @advisor_homepage.hit_escape }

      it('show the arrival time') { expect(@visible_list_view_appt_data[:created_date]).to eql(@advisor_homepage.appt_time_created_format(@appt_1.created_date).strip) }
      it('show the student name') { expect(@visible_list_view_appt_data[:student_link_name]).to eql(@appt_1.student.full_name) }
      it('show the student SID') { expect(@visible_list_view_appt_data[:student_sid]).to eql(@appt_1.student.sis_id) }
      it('show the appointment reason(s)') { expect(@visible_list_view_appt_data[:topics]).to eql(@appt_1.topics.map { |t| t.name.downcase }.sort) }

      it('allow the drop-in advisor to expand an appointment\'s details') { @advisor_homepage.view_appt_details @appt_1 }
      it('show the student name') { expect(@advisor_homepage.details_student_name).to eql(@appt_1.student.full_name) }
      it('show the appointment reason(s)') { expect(@advisor_homepage.appt_reasons.sort).to eql(@appt_1.topics.map { |t| t.name.downcase }.sort) }
      it('show the arrival time') { expect(@advisor_homepage.modal_created_at).to eql(@advisor_homepage.appt_time_created_format(@appt_1.created_date).strip) }
    end

    context 'on the student page' do

      before(:all) do
        @advisor_homepage.click_student_link @appt_1
        @advisor_student_page.show_appts
        @advisor_student_page.wait_until(1) { @advisor_student_page.visible_message_ids.include? @appt_1.id }
      end

      context 'when collapsed' do

        before(:all) { @visible_collapsed_date = @advisor_student_page.visible_collapsed_appt_data @appt_1 }

        it('show the appointment detail') { expect(@visible_collapsed_date[:detail]).to eql(@appt_1.detail) }
        it('show the appointment status') { expect(@visible_collapsed_date[:status]).to eql('ASSIGNED') }
        it('show the appointment date') { expect(@visible_collapsed_date[:created_date].split("\n")[1]).to eql(@advisor_student_page.expected_item_short_date_format(@appt_1.created_date)) }
      end

      context 'when expanded' do

        before(:all) do
          @advisor_student_page.expand_item @appt_1
          @visible_expanded_data = @advisor_student_page.visible_expanded_appt_data @appt_1
        end

        it('show the appointment detail') { expect(@visible_expanded_data[:detail]).to eql(@appt_1.detail) }
        it('show the appointment date') { expect(@visible_expanded_data[:created_date]).to eql(@advisor_student_page.expected_item_short_date_format @appt_1.created_date) }
        it('show the appointment check-in button') { expect(@advisor_student_page.check_in_button(@appt_1).exists?).to be true }
        it('show no appointment check-in time') { expect(@visible_expanded_data[:check_in_time]).to be_nil }
        it('show no appointment cancel reason') { expect(@visible_expanded_data[:cancel_reason]).to be_nil }
        it('show no appointment cancel additional info') { expect(@visible_expanded_data[:cancel_addl_info]).to be_nil }
        it('show no appointment advisor') { expect(@visible_expanded_data[:advisor_name]).to be_nil }
        it('show the appointment type') { expect(@visible_expanded_data[:type]).to eql('Drop-in') }
        it('show the appointment reasons') { expect(@visible_expanded_data[:topics]).to eql(@appt_1.topics.map { |t| t.name.upcase }.sort) }
      end
    end
  end

  ### DROP-IN APPOINTMENT ASSIGNMENTS

  describe 'drop-in appointment assignment' do

    # Scheduler

    context 'on the appointment intake desk' do

      after(:all) { @scheduler_intake_desk.hit_escape }

      it 'allows the scheduler to un-reserve a reserved appointment' do
        @scheduler_intake_desk.hit_escape
        @scheduler_intake_desk.click_unreserve_appt_button @appt_1
        @scheduler_intake_desk.reserved_for_el(@appt_1).when_not_present Utils.short_wait
        @appt_1.reserve_advisor = nil
      end

      it 'allows the scheduler to reserve an unreserved appointment' do
        @scheduler_intake_desk.hit_escape
        @scheduler_intake_desk.reserve_appt_for_advisor(@appt_1, @test.drop_in_advisor)
        @scheduler_intake_desk.wait_for_poller { @scheduler_intake_desk.reserved_for_el(@appt_1).visible? }
        @appt_1.reserve_advisor = @test.drop_in_advisor
      end
    end

    # Drop-in Advisor

    context 'on the waiting list' do

      before(:all) do
        @advisor_homepage.load_page
        @advisor_homepage.wait_until(Utils.short_wait) { @scheduler_homepage.visible_appt_ids.any? }
        @visible_list_view_appt_data = @advisor_homepage.visible_list_view_appt_data @appt_1
      end

      after(:all) { @advisor_homepage.hit_escape }

      it 'allow the drop-in advisor to un-reserve an appointment' do
        @advisor_homepage.hit_escape
        @advisor_homepage.click_unreserve_appt_button @appt_1
        @advisor_homepage.wait_for_poller { !@advisor_homepage.reserved_for_el(@appt_1).exists? }
        @appt_1.reserve_advisor = nil
      end

      it 'allow the drop-in advisor to reserve an appointment' do
        @advisor_homepage.reserve_appt_for_advisor(@appt_1, @test.drop_in_advisor)
        @advisor_homepage.reserved_for_el(@appt_1).when_visible 3
        expect(@advisor_homepage.reserved_for_el(@appt_1).text).to eql('Assigned to you')
        @appt_1.reserve_advisor = @test.drop_in_advisor
      end
    end

    context 'on the student page' do

      before(:all) do
        @advisor_homepage.click_student_link @appt_1
        @advisor_student_page.show_appts
        @advisor_student_page.wait_until(1) { @advisor_student_page.visible_message_ids.include? @appt_1.id }
        @advisor_student_page.expand_item @appt_1
      end

      it 'allow the drop-in advisor to unreserve the appointment' do
        @advisor_student_page.click_unreserve_appt_button @appt_1
        @advisor_student_page.reserved_for_el(@appt_1).when_not_present 3
      end

      it 'show Waiting status on the unreserved appointment' do
        @advisor_student_page.collapse_item @appt_1
        @advisor_student_page.wait_until(3) { @advisor_student_page.visible_collapsed_appt_data(@appt_1)[:status] == 'WAITING' }
      end

      it 'allow the drop-in advisor to reserve the appointment' do
        @advisor_student_page.expand_item @appt_1
        @advisor_student_page.reserve_appt_for_advisor(@appt_1, @test.drop_in_advisor)
        @advisor_student_page.reserved_for_el(@appt_1).when_visible 3
      end

      it 'show Reserved status on the reserved appointment' do
        @advisor_student_page.collapse_item @appt_1
        @advisor_student_page.wait_until(3) { @advisor_student_page.visible_collapsed_appt_data(@appt_1)[:status] == 'ASSIGNED' }
      end
    end
  end

  ### DROP-IN APPOINTMENT UPDATES

  describe 'drop-in appointment updating' do

    # Scheduler

    context 'on the intake desk' do

      it 'allows the scheduler to cancel an edit' do
        @scheduler_intake_desk.view_appt_details @appt_1
        @scheduler_intake_desk.click_close_details_button
        @scheduler_intake_desk.modal_student_name_element.when_not_visible 2
      end

      it 'allows the scheduler to remove reasons' do
        @scheduler_intake_desk.hit_escape
        @scheduler_intake_desk.view_appt_details @appt_1
        @scheduler_intake_desk.remove_reasons(@appt_1, @appt_1.topics)
        expect(@scheduler_intake_desk.appt_reasons).to be_empty
        expect(@scheduler_intake_desk.details_update_button_element.enabled?).to be false
      end

      it 'allows the scheduler to add reasons' do
        @scheduler_intake_desk.add_reasons(@appt_1, [Topic::READMISSION, Topic::SAP])
        expect(@scheduler_intake_desk.appt_reasons.sort).to eql(@appt_1.topics.map { |t| t.name.downcase }.sort)
        expect(@scheduler_intake_desk.details_update_button_element.enabled?).to be true
      end

      it 'allows the scheduler to edit additional info' do
        @appt_1.detail = "#{@appt_1.detail} - edited by scheduler"
        @scheduler_intake_desk.enter_detail @appt_1
      end

      it 'allows the scheduler to save an edit' do
        @scheduler_intake_desk.click_details_update_button
        @scheduler_intake_desk.wait_until(Utils.short_wait) { @scheduler_intake_desk.visible_list_view_appt_data(@appt_1)[:topics] == (@appt_1.topics.map { |t| t.name.downcase }.sort) }
      end
    end

    # Drop-in Advisor

    context 'on the waiting list' do

      it 'allows the drop-in advisor to cancel an edit' do
        @advisor_homepage.load_page
        @advisor_homepage.view_appt_details @appt_1
        @advisor_homepage.click_close_details_button
        @advisor_homepage.modal_student_name_element.when_not_visible 2
      end

      it 'allows the drop-in advisor to remove reasons' do
        @advisor_homepage.hit_escape
        @advisor_homepage.view_appt_details @appt_1
        @advisor_homepage.remove_reasons(@appt_1, @appt_1.topics)
        expect(@advisor_homepage.appt_reasons).to be_empty
        expect(@advisor_homepage.details_update_button_element.enabled?).to be false
      end

      it 'allows the drop-in advisor to add reasons' do
        @advisor_homepage.add_reasons(@appt_1, [Topic::RETROACTIVE_ADD, Topic::RETROACTIVE_DROP])
        expect(@advisor_homepage.appt_reasons).to eql(@appt_1.topics.map { |t| t.name.downcase }.sort)
        expect(@advisor_homepage.details_update_button_element.enabled?).to be true
      end

      it 'allows the drop-in advisor to edit additional info' do
        @appt_1.detail = "#{@appt_1.detail} - edited by advisor"
        @advisor_homepage.enter_detail @appt_1
      end

      it 'allows the drop-in advisor to save an edit' do
        @advisor_homepage.click_details_update_button
        @advisor_homepage.wait_until(Utils.short_wait) { @advisor_homepage.visible_list_view_appt_data(@appt_1)[:topics] == (@appt_1.topics.map { |t| t.name.downcase }.sort) }
      end
    end
  end

  describe 'appointment search' do

    before(:all) do
      @advisor_homepage.hit_escape
      @advisor_homepage.expand_search_options
      @advisor_homepage.uncheck_include_students_cbx
      @advisor_homepage.uncheck_include_classes_cbx
    end

    it 'can find a newly updated appointment by its description' do
      @advisor_homepage.type_note_appt_string_and_enter @appt_1.detail
      @search_results_page.wait_for_appt_search_result_rows
      expect(@search_results_page.appt_link(@appt_1).exists?).to be true
    end
  end

  ### DROP-IN APPOINTMENT CHECK-IN

  describe 'drop-in appointment checkin' do

    # Scheduler

    context 'on the intake desk' do

      before(:all) do
        @scheduler_intake_desk.click_new_appt
        @scheduler_intake_desk.create_appt @appt_2
        @appts << @appt_2
      end

      it 'requires that a scheduler select a drop-in advisor for the appointment' do
        @scheduler_intake_desk.click_appt_check_in_button @appt_2
        @scheduler_intake_desk.modal_check_in_button_element.when_present 1
        expect(@scheduler_intake_desk.modal_check_in_button_element.disabled?).to be true
        @scheduler_intake_desk.select_check_in_advisor @test.drop_in_advisor
        expect(@scheduler_intake_desk.modal_check_in_button_element.disabled?).to be false
      end

      it 'offers available drop-in advisors as advisor for the appointment' do
        expect(@scheduler_intake_desk.check_in_advisors.sort).to include(@test.drop_in_advisor.uid)
      end

      it 'can be done from the intake desk view' do
        @scheduler_intake_desk.select_check_in_advisor @test.drop_in_advisor
        @scheduler_intake_desk.click_modal_check_in_button
        @appt_2.status = AppointmentStatus::CHECKED_IN
        @appt_2.advisor = @test.drop_in_advisor
      end

      it 'removes the appointment from the intake desk list' do
        @scheduler_intake_desk.wait_until(Utils.short_wait) { !@scheduler_intake_desk.visible_appt_ids.include? @appt_2.id }
      end
    end

    # Drop-in Advisor

    context 'on the waiting list' do

      before(:all) do
        @advisor_student_page.click_home
        @advisor_homepage.click_new_appt
        @advisor_homepage.create_appt @appt_3
        @appts << @appt_3
      end

      it 'can be done from the list view' do
        @advisor_homepage.click_appt_check_in_button @appt_3
        @advisor_homepage.select_check_in_advisor @test.drop_in_advisor
        @advisor_homepage.click_modal_check_in_button
        @appt_3.status = AppointmentStatus::CHECKED_IN
        @appt_3.advisor = @test.drop_in_advisor
      end

      it 'updates the status of the appointment on the waiting list' do
        @advisor_homepage.wait_for_poller do
          visible_data = @advisor_homepage.visible_list_view_appt_data(@appt_3)
          visible_data[:checked_in_status] && visible_data[:checked_in_status].include?('CHECKED IN')
        end
      end

      it 'updates the scheduler appointment desk view dynamically' do
        @scheduler_intake_desk.wait_for_poller { (@scheduler_intake_desk.visible_appt_ids & [@appt_3.id]).empty? }
      end

      it('can be undone') { @advisor_homepage.undo_appt_check_in @appt_3 }
      it('updates the status of the appointment once undone') { @advisor_homepage.check_in_button(@appt_3).when_visible Utils.short_wait }

      it 'updates the scheduler appointment desk view dynamically once undone' do
        @scheduler_intake_desk.wait_for_poller { @scheduler_intake_desk.visible_appt_ids.include? @appt_3.id }
      end
    end

    context 'on the student page' do

      context 'when the advisor is not a drop-in advisor' do

        before(:all) do
          @advisor_homepage.log_out
          @advisor_homepage.dev_auth @test.advisor
          @advisor_student_page.load_page @appt_3.student
        end

        after(:all) { @advisor_student_page.log_out }

        it 'cannot be done' do
          @advisor_student_page.show_appts
          @advisor_student_page.expand_item @appt_3
          expect(@advisor_student_page.check_in_button(@appt_3).exists?).to be false
        end
      end

      context 'when the advisor is a drop-in advisor' do

        before(:all) do
          @advisor_homepage.dev_auth @test.drop_in_advisor
          @advisor_student_page.click_student_link @appt_3
          @advisor_student_page.show_appts
          @advisor_student_page.expand_item @appt_3
        end

        it 'can be done' do
          @advisor_student_page.click_check_in_button @appt_3
          @advisor_student_page.select_check_in_advisor @test.drop_in_advisor
          @advisor_student_page.click_modal_check_in_button
          @advisor_student_page.wait_until(Utils.short_wait) { @advisor_student_page.visible_expanded_appt_data(@appt_3)[:check_in_time] }
          @appt_3.status = AppointmentStatus::CHECKED_IN
          @appt_3.advisor = @test.drop_in_advisor
        end

        it 'updates the scheduler appointment desk view dynamically' do
          @scheduler_intake_desk.wait_for_poller { !@scheduler_intake_desk.visible_appt_ids.include? @appt_3.id }
        end
      end
    end
  end

  ### DROP-IN APPOINTMENT CANCELLATION

  describe 'drop-in appointment cancellation' do

    before(:all) do
      @advisor_student_page.click_home
      [@appt_4, @appt_5, @appt_6].each do |appt|
        @advisor_homepage.click_new_appt
        @advisor_homepage.create_appt appt
        @appts << appt
      end
    end

    # Scheduler

    context 'on the appointment intake desk' do

      before(:all) { @scheduler_intake_desk.wait_for_poller { @scheduler_intake_desk.visible_appt_ids.include? @appt_4.id } }

      it 'requires a reason' do
        @scheduler_intake_desk.click_appt_dropdown_button @appt_4
        @scheduler_intake_desk.click_cancel_appt_button @appt_4
        expect(@scheduler_intake_desk.cancel_confirm_button_element.disabled?).to be true
        @appt_4.cancel_reason = 'Cancelled by student'
        @scheduler_intake_desk.select_cancel_reason @appt_4
        expect(@scheduler_intake_desk.cancel_confirm_button_element.disabled?).to be false
      end

      it 'accepts additional info' do
        @appt_4.cancel_detail = "Some 'splainin' to do #{@test.id}"
        @scheduler_intake_desk.enter_cancel_explanation @appt_4
      end

      it 'can be done' do
        @scheduler_intake_desk.click_cancel_confirm_button
        @appt_4.status = AppointmentStatus::CANCELED
      end

      it 'removes the appointment from the list' do
        @scheduler_intake_desk.wait_until(Utils.short_wait) { !@scheduler_intake_desk.visible_appt_ids.include? @appt_4.id }
      end
    end

    # Drop-in Advisor

    context 'on the waiting list' do

      it 'requires a reason' do
        @advisor_homepage.click_appt_dropdown_button @appt_5
        @advisor_homepage.click_cancel_appt_button @appt_5
        expect(@advisor_homepage.cancel_confirm_button_element.disabled?).to be true
        @appt_5.cancel_reason = 'Cancelled by department/advisor'
        @advisor_homepage.select_cancel_reason @appt_5
        expect(@advisor_homepage.cancel_confirm_button_element.disabled?).to be false
      end

      it 'accepts additional info' do
        @appt_5.cancel_detail = "Even more 'splainin' to do #{@test.id}"
        @advisor_homepage.enter_cancel_explanation @appt_5
      end

      it 'can be done' do
        @advisor_homepage.click_cancel_confirm_button
        @appt_5.status = AppointmentStatus::CANCELED
      end

      it 'updates the appointment status on the waiting list' do
        @advisor_homepage.wait_until(Utils.short_wait) do
          visible_data = @advisor_homepage.visible_list_view_appt_data @appt_5
          visible_data[:canceled_status] && visible_data[:canceled_status].include?('CANCELLED')
        end
      end

      it 'updates the scheduler appointment desk view dynamically' do
        @scheduler_intake_desk.wait_for_poller { !@scheduler_intake_desk.visible_appt_ids.include? @appt_4.id }
      end

      it('can be undone') { @advisor_homepage.undo_appt_cancel @appt_5 }
      it('updates the status of the appointment once undone') do
        @advisor_homepage.wait_for_poller { @advisor_homepage.check_in_button(@appt_5).visible? }
      end

      it 'updates the scheduler appointment desk view dynamically once undone' do
        @scheduler_intake_desk.wait_for_poller { @scheduler_intake_desk.visible_appt_ids.include? @appt_5.id }
      end
    end

    context 'on the student page' do

      before(:all) do
        @advisor_homepage.click_student_link @appt_6
        @advisor_student_page.show_appts
        @advisor_student_page.expand_item @appt_6
      end

      it 'requires a reason' do
        @advisor_student_page.click_appt_dropdown_button @appt_6
        @advisor_student_page.click_cancel_appt_button @appt_6
        expect(@advisor_student_page.cancel_confirm_button_element.disabled?).to be true
        @appt_6.cancel_reason = 'Cancelled by student'
        @advisor_student_page.select_cancel_reason @appt_6
        expect(@advisor_student_page.cancel_confirm_button_element.disabled?).to be false
      end

      it 'accepts additional info' do
        @appt_6.cancel_detail = "Too much 'splainin' to do #{@test.id}"
        @advisor_student_page.enter_cancel_explanation @appt_6
      end

      it 'can be done' do
        @advisor_student_page.click_cancel_confirm_button
        @advisor_student_page.wait_until(Utils.short_wait) do
          visible_data = @advisor_student_page.visible_expanded_appt_data @appt_6
          visible_data[:cancel_reason] == @appt_6.cancel_reason
          visible_data[:cancel_addl_info] == @appt_6.cancel_detail
        end
        @appt_6.status = AppointmentStatus::CANCELED
      end

      it 'updates the scheduler appointment desk view dynamically' do
        @scheduler_intake_desk.wait_for_poller { !@scheduler_intake_desk.visible_appt_ids.include? @appt_6.id }
      end
    end
  end

  describe 'appointment search' do

    before(:all) do
      @advisor_homepage.hit_escape
      @advisor_homepage.expand_search_options
      @advisor_homepage.uncheck_include_students_cbx
      @advisor_homepage.uncheck_include_classes_cbx
    end

    it 'can find a cancelled appointment by its cancellation detail' do
      @advisor_homepage.type_note_appt_string_and_enter @appt_4.cancel_detail
      @search_results_page.wait_for_appt_search_result_rows
      expect(@search_results_page.appt_link(@appt_4).exists?).to be true
    end
  end

  ### APPOINTMENT SORTING ###

  describe 'intake desk appointments' do

    it 'shows today\'s pending appointments sorted by creation time' do
      pending_appts = @appts.select { |a| a.status == AppointmentStatus::WAITING }.sort_by(&:created_date).map(&:id)
      expect(@scheduler_intake_desk.visible_appt_ids).to eql(pending_appts)
    end
  end

  describe 'drop-in advisor waiting list' do

    before(:all) do
      @advisor_student_page.click_home
      @advisor_homepage.wait_until(Utils.short_wait) { @advisor_homepage.visible_appt_ids.any? }
    end

    it 'shows all today\'s appointments sorted by creation time, with canceled and checked-in segregated at the bottom' do
      non_pending_appts = @appts.select{ |a| [AppointmentStatus::CANCELED, AppointmentStatus::CHECKED_IN].include? a.status }.sort_by(&:created_date)
      pending_appts = (@appts - non_pending_appts).sort_by(&:created_date)
      @advisor_homepage.wait_for_poller { @advisor_homepage.visible_appt_ids == ((pending_appts + non_pending_appts).map(&:id)) }
    end
  end

  describe 'student appointment timeline' do

    before(:all) do
      student = @students.last
      checked_in_appt = Appointment.new(student: student, topics: [Topic::COURSE_ADD], detail: "Checked-in #{@test.id}")
      canceled_appt = Appointment.new(student: student, topics: [Topic::COURSE_ADD], detail: "Canceled #{@test.id}", cancel_reason: 'Cancelled by student', cancel_detail: 'Foo')
      pending_appt = Appointment.new(student: student, topics: [Topic::COURSE_ADD], detail: "Pending #{@test.id}")

      @advisor_homepage.click_new_appt
      @advisor_homepage.create_appt checked_in_appt
      @advisor_homepage.click_appt_check_in_button checked_in_appt
      @advisor_homepage.select_check_in_advisor @test.drop_in_advisor
      @advisor_homepage.click_modal_check_in_button
      @advisor_homepage.wait_for_poller do
        visible_data = @advisor_homepage.visible_list_view_appt_data checked_in_appt
        visible_data[:checked_in_status] && visible_data[:checked_in_status].include?('CHECKED IN')
      end

      @advisor_homepage.click_new_appt
      @advisor_homepage.create_appt canceled_appt
      @advisor_homepage.click_appt_dropdown_button canceled_appt
      @advisor_homepage.click_cancel_appt_button canceled_appt
      @advisor_homepage.select_cancel_reason canceled_appt
      @advisor_homepage.enter_cancel_explanation canceled_appt
      @advisor_homepage.click_cancel_confirm_button
      @advisor_homepage.wait_for_poller do
        visible_data = @advisor_homepage.visible_list_view_appt_data canceled_appt
        visible_data[:canceled_status] && visible_data[:canceled_status].include?('CANCELLED')
      end

      @advisor_homepage.click_new_appt
      @advisor_homepage.create_appt pending_appt

      @advisor_homepage.click_student_link pending_appt
      @advisor_student_page.show_appts
      boa_appts = BOACUtils.get_student_appts(student, @test.students).reject &:deleted_date
      sis_appts = NessieUtils.get_sis_appts student
      @student_appts = boa_appts + sis_appts
    end

    it 'shows all non-deleted appointments sorted by creation time' do
      expect(@advisor_student_page.visible_collapsed_item_ids('appointment')).to eql(@student_appts.sort_by(&:created_date).reverse.map(&:id).uniq)
    end
  end

  ### ASSIGNMENTS REMOVED WHEN ADVISOR GOES OFF-DUTY ###

  describe 'drop-in advisor' do

    before(:all) do
      @advisor_homepage.load_page
      @advisor_homepage.click_new_appt
      @advisor_homepage.create_appt @appt_10
      @advisor_homepage.reserved_for_el(@appt_10).when_visible 2
    end

    it 'is warned that going off-duty will remove appointment assignments' do
      @advisor_homepage.click_self_availability_button
      @advisor_homepage.off_duty_confirm_button_element.when_visible 2
    end

    it 'can cancel going off-duty and keep appointment assignments' do
      @advisor_homepage.click_off_duty_cancel
      @advisor_homepage.reserved_for_el(@appt_10).when_visible 2
    end

    it 'loses appointment assignments when going off-duty' do
      @advisor_homepage.click_self_availability_button
      @advisor_homepage.click_off_duty_confirm
      @advisor_homepage.wait_for_poller { !@advisor_homepage.reserved_for_el(@appt_10).exists? }
    end

    it 'can assign an appointment to itself while off-duty' do
      @advisor_homepage.reserve_appt_for_advisor(@appt_10, @test.drop_in_advisor)
      @advisor_homepage.wait_for_poller { @advisor_homepage.reserved_for_el(@appt_10).visible? }
      expect(@advisor_homepage.reserved_for_el(@appt_10).text).to eql('Assigned to you')
    end
  end

  describe 'scheduler' do

    before(:all) { @scheduler_intake_desk.set_advisor_available @test.drop_in_advisor }

    it 'is warned that taking an advisor off-duty will remove appointment assignments' do
      @scheduler_intake_desk.wait_for_poller { @scheduler_intake_desk.reserved_for_el(@appt_10).exists? }
      @scheduler_intake_desk.click_advisor_availability_toggle @test.drop_in_advisor
      @scheduler_intake_desk.off_duty_confirm_button_element.when_visible 2
    end

    it 'can cancel taking an advisor off-duty and keep appointment assignments' do
      @scheduler_intake_desk.click_off_duty_cancel
      expect(@scheduler_intake_desk.reserved_for_el(@appt_10).exists?).to be true
    end

    it 'loses appointment assignments when taking an advisor off-duty' do
      @scheduler_intake_desk.click_advisor_availability_toggle @test.drop_in_advisor
      @scheduler_intake_desk.click_off_duty_confirm
      @scheduler_intake_desk.wait_for_poller { !@scheduler_intake_desk.reserved_for_el(@appt_10).exists? }
    end

    ### SCHEDULER - LOGGING RESOLVED ISSUE ###

    context 'when logging a resolved issue' do

      before(:all) { @resolved_issue = Appointment.new(student: @students[11], topics: [Topic::COURSE_ADD], detail: "A resolved issue #{@test.id}") }

      it 'creates a checked-in appointment with itself' do
        @scheduler_intake_desk.log_resolved_issue(@resolved_issue, @test.drop_in_scheduler)
        expect(@resolved_issue.id).not_to be_nil
      end

      it 'updates the waiting list with the checked-in appointment' do
        @advisor_homepage.wait_for_poller do
          visible_data = @advisor_homepage.visible_list_view_appt_data(@resolved_issue)
          visible_data[:checked_in_status] && visible_data[:checked_in_status].include?('CHECKED IN')
        end
      end

      it 'updates the student page with the checked-in appointment' do
        @advisor_student_page.load_page @resolved_issue.student
        @advisor_student_page.show_appts
        @advisor_student_page.expand_item @resolved_issue
        visible_data = @advisor_student_page.visible_expanded_appt_data @resolved_issue
        expect(visible_data[:advisor_role]).to include('Intake Desk')
      end
    end
  end

  ### SETTINGS PAGE - DROP-IN STATUS ###

  describe 'settings page' do

    before(:all) do
      @advisor_homepage.load_page
      @advisor_homepage.click_new_appt
      @advisor_homepage.create_appt @appt_11
    end

    context 'when the user is a scheduler' do

      it 'is offered in the header' do
        @scheduler_intake_desk.click_header_dropdown
        expect(@scheduler_intake_desk.settings_link?).to be false
      end

      it 'cannot be reached in its admin flavor' do
        @scheduler_flight_deck.load_page
        @scheduler_flight_deck.wait_for_title 'Not Found'
      end
    end

    context 'when the user is a drop-in advisor' do

      before(:all) do
        @advisor_homepage.click_settings_link
        @scheduler_intake_desk.load_page @test.dept
      end

      it 'allows the user to remove its drop-in advising role' do
        @advisor_flight_deck.disable_drop_in_advising_role @test.drop_in_advisor.dept_memberships.first
        @scheduler_intake_desk.wait_for_poller { !@scheduler_intake_desk.drop_in_advisor_uids.include?(@test.drop_in_advisor.uid) }
      end

      it 'removes the user\'s access to the waiting list' do
        @advisor_homepage.load_page
        sleep 1
        expect(@advisor_homepage.new_appt_button?).to be false
      end

      it 'removes the user\'s appointment assignments on the waiting list when the drop-in advising role is removed' do
        @scheduler_intake_desk.wait_for_poller { !@scheduler_intake_desk.visible_list_view_appt_data(@appt_11)[:reserved_by] }
      end

      it 'removes the user\'s appointment assignments on the student page when the drop-in advising role is removed' do
        @advisor_student_page.load_page @appt_11.student
        @advisor_student_page.show_appts
        @advisor_student_page.expand_item @appt_11
        expect(@advisor_student_page.visible_expanded_appt_data(@appt_11)[:reserve_advisor]).to be_nil
        expect(@advisor_student_page.check_in_button(@appt_11).exists?).to be false
      end

      it 'allows the user to enable its drop-in advising role' do
        @advisor_flight_deck.click_settings_link
        @advisor_flight_deck.enable_drop_in_advising_role @test.drop_in_advisor.dept_memberships.first
        @scheduler_intake_desk.wait_for_poller { @scheduler_intake_desk.drop_in_advisor_uids.include? @test.drop_in_advisor.uid }
      end

      it 'restores the user\'s access to the waiting list' do
        @advisor_homepage.load_page
        @advisor_homepage.new_appt_button_element.when_visible Utils.short_wait
      end
    end
  end
end
