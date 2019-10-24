require_relative '../../util/spec_helper'

describe 'The BOAC users tool' do

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
    @admin_page.user_search_input_element.when_visible Utils.short_wait
  end

  after(:all) { Utils.quit_browser @driver }

  it 'defaults to all active users with any permissions' do
    expect(@admin_page.dept_select).to eql('-- Select a department --')
    expect(@admin_page.admins_cbx_checked?).to be true
    expect(@admin_page.advisors_cbx_checked?).to be true
    expect(@admin_page.canvas_access_cbx_checked?).to be true
    expect(@admin_page.directors_cbx_checked?).to be true
    expect(@admin_page.drop_in_advisors_cbx_checked?).to be true
    expect(@admin_page.schedulers_cbx_checked?).to be true
    expect(@admin_page.active_cbx_checked?).to be true
    expect(@admin_page.deleted_cbx_checked?).to be false
    expect(@admin_page.blocked_cbx_checked?).to be false
    expect(@admin_page.expired_cbx_checked?).to be false
  end

  it 'shows all departments' do
    expected_options = ['-- Select a department --', 'All Departments'] + non_admin_depts.map(&:name).sort
    logger.debug "Expected: #{expected_options}"
    logger.debug "Actual: #{@admin_page.dept_select_options}"
    expect(@admin_page.dept_select_options).to eql(expected_options)
  end

  non_admin_depts.each do |dept|
    it "shows all the advisors in #{dept.name}" do
      logger.info "Checking advisor list for #{dept.name}"
      dept_advisors = auth_users.select { |u| u.depts.include? dept }
      @admin_page.check_all_filters
      @admin_page.select_dept dept
      expected_uids = dept_advisors.map(&:uid).sort
      visible_uids = @admin_page.list_view_uids.sort
      @admin_page.wait_until(1, "Expected but not present: #{expected_uids - visible_uids}, present but not expected: #{visible_uids - expected_uids}") do
        visible_uids == expected_uids
      end
    end
  end

  it 'shows some advisor names' do
    @admin_page.check_all_filters
    @admin_page.select_all_depts
    @admin_page.wait_for_advisor_list
    @admin_page.sort_by_uid
    visible_names = @admin_page.advisor_name_elements.map &:text
    logger.debug "Visible names: #{visible_names}"
    visible_names.keep_if { |n| !n.empty? }
    expect(visible_names).not_to be_empty
  end

  it 'shows some advisor titles' do
    visible_titles = @admin_page.advisor_title_elements.map &:text
    logger.debug "Visible titles: #{visible_titles}"
    visible_titles.keep_if { |t| !t.empty? }
    expect(visible_titles).not_to be_empty
  end

  it 'shows some advisor email addresses' do
    visible_emails = @admin_page.advisor_email_elements.map &:text
    logger.debug "Visible emails: #{visible_emails}"
    visible_emails.keep_if { |e| !e.empty? }
    expect(visible_emails).not_to be_empty
  end

  # Inactive users don't come up in search results, so don't try to look for them
  # TODO - search for inactive users if BOAC-2882 is fixed
  auth_users.select { |u| u.uid.length == 7 && u.active }.shuffle.last(25).each do |user|

    it "allows an admin to search for UID #{user.uid}" do
      @admin_page.search_for_advisor user
      @admin_page.wait_for_advisor_list
      @admin_page.wait_until(1) { @admin_page.list_view_uids.length == 1 }
      expect(@admin_page.list_view_uids.first).to eql(user.uid)
    end

    it("shows the department(s) for UID #{user.uid}") { expect(@admin_page.visible_advisor_depts(user).sort).to eql(user.depts.map(&:name).sort) }

    it "shows the right Canvas permission for UID #{user.uid}" do
      @admin_page.expand_user_row user
      expected_permission = user.can_access_canvas_data ? 'Canvas data access' : 'No Canvas data'
      expect(@admin_page.visible_canvas_perm user).to eql(expected_permission)
    end

    it "shows the right admin permission for UID #{user.uid}" do
      expected_permission = 'Admin' if user.is_admin
      expect(@admin_page.visible_admin_perm user).to eql(expected_permission)
    end

    it "shows the active/deleted status for UID #{user.uid}" do
      expected_status = user.active ? 'Active' : 'Deleted'
      expect(@admin_page.visible_deleted_status user).to eql(expected_status)
    end

    it "shows the right blocked status for UID #{user.uid}" do
      expected_status = 'Blocked' if user.is_blocked
      expect(@admin_page.visible_blocked_status user).to eql(expected_status)
    end

    it "shows the department role(s) for UID #{user.uid}" do
      expected_roles = []
      expected_roles << 'Advisor' if user.advisor_roles.find(&:is_advisor)
      expected_roles << 'Director' if user.advisor_roles.find(&:is_director)
      expected_roles << 'Scheduler' if user.advisor_roles.find(&:is_scheduler)
      expected_roles << 'Drop-In Advisor' if user.advisor_roles.find(&:is_drop_in_advisor)
      expect(@admin_page.visible_dept_roles(user).uniq.sort).to eql(expected_roles.sort)
    end

    it "shows the department membership type(s) for UID #{user.uid}" do
      expected_types = []
      if user.advisor_roles.map(&:is_automated).compact.empty?
        expect(@admin_page.visible_dept_memberships user).to be_empty
      else
        expected_types << 'Automated Membership' if (user.advisor_roles.find { |r| r.is_automated })
        expected_types << 'Manual Membership' if (user.advisor_roles.find { |r| !r.is_automated })
        expect(@admin_page.visible_dept_memberships(user).uniq.sort).to eql(expected_types.sort)
      end
    end

    it "shows a 'become' link if UID #{user.uid} is active" do
      has_become_link = @admin_page.become_user_link_element(user).exists?
      user.active ? (expect(has_become_link).to be true) : (expect(has_become_link).to be false)
    end
  end

  context 'when filtering the advisor list' do

    before(:each) { @admin_page.reset_filters }

    it 'allows an admin to filter for Admins only' do
      @admin_page.toggle_checkbox_filter 'Advisors'
      @admin_page.toggle_checkbox_filter 'Canvas Access'
      @admin_page.toggle_checkbox_filter 'Directors'
      @admin_page.toggle_checkbox_filter 'Drop-In Advisors'
      @admin_page.toggle_checkbox_filter 'Schedulers'
      # TODO - the expectation
    end

    it 'allows an admin to filter out Admins' do
      @admin_page.toggle_checkbox_filter 'Admins'
      # TODO - the expectation
    end

    it 'allows an admin to filter for Advisors only' do
      @admin_page.toggle_checkbox_filter 'Admins'
      @admin_page.toggle_checkbox_filter 'Canvas Access'
      @admin_page.toggle_checkbox_filter 'Directors'
      @admin_page.toggle_checkbox_filter 'Drop-In Advisors'
      @admin_page.toggle_checkbox_filter 'Schedulers'
      # TODO - the expectation
    end

    it 'allows an admin to filter out Advisors' do
      @admin_page.toggle_checkbox_filter 'Advisors'
      # TODO - the expectation
    end

    it 'allows an admin to filter for Canvas Access only' do
      @admin_page.toggle_checkbox_filter 'Admins'
      @admin_page.toggle_checkbox_filter 'Advisors'
      @admin_page.toggle_checkbox_filter 'Directors'
      @admin_page.toggle_checkbox_filter 'Drop-In Advisors'
      @admin_page.toggle_checkbox_filter 'Schedulers'
      # TODO - the expectation
    end

    it 'allows an admin to filter out Canvas Access' do
      @admin_page.toggle_checkbox_filter 'Canvas Access'
      # TODO - the expectation
    end

    it 'allows an admin to filter for Directors only' do
      @admin_page.toggle_checkbox_filter 'Admins'
      @admin_page.toggle_checkbox_filter 'Advisors'
      @admin_page.toggle_checkbox_filter 'Canvas Access'
      @admin_page.toggle_checkbox_filter 'Drop-In Advisors'
      @admin_page.toggle_checkbox_filter 'Schedulers'
      # TODO - the expectation
    end

    it 'allows an admin to filter out Directors' do
      @admin_page.toggle_checkbox_filter 'Directors'
      # TODO - the expectation
    end

    it 'allows an admin to filter for Drop-In Advisors only' do
      @admin_page.toggle_checkbox_filter 'Admins'
      @admin_page.toggle_checkbox_filter 'Advisors'
      @admin_page.toggle_checkbox_filter 'Canvas Access'
      @admin_page.toggle_checkbox_filter 'Directors'
      @admin_page.toggle_checkbox_filter 'Schedulers'
      # TODO - the expectation
    end

    it 'allows an admin to filter out Drop-In Advisors' do
      @admin_page.toggle_checkbox_filter 'Drop-In Advisors'
      # TODO - the expectation
    end

    it 'allows an admin to filter for Schedulers only' do
      @admin_page.toggle_checkbox_filter 'Admins'
      @admin_page.toggle_checkbox_filter 'Advisors'
      @admin_page.toggle_checkbox_filter 'Canvas Access'
      @admin_page.toggle_checkbox_filter 'Directors'
      @admin_page.toggle_checkbox_filter 'Drop-In Advisors'
      # TODO - the expectation
    end

    it 'allows an admin to filter out Schedulers' do
      @admin_page.toggle_checkbox_filter 'Schedulers'
      # TODO - the expectation
    end

    it 'allows an admin to filter for Active users only' do
      # TODO - the expectation
    end

    it 'allows an admin to filter out Active users' do
      @admin_page.toggle_checkbox_filter 'Active'
      @admin_page.toggle_checkbox_filter 'Deleted'
      @admin_page.toggle_checkbox_filter 'Blocked'
      @admin_page.toggle_checkbox_filter 'Expired'
      # TODO - the expectation
    end

    it 'allows an admin to filter for Deleted users only' do
      @admin_page.toggle_checkbox_filter 'Active'
      @admin_page.toggle_checkbox_filter 'Deleted'
      # TODO - the expectation
    end

    it 'allows an admin to filter for Blocked Active users only' do
      @admin_page.toggle_checkbox_filter 'Blocked'
      # TODO - the expectation
    end

    it 'allows an amdin to filter for Expired users only' do
      # TODO - the expectation
    end
  end

  # TODO it 'allows an admin to sort users by UID ascending'
  # TODO it 'allows an admin to sort users by UID descending'
  # TODO it 'allows an admin to sort users by Name ascending'
  # TODO it 'allows an admin to sort users by Name descending'
  # TODO it 'allows an admin to sort users by Title ascending'
  # TODO it 'allows an admin to sort users by Title descending'

  context 'exporting all BOA users' do

    before(:all) { @csv = @admin_page.download_boa_users }

    dept_advisors.each do |dept|
      it "exports all #{dept[:dept].name} users" do
        dept_user_uids = dept[:advisors].map &:uid
        csv_dept_user_uids = @csv.map do |r|
          if r[:dept_code] == dept[:dept].code && r[:dept_name] == (dept[:dept].export_name || dept[:dept].name)
            r[:uid].to_s
          end
        end
        logger.debug "Unexpected #{dept[:dept].name} advisors: #{csv_dept_user_uids.compact - dept_user_uids}"
        logger.debug "Missing #{dept[:dept].name} advisors: #{dept_user_uids - csv_dept_user_uids.compact}"
        expect(csv_dept_user_uids.compact.sort).to eql(dept_user_uids.sort)
      end
    end

    it 'generates valid data' do
      first_names = []
      last_names = []
      emails = []
      @csv.each do |r|
        first_names << r[:first_name] if r[:first_name]
        last_names << r[:last_name] if r[:last_name]
        emails << r[:email] if r[:email]
      end
      logger.warn "The export CSV has #{@csv.count} rows, with #{first_names.length} first names, #{last_names.length} last names, and #{emails.length} emails"
      expect(first_names).not_to be_empty
      expect(last_names).not_to be_empty
      expect(emails).not_to be_empty
    end
  end
end
