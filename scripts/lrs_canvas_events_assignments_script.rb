require_relative '../util/spec_helper'

include Logging

begin

  course_id = ENV['COURSE_ID']

  @driver = Utils.launch_browser

  @canvas = Page::CanvasActivitiesPage.new @driver
  @cal_net= Page::CalNetPage.new @driver

  user_test_data = Utils.load_suitec_test_data.select { |data| data['tests']['canvas_assignment_submissions'] }
  users = user_test_data.map { |user_data| User.new(user_data) }
  @students = users.select { |user| user.role == 'Student' }
  @teacher = users.find { |user| user.role == 'Teacher' }

  @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)

  # COURSES

  course_id.nil? ? (logger.info "Will create #{Utils.script_loops} courses") : (logger.info "Will use course ID #{course_id}")
  Utils.script_loops.times do
    begin

      @test_course_identifier = Utils.get_test_id
      @course = Course.new({title: "LRS Assignments Test #{@test_course_identifier}", site_id: course_id})
      @canvas.create_generic_course_site(@driver, Utils.canvas_qa_sub_account, @course, users, @test_course_identifier)

      # ASSIGNMENTS

      logger.info "Will create #{Utils.script_loops} assignments"
      Utils.script_loops.times do
        begin

          # Create assignment
          @test_assignment_identifier = Utils.get_test_id
          @assignment = Assignment.new("Submission Assignment #{@test_assignment_identifier}", nil)
          @canvas.masquerade_as(@driver, @teacher, @course)
          @canvas.create_assignment(@course, @assignment)
          @canvas.stop_masquerading @driver

          @students.each do |student|
            begin

              # Submit assignment
              @canvas.masquerade_as(@driver, student, @course)
              @submission = Asset.new student.assets.first
              @canvas.submit_assignment(@assignment, student, @submission)
              @canvas.stop_masquerading @driver

            rescue => e
              # Catch errors related to the student
              logger.error "#{e.message + "\n"} #{e.backtrace.join("\n ")}"
            end
          end
        end
      end
    rescue => e
      # Catch errors related to the assignment
      logger.error "#{e.message + "\n"} #{e.backtrace.join("\n ")}"
    end
  end
rescue => e
  # Catch errors related to the course
  logger.error "#{e.message + "\n"} #{e.backtrace.join("\n ")}"
ensure
  @driver.quit
end
