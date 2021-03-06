require_relative '../../util/spec_helper'

test = SquiggyTestConfig.new 'engagement_index'
teacher = test.teachers.first
student_0 = test.students[0]
student_1 = test.students[1]
student_2 = test.students[2]
student_3 = test.students[3]

describe 'The Engagement Index' do

  before(:all) do
    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net= Page::CalNetPage.new @driver
    @assets_list = SquiggyAssetLibraryListViewPage.new @driver
    @asset_detail = SquiggyAssetLibraryDetailPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver

    @canvas.log_in(@cal_net, test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course test
    
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
    @engagement_index.sort_by_share_asc
    @engagement_index.wait_until(1) { @engagement_index.visible_sharing == @engagement_index.visible_sharing.sort }
  end

  it 'can be sorted by "Share" descending' do
    @engagement_index.sort_by_share_desc
    @engagement_index.wait_until(1) { @engagement_index.visible_sharing == @engagement_index.visible_sharing.sort.reverse }
  end

  it 'can be sorted by "Points" ascending' do
    @engagement_index.sort_by_points_asc
    @engagement_index.wait_until(1) { @engagement_index.visible_points == @engagement_index.visible_points.sort }
  end

  it 'can be sorted by "Points" descending' do
    @engagement_index.sort_by_points_desc
    @engagement_index.wait_until(1) { @engagement_index.visible_points == @engagement_index.visible_points.sort.reverse }
  end

  it 'can be sorted by "Recent Activity" ascending' do
    @engagement_index.sort_by_activity_asc
    @engagement_index.wait_until(1) { @engagement_index.visible_activity_dates == @engagement_index.visible_activity_dates.sort }
  end

  it 'can be sorted by "Recent Activity" descending' do
    @engagement_index.sort_by_activity_desc
    @engagement_index.wait_until(1) { @engagement_index.visible_activity_dates == @engagement_index.visible_activity_dates.sort.reverse }
  end

  # TEACHERS

  it 'allows teachers to see all users\' scores regardless of sharing preferences' do
    expect(@engagement_index.visible_names.sort).to eql(test.course.roster.map(&:full_name).sort)
  end

  it 'allows teachers to share their scores with students' do
    @engagement_index.share_score
    @engagement_index.wait_until(Utils.short_wait) { @engagement_index.sharing_preference(teacher) == 'Yes' }
    @canvas.masquerade_as(student_3, test.course)
    @engagement_index.load_scores test
    expect(@engagement_index.visible_names).to include(teacher.full_name)
  end

  it 'allows teachers to hide their scores from students' do
    @canvas.masquerade_as(teacher, test.course)
    @engagement_index.load_scores test
    @engagement_index.un_share_score
    @engagement_index.wait_for_scores
    @engagement_index.wait_until(Utils.short_wait) { @engagement_index.sharing_preference(teacher) == 'No' }
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

  # TEACHERS AND STUDENTS

  describe 'Canvas syncing' do

    before(:all) do
      @canvas.stop_masquerading
      @canvas.remove_users_from_course(test.course, [teacher, student_3])
    end

    [teacher, student_3].each do |user|

      it "removes #{user.role} UID #{user.uid} from the Engagement Index if the user has been removed from the course site" do
        @canvas.load_homepage
        @canvas.stop_masquerading if @canvas.stop_masquerading_link?
        @engagement_index.wait_until(Utils.medium_wait) do
          sleep 10
          @engagement_index.load_scores test
          !@engagement_index.visible_names.include? user.full_name
        end
      end

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
        @assets_list.expand_adv_search
        @assets_list.click_uploader_select
        expect(@assets_list.asset_uploader_options).not_to include(user.full_name)
      end
    end
  end
end
