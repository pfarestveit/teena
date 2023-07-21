require_relative '../../util/spec_helper'

unless ENV['NO_DEPS']

  describe 'BOA' do

    include Logging

    test = BOACTestConfig.new
    test.filtered_admits
    existing_cohorts = BOACUtils.get_user_filtered_cohorts test.advisor, admits: true
    latest_update_date = NessieUtils.get_admit_data_update_date
    all_admit_data = NessieUtils.get_admit_page_data

    before(:all) do
      @driver = Utils.launch_browser test.chrome_profile
      @homepage = BOACHomePage.new @driver
      @cohort_page = BOACFilteredAdmitsPage.new @driver
      @admit_page = BOACAdmitPage.new @driver

      @homepage.dev_auth test.advisor
      existing_cohorts.each do |c|
        @cohort_page.load_cohort c
        @cohort_page.delete_cohort c
      end
    end

    after(:all) { Utils.quit_browser @driver }

    context 'filtered cohort search' do

      before(:each) { @cohort_page.cancel_cohort if @cohort_page.cancel_cohort_button? && @cohort_page.cancel_cohort_button_element.visible? }

      describe 'default search' do

        before(:all) do
          @all_admits = Cohort.new(id: '0', name: 'CE3 Admissions', member_data: test.searchable_data)
          @homepage.load_page
          @cohort_page.click_sidebar_all_admits
        end

        it 'shows the most recent data update date if the data is stale' do
          if Date.parse(latest_update_date) == Date.today
            expect(@cohort_page.data_update_date_heading(latest_update_date).exists?).to be false
          else
            expect(@cohort_page.data_update_date_heading(latest_update_date).exists?).to be true
          end
        end

        it 'shows a FERPA reminder and link when the advisor exports a list of all admits' do
          @cohort_page.click_export_list
          title = 'FERPA (Privacy Disclosure) - Office of the Registrar'
          expect(@cohort_page.external_link_valid?(@cohort_page.ferpa_warning_link_element, title)).to be true
        end

        it 'allows the advisor to export a list of all admits' do
          @cohort_page.click_export_ferpa_cancel
          @all_admits.export_csv = @cohort_page.export_admit_list @all_admits
          @cohort_page.verify_admits_present_in_export(all_admit_data, @all_admits.member_data, @all_admits.export_csv)
        end

        it('allows the advisor to export a list of all admits containing no email addresses') { @cohort_page.verify_no_email_in_export @all_admits.export_csv }

        it('allows the advisor to export a list of all admits with all expected data') { @cohort_page.verify_mandatory_data_in_export @all_admits.export_csv }

        it('allows the advisor to export a list of all admits with all possible data') { @cohort_page.verify_optional_data_in_export @all_admits.export_csv }
      end

      test.searches.each_with_index do |cohort, i|

        it "shows all the admits sorted by Last Name who match #{cohort.search_criteria.inspect}" do
          # Follow both paths to create admit cohorts
          if i.odd?
            @homepage.load_page
            @cohort_page.click_sidebar_create_ce3_filtered
          else
            @homepage.load_page
            @cohort_page.click_sidebar_all_admits
            @cohort_page.click_create_cohort
          end

          @cohort_page.perform_admit_search cohort
          cohort.member_data = @cohort_page.expected_admit_search_results(test, cohort.search_criteria)
          cohort.members = cohort.member_data.map { |d| BOACUser.new(sis_id: d['sid']) }
          expected_results = @cohort_page.expected_sids_by_last_name cohort.member_data
          if cohort.member_data.length.zero?
            @cohort_page.wait_until(Utils.short_wait) { @cohort_page.results_count == 0 }
          else
            @cohort_page.sort_by_last_name unless cohort.member_data.length == 1
            visible_results = @cohort_page.list_view_admit_sids cohort
            @cohort_page.wait_until(1, "Missing: #{expected_results - visible_results}. Unexpected: #{visible_results - expected_results}") do
              visible_results.sort == expected_results.sort
            end
            @cohort_page.verify_list_view_sorting(expected_results, visible_results)
          end
        end

        it("shows the most recent data update date for #{cohort.search_criteria.inspect} if the data is stale") do
          if Date.parse(latest_update_date) == Date.today
            expect(@cohort_page.data_update_date_heading(latest_update_date).exists?).to be false
          else
            expect(@cohort_page.data_update_date_heading(latest_update_date).exists?).to be true
          end
        end

        it "shows the right data for the admits who match #{cohort.search_criteria.inspect}" do
          failures = []
          visible_sids = @cohort_page.admit_cohort_row_sids
          expected_admit_data = cohort.member_data.select { |d| visible_sids.include? d[:sid] }
          expected_admit_data.each { |admit| @cohort_page.verify_admit_row_data(admit[:sid], admit, failures) }
          logger.error "Failures: #{failures}" unless failures.empty?
          expect(failures).to be_empty
        end

        it("offers an Export List button for a search #{cohort.search_criteria.inspect}") { expect(@cohort_page.export_list_button?).to be true }

        it("allows the advisor to create a cohort using #{cohort.search_criteria.inspect}") { @cohort_page.create_new_cohort cohort }

        it("shows the cohort filters for a cohort using #{cohort.search_criteria.inspect}") { @cohort_page.verify_admit_filters_present cohort if cohort.id}

        it("shows the cohort member count in the sidebar using #{cohort.search_criteria.inspect}") { @cohort_page.wait_for_sidebar_cohort_member_count cohort if cohort.id }

        it("offers no cohort history button for a cohort using #{cohort.search_criteria.inspect}") { expect(@cohort_page.history_button?).to be false }
      end

      describe 'admit cohorts' do

        before(:all) do
          @cohort = test.searches.sort_by { |c| c.members.length }.last
          @cohort_page.load_cohort @cohort
        end

        it 'can be sorted by First Name' do
          @cohort_page.sort_by_first_name
          expected_results = @cohort_page.expected_sids_by_first_name(@cohort.member_data)
          visible_results = @cohort_page.list_view_admit_sids @cohort
          @cohort_page.verify_list_view_sorting(expected_results, visible_results)
          @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
        end

        it 'can be sorted by CS ID' do
          @cohort_page.sort_by_cs_id
          expected_results = @cohort.member_data.map { |u| u[:sid].to_i }.sort
          visible_results = @cohort_page.list_view_admit_sids @cohort
          @cohort_page.verify_list_view_sorting(expected_results, visible_results)
          @cohort_page.wait_until(1, "Expected #{expected_results} but got #{visible_results}") { visible_results == expected_results }
        end

        it 'allow the advisor to export a non-zero list of admits in a cohort' do
          @cohort.export_csv = @cohort_page.export_admit_list @cohort
          @cohort_page.verify_admits_present_in_export(all_admit_data, @cohort.member_data, @cohort.export_csv)
        end

        it 'allow the advisor to export a non-zero list containing no emails for a cohort' do
          @cohort_page.verify_no_email_in_export(@cohort.export_csv)
        end

        it 'offer links to admit pages' do
          cs_id = @cohort_page.admit_cohort_row_sids.first
          @cohort_page.click_admit_link cs_id
          @admit_page.sid_element.when_visible Utils.short_wait
          expect(@admit_page.sid).to eql(cs_id)
        end
      end
    end
  end
end
