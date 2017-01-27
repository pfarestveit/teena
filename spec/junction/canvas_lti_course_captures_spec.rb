require_relative '../../util/spec_helper'

describe 'bCourses Course Captures tool' do

  include Logging

  masquerade = ENV['masquerade']

  begin

    # The test data file should contain data variations such as cross-listings and courses with multiple primary sections
    test_user_data = Utils.load_test_users.select { |user| user['tests']['courseCapture'] }

    @driver = Utils.launch_browser
    @course_captures_page = Page::CalCentralPages::CanvasCourseCapturesPage.new @driver

    if masquerade
      @cal_net = Page::CalNetPage.new @driver
      @canvas = Page::CanvasPage.new @driver
      @canvas.log_in(@cal_net, Utils.super_admin_username, Utils.super_admin_password)
    else
      @splash_page = Page::CalCentralPages::SplashPage.new @driver
    end

    test_user_data.each do |data|

      begin

        # Get the Course Capture data expected to appear in Canvas sites for each test user
        user = User.new data
        canvas_content = data['tests']['courseCapture']['canvas']

        if canvas_content

          # Verify each Canvas site ID in the test data
          canvas_content.each do |course_site|
            course = Course.new({site_id: "#{course_site['siteId']}"})

            if masquerade
              @canvas.masquerade_as(user, course)
              @course_captures_page.load_embedded_tool(@driver, course)
            else
              @splash_page.load_page
              @splash_page.basic_auth user.uid
              @course_captures_page.load_standalone_tool course
            end

            expected_sections = course_site['sections']

            if expected_sections
              logger.debug "Expected section count is #{expected_sections.length}"

              # Verify that recordings load
              recordings_exist = @course_captures_page.verify_block { @course_captures_page.wait_until(Utils.medium_wait) { @course_captures_page.section_content_elements.any? } }
              it("shows UID #{user.uid} recordings on site ID '#{course.site_id}'") { expect(recordings_exist).to be true }

              if recordings_exist

                expected_sections.each do |section|

                  index = @course_captures_page.section_recordings_index section['code']

                  # Verify that the number of recordings and the section information matches expectations
                  @course_captures_page.show_all_recordings index
                  expected_section_code = section['code']
                  expected_video_count = section['videoCount']
                  expected_video_id = section['videoId']
                  visible_video_count = @course_captures_page.you_tube_recording_elements(@driver, index).length
                  visible_section_code = @course_captures_page.section_course_code index

                  if expected_sections.length > 1
                    it("shows UID #{user.uid} all the available lecture videos for one of #{expected_sections.length} primary sections on site ID #{course.site_id}") { expect(visible_video_count).to eql(expected_video_count) }
                    it("shows UID #{user.uid} the section code '#{expected_section_code}' on site ID #{course.site_id}") { expect(visible_section_code).to eql(expected_section_code) }
                  else
                    it("shows UID #{user.uid} all the available lecture videos for the one primary section on site ID #{course.site_id}") { expect(visible_video_count).to eql(expected_video_count) }
                    it("shows UID #{user.uid} no section code on site ID #{course.site_id}") { expect(visible_section_code).to be nil }
                  end

                  # Verify that the alert message, help page link, and the sample YouTube video ID are present
                  has_you_tube_alert = @course_captures_page.you_tube_alert_elements[index]
                  has_help_page_link = @course_captures_page.verify_external_link(@driver, @course_captures_page.help_page_link(index), 'Service at UC Berkeley')
                  @course_captures_page.switch_to_canvas_iframe @driver if ENV['masquerade']
                  has_you_tube_link = @course_captures_page.verify_external_link(@driver, @course_captures_page.you_tube_link(expected_video_id), 'YouTube')
                  @course_captures_page.switch_to_canvas_iframe @driver if ENV['masquerade']

                  it("shows UID #{user.uid} an explanation for viewing the recordings at You Tube on site ID #{course.site_id}") { expect(has_you_tube_alert).to be_truthy }
                  it("shows UID #{user.uid} a 'help page' link on site ID #{course.site_id}") { expect(has_help_page_link).to be true }
                  it("shows UID #{user.uid} a valid link to YouTube video ID #{expected_video_id} on site ID #{course.site_id}") { expect(has_you_tube_link).to be true }

                end

                # Verify that the 'report a problem' link works
                has_report_problem_link = @course_captures_page.verify_external_link(@driver, @course_captures_page.report_problem_element, 'Request Support or Give Feedback | Educational Technology Services')
                @course_captures_page.switch_to_canvas_iframe @driver if ENV['masquerade']

                it("offers UID #{user.uid} a 'Report a Problem' link on on site ID #{course.site_id}") { expect(has_report_problem_link).to be true }

              end
            end
          end
        end

      rescue => e
        it("encountered an error with UID #{user.uid}") { fail }
        logger.error "#{e.message}#{"\n"}#{e.backtrace.join("\n")}"
      end
    end

  rescue => e
    it('encountered an error') { fail }
    logger.error "#{e.message}#{"\n"}#{e.backtrace.join("\n")}"
  ensure
    Utils.quit_browser @driver
  end
end
