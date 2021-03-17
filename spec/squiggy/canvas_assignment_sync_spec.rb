require_relative '../../util/spec_helper'

describe 'Canvas assignment sync' do

  before(:all) do
    @test = SquiggyTestConfig.new 'canvas_sync'
    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net= Page::CalNetPage.new @driver
    @assets_list = SquiggyAssetLibraryListViewPage.new @driver
    @asset_detail = SquiggyAssetLibraryDetailPage.new @driver
    @manage_assets = SquiggyAssetLibraryManageAssetsPage.new @driver

    @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course @test

    @assignment_1 = Assignment.new({title: "Submission Assignment 1 #{test_id}"})
    @assignment_2 = Assignment.new({title: "Submission Assignment 2 #{test_id}"})
    @unsinkable_assignment = Assignment.new({title: "Unsinkable Assignment #{test_id}"})

    # Get two file assets for the user
    @student = @test.students.first
    @assets = @student.assets.select &:file_name
    @assets[0].title = @asset_library.get_canvas_submission_title @assets[0]
    @assets[0].category = @assignment_1.title
    @assets[1].title = @asset_library.get_canvas_submission_title @assets[1]
    @assets[1].category = @assignment_2.title

    # Teacher creates on non-sync-able assignment and two sync-able assignments and waits for the latter
    @canvas.masquerade_as(@test.teachers.first, @test.course)
    @canvas.load_course_site @test.course
    @canvas.create_unsyncable_assignment(@test.course, @unsinkable_assignment)
    @canvas.create_assignment(@test.course, @assignment_1)
    @canvas.create_assignment(@test.course, @assignment_2)
    @asset_library_manage.wait_for_canvas_category(@driver, @test.course.asset_library_url, @assignment_1)

    # Get users' scores before submission
    @initial_score = @engagement_index.user_score(@driver, @test.course.engagement_index_url, @student)
  end

  after(:all) { Utils.quit_browser @driver }

  it 'is false by default'
  it 'does not include assignments without sync-able submission types'

  context 'when enabled for Assignment 1 but not enabled for Assignment 2' do
    it 'adds assignment submission points to the Engagement Index score for both submissions'
    it 'adds assignment submission activity to the CSV export for both submissions'
    it 'shows the Assignment 1 submission in the Asset Library'
    it 'does not show the Assignment 2 submission in the Asset Library'
  end

  context 'when disabled for Assignment 1 but enabled for Assignment 2' do
    it 'does not alter existing assignment submission points on the Engagement Index score'
    it 'does not alter existing assignment submission activity on the CSV export'
    it 'hides the Assignment 1 submission in the Asset Library'
    it 'shows the Assignment 2 submission in the Asset Library'
  end
end
