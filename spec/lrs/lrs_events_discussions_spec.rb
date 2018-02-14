require_relative '../../util/spec_helper'

describe 'Canvas discussion events' do

  include Logging

  course_id = ENV['COURSE_ID']
  test_id = Utils.get_test_id
  event = Event.new({test_id: test_id})
  discussion = Discussion.new("Discussion Topic #{Utils.get_test_id}")

  before(:all) do
    @driver = Utils.launch_browser
    @canvas = Page::CanvasActivitiesPage.new @driver
    @cal_net = Page::CalNetPage.new @driver

    @test_user_data = LRSUtils.load_lrs_test_data.select { |data| data['tests']['discussions'] }
    @admin_user = User.new({username: Utils.ets_qa_username})
    @user_1 = User.new @test_user_data[0]
    @user_2 = User.new @test_user_data[1]

    @course = Course.new({title: "LRS Discussions Test #{test_id}", site_id: course_id})
    @canvas.log_in(@cal_net, Utils.ets_qa_username, Utils.ets_qa_password)
    @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, [@user_1, @user_2], test_id, [LtiTools::PRIVACY_DASHBOARD])
    @canvas.log_out(@driver, @cal_net)

    # User 1 logs in, creates topic, adds a reply, and logs out
    event.actor = @user_1
    @canvas.log_in(@cal_net, @user_1.username, Utils.test_user_password, event)
    @canvas.create_course_discussion(@driver, @course, discussion, event)
    @canvas.add_reply(discussion, nil, 'Discussion entry by the discussion topic creator', event)
    @canvas.log_out(@driver, @cal_net, event)

    # User 2 logs in, adds a reply, adds a nested reply, and logs out
    event.actor = @user_2
    @canvas.log_in(@cal_net, @user_2.username, Utils.test_user_password, event)
    @canvas.load_course_site(@driver, @course)
    @canvas.add_reply(discussion, nil, 'Discussion entry by somebody other than the discussion topic creator', event)
    @canvas.add_reply(discussion, 0, 'Discussion entry by somebody other than the discussion topic creator', event)
    @canvas.log_out(@driver, @cal_net, event)

    # Pause to make sure all the events have time to make it to the LRS
    @canvas.wait_for_event
  end

  after(:all) do
    Utils.quit_browser @driver
    LRSUtils.get_all_test_events event.csv
  end

  it('end up in the LRS database') { LRSUtils.verify_canvas_events event }

end
