require_relative '../../util/spec_helper'

describe 'Canvas assignment events' do

  include Logging

  course_id = ENV['COURSE_ID']
  test_id = Utils.get_test_id
  event = Event.new({test_id: test_id})

  before(:all) do
    @driver = Utils.launch_browser
    @canvas = Page::CanvasAssignmentsPage.new @driver
    @cal_net = Page::CalNetPage.new @driver

    @test_user_data = LRSUtils.load_lrs_test_data.select { |data| data['tests']['assignments'] }
    @teacher = User.new(@test_user_data.find { |u| u['role'] == 'Teacher' })
    @student = User.new(@test_user_data.find { |u| u['role'] == 'Student' })

    @course = Course.new({title: "LRS Assignments Test #{test_id}", site_id: course_id})
    @assignment = Assignment.new({title: "Assignment #{Utils.get_test_id}"})
    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, [@teacher, @student], test_id)
    # Teacher creates and then edits an assignment
    event.actor = @teacher
    @canvas.masquerade_as(@driver, @teacher, @course)
    @canvas.create_assignment(@course, @assignment, event)
    @canvas.edit_assignment_title(@assignment, event)

    # Student submits and then resubmits an assignment
    event.actor = @student
    @canvas.masquerade_as(@driver, @student, @course)
    initial_submission = Asset.new(@student.assets[0])
    @canvas.submit_assignment(@assignment, @student, initial_submission, event)
    # Pause to create enough distance between submission and resubmission
    sleep LRSUtils.event_time_discrep_seconds
    resubmission = Asset.new(@student.assets[1])
    @canvas.resubmit_assignment(@assignment, @student, resubmission, event)

    @canvas.wait_for_event
  end

  after(:all) do
    Utils.quit_browser @driver
    LRSUtils.get_all_test_events(event, event.csv)
  end

  it('end up in the LRS database') { LRSUtils.verify_canvas_events event }

end
