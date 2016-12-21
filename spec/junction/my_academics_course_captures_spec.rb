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
      course = capture['course']
      class_page = capture['classPagePath']
      lecture_count = capture['lectures']
      video_you_tube_id = capture['video']
      video_itunes = capture['itunesVideo']
      audio_url = capture['audio']
      audio_download = capture['audioDownload']
      audio_itunes = capture['itunesAudio']

      begin
        @splash_page.load_page
        @splash_page.basic_auth uid
        @my_academics.load_page class_page
        @my_academics.course_capture_heading_element.when_visible timeout=Utils.medium_wait

        # Audio but no video
        if video_you_tube_id.nil? && !audio_url.nil?

          has_right_default_tab = @my_academics.verify_block { @my_academics.audio_element.when_visible timeout }
          has_video_tab = @my_academics.video_tab?

          it("shows the audio tab by default for UID #{uid}") { expect(has_right_default_tab).to be true }
          it("shows no video tab for UID #{uid}") { expect(has_video_tab).to be false }

        # No audio and no video
        elsif video_you_tube_id.nil? && audio_url.nil?

          has_no_course_capture_message = @my_academics.verify_block { @my_academics.no_course_capture_msg_element.when_visible timeout }
          it("shows a 'no recordings' message for UID #{uid}") { expect(has_no_course_capture_message).to be true }

        # Video but no audio
        elsif audio_url.nil? && !video_you_tube_id.nil?

          has_right_default_tab = @my_academics.verify_block { @my_academics.video_table_element.when_visible timeout }
          has_audio_tab = @my_academics.audio_tab?

          it("shows the video tab by default for UID #{uid}") { expect(has_right_default_tab).to be true }
          it("shows no audio tab for UID #{uid}") { expect(has_audio_tab).to be false }

        # Video and audio
        else

          has_right_default_tab =  @my_academics.verify_block { @my_academics.video_table_element.when_visible timeout }
          has_audio_tab = @my_academics.audio_tab?

          it("shows the video tab by default for UID #{uid}") { expect(has_right_default_tab).to be true }
          it("shows an audio tab for UID #{uid}") { expect(has_audio_tab).to be true }

        end

        # Video content
        unless video_you_tube_id.nil?
          @my_academics.video_table_element.when_present timeout
          @my_academics.show_all_recordings

          has_you_tube_alert = @my_academics.you_tube_alert?
          has_help_page_link = @my_academics.verify_external_link(@driver, @my_academics.help_page_link_element, 'Service at UC Berkeley')
          all_visible_video_lectures = @my_academics.you_tube_recording_elements.length
          you_tube_link = @my_academics.you_tube_link video_you_tube_id

          it("shows an explanation for viewing the recordings at You Tube for UID #{uid}") { expect(has_you_tube_alert).to be true }
          it("shows a 'help page' link for UID #{uid}") { expect(has_help_page_link).to be true }
          it("shows all the available lecture videos for UID #{uid}") { expect(all_visible_video_lectures).to eql(lecture_count) }
          it("shows links to the recordings at YouTube for UID #{uid}") { expect(you_tube_link.exists?).to be true }

          unless video_itunes.nil?

            itunes_video_link_present = @my_academics.verify_external_link(@driver, @my_academics.itunes_video_link_element, "#{course} - Free Podcast by UC Berkeley on iTunes")
            it("shows an iTunes video URL for UID #{uid}") { expect(itunes_video_link_present).to be true }

          end
        end

        # Audio content
        unless audio_url.nil?

          @my_academics.wait_for_page_load_and_click @my_academics.audio_tab_element unless video_you_tube_id.nil?
          @my_academics.audio_source_element.when_present timeout

          all_visible_audio_lectures = @my_academics.audio_select_element.options.length
          audio_player_present = @my_academics.audio_source_element.attribute('src').include? audio_url

          it("shows all the available lecture audio recordings for UID #{uid}") { expect(all_visible_audio_lectures).to eql(lecture_count) }
          it("shows the right audio player content for UID #{uid}") { expect(audio_player_present).to be true }

          unless audio_download.nil?

            audio_download_link_present = @my_academics.audio_download_link_element.attribute('href').eql? audio_download
            it("shows an audio download link for UID #{uid}") { expect(audio_download_link_present).to be true }

          end

          unless audio_itunes.nil?

            itunes_audio_link_present = @my_academics.verify_external_link(@driver, @my_academics.itunes_audio_link_element, "#{course} - Free Podcast by UC Berkeley on iTunes")
            it("shows an iTunes audio URL for UID #{uid}") { expect(itunes_audio_link_present).to be true }

          end
        end

        unless video_you_tube_id.nil? && audio_url.nil?

          has_report_problem_link = @my_academics.verify_external_link(@driver, @my_academics.report_problem_link_element, 'Request Support or Give Feedback | Educational Technology Services')
          it("offers a 'Report a Problem' link for UID #{uid}") { expect(has_report_problem_link).to be true }

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
