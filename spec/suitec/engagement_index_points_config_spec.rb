require_relative '../../util/spec_helper'

describe 'Engagement Index points configuration', order: :defined do

  include Logging

  before(:all) do
    @course = Course.new({})

    # Load test data
    test_user_data = Utils.load_test_users.select { |data| data['tests']['engagementIndexPointsConfig'] }
    @teacher = User.new test_user_data.find { |user| user['role'] == 'Teacher' }
    @student = User.new test_user_data.find { |user| user['role'] == 'Student' }

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryPage.new @driver
    @engagement_index = Page::SuiteCPages::EngagementIndexPage.new @driver

    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_username)
    @canvas.get_suite_c_test_course(@driver, @course, [@teacher, @student], Utils.get_test_id, [SuiteCTools::ASSET_LIBRARY, SuiteCTools::ENGAGEMENT_INDEX])

    @canvas.load_course_site(@driver, @course)
    @asset_library_url = @canvas.click_tool_link(@driver, SuiteCTools::ASSET_LIBRARY)
    @engagement_index_url = @canvas.click_tool_link(@driver, SuiteCTools::ENGAGEMENT_INDEX)

    @canvas.masquerade_as(@driver, @student, @course)
    @asset_library.load_page(@driver, @asset_library_url)
    @asset_library.upload_file_to_library Asset.new(@student.assets.find { |asset| asset['type'] == 'File' })

    @canvas.masquerade_as(@driver, @teacher, @course)
    @engagement_index.load_scores(@driver, @engagement_index_url)
    @engagement_index.click_points_config
  end

  after(:all) { @driver.quit }

  it "by default shows '#{Activities::VIEW_ASSET.title}' worth default points" do
    expect(@engagement_index.activity_points Activities::VIEW_ASSET).to eql(Activities::VIEW_ASSET.points)
  end
  it "by default shows '#{Activities::ADD_ASSET_TO_LIBRARY.title}' worth default points" do
    expect(@engagement_index.activity_points Activities::ADD_ASSET_TO_LIBRARY).to eql(Activities::ADD_ASSET_TO_LIBRARY.points)
  end
  it "by default shows '#{Activities::LIKE.title}' worth default point" do
    expect(@engagement_index.activity_points Activities::LIKE).to eql(Activities::LIKE.points)
  end
  it "by default shows '#{Activities::DISLIKE.title}' worth default point" do
    expect(@engagement_index.activity_points Activities::DISLIKE).to eql(Activities::DISLIKE.points)
  end
  it "by default shows '#{Activities::GET_LIKE.title}' worth default point" do
    expect(@engagement_index.activity_points Activities::GET_LIKE).to eql(Activities::GET_LIKE.points)
  end
  it "by default shows '#{Activities::GET_DISLIKE.title}' worth default point" do
    expect(@engagement_index.activity_points Activities::GET_DISLIKE).to eql(Activities::GET_DISLIKE.points)
  end
  it "by default shows '#{Activities::COMMENT.title}' worth default points" do
    expect(@engagement_index.activity_points Activities::COMMENT).to eql(Activities::COMMENT.points)
  end
  it "by default shows '#{Activities::GET_COMMENT.title}' worth default point" do
    expect(@engagement_index.activity_points Activities::GET_COMMENT).to eql(Activities::GET_COMMENT.points)
  end
  it "by default shows '#{Activities::GET_COMMENT_REPLY.title}' worth default point" do
    expect(@engagement_index.activity_points Activities::GET_COMMENT_REPLY).to eql(Activities::GET_COMMENT_REPLY.points)
  end
  it "by default shows '#{Activities::SUBMIT_ASSIGNMENT.title}' worth default points" do
    expect(@engagement_index.activity_points Activities::SUBMIT_ASSIGNMENT).to eql(Activities::SUBMIT_ASSIGNMENT.points)
  end
  it "by default shows '#{Activities::ADD_DISCUSSION_TOPIC.title}' worth default points" do
    expect(@engagement_index.activity_points Activities::ADD_DISCUSSION_TOPIC).to eql(Activities::ADD_DISCUSSION_TOPIC.points)
  end
  it "by default shows '#{Activities::ADD_DISCUSSION_ENTRY.title}' worth default points" do
    expect(@engagement_index.activity_points Activities::ADD_DISCUSSION_ENTRY).to eql(Activities::ADD_DISCUSSION_ENTRY.points)
  end
  it "by default shows '#{Activities::GET_DISCUSSION_REPLY.title}' worth default point" do
    expect(@engagement_index.activity_points Activities::GET_DISCUSSION_REPLY).to eql(Activities::GET_DISCUSSION_REPLY.points)
  end
  it "by default shows '#{Activities::EXPORT_WHITEBOARD.title}' worth default points" do
    expect(@engagement_index.activity_points Activities::EXPORT_WHITEBOARD).to eql(Activities::EXPORT_WHITEBOARD.points)
  end
  it "by default shows '#{Activities::ADD_ASSET_TO_WHITEBOARD.title}' worth default points" do
    expect(@engagement_index.activity_points Activities::ADD_ASSET_TO_WHITEBOARD).to eql(Activities::ADD_ASSET_TO_WHITEBOARD.points)
  end
  it "by default shows '#{Activities::LEAVE_CHAT_MESSAGE.title}' worth default points" do
    expect(@engagement_index.activity_points Activities::LEAVE_CHAT_MESSAGE).to eql(Activities::LEAVE_CHAT_MESSAGE.points)
  end

  it 'allows a teacher to cancel disabling an activity' do
    @engagement_index.click_edit_points_config
    @engagement_index.click_disable_activity Activities::ADD_ASSET_TO_LIBRARY
    @engagement_index.click_cancel_config_edit
    expect(@engagement_index.enabled_activity_titles).to include(Activities::ADD_ASSET_TO_LIBRARY.title)
  end

  it 'allows a teacher to disable an activity type' do
    @engagement_index.disable_activity Activities::ADD_ASSET_TO_LIBRARY
    expect(@engagement_index.enabled_activity_titles).not_to include(Activities::ADD_ASSET_TO_LIBRARY.title)
    expect(@engagement_index.disabled_activity_titles).to include(Activities::ADD_ASSET_TO_LIBRARY.title)
  end

  it 'subtracts points retroactively for a disabled activity' do
    @engagement_index.click_back_to_index
    expect(@engagement_index.user_score @student).to eql('0')
  end

  it 'removes a disabled activity from the CSV export' do
    activity = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
    expect(activity).to be_empty
  end

  it 'disabled activities are not visible to a student' do
    @canvas.masquerade_as(@driver, @student, @course)
    @engagement_index.load_page(@driver, @engagement_index_url)
    @engagement_index.share_score
    @engagement_index.click_points_config
    expect(@engagement_index.enabled_activity_titles).not_to include(Activities::ADD_ASSET_TO_LIBRARY.title)
    expect(@engagement_index.disabled_activity_titles).to be_empty
  end

  it 'allows a teacher to cancel re-enabling a disabled activity type' do
    @canvas.masquerade_as(@driver, @teacher, @course)
    @engagement_index.load_scores(@driver, @engagement_index_url)
    @engagement_index.click_points_config
    @engagement_index.click_edit_points_config
    @engagement_index.click_enable_activity Activities::ADD_ASSET_TO_LIBRARY
    @engagement_index.click_cancel_config_edit
    expect(@engagement_index.enabled_activity_titles).not_to include(Activities::ADD_ASSET_TO_LIBRARY.title)
    expect(@engagement_index.disabled_activity_titles).to include(Activities::ADD_ASSET_TO_LIBRARY.title)
  end

  it 'allows a teacher to re-enable a disabled activity type' do
    @engagement_index.enable_activity Activities::ADD_ASSET_TO_LIBRARY
    expect(@engagement_index.enabled_activity_titles).to include(Activities::ADD_ASSET_TO_LIBRARY.title)
  end

  it 'adds points retroactively for a re-enabled activity' do
    @engagement_index.click_back_to_index
    expect(@engagement_index.user_score @student).to eql("#{@initial_score.to_i + Activities::ADD_ASSET_TO_LIBRARY.points}")
  end

  it 'adds a re-enabled activity to the CSV export' do
    activity = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
    expect(activity).to include("#{@student.full_name}, #{Activities::ADD_ASSET_TO_LIBRARY.type}, #{Activities::ADD_ASSET_TO_LIBRARY.points}, #{Activities::ADD_ASSET_TO_LIBRARY.points}")
  end

  it 'allows a teacher to change an activity type point value to a new integer' do
    @engagement_index.click_points_config
    @engagement_index.change_activity_points(Activities::ADD_ASSET_TO_LIBRARY, (Activities::ADD_ASSET_TO_LIBRARY.points + 10))
    expect(@engagement_index.activity_points(Activities::ADD_ASSET_TO_LIBRARY)).to eql(Activities::ADD_ASSET_TO_LIBRARY.points + 10)
  end

  it 'allows a teacher to recalculate points retroactively when changing activity type point values' do
    @engagement_index.click_back_to_index
    expect(@engagement_index.user_score @student).to eql("#{Activities::ADD_ASSET_TO_LIBRARY.points + 10}")
  end

  it 'recalculates activity points on the CSV export when changing activity type point values' do
    activity = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
    expect(activity).to include("#{@student.full_name}, #{Activities::ADD_ASSET_TO_LIBRARY.type}, #{Activities::ADD_ASSET_TO_LIBRARY.points + 10}, #{Activities::ADD_ASSET_TO_LIBRARY.points + 10}")
  end

  it 'allows a student to view the Points Configuration whether or not they share their scores' do
    @canvas.masquerade_as(@driver, @student, @course)
    @engagement_index.load_page(@driver, @engagement_index_url)
    expect(@engagement_index.points_config_link?).to be true
    if @engagement_index.share_score_cbx_checked?
      @engagement_index.uncheck_share_score_cbx
      ("#{@driver.browser}" == 'chrome') ?
          @engagement_index.users_table_element.when_not_present(Utils.short_wait) :
          @engagement_index.users_table_element.when_not_visible(Utils.short_wait)
      expect(@engagement_index.points_config_link?).to be true
    else
      @engagement_index.check_share_score_cbx
      @engagement_index.users_table_element.when_visible Utils.short_wait
      expect(@engagement_index.points_config_link?).to be true
    end
  end

  it 'shows a student no editing interface' do
    @engagement_index.click_points_config
    expect(@engagement_index.edit_points_config_button?).to be false
  end

end
