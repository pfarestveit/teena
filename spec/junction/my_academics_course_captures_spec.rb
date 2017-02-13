require_relative '../../util/spec_helper'

describe 'My Academics course captures card' do

  include Logging

  begin

    # The test data file should contain data variations such as cross-listings and courses with multiple primary sections
    test_users = Utils.load_test_users.select { |user| user['tests']['courseCapture'] }

    @driver = Utils.launch_browser
    @splash_page = Page::CalCentralPages::SplashPage.new @driver
    @my_academics = Page::CalCentralPages::MyAcademicsCourseCapturesCard.new @driver

    test_users.each do |user|

      begin

        # Get the Course Capture data expected to appear in CalCentral for each test user
        uid = user['uid']
        calcentral_content = user['tests']['courseCapture']['calCentral']
        class_page = calcentral_content['classPagePath']
        expected_sections = calcentral_content['sections']

        if calcentral_content

          @splash_page.load_page
          @splash_page.basic_auth uid
          @my_academics.load_page class_page
          @my_academics.course_capture_heading_element.when_visible timeout=Utils.medium_wait

          if expected_sections
            logger.debug "Expected section count is #{expected_sections.length}"

            # Verify that recordings load
            recordings_exist = @my_academics.verify_block { @my_academics.wait_until(Utils.medium_wait) { @my_academics.section_content_elements.any? } }
            it("shows UID #{uid} recordings on '#{class_page}'") { expect(recordings_exist).to be true }

            if recordings_exist

              expected_sections.each do |section|

                index = @my_academics.section_recordings_index section['code']

                # Verify that the section information and the number of recordings match expectations in the test data
                @my_academics.show_all_recordings index
                expected_section_code = section['code']
                expected_video_count = section['videoCount']
                expected_video_id = section['videoId']
                visible_video_count = @my_academics.you_tube_recording_elements(@driver, index).length
                visible_section_code = @my_academics.section_course_code index

                if expected_sections.length > 1
                  it("shows UID #{uid} all the available lecture videos for one of #{expected_sections.length} primary sections on '#{class_page}'") { expect(visible_video_count).to eql(expected_video_count) }
                  it("shows UID #{uid} the section code '#{expected_section_code}' on '#{class_page}'") { expect(visible_section_code).to eql(expected_section_code) }
                else
                  it("shows UID #{uid} all the available lecture videos for the one primary section on '#{class_page}'") { expect(visible_video_count).to eql(expected_video_count) }
                  it("shows UID #{uid} no section code on '#{class_page}'") { expect(visible_section_code).to be nil }
                end

                # Verify that the alert message, help page link, and the sample YouTube video ID are present
                has_you_tube_alert = @my_academics.you_tube_alert_elements[index]
                has_help_page_link = @my_academics.external_link_valid?(@driver, @my_academics.help_page_link(index), 'Service at UC Berkeley')
                has_you_tube_link = @my_academics.external_link_valid?(@driver, @my_academics.you_tube_link(expected_video_id), 'YouTube')

                it("shows UID #{uid} a 'help page' link on '#{class_page}'") { expect(has_help_page_link).to be true }
                it("shows UID #{uid} an explanation for viewing the recordings at You Tube on '#{class_page}'") { expect(has_you_tube_alert).to be_truthy }
                it("shows UID #{uid} a valid link to YouTube video ID #{expected_video_id} on '#{class_page}'") { expect(has_you_tube_link).to be true }

              end

              # Verify that the 'report a problem' link works
              has_report_problem_link = @my_academics.external_link_valid?(@driver, @my_academics.report_problem_element, 'Request Support or Give Feedback | Educational Technology Services')

              it("offers UID #{uid} a 'Report a Problem' link on '#{class_page}'") { expect(has_report_problem_link).to be true }

            end
          else

            # Verify that a user with no captures sees messaging instead
            has_no_course_capture_message = @my_academics.verify_block { @my_academics.no_course_capture_msg_element.when_visible Utils.medium_wait }
            it("shows UID #{uid} a 'no recordings' message on '#{class_page}'") { expect(has_no_course_capture_message).to be true }

          end
        end
      rescue => e
        it("encountered an error with UID #{uid}") { fail }
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
