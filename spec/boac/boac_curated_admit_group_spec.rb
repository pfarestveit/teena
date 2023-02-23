require_relative '../../util/spec_helper'

unless ENV['NO_DEPS']

  describe 'BOAC' do

    test = BOACTestConfig.new
    test.curated_admits
    latest_update_date = NessieUtils.get_admit_data_update_date
    all_admit_data = NessieUtils.get_admit_page_data

    # Initialize groups to be used later in the tests
    advisor_groups = [
      (group_1 = CuratedGroup.new({name: "Group 1 #{test.id}", ce3: true})),
      (group_2 = CuratedGroup.new({name: "Group 2 #{test.id}", ce3: true})),
      (group_3 = CuratedGroup.new({name: "Group 3 #{test.id}", ce3: true})),
      (group_4 = CuratedGroup.new({name: "Group 4 #{test.id}", ce3: true})),
      (group_5 = CuratedGroup.new({name: "Group 5 #{test.id}", ce3: true})),
      (group_6 = CuratedGroup.new({name: "Group 6 #{test.id}", ce3: true}))
    ]
    pre_existing_groups = BOACUtils.get_user_curated_groups test.advisor
    pre_existing_cohorts = BOACUtils.get_user_filtered_cohorts(test.advisor, {admits: true})

    before(:all) do
      @driver = Utils.launch_browser test.chrome_profile
      @homepage = BOACHomePage.new @driver
      @group_page = BOACGroupAdmitsPage.new @driver
      @cohort_page = BOACFilteredAdmitsPage.new @driver
      @admit_page = BOACAdmitPage.new @driver
      @search_page = BOACSearchResultsPage.new @driver
      @cohort = test.searches.first
      @admit = test.admits.shuffle.first

      @homepage.dev_auth test.advisor

      pre_existing_cohorts.each do |c|
        @cohort_page.load_cohort c
        @cohort_page.delete_cohort c
      end
      @cohort_page.search_and_create_new_cohort(@cohort, admits: true)
    end

    it 'admit groups can all be deleted' do
      pre_existing_groups.each do |c|
        @group_page.load_page c
        @group_page.delete_cohort c
      end
    end

    describe 'admit group creation' do

      it 'can be done using the admit cohort list view group selector' do
        @cohort_page.load_cohort @cohort
        @cohort_page.wait_for_admit_checkboxes
        sids = @cohort_page.admit_cohort_row_sids
        visible_members = test.admits.select { |m| sids.include? m.sis_id }
        group = CuratedGroup.new name: "CE3 group from cohort #{test.id}", ce3: true
        @cohort_page.select_and_add_admits_to_new_ce3_grp(visible_members.last(10), group)
      end

      it 'can be done using the admit search results group selector' do
        @homepage.type_non_note_simple_search_and_enter @admit.sis_id
        group = CuratedGroup.new name: "CE3 group from search #{test.id}", ce3: true
        @search_page.select_and_add_admits_to_new_ce3_grp([@admit], group)
      end

      it 'can be done using the admit page group selector' do
        @admit_page.load_page @admit.sis_id
        group = CuratedGroup.new name: "CE3 group from profile #{test.id}", ce3: true
        @admit_page.add_admit_to_new_ce3_grp(@admit, group)
      end

      it 'can be done using bulk SIDs feature' do
        admits = test.admits.first 52
        @admit_page.click_sidebar_create_admit_group
        group = CuratedGroup.new name: "CE3 group from CS IDs #{test.id}", ce3: true
        @group_page.create_group_with_bulk_sids(admits, group)
      end
    end

    describe 'admit group names' do

      before(:all) { @group = CuratedGroup.new({ce3: true}) }
      before(:each) { @admit_page.cancel_group if @admit_page.grp_cancel_button_element.visible? }

      it 'are required' do
        @admit_page.load_page @admit.sis_id
        @admit_page.click_add_to_ce3_grp_button
        @admit_page.click_create_new_ce3_grp
        expect(@admit_page.grp_save_button_element.disabled?).to be true
      end

      it 'are truncated to 255 characters' do
        @group.name = "#{'A llooooong title ' * 15}?"
        @admit_page.click_add_to_ce3_grp_button
        @admit_page.click_create_new_ce3_grp
        @admit_page.enter_group_name @group
        @admit_page.no_chars_left_msg_element.when_present 1
      end

      it 'must be unique among the advisor\'s groups' do
        @group.name = @cohort.name
        @admit_page.click_add_to_ce3_grp_button
        @admit_page.click_create_new_ce3_grp
        @admit_page.name_and_save_group @group
        @admit_page.dupe_filtered_name_msg_element.when_visible Utils.short_wait
      end

      it 'can be changed' do
        @group.name = "CE3 Name Validation #{test.id}"
        @admit_page.add_admit_to_new_ce3_grp(@admit, @group)
        @group_page.load_page @group
        @group_page.rename_grp(@group, "Renamed #{@group.name}")
      end
    end

    describe 'admit group membership' do

      before(:all) do
        admit = test.admits.last
        @admit_page.load_page admit.sis_id
        advisor_groups.each { |grp| @admit_page.add_admit_to_new_ce3_grp(admit, grp) }
      end

      it 'can be added from admit cohort list view using select-all' do
        @cohort_page.load_cohort @cohort
        admits_to_add = @cohort_page.admits_available_to_add_to_grp(test, group_1)
        @cohort_page.select_and_add_all_admits_to_ce3_grp(admits_to_add, group_1)
        @group_page.load_page group_1
        expect(@group_page.list_view_admit_sids(group_1).sort).to eql(group_1.members.map(&:sis_id).sort)
      end

      it 'can be added from admit cohort list view using individual selections' do
        @cohort_page.load_cohort @cohort
        admits_to_add = @cohort_page.admits_available_to_add_to_grp(test, group_2)
        @cohort_page.select_and_add_admits_to_ce3_grp(admits_to_add[0..-2], group_2)
        @group_page.load_page group_2
        expect(@group_page.list_view_admit_sids(group_2).sort).to eql(group_2.members.map(&:sis_id).sort)
      end

      it 'can be added on the admit page' do
        @admit_page.load_page @admit.sis_id
        @admit_page.add_admit_to_ce3_grp(@admit, group_3)
        @group_page.load_page group_3
        expect(@group_page.list_view_admit_sids(group_3).sort).to eql(group_3.members.map(&:sis_id).sort)
      end

      it 'can be added on the bulk-add-SIDs page' do
        @group_page.load_page group_4
        @group_page.add_comma_sep_sids_to_existing_grp(test.admits.last(10), group_4)
        expect(@group_page.list_view_admit_sids(group_4).sort).to eql(group_4.members.map(&:sis_id).sort)
      end

      it 'can be added on admit search results using select-all' do
        @homepage.type_non_note_simple_search_and_enter @admit.sis_id
        admits_to_add = @search_page.admits_available_to_add_to_grp(test, group_5)
        @search_page.select_and_add_all_admits_to_ce3_grp(admits_to_add, group_5)
        @group_page.load_page group_5
        expect(@group_page.list_view_admit_sids(group_5).sort).to eql(group_5.members.map(&:sis_id).sort)
      end

      it 'can be added on admit search results using individual selections' do
        @homepage.type_non_note_simple_search_and_enter @admit.sis_id
        @search_page.select_and_add_admits_to_ce3_grp([@admit], group_6)
        @group_page.load_page group_6
        expect(@group_page.list_view_admit_sids(group_6).sort).to eql(group_6.members.map(&:sis_id).sort)
      end

      it 'is shown on the admit page' do
        @admit_page.load_page group_1.members.first.sis_id
        @admit_page.click_add_to_ce3_grp_button
        expect(@admit_page.ce3_grp_selected? group_1).to be true
      end

      it 'can be removed on the group list view page' do
        @group_page.load_page group_2
        admit = group_2.members.last
        @group_page.remove_admit_by_row_index(group_2, admit)
      end

      it 'can be removed on the admit page using the group checkbox' do
        @admit_page.load_page group_1.members.last.sis_id
        @admit_page.remove_admit_from_ce3_grp(group_1.members.last, group_1)
        @group_page.load_page group_1
        expect(@group_page.list_view_admit_sids(group_1).sort).to eql(group_1.members.map(&:sis_id).sort)
      end
    end

    describe 'admit group bulk-add SIDs' do

      before(:each) { @group_page.load_page group_4 }

      it 'rejects malformed input' do
        @group_page.load_page group_4
        @group_page.click_add_sids_button
        @group_page.enter_sid_list(@group_page.create_group_textarea_sids_element, 'nullum magnum ingenium sine mixtura dementiae fuit')
        @group_page.click_add_sids_to_group_button
        @group_page.click_remove_invalid_sids
      end

      it 'rejects SIDs that do not match any BOA admit SIDs' do
        @group_page.click_add_sids_button
        @group_page.enter_sid_list(@group_page.create_group_textarea_sids_element,  '9999999990, 9999999991')
        @group_page.click_add_sids_to_group_button
        @group_page.click_remove_invalid_sids
      end

      it 'allows the user to remove rejected SIDs automatically' do
        a = [test.admits.last.sis_id]
        2.times { |i| a << "99999999#{10 + i}" }
        @group_page.click_add_sids_button
        @group_page.enter_sid_list(@group_page.create_group_textarea_sids_element,  a.join(', '))
        @group_page.click_add_sids_to_group_button
        @group_page.click_remove_invalid_sids
      end

      it 'allows the user to add large sets of SIDs' do
        admits = test.admits.first(BOACUtils.group_bulk_sids_max)
        groups = admits.each_slice((admits.size / 3.0).round).to_a

        comma_separated = groups[0]
        @group_page.add_comma_sep_sids_to_existing_grp(comma_separated, group_4)
        @group_page.wait_for_spinner

        line_separated = groups[1]
        @group_page.add_line_sep_sids_to_existing_grp(line_separated, group_4)
        @group_page.wait_for_spinner

        space_separated = groups[2]
        @group_page.add_space_sep_sids_to_existing_grp(space_separated, group_4)
        @group_page.wait_for_spinner
        @group_page.load_page group_4
      end
    end

    describe 'admit group membership' do

      before(:all) { @group = advisor_groups.sort_by { |g| g.members.length }.last }

      it 'appears in Everyone\'s Groups' do
        visible = (@group_page.visible_everyone_groups.map &:name).sort
        expect(visible).to include(@group.name)
      end

      it 'shows the most recent data update date if the data is stale' do
        @group_page.load_page @group
        if Date.parse(latest_update_date) == Date.today
          expect(@group_page.data_update_date_heading(latest_update_date).exists?).to be false
        else
          expect(@group_page.data_update_date_heading(latest_update_date).exists?).to be true
        end
      end

      it 'shows the right data for the admits' do
        failures = []
        visible_sids = @group_page.admit_cohort_row_sids

        group_sids = @group.members.map &:sis_id
        @group.member_data = test.searchable_data.select { |d| group_sids.include? d[:sid] }
        expected_admit_data = @group.member_data.select { |d| visible_sids.include? d[:sid] }

        expected_admit_data.each { |admit| @group_page.verify_admit_row_data(admit[:sid], admit, failures) }
        expect(failures).to be_empty
      end

      it 'can be exported' do
        @group.export_csv = @group_page.export_admit_list @group
        @group_page.verify_admits_present_in_export(all_admit_data, @group.member_data, @group.export_csv)
      end

      it 'can be exported with no email addresses' do
        @group_page.verify_no_email_in_export(@group.export_csv)
      end
    end

    describe 'admit groups' do

      it 'can be renamed' do
        @group_page.load_page advisor_groups.first
        @group_page.rename_grp(advisor_groups.first, "#{advisor_groups.first.name} Renamed")
      end

      it('allow a deletion to be canceled') { @group_page.cancel_cohort_deletion advisor_groups.first }

      it 'cannot be reached by a non-CE3 advisor' do
        test.dept = BOACDepartments::L_AND_S
        test.set_advisor
        @homepage.log_out
        @homepage.dev_auth test.advisor
        @group_page.hit_non_auth_group advisor_groups.first
      end
    end
  end
end
