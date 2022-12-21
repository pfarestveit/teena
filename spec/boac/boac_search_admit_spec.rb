require_relative '../../util/spec_helper'

unless ENV['DEPS']

  test = BOACTestConfig.new
  test.search_admits
  auth_users = BOACUtils.get_authorized_users.select { |a| a.active && !a.is_blocked }
  latest_update_date = NessieUtils.get_admit_data_update_date

  describe 'CE3 admit search' do

    include Logging

    begin

      @driver = Utils.launch_browser
      @homepage = BOACHomePage.new @driver
      @search_results_page = BOACSearchResultsPage.new @driver
      @admit_page = BOACAdmitPage.new @driver

      advisor = auth_users.find { |u| !u.is_admin && !u.depts.include?(BOACDepartments::ZCEEE) }
      @homepage.dev_auth advisor
      @homepage.expand_search_options
      non_ce3_cbx_visible = @homepage.include_admits_cbx?
      it('is not available to a non-CE3, non-admin user') { expect(non_ce3_cbx_visible).to be false }

      admin = auth_users.find { |u| u.is_admin && !u.depts.include?(BOACDepartments::ZCEEE) }
      @homepage.log_out
      @homepage.dev_auth admin
      @homepage.expand_search_options
      admin_cbx_visible = @homepage.verify_block { @homepage.include_admits_cbx_element.when_visible Utils.short_wait }
      it('is available to an admin user') { expect(admin_cbx_visible).to be true }

      @homepage.log_out
      @homepage.dev_auth test.advisor
      @homepage.expand_search_options
      ce3_cbx_visible = @homepage.verify_block { @homepage.include_admits_cbx_element.when_visible Utils.short_wait }
      it('is available to a CE3 user') { expect(ce3_cbx_visible).to be true }

      @homepage.exclude_admits
      @homepage.type_non_note_string_and_enter test.test_students.first.sis_id
      @homepage.wait_for_spinner
      ce3_excluded = @search_results_page.verify_block do
        !@search_results_page.admit_results_count?
        @search_results_page.search_result_all_row_cs_ids.empty?
      end
      it('can be excluded from results') { expect(ce3_excluded).to be true }

      @homepage.include_admits
      test.test_students.each do |admit|

        begin
          @homepage.load_page

          # SEARCHES

          @homepage.type_non_note_string_and_enter admit.first_name
          complete_first_results = @search_results_page.admit_in_search_result? admit
          it("finds CS ID #{admit.sis_id} with the complete first name") { expect(complete_first_results).to be true }

          @homepage.type_non_note_string_and_enter admit.first_name[0..2]
          partial_first_results = @search_results_page.admit_in_search_result? admit
          it("finds CS ID #{admit.sis_id} with a partial first name") { expect(partial_first_results).to be true }

          @homepage.type_non_note_string_and_enter admit.last_name
          complete_last_results = @search_results_page.admit_in_search_result? admit
          it("finds CS ID #{admit.sis_id} with the complete last name") { expect(complete_last_results).to be true }

          @homepage.type_non_note_string_and_enter admit.last_name[0..2]
          partial_last_results = @search_results_page.admit_in_search_result? admit
          it("finds CS ID #{admit.sis_id} with a partial last name") { expect(partial_last_results).to be true }

          @homepage.type_non_note_string_and_enter "#{admit.first_name} #{admit.last_name}"
          complete_first_last_results = @search_results_page.admit_in_search_result? admit
          it("finds CS ID #{admit.sis_id} with the complete first and last name") { expect(complete_first_last_results).to be true }

          @homepage.type_non_note_string_and_enter "#{admit.last_name}, #{admit.first_name}"
          complete_last_first_results = @search_results_page.admit_in_search_result? admit
          it("finds CS ID #{admit.sis_id} with the complete last and first name") { expect(complete_last_first_results).to be true }

          @homepage.type_non_note_string_and_enter "#{admit.first_name[0..2]} #{admit.last_name[0..2]}"
          partial_first_last_results = @search_results_page.admit_in_search_result? admit
          it("finds CS ID #{admit.sis_id} with a partial first and last name") { expect(partial_first_last_results).to be true }

          @homepage.type_non_note_string_and_enter "#{admit.last_name[0..2]}, #{admit.first_name[0..2]}"
          partial_last_first_results = @search_results_page.admit_in_search_result? admit
          it("finds CS ID #{admit.sis_id} with a partial last and first name") { expect(partial_last_first_results).to be true }

          @homepage.type_non_note_string_and_enter admit.sis_id.to_s[0..4]
          partial_sid_results = @search_results_page.admit_in_search_result? admit
          it("finds CS ID #{admit.sis_id} with a partial SID") { expect(partial_sid_results).to be true }

          @homepage.type_non_note_string_and_enter admit.sis_id.to_s
          complete_sid_results = @search_results_page.admit_in_search_result? admit
          it("finds CS ID #{admit.sis_id} with the complete SID") { expect(complete_sid_results).to be true }

          # VISIBLE ADMIT DATA

          admit_data = test.searchable_data.find { |d| d[:sid] == admit.sis_id }
          visible_row_data = @search_results_page.visible_admit_row_data admit.sis_id

          it("shows the name for CS ID #{admit.sis_id}") { expect(visible_row_data[:name]).to include(admit.last_name) }
          it("shows the CS ID for CS ID #{admit.sis_id}") { expect(visible_row_data[:cs_id]).to eql(admit.sis_id) }
          it("shows the CEP status for CS ID #{admit.sis_id}") { expect(visible_row_data[:cep]).to eql("#{admit_data[:special_program_cep]}") }
          it("shows the Re-entry status for CS ID #{admit.sis_id}") { expect(visible_row_data[:re_entry]).to eql("#{admit_data[:re_entry_status]}") }
          it("shows the 1st Gen College status for CS ID #{admit.sis_id}") { expect(visible_row_data[:first_gen]).to eql("#{admit_data[:first_gen_college]}") }
          it("shows the UREM status for CS ID #{admit.sis_id}") { expect(visible_row_data[:urem]).to eql("#{admit_data[:urem]}") }
          it("shows the Fee Waiver status for CS ID #{admit.sis_id}") { expect(visible_row_data[:waiver]).to eql("#{admit_data[:fee_waiver]}") }
          it("shows the Freshman/Transfer status for CS ID #{admit.sis_id}") { expect(visible_row_data[:fresh_trans]).to eql("#{admit_data[:freshman_or_transfer]}") }
          it("shows the International status for CS ID #{admit.sis_id}") { expect(visible_row_data[:intl]).to eql("#{admit_data[:intl]}") }

          update_date_present = @search_results_page.data_update_date_heading(latest_update_date).exists?
          if Date.parse(latest_update_date) == Date.today
            it("shows no data update date for CS ID #{admit.sis_id}") { expect(update_date_present).to be false }
          else
            it("shows the latest data update date for CS ID #{admit.sis_id}") { expect(update_date_present).to be true }
          end

          @search_results_page.click_admit_link admit.sis_id
          link_works = @admit_page.verify_block { @admit_page.sid_element.when_visible Utils.short_wait }
          it("offers links to admit pages for CS ID #{admit.sis_id}") { expect(link_works).to be true }

          @admit_page.go_back
          back_button_works = @search_results_page.verify_block { @search_results_page.admit_in_search_result? admit }
          it("can be reloaded using the Back button on an admit page for CS ID #{admit.sis_id}") { expect(back_button_works).to be true }

        rescue => e
          Utils.log_error e
          it("test hit an error with admit CS ID #{admit.sis_id}") { fail }
        end
      end
    rescue => e
      Utils.log_error e
      it('test hit an error initializing') { fail }
    ensure
      Utils.quit_browser @driver
    end
  end
end
