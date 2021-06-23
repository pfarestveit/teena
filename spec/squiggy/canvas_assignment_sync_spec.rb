require_relative '../../util/spec_helper'

describe 'Canvas assignment sync' do

  submit_assignment = SquiggyActivity::SUBMIT_ASSIGNMENT

  before(:all) do
    @test = SquiggyTestConfig.new 'canvas_sync'
    @test.course.site_id = ENV['COURSE_ID']
    @driver = Utils.launch_browser
    @canvas = Page::CanvasAssignmentsPage.new @driver
    @cal_net= Page::CalNetPage.new @driver
    @asset_library = SquiggyAssetLibraryDetailPage.new @driver
    @manage_assets = SquiggyAssetLibraryManageAssetsPage.new @driver
    @engagement_index = SquiggyEngagementIndexPage.new @driver

    @canvas.log_in(@cal_net, @test.admin.username, Utils.super_admin_password)
    @canvas.create_squiggy_course @test

    @assignment_1 = Assignment.new({title: "Submission Assignment 1 #{@test.id}"})
    @assignment_2 = Assignment.new({title: "Submission Assignment 2 #{@test.id}"})
    @unsinkable_assignment = Assignment.new({title: "Unsinkable Assignment #{@test.id}"})

    # Get two file assets for the user
    @student = @test.students.first
    @assets = @student.assets.select &:file_name
    @asset_1 = @assets[0]
    @asset_1.title = @asset_library.canvas_submission_title @asset_1
    @asset_1.category = @assignment_1.title
    @asset_2 = @assets[1]
    @asset_2.title = @asset_library.canvas_submission_title @asset_2
    @asset_2.category = @assignment_2.title

    # Teacher creates on non-sync-able assignment and two sync-able assignments and waits for the latter
    @canvas.masquerade_as(@test.teachers.first, @test.course)
    @canvas.load_course_site @test.course
    @canvas.create_unsyncable_assignment(@test.course, @unsinkable_assignment)
    @canvas.create_assignment(@test.course, @assignment_1)
    @canvas.create_assignment(@test.course, @assignment_2)
    @manage_assets.wait_for_canvas_category(@test, @assignment_1)

    # Get score before submission
    @student.score = @engagement_index.user_score(@test, @student)
  end

  after(:all) { Utils.quit_browser @driver }

  it 'is false by default' do
    @manage_assets.wait_for_canvas_category(@test, @assignment_2)
    expect(@manage_assets.assignment_sync_cbx(@assignment_1).checked?).to be false
    expect(@manage_assets.assignment_sync_cbx(@assignment_2).checked?).to be false
  end

  it 'does not include assignments without sync-able submission types' do
    expect(@manage_assets.canvas_category_title_elements.map(&:text)).not_to include(@unsinkable_assignment.title)
  end

  context 'when enabled for Assignment 1 but not enabled for Assignment 2' do

    before(:all) do
      # Teacher enables sync for assignment 1 but not assignment 2
      @asset_library.load_page @test
      @asset_library.click_manage_assets_link
      @manage_assets.enable_assignment_sync @assignment_1
      poller_assignment = Assignment.new({title: "Throwaway Assignment 1 #{@test.id}"})
      @canvas.create_assignment(@test.course, poller_assignment)
      @manage_assets.wait_for_canvas_category(@test, poller_assignment)

      # Student submits both assignments
      @canvas.masquerade_as(@student, @test.course)
      @canvas.submit_assignment(@assignment_1, @student, @asset_1)
      @canvas.submit_assignment(@assignment_2, @student, @asset_2)
      @canvas.masquerade_as(@test.teachers.first, @test.course)
    end

    it 'adds assignment submission points to the Engagement Index score for both submissions' do
      expected_score = @student.score + (submit_assignment.points * 2)
      user_score_updated = @engagement_index.user_score_updated?(@test, @student, expected_score)
      expect(user_score_updated).to be true
    end

    it 'adds assignment submission activity to the CSV export for both submissions' do
      csv = @engagement_index.download_csv @test
      assign_1 = csv.find do |r|
        r[:user_name] == @student.full_name &&
          r[:action] == submit_assignment.type &&
          r[:score] == submit_assignment.points &&
          r[:running_total] == (@student.score - submit_assignment.points)
      end
      assign_2 = csv.find do |r|
        r[:user_name] == @student.full_name &&
          r[:action] == submit_assignment.type &&
          r[:score] == submit_assignment.points &&
          r[:running_total] == @student.score
      end
      expect(assign_1).to be_truthy
      expect(assign_2).to be_truthy
    end

    it 'shows the Assignment 1 submission in the Asset Library' do
      @asset_library.load_page @test
      SquiggyUtils.set_asset_id(@asset_1, @assignment_1.id)
      @asset_library.advanced_search(nil, @assignment_1.title, @student, nil, nil)
      expect(@asset_library.visible_list_view_asset_data(@asset_1)[:title]).to eql(@asset_1.title)
    end

    it 'does not show the Assignment 2 submission in the Asset Library' do
      @asset_library.load_page @test
      @asset_library.open_advanced_search
      @asset_library.click_category_search_select
      expect(@asset_library.parameter_option(@assignment_2.title).exists?).to be false
    end
  end

  context 'when disabled for Assignment 1 but enabled for Assignment 2' do

    before(:all) do
      # Teacher disables sync for assignment 1 and enables it for assignment 2
      @asset_library.load_page @test
      @asset_library.click_manage_assets_link
      @manage_assets.disable_assignment_sync @assignment_1
      @manage_assets.enable_assignment_sync @assignment_2
      poller_assignment = Assignment.new({title: "Throwaway Assignment 2 #{@test.id}"})
      @canvas.create_assignment(@test.course, poller_assignment)
      @manage_assets.wait_for_canvas_category(@test, poller_assignment)
    end

    it 'does not alter existing assignment submission points on the Engagement Index score' do
      expect(@engagement_index.user_score(@test, @student)).to eql(@student.score)
    end

    it 'does not alter existing assignment submission activity on the CSV export' do
      csv = @engagement_index.download_csv @test
      assign_1 = csv.find do |r|
        r[:user_name] == @student.full_name &&
          r[:action] == submit_assignment.type &&
          r[:score] == submit_assignment.points &&
          r[:running_total] == (@student.score - submit_assignment.points)
      end
      assign_2 = csv.find do |r|
        r[:user_name] == @student.full_name &&
          r[:action] == submit_assignment.type &&
          r[:score] == submit_assignment.points &&
          r[:running_total] == @student.score
      end
      expect(assign_1).to be_truthy
      expect(assign_2).to be_truthy
    end

    it 'hides the Assignment 1 submission in the Asset Library' do
      @asset_library.load_page @test
      @asset_library.open_advanced_search
      @asset_library.click_category_search_select
      expect(@asset_library.parameter_option(@assignment_1.title).exists?).to be false
    end

    it 'shows the Assignment 2 submission in the Asset Library' do
      @asset_library.load_page @test
      SquiggyUtils.set_asset_id(@asset_2, @assignment_2.id)
      @asset_library.advanced_search(nil, @assignment_2.title, @student, nil, nil)
      expect(@asset_library.visible_list_view_asset_data(@asset_2)[:title]).to eql(@asset_2.title)
    end
  end
end
