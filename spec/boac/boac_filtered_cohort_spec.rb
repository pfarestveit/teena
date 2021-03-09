require_relative '../../util/spec_helper'

if (ENV['DEPS'] || ENV['DEPS'].nil?) && !ENV['NO_DEPS']

  describe 'BOAC', order: :defined do

    include Logging

    test = BOACTestConfig.new
    test.filtered_cohorts
    pre_existing_cohorts = BOACUtils.get_user_filtered_cohorts test.advisor, default: true

    before(:all) do
      @driver = Utils.launch_browser test.chrome_profile
      @homepage = BOACHomePage.new @driver
      @cohort_page = BOACFilteredCohortPage.new(@driver, test.advisor)
      @student_page = BOACStudentPage.new @driver

      @homepage.dev_auth test.advisor
    end

    after(:all) { Utils.quit_browser @driver }

    context 'when an advisor has no filtered cohorts' do

      before(:all) do
        @homepage.load_page
        pre_existing_cohorts.each do |c|
          @cohort_page.load_cohort c
          @cohort_page.delete_cohort c
        end
      end

      it('shows a No Filtered Cohorts message on the homepage') do
        @homepage.load_page
        @homepage.no_filtered_cohorts_msg_element.when_visible Utils.short_wait
      end
    end

    context 'filtered cohort search' do

      before(:each) { @cohort_page.cancel_cohort if @cohort_page.cancel_cohort_button? && @cohort_page.cancel_cohort_button_element.visible? }

      test.searches.each do |cohort|
        it "shows all the students sorted by Last Name who match #{cohort.search_criteria.list_filters}" do
          @cohort_page.click_sidebar_create_filtered
          @cohort_page.perform_student_search cohort
          @cohort_page.set_cohort_members(cohort, test)
          expected = NessieFilterUtils.cohort_by_last_name(test, cohort.search_criteria)
          if cohort.members.empty?
            @cohort_page.wait_until(Utils.short_wait) { @cohort_page.results_count == 0 }
          else
            visible = @cohort_page.visible_sids
            @cohort_page.wait_until(1, "Missing: #{expected - visible}. Unexpected: #{visible - expected}") do
              visible.sort == expected.sort
            end
            @cohort_page.verify_list_view_sorting(expected, visible)
          end
        end

        it "shows me a query for #{cohort.search_criteria.list_filters}" do
          NessieFilterUtils.cohort_by_level(test, cohort.search_criteria)
        end

        it "shows an Export List button for search #{cohort.search_criteria.list_filters}" do
          button_enabled = @cohort_page.export_list_button_element.enabled?
          cohort.members.any? ? (expect(button_enabled).to be true) : (expect(button_enabled).to be false)
        end

        it("allows the advisor to create a cohort using #{cohort.search_criteria.list_filters}") { @cohort_page.create_new_cohort cohort }

        it("shows the cohort filters for a cohort using #{cohort.search_criteria.list_filters}") { @cohort_page.verify_student_filters_present cohort }

        it "shows the filtered cohort on the homepage with criteria #{cohort.search_criteria.list_filters}" do
          @homepage.load_page
          @homepage.wait_until(Utils.medium_wait) { @homepage.filtered_cohorts.include? cohort.name }
        end

        it "shows the filtered cohort member count with criteria #{cohort.search_criteria.list_filters}" do
          @homepage.wait_until(Utils.short_wait, "Expected #{cohort.members.length} but got #{@homepage.member_count(cohort)}") do
            @homepage.member_count(cohort) == cohort.members.length
          end
        end
      end
    end

    context 'export' do

      before(:all) do
        # For export tests, pick the most populous cohort
        @cohort = test.searches.select(&:member_count).sort_by(&:member_count).last
        @cohort_page.load_cohort @cohort
      end

      it "allows the advisor to export a non-empty list of students in a cohort" do
        parsed_csv = @cohort_page.export_student_list @cohort
        @cohort_page.verify_student_list_default_export(@cohort.members, parsed_csv)
      end

      it "allows the advisor to choose columns to include when exporting a cohort" do
        parsed_csv = @cohort_page.export_custom_student_list @cohort
        @cohort_page.verify_student_list_custom_export(@cohort.members, parsed_csv)
      end
    end

    context 'sorting' do

      before(:all) do
        # For sorting tests, pick the most populous cohort
        @cohort = test.searches.select(&:member_count).sort_by(&:member_count).last
        @cohort_page.load_cohort @cohort
      end

      it "sorts by First Name" do
        @cohort_page.sort_by_first_name
        expected = NessieFilterUtils.cohort_by_first_name(test, @cohort.search_criteria)
        @cohort_page.compare_visible_sids_to_expected expected
      end

      it "sorts by Team" do
        if [BOACDepartments::ADMIN, BOACDepartments::ASC].include? test.dept
          @cohort_page.sort_by_team
          expected = NessieFilterUtils.cohort_by_team(test, @cohort.search_criteria)
          @cohort_page.compare_visible_sids_to_expected expected
        end
      end

      it "sorts by GPA ascending" do
        @cohort_page.sort_by_gpa_cumulative
        expected = NessieFilterUtils.cohort_by_gpa_asc(test, @cohort.search_criteria)
        @cohort_page.compare_visible_sids_to_expected expected
      end

      it "sorts by GPA descending" do
        @cohort_page.sort_by_gpa_cumulative_desc
        expected = NessieFilterUtils.cohort_by_gpa_desc(test, @cohort.search_criteria)
        @cohort_page.compare_visible_sids_to_expected expected
      end

      it "sorts by GPA ascending (term #{BOACUtils.previous_term_code})" do
        term = BOACUtils.previous_term_code
        @cohort_page.sort_by_last_term_gpa term
        expected = NessieFilterUtils.cohort_by_gpa_last_term_asc(test, @cohort.search_criteria)
        @cohort_page.compare_visible_sids_to_expected expected
      end

      it "sorts by GPA descending (term #{BOACUtils.previous_term_code})" do
        term = BOACUtils.previous_term_code
        @cohort_page.sort_by_last_term_gpa_desc term
        expected = NessieFilterUtils.cohort_by_gpa_last_term_desc(test, @cohort.search_criteria)
        @cohort_page.compare_visible_sids_to_expected expected
      end

      it "sorts by GPA ascending (#{BOACUtils.previous_term_code BOACUtils.previous_term_code})" do
        term = BOACUtils.previous_term_code BOACUtils.previous_term_code
        @cohort_page.sort_by_last_term_gpa term
        expected = NessieFilterUtils.cohort_by_gpa_last_last_term_asc(test, @cohort.search_criteria)
        @cohort_page.compare_visible_sids_to_expected expected
      end

      it "sorts by GPA descending (#{BOACUtils.previous_term_code BOACUtils.previous_term_code})" do
        term = BOACUtils.previous_term_code BOACUtils.previous_term_code
        @cohort_page.sort_by_last_term_gpa_desc term
        expected = NessieFilterUtils.cohort_by_gpa_last_last_term_desc(test, @cohort.search_criteria)
        @cohort_page.compare_visible_sids_to_expected expected
      end

      it "sorts by Level" do
        @cohort_page.sort_by_level
        expected = NessieFilterUtils.cohort_by_level(test, @cohort.search_criteria)
        @cohort_page.compare_visible_sids_to_expected expected
      end

      it "sorts by Major" do
        @cohort_page.sort_by_major
        expected = NessieFilterUtils.cohort_by_major(test, @cohort.search_criteria)
        @cohort_page.compare_visible_sids_to_expected expected
      end

      it "sorts by Entering Term" do
        @cohort_page.sort_by_entering_term
        expected = NessieFilterUtils.cohort_by_matriculation(test, @cohort.search_criteria)
        @cohort_page.compare_visible_sids_to_expected expected
      end

      it "sorts by Terms in Attendance ascending" do
        @cohort_page.sort_by_terms_in_attend
        expected = NessieFilterUtils.cohort_by_terms_in_attend_asc(test, @cohort.search_criteria)
        @cohort_page.compare_visible_sids_to_expected expected
      end

      it "sorts by Terms in Attendance descending" do
        @cohort_page.sort_by_terms_in_attend_desc
        expected = NessieFilterUtils.cohort_by_terms_in_attend_desc(test, @cohort.search_criteria)
        @cohort_page.compare_visible_sids_to_expected expected
      end

      it "sorts by Units In Progress ascending" do
        @cohort_page.sort_by_units_in_progress
        expected = NessieFilterUtils.cohort_by_units_in_prog_asc(test, @cohort.search_criteria)
        @cohort_page.compare_visible_sids_to_expected expected
      end

      it "sorts by Units In Progress descending" do
        @cohort_page.sort_by_units_in_progress_desc
        expected = NessieFilterUtils.cohort_by_units_in_prog_desc(test, @cohort.search_criteria)
        @cohort_page.compare_visible_sids_to_expected expected
      end

      it "sorts by Units Completed ascending" do
        @cohort_page.sort_by_units_completed
        expected = NessieFilterUtils.cohort_by_units_complete_asc(test, @cohort.search_criteria)
        @cohort_page.compare_visible_sids_to_expected expected
      end

      it "sorts by Units Completed descending" do
        @cohort_page.sort_by_units_completed_desc
        expected = NessieFilterUtils.cohort_by_units_complete_desc(test, @cohort.search_criteria)
        @cohort_page.compare_visible_sids_to_expected expected
      end

      ### HOMEPAGE COHORTS ###

      it "shows the first 50 filtered cohort members who have alerts on the homepage" do
        @homepage.load_page
        @homepage.expand_member_rows @cohort
        @homepage.verify_member_alerts(@cohort, test.advisor)
      end

      it "by default sorts by alert count descending the first 50 cohort members who have alerts on the homepage" do
        expected_sequence = @homepage.expected_sids_by_alerts_desc @cohort.members
        @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids @cohort}") do
          @homepage.all_row_sids(@cohort) == expected_sequence
        end
      end

      it "allows the advisor to sort by alert count ascending the first 50 cohort members who have alerts on the homepage" do
        expected_sequence = @homepage.expected_sids_by_alerts @cohort.members
        @homepage.sort_by_alert_count @cohort
        @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids @cohort}") { @homepage.all_row_sids(@cohort) == expected_sequence }
      end

      it "allows the advisor to sort by name ascending cohort the first 50 members who have alerts on the homepage" do
        expected_sequence = NessieFilterUtils.list_by_last_name_asc @cohort.members.map &:sis_id
        @homepage.sort_by_name @cohort
        @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids @cohort}") do
          @homepage.all_row_sids(@cohort) == expected_sequence
        end
      end

      it "allows the advisor to sort by name descending the first 50 cohort members who have alerts on the homepage" do
        expected_sequence = NessieFilterUtils.list_by_last_name_desc @cohort.members.map &:sis_id
        @homepage.sort_by_name @cohort
        @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids @cohort}") do
          @homepage.all_row_sids(@cohort) == expected_sequence
        end
      end

      it "allows the advisor to sort by SID ascending the first 50 cohort members who have alerts on the homepage" do
        expected_sequence = @cohort.members.map(&:sis_id).sort
        @homepage.sort_by_sid @cohort
        @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids @cohort}") do
          @homepage.all_row_sids(@cohort) == expected_sequence
        end
      end

      it "allows the advisor to sort by SID descending the first 50 cohort members who have alerts on the homepage" do
        expected_sequence = @cohort.members.map(&:sis_id).sort.reverse
        @homepage.sort_by_sid @cohort
        @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids @cohort}") do
          @homepage.all_row_sids(@cohort) == expected_sequence
        end
      end

      it "allows the advisor to sort by major ascending the first 50 cohort members who have alerts on the homepage" do
        expected_sequence = NessieFilterUtils.list_by_major_asc @cohort.members.map &:sis_id
        @homepage.sort_by_major @cohort
        @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids @cohort}") do
          @homepage.all_row_sids(@cohort) == expected_sequence
        end
      end

      it "allows the advisor to sort by major descending the first 50 cohort members who have alerts on the homepage" do
        expected_sequence = NessieFilterUtils.list_by_major_desc @cohort.members.map &:sis_id
        @homepage.sort_by_major @cohort
        @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids @cohort}") do
          @homepage.all_row_sids(@cohort) == expected_sequence
        end
      end

      it "allows the advisor to sort by expected grad date ascending the first 50 cohort members who have alerts on the homepage" do
        expected_sequence = NessieFilterUtils.list_by_grad_term_asc @cohort.members.map &:sis_id
        @homepage.sort_by_expected_grad @cohort
        @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids @cohort}") do
          @homepage.all_row_sids(@cohort) == expected_sequence
        end
      end

      it "allows the advisor to sort by expected grad date descending the first 50 cohort members who have alerts on the homepage" do
        expected_sequence = NessieFilterUtils.list_by_grad_term_desc @cohort.members.map &:sis_id
        @homepage.sort_by_expected_grad @cohort
        @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids @cohort}") do
          @homepage.all_row_sids(@cohort) == expected_sequence
        end
      end

      it "allows the advisor to sort by term units ascending the first 50 cohort members who have alerts on the homepage" do
        expected_sequence = NessieFilterUtils.list_by_units_in_prog_asc @cohort.members.map &:sis_id
        @homepage.sort_by_term_units @cohort
        @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids @cohort}") do
          @homepage.all_row_sids(@cohort) == expected_sequence
        end
      end

      it "allows the advisor to sort by term units descending the first 50 cohort members who have alerts on the homepage" do
        expected_sequence = NessieFilterUtils.list_by_units_in_prog_desc @cohort.members.map &:sis_id
        @homepage.sort_by_term_units @cohort
        @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids @cohort}") do
          @homepage.all_row_sids(@cohort) == expected_sequence
        end
      end

      it "allows the advisor to sort by cumulative units ascending the first 50 cohort members who have alerts on the homepage" do
        expected_sequence = NessieFilterUtils.list_by_units_complete_asc @cohort.members.map &:sis_id
        @homepage.sort_by_cumul_units @cohort
        @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids @cohort}") do
          @homepage.all_row_sids(@cohort) == expected_sequence
        end
      end

      it "allows the advisor to sort by cumulative descending the first 50 cohort members who have alerts on the homepage" do
        expected_sequence = NessieFilterUtils.list_by_units_complete_desc @cohort.members.map &:sis_id
        @homepage.sort_by_cumul_units @cohort
        @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids @cohort}") do
          @homepage.all_row_sids(@cohort) == expected_sequence
        end
      end

      it "allows the advisor to sort by GPA ascending the first 50 cohort members who have alerts on the homepage" do
        expected_sequence = NessieFilterUtils.list_by_gpa_asc @cohort.members.map &:sis_id
        @homepage.sort_by_gpa @cohort
        @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids @cohort}") do
          @homepage.all_row_sids(@cohort) == expected_sequence
        end
      end

      it "allows the advisor to sort by GPA descending the first 50 cohort members who have alerts on the homepage" do
        expected_sequence = NessieFilterUtils.list_by_gpa_desc @cohort.members.map &:sis_id
        @homepage.sort_by_gpa @cohort
        @homepage.wait_until(1, "Expected #{expected_sequence}, but got #{@homepage.all_row_sids @cohort}") do
          @homepage.all_row_sids(@cohort) == expected_sequence
        end
      end

      it "offers a link to the filtered cohort" do
        @homepage.click_filtered_cohort @cohort
        @cohort_page.cohort_heading(@cohort).when_visible Utils.medium_wait
      end
    end

    context 'validation' do

      it 'requires a title' do
        @homepage.click_sidebar_create_filtered
        @cohort_page.perform_student_search test.searches.first
        @cohort_page.click_save_cohort_button_one
        expect(@cohort_page.save_cohort_button_two_element.disabled?).to be true
      end

      it 'truncates a title over 255 characters' do
        cohort = FilteredCohort.new({name: "#{test.id}#{'A loooooong title ' * 15}?"})
        @homepage.load_page
        @homepage.click_sidebar_create_filtered
        @cohort_page.perform_student_search test.searches.first
        @cohort_page.save_and_name_cohort cohort
        cohort.name = cohort.name[0..254]
        @cohort_page.wait_for_filtered_cohort cohort
        test.searches << cohort
      end

      it 'requires that a title be unique among the user\'s existing cohorts' do
        cohort = FilteredCohort.new({name: test.searches.first.name})
        @cohort_page.click_sidebar_create_filtered
        @cohort_page.perform_student_search test.searches.first
        @cohort_page.save_and_name_cohort cohort
        @cohort_page.dupe_filtered_name_msg_element.when_visible Utils.short_wait
      end
    end

    context 'when the advisor views its cohorts' do

      it('shows only the advisor\'s cohorts on the homepage') do
        test.searches.flatten!
        @homepage.load_page
        @homepage.wait_until(Utils.short_wait) { @homepage.filtered_cohorts.any? }
        expected = (test.searches.map &:name).sort
        @homepage.wait_until(1, "Missing #{expected - @homepage.filtered_cohorts.sort}, unexpected #{@homepage.filtered_cohorts.sort - expected}") do
          @homepage.filtered_cohorts.sort == expected
        end
      end
    end

    context 'when the advisor enters invalid filter input' do

      shared_examples 'GPA range validation' do |filter_name|

        before(:each) do
          @homepage.click_sidebar_create_filtered
          @cohort_page.select_new_filter_option filter_name
        end

        it 'an error prompts for numeric input' do
          @cohort_page.select_new_filter_sub_option(filter_name, {'min' => 'A', 'max' => ''})
          @cohort_page.gpa_filter_range_error_element.when_visible 1
        end

        it 'an error prompts for logical numeric input' do
          @cohort_page.select_new_filter_sub_option(filter_name, {'min' => '4', 'max' => '0'})
          @cohort_page.gpa_filter_logical_error_element.when_visible 1
        end

        it 'an error prompts for numeric input from 0 to 4' do
          @cohort_page.select_new_filter_sub_option(filter_name, {'min' => '-1', 'max' => '5'})
          @cohort_page.gpa_filter_range_error_element.when_visible 1
        end

        it 'no Add button appears without two valid values' do
          @cohort_page.select_new_filter_sub_option(filter_name, {'min' => '3.5', 'max' => ''})
          expect(@cohort_page.unsaved_filter_add_button?).to be false
        end
      end

      context 'in the cumulative GPA filter' do
        include_examples 'GPA range validation', 'GPA (Cumulative)'
      end

      context 'in the term GPA filter' do
        include_examples 'GPA range validation', 'GPA (Last Term)'
      end

      context 'in the Last Name filter' do

        before(:all) do
          @cohort_page.unsaved_filter_cancel_button
          @cohort_page.select_new_filter_option 'Last Name'
        end

        it 'an error prompts for logical input' do
          @cohort_page.select_new_filter_sub_option('Last Name', {'min' => 'Z', 'max' => 'A'})
          @cohort_page.last_name_filter_logical_error_element.when_visible 1
        end

        it 'no Add button appears without two valid values' do
          @cohort_page.select_new_filter_sub_option('Last Name', {'min' => 'P', 'max' => ''})
          expect(@cohort_page.unsaved_filter_add_button?).to be false
        end
      end
    end

    context 'when the advisor edits a cohort\'s search filters' do

      before(:all) { @cohort_page.search_and_create_new_cohort(test.default_cohort, default: true) }

      before(:each) do
        if @cohort_page.cohort_update_button?
          @cohort_page.wait_for_update_and_click @cohort_page.cohort_update_cancel_button_element
        end
      end

      it 'allows the advisor to edit an Academic Standing filter' do
        test.default_cohort.search_criteria.academic_standing = ['Good Standing']
        @cohort_page.edit_filter('Academic Standing', test.default_cohort.search_criteria.academic_standing.first)
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove an Academic Standing filter' do
        test.default_cohort.search_criteria.academic_standing.shift
        @cohort_page.remove_filter_of_type 'Academic Standing'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to edit a College filter' do
        test.default_cohort.search_criteria.college = ['Undergrad Chemistry']
        @cohort_page.edit_filter('College', test.default_cohort.search_criteria.college.first)
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove a College filter' do
        test.default_cohort.search_criteria.college.shift
        @cohort_page.remove_filter_of_type 'College'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to edit a cumulative GPA filter' do
        test.default_cohort.search_criteria.gpa = [{'min' => '3.00', 'max' => '4'}]
        @cohort_page.edit_filter('GPA (Cumulative)', test.default_cohort.search_criteria.gpa.first)
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove a cumulative GPA filter' do
        test.default_cohort.search_criteria.gpa.shift
        @cohort_page.remove_filter_of_type 'GPA (Cumulative)'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to edit a term GPA filter' do
        test.default_cohort.search_criteria.gpa_last_term = [{'min' => '2', 'max' => '3.80'}]
        @cohort_page.edit_filter('GPA (Last Term)', test.default_cohort.search_criteria.gpa_last_term.first)
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove a term GPA filter' do
        test.default_cohort.search_criteria.gpa_last_term.shift
        @cohort_page.remove_filter_of_type 'GPA (Last Term)'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove a Holds filter' do
        test.default_cohort.search_criteria.holds = nil
        @cohort_page.remove_filter_of_type 'Holds'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to edit a Level filter' do
        test.default_cohort.search_criteria.level = ['30']
        @cohort_page.edit_filter('Level', test.default_cohort.search_criteria.level.first)
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove a Level filter' do
        test.default_cohort.search_criteria.level.shift
        @cohort_page.remove_filter_of_type 'Level'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to edit a Units Completed filter' do
        test.default_cohort.search_criteria.units_completed = ['60 - 89']
        @cohort_page.edit_filter('Units Completed', test.default_cohort.search_criteria.units_completed.first)
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove a Units Completed filter' do
        test.default_cohort.search_criteria.units_completed.shift
        @cohort_page.remove_filter_of_type 'Units Completed'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to edit an Intended Major filter' do
        test.default_cohort.search_criteria.intended_major = ['History BA']
        @cohort_page.edit_filter('Intended Major', test.default_cohort.search_criteria.intended_major.first)
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove an Intended Major filter' do
        test.default_cohort.search_criteria.intended_major.shift
        @cohort_page.remove_filter_of_type 'Intended Major'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to edit a Major filter' do
        test.default_cohort.search_criteria.major = ['Bioengineering BS']
        @cohort_page.edit_filter('Major', test.default_cohort.search_criteria.major.first)
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove a Major filter' do
        test.default_cohort.search_criteria.major.shift
        @cohort_page.remove_filter_of_type 'Major'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to edit a Minor filter' do
        test.default_cohort.search_criteria.minor = ['History UG']
        @cohort_page.edit_filter('Minor', test.default_cohort.search_criteria.minor.first)
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove a Minor filter' do
        test.default_cohort.search_criteria.minor.shift
        @cohort_page.remove_filter_of_type 'Minor'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove a Transfer Student filter' do
        test.default_cohort.search_criteria.transfer_student = nil
        @cohort_page.remove_filter_of_type 'Transfer Student'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to edit an Entering Term filter' do
        new_term_id = (test.default_cohort.search_criteria.entering_terms.first.to_i - 10).to_s
        test.default_cohort.search_criteria.entering_terms = [new_term_id]
        @cohort_page.edit_filter('Entering Term', test.default_cohort.search_criteria.entering_terms.first)
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove an Entering Term filter' do
        test.default_cohort.search_criteria.entering_terms.shift
        @cohort_page.remove_filter_of_type 'Entering Term'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to edit an Expected Graduation Term filter' do
        new_term_id = (test.default_cohort.search_criteria.expected_grad_terms.first.to_i + 10).to_s
        test.default_cohort.search_criteria.expected_grad_terms = [new_term_id]
        @cohort_page.edit_filter('Expected Graduation Term', test.default_cohort.search_criteria.expected_grad_terms.first)
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove an Expected Graduation Term filter' do
        test.default_cohort.search_criteria.expected_grad_terms.shift
        @cohort_page.remove_filter_of_type 'Expected Graduation Term'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove an Unrepresented Minority filter' do
        test.default_cohort.search_criteria.underrepresented_minority = nil
        @cohort_page.remove_filter_of_type 'Underrepresented Minority'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to edit an Ethnicity filter' do
        test.default_cohort.search_criteria.ethnicity = ['Thai']
        @cohort_page.edit_filter('Ethnicity', test.default_cohort.search_criteria.ethnicity.first)
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove an Ethnicity filter' do
        test.default_cohort.search_criteria.ethnicity.shift
        @cohort_page.remove_filter_of_type 'Ethnicity'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to edit a Visa Type filter' do
        test.default_cohort.search_criteria.visa_type = ['Permanent Resident']
        @cohort_page.edit_filter('Visa Type', test.default_cohort.search_criteria.visa_type.first)
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove a Visa Type filter' do
        test.default_cohort.search_criteria.visa_type.shift
        @cohort_page.remove_filter_of_type 'Visa Type'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to edit a Gender filter' do
        test.default_cohort.search_criteria.gender = ['Female']
        @cohort_page.edit_filter('Gender', test.default_cohort.search_criteria.gender.first)
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove a Gender filter' do
        test.default_cohort.search_criteria.gender.shift
        @cohort_page.remove_filter_of_type 'Gender'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to edit an Ethnicity (COE) filter' do
        test.default_cohort.search_criteria.coe_ethnicity = ['E']
        @cohort_page.edit_filter('Ethnicity (COE)', test.default_cohort.search_criteria.coe_ethnicity.first)
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove an Ethnicity (COE) filter' do
        test.default_cohort.search_criteria.coe_ethnicity.shift
        @cohort_page.remove_filter_of_type 'Ethnicity (COE)'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to edit a Gender (COE) filter' do
        test.default_cohort.search_criteria.coe_gender = ['M']
        @cohort_page.edit_filter('Gender (COE)', test.default_cohort.search_criteria.coe_gender.first)
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove a Gender (COE) filter' do
        test.default_cohort.search_criteria.coe_gender.shift
        @cohort_page.remove_filter_of_type 'Gender (COE)'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove an Underrepresented Minority (COE) filter' do
        test.default_cohort.search_criteria.coe_underrepresented_minority = false
        @cohort_page.remove_filter_of_type 'Underrepresented Minority (COE)'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove an Inactive (ASC) filter' do
        test.default_cohort.search_criteria.asc_inactive = nil
        @cohort_page.remove_filter_of_type 'Inactive (ASC)'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove an Intensive (ASC) filter' do
        test.default_cohort.search_criteria.asc_intensive = false
        @cohort_page.remove_filter_of_type 'Intensive (ASC)'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to edit a Team (ASC) filter' do
        test.default_cohort.search_criteria.asc_team = [Squad::WCR]
        @cohort_page.edit_filter('Team (ASC)', test.default_cohort.search_criteria.asc_team.first.name)
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove a Team (ASC) filter' do
        test.default_cohort.search_criteria.asc_team.shift
        @cohort_page.remove_filter_of_type 'Team (ASC)'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to edit a PREP (COE) filter' do
        test.default_cohort.search_criteria.coe_prep = ['T-PREP']
        @cohort_page.edit_filter('PREP (COE)', test.default_cohort.search_criteria.coe_prep.first)
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove a PREP (COE) filter' do
        test.default_cohort.search_criteria.coe_prep.shift
        @cohort_page.remove_filter_of_type 'PREP (COE)'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to edit a Last Name filter' do
        test.default_cohort.search_criteria.last_name = [{'min' => 'B', 'max' => 'Y'}]
        @cohort_page.edit_filter('Last Name', test.default_cohort.search_criteria.last_name.first)
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove a Last Name filter' do
        test.default_cohort.search_criteria.last_name = nil
        @cohort_page.remove_filter_of_type 'Last Name'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to edit a My Students filter' do
        if test.default_cohort.search_criteria.cohort_owner_academic_plans
          test.default_cohort.search_criteria.cohort_owner_academic_plans = ['*']
          @cohort_page.edit_filter('My Students', '*')
          @cohort_page.verify_student_filters_present test.default_cohort
        else
          logger.warn 'Skipping test for editing My Students since the filter is not available to the user'
        end
      end

      it 'allows the advisor to remove a My Students filter' do
        if test.default_cohort.search_criteria.cohort_owner_academic_plans
          test.default_cohort.search_criteria.cohort_owner_academic_plans.shift
          @cohort_page.remove_filter_of_type 'My Students'
          @cohort_page.verify_student_filters_present test.default_cohort
        else
          logger.warn 'Skipping test for removing My Students since the filter is not available to the user'
        end
      end

      it 'allows the advisor to edit an Advisor (COE) filter' do
        test.default_cohort.search_criteria.coe_advisor = [BOACUtils.get_dept_advisors(BOACDepartments::COE).last.uid.to_s]
        @cohort_page.edit_filter('Advisor (COE)', test.default_cohort.search_criteria.coe_advisor.first)
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove an Advisor (COE) filter' do
        test.default_cohort.search_criteria.coe_advisor.shift
        @cohort_page.remove_filter_of_type 'Advisor (COE)'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove an Inactive (CoE) filter' do
        test.default_cohort.search_criteria.coe_inactive = nil
        @cohort_page.remove_filter_of_type 'Inactive (COE)'
        @cohort_page.verify_student_filters_present test.default_cohort
      end

      it 'allows the advisor to remove a Probation (COE) filter' do
        test.default_cohort.search_criteria.coe_probation = nil
        @cohort_page.remove_filter_of_type 'Probation (COE)'
      end
    end

    context 'when the advisor edits a cohort\'s name' do

      it 'renames the existing cohort' do
        cohort = test.searches.first
        id = cohort.id
        @cohort_page.rename_cohort(cohort, "#{cohort.name} - Renamed")
        expect(cohort.id).to eql(id)
      end
    end

    context 'when the advisor deletes a cohort and tries to navigate to the deleted cohort' do

      before(:all) do
        @cohort_page.load_cohort test.searches.first
        @cohort_page.delete_cohort test.searches.first
      end

      it 'shows a Not Found page' do
        @cohort_page.navigate_to "#{BOACUtils.base_url}/cohort/#{test.searches.first.id}"
        @cohort_page.wait_for_title 'Page not found'
      end
    end

  end
end
