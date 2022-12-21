require_relative '../../util/spec_helper'

unless ENV['DEPS']

  describe 'The BOAC passenger manifest' do

    include Logging

    test = BOACTestConfig.new
    test.user_mgmt
    auth_users = BOACUtils.get_authorized_users
    non_admin_depts = BOACDepartments::DEPARTMENTS - [BOACDepartments::ADMIN, BOACDepartments::NOTES_ONLY]
    dept_advisors = non_admin_depts.map { |dept| {:dept => dept, :advisors => BOACUtils.get_dept_advisors(dept)} }
    dept_advisors.keep_if { |a| a[:advisors].any? }

    before(:all) do
      # Initialize a user for the add/edit user tests
      @add_edit_user = BOACUser.new(
          uid: BOACUtils.config['test_add_edit_uid'],
          active: true,
          can_access_canvas_data: true,
          dept_memberships: [
              DeptMembership.new(
                  dept: BOACDepartments::L_AND_S,
                  advisor_role: AdvisorRole::ADVISOR,
                  is_automated: true
              )
          ]
      )

      # Initialize users for the add/remove scheduler tests
      @add_remove_advisor = auth_users.find { |u| (u.depts == [BOACDepartments::L_AND_S]) && u.can_access_advising_data }

      # Hard delete the add/edit user and the add/remove scheduler in case they're still lying around from a previous test run
      BOACUtils.hard_delete_auth_user @add_edit_user
      auth_users.delete_if { |u| u.uid == @add_edit_user.uid }

      @driver = Utils.launch_browser
      @homepage = BOACHomePage.new @driver
      @admin_page = BOACFlightDeckPage.new @driver
      @api_admin_page = BOACApiAdminPage.new @driver
      @pax_manifest_page = BOACPaxManifestPage.new @driver
      @class_page = BOACClassListViewPage.new @driver
      @cohort_page = BOACFilteredStudentsPage.new(@driver, @add_edit_user)
      @student_page = BOACStudentPage.new @driver

      @homepage.dev_auth
      @homepage.click_pax_manifest_link
      @pax_manifest_page.filter_mode_select_element.when_visible Utils.medium_wait
    end

    after(:all) do
      BOACUtils.hard_delete_auth_user @add_edit_user
      Utils.quit_browser @driver
    end

    it 'defaults to user search mode' do
      expect(@pax_manifest_page.filter_mode_select).to eql('Search')
      expect(@pax_manifest_page.user_search_input_element.visible?).to be true
    end

    context 'in user search mode' do
      auth_users.reject { |u| u.uid == Utils.super_admin_uid }.select { |u| u.uid.length == 7 }.shuffle.last(5).each do |user|
        context "searching for UID #{user.uid}" do
          before(:all) do
            @pax_manifest_page.search_for_advisor user
            @pax_manifest_page.wait_for_advisor_list
            @pax_manifest_page.expand_user_row user
          end

          it("shows a search result for UID #{user.uid}") { expect(@pax_manifest_page.list_view_uids.first).to eql(user.uid) }

          it("shows the department(s) for UID #{user.uid}") { expect(@pax_manifest_page.visible_advisor_depts(user).sort).to eql(user.depts.map(&:name).uniq.sort) }

          it "shows the department role(s) for UID #{user.uid}" do
            user.dept_memberships.each do |membership|
              if membership.dept
                expected_roles = []
                expected_roles << 'Advisor' if membership.advisor_role == AdvisorRole::ADVISOR
                expected_roles << 'Director' if membership.advisor_role == AdvisorRole::DIRECTOR
                expected_roles << user.degree_progress_perm.user_perm if user.degree_progress_perm
                visible_dept_roles = @pax_manifest_page.visible_dept_roles(user, membership.dept.code)
                visible_roles = visible_dept_roles.split(' — ').last
                actual_roles = visible_roles.split(' and ')
                actual_roles.concat(actual_roles.pop.split(' and '))
                expect(actual_roles).to eql(expected_roles)
              end
            end
          end

          it "shows the right Canvas permission for UID #{user.uid}" do
            visible_user_details = @pax_manifest_page.get_user_details user
            expect(visible_user_details['canAccessCanvasData']).to eql(user.can_access_canvas_data)
          end

          it "shows the right admin permission for UID #{user.uid}" do
            visible_user_details = @pax_manifest_page.get_user_details user
            expect(visible_user_details['isAdmin']).to eql(user.is_admin)
          end

          it "shows the active/deleted status for UID #{user.uid}" do
            visible_user_details = @pax_manifest_page.get_user_details user
            expect(visible_user_details['deletedAt'] ? false : true).to eql(user.active)
          end

          it "shows the right blocked status for UID #{user.uid}" do
            visible_user_details = @pax_manifest_page.get_user_details user
            expect(visible_user_details['isBlocked']).to eql(user.is_blocked)
          end

          it "shows the department membership type(s) for UID #{user.uid}" do
            visible_user_details = @pax_manifest_page.get_user_details user
            user.dept_memberships.each do |dept_role|
              if dept_role.dept
                visible_dept = visible_user_details['departments'].find { |d| d['code'] == dept_role.dept.code }
                expect(visible_dept['automateMembership']).to eql(dept_role.is_automated)
              end
            end
          end

          it "shows a 'become' link if UID #{user.uid} is active" do
            has_become_link = @pax_manifest_page.become_user_link_element(user).exists?
            (user.active && user.uid != Utils.super_admin_uid) ? (expect(has_become_link).to be true) : (expect(has_become_link).to be false)
          end
        end
      end
    end

    context 'in user filter mode' do
      before { @pax_manifest_page.select_filter_mode }

      it 'shows all departments' do
        expected_options = ['All'] + (dept_advisors.map { |a| a[:dept].name }).sort
        expect(@pax_manifest_page.dept_select_options).to eql(expected_options)
      end

      it 'shows all the advisors in a given department' do
        dept = dept_advisors.first
        logger.info "Checking advisor list for #{dept[:dept].name}"
        @pax_manifest_page.select_dept dept[:dept]
        expected_uids = dept[:advisors].map(&:uid).sort
        @pax_manifest_page.wait_for_advisor_list
        visible_uids = @pax_manifest_page.list_view_uids.sort
        @pax_manifest_page.wait_until(1, "Expected but not present: #{expected_uids - visible_uids}, present but not expected: #{visible_uids - expected_uids}") do
          visible_uids == expected_uids
        end
      end

      it 'shows some advisor names' do
        @pax_manifest_page.select_all_depts
        @pax_manifest_page.wait_for_advisor_list
        visible_names = @pax_manifest_page.advisor_name_elements.map &:text
        visible_names.keep_if { |n| !n.empty? }
        expect(visible_names).not_to be_empty
      end

      it 'shows some advisor department titles' do
        sleep Utils.short_wait
        visible_dept_titles = @pax_manifest_page.advisor_dept_elements.map &:text
        visible_dept_titles.keep_if { |t| !t.empty? }
        expect(visible_dept_titles).not_to be_empty
      end

      it 'shows some advisor email addresses' do
        visible_emails = @pax_manifest_page.advisor_email_elements.map { |e| e.attribute('href') }
        visible_emails.keep_if { |e| !e.empty? }
        expect(visible_emails).not_to be_empty
      end
    end

    context 'in BOA Admin mode' do
      before { @pax_manifest_page.select_admin_mode }

      it 'shows all the admins' do
        dept = BOACDepartments::ADMIN
        logger.info "Checking users list for #{dept.name}"
        admin_users = auth_users.select { |u| u.is_admin }
        expected_uids = admin_users.map(&:uid).sort
        @pax_manifest_page.wait_for_advisor_list
        visible_uids = @pax_manifest_page.list_view_uids.sort
        @pax_manifest_page.wait_until(1, "Expected but not present: #{expected_uids - visible_uids}, present but not expected: #{visible_uids - expected_uids}") do
          visible_uids == expected_uids
        end
      end
    end

    context 'exporting all BOA users' do

      before(:all) { @csv = @pax_manifest_page.download_boa_users }

      dept_advisors.each do |dept|
        it "exports all #{dept[:dept].name} users" do
          dept_user_uids = dept[:advisors].map &:uid
          csv_dept_user_uids = @csv.map do |r|
            if r[:department]&.include? "#{dept[:dept].code}:"
              r[:uid].to_s
            end
          end
          unexpected_advisors = csv_dept_user_uids.compact.uniq - dept_user_uids
          missing_advisors = dept_user_uids - csv_dept_user_uids.compact.uniq
          logger.debug "Unexpected #{dept[:dept].name} advisors: #{unexpected_advisors}" unless unexpected_advisors.empty?
          logger.debug "Missing #{dept[:dept].name} advisors: #{missing_advisors}" unless missing_advisors.empty?
          @pax_manifest_page.wait_until(1, "Unexpected #{dept[:dept].name} advisors: #{unexpected_advisors}. Missing #{dept[:dept].name} advisors: #{missing_advisors}") do
            csv_dept_user_uids.compact.uniq.sort == dept_user_uids.sort
          end
        end
      end

      it 'generates valid data' do
        first_names = []
        last_names = []
        uids = []
        titles = []
        emails = []
        departments = []
        appt_roles = []
        can_access_canvas_data_flags = []
        is_blocked_flags = []
        last_logins = []
        @csv.each do |r|
          first_names << r[:first_name] if r[:first_name]
          last_names << r[:last_name] if r[:last_name]
          uids << r[:uid] if r[:uid]
          titles << r[:title] if r[:title]
          emails << r[:email] if r[:email]
          departments << r[:department] if r[:department]
          appt_roles << r[:appointment_roles] if r[:appointment_roles]
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
        expect(appt_roles).not_to be_empty
        expect(can_access_canvas_data_flags).not_to be_empty
        expect(is_blocked_flags).not_to be_empty
        expect(last_logins).not_to be_empty
      end
    end

    context 'in user adding mode' do

      before(:all) { @pax_manifest_page.load_page }

      it 'allows an admin to cancel adding a user' do
        @pax_manifest_page.click_add_user
        @pax_manifest_page.click_cancel_button
      end

      it 'allows an admin to add a user' do
        @pax_manifest_page.add_user @add_edit_user
        @pax_manifest_page.search_for_advisor @add_edit_user
        @pax_manifest_page.wait_until(Utils.short_wait) { @pax_manifest_page.list_view_uids.include? @add_edit_user.uid.to_s }
      end

      it 'prevents an admin adding an existing user' do
        @pax_manifest_page.click_add_user
        @pax_manifest_page.enter_new_user_data @add_edit_user
        @pax_manifest_page.dupe_user_el(@add_edit_user).when_visible Utils.short_wait
      end
    end

    context 'in user edit mode' do

      before(:all) do
        @pax_manifest_page.load_page
        @pax_manifest_page.search_for_advisor @add_edit_user
      end

      before(:each) { @pax_manifest_page.click_cancel_button if @pax_manifest_page.cancel_user_button? }

      it 'allows an admin to cancel an edit' do
        @pax_manifest_page.click_edit_user @add_edit_user
        @pax_manifest_page.click_cancel_button
      end

      it 'allows an admin to block a user' do
        @add_edit_user.is_blocked = true
        @pax_manifest_page.edit_user @add_edit_user
        @pax_manifest_page.click_edit_user @add_edit_user
        @pax_manifest_page.wait_until(2) { @pax_manifest_page.is_blocked_cbx }
        expect(@pax_manifest_page.is_blocked_cbx.selected?).to be true
      end

      it 'allows an admin to unblock a user' do
        @add_edit_user.is_blocked = false
        @pax_manifest_page.edit_user @add_edit_user
        @pax_manifest_page.click_edit_user @add_edit_user
        @pax_manifest_page.wait_until(2) { @pax_manifest_page.is_blocked_cbx }
        expect(@pax_manifest_page.is_blocked_cbx.selected?).to be false
      end

      it 'allows an admin to set a user\'s department membership to automated' do
        @add_edit_user.dept_memberships.first.is_automated = true
        @pax_manifest_page.edit_user @add_edit_user
        @pax_manifest_page.click_edit_user @add_edit_user
        @pax_manifest_page.wait_until(2) { @pax_manifest_page.is_automated_dept_cbx @add_edit_user.dept_memberships.first.dept }
        expect(@pax_manifest_page.is_automated_dept_cbx(@add_edit_user.dept_memberships.first.dept).selected?).to be true
      end

      it 'allows an admin to set a user\'s department membership to manual' do
        @add_edit_user.dept_memberships.first.is_automated = false
        @pax_manifest_page.edit_user @add_edit_user
        @pax_manifest_page.click_edit_user @add_edit_user
        @pax_manifest_page.wait_until(2) { @pax_manifest_page.is_automated_dept_cbx @add_edit_user.dept_memberships.first.dept }
        expect(@pax_manifest_page.is_automated_dept_cbx(@add_edit_user.dept_memberships.first.dept).selected?).to be false
      end

      context 'performing edits' do

        before(:all) { @student = test.students.sample }

        before(:each) do
          @pax_manifest_page.hit_escape
          @pax_manifest_page.log_out if @pax_manifest_page.header_dropdown?
          @homepage.dev_auth
          @pax_manifest_page.load_page
          @pax_manifest_page.search_for_advisor @add_edit_user
        end

        it 'allows an admin to add an admin role to a user' do
          @add_edit_user.is_admin = true
          @pax_manifest_page.edit_user @add_edit_user
          @pax_manifest_page.click_become_user_link_element @add_edit_user
          @homepage.wait_for_title 'Home'
          @pax_manifest_page.load_page
        end

        it 'allows an admin to remove an admin role from a user' do
          @add_edit_user.is_admin = false
          @pax_manifest_page.edit_user @add_edit_user
          @pax_manifest_page.click_become_user_link_element @add_edit_user
          @homepage.wait_for_title 'Home'
          @pax_manifest_page.hit_page_url
          @pax_manifest_page.wait_for_title 'Page not found'
        end

        it 'allows an admin to prevent a user from viewing Canvas data' do
          @add_edit_user.can_access_canvas_data = false
          @pax_manifest_page.edit_user @add_edit_user
          @pax_manifest_page.click_become_user_link_element @add_edit_user
          @homepage.wait_for_title 'Home'
          @class_page.hit_class_page_url('2198', '21595')
          expected_error = 'Failed to load resource: the server responded with a status of 403 ()'
          @class_page.wait_until(Utils.short_wait) { Utils.console_error_present?(@driver, expected_error) }
        end

        it 'allows an admin to permit a user to view Canvas data' do
          @add_edit_user.can_access_canvas_data = true
          @pax_manifest_page.edit_user @add_edit_user
          @pax_manifest_page.click_become_user_link_element @add_edit_user
          @homepage.wait_for_title 'Home'
          @class_page.load_page('2198', '21595')
        end

        it 'allows an admin to prevent a user from viewing notes and appointments' do
          @add_edit_user.can_access_advising_data = false
          @pax_manifest_page.edit_user @add_edit_user
          @pax_manifest_page.click_become_user_link_element @add_edit_user
          @homepage.wait_for_title 'Home'
          @student_page.load_page @student
          @student_page.wait_for_timeline
          expect(@student_page.new_note_button?).to be false
          expect(@student_page.notes_button?).to be false
          expect(@student_page.appts_button?).to be false
        end

        it 'allows an admin to permit a user to view notes and appointments' do
          @add_edit_user.can_access_advising_data = true
          @pax_manifest_page.edit_user @add_edit_user
          @pax_manifest_page.click_become_user_link_element @add_edit_user
          @homepage.wait_for_title 'Home'
          @student_page.load_page @student
          @student_page.wait_for_timeline
          expect(@student_page.new_note_button?).to be true
          expect(@student_page.notes_button?).to be true
          expect(@student_page.appts_button?).to be true
        end

        it 'allows an admin to delete a user' do
          @add_edit_user.active = false
          @pax_manifest_page.edit_user @add_edit_user
          @pax_manifest_page.click_edit_user @add_edit_user
          @pax_manifest_page.is_deleted_cbx.when_present 2
          expect(@pax_manifest_page.is_deleted_cbx.selected?).to be true
          expect(@pax_manifest_page.is_blocked_cbx.selected?).to be false
          @pax_manifest_page.hit_escape
          @pax_manifest_page.log_out
          @homepage.enter_dev_auth_creds @add_edit_user
          @homepage.deleted_msg_element.when_visible Utils.short_wait
        end

        it 'allows an admin to un-delete a user' do
          @add_edit_user.active = true
          @pax_manifest_page.edit_user @add_edit_user
          @pax_manifest_page.click_edit_user @add_edit_user
          @pax_manifest_page.is_deleted_cbx.when_present 2
          expect(@pax_manifest_page.is_deleted_cbx.selected?).to be false
          expect(@pax_manifest_page.is_blocked_cbx.selected?).to be false
          @pax_manifest_page.hit_escape
          @pax_manifest_page.log_out
          @homepage.dev_auth @add_edit_user
        end

        it 'allows an admin to give a user a department membership' do
          @add_edit_user.dept_memberships << DeptMembership.new(dept: BOACDepartments::ASC, advisor_role: AdvisorRole::ADVISOR)
          @pax_manifest_page.edit_user @add_edit_user
          @pax_manifest_page.click_become_user_link_element @add_edit_user
          @homepage.wait_for_title 'Home'
          @homepage.click_sidebar_create_filtered
          expect(@cohort_page.filter_options).to include('Team (ASC)')
        end

        it 'allows an admin to remove a user\'s department membership' do
          asc_role = @add_edit_user.dept_memberships.find { |r| r.dept == BOACDepartments::ASC }
          @add_edit_user.dept_memberships.delete asc_role
          @pax_manifest_page.edit_user @add_edit_user
          @pax_manifest_page.click_become_user_link_element @add_edit_user
          @homepage.wait_for_title 'Home'
          @homepage.click_sidebar_create_filtered
          expect(@cohort_page.filter_options).not_to include('Team')
        end

        it 'allows an admin to give a user a department director role' do
          @add_edit_user.dept_memberships.first.advisor_role = AdvisorRole::DIRECTOR
          @pax_manifest_page.edit_user @add_edit_user
          @pax_manifest_page.click_become_user_link_element @add_edit_user
          @homepage.no_filtered_cohorts_msg_element.when_visible Utils.short_wait
        end

        it 'allows an admin to give a user a department advisor role' do
          @add_edit_user.dept_memberships.first.advisor_role = AdvisorRole::ADVISOR
          @pax_manifest_page.edit_user @add_edit_user
          @pax_manifest_page.click_become_user_link_element @add_edit_user
          @homepage.no_filtered_cohorts_msg_element.when_visible Utils.short_wait
        end
      end
    end
  end
end
