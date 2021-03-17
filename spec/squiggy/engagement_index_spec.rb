require_relative '../../util/spec_helper'

describe 'The Engagement Index' do

  before(:all) do
    @test = SquiggyTestConfig.new 'engagement_index'
    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net= Page::CalNetPage.new @driver
    @assets_list = SquiggyAssetLibraryListViewPage.new @driver
    @asset_detail = SquiggyAssetLibraryDetailPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver

    @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course @test

    @canvas.masquerade_as(@test.course.students.first, @test.course)

    # TODO - upload an asset
    # TODO - comment on the asset
    # TODO - like the asset
  end

  after(:all) { Utils.quit_browser @driver }

  it 'is sorted by "Rank" descending by default'
  it 'can be sorted by "Rank" ascending'
  it 'can be sorted by "Rank" descending'
  it 'can be sorted by "Name" ascending'
  it 'can be sorted by "Name" descending'
  it 'can be sorted by "Share" ascending'
  it 'can be sorted by "Share" descending'
  it 'can be sorted by "Points" ascending'
  it 'can be sorted by "Points" descending'
  it 'can be sorted by "Recent Activity" ascending'
  it 'can be sorted by "Recent Activity" descending'

  it 'allows teachers to see all users\' scores regardless of sharing preferences'
  it 'allows teachers to share their scores with students'
  it 'allows teachers to hide their scores from students'

  it 'allows students to share their scores with other students'
  it 'shows students who have shared their scores a box plot graph of their scores in relation to other users\' scores'
  it 'only shows students who have shared their scores the scores of other users who have also shared'
  it 'shows students the "Rank" column'
  it 'shows students the "Name" column'
  it 'does not show students the "Share" column'
  it 'shows students the "Points" column'
  it 'shows students the "Recent Activity" column'
  it 'does not shows students a "Download CSV" button'
  it 'allows students to hide their scores from other students'
  it 'shows students who have not shared their scores only their own scores'

  describe 'Canvas syncing' do
    teacher_and_student = []
    teacher_and_student.each do |user|
      it "removes #{user.role} UID #{user.uid} from the Engagement Index if the user has been removed from the course site"
      it "prevents #{user.role} UID #{user.uid} from reaching the Engagement Index if the user has been removed from the course site"
      it "removes #{user.role} UID #{user.uid} from the Asset Library if the user has been removed from the course site"
      it "prevents #{user.role} UID #{user.uid} from reaching the Asset Library if the user has been removed from the course site"
    end
  end
end
