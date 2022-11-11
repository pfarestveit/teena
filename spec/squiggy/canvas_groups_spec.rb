require_relative '../../util/spec_helper'

describe 'A SuiteC course' do

  before(:all) do
    @test = SquiggyTestConfig.new 'canvas_groups'
    @test.course.site_id = nil
    @section_1 = Section.new label: "WBL 001 #{@test.id}", sis_id: "WBL 001 #{@test.id}"
    @section_2 = Section.new label: "WBL 002 #{@test.id}", sis_id: "WBL 002 #{@test.id}"
    @test.course.sections = [@section_1, @section_2]
    (@teacher = @test.teachers.first).sections = [@section_2]
    (@student_1 = @test.students[0]).sections = [@section_1]
    (@student_2 = @test.students[1]).sections = [@section_1]
    (@student_3 = @test.students[2]).sections = [@section_1, @section_2]
    (@student_4 = @test.students[3]).sections = [@section_2]
    (@student_5 = @test.students[4]).sections = [@section_2]

    @teacher_group_set = GroupSet.new title: "Teacher group set #{@test.id}"
    @teacher_group_1 = Group.new title: "Teacher group 1.1 #{@test.id}",
                                 group_set: @teacher_group_set,
                                 members: [@student_1, @student_3, @student_4]
    @teacher_group_2 = Group.new title: "Teacher group 1.2 #{@test.id}",
                                 group_set: @teacher_group_set,
                                 members: [@student_2, @student_5]
    @teacher_group_set.groups = [@group_1, @group_2]

    @student_group_set = GroupSet.new title: 'Student Groups'
    @student_group = Group.new title: "Student group 2.1 #{@test.id}",
                               members: [@student_1, @student_5]
    @group_options = [
      "#{@teacher_group_set.title} - #{@teacher_group_1.title}",
      "#{@teacher_group_set.title} - #{@teacher_group_2.title}",
      "#{@student_group_set.title} - #{@student_group.title}"
    ]

    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @canvas = Page::CanvasGroupsPage.new @driver
    @canvas_assignments = Page::CanvasAssignmentsPage.new @driver
    @asset_library = SquiggyAssetLibraryDetailPage.new @driver
    @manage_assets = SquiggyAssetLibraryManageAssetsPage.new @driver
    @whiteboards = SquiggyWhiteboardPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver

    @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course @test
    @engagement_index.wait_for_new_user_sync(@test, @test.course.roster)
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when no groups exist' do

    context 'and a student searches the asset library' do
      before(:all)  do
        @canvas.masquerade_as(@student_1, @test.course)
        @asset_library.load_page @test
      end
      it 'does not offer search filtering by group' do
        @asset_library.expand_adv_search
        expect(@asset_library.group_select?).to be false
      end
    end

    context 'and a teacher searches the asset library' do
      before(:all)  do
        @canvas.masquerade_as(@teacher, @test.course)
        @asset_library.load_page @test
      end
      it 'does not offer search filtering by group' do
        @asset_library.expand_adv_search
        expect(@asset_library.group_select?).to be false
      end
    end
  end

  context 'when groups exist' do

    before(:all) do
      @canvas.masquerade_as(@teacher, @course)
      @canvas.instr_create_grp_set(@test.course, @teacher_group_set)
      @canvas.instr_create_grp(@test.course, @teacher_group_1)
      @canvas.instr_create_grp(@test.course, @teacher_group_2)

      # Remove course member to ensure poller has reached course before proceeding with tests
      @canvas.stop_masquerading
      @canvas.remove_users_from_course(@test.course, [@test.teachers[1]])
      @engagement_index.wait_for_removed_user_sync(@test, [@test.teachers[1]])
    end

    context 'with no members' do

      context 'and a student searches the asset library' do
        before(:all)  do
          @canvas.masquerade_as @student_1
          @asset_library.load_page @test
        end
        it 'offers search filtering by all groups' do
          @asset_library.expand_adv_search
          @asset_library.click_group_select
          expect(@asset_library.group_options.sort).to eql(@group_options.sort)
        end
      end

      context 'and a teacher searches the asset library' do
        before(:all)  do
          @canvas.masquerade_as @teacher
          @asset_library.load_page @test
        end
        it 'offers search filtering by all groups' do
          @asset_library.expand_adv_search
          @asset_library.click_group_select
          expect(@asset_library.group_options.sort).to eql(@group_options.sort)
        end
      end
    end

    context 'with members' do

      before(:all) do
        @teacher_group_1.members.each do |s|
          @canvas.masquerade_as(s, @test.course)
          @canvas.stud_join_grp(@test.course, @teacher_group_1)
        end
        @teacher_group_2.members.each do|s|
          @canvas.masquerade_as(s, @test.course)
          @canvas.stud_join_grp(@test.course, @teacher_group_2)
        end

        @canvas.masquerade_as @student_1
        @canvas.stud_create_grp(@test.course, @student_group)
        @canvas.masquerade_as @student_5
        @canvas.stud_join_grp(@test.course, @student_group)

        # Add course member to ensure poller has reached course before proceeding with tests
        @canvas.stop_masquerading
        @canvas.add_users(@test.course, [@test.teachers[1]])
        @engagement_index.wait_for_new_user_sync(@test, [@test.teachers[1]])
      end

      context 'and the group name changes' do
        before(:all) do
          @canvas.masquerade_as @student_1
          @canvas.stud_edit_grp_name(@test.course, @student_group, "#{@student_group.title} Edited")

          # Remove course member to ensure poller has reached course before proceeding with tests
          @canvas.stop_masquerading
          @canvas.remove_users_from_course(@test.course, [@test.teachers[1]])
          @engagement_index.wait_for_removed_user_sync(@test, [@test.teachers[1]])
        end

        it 'offers search filtering by the updated group name' do
          @canvas.masquerade_as @student_1
          @asset_library.load_page @test
          @asset_library.expand_adv_search
          @asset_library.click_group_select
          expect(@asset_library.group_options.sort).to eql(@group_options.sort)
        end
      end
    end

    context 'with members who have assets' do

      before(:all) do
        @test.students.each do |s|
          @canvas.masquerade_as(s, @test.course)
          @asset_library.load_page @test
          asset = s.assets.first
          asset.file_name ? @asset_library.upload_file_asset(asset) : @asset_library.add_link_asset(asset)
        end

        @group_1_1_whiteboard = SquiggyWhiteboard.new title: "Group 1.1 Whiteboard #{@test.id}",
                                                      owner: @student_1,
                                                      collaborators: [@student_3, @student_4]
        @canvas.masquerade_as @student_1
        @whiteboards.load_page @test
        @whiteboards.create_whiteboard @group_1_1_whiteboard
      end

      it 'filters the Asset Library by group' do
        @asset_library.load_page @test
        @asset_library.advanced_search(nil, nil, nil, nil, nil, @teacher_group_1, nil)
        @asset_library.wait_for_asset_results [@student_4.assets[0], @student_3.assets[0], @student_1.assets[0]]
      end
      it 'filters the Asset Library by group and keyword' do
        @asset_library.advanced_search(@student_4.assets[0].title.split[0], nil, nil, nil, nil, @teacher_group_1, nil)
        @asset_library.wait_for_asset_results [@student_4.assets[0]]
      end
      it 'filters the Asset Library by group and asset owner' do
        @asset_library.advanced_search(nil, nil, @student_3, nil, nil, @teacher_group_2, nil)
        @asset_library.wait_for_no_results
      end
      it 'filters the Asset Library by group and section' do
        @asset_library.advanced_search(nil, nil, nil, nil, @section_2, @student_group, nil)
        @asset_library.wait_for_asset_results [@student_5.assets[0]]
      end

      # TODO it 'filters existing assets by group on a whiteboard'
      # TODO it 'filters existing assets by group and section on a whiteboard'
      # TODO it 'filters existing assets by group and category on a whiteboard'
      # TODO it 'filters existing assets by group and section on a whiteboard'
    end

    context 'with members who have switched groups' do

      before(:all) do
        @canvas.masquerade_as @student_3
        @canvas.stud_switch_grps(@test.course, @teacher_group_2)
        @teacher_group_1.members.delete @student_3
        @teacher_group_2.members << @student_3

        # Add course member to ensure poller has reached course before proceeding with tests
        @canvas.stop_masquerading
        @canvas.add_users(@test.course, [@test.teachers[1]])
        @engagement_index.wait_for_new_user_sync(@test, [@test.teachers[1]])
      end

      it 'filters the Asset Library by group' do
        @canvas.masquerade_as @student_1
        @asset_library.load_page @test
        @asset_library.advanced_search(nil, nil, nil, nil, nil, @teacher_group_1, nil)
        @asset_library.wait_for_asset_results [@student_4.assets[0], @student_1.assets[0]]
      end
      it 'filters the Asset Library by group and keyword' do
        @asset_library.advanced_search(@student_3.assets[0].title.split[0], nil, nil, nil, nil, @teacher_group_2, nil)
        @asset_library.wait_for_asset_results [@student_3.assets[0]]
      end
      it 'filters the Asset Library by group and asset owner' do
        @asset_library.advanced_search(nil, nil, @student_3, nil, nil, @teacher_group_1, nil)
        @asset_library.wait_for_no_results
      end
      it 'filters the Asset Library by group and section' do
        @asset_library.advanced_search(nil, nil, nil, nil, @section_2, @teacher_group_2, nil)
        @asset_library.wait_for_asset_results [@student_5.assets[0], @student_3.assets[0]]
      end

      # TODO it 'filters existing assets by group on a whiteboard'
      # TODO it 'filters existing assets by group and section on a whiteboard'
      # TODO it 'filters existing assets by group and category on a whiteboard'
      # TODO it 'filters existing assets by group and section on a whiteboard'
    end

    context 'with members who have left' do

      before(:all) do
        @canvas.masquerade_as @student_1
        @canvas.stud_leave_grp(@test.course, @teacher_group_1)
        @teacher_group_1.members.delete @student_1

        # Remove course member to ensure poller has reached course before proceeding with tests
        @canvas.stop_masquerading
        @canvas.remove_users_from_course(@test.course, [@test.teachers[1]])
        @engagement_index.wait_for_removed_user_sync(@test, [@test.teachers[1]])
      end

      it 'filters the Asset Library by group' do
        @canvas.masquerade_as @student_1
        @asset_library.load_page @test
        @asset_library.advanced_search(nil, nil, nil, nil, nil, @teacher_group_1, nil)
        @asset_library.wait_for_asset_results [@student_4.assets[0]]
      end
      it 'filters the Asset Library by group and keyword' do
        @asset_library.advanced_search(@student_1.assets[0].title.split[0], nil, nil, nil, nil, @teacher_group_1, nil)
        @asset_library.wait_for_no_results
      end
      it 'filters the Asset Library by group and asset owner' do
        @asset_library.advanced_search(nil, nil, @student_1, nil, nil, @teacher_group_1, nil)
        @asset_library.wait_for_no_results
      end
      it 'filters the Asset Library by group and section' do
        @asset_library.advanced_search(nil, nil, nil, nil, @section_1, @teacher_group_1, nil)
        @asset_library.wait_for_no_results
      end

      # TODO it 'filters existing assets by group on a whiteboard'
      # TODO it 'filters existing assets by group and section on a whiteboard'
      # TODO it 'filters existing assets by group and category on a whiteboard'
      # TODO it 'filters existing assets by group and section on a whiteboard'
    end

    context 'and section silos are enabled' do

      before(:all) do
        @canvas.masquerade_as @teacher
        @asset_library.load_page @test
        @asset_library.click_manage_assets_link
        @manage_assets.silo_sections
      end

      it 'filters the Asset Library by group' do
        @canvas.masquerade_as @student_1
        @asset_library.load_page @test
        @asset_library.advanced_search(nil, nil, nil, nil, nil, @teacher_group_1, nil)
        @asset_library.wait_for_asset_results [@student_4.assets[0]]
      end
      it 'filters the Asset Library by group and keyword' do
        @asset_library.advanced_search(@student_1.assets[0].title.split[0], nil, nil, nil, nil, @teacher_group_1, nil)
        @asset_library.wait_for_no_results
      end
      it 'filters the Asset Library by group and asset owner' do
        @asset_library.advanced_search(nil, nil, @student_1, nil, nil, @teacher_group_1, nil)
        @asset_library.wait_for_no_results
      end
      it 'filters the Asset Library by group and section' do
        @asset_library.advanced_search(nil, nil, nil, nil, @section_1, @student_group, nil)
        @asset_library.wait_for_asset_results [@student_1.assets[0]]
      end

      # TODO it 'filters existing assets by group on a whiteboard'
      # TODO it 'filters existing assets by group and section on a whiteboard'
      # TODO it 'filters existing assets by group and category on a whiteboard'
      # TODO it 'filters existing assets by group and section on a whiteboard'
    end
  end

  context 'when groups are deleted' do

    before(:all) do
      @canvas.masquerade_as @teacher
      @canvas.instr_delete_grp_set(@test.course, @teacher_group_set)

      # Add course member to ensure poller has reached course before proceeding with tests
      @canvas.stop_masquerading
      @canvas.add_users(@test.course, [@test.teachers[1]])
      @engagement_index.wait_for_new_user_sync(@test, [@test.teachers[1]])
    end

    it 'removes the group filter option from the Asset Library' do
      @canvas.masquerade_as @student_1
      @asset_library.load_page @test
      @asset_library.expand_adv_search
      @asset_library.click_group_select
      expect(@asset_library.group_options.sort).to eql(["#{@student_group_set.title} - #{@student_group.title}"])
    end

    # TODO it 'removes the group filter option from existing assets on a whiteboard'
  end
end
