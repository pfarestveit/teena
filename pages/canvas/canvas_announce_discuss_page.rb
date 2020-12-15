require_relative '../../util/spec_helper'

module Page

  class CanvasAnnounceDiscussPage < CanvasPage

    include PageObject
    include Logging
    include Page

    link(:settings_link, class: 'announcement_cog')
    link(:delete_link, class: 'delete_discussion')

    # Deletes an announcement or a discussion
    # @param title [String]
    # @param url [String]
    def delete_activity(title, url)
      logger.info "Deleting '#{title}'"
      navigate_to url
      wait_for_load_and_click settings_link_element
      alert { wait_for_update_and_click delete_link_element }
      list_item_element(xpath: "//li[contains(.,'#{title} deleted successfully')]").when_present Utils.short_wait
    end

    # ANNOUNCEMENTS

    link(:html_editor_link, xpath: '//a[contains(.,"HTML Editor")]')
    text_area(:announcement_msg, name: 'message')
    h1(:announcement_title_heading, class: 'discussion-title')

    # Creates an announcement on a course site
    # @param course [Course]
    # @param announcement [Announcement]
    def create_course_announcement(course, announcement)
      logger.info "Creating announcement: #{announcement.title}"
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/discussion_topics/new?is_announcement=true"
      enter_and_save_announcement announcement
    end

    # Creates an announcement in a group within a course site
    # @param group [Group]
    # @param announcement [Announcement]
    # @param event [Event]
    def create_group_announcement(group, announcement, event = nil)
      logger.info "Creating group announcement: #{announcement.title}"
      navigate_to "#{Utils.canvas_base_url}/groups/#{group.site_id}/discussion_topics/new?is_announcement=true"
      enter_and_save_announcement(announcement, event)
    end

    # Enters an announcement title and body and saves it
    # @param announcement [Announcement]
    # @param event [Event]
    def enter_and_save_announcement(announcement, event = nil)
      discussion_title_element.when_present Utils.short_wait
      discussion_title_element.send_keys announcement.title
      html_editor_link if html_editor_link_element.visible?
      wait_for_element_and_type_js(announcement_msg_element, announcement.body)
      wait_for_update_and_click_js save_button_element
      announcement_title_heading_element.when_visible Utils.medium_wait
      add_event(event, EventType::CREATE, announcement.title)
      announcement.url = current_url
      logger.info "Announcement URL is #{announcement.url}"
    end

    # DISCUSSIONS

    link(:new_discussion_link, xpath: '//a[contains(@href,"/discussion_topics/new")]')
    link(:subscribed_link, class: 'topic-unsubscribe-button')
    text_area(:discussion_title, id: 'discussion-title')
    checkbox(:threaded_discussion_cbx, id: 'threaded')
    checkbox(:graded_discussion_cbx, id: 'use_for_grading')
    elements(:discussion_reply, :list_item, xpath: '//ul[@class="discussion-entries"]/li')
    elements(:discussion_reply_author, :link, xpath: '//ul[@class="discussion-entries"]/li//h2[@class="discussion-title"]/a')
    elements(:discussion_page_link, :link, xpath: '//div[@class="discussion-page-nav"]//a')
    link(:primary_reply_link, xpath: '//article[@id="discussion_topic"]//a[@data-event="addReply"]')
    button(:primary_post_reply_button, xpath: '//article[@id="discussion_topic"]//button[contains(.,"Post Reply")]')
    iframe(:primary_reply_iframe, xpath: '//iframe[contains(@id, "root_reply_message_for_")]')
    elements(:secondary_reply_link, :link, xpath: '//li[contains(@class,"entry")]//span[text()="Reply"]/..')
    elements(:secondary_post_reply_button, :button, xpath: '//li[contains(@class,"entry")]//button[contains(.,"Post Reply")]')
    iframe(:secondary_reply_iframe, xpath: '//iframe[contains(@id, "reply_message_for")]')
    button(:reply_prompt_dismiss_button, xpath: '//button[contains(., "No")]')
    button(:save_discuss_button, xpath: '//button[text()="Save"][@type="submit"]')

    # Creates a discussion on a course site
    # @param course [Course]
    # @param discussion [Discussion]
    # @param event [Event]
    def create_course_discussion(course, discussion, event = nil)
      logger.info "Creating discussion topic named '#{discussion.title}'"
      load_course_site course
      navigate_to "#{Utils.canvas_base_url}/courses/#{course.site_id}/discussion_topics"
      enter_and_save_discussion(discussion, event)
    end

    # Creates a discussion on a group site
    # @param group [Group]
    # @param discussion [Discussion]
    # @param event [Event]
    def create_group_discussion(group, discussion, event = nil)
      logger.info "Creating group discussion topic named '#{discussion.title}'"
      navigate_to "#{Utils.canvas_base_url}/groups/#{group.site_id}/discussion_topics"
      enter_and_save_discussion(discussion, event)
    end

    # Enters and saves a discussion topic
    # @param discussion [Discussion]
    # @param event [Event]
    def enter_and_save_discussion(discussion, event = nil)
      wait_for_load_and_click new_discussion_link_element
      discussion_title_element.when_present Utils.short_wait
      discussion_title_element.send_keys discussion.title
      js_click threaded_discussion_cbx_element
      teacher_role = save_and_publish_button?
      teacher_role ? click_save_and_publish : wait_for_update_and_click(save_discuss_button_element)
      add_event(event, EventType::CREATE, discussion.title)
      teacher_role ? published_button_element.when_visible(Utils.medium_wait) : subscribed_link_element.when_visible(Utils.medium_wait)
      discussion.url = current_url
      logger.info "Discussion URL is #{discussion.url}"
    end

    # Adds a reply to a discussion.  If an index is given, then adds a reply to an existing reply at that index.  Otherwise,
    # adds a reply to the topic itself.
    # @param discussion [Discussion]
    # @param index [Integer]
    # @param reply_body [String]
    # @param event [Event]
    def add_reply(discussion, index, reply_body, event = nil)
      navigate_to discussion.url
      hide_canvas_footer_and_popup
      if index.nil?
        logger.info "Creating new discussion entry with body '#{reply_body}'"
        wait_for_load_and_click_js primary_reply_link_element
        replies = discussion_reply_elements.length
        switch_to_frame primary_reply_iframe_element.attribute('id')
        wait_for_element_and_type_js(paragraph_element(xpath: '//p'), reply_body)
        switch_to_main_content
        reply_prompt_dismiss_button_element.click if reply_prompt_dismiss_button_element.exists?
        wait_for_load_and_click_js primary_post_reply_button_element
      else
        logger.info "Replying to a discussion entry at index #{index} with body '#{reply_body}'"
        wait_until(Utils.short_wait) { secondary_reply_link_elements.any? }
        replies = discussion_reply_elements.length
        wait_for_load_and_click_js secondary_reply_link_elements[index]
        switch_to_frame secondary_reply_iframe_element.attribute('id')
        wait_for_element_and_type_js(paragraph_element(xpath: '//p'), reply_body)
        switch_to_main_content
        reply_prompt_dismiss_button_element.click if reply_prompt_dismiss_button_element.exists?
        wait_for_load_and_click_js secondary_post_reply_button_elements[index]
      end
      add_event(event, EventType::POST, reply_body)
      wait_until(Utils.short_wait) { discussion_reply_elements.length == replies + 1 }
    end

    # Waits for a discussion thread to load and returns an array of elements containing the discussion entry authors
    # @return [Array<PageObject::Elements::Link>]
    def wait_for_discussion
      begin
        wait_until(Utils.short_wait) { discussion_reply_author_elements.any? &:visible? }
        discussion_reply_author_elements
      rescue
        logger.warn 'No discussion entries found'
        []
      end
    end

    # Given an array of elements containing discussion entry authors, returns the creators' Canvas IDs and entry dates
    # @param course [Course]
    # @param author_elements [Array<PageObject::Elements::Link>]
    # @return [Array[<Hash>]]
    def get_page_discussion_entries(course, author_elements)
      author_elements.map do |el|
        canvas_id = el.attribute('href').split('/users/')[1]
        logger.debug "Found Canvas ID #{canvas_id}"
        date_el = span_element(xpath: "//a[@data-student_id='#{canvas_id}'][contains(@title,'Author')]/../following-sibling::div[contains(@class, 'discussion-pubdate')]//span[@class='screenreader-only']")
        {
          :canvas_id => canvas_id,
          :date => DateTime.parse(date_el.text.gsub('at', ''))
        }
      end
    end

    # Returns all the authors and dates of discussion entries on a course site discussion thread
    # @param course [Course]
    # @return [Array<Hash>]
    def discussion_entries(course)
      author_els = wait_for_discussion

      # If there are entries, collect those on page one
      replies = get_page_discussion_entries(course, author_els)

      # If there are additional pages, collect those as well
      pages = (discussion_page_link_elements.map &:text).uniq if discussion_page_link_elements.any?
      if pages && pages.any?
        pages.each do |page|
          wait_for_update_and_click_js(discussion_page_link_elements.find { |el| el.text == page })
          author_els = wait_for_discussion
          replies << get_page_discussion_entries(course, author_els)
        end
      end
      replies.flatten
    end

  end
end
