require_relative '../../util/spec_helper'

describe 'The BOAC passenger manifest' do

  include Logging

  test = BOACTestConfig.new
  test.user_mgmt
  auth_users = BOACUtils.get_authorized_users
  non_admin_depts = BOACDepartments::DEPARTMENTS - [BOACDepartments::ADMIN, BOACDepartments::NOTES_ONLY]
  dept_advisors = non_admin_depts.map { |dept| {:dept => dept, :advisors => BOACUtils.get_dept_advisors(dept)} }

  before(:all) do
    # Initialize a user for the add/edit user tests
    @add_edit_user = BOACUser.new(
        uid: BOACUtils.config['test_add_edit_uid'],
        active: true,
        can_access_canvas_data: true,
        advisor_roles: [
            AdvisorRole.new(
                dept: BOACDepartments::L_AND_S,
                is_advisor: true,
                is_automated: true
            )
        ]
    )
    # Hard delete the add/edit user in case it's still lying around from a previous test run
    BOACUtils.hard_delete_auth_user @add_edit_user
    auth_users.delete_if { |u| u.uid == @add_edit_user.uid }

    @driver = Utils.launch_browser
    @homepage = BOACHomePage.new @driver
    @admin_page = BOACPaxManifestPage.new @driver
    @class_page = BOACClassListViewPage.new @driver
    @cohort_page = BOACFilteredCohortPage.new(@driver, @add_edit_user)
    @intake_desk_page = BOACApptIntakeDeskPage.new @driver

    @homepage.dev_auth
    @homepage.click_pax_manifest_link
    @admin_page.filter_mode_select_element.when_visible Utils.medium_wait
  end

  after(:all) do
    BOACUtils.hard_delete_auth_user @add_edit_user
    Utils.quit_browser @driver
  end

  it 'defaults to user search mode' do
    expect(@admin_page.filter_mode_select).to eql('Search')
    expect(@admin_page.user_search_input_element.visible?).to be true
  end

  context 'in user search mode' do
    auth_users.select { |u| u.uid.length == 7 }.shuffle.last(25).each do |user|
      context "searching for UID #{user.uid}" do
        before(:all) do
          @admin_page.search_for_advisor user
          @admin_page.wait_for_advisor_list
          @admin_page.expand_user_row user
        end

        it("shows a search result for UID #{user.uid}") { expect(@admin_page.list_view_uids.first).to eql(user.uid) }

        it("shows the department(s) for UID #{user.uid}") { expect(@admin_page.visible_advisor_depts(user).sort).to eql(user.depts.map(&:name).uniq.sort) }

        it "shows the department role(s) for UID #{user.uid}" do
          user.advisor_roles.each do |dept_role|
            if dept_role.dept
              expected_roles = []
              expected_roles << 'Advisor' if dept_role.is_advisor
              expected_roles << 'Director' if dept_role.is_director
              expected_roles << 'Scheduler' if dept_role.is_scheduler
              expected_roles << 'Drop-In Advisor' if dept_role.is_drop_in_advisor
              visible_dept_roles = @admin_page.visible_dept_roles(user, dept_role.dept.code)
              visible_roles = visible_dept_roles[/.*\(([^\)]*)/,1]
              actual_roles = visible_roles.split(', ')
              actual_roles.concat(actual_roles.pop.split(' and '))
              expect(actual_roles).to eql(expected_roles)
            end
          end
        end

        it "shows the right Canvas permission for UID #{user.uid}" do
          visible_user_details = @admin_page.get_user_details user
          expect(visible_user_details['canAccessCanvasData']).to eql(user.can_access_canvas_data)
        end

        it "shows the right admin permission for UID #{user.uid}" do
          visible_user_details = @admin_page.get_user_details user
          expect(visible_user_details['isAdmin']).to eql(user.is_admin)
        end

        it "shows the active/deleted status for UID #{user.uid}" do
          visible_user_details = @admin_page.get_user_details user
          expect(visible_user_details['deletedAt'] ? false : true).to eql(user.active)
        end

        it "shows the right blocked status for UID #{user.uid}" do
          visible_user_details = @admin_page.get_user_details user
          expect(visible_user_details['isBlocked']).to eql(user.is_blocked)
        end

        it "shows the department membership type(s) for UID #{user.uid}" do
          visible_user_details = @admin_page.get_user_details user
          user.advisor_roles.each do |dept_role|
            if dept_role.dept
              visible_dept = visible_user_details['departments'].find { |d| d['code'] == dept_role.dept.code}
              expect(visible_dept['automateMembership']).to eql(dept_role.is_automated)
            end
          end
        end

        it "shows a 'become' link if UID #{user.uid} is active" do
          has_become_link = @admin_page.become_user_link_element(user).exists?
          user.active ? (expect(has_become_link).to be true) : (expect(has_become_link).to be false)
        end
      end
    end
  end

  context 'in user filter mode' do
    before { @admin_page.select_filter_mode }

    it 'shows all departments' do
      expected_options = ['All'] + non_admin_depts.map(&:name).sort
      expect(@admin_page.dept_select_options).to eql(expected_options)
    end

    non_admin_depts.each do |dept|
      it "shows all the advisors in #{dept.name}" do
        logger.info "Checking advisor list for #{dept.name}"
        dept_advisors = auth_users.select { |u| u.depts.include? dept }
        @admin_page.select_dept dept
        expected_uids = dept_advisors.map(&:uid).sort
        @admin_page.wait_for_advisor_list
        visible_uids = @admin_page.list_view_uids.sort
        @admin_page.wait_until(1, "Expected but not present: #{expected_uids - visible_uids}, present but not expected: #{visible_uids - expected_uids}") do
          visible_uids == expected_uids
        end
      end
    end

    it 'shows some advisor names' do
      @admin_page.select_all_depts
      @admin_page.wait_for_advisor_list
      visible_names = @admin_page.advisor_name_elements.map &:text
      visible_names.keep_if { |n| !n.empty? }
      expect(visible_names).not_to be_empty
    end

    it 'shows some advisor department titles' do
      visible_dept_titles = @admin_page.advisor_dept_elements.map &:text
      visible_dept_titles.keep_if { |t| !t.empty? }
      expect(visible_dept_titles).not_to be_empty
    end

    it 'shows some advisor email addresses' do
      visible_emails = @admin_page.advisor_email_elements.map { |e| e.attribute('href') }
      visible_emails.keep_if { |e| !e.empty? }
      expect(visible_emails).not_to be_empty
    end

    # TODO it 'allows an admin to sort users by Last Name ascending'
    # TODO it 'allows an admin to sort users by Last Name descending'
    # TODO it 'allows an admin to sort users by Last Login ascending'
    # TODO it 'allows an admin to sort users by Last Login descending'
  end

  context 'in BOA Admin mode' do
    before { @admin_page.select_admin_mode }

    it "shows all the admins" do
      dept = BOACDepartments::ADMIN
      logger.info "Checking users list for #{dept.name}"
      admin_users = auth_users.select { |u| u.is_admin }
      expected_uids = admin_users.map(&:uid).sort
      @admin_page.wait_for_advisor_list
      visible_uids = @admin_page.list_view_uids.sort
      @admin_page.wait_until(1, "Expected but not present: #{expected_uids - visible_uids}, present but not expected: #{visible_uids - expected_uids}") do
        visible_uids == expected_uids
      end
    end
  end

  context 'exporting all BOA users' do

    before(:all) { @csv = @admin_page.download_boa_users }

    dept_advisors.each do |dept|
      it "exports all #{dept[:dept].name} users" do
        dept_user_uids = dept[:advisors].map &:uid
        csv_dept_user_uids = @csv.map do |r|
          if r[:departments].include? "#{dept[:dept].code}:"
            r[:uid].to_s
          end
        end
        unexpected_advisors = csv_dept_user_uids.compact.uniq - dept_user_uids
        missing_advisors = dept_user_uids - csv_dept_user_uids.compact.uniq
        logger.debug "Unexpected #{dept[:dept].name} advisors: #{unexpected_advisors}" unless unexpected_advisors.empty?
        logger.debug "Missing #{dept[:dept].name} advisors: #{missing_advisors}" unless missing_advisors.empty?
        expect(csv_dept_user_uids.compact.uniq.sort).to eql(dept_user_uids.sort)
      end
    end

    it 'generates valid data' do
      first_names = []
      last_names = []
      uids = []
      titles = []
      emails = []
      departments = []
      drop_in_advising_flags = []
      can_access_canvas_data_flags = []
      is_blocked_flags = []
      last_logins = []
      @csv.each do |r|
        first_names << r[:first_name] if r[:first_name]
        last_names << r[:last_name] if r[:last_name]
        uids << r[:uid] if r[:uid]
        titles << r[:title] if r[:title]
        emails << r[:email] if r[:email]
        departments << r[:departments] if r[:departments]
        drop_in_advising_flags << r[:drop_in_advising] if r[:drop_in_advising]
        can_access_canvas_data_flags << r[:can_access_canvas_data]
        is_blocked_flags << r[:is_blocked]
        last_logins << r[:last_login] if r[:last_login]
      end
      logger.warn "The export CSV has #{@csv.count} rows, with #{first_names.length} first names, #{last_names.length} last names, and #{emails.length} emails"
      expect(first_names).not_to be_empty
      expect(last_names).not_to be_empty
      expect(uids).not_to be_empty
      expect(titles).not_to be_empty
      expect(emails).not_to be_empty
      expect(departments).not_to be_empty
      expect(drop_in_advising_flags).not_to be_empty
      expect(can_access_canvas_data_flags).not_to be_empty
      expect(is_blocked_flags).not_to be_empty
      expect(last_logins).not_to be_empty
    end
  end

  context 'in user adding mode' do

    before(:all) { @admin_page.load_page }

    it 'allows an admin to cancel adding a user' do
      @admin_page.click_add_user
      @admin_page.click_cancel_button
    end

    it 'allows an admin to add a user' do
      @admin_page.add_user @add_edit_user
      @admin_page.search_for_advisor @add_edit_user
      @admin_page.wait_until(Utils.short_wait) { @admin_page.list_view_uids.include? @add_edit_user.uid.to_s }
    end

    it 'prevents an admin adding an existing user' do
      @admin_page.click_add_user
      @admin_page.enter_new_user_data @add_edit_user
      @admin_page.dupe_user_el(@add_edit_user).when_visible Utils.short_wait
    end
  end

  context 'in user edit mode' do

    before(:each) { @admin_page.hit_escape }

    it 'allows an admin to cancel an edit' do
      @admin_page.click_edit_user @add_edit_user
      @admin_page.click_cancel_button
    end

    it 'allows an admin to block a user' do
      @add_edit_user.is_blocked = true
      @admin_page.edit_user @add_edit_user
      @admin_page.click_edit_user @add_edit_user
      @admin_page.wait_until(2) { @admin_page.is_blocked_cbx }
      expect(@admin_page.is_blocked_cbx.selected?).to be true
    end

    it 'allows an admin to unblock a user' do
      @add_edit_user.is_blocked = false
      @admin_page.edit_user @add_edit_user
      @admin_page.click_edit_user @add_edit_user
      @admin_page.wait_until(2) { @admin_page.is_blocked_cbx }
      expect(@admin_page.is_blocked_cbx.selected?).to be false
    end

    it 'allows an admin to set a user\'s department membership to automated' do
      @add_edit_user.advisor_roles.first.is_automated = true
      @admin_page.edit_user @add_edit_user
      @admin_page.click_edit_user @add_edit_user
      @admin_page.wait_until(2) { @admin_page.is_automated_dept_cbx @add_edit_user.advisor_roles.first.dept }
      expect(@admin_page.is_automated_dept_cbx(@add_edit_user.advisor_roles.first.dept).selected?).to be true
    end

    it 'allows an admin to set a user\'s department membership to manual' do
      @add_edit_user.advisor_roles.first.is_automated = false
      @admin_page.edit_user @add_edit_user
      @admin_page.click_edit_user @add_edit_user
      @admin_page.wait_until(2) { @admin_page.is_automated_dept_cbx @add_edit_user.advisor_roles.first.dept }
      expect(@admin_page.is_automated_dept_cbx(@add_edit_user.advisor_roles.first.dept).selected?).to be false
    end

    context 'performing edits' do

      before(:each) do
        @admin_page.hit_escape
        @admin_page.log_out if @admin_page.header_dropdown?
        @homepage.dev_auth
        @admin_page.load_page
        @admin_page.search_for_advisor @add_edit_user
      end

      it 'allows an admin to add an admin role to a user' do
        @add_edit_user.is_admin = true
        @admin_page.edit_user @add_edit_user
        @admin_page.click_become_user_link_element @add_edit_user
        @homepage.wait_for_title 'Home'
        @admin_page.load_page
      end

      it 'allows an admin to remove an admin role from a user' do
        @add_edit_user.is_admin = false
        @admin_page.edit_user @add_edit_user
        @admin_page.click_become_user_link_element @add_edit_user
        @homepage.wait_for_title 'Home'
        @admin_page.hit_page_url
        @admin_page.wait_for_title 'Page not found'
      end

      it 'allows an admin to prevent a user from viewing Canvas data' do
        @add_edit_user.can_access_canvas_data = false
        @admin_page.edit_user @add_edit_user
        @admin_page.click_become_user_link_element @add_edit_user
        @homepage.wait_for_title 'Home'
        @class_page.hit_class_page_url('2198', '21595')
        @class_page.wait_for_title 'Page not found'
      end

      it 'allows an admin to permit a user to view Canvas data' do
        @add_edit_user.can_access_canvas_data = true
        @admin_page.edit_user @add_edit_user
        @admin_page.click_become_user_link_element @add_edit_user
        @homepage.wait_for_title 'Home'
        @class_page.load_page('2198', '21595')
      end

      it 'allows an admin to delete a user' do
        @add_edit_user.active = false
        @admin_page.edit_user @add_edit_user
        @admin_page.log_out
        @homepage.enter_dev_auth_creds @add_edit_user
        @homepage.deleted_msg_element.when_visible Utils.short_wait
      end

      it 'allows an admin to un-delete a user' do
        @add_edit_user.active = true
        @admin_page.edit_user @add_edit_user
        @admin_page.log_out
        @homepage.dev_auth @add_edit_user
      end

      it 'allows an admin to give a user a department membership' do
        @add_edit_user.advisor_roles << AdvisorRole.new(dept: BOACDepartments::ASC, is_advisor: true)
        @admin_page.edit_user @add_edit_user
        @admin_page.click_become_user_link_element @add_edit_user
        @homepage.wait_for_title 'Home'
        @homepage.click_sidebar_create_filtered
        @cohort_page.click_new_filter_button
        @cohort_page.wait_until(1) { @cohort_page.new_filter_option_elements.any? &:visible? }
        expect(@cohort_page.new_filter_option('groupCodes').visible?).to be true
      end

      it 'allows an admin to remove a user\'s department membership' do
        asc_role = @add_edit_user.advisor_roles.find { |r| r.dept == BOACDepartments::ASC }
        @add_edit_user.advisor_roles.delete asc_role
        @admin_page.edit_user @add_edit_user
        @admin_page.click_become_user_link_element @add_edit_user
        @homepage.wait_for_title 'Home'
        @homepage.click_sidebar_create_filtered
        @cohort_page.click_new_filter_button
        @cohort_page.wait_until(1) { @cohort_page.new_filter_option_elements.any? &:visible? }
        expect(@cohort_page.new_filter_option('groupCodes').visible?).to be false
      end

      it 'allows an admin to give a user a department drop-in advisor role' do
        @add_edit_user.advisor_roles.first.is_advisor = false
        @add_edit_user.advisor_roles.first.is_drop_in_advisor = true
        @admin_page.edit_user @add_edit_user
        @admin_page.click_become_user_link_element @add_edit_user
        @homepage.wait_for_title 'Home'
        @homepage.new_appt_button_element.when_visible Utils.short_wait
      end

      it 'allows an admin to give a user a department director role' do
        @add_edit_user.advisor_roles.first.is_drop_in_advisor = false
        @add_edit_user.advisor_roles.first.is_director = true
        @admin_page.edit_user @add_edit_user
        @admin_page.click_become_user_link_element @add_edit_user
        @homepage.no_filtered_cohorts_msg_element.when_visible Utils.short_wait
        expect(@homepage.new_appt_button?).to be false
      end

      it 'allows an admin to give a user a department scheduler role' do
        @add_edit_user.advisor_roles.first.is_director = false
        @add_edit_user.advisor_roles.first.is_scheduler = true
        @admin_page.edit_user @add_edit_user
        @admin_page.click_become_user_link_element @add_edit_user
        @intake_desk_page.wait_for_title 'Drop-in Appointments Desk'
        @intake_desk_page.new_appt_button_element.when_visible Utils.short_wait
      end

      it 'allows an admin to give a user a department advisor role' do
        @add_edit_user.advisor_roles.first.is_scheduler = false
        @add_edit_user.advisor_roles.first.is_advisor = true
        @admin_page.edit_user @add_edit_user
        @admin_page.click_become_user_link_element @add_edit_user
        @homepage.no_filtered_cohorts_msg_element.when_visible Utils.short_wait
        expect(@homepage.new_appt_button?).to be false
      end
    end
  end
end
