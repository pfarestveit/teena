require_relative '../../util/spec_helper'

describe 'A SuiteC course' do

  add_topic = SquiggyActivity::ADD_DISCUSSION_TOPIC
  add_entry = SquiggyActivity::ADD_DISCUSSION_ENTRY
  get_reply = SquiggyActivity::GET_DISCUSSION_REPLY

  before(:all) do
    @test = SquiggyTestConfig.new 'canvas_groups'
    @test.course.site_id = nil
    @section_1 = Section.new label: "WBL 001 #{@test.id}", sis_id: "WBL 001 #{@test.id}"
    @section_2 = Section.new label: "WBL 002 #{@test.id}", sis_id: "WBL 002 #{@test.id}"
    @test.course.sections = [@section_1, @section_2]
    (@teacher_1 = @test.teachers[0]).sections = [@section_2]
    (@student_1 = @test.students[0]).sections = [@section_1]
    (@student_2 = @test.students[1]).sections = [@section_1]
    (@student_3 = @test.students[2]).sections = [@section_1, @section_2]
    (@student_4 = @test.students[3]).sections = [@section_2]
    (@student_5 = @test.students[4]).sections = [@section_2]
    @teacher_2 = @test.teachers[1]

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
                               group_set: @student_group_set,
                               members: [@student_1, @student_5]
    @group_options = [
      "#{@teacher_group_set.title} - #{@teacher_group_1.title}",
      "#{@teacher_group_set.title} - #{@teacher_group_2.title}"
    ]

    @group_1_whiteboard = SquiggyWhiteboard.new title: "Group 1.1 Whiteboard #{@test.id}",
                                                  owner: @student_1,
                                                  collaborators: [@student_3, @student_4]

    @driver = Utils.launch_browser
    @cal_net = Page::CalNetPage.new @driver
    @canvas_groups_page = Page::CanvasGroupsPage.new @driver
    @canvas_discussions_page = Page::CanvasAnnounceDiscussPage.new @driver
    @canvas_assignments = Page::CanvasAssignmentsPage.new @driver
    @asset_library = SquiggyAssetLibraryDetailPage.new @driver
    @manage_assets = SquiggyAssetLibraryManageAssetsPage.new @driver
    @whiteboards = SquiggyWhiteboardPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver

    @canvas_groups_page.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas_groups_page.create_squiggy_course @test
    @engagement_index.wait_for_new_user_sync(@test, @test.course.roster)
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when no groups exist' do

    context 'and a student searches the asset library' do
      before(:all)  do
        @canvas_groups_page.masquerade_as(@student_1, @test.course)
        @asset_library.load_page @test
      end
      it 'does not offer search filtering by group' do
        @asset_library.open_advanced_search
        expect(@asset_library.group_select?).to be false
      end
    end

    context 'and a teacher searches the asset library' do
      before(:all)  do
        @canvas_groups_page.masquerade_as(@teacher_1, @test.course)
        @asset_library.load_page @test
      end
      it 'does not offer search filtering by group' do
        @asset_library.open_advanced_search
        expect(@asset_library.group_select?).to be false
      end
    end
  end

  context 'when groups exist' do

    before(:all) do
      @canvas_groups_page.masquerade_as(@teacher_1, @course)
      @canvas_groups_page.instr_create_grp_set(@test.course, @teacher_group_set)
      @canvas_groups_page.instr_create_grp(@test.course, @teacher_group_1)
      @canvas_groups_page.instr_create_grp(@test.course, @teacher_group_2)

      # Remove course member to ensure poller has reached course before proceeding with tests
      @canvas_groups_page.stop_masquerading
      @canvas_groups_page.remove_users_from_course(@test.course, [@teacher_2])
      @engagement_index.wait_for_removed_user_sync(@test, [@teacher_2])
    end

    context 'with no members' do

      context 'and a student searches the asset library' do
        before(:all)  do
          @canvas_groups_page.masquerade_as @student_1
          @asset_library.load_page @test
        end
        it 'offers search filtering by all groups' do
          @asset_library.open_advanced_search
          @asset_library.click_group_select
          expect(@asset_library.group_options.sort).to eql(@group_options.sort)
        end
      end

      context 'and a teacher searches the asset library' do
        before(:all)  do
          @canvas_groups_page.masquerade_as @teacher_1
          @asset_library.load_page @test
        end
        it 'offers search filtering by all groups' do
          @asset_library.open_advanced_search
          @asset_library.click_group_select
          expect(@asset_library.group_options.sort).to eql(@group_options.sort)
        end
      end
    end

    context 'with members' do

      before(:all) do
        @teacher_group_1.members.each do |s|
          @canvas_groups_page.masquerade_as(s, @test.course)
          @canvas_groups_page.stud_join_grp(@test.course, @teacher_group_1)
        end
        @teacher_group_2.members.each do|s|
          @canvas_groups_page.masquerade_as(s, @test.course)
          @canvas_groups_page.stud_join_grp(@test.course, @teacher_group_2)
        end

        @canvas_groups_page.masquerade_as @student_1
        @canvas_groups_page.stud_create_grp(@test.course, @student_group)
        @canvas_groups_page.masquerade_as @student_5
        @canvas_groups_page.stud_join_grp(@test.course, @student_group)

        @group_options = [
          "#{@teacher_group_set.title} - #{@teacher_group_1.title}",
          "#{@teacher_group_set.title} - #{@teacher_group_2.title}",
          "#{@student_group_set.title} - #{@student_group.title}"
        ]

        # Add course member to ensure poller has reached course before proceeding with tests
        @canvas_groups_page.stop_masquerading
        @canvas_groups_page.add_users(@test.course, [@teacher_2])
        @engagement_index.wait_for_new_user_sync(@test, [@teacher_2])
      end

      context 'and the group name changes' do
        before(:all) do
          @canvas_groups_page.masquerade_as @student_1
          @canvas_groups_page.stud_edit_grp_name(@test.course, @student_group, "#{@student_group.title} Edited")

          @group_options = [
            "#{@teacher_group_set.title} - #{@teacher_group_1.title}",
            "#{@teacher_group_set.title} - #{@teacher_group_2.title}",
            "#{@student_group_set.title} - #{@student_group.title}"
          ]

          # Remove course member to ensure poller has reached course before proceeding with tests
          @canvas_groups_page.stop_masquerading
          @canvas_groups_page.remove_users_from_course(@test.course, [@teacher_2])
          @engagement_index.wait_for_removed_user_sync(@test, [@teacher_2])
        end

        it 'offers search filtering by the updated group name' do
          @canvas_groups_page.masquerade_as @student_1
          @asset_library.load_page @test
          @asset_library.open_advanced_search
          @asset_library.click_group_select
          expect(@asset_library.group_options.sort).to eql(@group_options.sort)
        end
      end
    end

    context 'with members who have assets' do

      before(:all) do
        @test.students.each do |s|
          @canvas_groups_page.masquerade_as(s, @test.course)
          @asset_library.load_page @test
          asset = s.assets.first
          asset.file_name ? @asset_library.upload_file_asset(asset) : @asset_library.add_link_asset(asset)
        end

        @canvas_groups_page.masquerade_as @student_1
        @whiteboards.load_page @test
        @whiteboards.create_whiteboard @group_1_whiteboard
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
      it 'filters existing assets by group on a whiteboard' do
        @whiteboards.load_page @test
        @whiteboards.open_whiteboard @group_1_whiteboard
        @whiteboards.click_add_existing_asset
        @whiteboards.advanced_search(@test.id, nil, nil, 'File', nil, @teacher_group_1, nil)
        @whiteboards.wait_for_asset_results [@student_4.assets[0], @student_1.assets[0]]
      end
    end

    context 'with members who have switched groups' do

      before(:all) do
        @canvas_groups_page.masquerade_as @student_3
        @canvas_groups_page.stud_switch_grps(@test.course, @teacher_group_2)
        @teacher_group_1.members.delete @student_3
        @teacher_group_2.members << @student_3

        # Add course member to ensure poller has reached course before proceeding with tests
        @canvas_groups_page.stop_masquerading
        @canvas_groups_page.add_users(@test.course, [@teacher_2])
        @engagement_index.wait_for_new_user_sync(@test, [@teacher_2])
      end

      it 'filters the Asset Library by group' do
        @canvas_groups_page.masquerade_as @student_1
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

      # TODO it 'filters existing assets by group on a whiteboard'
      # TODO it 'filters existing assets by group and section on a whiteboard'
      # TODO it 'filters existing assets by group and category on a whiteboard'
      # TODO it 'filters existing assets by group and section on a whiteboard'
    end

    context 'with members who have left' do

      before(:all) do
        @canvas_groups_page.masquerade_as @student_1
        @canvas_groups_page.stud_leave_grp(@test.course, @teacher_group_1)
        @teacher_group_1.members.delete @student_1

        # Remove course member to ensure poller has reached course before proceeding with tests
        @canvas_groups_page.stop_masquerading
        @canvas_groups_page.remove_users_from_course(@test.course, [@teacher_2])
        @engagement_index.wait_for_removed_user_sync(@test, [@teacher_2])
      end

      it 'filters the Asset Library by group' do
        @canvas_groups_page.masquerade_as @student_1
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

      # TODO it 'filters existing assets by group on a whiteboard'
      # TODO it 'filters existing assets by group and section on a whiteboard'
      # TODO it 'filters existing assets by group and category on a whiteboard'
      # TODO it 'filters existing assets by group and section on a whiteboard'
    end

    context 'and section silos are enabled' do

      before(:all) do
        @canvas_groups_page.masquerade_as @teacher_1
        @asset_library.load_page @test
        @asset_library.click_manage_assets_link
        @manage_assets.silo_sections
      end

      it 'filters the Asset Library by group' do
        @canvas_groups_page.masquerade_as @student_1
        @asset_library.load_page @test
        @asset_library.advanced_search(nil, nil, nil, nil, nil, @teacher_group_2, nil)
        @asset_library.wait_for_asset_results [@student_3.assets[0], @student_2.assets[0]]
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
        @asset_library.advanced_search(nil, nil, nil, nil, nil, @student_group, nil)
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
      @canvas_groups_page.masquerade_as @teacher_1
      @canvas_groups_page.instr_delete_grp_set(@test.course, @teacher_group_set)

      # Add course member to ensure poller has reached course before proceeding with tests
      @canvas_groups_page.stop_masquerading
      @canvas_groups_page.add_users(@test.course, [@teacher_2])
      @engagement_index.wait_for_new_user_sync(@test, [@teacher_2])
    end

    it 'removes the group filter option from the Asset Library' do
      @canvas_groups_page.masquerade_as @student_1
      @asset_library.load_page @test
      @asset_library.open_advanced_search
      @asset_library.click_group_select
      expect(@asset_library.group_options.sort).to eql(["#{@student_group_set.title} - #{@student_group.title}"])
    end

    # TODO it 'removes the group filter option from existing assets on a whiteboard'
  end
  
  context 'discussion' do
    
    before(:all) do
      @canvas_discussions_page.masquerade_as @teacher_1
      @asset_library.load_page @test
      @asset_library.click_manage_assets_link
      @manage_assets.silo_sections

      @teacher_1.score = @engagement_index.user_score(@test, @teacher_1)
      @teacher_2.score = @engagement_index.user_score(@test, @teacher_2)

      @discussion = Discussion.new "#{@test.course.title} Discussion"
      @canvas_discussions_page.create_course_discussion(@test.course, @discussion)
      @teacher_1_expected_score = @teacher_1.score + add_topic.points
    end
    it 'earns Discussion Topic Engagement Index points for the discussion creator' do
      expect(@engagement_index.user_score_updated?(@test, @teacher_1, @teacher_1_expected_score)).to be true
    end

    it 'adds discussion-topic activity to the CSV export for the discussion creator' do
      activity = @engagement_index.download_csv(@test).find do |r|
        r[:user_name] == @teacher_1.full_name &&
          r[:action] == add_topic.type &&
          r[:score] == add_topic.points &&
          r[:running_total] == @teacher_1.score
      end
      expect(activity).to be_truthy
    end

    describe 'entry' do

      context 'when added' do

        before(:all) do
          # User 0 creates an entry on the topic, which should earn no points
          @canvas_discussions_page.add_reply(@discussion, nil, 'Discussion entry by the discussion topic creator')

          # User 1 creates an entry on the topic, which should earn points for User 1 only
          @canvas_discussions_page.masquerade_as(@teacher_2, @test.course)
          @canvas_discussions_page.add_reply(@discussion, nil, 'Discussion entry by someone other than the discussion topic creator')
          @teacher_2_expected_score = @teacher_2.score + add_entry.points
        end

        context 'by someone other than the discussion topic creator' do

          it 'earns Discussion Entry Engagement Index points for the user adding the entry' do
            expect(@engagement_index.user_score_updated?(@test, @teacher_2, @teacher_2_expected_score)).to be true
          end

          it 'earns no points for the discussion topic creator' do
            expect(@engagement_index.user_score(@test, @teacher_1)).to eql(@teacher_1.score)
          end

          it 'adds discussion-entry activity to the CSV export for the user adding the entry' do
            activity = @engagement_index.download_csv(@test).find do |r|
              r[:user_name] == @teacher_2.full_name &&
                r[:action] == add_entry.type &&
                r[:score] == add_entry.points &&
                r[:running_total] == @teacher_2.score
            end
            expect(activity).to be_truthy
          end
        end

        context 'by the discussion topic creator' do

          it 'earns no Discussion Entry Engagement Index points for the user adding the entry' do
            expect(@engagement_index.user_score(@test, @teacher_1)).to eql(@teacher_1.score)
          end

          it 'adds no discussion-entry activity to the CSV export for the discussion creator' do
            activity = @engagement_index.download_csv(@test).find do |r|
              r[:user_name] == @teacher_1.full_name &&
                r[:action] == add_entry.type &&
                r[:score] == add_entry.points &&
                r[:running_total] == (@teacher_1.score + add_entry.points)
            end
            expect(activity).to be_falsey
          end
        end
      end

      context 'when added' do

        before(:all) do
          # User 1 replies to the topic again, which should earn points for User 1 only
          @canvas_discussions_page.add_reply(@discussion, nil, 'Discussion entry by somebody other than the discussion topic creator')
          @teacher_2_expected_score = @teacher_2.score + add_entry.points
        end

        context 'by someone who has already added an earlier discussion entry' do

          it 'earns Discussion Entry Engagement Index points for the user adding the entry' do
            expect(@engagement_index.user_score_updated?(@test, @teacher_2, @teacher_2_expected_score)).to be true
          end

          it 'earns no points for the discussion topic creator' do
            expect(@engagement_index.user_score(@test, @teacher_1)).to eql(@teacher_1.score)
          end

          it 'adds discussion-entry activity to the CSV export for the user adding the entry' do
            activity = @engagement_index.download_csv(@test).find do |r|
              r[:user_name] == @teacher_2.full_name &&
                r[:action] == add_entry.type &&
                r[:score] == add_entry.points &&
                r[:running_total] == @teacher_2.score
            end
            expect(activity).to be_truthy
          end
        end
      end
    end

    describe 'entry reply' do

      context 'when added' do

        before(:all) do
          # User 0 replies to own entry, which should earn no points
          @canvas_discussions_page.masquerade_as @teacher_1
          @canvas_discussions_page.add_reply(@discussion, 0, 'Reply by the discussion topic creator and also the discussion entry creator')

          # User 0 replies to User 1's first entry, which should earn points for both
          @canvas_discussions_page.add_reply(@discussion, 2, 'Reply by the discussion topic creator but not the discussion entry creator')
          @teacher_1_expected_score = @teacher_1.score + add_entry.points
          @teacher_2_expected_score = @teacher_2.score + get_reply.points
        end

        context 'by someone who created the discussion topic but not the discussion entry' do

          it 'earns Discussion Entry Engagement Index points for the user who added the discussion entry reply' do
            expect(@engagement_index.user_score_updated?(@test, @teacher_1, @teacher_1_expected_score)).to be true
          end

          it 'earns Discussion Reply Engagement Index points for the user who received the discussion entry reply' do
            expect(@engagement_index.user_score_updated?(@test, @teacher_2, @teacher_2_expected_score)).to be true
          end

          it 'adds discussion-entry activity to the CSV export for the entry reply' do
            activity = @engagement_index.download_csv(@test).find do |r|
              r[:user_name] == @teacher_1.full_name &&
                r[:action] == add_entry.type &&
                r[:score] == add_entry.points &&
                r[:running_total] == @teacher_1.score
            end
            expect(activity).to be_truthy
          end

          it 'adds discussion-reply activity to the CSV export for the entry reply' do
            activity = @engagement_index.download_csv(@test).find do |r|
              r[:user_name] == @teacher_2.full_name &&
                r[:action] == get_reply.type &&
                r[:score] == get_reply.points &&
                r[:running_total] == @teacher_2.score
            end
            expect(activity).to be_truthy
          end
        end

        context 'by someone who created the discussion topic and the discussion entry' do

          it 'earns no Engagement Index points for the user' do
            expect(@engagement_index.user_score(@test, @teacher_1)).to eql(@teacher_1.score)
          end
        end
      end

      context 'when added' do

        before(:all) do
          # User 1 replies to own first entry, which should earn no points
          @canvas_discussions_page.masquerade_as @teacher_2
          @canvas_discussions_page.add_reply(@discussion, 2, 'Reply by somebody other than the discussion topic creator but who is the discussion entry creator')

          # User 1 replies to User 0's entry, which should earn points for both
          @canvas_discussions_page.add_reply(@discussion, 0, 'Reply by somebody other than the discussion topic creator and other than the discussion entry creator')
          @teacher_2_expected_score = @teacher_2.score + add_entry.points
          @teacher_1_expected_score = @teacher_1.score + get_reply.points
        end

        context 'by someone who did not create the discussion topic or the discussion entry' do

          it 'earns Discussion Reply Engagement Index points for the user who received the discussion entry reply' do
            expect(@engagement_index.user_score_updated?(@test, @teacher_1, @teacher_1_expected_score)).to be true
          end

          it 'earns Discussion Entry Engagement Index points for the user who added the discussion entry reply' do
            expect(@engagement_index.user_score_updated?(@test, @teacher_2, @teacher_2_expected_score)).to be true
          end

          it 'adds discussion-reply activity to the CSV export fort the user who received the discussion entry reply' do
            activity = @engagement_index.download_csv(@test).find do |r|
              r[:user_name] == @teacher_1.full_name &&
                r[:action] == get_reply.type &&
                r[:score] == get_reply.points &&
                r[:running_total] == @teacher_1.score
            end
            expect(activity).to be_truthy
          end

          it 'adds discussion-entry activity to the CSV export for the user who added the discussion entry reply' do
            activity = @engagement_index.download_csv(@test).find do |r|
              r[:user_name] == @teacher_2.full_name &&
                r[:action] == add_entry.type &&
                r[:score] == add_entry.points &&
                r[:running_total] == @teacher_2.score
            end
            expect(activity).to be_truthy
          end
        end

        context 'by someone who did not create the discussion topic but did create the discussion entry' do

          it 'earns no Engagement Index points for the user' do
            expect(@engagement_index.user_score(@test, @teacher_2)).to eql(@teacher_2.score)
          end
        end
      end

      context 'when added' do

        before(:all) do
          # User 1 replies to own first entry, which should earn no points
          @canvas_discussions_page.add_reply(@discussion, 3, 'Reply by somebody other than the discussion topic creator but who is the discussion entry creator')

          # User 1 replies again to User 0's reply, which should earn points for both
          @canvas_discussions_page.add_reply(@discussion, 0, 'Second reply by somebody other than the discussion topic creator and other than the discussion entry creator')
          @teacher_2_expected_score = @teacher_2.score + add_entry.points
          @teacher_1_expected_score = @teacher_1.score + get_reply.points
        end

        context 'by someone who did not create the discussion topic but did create the discussion entry' do

          it 'earns Discussion Reply Engagement Index points for the user who received the discussion entry reply' do
            expect(@engagement_index.user_score_updated?(@test, @teacher_1, @teacher_1_expected_score)).to be true
          end

          it 'earns Discussion Entry Engagement Index points for the user who added the discussion entry reply' do
            expect(@engagement_index.user_score_updated?(@test, @teacher_2, @teacher_2_expected_score)).to be true
          end

          it 'adds discussion-entry activity to the CSV export for the user who received the discussion entry reply' do
            activity = @engagement_index.download_csv(@test).find do |r|
              r[:user_name] == @teacher_1.full_name &&
                r[:action] == get_reply.type &&
                r[:score] == get_reply.points &&
                r[:running_total] == @teacher_1.score
            end
            expect(activity).to be_truthy
          end

          it 'adds discussion-reply activity to the CSV export for the user who added the discussion entry reply' do
            activity = @engagement_index.download_csv(@test).find do |r|
              r[:user_name] == @teacher_2.full_name &&
                r[:action] == add_entry.type &&
                r[:score] == add_entry.points &&
                r[:running_total] == @teacher_2.score
            end
            expect(activity).to be_truthy
          end
        end

        context 'by someone who added an earlier discussion entry reply' do

          it 'earns no Engagement Index points for the user' do
            expect(@engagement_index.user_score(@test, @teacher_2)).to eql(@teacher_2.score)
          end
        end
      end
    end

    describe 'reply to reply' do

      context 'when added' do

        before(:all) do
          # User 1 replies to its own first reply to User 0's entry, which should earn no points
          @canvas_discussions_page.add_reply(@discussion, 2, 'Reply-to-reply by somebody who created the reply but not the topic or the entry')

          # User 0 replies to User 1's first reply to User 1's entry, which should earn points for both
          @canvas_discussions_page.masquerade_as @teacher_1
          @canvas_discussions_page.add_reply(@discussion, 2, 'Reply-to-reply by somebody who created the topic and the entry but not the reply')
          @teacher_1_expected_score = @teacher_1.score + add_entry.points
          @teacher_2_expected_score = @teacher_2.score + get_reply.points
        end

        context 'by someone who created the entry but not the reply' do

          it 'earns Discussion Entry Engagement Index points for the user who added the reply to reply' do
            expect(@engagement_index.user_score_updated?(@test, @teacher_1, @teacher_1_expected_score)).to be true
          end

          it 'earns Discussion Reply Engagement Index points for the user who received the reply to reply' do
            expect(@engagement_index.user_score_updated?(@test, @teacher_2, @teacher_2_expected_score)).to be true
          end

          it 'adds discussion-entry activity to the CSV export for the user added the reply to reply' do
            activity = @engagement_index.download_csv(@test).find do |r|
              r[:user_name] == @teacher_1.full_name &&
                r[:action] == add_entry.type &&
                r[:score] == add_entry.points &&
                r[:running_total] == @teacher_1.score
            end
            expect(activity).to be_truthy
          end

          it 'adds discussion-reply activity to the CSV export for the user who received the reply to reply' do
            activity = @engagement_index.download_csv(@test).find do |r|
              r[:user_name] == @teacher_2.full_name &&
                r[:action] == get_reply.type &&
                r[:score] == get_reply.points &&
                r[:running_total] == @teacher_2.score
            end
            expect(activity).to be_truthy
          end
        end

        context 'by someone who created the reply but not the entry' do

          it 'earns no Engagement Index points for the user' do
            expect(@engagement_index.user_score(@test, @teacher_2)).to eql(@teacher_2.score)
          end
        end
      end
    end
  end
end
