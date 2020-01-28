require_relative '../../util/spec_helper'

include Logging

depts = BOACDepartments::DEPARTMENTS - [BOACDepartments::ADMIN, BOACDepartments::NOTES_ONLY]
all_users = BOACUtils.get_authorized_users.select &:active
all_non_admin_users = all_users.reject &:is_admin

admin = all_users.find &:is_admin
director = all_non_admin_users.find { |u| u.advisor_roles.find &:is_director }
director_depts = director.advisor_roles.select(&:is_director).map(&:dept)
advisor = all_non_admin_users.find { |u| u.advisor_roles.select(&:is_advisor).reject(&:is_director).any? }
scheduler = all_non_admin_users.find { |u| u.advisor_roles.select(&:is_scheduler).reject(&:is_director).reject(&:is_advisor).any? }

logger.warn "Admin UID #{admin.uid}, director UID #{director.uid}, advisor UID #{advisor.uid}, scheduler UID #{scheduler.uid}"

advisor_data = BOACUtils.get_last_login_and_note_count

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
      @ttl_note_count = BOACUtils.get_total_note_count
    end

    after(:all) { @flight_data_recorder.log_out }

    it 'hides the complete notes report by default' do
      @flight_data_recorder.show_hide_report_button_element.when_visible Utils.short_wait
      expect(@flight_data_recorder.notes_count_boa_authors_element.visible?).to be false
    end

    it 'allows the user to view the complete notes report' do
      @flight_data_recorder.toggle_note_report_visibility
      @flight_data_recorder.notes_count_boa_authors_element.when_visible 1
    end

    it 'shows the total number of notes imported from the SIS' do
      expect(@flight_data_recorder.notes_count_sis).to eql(Utils.int_to_s_with_commas NessieUtils.get_external_note_count('sis_advising_notes'))
    end

    it 'shows the total number of notes imported from the ASC' do
      expect(@flight_data_recorder.notes_count_asc).to eql(Utils.int_to_s_with_commas NessieUtils.get_external_note_count('boac_advising_asc'))
    end

    it 'shows the total number of notes imported from the CEEE' do
      expect(@flight_data_recorder.notes_count_ei).to eql(Utils.int_to_s_with_commas NessieUtils.get_external_note_count('boac_advising_e_i'))
    end

    context 'viewing the created-in-BOA notes report' do

      it 'shows the total number of notes' do
        expect(@flight_data_recorder.boa_note_count).to eql(Utils.int_to_s_with_commas @ttl_note_count)
      end

      it 'shows the total distinct note authors' do
        expect(@flight_data_recorder.notes_count_boa_authors).to eql(Utils.int_to_s_with_commas BOACUtils.get_distinct_note_author_count)
      end

      it 'shows the percentage of notes with attachments' do
        expected = ((BOACUtils.get_notes_with_attachments_count.to_f / @ttl_note_count.to_f) * 100).round(1).to_s
        expect(@flight_data_recorder.notes_count_boa_with_attachments).to include(expected)
      end

      it 'shows the percentage of notes with topics' do
        expected = ((BOACUtils.get_notes_with_topics_count.to_f / @ttl_note_count.to_f) * 100).round(1).to_s
        expect(@flight_data_recorder.notes_count_boa_with_topics).to include(expected)
      end
    end

    depts.each do |dept|

      it "allows the user to filter users by #{dept.name}" do
        @flight_data_recorder.select_dept_report dept
      end

      it "shows all the users in #{dept.name}" do
        expected_uids = all_users.select { |u| u.depts.include? dept }.map(&:uid).sort
        visible_uids = @flight_data_recorder.list_view_uids.sort
        @flight_data_recorder.wait_until(1, "Missing: #{expected_uids - visible_uids}. Unexpected: #{visible_uids - expected_uids}") do
          visible_uids == expected_uids
        end
      end

      all_users.select { |u| u.depts.include? dept }.each do |user|

        it "shows the total number of BOA notes created by #{dept.name} UID #{user.uid}" do
          count = (advisor_data.find { |a| a[:uid] == user.uid })[:note_count]
          expect(@flight_data_recorder.advisor_note_count user).to eql(count)
        end

        it "shows the last login date for #{dept.name} UID #{user.uid}" do
          date = (advisor_data.find { |a| a[:uid] == user.uid.to_s })[:last_login]
          date = if date
                   date.strftime('%b %-d, %Y')
                 else
                   '—'
                 end
          expect(@flight_data_recorder.advisor_last_login user).to eql(date)
        end

        user.advisor_roles.each do |role|

          # TODO - include the full visible role once user roles are sussed out
          it "shows the #{dept.name} UID #{user.uid} department role #{role.inspect}" do
            expect(@flight_data_recorder.advisor_role(user, role.dept)).to include(role.dept.name)
          end
        end
      end
    end
  end

  context 'when the user is a director' do

    before(:all) do
      @homepage.dev_auth director
      @homepage.click_flight_data_recorder_link
    end

    after(:all) { @flight_data_recorder.log_out }

    it "only shows data for UID #{director.uid} departments #{director_depts.map &:name}" do
      @flight_data_recorder.wait_until(Utils.short_wait) { @flight_data_recorder.dept_heading? || @flight_data_recorder.dept_select? }
      if director_depts.length > 1
        expect(@flight_data_recorder.dept_select_option_values.sort).to eql(director_depts.map(&:code).sort)
      else
        name = director_depts.first.export_name || director_depts.first.name
        expect(@flight_data_recorder.dept_heading).to eql(name)
      end
    end

    it 'hides the complete notes report by default' do
      @flight_data_recorder.show_hide_report_button_element.when_visible Utils.short_wait
      expect(@flight_data_recorder.notes_count_boa_authors_element.visible?).to be false
    end

    it 'allows the user to view the complete notes report' do
      @flight_data_recorder.toggle_note_report_visibility
      @flight_data_recorder.notes_count_boa_authors_element.when_visible 1
    end

    director_depts.each do |dept|

      it "allows the user to filter users by #{dept.name}" do
        @flight_data_recorder.select_dept_report dept if director_depts.length > 1
      end

      it "shows all the users in #{dept.name}" do
        expected_uids = all_users.select { |u| u.depts.include? dept }.map(&:uid).sort
        visible_uids = @flight_data_recorder.list_view_uids.sort
        @flight_data_recorder.wait_until(1, "Missing: #{expected_uids - visible_uids}. Unexpected: #{visible_uids - expected_uids}") do
          visible_uids == expected_uids
        end
      end

      all_non_admin_users.select { |u| u.depts.include? dept }.each do |user|

        it "shows the total number of BOA notes created by #{dept.name} UID #{user.uid}" do
          count = (advisor_data.find { |a| a[:uid] == user.uid })[:note_count]
          expect(@flight_data_recorder.advisor_note_count user).to eql(count)
        end

        it "shows the last login date for #{dept.name} UID #{user.uid}" do
          date = (advisor_data.find { |a| a[:uid] == user.uid.to_s })[:last_login]
          date = if date
                   date.strftime('%b %-d, %Y')
                 else
                   '—'
                 end
          expect(@flight_data_recorder.advisor_last_login user).to eql(date)
        end
      end
    end
  end

  context 'when the user is an advisor' do

    before(:all) { @homepage.dev_auth advisor }

    after(:all) do
      @flight_data_recorder.hit_escape
      @flight_data_recorder.log_out
    end

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

    after(:all) do
      @flight_data_recorder.hit_escape
      @flight_data_recorder.log_out
    end

    it 'prevents the user hitting the page' do
      @flight_data_recorder.load_page scheduler.depts.first
      @flight_data_recorder.wait_for_title 'Not Found'
    end

    it 'offers no link in the header' do
      @homepage.click_header_dropdown
      expect(@homepage.flight_data_recorder_link?).to be false
    end

  end
end
