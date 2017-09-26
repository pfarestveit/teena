require_relative '../util/spec_helper'

# This script generates 7 assets with varying impact scores, for use in testing the trending asset calculation.

begin

  include Logging
  test_id = Utils.get_test_id

  # Get test users
  user_test_data = SuiteCUtils.load_suitec_test_data.select { |data| data['tests']['impact_studio_assets'] }
  users = user_test_data.map { |data| User.new(data) if %w(Teacher Student).include? data['role'] }
  teacher = users.find { |user| user.role == 'Teacher' }
  students = users.select { |user| user.role == 'Student' }
  student_1 = students[0]
  student_2 = students[1]

  # Get test assets
  all_assets = []
  all_assets << (asset_1 = Asset.new(student_1.assets.find { |a| a['type'] == 'Link' }))
  all_assets << (asset_2 = Asset.new((student_1.assets.select { |a| a['type'] == 'File' })[0]))
  all_assets << (asset_3 = Asset.new((student_1.assets.select { |a| a['type'] == 'File' })[1]))
  all_assets << (asset_4 = Asset.new({}))
  all_assets << (asset_5 = Asset.new(teacher.assets.find { |a| a['type'] == 'File' }))
  all_assets << (asset_6 = Asset.new(student_2.assets.find { |a| a['type'] == 'File' }))
  all_assets << (asset_7 = Asset.new(student_2.assets.find { |a| a['type'] == 'Link' }))
  whiteboard = Whiteboard.new({owner: student_1, title: "Whiteboard #{test_id}", collaborators: [student_2]})

  @course = Course.new({title: "Impact Studio Assets #{test_id}", code: "Impact Studio Assets #{test_id}", site_id: ENV['COURSE_ID']})

  @driver = Utils.launch_browser
  @canvas = Page::CanvasPage.new @driver
  @cal_net = Page::CalNetPage.new @driver
  @asset_library = Page::SuiteCPages::AssetLibraryPage.new @driver
  @engagement_index = Page::SuiteCPages::EngagementIndexPage.new @driver
  @impact_studio = Page::SuiteCPages::ImpactStudioPage.new @driver
  @whiteboards = Page::SuiteCPages::WhiteboardsPage.new @driver

  # Create course site if necessary
  @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
  @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, users, test_id,
                                     [LtiTools::ASSET_LIBRARY, LtiTools::ENGAGEMENT_INDEX, LtiTools::IMPACT_STUDIO, LtiTools::WHITEBOARDS])
  @asset_library_url = @canvas.click_tool_link(@driver, LtiTools::ASSET_LIBRARY)
  @engagement_index_url = @canvas.click_tool_link(@driver, LtiTools::ENGAGEMENT_INDEX)
  @impact_studio_url = @canvas.click_tool_link(@driver, LtiTools::IMPACT_STUDIO)
  @whiteboards_url = @canvas.click_tool_link(@driver, LtiTools::WHITEBOARDS)

  [student_1, student_2].each do |student|
    @canvas.masquerade_as(@driver, student, @course)
    @engagement_index.load_page(@driver, @engagement_index_url)
    @engagement_index.share_score
  end

  # Student 1 add asset 1 via asset library
  @canvas.masquerade_as(@driver, student_1, @course)
  @asset_library.load_page(@driver, @asset_library_url)
  @asset_library.add_site asset_1

  # Student 1 add asset 2 to whiteboard, exclude from asset library
  @whiteboards.load_page(@driver, @whiteboards_url)
  @whiteboards.create_and_open_whiteboard(@driver, whiteboard)
  @whiteboards.add_asset_exclude_from_library asset_2
  @whiteboards.open_original_asset_link_element.when_visible Utils.long_wait
  asset_2.id = @whiteboards.added_asset_id
  asset_2.visible = false
  @whiteboards.close_whiteboard @driver
  @impact_studio.load_page(@driver, @impact_studio_url)

  # Student 1 add asset 3 to a whiteboard and include it in the asset library
  @whiteboards.load_page(@driver, @whiteboards_url)
  @whiteboards.open_whiteboard(@driver, whiteboard)
  @whiteboards.add_asset_include_in_library asset_3
  @whiteboards.open_original_asset_link_element.when_visible Utils.long_wait
  @whiteboards.close_whiteboard @driver
  @asset_library.load_page(@driver, @asset_library_url)
  asset_3.id = @asset_library.list_view_asset_ids.first
  @impact_studio.load_page(@driver, @impact_studio_url)

  # Student 1 export whiteboard to create asset 4
  @whiteboards.load_page(@driver, @whiteboards_url)
  @whiteboards.open_whiteboard(@driver, whiteboard)
  @whiteboards.export_to_asset_library whiteboard
  @whiteboards.close_whiteboard @driver
  @asset_library.load_page(@driver, @asset_library_url)
  asset_4.id = @asset_library.list_view_asset_ids.first
  asset_4.type = 'Whiteboard'
  asset_4.title = whiteboard.title
  @impact_studio.load_page(@driver, @impact_studio_url)

  # Teacher add asset 5 via asset library
  @canvas.masquerade_as(@driver, teacher, @course)
  @asset_library.load_page(@driver, @asset_library_url)
  @asset_library.upload_file_to_library asset_5

  # Student 2 add asset 6 via asset library
  @canvas.masquerade_as(@driver, student_2, @course)
  @asset_library.load_page(@driver, @asset_library_url)
  @asset_library.upload_file_to_library asset_6

  # Student 2 add asset 7 via asset library and then deletes it
  @asset_library.load_page(@driver, @asset_library_url)
  @asset_library.add_site asset_7
  @asset_library.load_asset_detail(@driver, @asset_library_url, asset_7)
  @asset_library.delete_asset asset_7

  # One student uses the other's asset on the shared whiteboard
  @whiteboards.load_page(@driver, @whiteboards_url)
  @whiteboards.open_whiteboard(@driver, whiteboard)
  @whiteboards.add_existing_assets [asset_1]
  @whiteboards.open_original_asset_link_element.when_visible Utils.medium_wait
  @whiteboards.close_whiteboard @driver

  # Teacher views the student's asset
  @canvas.masquerade_as(@driver, teacher, @course)
  @asset_library.load_asset_detail(@driver, @asset_library_url, asset_3)

  # Teacher comments on the student's asset
  @canvas.masquerade_as(@driver, teacher, @course)
  @asset_library.load_asset_detail(@driver, @asset_library_url, asset_6)
  @asset_library.add_comment(asset_6, 'This is a comment from Teacher to Student 2')
  @asset_library.wait_until(Utils.short_wait) { @asset_library.asset_detail_comment_count == '1' }

  # Teacher replies to comment on the student's asset
  @asset_library.load_asset_detail(@driver, @asset_library_url, asset_6)
  @asset_library.reply_to_comment(asset_6, 0, 'This is another comment from Teacher to Student 2')
  @asset_library.wait_until(Utils.short_wait) { @asset_library.asset_detail_comment_count == '2' }

  # One student likes the teacher's asset
  @canvas.masquerade_as(@driver, student_1, @course)
  @asset_library.load_asset_detail(@driver, @asset_library_url, asset_5)
  @asset_library.toggle_detail_view_item_like asset_5
  @asset_library.wait_until { @asset_library.detail_view_asset_likes_count == '1' }

  # Teacher remixes the students' whiteboard
  @canvas.masquerade_as(@driver, teacher, @course)
  @asset_library.load_asset_detail(@driver, @asset_library_url, asset_4)
  @asset_library.click_remix

  asset_1.impact_score = SuiteCUtils.get_asset_impact_score asset_1
  asset_2.impact_score = SuiteCUtils.get_asset_impact_score asset_2
  asset_3.impact_score = SuiteCUtils.get_asset_impact_score asset_3
  asset_4.impact_score = SuiteCUtils.get_asset_impact_score asset_4
  asset_5.impact_score = SuiteCUtils.get_asset_impact_score asset_5
  asset_6.impact_score = SuiteCUtils.get_asset_impact_score asset_6
  asset_7.impact_score = SuiteCUtils.get_asset_impact_score asset_7

  logger.info "The trending asset IDs should be '#{@impact_studio.impactful_studio_asset_ids all_assets}'"

ensure
  Utils.quit_browser @driver
end
