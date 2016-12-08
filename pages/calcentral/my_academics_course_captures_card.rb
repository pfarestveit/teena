require_relative '../../util/spec_helper'

module Page

  module CalCentralPages

    class MyAcademicsCourseCapturesCard < MyAcademicsClassPage

      include PageObject
      include Logging
      include Page
      include CalCentralPages

      # COURSE CAPTURES
      h2(:course_capture_heading, xpath: '//h2[text()="Course Captures"]')
      link(:video_tab, text: 'Video')
      div(:no_video_msg, xpath: '//div[contains(.,"No video content available.")]')
      div(:you_tube_alert, xpath: '//div[contains(.,"Log in to YouTube with your bConnected account to watch the videos below.")]')
      link(:help_page_link, xpath: '//a[contains(.,"help page")]')
      table(:video_table, xpath: '//table[@data-ng-if="section.videos.length"]')
      elements(:you_tube_recording, :link, xpath: '//a[@data-ng-bind="video.lecture"]')
      button(:show_more_videos, xpath: '//div[@data-cc-show-more-list="section.videos"]/button')
      link(:itunes_video_link, xpath: '//li[@class="cc-widget-webcast-itunes-link"]/a')
      link(:audio_tab, text: 'Audio')
      div(:no_audio_msg, xpath: '//div[contains(.,"No audio content available.")]')
      select(:audio_select, xpath: '//select[@data-ng-model="selectedAudio"]')
      audio(:audio, xpath: '//audio')
      audio(:audio_source, xpath: '//audio/source')
      link(:audio_download_link, xpath: '//li[@data-ng-if="selectedAudio.downloadUrl"]/a')
      link(:itunes_audio_link, xpath: '//li[@data-ng-if="iTunes.audio"]/a')
      div(:no_course_capture_msg, xpath: '//div[contains(text(),"There are no recordings available.")]')
      link(:report_problem_link, xpath: '//a[contains(text(),"Report a problem")]')

      # Clicks the 'show more' button until it disappears
      def show_all_recordings
        show_more_videos while show_more_videos?
      end

      # Returns the link element whose href attribute includes a given YouTube video ID
      # @param video_id [String]
      # @return [PageObject::Elements::Link]
      def you_tube_link(video_id)
        you_tube_recording_elements.find { |recording| recording.attribute('href').include? video_id }
      end

    end
  end
end
