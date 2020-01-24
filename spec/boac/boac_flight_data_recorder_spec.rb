require_relative '../../util/spec_helper'

include Logging

depts = BOACDepartments::DEPARTMENTS - [BOACDepartments::ADMIN, BOACDepartments::NOTES_ONLY]
all_users = BOACUtils.get_authorized_users.select &:active
all_non_admin_users = all_users.reject &:is_admin

admin = all_users.find &:is_admin
director = all_non_admin_users.find { |u| u.advisor_roles.find &:is_director }
advisor = all_non_admin_users.find { |u| u.advisor_roles.select(&:is_advisor).reject(&:is_director).any? }
scheduler = all_non_admin_users.find { |u| u.advisor_roles.select(&:is_scheduler).reject(&:is_director).reject(&:is_advisor).any? }

logger.warn "Admin UID #{admin.uid}, director UID #{director.uid}, advisor UID #{advisor.uid}, scheduler UID #{scheduler.uid}"

describe 'BOA flight data recorder' do

  before(:all) do
    @driver = Utils.launch_browser
    @homepage = BOACHomePage.new @driver
    @flight_data_recorder = BOACFlightDataRecorderPage.new @driver
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when the user is an admin' do

    before(:all) do
      @homepage.dev_auth admin
      @homepage.click_flight_data_recorder_link
    end

    after(:all) { @flight_data_recorder.log_out }

    it 'hides the complete notes report by default' do
      @flight_data_recorder.show_hide_report_button_element.when_visible Utils.short_wait
      expect(@flight_data_recorder.notes_count_boa_authors?).to be false
    end

    it 'allows the user to view the complete notes report' do
      @flight_data_recorder.toggle_note_report_visibility
      @flight_data_recorder.notes_count_boa_authors_element.when_visible 1
    end

    it 'shows the total number of notes imported from the SIS'
    it 'shows the total number of notes imported from the ASC'
    it 'shows the total number of notes imported from the CEEE'

    context 'viewing the created-in-BOA notes report' do
      it 'shows the total number of notes'
      it 'shows the total distinct note authors'
      it 'shows the percentage of notes with attachments'
      it 'shows the percentage of notes with topics'
    end

    depts.each do |dept|

      it "allows the user to filter users by #{dept.name}" do
        @flight_data_recorder.select_dept_report dept
        @flight_data_recorder.dept_list_header(dept).when_visible Utils.short_wait
      end

      it "shows the right number of users in #{dept.name}" do
        @flight_data_recorder.wait_for_user_count(dept, (all_users.select { |u| u.depts.include? dept }.length))
      end

      it "shows all the users in #{dept.name}" do
        expected_uids = all_users.select { |u| u.depts.include? dept }.map(&:uid).sort
        visible_uids = @flight_data_recorder.list_view_uids(dept, expected_uids.length).sort
        @flight_data_recorder.wait_until(1, "Missing: #{expected_uids - visible_uids}. Unexpected: #{visible_uids - expected_uids}") do
          visible_uids == expected_uids
        end
      end

      #all_users.select { |u| u.depts.include? dept }.each do |user|
      #
      #  it "shows a link to the directory for #{dept.name} UID #{user.uid}"
      #  it "shows the total number of BOA notes created by #{dept.name} UID #{user.uid}"
      #  it "shows the last login date for #{dept.name} UID #{user.uid}"
      #
      #  user.advisor_roles.each do |role|
      #
      #    it "shows the #{dept.name} UID #{user.uid} department role #{role.inspect}"
      #
      #  end
      #end
    end
  end

  context 'when the user is a director' do

    before(:all) do
      @homepage.dev_auth director
      @homepage.click_flight_data_recorder_link
    end

    after(:all) { @flight_data_recorder.log_out }

    it "only shows data for UID #{director.uid} departments #{director.advisor_roles.select(&:is_director).map(&:dept).map(&:name)}"
    it 'hides the complete notes report by default'
    it 'allows the user to view the complete notes report'

    director.advisor_roles.select(&:is_director).map(&:dept).each do |dept|

      it "allows the user to filter users by #{dept.name}"

      all_non_admin_users.select { |u| u.depts.include? dept }.each do |user|

        it "shows a link to the directory for #{dept.name} UID #{user.uid}"
        it "shows the total number of BOA notes created by #{dept.name} UID #{user.uid}"
        it "shows the last login date for #{dept.name} UID #{user.uid}"

      end
    end
  end

  context 'when the user is an advisor' do

    before(:all) { @homepage.dev_auth advisor }
    after(:all) { @flight_data_recorder.log_out }

    it 'prevents the user hitting the page' do
      @flight_data_recorder.load_page advisor.depts.first
      @flight_data_recorder.wait_for_title 'Page not found'
    end

    it 'offers no link in the header' do
      @homepage.click_header_dropdown
      expect(@homepage.flight_data_recorder_link?).to be false
    end

  end

  context 'when the user is a scheduler' do

    before(:all) { @homepage.dev_auth scheduler }
    after(:all) { @flight_data_recorder.log_out }

    it 'prevents the user hitting the page' do
      @flight_data_recorder.load_page scheduler.depts.first
      @flight_data_recorder.wait_for_title 'Page not found'
    end

    it 'offers no link in the header' do
      @homepage.click_header_dropdown
      expect(@homepage.flight_data_recorder_link?).to be false
    end

  end
end
