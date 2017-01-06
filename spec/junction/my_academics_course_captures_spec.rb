require_relative '../../util/spec_helper'

describe 'My Academics course captures card' do

  include Logging

  begin

    @driver = Utils.launch_browser

    @splash_page = Page::CalCentralPages::SplashPage.new @driver
    @my_academics = Page::CalCentralPages::MyAcademicsCourseCapturesCard.new @driver

    test_users = Utils.load_test_users.select { |user| user['tests']['courseCapture'] }

    test_users.each do |user|
      uid = user['uid']
      logger.info "UID is #{uid}"

      capture = user['tests']['courseCapture']
      video_you_tube_id = capture['video']

      begin
        @splash_page.load_page
        @splash_page.basic_auth uid
        @my_academics.load_page capture['classPagePath']
        @my_academics.course_capture_heading_element.when_visible timeout=Utils.medium_wait

        has_video_tab = @my_academics.verify_block { @my_academics.video_table_element.when_visible timeout }
        has_audio_tab = @my_academics.audio_tab?
        has_no_course_capture_message = @my_academics.no_course_capture_msg?

        if video_you_tube_id

          it("shows no 'no recordings' message for UID #{uid}") { expect(has_no_course_capture_message).to be false }
          it("shows the video tab for UID #{uid}") { expect(has_video_tab).to be true }
          it("shows no audio tab for UID #{uid}") { expect(has_audio_tab).to be false }

          @my_academics.show_all_recordings
          all_visible_video_lectures = @my_academics.you_tube_recording_elements.length
          it("shows all the available lecture videos for UID #{uid}") { expect(all_visible_video_lectures).to eql(capture['lectures']) }

          you_tube_link = @my_academics.you_tube_link video_you_tube_id
          it("shows links to the recordings at YouTube for UID #{uid}") { expect(you_tube_link.exists?).to be true }

          has_you_tube_alert = @my_academics.you_tube_alert?
          it("shows an explanation for viewing the recordings at You Tube for UID #{uid}") { expect(has_you_tube_alert).to be true }

          has_help_page_link = @my_academics.verify_external_link(@driver, @my_academics.help_page_link_element, 'Service at UC Berkeley')
          it("shows a 'help page' link for UID #{uid}") { expect(has_help_page_link).to be true }

          has_report_problem_link = @my_academics.verify_external_link(@driver, @my_academics.report_problem_link_element, 'Request Support or Give Feedback | Educational Technology Services')
          it("offers a 'Report a Problem' link for UID #{uid}") { expect(has_report_problem_link).to be true }

        else

          it("shows a 'no recordings' message for UID #{uid}") { expect(has_no_course_capture_message).to be true }
          it("shows no video tab for UID #{uid}") { expect(has_video_tab).to be false }
          it("shows no audio tab for UID #{uid}") { expect(has_audio_tab).to be false }

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
