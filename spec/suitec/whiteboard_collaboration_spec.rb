require_relative '../../util/spec_helper'

describe 'Whiteboard', order: :defined do

  include Logging

  course_id = ENV['COURSE_ID']
  test_id = Utils.get_test_id
  event_driver_1 = Event.new({test_script: self, test_id: test_id})
  event_driver_2 = Event.new({test_script: self, test_id: test_id})
  event_driver_3 = Event.new({test_script: self, test_id: test_id})
  timeout = Utils.short_wait

  course = Course.new({title: "Whiteboard Collaboration #{test_id}"})
  course.site_id = course_id

  # Load test users
  user_test_data = SuiteCUtils.load_suitec_test_data.select { |data| data['tests']['whiteboard_collaboration'] }
  admin = User.new({uid: Utils.super_admin_uid, username: Utils.super_admin_username})
  users = []
  users << (teacher = User.new user_test_data.find { |data| data['role'] == 'Teacher' })
  users << (lead_ta = User.new user_test_data.find { |data| data['role'] == 'Lead TA' })
  users << (ta = User.new user_test_data.find { |data| data['role'] == 'TA' })
  users << (designer = User.new user_test_data.find { |data| data['role'] == 'Designer' })
  users << (observer = User.new user_test_data.find { |data| data['role'] == 'Observer' })
  users << (reader = User.new user_test_data.find { |data| data['role'] == 'Reader' })

  students_data = user_test_data.select { |data| data['role'] == 'Student' }
  users << (student_1 = User.new students_data[0])
  users << (student_2 = User.new students_data[1])
  users << (student_3 = User.new students_data[2])

  before(:all) do

    # Launch first browser
    @driver_1 = Utils.launch_browser
    @canvas_driver_1 = Page::CanvasPage.new @driver_1
    @cal_net_driver_1 = Page::CalNetPage.new @driver_1
    @whiteboards_driver_1 = Page::SuiteCPages::WhiteboardPage.new @driver_1
    @engagement_index_driver_1 = Page::SuiteCPages::EngagementIndexConfigPage.new @driver_1

    # Create course site if necessary. If using an existing site, include the Asset Library and make sure Canvas sync is enabled.
    tools = [LtiTools::ENGAGEMENT_INDEX, LtiTools::WHITEBOARDS]
    tools << LtiTools::ASSET_LIBRARY unless course_id.nil?
    @canvas_driver_1.log_in(@cal_net_driver_1, admin.username, Utils.super_admin_password)
    event_driver_1.actor = admin
    @canvas_driver_1.create_generic_course_site(@driver_1, Utils.canvas_qa_sub_account, course, users, test_id, tools)
    @whiteboards_url = @canvas_driver_1.click_tool_link(@driver_1, LtiTools::WHITEBOARDS, event_driver_1)
    @engagement_index_url = @canvas_driver_1.click_tool_link(@driver_1, LtiTools::ENGAGEMENT_INDEX, event_driver_1)
    if course_id
      @asset_library = Page::SuiteCPages::AssetLibraryDetailPage.new @driver_1
      @asset_library_url = @canvas_driver_1.click_tool_link(@driver_1, LtiTools::ASSET_LIBRARY, event_driver_1)
      @asset_library.ensure_canvas_sync(@driver_1, @asset_library_url, event_driver_1)
    end

    # Wait until all are synced to the course before proceeding
    @engagement_index_driver_1.wait_for_new_user_sync(@driver_1, @engagement_index_url, course, users, event_driver_1)

    # Create three whiteboards
    @whiteboards = []
    @whiteboards << (@whiteboard_1 = Whiteboard.new({owner: student_1, title: "Whiteboard Collaboration #{test_id} - board 1", collaborators: [student_2, student_3]}))
    @whiteboards << (@whiteboard_2 = Whiteboard.new({owner: student_2, title: "Whiteboard Collaboration #{test_id} - board 2", collaborators: [teacher, student_1]}))
    @whiteboards << (@whiteboard_3 = Whiteboard.new({owner: student_3, title: "Whiteboard Collaboration #{test_id} - board 3", collaborators: []}))

    @whiteboards.each do |board|
      @canvas_driver_1.masquerade_as(@driver_1, (event_driver_1.actor = board.owner), course)
      @whiteboards_driver_1.load_page(@driver_1, @whiteboards_url, event_driver_1)
      @whiteboards_driver_1.create_whiteboard(board, event_driver_1)
    end
  end

  after(:all) { @driver_1.quit }

  describe 'access' do

    after(:each) { @whiteboards_driver_1.close_whiteboard @driver_1 }

    [teacher, lead_ta, ta, designer, observer, reader].each do |user|

      it "allows a course #{user.role} to search for whiteboards if the user has permission to do so" do
        @canvas_driver_1.masquerade_as(@driver_1, (event_driver_1.actor = user), course)
        @whiteboards_driver_1.load_page(@driver_1, @whiteboards_url, event_driver_1)
        if ['Teacher', 'Lead TA', 'TA', 'Designer', 'Reader'].include? user.role
          logger.info "Verifying #{user.role} #{user.full_name} has access to whiteboard search"
          @whiteboards_driver_1.simple_search("Collaboration #{test_id}", event_driver_1)
          @whiteboards_driver_1.wait_until(timeout) { @whiteboards_driver_1.list_view_whiteboard_elements.length == 3 }
          @whiteboards_driver_1.wait_until(timeout) { @whiteboards_driver_1.visible_whiteboard_titles.sort == [@whiteboard_1.title, @whiteboard_2.title, @whiteboard_3.title].sort }
        else
          logger.info "Verifying #{user.role} #{user.full_name} has no access to whiteboard search"
          has_access = @whiteboards_driver_1.verify_block { @whiteboards_driver_1.simple_search_input_element.when_visible 2 }
          expect(has_access).to be false
        end
      end

      it "allows a course #{user.role} to view any whiteboard and its membership if the user has permission to do so" do
        @canvas_driver_1.masquerade_as(@driver_1, (event_driver_1.actor = user), course)
        if ['Teacher', 'Lead TA', 'TA', 'Designer', 'Reader'].include? user.role
          logger.info "Verifying #{user.role} #{user.full_name} has access to '#{@whiteboard_3.title}' and its membership"
          @whiteboards_driver_1.load_page(@driver_1, @whiteboards_url, event_driver_1)
          @whiteboards_driver_1.open_whiteboard(@driver_1, @whiteboard_3, event_driver_1)
          @whiteboards_driver_1.verify_collaborators [@whiteboard_3.owner, @whiteboard_3.collaborators]
          @whiteboards_driver_1.close_whiteboard @driver_1
        else
          @whiteboards_driver_1.hit_whiteboard_url(course, @whiteboards_url, @whiteboard_3, event_driver_1)
          has_access = @whiteboards_driver_1.verify_block { @whiteboards_driver_1.settings_button_element.when_visible 2 }
          expect(has_access).to be false
        end
      end

      it "allows a course #{user.role} to delete any whiteboard if the user has permission to do so" do
        @canvas_driver_1.masquerade_as(@driver_1, (event_driver_1.actor = user), course)
        if ['Teacher', 'Lead TA', 'TA', 'Designer', 'Reader'].include? user.role
          logger.info "Verifying #{user.role} #{user.full_name} has a delete button for '#{@whiteboard_3.title}'"
          @whiteboards_driver_1.load_page(@driver_1, @whiteboards_url, event_driver_1)
          @whiteboards_driver_1.open_whiteboard(@driver_1, @whiteboard_3, event_driver_1)
          @whiteboards_driver_1.click_settings_button
          has_delete_button = @whiteboards_driver_1.verify_block { @whiteboards_driver_1.delete_button_element.when_visible timeout }
          @whiteboards_driver_1.close_whiteboard @driver_1
          expect(has_delete_button).to be true
        else
          @whiteboards_driver_1.hit_whiteboard_url(course, @whiteboards_url, @whiteboard_3, event_driver_1)
          has_access = @whiteboards_driver_1.verify_block { @whiteboards_driver_1.settings_button_element.when_visible 2 }
          expect(has_access).to be false
        end
      end
    end

    context 'when the user is a Student with membership in some whiteboards but not all' do

      after(:each) { @whiteboards_driver_1.close_whiteboard @driver_1 }

      it 'the user can see its whiteboards' do
        @canvas_driver_1.masquerade_as(@driver_1, (event_driver_1.actor = student_1), course)
        @whiteboards_driver_1.load_page(@driver_1, @whiteboards_url, event_driver_1)
        @whiteboards_driver_1.wait_until(timeout) do
          @whiteboards_driver_1.list_view_whiteboard_title_elements.any?
          @whiteboards_driver_1.list_view_whiteboard_title_elements[0].text == @whiteboard_2.title
        end
        @whiteboards_driver_1.wait_until(timeout) { @whiteboards_driver_1.list_view_whiteboard_title_elements[1].text == @whiteboard_1.title }
      end

      it 'the user cannot see or reach other whiteboards' do
        @whiteboards_driver_1.wait_until(timeout) do
          @whiteboards_driver_1.list_view_whiteboard_title_elements.length == 2 ||
              @whiteboards_driver_1.list_view_whiteboard_title_elements[2].text != @whiteboard_3.title
        end
        @whiteboards_driver_1.hit_whiteboard_url(course, @whiteboards_url, @whiteboard_3, event_driver_1)
        has_access = @whiteboards_driver_1.verify_block { @whiteboards_driver_1.settings_button_element.when_visible timeout }
        expect(has_access).to be false
      end
    end
  end

  describe 'collaboration' do

    before(:all) do
      @driver_2 = Utils.launch_browser Utils.optional_chrome_profile_dir
      @canvas_driver_2 = Page::CanvasPage.new @driver_2
      @cal_net_driver_2 = Page::CalNetPage.new @driver_2
      @whiteboards_driver_2 = Page::SuiteCPages::WhiteboardPage.new @driver_2
      @canvas_driver_2.log_in(@cal_net_driver_2, Utils.super_admin_username, Utils.super_admin_password)
    end

    after(:all) { @driver_2.quit }

    describe 'members pane' do

      before(:all) do
        @canvas_driver_1.masquerade_as(@driver_1, (event_driver_1.actor = student_1), course)
        @canvas_driver_2.masquerade_as(@driver_2, (event_driver_2.actor = student_3), course)
        @whiteboards_driver_2.load_page(@driver_2, @whiteboards_url, event_driver_2)
      end

      after(:all) { @whiteboards_driver_2.close_whiteboard @driver_2 }

      it "allows #{student_1.full_name} to see a list of all whiteboard members" do
        @whiteboards_driver_1.load_page(@driver_1, @whiteboards_url, event_driver_1)
        @whiteboards_driver_1.open_whiteboard(@driver_1, @whiteboard_1, event_driver_1)
        @whiteboards_driver_1.show_collaborators_pane
        @whiteboards_driver_1.wait_until(timeout) do
          @whiteboards_driver_1.collaborator student_1
          @whiteboards_driver_1.collaborator student_2
          @whiteboards_driver_1.collaborator student_3
        end
      end

      it("allows #{student_1.full_name} to see which members are currently online") { expect(@whiteboards_driver_1.collaborator_online? student_1).to be true }

      it "allows #{student_1.full_name} to see which members are currently offline" do
        expect(@whiteboards_driver_1.collaborator_online? student_2).to be false
        expect(@whiteboards_driver_1.collaborator_online? student_3).to be false
      end

      it "allows #{student_1.full_name} to see which members have just come online" do
        @whiteboards_driver_2.open_whiteboard(@driver_2, @whiteboard_1, event_driver_2)
        actual_online_time = Time.now
        @whiteboards_driver_1.wait_until(Utils.medium_wait) { @whiteboards_driver_1.collaborator_online? student_3 }
        logger.warn "It took #{Time.now - actual_online_time} seconds for the user to visually appear online"
      end

      it "allows #{student_1.full_name} to see which members have just gone offline" do
        @whiteboards_driver_2.close_whiteboard @driver_2
        actual_offline_time = Time.now
        @whiteboards_driver_1.wait_until(Utils.long_wait) { !@whiteboards_driver_1.collaborator_online? student_3 }
        logger.warn "It took #{Time.now - actual_offline_time} seconds for the user to visually go offline"
      end

      it "does not allow #{student_1.full_name} to see if a non-member teacher has just come online" do
        @canvas_driver_2.masquerade_as(@driver_2, (event_driver_2.actor = teacher), course)
        @whiteboards_driver_2.load_page(@driver_2, @whiteboards_url, event_driver_2)
        @whiteboards_driver_2.open_whiteboard(@driver_2, @whiteboard_1, event_driver_2)
        teacher_visible = @whiteboards_driver_1.verify_block { @whiteboards_driver_1.collaborator(teacher).when_present timeout }
        expect(teacher_visible).to be false
      end

      it "allows #{student_1.full_name} to close the collaborators pane" do
        @whiteboards_driver_1.hide_collaborators_pane
        @whiteboards_driver_1.wait_until(timeout) { !@whiteboards_driver_1.collaborator_elements.last.visible? }
        @whiteboards_driver_1.wait_until(timeout) { !@whiteboards_driver_1.chat_msg_input_element.visible? }
      end

      it "allows #{student_1.full_name} to reopen the collaborators pane" do
        @whiteboards_driver_1.show_collaborators_pane
        @whiteboards_driver_1.wait_until(timeout) { @whiteboards_driver_1.collaborator_elements.last.visible? }
      end
    end

    describe 'chat' do

      before(:all) do
        @whiteboards_driver_1.show_chat_pane

        # Make sure chat activity is configured with a non-zero point value
        @engagement_index_driver_2 = Page::SuiteCPages::EngagementIndexPage.new @driver_2
        @canvas_driver_2.load_course_site(@driver_2, course)
        @engagement_index_driver_2.load_page(@driver_2, @engagement_index_url, event_driver_2)
        @new_chat_point_value = Activity::LEAVE_CHAT_MESSAGE.points + 1
        @engagement_index_driver_2.click_points_config event_driver_2
        @engagement_index_driver_2.change_activity_points(Activity::LEAVE_CHAT_MESSAGE, @new_chat_point_value)
        @engagement_index_driver_2.click_back_to_index event_driver_2
        @initial_score = @engagement_index_driver_2.user_score(@driver_2, @engagement_index_url, student_1, event_driver_2)
      end

      it "allows #{student_1.full_name} to close the chat pane" do
        @whiteboards_driver_1.hide_chat_pane
        @whiteboards_driver_1.wait_until(timeout) { !@whiteboards_driver_1.chat_msg_input_element.visible? }
        @whiteboards_driver_1.wait_until(timeout) { !@whiteboards_driver_1.collaborator_elements.any? }
      end

      it "allows #{student_1.full_name} to reopen the chat pane" do
        @whiteboards_driver_1.show_chat_pane
        @whiteboards_driver_1.wait_until(timeout) { @whiteboards_driver_1.chat_msg_input? }
      end

      it "allows #{teacher.full_name} to send messages to another user" do
        @whiteboards_driver_2.load_page(@driver_2, @whiteboards_url, event_driver_2)
        @whiteboards_driver_2.open_whiteboard(@driver_2, @whiteboard_1, event_driver_2)
        @whiteboards_driver_2.send_chat_msg('foo', event_driver_2)
        @whiteboards_driver_2.verify_chat_msg(teacher, 'foo')
      end

      it "allows #{student_1.full_name} to receive messages from another user" do
        @whiteboards_driver_1.verify_chat_msg(teacher, 'foo')
      end

      it "allows #{student_1.full_name} to send responses to another user" do
        @whiteboards_driver_1.send_chat_msg('bar', event_driver_1)
        @whiteboards_driver_1.verify_chat_msg(student_1, 'bar')
      end

      it "allows #{teacher.full_name} to receive responses from another user" do
        @whiteboards_driver_2.verify_chat_msg(student_1, 'bar')
      end

      it "allows #{student_1.full_name} to send messages with links that open in a new window" do
        @whiteboards_driver_1.send_chat_msg('check out www.google.com', event_driver_1)
        @whiteboards_driver_1.wait_until(timeout) { @whiteboards_driver_1.chat_msg_body_elements.last.text.include? 'check out' }
        @whiteboards_driver_1.external_link_valid?(@driver_1, @whiteboards_driver_1.chat_msg_link('last()', 'www.google.com'), 'Google')
      end

      it "earns '#{Activity::LEAVE_CHAT_MESSAGE.title}' points on the Engagement Index for #{student_1.full_name}" do
        @whiteboards_driver_2.close_whiteboard @driver_2
        expected_score = @initial_score.to_i + (@new_chat_point_value * 2)
        actual_score = (@engagement_index_driver_2.user_score(@driver_2, @engagement_index_url, student_1, event_driver_2)).to_i
        expect(actual_score).to eql(expected_score)
      end

      it "adds '#{Activity::LEAVE_CHAT_MESSAGE.type}' activity to the CSV export for #{student_1.full_name}" do
        scores = @engagement_index_driver_2.download_csv(@driver_2, course, @engagement_index_url)
        expect(scores).to include("#{student_1.full_name}, #{Activity::LEAVE_CHAT_MESSAGE.type}, #{@new_chat_point_value}, #{@initial_score.to_i + @new_chat_point_value}")
        expect(scores).to include("#{student_1.full_name}, #{Activity::LEAVE_CHAT_MESSAGE.type}, #{@new_chat_point_value}, #{@initial_score.to_i + (@new_chat_point_value * 2)}")
      end
    end
  end

  describe 'membership' do

    before(:all) do
      @whiteboards_driver_1.close_whiteboard @driver_1
      @whiteboards_driver_1.open_whiteboard(@driver_1, @whiteboard_1, event_driver_1)
    end

    it "allows #{student_1.full_name} to add a member" do
      @whiteboards_driver_1.add_collaborator(@whiteboard_1, teacher, event_driver_1)
      @whiteboards_driver_1.close_whiteboard @driver_1
      @whiteboards_driver_1.open_whiteboard(@driver_1, @whiteboard_1, event_driver_1)
      @whiteboards_driver_1.show_collaborators_pane
      @whiteboards_driver_1.wait_until(timeout) { @whiteboards_driver_1.collaborator teacher }
    end

    it "allows #{student_1.full_name} to delete a member" do
      @whiteboards_driver_1.remove_collaborator(student_3, event_driver_1)
      @whiteboards_driver_1.close_whiteboard @driver_1
      @whiteboards_driver_1.open_whiteboard(@driver_1, @whiteboard_1, event_driver_1)
      @whiteboards_driver_1.show_collaborators_pane
      @whiteboards_driver_1.collaborator(student_3).when_not_visible timeout rescue Selenium::WebDriver::Error::StaleElementReferenceError
    end

    it "allows #{student_1.full_name} to delete its own membership" do
      @whiteboards_driver_1.remove_collaborator(student_1, event_driver_1)
      @driver_1.switch_to.window @driver_1.window_handles.first
      @whiteboards_driver_1.hit_whiteboard_url(course, @whiteboards_url, @whiteboard_1, event_driver_1)
      has_access = @whiteboards_driver_1.verify_block { @whiteboards_driver_1.settings_button_element.when_visible 2 }
      expect(has_access).to be false
    end
  end

  describe 'Canvas syncing' do

    before(:all) do
      @canvas_driver_1.stop_masquerading @driver_1
      event_driver_1.actor = admin
      @canvas_driver_1.remove_users_from_course(course, [teacher, student_1], event_driver_1)
      # Access to whiteboards is based on session cookie, so launch another browser to check cookie-less access
      @driver_3 = Utils.launch_browser Utils.optional_chrome_profile_dir
      @canvas_driver_3 = Page::CanvasPage.new @driver_3
      @cal_net_driver_3 = Page::CalNetPage.new @driver_3
      @whiteboards_driver_3 = Page::SuiteCPages::WhiteboardPage.new @driver_3
      @canvas_driver_3.log_in(@cal_net_driver_3, admin.username, Utils.super_admin_password)
      event_driver_3.actor = admin
      @engagement_index_url = @canvas_driver_1.click_tool_link(@driver_1, LtiTools::ENGAGEMENT_INDEX, event_driver_3)
      @engagement_index_driver_1 = Page::SuiteCPages::EngagementIndexPage.new @driver_1
    end

    after(:all) { @driver_3.quit }

    [teacher, student_1].each do |user|

      it "removes #{user.role} UID #{user.uid} from all whiteboards if the user has been removed from the course site" do
        @canvas_driver_1.load_course_site(@driver_1, course)
        @canvas_driver_1.stop_masquerading(@driver_1) if @canvas_driver_1.stop_masquerading_link?
        event_driver_1.actor = admin
        # Wait until the user has been dropped from the Engagement Index before checking whiteboards
        @engagement_index_driver_1.wait_for_removed_user_sync(@driver_1, @engagement_index_url, [user], event_driver_1)
        [@whiteboard_1, @whiteboard_2, @whiteboard_3].each do |whiteboard|
          @whiteboards_driver_1.wait_until(Utils.long_wait) do
            @whiteboards_driver_1.hit_whiteboard_url(course, @whiteboards_url, whiteboard, event_driver_1)
            @whiteboards_driver_1.add_event(event_driver_1, EventType::OPEN_WHITEBOARD)
            @whiteboards_driver_1.add_event(event_driver_1, EventType::GET_CHAT_MSG)
            @whiteboards_driver_1.click_settings_button
            !@whiteboards_driver_1.collaborator_name(user).exists?
          end
        end
      end

      it "prevents #{user.role} UID #{user.uid} from reaching any whiteboards if the user has been removed from the course site" do
        @canvas_driver_3.masquerade_as(@driver_3, (event_driver_3.actor = user), course)
        [@whiteboard_1, @whiteboard_2, @whiteboard_3].each do |whiteboard|
          @whiteboards_driver_3.hit_whiteboard_url(course, @whiteboards_url, whiteboard, event_driver_3)
          failure_to_launch = @whiteboards_driver_3.verify_block { @whiteboards_driver_3.launch_failure_element.when_visible timeout }
          expect(failure_to_launch).to be true
        end
      end
    end
  end

  describe 'events' do

    it('record the right number of events') { expect(SuiteCUtils.events_match?(@course, event)).to be true }
  end

end
