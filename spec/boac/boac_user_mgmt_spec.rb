require_relative '../../util/spec_helper'

describe 'The BOAC passenger manifest' do

  include Logging

  test = BOACTestConfig.new
  test.user_mgmt
  auth_users = BOACUtils.get_authorized_users
  non_admin_depts = BOACDepartments::DEPARTMENTS - [BOACDepartments::ADMIN, BOACDepartments::NOTES_ONLY]
  dept_advisors = non_admin_depts.map { |dept| {:dept => dept, :advisors => BOACUtils.get_dept_advisors(dept)} }

  before(:all) do
    @driver = Utils.launch_browser
    @homepage = BOACHomePage.new @driver
    @admin_page = BOACPaxManifestPage.new @driver

    @homepage.dev_auth
    @homepage.click_pax_manifest_link
    @admin_page.filter_mode_select_element.when_visible Utils.medium_wait
  end

  after(:all) { Utils.quit_browser @driver }

  it 'defaults to user search mode' do
    expect(@admin_page.filter_mode_select).to eql('Search')
    expect(@admin_page.user_search_input_element.visible?).to be true
  end

  context 'in user search mode' do
    # Inactive users don't come up in search results, so don't try to look for them
    # TODO - search for inactive users if BOAC-2882 is fixed
    auth_users.select { |u| u.uid.length == 7 && u.active }.shuffle.last(25).each do |user|
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
            visible_dept = visible_user_details['departments'].find { |d| d['code'] == dept_role.dept.code}
            expect(visible_dept['automateMembership']).to eql(dept_role.is_automated)
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
          if r[:departments].include? dept[:dept].code
            r[:uid].to_s
          end
        end
        unexpected_advisors = csv_dept_user_uids.compact - dept_user_uids
        missing_advisors = dept_user_uids - csv_dept_user_uids.compact
        logger.debug "Unexpected #{dept[:dept].name} advisors: #{unexpected_advisors}" unless unexpected_advisors.empty?
        logger.debug "Missing #{dept[:dept].name} advisors: #{missing_advisors}" unless missing_advisors.empty?
        expect(csv_dept_user_uids.compact.sort).to eql(dept_user_uids.sort)
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
end
