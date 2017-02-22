require_relative '../../util/spec_helper'

describe 'The Engagement Index', order: :defined do

  include Logging

  # Load test data
  test_user_data = Utils.load_test_users.select { |data| data['tests']['engagementIndexSorting'] }
  teacher = User.new test_user_data.find { |user| user['role'] == 'Teacher' }
  student_data = test_user_data.select { |user| user['role'] == 'Student' }
  student_1 = User.new student_data[0]
  student_2 = User.new student_data[1]
  student_3 = User.new student_data[2]
  student_4 = User.new student_data[3]
  asset = Asset.new(student_3.assets.find { |asset| asset['type'] == 'File' })

  before(:all) do
    @course = Course.new({})

    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryPage.new @driver
    @engagement_index = Page::SuiteCPages::EngagementIndexPage.new @driver

    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.get_suite_c_test_course(@course, [teacher, student_1, student_2, student_3, student_4], Utils.get_test_id, [SuiteCTools::ASSET_LIBRARY, SuiteCTools::ENGAGEMENT_INDEX])

    @canvas.load_course_site @course
    @asset_library_url = @canvas.click_tool_link(@driver, SuiteCTools::ASSET_LIBRARY)
    @engagement_index_url = @canvas.click_tool_link(@driver, SuiteCTools::ENGAGEMENT_INDEX)

    # Add asset to library
    @canvas.masquerade_as(student_3, @course)
    @engagement_index.load_page(@driver, @engagement_index_url)
    @engagement_index.share_score
    @asset_library.load_page(@driver, @asset_library_url)
    @asset_library.upload_file_to_library asset

    # Comment on the asset
    @canvas.masquerade_as(student_1, @course)
    @engagement_index.load_page(@driver, @engagement_index_url)
    @engagement_index.un_share_score
    @asset_library.load_asset_detail(@driver, @asset_library_url, asset)
    @asset_library.add_comment 'Testing Testing'

    # Like the asset
    @canvas.masquerade_as(student_2, @course)
    @engagement_index.load_page(@driver, @engagement_index_url)
    @engagement_index.un_share_score
    @asset_library.load_asset_detail(@driver, @asset_library_url, asset)
    @asset_library.toggle_detail_view_item_like

    @canvas.masquerade_as(student_4, @course)
    @engagement_index.load_page(@driver, @engagement_index_url)
    @engagement_index.share_score

    @canvas.masquerade_as(teacher, @course)
    @engagement_index.load_scores(@driver, @engagement_index_url)
  end

  after(:all) { @driver.quit }

  # SORTING

  it 'is sorted by "Rank" descending by default' do
    expect(@engagement_index.visible_ranks).to eql(@engagement_index.visible_ranks.sort)
    expect(@engagement_index.sort_asc?).to be true
  end

  it 'can be sorted by "Rank" ascending' do
    rank_asc = @engagement_index.visible_ranks.sort
    @engagement_index.sort_by_rank_asc
    @engagement_index.wait_until(Utils.short_wait) { @engagement_index.visible_ranks == rank_asc }
  end

  it 'can be sorted by "Rank" descending' do
    rank_desc = @engagement_index.visible_ranks.sort { |x, y| y <=> x }
    @engagement_index.sort_by_rank_desc
    @engagement_index.wait_until(Utils.short_wait) { @engagement_index.visible_ranks == rank_desc }
  end

  it 'can be sorted by "Name" ascending' do
    name_asc = @engagement_index.visible_names.sort
    @engagement_index.sort_by_name_asc
    @engagement_index.wait_until(Utils.short_wait) { @engagement_index.visible_names == name_asc }
  end

  it 'can be sorted by "Name" descending' do
    name_desc = @engagement_index.visible_names.sort { |x, y| y <=> x }
    @engagement_index.sort_by_name_desc
    @engagement_index.wait_until(Utils.short_wait) { @engagement_index.visible_names == name_desc }
  end

  it 'can be sorted by "Share" ascending' do
    share_asc = @engagement_index.visible_sharing.sort
    @engagement_index.sort_by_share_asc
    @engagement_index.wait_until(Utils.short_wait) { @engagement_index.visible_sharing == share_asc }
  end

  it 'can be sorted by "Share" descending' do
    share_desc = @engagement_index.visible_sharing.sort { |x, y| y <=> x }
    @engagement_index.sort_by_share_desc
    @engagement_index.wait_until(Utils.short_wait) { @engagement_index.visible_sharing == share_desc }
  end

  it 'can be sorted by "Points" ascending' do
    points_asc = @engagement_index.visible_points.sort
    @engagement_index.sort_by_points_asc
    @engagement_index.wait_until(Utils.short_wait) { @engagement_index.visible_points == points_asc }
  end

  it 'can be sorted by "Points" descending' do
    points_desc = @engagement_index.visible_points.sort { |x, y| y <=> x }
    @engagement_index.sort_by_points_desc
    @engagement_index.wait_until(Utils.short_wait) { @engagement_index.visible_points == points_desc }
  end

  it 'can be sorted by "Recent Activity" ascending' do
    dates_asc = @engagement_index.visible_activity_dates.sort
    @engagement_index.sort_by_activity_asc
    @engagement_index.wait_until(Utils.short_wait) { @engagement_index.visible_activity_dates == dates_asc }
  end

  it 'can be sorted by "Recent Activity" descending' do
    dates_desc = @engagement_index.visible_activity_dates.sort { |x, y| y <=> x }
    @engagement_index.sort_by_activity_desc
    @engagement_index.wait_until(Utils.short_wait) { @engagement_index.visible_activity_dates == dates_desc }
  end

  # TEACHERS

  it 'allows teachers to see all users\' scores regardless of sharing preferences' do
    expect(@engagement_index.visible_names.sort).to eql([teacher.full_name, student_1.full_name, student_2.full_name, student_3.full_name, student_4.full_name].sort)
  end

  it 'allows teachers to share their scores with students' do
    @engagement_index.share_score
    @engagement_index.wait_until(Utils.short_wait) { @engagement_index.sharing_preference(teacher) == 'Yes' }
    @canvas.masquerade_as(student_4, @course)
    @engagement_index.load_scores(@driver, @engagement_index_url)
    expect(@engagement_index.visible_names).to include(teacher.full_name)
  end

  it 'allows teachers to hide their scores from students' do
    @canvas.masquerade_as(teacher, @course)
    @engagement_index.load_scores(@driver, @engagement_index_url)
    @engagement_index.un_share_score
    @engagement_index.wait_until(Utils.short_wait) { @engagement_index.sharing_preference(teacher) == 'No' }
    @canvas.masquerade_as(student_4, @course)
    @engagement_index.load_scores(@driver, @engagement_index_url)
    expect(@engagement_index.visible_names).not_to include(teacher.full_name)
  end

  # STUDENTS

  it 'allows students to share their scores with other students' do
    @canvas.masquerade_as(student_1, @course)
    @engagement_index.load_page(@driver, @engagement_index_url)
    @engagement_index.share_score
    @engagement_index.users_table_element.when_visible Utils.short_wait
  end

  it 'shows students who have shared their scores a box plot graph of their scores in relation to other users\' scores' do
    expect(@engagement_index.user_info_rank?).to be true
    expect(@engagement_index.user_info_points?).to be true
    expect(@engagement_index.user_info_boxplot?).to be true
  end

  it 'only shows students who have shared their scores the scores of other users who have also shared' do
    expect(@engagement_index.visible_names.sort).to eql([student_1.full_name, student_3.full_name, student_4.full_name])
  end

  it 'shows students the "Rank" column' do
    expect(@engagement_index.sort_by_rank?).to be true
  end

  it 'shows students the "Name" column' do
    expect(@engagement_index.sort_by_name?).to be true
  end

  it 'does not show students the "Share" column' do
    expect(@engagement_index.sort_by_share?).to be false
  end

  it 'shows students the "Points" column' do
    expect(@engagement_index.sort_by_points?).to be true
  end

  it 'shows students the "Recent Activity" column' do
    expect(@engagement_index.sort_by_activity?).to be true
  end

  it 'does not shows students a "Download CSV" button' do
    expect(@engagement_index.download_csv_link?).to be false
  end

  it 'allows students to hide their scores from other students' do
    @engagement_index.un_share_score
    @engagement_index.users_table_element.when_not_visible Utils.short_wait
  end

  it 'shows students who have not shared their scores only their own scores' do
    expect(@engagement_index.user_info_rank?).to be false
    expect(@engagement_index.user_info_points?).to be true
    expect(@engagement_index.user_info_boxplot?).to be true
  end

  # TEACHERS AND STUDENTS

  describe 'Canvas syncing' do

    before(:all) do
      @canvas.stop_masquerading
      [teacher, student_4].each { |user| @canvas.remove_user_from_course(@course, user) }
    end

    [teacher, student_4].each do |user|

      it "removes #{user.role} UID #{user.uid} from the Engagement Index if the user has been removed from the course site" do
        @canvas.load_homepage
        @canvas.stop_masquerading if @canvas.stop_masquerading_link?
        @engagement_index.wait_until(Utils.long_wait) do
          @engagement_index.load_page(@driver, @engagement_index_url)
          !@engagement_index.visible_names.include? user.full_name
        end
      end

      it "prevents #{user.role} UID #{user.uid} from reaching the Engagement Index if the user has been removed from the course site" do
        @canvas.masquerade_as(user, @course)
        @engagement_index.navigate_to @engagement_index_url
        @canvas.unauthorized_msg_element.when_visible Utils.short_wait
      end
    end

  end
end
