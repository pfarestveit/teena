require_relative '../../util/spec_helper'

describe 'Canvas discussion events' do

  include Logging

  course_id = ENV['COURSE_ID']
  test_id = Utils.get_test_id
  event = Event.new({test_id: test_id})
  discussion = Discussion.new("Discussion Topic #{Utils.get_test_id}")

  before(:all) do
    @driver = Utils.launch_browser
    @canvas = Page::CanvasAnnounceDiscussPage.new @driver
    @cal_net = Page::CalNetPage.new @driver

    @test_user_data = LRSUtils.load_lrs_test_data.select { |data| data['tests']['discussions'] }
    @admin_user = User.new({username: Utils.ets_qa_username})
    @user_1 = User.new @test_user_data[0]
    @user_2 = User.new @test_user_data[1]

    @course = Course.new({title: "LRS Discussions Test #{test_id}", site_id: course_id})
    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, [@user_1, @user_2], test_id)

    # User 1 creates topic, adds a reply
    event.actor = @user_1
    @canvas.masquerade_as(@driver, @user_1, @course)
    @canvas.create_course_discussion(@driver, @course, discussion, event)
    @canvas.add_reply(discussion, nil, 'Discussion entry by the discussion topic creator', event)

    # User 2 adds a reply, adds a nested reply
    event.actor = @user_2
    @canvas.masquerade_as(@driver, @user_2, @course)
    @canvas.add_reply(discussion, nil, 'Discussion entry by somebody other than the discussion topic creator', event)
    @canvas.add_reply(discussion, 0, 'Discussion entry by somebody other than the discussion topic creator', event)

    # Pause to make sure all the events have time to make it to the LRS
    @canvas.wait_for_event
  end

  after(:all) do
    Utils.quit_browser @driver
    LRSUtils.get_all_test_events(event, event.csv)
  end

  it('end up in the LRS database') { LRSUtils.verify_canvas_events event }

end
