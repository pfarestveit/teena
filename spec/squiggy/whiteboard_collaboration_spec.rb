require_relative '../../util/spec_helper'

describe 'Whiteboard' do

  include Logging

  test = SquiggyTestConfig.new 'whiteboard_collaboration'
  test.course.site_id = ENV['COURSE_ID']
  timeout = Utils.short_wait
  teacher = test.teachers[0]
  student_1 = test.students[0]
  student_2 = test.students[1]
  student_3 = test.students[2]

  before(:all) do
    # Launch first browser
    @driver_1 = Utils.launch_browser
    @canvas_driver_1 = Page::CanvasPage.new @driver_1
    @cal_net_driver_1 = Page::CalNetPage.new @driver_1
    @whiteboards_driver_1 = SquiggyWhiteboardPage.new @driver_1
    @engagement_index_driver_1 = SquiggyEngagementIndexPage.new @driver_1

    @canvas_driver_1.log_in(@cal_net_driver_1, test.admin.username, Utils.super_admin_password)
    @canvas_driver_1.create_squiggy_course test
    @engagement_index_driver_1.wait_for_new_user_sync(test, test.students)

    @whiteboard_1 = SquiggyWhiteboard.new(
      owner: student_1,
      title: "Whiteboard 1 #{test.id}",
      collaborators: [student_2, student_3]
    )
    @whiteboard_2 = SquiggyWhiteboard.new(
      owner: student_2,
      title: "Whiteboard 2 #{test.id}",
      collaborators: [teacher, student_1]
    )
    @whiteboard_3 = SquiggyWhiteboard.new(
      owner: student_3,
      title: "Whiteboard 3 #{test.id}",
      collaborators: []
    )
    @whiteboards = [@whiteboard_1, @whiteboard_2, @whiteboard_3]
    @whiteboards.each do |board|
      @canvas_driver_1.masquerade_as(board.owner, test.course)
      @whiteboards_driver_1.load_page test
      @whiteboards_driver_1.create_whiteboard board
    end
  end

  describe 'access' do

    after(:each) { @whiteboards_driver_1.close_whiteboard }

    [teacher, test.lead_ta, test.ta, test.designer, test.reader].each do |user|

      it "allows a course #{user.role} to search for whiteboards" do
        @whiteboards_driver_1.close_whiteboard
        @canvas_driver_1.masquerade_as(user, test.course)
        @whiteboards_driver_1.load_page test
        @whiteboards_driver_1.simple_search test.id
        @whiteboards_driver_1.wait_until(timeout) { @whiteboards_driver_1.list_view_whiteboard_elements.length == 3 }
        @whiteboards_driver_1.wait_until(timeout) do
          @whiteboards_driver_1.visible_whiteboard_titles.sort == [@whiteboard_1.title, @whiteboard_2.title, @whiteboard_3.title].sort
        end
      end

      it "allows a course #{user.role} to view any whiteboard and its membership with a delete button" do
        @whiteboards_driver_1.open_whiteboard @whiteboard_3
        @whiteboards_driver_1.verify_collaborators [@whiteboard_3.owner, @whiteboard_3.collaborators]
        expect(@whiteboards_driver_1.delete_button?).to be true
      end
    end

    [test.observer, student_1].each do |user|

      it "does not allow a course #{user.role} to search for whiteboards" do
        @whiteboards_driver_1.close_whiteboard
        @canvas_driver_1.masquerade_as(user, test.course)
        @whiteboards_driver_1.load_page test
        has_access = @whiteboards_driver_1.verify_block { @whiteboards_driver_1.simple_search_input_element.when_visible 2 }
        expect(has_access).to be false
      end

      it "does not allow a course #{user.role} to open foreign whiteboards" do
        @whiteboards_driver_1.hit_whiteboard_url @whiteboard_3
        has_access = @whiteboards_driver_1.verify_block { @whiteboards_driver_1.settings_button_element.when_visible 2 }
        expect(has_access).to be false
      end
    end

    context 'when the user is a Student with membership in some whiteboards but not all' do

      after(:all) { @whiteboards_driver_1.close_whiteboard }

      it 'the user can see its whiteboards' do
        @canvas_driver_1.masquerade_as(student_1, test.course)
        @whiteboards_driver_1.load_page test
        @whiteboards_driver_1.wait_until(timeout) do
          @whiteboards_driver_1.list_view_whiteboard_title_elements.any?
          @whiteboards_driver_1.list_view_whiteboard_title_elements[0].text == @whiteboard_2.title
          @whiteboards_driver_1.list_view_whiteboard_title_elements[1].text == @whiteboard_1.title
        end
      end

      it 'the user cannot see or reach other whiteboards' do
        @whiteboards_driver_1.wait_until(timeout) do
          @whiteboards_driver_1.list_view_whiteboard_title_elements.length == 2 ||
            @whiteboards_driver_1.list_view_whiteboard_title_elements[2].text != @whiteboard_3.title
        end
        @whiteboards_driver_1.hit_whiteboard_url @whiteboard_3
        has_access = @whiteboards_driver_1.verify_block { @whiteboards_driver_1.settings_button_element.when_visible 2 }
        expect(has_access).to be false
      end
    end
  end

  describe 'collaboration members pane' do

    before(:all) do
      @driver_2 = Utils.launch_browser
      @canvas_driver_2 = Page::CanvasPage.new @driver_2
      @cal_net_driver_2 = Page::CalNetPage.new @driver_2
      @whiteboards_driver_2 = SquiggyWhiteboardPage.new @driver_2
      @canvas_driver_2.log_in(@cal_net_driver_2, test.admin.username, Utils.super_admin_password)

      @canvas_driver_1.masquerade_as(student_1, test.course)
      @canvas_driver_2.masquerade_as(student_3, test.course)
      @whiteboards_driver_2.load_page test
    end

    after(:all) { @driver_2.quit }

    it "allows #{student_1.full_name} to see a list of all whiteboard members" do
      @whiteboards_driver_1.load_page test
      @whiteboards_driver_1.open_whiteboard @whiteboard_1
      @whiteboards_driver_1.show_collaborators
      @whiteboards_driver_1.wait_until(timeout) do
        @whiteboards_driver_1.collaborator(student_1).visible?
        @whiteboards_driver_1.collaborator(student_2).visible?
        @whiteboards_driver_1.collaborator(student_3).visible?
      end
    end

    it "allows #{student_1.full_name} to see which members are currently online" do
      expect(@whiteboards_driver_1.collaborator_online? student_1).to be true
    end

    it "allows #{student_1.full_name} to see which members are currently offline" do
      expect(@whiteboards_driver_1.collaborator_online? student_2).to be false
      expect(@whiteboards_driver_1.collaborator_online? student_3).to be false
    end

    it "allows #{student_1.full_name} to see which members have just come online" do
      @whiteboards_driver_2.open_whiteboard @whiteboard_1
      actual_online_time = Time.now
      @whiteboards_driver_1.wait_until(Utils.short_wait) { @whiteboards_driver_1.collaborator_online? student_3 }
      logger.warn "It took #{Time.now - actual_online_time} seconds for the user to appear online"
    end

    it "allows #{student_1.full_name} to see which members have just gone offline" do
      @whiteboards_driver_2.close_whiteboard
      actual_offline_time = Time.now
      @whiteboards_driver_1.wait_until(130) { !@whiteboards_driver_1.collaborator_online? student_3 }
      logger.warn "It took #{Time.now - actual_offline_time} seconds for the user to go offline"
    end

    it "does not allow #{student_1.full_name} to see if a non-member teacher has just come online" do
      @canvas_driver_2.masquerade_as(teacher, test.course)
      @whiteboards_driver_2.load_page test
      @whiteboards_driver_2.open_whiteboard @whiteboard_1
      teacher_visible = @whiteboards_driver_1.verify_block { @whiteboards_driver_1.collaborator(teacher).when_present timeout }
      expect(teacher_visible).to be false
    end

    it "allows #{student_1.full_name} to close the collaborators pane" do
      @whiteboards_driver_1.hide_collaborators
      @whiteboards_driver_1.collaborator(student_1).when_not_visible 1
    end

    it "allows #{student_1.full_name} to reopen the collaborators pane" do
      @whiteboards_driver_1.show_collaborators
      @whiteboards_driver_1.collaborator(student_1).when_visible 1
    end
  end

  describe 'membership' do

    before(:all) do
      @whiteboards_driver_1.close_whiteboard
      @whiteboards_driver_1.open_whiteboard @whiteboard_1
    end

    it "allows #{student_1.full_name} to add a member" do
      @whiteboards_driver_1.add_collaborator teacher
      @whiteboards_driver_1.close_whiteboard
      @whiteboards_driver_1.open_whiteboard @whiteboard_1
      @whiteboards_driver_1.show_collaborators
      @whiteboards_driver_1.collaborator(teacher).when_visible timeout
    end

    it "allows #{student_1.full_name} to delete a member" do
      @whiteboards_driver_1.remove_collaborator student_3
      @whiteboards_driver_1.close_whiteboard
      @whiteboards_driver_1.open_whiteboard @whiteboard_1
      @whiteboards_driver_1.show_collaborators
      @whiteboards_driver_1.collaborator(student_3).when_not_present timeout
    end

    it "allows #{student_1.full_name} to delete its own membership" do
      @whiteboards_driver_1.remove_collaborator student_1
      @whiteboards_driver_1.switch_to_first_window
      @whiteboards_driver_1.hit_whiteboard_url @whiteboard_1
      has_access = @whiteboards_driver_1.verify_block { @whiteboards_driver_1.settings_button_element.when_visible 2 }
      expect(has_access).to be false
    end
  end

  describe 'Canvas syncing' do

    before(:all) do
      @canvas_driver_1.stop_masquerading
      @canvas_driver_1.remove_users_from_course(test.course, [teacher, student_1])
      @engagement_index_driver_1.wait_for_removed_user_sync(test, [teacher, student_1])

      # Access to whiteboards is based on session cookie, so launch another browser to check cookie-less access
      @driver_3 = Utils.launch_browser
      @canvas_driver_3 = Page::CanvasPage.new @driver_3
      @cal_net_driver_3 = Page::CalNetPage.new @driver_3
      @whiteboards_driver_3 = SquiggyWhiteboardPage.new @driver_3
      @canvas_driver_3.log_in(@cal_net_driver_3, test.admin.username, Utils.super_admin_password)
      @whiteboards_driver_1.load_page test
    end

    after(:all) { @driver_3.quit }

    [teacher, student_1].each do |user|

      it "removes #{user.role} UID #{user.uid} from all whiteboards if the user has been removed from the course site" do
        [@whiteboard_1, @whiteboard_2, @whiteboard_3].each do |whiteboard|
          @whiteboards_driver_1.close_whiteboard
          @whiteboards_driver_1.open_whiteboard whiteboard
          @whiteboards_driver_1.click_settings_button
          # TODO wait for collaborators pane to be visible
          @whiteboards_driver_1.collaborator_name(user).when_not_present 1
        end
      end

      it "prevents #{user.role} UID #{user.uid} from reaching any whiteboards if the user has been removed from the course site" do
        @canvas_driver_3.masquerade_as(user, test.course)
        [@whiteboard_1, @whiteboard_2, @whiteboard_3].each do |whiteboard|
          @whiteboards_driver_3.hit_whiteboard_url whiteboard
          @whiteboards_driver_3.page_not_found_element.when_visible timeout
        end
      end
    end
  end
end
