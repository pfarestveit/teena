require_relative '../../util/spec_helper'

describe 'My Dashboard', order: :defined do

  include Logging

  test_id = Utils.get_test_id
  timeout = Utils.medium_wait

  course_test_data = {code: "QA #{test_id} LEC001", title: "QA CalCentral Dashboard Test - #{test_id}"}
  user_test_data = Utils.load_test_users.select { |user| user['tests']['canvasIntegration'] }

  before(:all) { @driver = Utils.launch_browser }

  describe 'Canvas activities' do

    before(:all) do
      @splash_page = Page::CalCentralPages::SplashPage.new @driver
      @cal_net = Page::CalNetPage.new @driver
      @my_classes = Page::CalCentralPages::MyDashboardMyClassesCard.new @driver
      @notifications = Page::CalCentralPages::MyDashboardNotificationsCard.new @driver
      @tasks = Page::CalCentralPages::MyDashboardTasksCard.new @driver
      @canvas = Page::CanvasPage.new @driver
      @classes_api = ApiMyClassesPage.new @driver

      @course = Course.new course_test_data
      @teacher = User.new user_test_data.find { |user| user['role'] == 'Teacher' }
      @student = User.new user_test_data.find { |user| user['role'] == 'Student' }

      # Admin creates course site in the current term
      @my_dashboard = @splash_page.log_in_to_dashboard(@driver, @cal_net, Utils.ets_qa_username, Utils.ets_qa_password)
      @notifications.notifications_heading_element.when_visible timeout
      @course.term = @classes_api.current_term @driver
      @my_dashboard.log_out @splash_page
      @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
      @canvas.create_generic_course_site(@course, [@teacher, @student], test_id)
      @canvas.log_out(@driver, @cal_net)

      # Student accepts course invite so that the site will be included in the user's data
      @canvas.log_in(@cal_net, @student.username, Utils.test_user_password)
      @canvas.load_course_site @course
      @canvas.log_out(@driver, @cal_net)

      # Teacher creates a discussion, an announcement, and past/present/future assignments
      @canvas.log_in(@cal_net, @teacher.username, Utils.test_user_password)
      @canvas.load_course_site @course
      @today = Date.today

      @discussion =(Discussion.new "Discussion title in #{@course.code}", @today)
      @canvas.create_discussion(@course, @discussion)

      @announcement = Announcement.new("Announcement title in #{@course.code}", "This is the body of an announcement about #{@course.code}", @today)
      @canvas.create_announcement(@course, @announcement)

      @past_assignment = Assignment.new("Yesterday Assignment #{test_id}", @today - 1)
      @canvas.create_assignment(@course, @past_assignment)
      @today_assignment = Assignment.new("Today Assignment #{test_id}", @today)
      @canvas.create_assignment(@course, @today_assignment)
      @future_assignment = Assignment.new("Tomorrow Assignment #{test_id}", @today + 1)
      @canvas.create_assignment(@course, @future_assignment)

      # The ordering of the Canvas assignment sub-activities is unpredictable, so compare sorted arrays of the expected and actual assignment data displayed
      @assignment_summaries = ['Assignment Created', 'Assignment Created', 'Assignment Created']
      @assignment_descriptions = []
      @assignment_descriptions << "#{@future_assignment.title}, #{@course.title} - A new assignment has been created for your course, #{@course.title} #{@future_assignment.title} due: #{@notifications.date_format @future_assignment.due_date} at 11:59pm"
      @assignment_descriptions << "#{@today_assignment.title}, #{@course.title} - A new assignment has been created for your course, #{@course.title} #{@today_assignment.title} due: #{@notifications.date_format @today_assignment.due_date} at 11:59pm"
      @assignment_descriptions << "#{@past_assignment.title}, #{@course.title} - A new assignment has been created for your course, #{@course.title} #{@past_assignment.title} due: #{@notifications.date_format @past_assignment.due_date} at 11:59pm"

      @canvas.log_out(@driver, @cal_net)

      # Wait for Canvas to index new data
      sleep Utils.long_wait

      # Clear cache so that new data will load immediately
      Utils.clear_cache(@driver, @splash_page, @my_dashboard)
    end

    context 'when viewed by an instructor' do

      before(:all) do
        @splash_page.click_sign_in_button
        @cal_net.log_in(@teacher.username, Utils.test_user_password)
        @notifications.wait_for_notifications @course

        # The ordering of the Canvas notifications is unpredictable, so find out which is where on the activities list
        notifications = []
        @notifications.notification_summary_elements.each { |summary| notifications << summary.text }
        @discuss_index = notifications.index(notifications.find { |summary| summary.include? 'Discussion' })
        @announce_index = notifications.index(notifications.find { |summary| summary.include? 'Announcement' })
        @assign_index = notifications.index(notifications.find { |summary| summary.include? 'Assignment' })
      end

      # My Classes

      it 'show the course site name in My Classes' do
        @my_classes.other_sites_div_element.when_visible Utils.medium_wait
        expect(@my_classes.other_course_site_names).to include(@course.code)
      end
      it('show the course site description in My Classes') do
        expect(@my_classes.other_course_site_descrips).to include(@course.title)
      end

      # Notifications - announcement, discussion

      it('show a combined notification for similar notifications on the same course site on the same date') do
        @notifications.wait_until(timeout) { @notifications.notification_summary_elements[@assign_index].text == '3 Assignments' }
      end
      it('show an assignment\'s course site name on a notification') do
        expect(@notifications.notification_source_elements[@assign_index].text).to eql("#{@course.code}")
      end
      it('show an assignment\'s course site creation date on a notification') do
        expect(@notifications.notification_date_elements[@assign_index].text).to eql("#{@notifications.date_format @today}")
      end
      it 'show individual notifications if a combined one is expanded' do
        expect(@notifications.sub_notification_summaries(@assign_index)).to eql(@assignment_summaries)
      end
      it 'show overdue, current, and future assignment notification detail' do
        expect(@notifications.sub_notification_descrips(@assign_index).sort).to eql(@assignment_descriptions.sort)
      end
      it 'show an announcement title on a notification' do
        expect(@notifications.notification_summary_elements[@announce_index].text).to eql(@announcement.title)
      end
      it 'show an announcement source on a notification' do
        @notifications.expand_notification_detail @announce_index
        expect(@notifications.notification_source_elements[@announce_index].text).to eql(@course.code)
      end
      it 'show an announcement date on a notification' do
        expect(@notifications.notification_date_elements[@announce_index].text).to eql(@notifications.date_format @announcement.date)
      end
      it 'show announcement detail on a notification' do
        expect(@notifications.notification_desc_elements[@announce_index].text).to eql(@announcement.body)
      end
      it 'show a link to an announcement on a notification' do
        expect(@notifications.notification_more_info_link(@announce_index).attribute('href')).to eql(@announcement.url)
      end
      it 'show a discussion title on a notification' do
        expect(@notifications.notification_summary_elements[@discuss_index].text).to eql(@discussion.title)
      end
      it 'show a discussion source on a notification' do
        @notifications.expand_notification_detail @discuss_index
        expect(@notifications.notification_source_elements[@discuss_index].text).to eql(@course.code)
      end
      it 'show a discussion date on a notification' do
        expect(@notifications.notification_date_elements[@discuss_index].text).to eql(@notifications.date_format @discussion.date)
      end
      it 'show a link to a discussion on a notification' do
        expect(@notifications.notification_more_info_link(@discuss_index).attribute('href')).to eql(@discussion.url)
      end

      # Tasks - assignments
      it 'show no assignment tasks' do
        @tasks.scheduled_tasks_tab_element.when_present timeout
        expect(@tasks.overdue_task_count).to eql('')
        expect(@tasks.today_task_count).to eql('')
        expect(@tasks.future_task_count).to eql('')
      end

      after(:all) { @my_dashboard.log_out @splash_page if @notifications.notifications_heading? }

    end

    context 'viewed by a student' do

      before(:all) do
        @splash_page.load_page
        @splash_page.click_sign_in_button
        @cal_net.log_in(@student.username, Utils.test_user_password)
        @notifications.wait_for_notifications @course

        # The ordering of the Canvas notifications is unpredictable, so find out which is where on the activities list
        notifications = []
        @notifications.notification_summary_elements.each { |summary| notifications << summary.text }
        @discuss_index = notifications.index(notifications.find { |summary| summary.include? 'Discussion' })
        @announce_index = notifications.index(notifications.find { |summary| summary.include? 'Announcement' })
        @assign_index = notifications.index(notifications.find { |summary| summary.include? 'Assignments' })
      end

      # My Classes
      it 'show the course name in My Classes' do
        @my_classes.other_sites_div_element.when_visible timeout
        expect(@my_classes.other_course_site_names).to include(@course.code)
      end
      it 'show the course description in My Classes' do
        expect(@my_classes.other_course_site_descrips).to include(@course.title)
      end

      # Notifications - assignments, announcement, discussion
      it 'show a combined notification for similar notifications on the same course site on the same date' do
        @notifications.wait_until(timeout) { @notifications.notification_summary_elements[@assign_index].text == '3 Assignments' }
      end
      it 'show an assignment\'s course site name and creation date on a notification' do
        expect(@notifications.notification_source_elements[@assign_index].text).to eql("#{@course.code}")
        expect(@notifications.notification_date_elements[@assign_index].text).to eql("#{@notifications.date_format @today}")
      end
      it 'show individual notifications if a combined one is expanded' do
        expect(@notifications.sub_notification_summaries(@assign_index)).to eql(@assignment_summaries)
      end
      it 'show overdue, current, and future assignment notifications detail' do
        expect(@notifications.sub_notification_descrips(@assign_index).sort).to eql(@assignment_descriptions.sort)
      end
      it 'show an announcement title on a notification' do
        expect(@notifications.notification_summary_elements[@announce_index].text).to eql(@announcement.title)
      end
      it 'show an announcement source on a notification' do
        @notifications.expand_notification_detail @announce_index
        expect(@notifications.notification_source_elements[@announce_index].text).to eql(@course.code)
      end
      it 'show an announcement date on a notification' do
        expect(@notifications.notification_date_elements[@announce_index].text).to eql(@notifications.date_format @announcement.date)
      end
      it 'show an announcement detail on a notification' do
        expect(@notifications.notification_desc_elements[@announce_index].text).to eql(@announcement.body)
      end
      it 'show a link to an announcement on a notification' do
        expect(@notifications.notification_more_info_link(@announce_index).attribute('href')).to eql(@announcement.url)
      end
      it 'show a discussion title on a notification' do
        expect(@notifications.notification_summary_elements[@discuss_index].text).to eql(@discussion.title)
      end
      it 'show a discussion source on a notification' do
        @notifications.expand_notification_detail @discuss_index
        expect(@notifications.notification_source_elements[@discuss_index].text).to eql(@course.code)
      end
      it 'show a discussion date on a notification' do
        expect(@notifications.notification_date_elements[@discuss_index].text).to eql(@notifications.date_format @discussion.date)
      end
      it 'show a link to a discussion on a notification' do
        expect(@notifications.notification_more_info_link(@discuss_index).attribute('href')).to eql(@discussion.url)
      end

      # Tasks - assignments
      it 'show an overdue assignment as an overdue task' do
        @tasks.wait_for_overdue_tasks
        expect(@tasks.overdue_task_title_elements.last.text).to eql(@past_assignment.title)
      end
      it 'show an overdue assignment\'s course site name on a task' do
        expect(@tasks.overdue_task_course_elements.last.text).to eql(@course.code.upcase)
      end
      it 'show an overdue assignment\'s due date and time on a task' do
        expect(@tasks.overdue_task_date_elements.last.text).to eql(@tasks.date_format @past_assignment.due_date)
        expect(@tasks.overdue_task_time_elements.last.text).to eql('11 PM')
      end
      it 'show a link to an overdue Canvas assignment on a task' do
        @tasks.show_overdue_task_detail @tasks.overdue_task_elements.rindex(@tasks.overdue_task_elements.last)
        @tasks.overdue_task_bcourses_link_elements.last.when_visible timeout
        expect(@tasks.overdue_task_bcourses_link_elements.last.attribute('href')).to eql(@past_assignment.url)
      end
      it 'show a currently due assignment as a Today task' do
        expect(@tasks.today_task_title_elements.last.text).to eql(@today_assignment.title)
      end
      it 'show a currently due assignment\'s course site name on a task' do
        expect(@tasks.today_task_course_elements.last.text).to eql(@course.code.upcase)
      end
      it 'show a currently due assignment\'s due date and date on a task' do
        expect(@tasks.today_task_date_elements.last.text).to eql(@tasks.date_format @today_assignment.due_date)
        expect(@tasks.today_task_time_elements.last.text).to eql('11 PM')
      end
      it 'show a link to a currently due Canvas assignment on a task' do
        @tasks.show_today_task_detail @tasks.today_task_elements.rindex(@tasks.today_task_elements.last)
        @tasks.today_task_bcourses_link_elements.last.when_visible timeout
        expect(@tasks.today_task_bcourses_link_elements.last.attribute('href')).to eql(@today_assignment.url)
      end
      it 'show a future assignment as a future task' do
        expect(@tasks.future_task_title_elements.last.text).to eql(@future_assignment.title)
      end
      it 'show a future assignment\'s course site name on a task' do
        expect(@tasks.future_task_course_elements.last.text).to eql(@course.code.upcase)
      end
      it 'show a future assignment\'s due date and time on a task' do
        expect(@tasks.future_task_date_elements.last.text).to eql(@tasks.date_format @future_assignment.due_date)
        expect(@tasks.future_task_time_elements.last.text).to eql('11 PM')
      end
      it 'show a link to a future due Canvas assignment on a task' do
        @tasks.show_future_task_detail @tasks.future_task_elements.rindex(@tasks.future_task_elements.last)
        @tasks.future_task_bcourses_link_elements.last.when_visible timeout
        expect(@tasks.future_task_bcourses_link_elements.last.attribute('href')).to eql(@future_assignment.url)
      end
    end

    after(:all) do
      @my_dashboard.log_out @splash_page if @notifications.notifications_heading?
      @canvas.log_in(@cal_net, Utils.ets_qa_username, Utils.ets_qa_password)
      @canvas.delete_course(@driver, @course)
    end

  end

  after(:all) { Utils.quit_browser @driver }

end
