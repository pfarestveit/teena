require_relative '../../util/spec_helper'

class BOACFlightDeckPage

  include PageObject
  include Logging
  include Page
  include BOACPages

  h1(:my_profile_heading, xpath: '//h1[text()="Profile"]')
  checkbox(:demo_mode_toggle, id: 'toggle-demo-mode')

  def load_advisor_page
    navigate_to "#{BOACUtils.base_url}/profile"
    my_profile_heading_element.when_visible Utils.short_wait
  end

  #### SERVICE ANNOUNCEMENTS ####

  checkbox(:post_service_announcement_checkbox, id: 'checkbox-publish-service-announcement')
  h2(:edit_service_announcement, id: 'edit-service-announcement')
  text_area(:update_service_announcement, xpath: '(//div[@role="textbox"])[2]')
  button(:update_service_announcement_button, id: 'button-update-service-announcement')
  span(:service_announcement_banner, id: 'service-announcement-banner')
  button(:dismiss_announcement_button, id: 'dismiss-service-announcement')

  def service_announcement_checkbox_label
    post_service_announcement_checkbox_element.attribute('aria-label')
  end

  def dismiss_announcement
    logger.info 'Dismissing service alert'
    wait_for_update_and_click dismiss_announcement_button_element
    service_announcement_banner_element.when_not_present 1
  end

  def update_service_announcement(announcement)
    logger.info "Entering service announcement '#{announcement}'"
    wait_for_textbox_and_type(update_service_announcement_element, announcement)
    wait_for_update_and_click update_service_announcement_button_element
  end

  def toggle_service_announcement_checkbox
    logger.info 'Clicking the service announcement posting checkbox'
    (el = post_service_announcement_checkbox_element).when_present Utils.short_wait
    js_click el
  end

  def post_service_announcement
    logger.info 'Posting a service announcement'
    post_service_announcement_checkbox.when_present Utils.short_wait
    tries ||= 2
    begin
      tries -= 1
      sleep Utils.click_wait
      toggle_service_announcement_checkbox if service_announcement_checkbox_label == 'Post'
      wait_until(Utils.short_wait) { service_announcement_checkbox_label == 'Posted' }
    rescue
      if tries.zero?
        logger.error 'Failed to post service alert'
        fail
      else
        logger.warn 'Failed to post service alert, retrying'
        retry
      end
    end
  end

  def unpost_service_announcement
    logger.info 'Un-posting a service announcement'
    post_service_announcement_checkbox.when_present Utils.medium_wait
    tries ||= 2
    begin
      tries -= 1
      sleep Utils.click_wait
      toggle_service_announcement_checkbox if service_announcement_checkbox_label == 'Posted'
      wait_until(Utils.short_wait) { service_announcement_checkbox_label == 'Post' }
    rescue
      if tries.zero?
        logger.error 'Failed to unpost a service alert'
        fail
      else
        logger.warn 'Failed to unpost a service alert, retrying'
        retry
      end

    end
  end

  ### TOPICS ###

  text_field(:topic_search_input, id: 'filter-topics')
  button(:topic_search_clear_button, xpath: '//button[contains(., "Clear")]')
  button(:topic_create_button, id: 'new-note-button')
  text_field(:topic_name_input, id: 'topic-label')
  button(:topic_save_button, id: 'topic-save')
  button(:topic_cancel_button, id: 'cancel')

  def label_validation_error
    div_element(id: 'topic-label-error').text
  end

  def label_length_validation
    span_element(id: 'input-live-help').text
  end

  def topic_row_xpath(topic)
    "//h2[text()=\"Manage Topics\"]/following-sibling::div//tbody//td[text()=\"#{topic.name}\"]/.."
  end

  def topic_row(topic)
    row_element(xpath: topic_row_xpath(topic))
  end

  def topic_deleted?(topic)
    cell_element(xpath: "#{topic_row_xpath topic}/td[2]").text == 'Yes'
  end

  def topic_in_notes_count(topic)
    cell_element(xpath: "#{topic_row_xpath topic}/td[3]").text
  end

  def topic_deletion_toggle_button(topic)
    cell_element(xpath: "#{topic_row_xpath topic}/td[4]//button")
  end

  def click_create_topic
    logger.info 'Clicking the Create topic button'
    wait_for_load_and_click topic_create_button_element
  end

  def click_save_topic
    logger.info 'Clicking the Save topic button'
    wait_for_update_and_click topic_save_button_element
  end

  def click_cancel_topic
    logger.info 'Clicking the Cancel topic button'
    wait_for_update_and_click topic_cancel_button_element
    topic_name_input_element.when_not_present 1
  end

  def delete_topic(topic)
    logger.info "Clicking the delete button for topic '#{topic.name}'"
    wait_for_update_and_click topic_deletion_toggle_button(topic)
    wait_for_update_and_click confirm_delete_or_discard_button_element
    confirm_delete_or_discard_button_element.when_not_present 1
  end

  def undelete_topic(topic)
    logger.info "Clicking the undelete button for topic '#{topic.name}'"
    wait_for_update_and_click topic_deletion_toggle_button(topic)
    sleep 1
  end

  def enter_topic_label(label)
    logger.info "Entering topic label '#{label}'"
    wait_for_element_and_type(topic_name_input_element, label)
  end

  def create_topic(topic)
    click_create_topic
    enter_topic_label topic.name
    click_save_topic
    set_new_topic_id topic
  end

  def set_new_topic_id(topic)
    wait_until(Utils.short_wait) { BOACUtils.get_topic_id topic }
  end

  def search_for_topic(topic)
    logger.info "Searching for topic '#{topic.name}'"
    wait_for_element_and_type(topic_search_input_element, topic.name)
    sleep Utils.click_wait
  end

end
