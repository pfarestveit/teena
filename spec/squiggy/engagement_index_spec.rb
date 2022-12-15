require_relative '../../util/spec_helper'

test = SquiggyTestConfig.new 'engagement_index'
test.course.site_id = nil
teacher = test.teachers.first
student_0 = test.students[0]
student_1 = test.students[1]
student_2 = test.students[2]
student_3 = test.students[3]

describe 'The Engagement Index' do

  before(:all) do
    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @assets_list = SquiggyAssetLibraryListViewPage.new @driver
    @asset_detail = SquiggyAssetLibraryDetailPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver
    @impact_studio = SquiggyImpactStudioPage.new @driver

    @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course test
    @canvas.disable_tool(test.course, SquiggyTool::IMPACT_STUDIO) if test.course.impact_studio_url

    @asset = student_2.assets.find &:file_name
    @asset.title = "#{@asset.title} #{test.id}"

    # Add asset to library
    @canvas.masquerade_as(student_0, test.course)
    @engagement_index.load_page test
    @engagement_index.share_score
    @assets_list.load_page test
    @assets_list.upload_file_asset @asset

    # Comment on the asset
    comment = SquiggyComment.new asset: @asset, user: student_1, body: 'Testing Testing'
    @canvas.masquerade_as(student_1, test.course)
    @engagement_index.load_page test
    @engagement_index.un_share_score
    @engagement_index.users_table_element.when_not_present 2
    @asset_detail.load_asset_detail(test, @asset)
    @asset_detail.add_comment comment

    # View the asset detail
    @canvas.masquerade_as(student_2, test.course)
    @engagement_index.load_page test
    @engagement_index.un_share_score
    @engagement_index.users_table_element.when_not_present 2
    @asset_detail.load_asset_detail(test, @asset)

    @canvas.masquerade_as(student_3, test.course)
    @engagement_index.load_page test
    @engagement_index.share_score

    @canvas.masquerade_as(teacher, test.course)
    @engagement_index.load_scores test
  end

  after(:all) { Utils.quit_browser @driver }

  [teacher, student_1, student_2, student_3].each do |user|
    it "offers no #{user.full_name} Impact Studio link for a course site with no Impact Studio" do
      expect(@engagement_index.user_profile_link(test, user).exists?).to be false
    end
  end

  it 'is sorted by "Rank" ascending by default' do
    expect(@engagement_index.visible_ranks).to eql(@engagement_index.visible_ranks.sort)
  end

  it 'can be sorted by "Rank" descending' do
    @engagement_index.sort_by_rank_desc
    @engagement_index.wait_until(1) { @engagement_index.visible_ranks == @engagement_index.visible_ranks.sort.reverse }
  end

  it 'can be sorted by "Name" ascending' do
    @engagement_index.sort_by_name_asc
    @engagement_index.wait_until(1) { @engagement_index.visible_names == @engagement_index.visible_names.sort }
  end

  it 'can be sorted by "Name" descending' do
    @engagement_index.sort_by_name_desc
    @engagement_index.wait_until(1) { @engagement_index.visible_names == @engagement_index.visible_names.sort.reverse }
  end

  it 'can be sorted by "Share" ascending' do
    test.course.impact_studio_url = nil
    @engagement_index.sort_by_share_asc
    @engagement_index.wait_until(1) { @engagement_index.visible_sharing(test) == @engagement_index.visible_sharing(test).sort }
  end

  it 'can be sorted by "Share" descending' do
    @engagement_index.sort_by_share_desc
    @engagement_index.wait_until(1) { @engagement_index.visible_sharing(test) == @engagement_index.visible_sharing(test).sort.reverse }
  end

  it 'can be sorted by "Points" ascending' do
    @engagement_index.sort_by_points_asc
    @engagement_index.wait_until(1) { @engagement_index.visible_points(test) == @engagement_index.visible_points(test).sort }
  end

  it 'can be sorted by "Points" descending' do
    @engagement_index.sort_by_points_desc
    @engagement_index.wait_until(1) { @engagement_index.visible_points(test) == @engagement_index.visible_points(test).sort.reverse }
  end

  # TEACHERS

  it 'allows teachers to see all users\' scores regardless of sharing preferences' do
    expect(@engagement_index.visible_names.sort).to eql(test.course.roster.map(&:full_name).sort)
  end

  it 'allows teachers to share their scores with students' do
    @engagement_index.share_score
    @engagement_index.wait_until(Utils.short_wait, "Expected Yes, got #{@engagement_index.sharing_preference(test, teacher)}") do
      @engagement_index.sharing_preference(test, teacher) == 'Yes'
    end
    @canvas.masquerade_as(student_3, test.course)
    @engagement_index.load_scores test
    expect(@engagement_index.visible_names).to include(teacher.full_name)
  end

  it 'allows teachers to hide their scores from students' do
    @canvas.masquerade_as(teacher, test.course)
    @engagement_index.load_scores test
    @engagement_index.un_share_score
    @engagement_index.wait_for_scores
    @engagement_index.wait_until(Utils.short_wait, "Expected No, got #{@engagement_index.sharing_preference(test, teacher)}") do
      @engagement_index.sharing_preference(test, teacher) == 'No'
    end
    @canvas.masquerade_as(student_3, test.course)
    @engagement_index.load_scores test
    expect(@engagement_index.visible_names).not_to include(teacher.full_name)
  end

  # STUDENTS

  it 'allows students to share their scores with other students' do
    @canvas.masquerade_as(student_0, test.course)
    @engagement_index.load_page test
    @engagement_index.share_score
  end

  it 'shows students who have shared their scores a box plot graph of their scores in relation to other users\' scores' do
    expect(@engagement_index.user_info_rank?).to be true
    expect(@engagement_index.user_info_points?).to be true
    expect(@engagement_index.user_info_boxplot?).to be true
  end

  it 'only shows students who have shared their scores the scores of other users who have also shared' do
    expect(@engagement_index.visible_names.sort).to eql([student_0.full_name, student_3.full_name])
  end

  it('shows students the "Rank" column') { expect(@engagement_index.sort_by_rank?).to be true }
  it('shows students the "Name" column') { expect(@engagement_index.sort_by_name?).to be true }
  it('does not show students the "Share" column') { expect(@engagement_index.sort_by_share?).to be false }
  it('shows students the "Points" column') { expect(@engagement_index.sort_by_points?).to be true }
  it('shows students the "Recent Activity" column') { expect(@engagement_index.sort_by_activity?).to be true }
  it('does not shows students a "Download CSV" button') { expect(@engagement_index.download_csv_link?).to be false }

  it('allows students to hide their scores from other students') do
    @engagement_index.un_share_score
    @engagement_index.users_table_element.when_not_present 2
  end

  it 'shows students who have not shared their scores only their own scores' do
    expect(@engagement_index.visible_names).to be_empty
    expect(@engagement_index.user_info_rank?).to be false
    expect(@engagement_index.user_info_points?).to be true
    expect(@engagement_index.user_info_boxplot?).to be false
  end

  # COLLABORATION

  describe '"looking for collaborators"' do

    before(:all) do
      @canvas.stop_masquerading
      @canvas.enable_tool(test.course, SquiggyTool::IMPACT_STUDIO)
      test.course.impact_studio_url = @canvas.click_tool_link SquiggyTool::IMPACT_STUDIO
    end

    context 'when the user is not looking' do

      before(:all) do
        @canvas.masquerade_as(student_1, test.course)
        @engagement_index.load_page test
        @engagement_index.share_score
      end

      context 'and another user views the user' do

        before(:all) do
          @canvas.masquerade_as(student_2, test.course)
          @engagement_index.load_page test
          @engagement_index.share_score
        end

        it 'shows no collaboration elements on the Engagement Index' do
          @engagement_index.user_profile_link(test, student_1).when_visible Utils.short_wait
          expect(@engagement_index.collaboration_button_element(student_1).exists?).to be false
        end
      end
    end

    context 'when the user is looking' do

      before(:all) do
        @canvas.masquerade_as(student_1, test.course)
        @impact_studio.load_page test
        @impact_studio.set_collaboration_true
      end

      context 'and another user views the user' do

        before(:all) do
          @canvas.masquerade_as(student_2, test.course)
          @engagement_index.load_scores test
        end

        it 'shows a collaborate button on the Engagement Index' do
          @engagement_index.collaboration_button_element(student_1).when_present Utils.short_wait
        end
      end
    end
  end

  describe 'points configuration' do

    before(:all) do
      @canvas.masquerade_as student_3
      @assets_list.load_page test
      @assets_list.upload_file_asset student_3.assets.find(&:file_name)
      @add_asset_activity = SquiggyActivity::ADD_ASSET_TO_LIBRARY

      @canvas.masquerade_as teacher
      @engagement_index.load_scores test
      @engagement_index.click_points_config
    end

    SquiggyActivity::ACTIVITIES.each do |squigtivity|
      it "by default shows '#{squigtivity.title}' worth default points" do
        expect(@engagement_index.activity_points squigtivity).to eql(squigtivity.points)
      end
    end

    it 'allows a teacher to cancel disabling an activity' do
      @engagement_index.click_edit_points_config
      @engagement_index.click_disable_activity @add_asset_activity
      @engagement_index.click_cancel_config_edit
      expect(@engagement_index.enabled_activity_titles).to include(@add_asset_activity.title)
    end

    it 'allows a teacher to disable an activity type' do
      @engagement_index.disable_activity @add_asset_activity
      @engagement_index.wait_until(3) { !@engagement_index.enabled_activity_titles.include? @add_asset_activity.title }
      @engagement_index.wait_until(3) { @engagement_index.disabled_activity_titles.include? @add_asset_activity.title }
    end

    it 'subtracts points retroactively for a disabled activity' do
      @engagement_index.click_back_to_index
      expect(@engagement_index.user_score(test, student_3)).to eql(0)
    end

    it 'removes a disabled activity from the CSV export' do
      csv = @engagement_index.download_csv test
      activity = csv.find do |r|
        r[:user_name] == student_3.full_name &&
          r[:action] == @add_asset_activity.type &&
          r[:score] == @add_asset_activity.points
      end
      expect(activity).to be_falsey
    end

    it 'disabled activities are not visible to a student' do
      @canvas.masquerade_as(student_3, test.course)
      @engagement_index.load_page test
      @engagement_index.share_score
      @engagement_index.click_points_config
      expect(@engagement_index.enabled_activity_titles).not_to include(@add_asset_activity.title)
      expect(@engagement_index.disabled_activity_titles).to be_empty
    end

    it 'allows a teacher to cancel re-enabling a disabled activity type' do
      @canvas.masquerade_as(teacher, test.course)
      @engagement_index.load_scores test
      @engagement_index.click_points_config
      @engagement_index.click_edit_points_config
      @engagement_index.click_enable_activity @add_asset_activity
      @engagement_index.click_cancel_config_edit
      expect(@engagement_index.enabled_activity_titles).not_to include(@add_asset_activity.title)
      expect(@engagement_index.disabled_activity_titles).to include(@add_asset_activity.title)
    end

    it 'allows a teacher to re-enable a disabled activity type' do
      @engagement_index.enable_activity @add_asset_activity
      expect(@engagement_index.enabled_activity_titles).to include(@add_asset_activity.title)
    end

    it 'adds points retroactively for a re-enabled activity' do
      @engagement_index.click_back_to_index
      expect(@engagement_index.user_score(test, student_3)).to eql(@add_asset_activity.points)
    end

    it 'adds a re-enabled activity to the CSV export' do
      csv = @engagement_index.download_csv test
      activity = csv.find { |r| r[:user_name] == student_3.full_name && r[:action] == @add_asset_activity.type && r[:score] == @add_asset_activity.points }
      expect(activity).to be_truthy
    end

    it 'allows a teacher to change an activity type point value to a new integer' do
      @engagement_index.load_page test
      @engagement_index.click_points_config
      @engagement_index.change_activity_points(@add_asset_activity, (@add_asset_activity.points + 10))
      expect(@engagement_index.activity_points(@add_asset_activity)).to eql(@add_asset_activity.points)
    end

    it 'allows a teacher to recalculate points retroactively when changing activity type point values' do
      @engagement_index.click_back_to_index
      expect(@engagement_index.user_score(test, student_3)).to eql(@add_asset_activity.points)
    end

    it 'recalculates activity points on the CSV export when changing activity type point values' do
      csv = @engagement_index.download_csv test
      activity = csv.find { |r| r[:user_name] == student_3.full_name && r[:action] == @add_asset_activity.type && r[:score] == @add_asset_activity.points }
      expect(activity).to be_truthy
    end

    it 'allows a student to view the Points Configuration whether or not they share their scores' do
      @canvas.masquerade_as(student_3, test.course)
      @engagement_index.load_page test
      @engagement_index.points_config_button_element.when_visible Utils.short_wait
      if @engagement_index.share_score_cbx_checked?
        @engagement_index.un_share_score
        @engagement_index.users_table_element.when_not_present 2
      else
        @engagement_index.share_score
      end
      expect(@engagement_index.points_config_button?).to be true
    end

    it 'shows a student no editing interface' do
      @engagement_index.click_points_config
      expect(@engagement_index.edit_points_config_button?).to be false
    end
  end

  # TEACHERS AND STUDENTS

  describe 'Canvas syncing' do

    before(:all) do
      @canvas.stop_masquerading
      @canvas.remove_users_from_course(test.course, [teacher, student_3])
    end

    it 'removes users from the Engagement Index if they have been removed from the course site' do
      @engagement_index.wait_for_removed_user_sync(test, [teacher, student_3])
    end

    [teacher, student_3].each do |user|

      it "prevents #{user.role} UID #{user.uid} from reaching the Engagement Index if the user has been removed from the course site" do
        @canvas.masquerade_as(user, test.course)
        @engagement_index.navigate_to test.course.engagement_index_url
        @canvas.access_denied_msg_element.when_visible Utils.short_wait
      end

      it "prevents #{user.role} UID #{user.uid} from reaching the Asset Library if the user has been removed from the course site" do
        @assets_list.navigate_to test.course.asset_library_url
        @canvas.access_denied_msg_element.when_visible Utils.short_wait
      end

      it "removes #{user.role} UID #{user.uid} from the Asset Library if the user has been removed from the course site" do
        @canvas.stop_masquerading
        @assets_list.load_page test
        @assets_list.open_advanced_search
        @assets_list.click_uploader_select
        expect(@assets_list.asset_uploader_options).not_to include(user.full_name)
      end
    end
  end
end
