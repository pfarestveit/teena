require_relative '../../util/spec_helper'

describe 'Engagement Index points configuration' do

  before(:all) do
    @test = SquiggyTestConfig.new 'engagement_config'
    @test.course.site_id = nil
    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net= Page::CalNetPage.new @driver
    @assets_list = SquiggyAssetLibraryListViewPage.new @driver
    @asset_detail = SquiggyAssetLibraryDetailPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver

    @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course @test

    @student = @test.students.first
    @canvas.masquerade_as(@student, @test.course)

    @assets_list.load_page @test
    @assets_list.upload_file_asset @student.assets.find(&:file_name)
    @add_asset_activity = SquiggyActivity::ADD_ASSET_TO_LIBRARY

    @canvas.masquerade_as(@test.teachers.first, @course)
    @engagement_index.load_scores @test
    @engagement_index.click_points_config
  end

  after(:all) { Utils.quit_browser @driver }

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
    expect(@engagement_index.user_score(@test, @student)).to eql(0)
  end

  it 'removes a disabled activity from the CSV export' do
    expect(@engagement_index.download_csv @test).to be_empty
  end

  it 'disabled activities are not visible to a student' do
    @canvas.masquerade_as(@student, @test.course)
    @engagement_index.load_page @test
    @engagement_index.share_score
    @engagement_index.click_points_config
    expect(@engagement_index.enabled_activity_titles).not_to include(@add_asset_activity.title)
    expect(@engagement_index.disabled_activity_titles).to be_empty
  end

  it 'allows a teacher to cancel re-enabling a disabled activity type' do
    @canvas.masquerade_as(@test.teachers.first, @test.course)
    @engagement_index.load_scores @test
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
    expect(@engagement_index.user_score(@test, @student)).to eql(@add_asset_activity.points)
  end

  it 'adds a re-enabled activity to the CSV export' do
    csv = @engagement_index.download_csv @test
    activity = csv.find { |r| r[:user_name] == @student.full_name && r[:action] == @add_asset_activity.type && r[:score] == @add_asset_activity.points }
    expect(activity).to be_truthy
  end

  it 'allows a teacher to change an activity type point value to a new integer' do
    @engagement_index.load_page @test
    @engagement_index.click_points_config
    @engagement_index.change_activity_points(@add_asset_activity, (@add_asset_activity.points + 10))
    expect(@engagement_index.activity_points(@add_asset_activity)).to eql(@add_asset_activity.points)
  end

  it 'allows a teacher to recalculate points retroactively when changing activity type point values' do
    @engagement_index.click_back_to_index
    expect(@engagement_index.user_score(@test, @student)).to eql(@add_asset_activity.points)
  end

  it 'recalculates activity points on the CSV export when changing activity type point values' do
    csv = @engagement_index.download_csv @test
    activity = csv.find { |r| r[:user_name] == @student.full_name && r[:action] == @add_asset_activity.type && r[:score] == @add_asset_activity.points }
    expect(activity).to be_truthy
  end

  it 'allows a student to view the Points Configuration whether or not they share their scores' do
    @canvas.masquerade_as(@student, @test.course)
    @engagement_index.load_page @test
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
