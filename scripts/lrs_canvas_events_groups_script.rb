require_relative '../util/spec_helper'

include Logging

begin

  course_id = ENV['COURSE_ID']
  loops = LRSUtils.script_loops
  @driver = Utils.launch_browser

  @canvas = Page::CanvasGroupsPage.new @driver
  @canvas_discussions_page = Page::CanvasAnnounceDiscussPage.new @driver
  @cal_net = Page::CalNetPage.new @driver

  # Script requires a minimum of one teacher and three students in test data
  user_test_data = SuiteCUtils.load_suitec_test_data.select { |data| data['tests']['canvas_groups'] }
  users = user_test_data.map { |user_data| User.new(user_data) }
  students = users.select { |user| user.role == 'Student' }
  @teacher = users.find { |user| user.role == 'Teacher' }

  @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)

  # COURSES

  course_id.nil? ? (logger.info "Will create #{LRSUtils.script_loops} courses") : (logger.info "Will use course ID #{course_id}")
  loops.times do
    begin

      @test_course_identifier = Utils.get_test_id
      @course = Course.new({title: "LRS Groups Test #{@test_course_identifier}", site_id: course_id})
      @canvas.stop_masquerading(@driver) if @canvas.stop_masquerading_link?
      @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, users, @test_course_identifier)

      # TEACHER-CREATED GROUPS

      logger.info "Will create #{loops} sets of teacher-created groups"
      loops.times do
        begin

          @test_group_identifier = Utils.get_test_id
          @teacher_group = Group.new({title: "Teacher Group #{@test_group_identifier}", members: students, group_set: "Teacher Group Set #{@test_group_identifier}"})
          @canvas.masquerade_as(@driver, @teacher, @course)
          @canvas.instructor_create_grp(@course, @teacher_group)

          students.each do |student|
            @canvas.masquerade_as(@driver, student, @course)
            @canvas.student_join_grp(@course, @teacher_group)
          end

          # GROUP ACTIVITIES

          logger.info "Will create #{loops} sets of activities"
          loops.times do
            begin

              @test_activity_identifier = Utils.get_test_id
              @canvas.masquerade_as(@driver, @teacher, @course)

              # Announcement

              @announcement = Announcement.new("Teacher Group Announcement #{@test_activity_identifier}", 'This is a teacher-created group announcement')
              @canvas_discussions_page.create_group_announcement(@teacher_group, @announcement)

              # Discussion

              @discussion = Discussion.new("Teacher Group Discussion #{@test_activity_identifier}")
              @canvas_discussions_page.create_group_discussion(@teacher_group, @discussion)
              # Student 1 creates an entry on the topic
              @canvas_discussions_page.masquerade_as(@driver, students[0])
              @canvas_discussions_page.add_reply(@discussion, nil, 'Discussion entry by student 1')
              # Student 2 creates two entries on the topic
              @canvas_discussions_page.masquerade_as(@driver, students[1])
              @canvas_discussions_page.add_reply(@discussion, nil, 'Discussion entry by student 2')
              @canvas_discussions_page.add_reply(@discussion, nil, 'Discussion entry by student 2')
              # Student 1 replies to User 2's first entry
              @canvas_discussions_page.masquerade_as(@driver, students[0], @course)
              @canvas_discussions_page.add_reply(@discussion, 1, 'Reply by student 1')
              # Student 2 replies to User 1's entry
              @canvas_discussions_page.masquerade_as(@driver, students[1], @course)
              @canvas_discussions_page.add_reply(@discussion, 0, 'Reply by student 2')
              # Student 1 replies to own entry
              @canvas_discussions_page.masquerade_as(@driver, students[0], @course)
              @canvas_discussions_page.add_reply(@discussion, 0, 'Reply by student 1')
              # Student 2 replies to own first entry and to Student 1's reply
              @canvas_discussions_page.masquerade_as(@driver, students[1], @course)
              @canvas_discussions_page.add_reply(@discussion, 3, 'Reply by student 2')
              @canvas_discussions_page.add_reply(@discussion, 0, 'Reply by student 2')

              # Delete announcement and discussion

              @canvas_discussions_page.masquerade_as(@driver, @teacher, @course)
              @canvas_discussions_page.delete_activity(@announcement.title, @announcement.url)
              @canvas_discussions_page.delete_activity(@discussion.title, @discussion.url)

            rescue => e
              # Catch errors related to the activities
              Utils.log_error e
            end
          end

          # Student leaves group

          @canvas.masquerade_as(@driver, students[0], @course)
          @canvas.student_leave_grp(@course, @teacher_group)

          # Delete group

          @canvas.masquerade_as(@driver, @teacher, @course)
          @canvas.instructor_delete_grp_set(@course, @teacher_group)

        rescue => e
          # Catch errors related to the group
          Utils.log_error e
        end
      end

      # STUDENT-CREATED GROUPS

      logger.info "Will create #{loops} sets of student-created groups"
      loops.times do
        begin

          @test_group_identifier = Utils.get_test_id
          # The student creating the group does not need to add itself as a member
          @members = students.reject { |s| s == students[0] }
          @student_group = Group.new({title: "Student Group #{@test_group_identifier}", members: @members, group_set: 'Student Groups'})
          @canvas.masquerade_as(@driver, students[0], @course)
          @canvas.student_create_grp(@course, @student_group)

          # Edit group title

          @canvas.student_edit_grp_name(@course, @student_group, "#{@student_group.title} - Edited")

          # GROUP ACTIVITIES

          logger.info "Will create #{loops} sets of activities"
          loops.times do
            begin

              @test_activity_identifier = Utils.get_test_id

              # Announcement
              @announcement = Announcement.new("Student Group Announcement #{@test_activity_identifier}", 'This is a student-created group announcement')
              @canvas_discussions_page.create_group_announcement(@student_group, @announcement)

              # Discussion

              @discussion = Discussion.new("Student Group Discussion #{@test_activity_identifier}")
              @canvas_discussions_page.create_group_discussion(@student_group, @discussion)

              # Student 2 creates an entry on the topic
              @canvas_discussions_page.masquerade_as(@driver, students[1])
              @canvas_discussions_page.add_reply(@discussion, nil, 'Discussion entry by student 2')
              # Student 3 creates two entries on the topic
              @canvas_discussions_page.masquerade_as(@driver, students[2])
              @canvas_discussions_page.add_reply(@discussion, nil, 'Discussion entry by student 3')
              @canvas_discussions_page.add_reply(@discussion, nil, 'Discussion entry by student 3')
              # Student 2 replies to User 2's first entry
              @canvas_discussions_page.masquerade_as(@driver, students[1], @course)
              @canvas_discussions_page.add_reply(@discussion, 1, 'Reply by student 2')
              # Student 3 replies to User 1's entry
              @canvas_discussions_page.masquerade_as(@driver, students[2], @course)
              @canvas_discussions_page.add_reply(@discussion, 0, 'Reply by student 3')
              # Student 2 replies to own entry
              @canvas_discussions_page.masquerade_as(@driver, students[1], @course)
              @canvas_discussions_page.add_reply(@discussion, 0, 'Reply by student 2')
              # Student 3 replies to own first entry and to Student 2's reply
              @canvas_discussions_page.masquerade_as(@driver, students[2], @course)
              @canvas_discussions_page.add_reply(@discussion, 3, 'Reply by student 3')
              @canvas_discussions_page.add_reply(@discussion, 0, 'Reply by student 3')

              # Delete announcement and discussion

              @canvas_discussions_page.masquerade_as(@driver, students[0], @course)
              @canvas_discussions_page.delete_activity(@announcement.title, @announcement.url)
              @canvas_discussions_page.delete_activity(@discussion.title, @discussion.url)

            rescue => e
              # Catch errors related to the activities
              Utils.log_error e
            end
          end

          # Student leaves group

          @canvas.student_leave_grp(@course, @student_group)

        rescue => e
          # Catch errors related to the group
          Utils.log_error e
        end
      end
    rescue => e
      # Catch errors related to the course
      Utils.log_error e
    end
  end
rescue => e
  # Catch errors related to the script
  Utils.log_error e
ensure
  Utils.quit_browser @driver
end
