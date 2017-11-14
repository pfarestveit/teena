require_relative '../util/spec_helper'

begin

  include Logging
  test_id = Utils.get_test_id
  course_title = "Activity Network #{test_id}"
  test_data = SuiteCUtils.load_suitec_test_data

  # Load the test script CSV
  test_script = CSV.table File.join(ENV['HOME'], '.webdriver-config/test-steps-activity-network.csv')

  uids = test_script[:uid].uniq
  user_data = test_data.select { |d| uids.include? d['uid'] }
  users = user_data.map { |d| User.new(d) }
  @assets = []
  @comments = []
  @whiteboards = []
  @discussions = []

  def find_asset(step)
    @assets.find { |a| a.title.include? step[:asset] }
  end

  def find_comment(step)
    @comments.find { |c| c.body.include? step[:comment] }
  end

  def find_whiteboard(step)
    @whiteboards.find { |w| w.title.include? step[:whiteboard] }
  end

  def find_discussion(step)
    @discussions.find { |d| d.title.include? step[:discussion] }
  end

  @course = Course.new({:title => course_title, :code => course_title})
  @course.site_id = ENV['COURSE']

  @driver = Utils.launch_browser
  @canvas = Page::CanvasActivitiesPage.new @driver
  @cal_net = Page::CalNetPage.new @driver
  @asset_library_page = Page::SuiteCPages::AssetLibraryPage.new @driver
  @impact_studio_page = Page::SuiteCPages::ImpactStudioPage.new @driver
  @whiteboards_page = Page::SuiteCPages::WhiteboardsPage.new @driver

  # Create course site if necessary
  @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
  @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, users, test_id,
                                     [LtiTools::ASSET_LIBRARY, LtiTools::IMPACT_STUDIO, LtiTools::WHITEBOARDS])
  @asset_library_page_url = @canvas.click_tool_link(@driver, LtiTools::ASSET_LIBRARY)
  @impact_studio_page_url = @canvas.click_tool_link(@driver, LtiTools::IMPACT_STUDIO)
  @whiteboards_url = @canvas.click_tool_link(@driver, LtiTools::WHITEBOARDS)

  test_script.each do |step|

    step_number = test_script.find_index(step) + 1
    logger.info "Executing step #{step_number}: #{step[:test_case]}"

    begin

      # Determine which user will take action
      user = users.find { |u| u.uid == step[:uid] }
      @canvas.masquerade_as(@driver, user, @course)

      # Determine which action to take
      case step[:action]

        # ASSETS

        when 'add_asset'
          asset = Asset.new user.assets.first
          asset.title = "#{step[:asset]} - #{test_id}"
          @asset_library_page.load_page(@driver, @asset_library_page_url)
          asset.type == 'File' ?
              @asset_library_page.upload_file_to_library(asset) :
              @asset_library_page.add_site(asset)
          @assets << asset

        when 'view_asset'
          @asset_library_page.load_asset_detail(@driver, @asset_library_page_url, find_asset(step))

        when 'like'
          @asset_library_page.load_asset_detail(@driver, @asset_library_page_url, asset = find_asset(step))
          @asset_library_page.like_asset asset

        when 'unlike'
          @asset_library_page.load_asset_detail(@driver, @asset_library_page_url, asset = find_asset(step))
          @asset_library_page.unlike_asset asset

        when 'comment'
          asset = find_asset step
          comment = Comment.new(user, "#{asset.title} - #{step[:comment]}")
          @asset_library_page.load_asset_detail(@driver, @asset_library_page_url, asset)
          @asset_library_page.add_comment(asset, comment)
          @comments << comment

        when 'comment_reply'
          comment = find_comment(step)
          reply = Comment.new(user, "#{comment.body} - #{step[:reply]}")
          @asset_library_page.load_asset_detail(@driver, @asset_library_page_url, asset = find_asset(step))
          @asset_library_page.reply_to_comment(asset, comment, reply)

        when 'delete_comment'
          @asset_library_page.load_asset_detail(@driver, @asset_library_page_url, asset = find_asset(step))
          @asset_library_page.delete_comment(asset, find_comment(step))

        when 'pin_asset'
          @asset_library_page.load_asset_detail(@driver, @asset_library_page_url, asset = find_asset(step))
          @asset_library_page.pin_detail_view_asset asset

        when 'unpin_asset'
          @asset_library_page.load_asset_detail(@driver, @asset_library_page_url, asset = find_asset(step))
          @asset_library_page.unpin_detail_view_asset asset

        when 'delete_asset'
          @asset_library_page.load_asset_detail(@driver, @asset_library_page_url, asset = find_asset(step))
          @asset_library_page.delete_asset asset

        # WHITEBOARDS

        when 'add_whiteboard'
          collaborators = users.select { |u| step[:collaborators].include? "#{u.uid}" }
          whiteboard = Whiteboard.new(:title => "#{step[:whiteboard]} - #{test_id}", :collaborators => collaborators)
          @whiteboards_page.load_page(@driver, @whiteboards_url)
          @whiteboards_page.create_whiteboard whiteboard
          @whiteboards << whiteboard

        when 'whiteboard_add_asset'
          @whiteboards_page.load_page(@driver, @whiteboards_url)
          @whiteboards_page.open_whiteboard(@driver, find_whiteboard(step))
          @whiteboards_page.add_existing_assets [find_asset(step)]
          @whiteboards_page.close_whiteboard @driver

        when 'export_whiteboard'
          @whiteboards_page.load_page(@driver, @whiteboards_url)
          @whiteboards_page.open_whiteboard(@driver, whiteboard = find_whiteboard(step))
          asset = @whiteboards_page.export_to_asset_library(whiteboard)
          @assets << asset

        when 'remix_whiteboard'
          @asset_library_page.load_asset_detail(@driver, @asset_library_page_url, find_asset(step))
          whiteboard = @asset_library_page.click_remix
          @whiteboards << whiteboard

        # DISCUSSIONS

        when 'discussion_topic'
          discussion = Discussion.new "#{step[:discussion]} - #{test_id}"
          @canvas.create_course_discussion(@driver, @course, discussion)
          @discussions << discussion

        when 'discussion_entry'
          @canvas.add_reply(find_discussion(step), nil, "#{step[:reply]} - #{test_id}")

        when 'delete_discussion'
          discussion = find_discussion step
          @canvas.delete_activity(discussion.title, discussion.url)

        else
          logger.error "Step not supported: #{step}"

      end

      @impact_studio_page.load_page(@driver, @impact_studio_page_url)
      sleep Utils.short_wait
      Utils.save_screenshot(@driver, "#{test_id}-step#{step_number}-#{step[:uid]}-#{step[:action]}")

    rescue => e
      logger.error "Step failed: #{step}"
      Utils.log_error e
    end
  end

ensure
  Utils.quit_browser @driver
end
