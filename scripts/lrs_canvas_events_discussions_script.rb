require_relative '../util/spec_helper'

include Logging

begin

  course_id = ENV['COURSE_ID']

  @driver = Utils.launch_browser

  @canvas = Page::CanvasActivitiesPage.new @driver
  @cal_net = Page::CalNetPage.new @driver

  @test_user_data = SuiteCUtils.load_suitec_test_data.select { |data| data['tests']['canvas_discussions'] }
  @admin_user = User.new(username: Utils.ets_qa_username)
  @user_1 = User.new @test_user_data[0]
  @user_2 = User.new @test_user_data[1]

  # COURSES

  course_id.nil? ? (logger.info "Will create #{LRSUtils.script_loops} courses") : (logger.info "Will use course ID #{course_id}")
  LRSUtils.script_loops.times do
    begin

      @test_course_identifier = Utils.get_test_id
      @course = Course.new({title: "LRS Discussions Test #{@test_course_identifier}", site_id: course_id})

      @canvas.load_homepage
      sleep Utils.short_wait
      @canvas.log_out(@driver, @cal_net) if @canvas.profile_link?
      @canvas.log_in(@cal_net, Utils.ets_qa_username, Utils.ets_qa_password)
      @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, [@user_1, @user_2], @test_course_identifier, [LtiTools::PRIVACY_DASHBOARD])

      # DISCUSSIONS

      logger.info "Will create #{LRSUtils.script_loops} discussions"
      LRSUtils.script_loops.times do
        begin

          @test_discuss_identifier = Utils.get_test_id

          # User 1 creates a discussion topic
          @discussion = Discussion.new("Discussion Topic #{@test_discuss_identifier}")
          @canvas.log_out(@driver, @cal_net)
          @canvas.log_in(@cal_net, @user_1.username, Utils.test_user_password)
          @canvas.create_course_discussion(@driver, @course, @discussion)

          # User 1 creates an entry on the topic
          @canvas.add_reply(@discussion, nil, 'Discussion entry by the discussion topic creator')

          # User 2 creates an entry on the topic
          @canvas.log_out(@driver, @cal_net)
          @canvas.log_in(@cal_net, @user_2.username, Utils.test_user_password)
          @canvas.load_course_site(@driver, @course)
          @canvas.add_reply(@discussion, nil, 'Discussion entry by somebody other than the discussion topic creator')

          # User 2 replies to the topic again
          @canvas.add_reply(@discussion, nil, 'Discussion entry by somebody other than the discussion topic creator')

          # User 1 replies to User 2's first entry
          @canvas.log_out(@driver, @cal_net)
          @canvas.log_in(@cal_net, @user_1.username, Utils.test_user_password)
          @canvas.add_reply(@discussion, 1, 'Reply by the discussion topic creator but not the discussion entry creator')

          # User 2 replies to User 1's entry
          @canvas.log_out(@driver, @cal_net)
          @canvas.log_in(@cal_net, @user_2.username, Utils.test_user_password)
          @canvas.add_reply(@discussion, 0, 'Reply by somebody other than the discussion topic creator and other than the discussion entry creator')

          # User 1 replies to own entry
          @canvas.log_out(@driver, @cal_net)
          @canvas.log_in(@cal_net, @user_1.username, Utils.test_user_password)
          @canvas.add_reply(@discussion, 0, 'Reply by the discussion topic creator and also the discussion entry creator')

          # User 2 replies to own first entry
          @canvas.log_out(@driver, @cal_net)
          @canvas.log_in(@cal_net, @user_2.username, Utils.test_user_password)
          @canvas.add_reply(@discussion, 3, 'Reply by somebody other than the discussion topic creator but who is the discussion entry creator')

          # User 2 replies again to User 1's reply
          @canvas.log_out(@driver, @cal_net)
          @canvas.log_in(@cal_net, @user_2.username, Utils.test_user_password)
          @canvas.add_reply(@discussion, 0, 'Reply by somebody other than the discussion topic creator and other than the discussion entry creator')

          # User 1 replies to User 2's first reply to User 1's entry
          @canvas.log_out(@driver, @cal_net)
          @canvas.log_in(@cal_net, @user_1.username, Utils.test_user_password)
          @canvas.add_reply(@discussion, 1, 'Reply-to-reply by somebody who created the topic and the entry but not the reply')

          # User 2 replies to its own first reply to User 1's entry
          @canvas.log_out(@driver, @cal_net)
          @canvas.log_in(@cal_net, @user_2.username, Utils.test_user_password)
          @canvas.add_reply(@discussion, 1, 'Reply-to-reply by somebody who created the reply but not the topic or the entry')

        rescue => e
          # Catch errors related to the discussion
          logger.error "#{e.message + "\n"} #{e.backtrace.join("\n ")}"
        end
      end
    rescue => e
      # Catch errors related to the course
      logger.error "#{e.message + "\n"} #{e.backtrace.join("\n ")}"
    end
  end
end
