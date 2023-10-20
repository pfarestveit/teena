require_relative '../../util/spec_helper'

unless ENV['NO_DEPS']

  describe 'BOAC' do

    include Logging

    test = BOACTestConfig.new
    test.curated_groups
    test_student = test.cohort_members.sort_by(&:uid).first
    logger.debug "Test student is UID #{test_student.uid} SID #{test_student.sis_id}"

    # Initialize groups to be used later in the tests
    advisor_groups = [
        (group_1 = CuratedGroup.new({:name => "Group 1 #{test.id}"})),
        (group_2 = CuratedGroup.new({:name => "Group 2 #{test.id}"})),
        (group_3 = CuratedGroup.new({:name => "Group 3 #{test.id}"})),
        (group_4 = CuratedGroup.new({:name => "Group 4 #{test.id}"})),
        (group_5 = CuratedGroup.new({:name => "Group 5 #{test.id}"})),
        (group_6 = CuratedGroup.new({:name => "Group 6 #{test.id}"})),
        (group_7 = CuratedGroup.new({:name => "Group 7 #{test.id}"})),
        (group_8 = CuratedGroup.new({:name => "Group 8 #{test.id}"}))
    ]
    other_advisor = BOACUtils.get_admin_users.find { |u| u.uid != test.advisor.uid }
    pre_existing_cohorts = BOACUtils.get_user_filtered_cohorts test.advisor, default: true
    pre_existing_groups = BOACUtils.get_user_curated_groups test.advisor

    before(:all) do
      @driver = Utils.launch_browser test.chrome_profile
      @analytics_page = BOACApiStudentPage.new @driver
      @homepage = BOACHomePage.new @driver
      @group_page = BOACGroupStudentsPage.new @driver
      @filtered_page = BOACFilteredStudentsPage.new(@driver, test.advisor)
      @student_page = BOACStudentPage.new @driver
      @class_page = BOACClassListViewPage.new @driver
      @search_page = BOACSearchResultsPage.new @driver

      # Get enrollment data for test student for class page tests
      @homepage.dev_auth test.advisor
      @analytics_page.get_data test_student
      @term = @analytics_page.terms.first
      @course = @analytics_page.courses(@term).first

      # Delete all pre-existing cohorts since they might contain group filters and prevent group deletion
      @homepage.load_page
      pre_existing_cohorts.each do |c|
        @filtered_page.load_cohort c
        @filtered_page.delete_cohort c
      end

      # Create a default filtered cohort
      @filtered_page.search_and_create_new_cohort(test.default_cohort, default: true) unless test.default_cohort.id
    end

    after(:all) { Utils.quit_browser @driver }

    it 'groups can all be deleted' do
      pre_existing_groups.each do |c|
        @group_page.load_page c
        @group_page.delete_cohort c
      end
    end

    describe 'group creation' do

      it 'can be done using the filtered cohort list view group selector' do
        @filtered_page.load_cohort test.default_cohort
        @filtered_page.wait_for_student_list
        sids = @filtered_page.list_view_sids
        visible_members = test.students.select { |m| sids.include? m.sis_id }
        group_created_from_filter = CuratedGroup.new({:name => "Group created from filtered cohort #{test.id}"})
        @filtered_page.select_and_add_students_to_new_grp(visible_members.last(10), group_created_from_filter)
      end

      it 'can be done using the class page list view group selector' do
        @class_page.load_page(@analytics_page.term_id(@term), @analytics_page.course_section_ccns(@course).first)
        sids = @class_page.class_list_view_sids
        visible_members = test.students.select { |m| sids.include? m.sis_id }
        group_created_from_class = CuratedGroup.new({:name => "Group created from class page #{test.id}"})
        @class_page.select_and_add_students_to_new_grp(visible_members.first(10), group_created_from_class)
      end

      it 'can be done using the user search results group selector' do
        @homepage.enter_simple_search_and_hit_enter test_student.sis_id
        group_created_from_search = CuratedGroup.new({:name => "Group created from search results #{test.id}"})
        @search_page.select_and_add_students_to_new_grp([test_student], group_created_from_search)
      end

      it 'can be done using the student page group selector' do
        @student_page.load_page test_student
        group_created_from_profile = CuratedGroup.new({:name => "Group created from student page #{test.id}"})
        @student_page.add_student_to_new_grp(test_student, group_created_from_profile)
      end

      it 'can be done using bulk SIDs feature' do
        students = test.students.first(52)
        @homepage.click_sidebar_create_student_group
        group_created_from_bulk = CuratedGroup.new({:name => "Group created with bulk SIDs #{test.id}"})
        @group_page.create_group_with_bulk_sids(students, group_created_from_bulk)
        @group_page.wait_for_sidebar_group group_created_from_bulk
        @group_page.group_name_heading(group_created_from_bulk).when_visible Utils.short_wait
      end
    end

    describe 'group names' do

      before(:all) do

        @homepage.load_page

        # Create a filtered cohort to verify that a group cannot have the same name
        filters = CohortFilter.new
        filters.set_custom_filters level: ['10']
        @existing_filtered_cohort = FilteredCohort.new name: "Existing Filtered Cohort #{test.id}", search_criteria: filters
        @group_page.click_sidebar_create_filtered
        @filtered_page.perform_student_search @existing_filtered_cohort
        @filtered_page.create_new_cohort @existing_filtered_cohort

        # Create a curated group to verify that another group cannot have the same name
        @existing_group = CuratedGroup.new({:name => "Existing Group #{test.id}"})
        @student_page.load_page test_student
        @student_page.add_student_to_new_grp(test_student, @existing_group)

        # Create and then delete a curated group to verify that another group can have the same name
        @deleted_group = CuratedGroup.new({:name => "Deleted Group #{test.id}"})
        @student_page.add_student_to_new_grp(test_student, @deleted_group)
        @group_page.load_page @deleted_group
        @group_page.delete_cohort @deleted_group

        @new_group = CuratedGroup.new({})
        @student_page.load_page test_student
      end

      before(:each) { @student_page.cancel_group if @student_page.grp_cancel_button_element.visible? }

      it 'are required' do
        @student_page.click_add_to_grp_button
        @student_page.click_create_new_grp
        expect(@student_page.grp_save_button_element.disabled?).to be true
      end

      it 'are truncated to 255 characters' do
        @new_group.name = "#{'A llooooong title ' * 15}?"
        @student_page.click_add_to_grp_button
        @student_page.click_create_new_grp
        @student_page.enter_group_name @new_group
        @student_page.no_chars_left_msg_element.when_present 1
      end

      it 'must not match a non-deleted group belonging to the same advisor' do
        @new_group.name = @existing_group.name
        @student_page.click_add_to_grp_button
        @student_page.click_create_new_grp
        @student_page.name_and_save_group @new_group
        @student_page.dupe_grp_name_msg_element.when_visible Utils.short_wait
      end

      it 'must not match a non-deleted filtered cohort belonging to the same advisor' do
        @new_group.name = @existing_filtered_cohort.name
        @student_page.click_add_to_grp_button
        @student_page.click_create_new_grp
        @student_page.name_and_save_group @new_group
        @student_page.dupe_filtered_name_msg_element.when_visible Utils.short_wait
      end

      it 'can be the same as a deleted group belonging to the same advisor' do
        @new_group.name = @deleted_group.name
        @student_page.add_student_to_new_grp(test_student, @new_group)
      end

      it 'can be changed' do
        @group_page.load_page @new_group
        @group_page.rename_grp(@new_group, "#{@new_group.name} Renamed")
      end
    end

    describe 'group membership' do

      before(:all) do
        student = test.cohort_members.last
        test.cohort_members.pop
        @student_page.load_page student
        advisor_groups.each { |c| @student_page.add_student_to_new_grp(student, c) }
      end

      it 'can be added from filtered cohort list view using select-all' do
        @filtered_page.load_cohort test.default_cohort
        @filtered_page.select_and_add_all_students_to_grp(test.students, group_1)
        @group_page.load_page group_1
        expect(@group_page.visible_sids.sort).to eql(group_1.members.map(&:sis_id).sort)
      end

      it 'can be added from filtered cohort list view using individual selections' do
        @filtered_page.load_cohort test.default_cohort
        group_uids = group_2.members.map &:uid
        visible_uids = @filtered_page.list_view_uids - group_uids
        test.cohort_members = test.cohort_members.select { |m| visible_uids.include? m.uid }
        @filtered_page.select_and_add_students_to_grp(test.cohort_members[0..-2], group_2)
        @group_page.load_page group_2
        expect(@group_page.visible_sids.sort).to eql(group_2.members.map(&:sis_id).sort)
        test.cohort_members.pop
      end

      it 'can be added on the student page' do
        @student_page.load_page test_student
        @student_page.add_student_to_grp(test_student, group_3)
        @group_page.load_page group_3
        expect(@group_page.visible_sids.sort).to eql(group_3.members.map(&:sis_id).sort)
      end

      it 'can be added on the bulk-add-SIDs page' do
        @group_page.load_page group_4
        @group_page.add_comma_sep_sids_to_existing_grp(test.students.last(10), group_4)
        missing_sids = group_4.members.map(&:sis_id).sort - @group_page.visible_sids.sort
        # Account for SIDs that have no associated data and will not appear in Boa
        if missing_sids.any?
          missing_sids.each do |missing_sid|
            logger.info "Checking data for missing SID '#{missing_sid}'"
            student = group_4.members.find { |s| s.sis_id == missing_sid }
            api_data = @analytics_page.get_data student
            unless api_data
              logger.info "Removing SID #{missing_sid} from the group since the student does not appear in Boa"
              missing_sids.delete missing_sid
              group_4.members.delete student
            end
          end
        end
        expect(missing_sids).to be_empty
      end

      it 'can be added on class page list view using select-all' do
        @class_page.load_page(@analytics_page.term_id(@term), @analytics_page.course_section_ccns(@course).first)
        @class_page.select_and_add_all_students_to_grp(test.students, group_5)
        @group_page.load_page group_5
        expect(@group_page.visible_sids.sort).to eql(group_5.members.map(&:sis_id).sort)
      end

      it 'can be added on class page list view using individual selections' do
        @student_page.load_page test_student
        @student_page.expand_academic_year @analytics_page.term_name(@term)
        @student_page.click_class_page_link(@analytics_page.term_id(@term), @analytics_page.course_section_ccns(@course).first)
        @class_page.select_and_add_students_to_grp([test_student], group_6)
        @group_page.load_page group_6
        expect(@group_page.visible_sids.sort).to eql(group_3.members.map(&:sis_id).sort)
      end

      it 'can be added on user search results using select-all' do
        @homepage.enter_simple_search_and_hit_enter test_student.sis_id
        @search_page.select_and_add_all_students_to_grp(test.students, group_7)
        @group_page.load_page group_7
        expect(@group_page.visible_sids.sort).to eql(group_7.members.map(&:sis_id).sort)
      end

      it 'can be added on user search results using individual selections' do
        @homepage.enter_simple_search_and_hit_enter test_student.sis_id
        @search_page.select_and_add_students_to_grp([test_student], group_8)
        @group_page.load_page group_8
        expect(@group_page.visible_sids.sort).to eql(group_8.members.map(&:sis_id).sort)
      end

      it 'is shown on the student page' do
        @student_page.load_page group_1.members.first
        @student_page.click_add_to_grp_button
        expect(@student_page.grp_selected? group_1).to be true
      end

      it 'can be removed on the group list view page' do
        @group_page.load_page group_2
        student = group_2.members.last
        logger.info "Removing UID #{student.uid} from group '#{group_2.name}'"
        @group_page.remove_student_by_row_index(group_2, student)
        expect(@group_page.visible_sids.sort).to eql(group_2.members.map(&:sis_id).sort)
      end

      it 'can be removed on the student page using the group checkbox' do
        @student_page.load_page group_1.members.last
        @student_page.remove_student_from_grp(group_1.members.last, group_1)
        @group_page.load_page group_1
        expect(@group_page.visible_sids.sort).to eql(group_1.members.map(&:sis_id).sort)
      end
    end

    describe 'membership on the sidebar' do

      before(:all) do
        @group_9 = CuratedGroup.new(name: "Group 9 #{test.id}")
        @group_10 = CuratedGroup.new(name: "Group 10 #{test.id}")
        @student = test.cohort_members.last
        @student_page.load_page @student
      end

      it 'is updated when a student is added to a new group' do
        @student_page.add_student_to_new_grp(@student, @group_9)
        @student_page.wait_for_sidebar_group_member_count @group_9
      end

      it 'is updated when a student is removed from a new group' do
        @group_page.load_page @group_9
        @group_page.remove_student_by_row_index(@group_9, @student)
        @group_page.wait_for_sidebar_group_member_count @group_9
      end

      it 'is updated when the same student is added to yet another new group' do
        @group_page.enter_simple_search_and_hit_enter @student.sis_id
        @search_page.select_and_add_students_to_new_grp([@student], @group_10)
        @search_page.wait_for_sidebar_group_member_count @group_10
        @search_page.wait_for_sidebar_group_member_count @group_9
      end

      it 'is updated when the same student is removed from yet another group' do
        @group_page.load_page @group_10
        @group_page.remove_student_by_row_index(@group_10, @student)
        @search_page.wait_for_sidebar_group_member_count @group_10
        @search_page.wait_for_sidebar_group_member_count @group_9
      end
    end

    describe 'group bulk-add SIDs' do

      before(:each) { @group_page.load_page group_4 }

      it 'rejects malformed input' do
        @group_page.click_add_sids_button
        @group_page.enter_sid_list(@group_page.create_group_textarea_sids_element, 'nullum magnum ingenium sine mixtura dementiae fuit')
        @group_page.click_add_sids_to_group_button
        @group_page.click_remove_invalid_sids
      end

      it 'rejects SIDs that do not match any Boa student SIDs' do
        @group_page.click_add_sids_button
        @group_page.enter_sid_list(@group_page.create_group_textarea_sids_element, '9999999990, 9999999991')
        @group_page.click_add_sids_to_group_button
        @group_page.click_remove_invalid_sids
      end

      it 'allows the user to remove rejected SIDs automatically if there are more than 15' do
        a = [test.students.last.sis_id]
        16.times { |i| a << "99999999#{10 + i}" }
        @group_page.click_add_sids_button
        @group_page.enter_sid_list(@group_page.create_group_textarea_sids_element, a.join(', '))
        @group_page.click_add_sids_to_group_button
        @group_page.click_remove_invalid_sids
      end

      it 'allows the user to add large sets of SIDs' do
        students = test.students.first(BOACUtils.group_bulk_sids_max)
        groups = students.each_slice((students.size / 3.0).round).to_a

        comma_separated = groups[0]
        @group_page.add_comma_sep_sids_to_existing_grp(comma_separated, group_4)
        @group_page.wait_for_list_to_load

        line_separated = groups[1]
        @group_page.add_line_sep_sids_to_existing_grp(line_separated, group_4)
        @group_page.wait_for_spinner

        space_separated = groups[2]
        @group_page.add_space_sep_sids_to_existing_grp(space_separated, group_4)
        @group_page.wait_for_spinner
        @group_page.load_page group_4

        # Account for SIDs that have no associated data and will not appear in Boa
        missing_sids = group_4.members.map(&:sis_id).sort - @group_page.visible_sids.sort
        if missing_sids.any?
          missing_sids.each do |missing_sid|
            logger.info "Checking data for missing SID '#{missing_sid}'"
            student = group_4.members.find { |s| s.sis_id == missing_sid }
            api_data = @analytics_page.get_data student
            unless api_data
              logger.info "Removing SID #{missing_sid} from the group since the student does not appear in Boa"
              missing_sids.delete missing_sid
              group_4.members.delete student
            end
          end
        end
        logger.warn "Missing SIDs in #{group_4.name}: #{missing_sids}"
        expect(missing_sids).to be_empty
      end
    end

    describe 'group membership' do

      before(:all) { @group_page.load_page group_4 }

      it "can be exported for group #{group_4.name}" do
        csv = @group_page.export_student_list group_4
        @group_page.verify_student_list_default_export(group_4.members, csv)
      end

      it "can be exported with custom columns for group #{group_4.name}" do
        csv = @group_page.export_custom_student_list group_4
        @group_page.verify_student_list_custom_export(group_4.members, csv)
      end
    end

    describe 'groups' do

      it 'can be renamed' do
        @group_page.load_page advisor_groups.first
        @group_page.rename_grp(advisor_groups.first, "#{advisor_groups.first.name} Renamed")
      end

      it('allow a deletion to be canceled') { @group_page.cancel_cohort_deletion advisor_groups.first }

      context 'on the homepage' do

        advisor_groups.each do |group|

          it "shows the group name #{group.name}" do
            @homepage.load_page
            @homepage.wait_until(Utils.medium_wait, "Expected #{@homepage.curated_groups} to include #{group.name}") do
              @homepage.curated_groups.include? group.name
            end
          end

          it "shows the group #{group.name} membership count" do
            @homepage.wait_until(Utils.short_wait, "Expected #{group.members.length} members, but got #{@homepage.member_count(group)}") do
              @homepage.member_count(group) == group.members.length
            end
          end

          it "shows the group #{group.name} members with alerts" do
            @homepage.expand_member_rows group
            @homepage.verify_member_alerts(group, test.advisor)
          end
        end
      end
    end

    describe 'groups' do

      before(:all) do
        @homepage.log_out
        @homepage.dev_auth other_advisor
      end

      it('does not appear in another user\'s sidebar') { expect(@homepage.sidebar_student_groups & advisor_groups.map(&:name)).to be_empty }

    end
  end
end
