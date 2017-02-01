require_relative '../../util/spec_helper'

include Logging

describe 'Canvas assignment sync', order: :defined do

  course_id = ENV['course_id']
  test_id = Utils.get_test_id

  before(:all) do
    @course = Course.new({})
    @course.site_id = course_id
    @driver = Utils.launch_browser
    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @asset_library = Page::SuiteCPages::AssetLibraryPage.new @driver
    @engagement_index = Page::SuiteCPages::EngagementIndexPage.new @driver

    # Load test data
    user_test_data = Utils.load_test_users.select { |data| data['tests']['canvasAssignmentSyncing'] }
    @teacher = User.new user_test_data.find { |data| data['role'] == 'Teacher' }
    @student = User.new user_test_data.find { |data| data['role'] == 'Student' }
    @assignment_1 = Assignment.new("Submission Assignment 1 #{test_id}", nil)
    @assignment_2 = Assignment.new("Submission Assignment 2 #{test_id}", nil)

    # Create course site if necessary. If an existing site, ensure Canvas sync is enabled.
    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.get_suite_c_test_course(@course, [@teacher, @student], test_id, [SuiteCTools::ASSET_LIBRARY, SuiteCTools::ENGAGEMENT_INDEX])
    @asset_library_url = @canvas.click_tool_link(@driver, SuiteCTools::ASSET_LIBRARY)
    @engagement_index_url = @canvas.click_tool_link(@driver, SuiteCTools::ENGAGEMENT_INDEX)
    @asset_library.ensure_canvas_sync(@driver, @asset_library_url) unless course_id.nil?

    @asset_1 = Asset.new @student.assets[0]
    @asset_1.title = @asset_library.get_canvas_submission_title @asset_1
    @asset_1.category = @assignment_1.title
    @asset_2 = Asset.new @student.assets[1]
    @asset_2.title = @asset_library.get_canvas_submission_title @asset_2
    @asset_2.category = @assignment_2.title

    # Get users' scores before submission
    @engagement_index.load_scores(@driver, @engagement_index_url)
    @initial_score = @engagement_index.user_score @student

    # Teacher creates two assignments and waits for them to appear in the Asset Library categories list
    @canvas.masquerade_as(@teacher, @course)
    @canvas.load_course_site @course
    @canvas.create_assignment(@course, @assignment_1)
    @canvas.create_assignment(@course, @assignment_2)
    @asset_library.wait_for_canvas_category(@driver, @asset_library_url, @assignment_1)
    @asset_library.wait_for_canvas_category(@driver, @asset_library_url, @assignment_2)
  end

  after(:all) { @driver.quit }

  it 'is false by default' do
    expect(@asset_library.assignment_sync_cbx(@assignment_1).checked?).to be false
    expect(@asset_library.assignment_sync_cbx(@assignment_2).checked?).to be false
  end

  context 'when enabled for Assignment 1 but not enabled for Assignment 2' do

    before(:all) do
      # Teacher enables sync for assignment 1 but not assignment 2
      @canvas.masquerade_as(@teacher, @course)
      @asset_library.load_page(@driver, @asset_library_url)
      @asset_library.click_manage_assets_link
      @asset_library.enable_assignment_sync @assignment_1
      @asset_library.pause_for_poller

      # Student submits both assignments
      @canvas.masquerade_as(@student, @course)
      @canvas.submit_assignment(@assignment_1, @student, @asset_1)
      @canvas.submit_assignment(@assignment_2, @student, @asset_2)
      @canvas.stop_masquerading
    end

    it 'adds assignment submission points to the Engagement Index score for both submissions' do
      user_score_updated = @engagement_index.user_score_updated?(@driver, @engagement_index_url, @student, (@initial_score.to_i + (Activities::SUBMIT_ASSIGNMENT.points * 2)).to_s)
      expect(user_score_updated).to be true
    end

    it 'adds assignment submission activity to the CSV export for both submissions' do
      rows = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
      expected_row_1 = "#{@student.full_name}, #{Activities::SUBMIT_ASSIGNMENT.type}, #{Activities::SUBMIT_ASSIGNMENT.points}, #{@initial_score.to_i + Activities::SUBMIT_ASSIGNMENT.points}"
      expected_row_2 = "#{@student.full_name}, #{Activities::SUBMIT_ASSIGNMENT.type}, #{Activities::SUBMIT_ASSIGNMENT.points}, #{@initial_score.to_i + (Activities::SUBMIT_ASSIGNMENT.points * 2)}"
      expect(rows & [expected_row_1, expected_row_2]).to eql([expected_row_1, expected_row_2])
    end

    it 'shows the Assignment 1 submission in the Asset Library' do
      @asset_library.load_page(@driver, @asset_library_url)
      @asset_library.advanced_search(nil, @assignment_1.title, @student, nil)
      @asset_library.wait_until(Utils.short_wait) { @asset_library.list_view_asset_ids.length == 1 }
      @asset_library.verify_first_asset(@student, @asset_1)
    end

    it 'hides the Assignment 2 submission in the Asset Library' do
      @asset_library.load_page(@driver, @asset_library_url)
      @asset_library.wait_for_page_load_and_click @asset_library.advanced_search_button_element
      expect(@asset_library.category_select_options).to_not include(@assignment_2.title)
    end
  end

  context 'when disabled for Assignment 1 but enabled for Assignment 2' do

    before(:all) do
      # Teacher disables sync for assignment 1 and enables it for assignment 2
      @canvas.masquerade_as(@teacher, @course)
      @asset_library.load_page(@driver, @asset_library_url)
      @asset_library.click_manage_assets_link
      @asset_library.disable_assignment_sync @assignment_1
      @asset_library.enable_assignment_sync @assignment_2
    end

    it 'does not alter existing assignment submission points on the Engagement Index score' do
      @engagement_index.load_scores(@driver, @engagement_index_url)
      expect(@engagement_index.user_score @student).to eql((@initial_score.to_i + (Activities::SUBMIT_ASSIGNMENT.points * 2)).to_s)
    end

    it 'does not alter existing assignment submission activity on the CSV export' do
      rows = @engagement_index.download_csv(@driver, @course, @engagement_index_url)
      expected_row_1 = "#{@student.full_name}, #{Activities::SUBMIT_ASSIGNMENT.type}, #{Activities::SUBMIT_ASSIGNMENT.points}, #{@initial_score.to_i + Activities::SUBMIT_ASSIGNMENT.points}"
      expected_row_2 = "#{@student.full_name}, #{Activities::SUBMIT_ASSIGNMENT.type}, #{Activities::SUBMIT_ASSIGNMENT.points}, #{@initial_score.to_i + (Activities::SUBMIT_ASSIGNMENT.points * 2)}"
      expect(rows & [expected_row_1, expected_row_2]).to eql([expected_row_1, expected_row_2])
    end

    it 'hides the Assignment 1 submission in the Asset Library' do
      @asset_library.load_page(@driver, @asset_library_url)
      @asset_library.wait_for_page_load_and_click @asset_library.advanced_search_button_element
      expect(@asset_library.category_select_options).to_not include(@assignment_1.title)
    end

    it 'shows the Assignment 2 submission in the Asset Library' do
      @asset_library.load_page(@driver, @asset_library_url)
      @asset_library.advanced_search(nil, @assignment_2.title, @student, nil)
      @asset_library.wait_until(Utils.short_wait) { @asset_library.list_view_asset_ids.length == 1 }
      @asset_library.verify_first_asset(@student, @asset_2)
      expect(@asset_1.id).to_not eql(@asset_2.id)
    end
  end
end
