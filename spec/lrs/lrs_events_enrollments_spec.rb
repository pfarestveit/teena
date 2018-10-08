require_relative '../../util/spec_helper'

describe 'Canvas enrollment events' do

  include Logging

  course_id = ENV['COURSE_ID']
  test_id = Utils.get_test_id
  event = Event.new({test_id: test_id})

  before(:all) do

    @driver = Utils.launch_browser

    @canvas = Page::CanvasPage.new @driver
    @cal_net = Page::CalNetPage.new @driver
    @find_person_to_add = Page::JunctionPages::CanvasCourseAddUserPage.new @driver

    # Script requires a minimum of two teachers and four students in test data
    user_test_data = LRSUtils.load_lrs_test_data.select { |data| data['tests']['enrollments'] }
    users = user_test_data.map { |user_data| User.new(user_data) }
    users.each { |u| u.status = 'active' }
    admin = User.new({:uid => Utils.super_admin_uid, :username => Utils.super_admin_username})
    teachers = users.select { |user| user.role == 'Teacher' }
    students = users.select { |user| user.role == 'Student' }

    event.actor = admin
    @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    @course = Course.new({:title => "LRS Enrollments Test #{test_id}", :site_id => course_id})
    @section = Section.new({:course => @course, :sis_id => "SEC:#{@course.title.gsub(' ', '-')}"})
    @course.sections = [@section]
    @course.sis_id = "CRS:#{@course.title.gsub(' ', '-')}"

    @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, [], test_id, nil, event)
    @canvas.add_sis_section_and_ids(@course, @section)

    # Admin creates teacher enrollment via Canvas add-user
    @canvas.add_users(@course, [teachers[0]], @section, event)

    # Admin creates teacher enrollment and student enrollment via SIS import - no events are captured yet
    users_to_add = [teachers[1], students[0]]
    users_csv = Utils.create_sis_user_import(users)
    enrollments_csv = Utils.create_sis_enrollment_import(@course, @section, users_to_add)
    @canvas.upload_sis_imports([users_csv, enrollments_csv], users_to_add)

    # Admin creates student enrollment via Canvas add-user
    @canvas.add_users(@course, [students[1]], @section, event)

    # Teacher creates student enrollment via Find a Person to Add - no events are captured yet
    event.actor = teachers[0]
    @canvas.masquerade_as(@driver, teachers[0], @course)
    @canvas.load_users_page @course
    @canvas.click_find_person_to_add @driver
    @find_person_to_add.search(students[2].uid, 'CalNet UID')
    @find_person_to_add.add_user_by_uid(students[2], @section)

    # Teacher removes student via Canvas remove-user
    @canvas.remove_users_from_course(@course, [students[1]])

    # Admin removes teacher and student via SIS import - no events are captured yet
    event.actor = admin
    @canvas.stop_masquerading @driver
    users_to_remove = [teachers[0], students[0]]
    users_to_remove.each { |u| u.status = 'deleted' }
    enrollments_csv = Utils.create_sis_enrollment_import(@course, @section, users_to_remove)
    @canvas.upload_sis_imports([enrollments_csv], users_to_remove)

    @canvas.wait_for_event
  end

  after(:all) do
    Utils.quit_browser @driver
    LRSUtils.get_all_test_events(event, event.csv)
  end

  it('should end up in the LRS database') { LRSUtils.verify_canvas_events event }

end
