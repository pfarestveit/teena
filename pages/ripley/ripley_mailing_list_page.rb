require_relative '../../util/spec_helper'

class RipleyMailingListPage

  include PageObject
  include Logging
  include Page
  include RipleyPages

  link(:mailing_list_link, text: RipleyTool::MAILING_LIST.name)
  div(:no_list_msg, xpath: '//div[text()=" No Mailing List has been created for this site. "]')
  button(:create_list_button, id: 'btn-create-mailing-list')
  div(:list_created_msg, id: 'TBD "A Mailing List has been created"')
  div(:list_address, id: 'TBD')
  div(:list_dupe_error_msg, id: 'TBD "A Mailing List cannot be created for the site"')
  div(:list_dupe_email_msg, id: 'TBD "is already in use by another Mailing List."')

  def embedded_tool_path(course)
    "/courses/#{course.site_id}/external_tools/#{RipleyUtils.mailing_list_tool_id}"
  end

  def hit_embedded_tool_url(course)
    navigate_to "#{Utils.canvas_base_url}#{embedded_tool_path course}"
  end

  def load_embedded_tool(course)
    logger.info "Loading embedded instructor Mailing List tool for course ID #{course.site_id}"
    load_tool_in_canvas embedded_tool_path(course)
  end

  def load_standalone_tool(course)
    logger.info "Loading standalone instructor Mailing List tool for course ID #{course.site_id}"
    navigate_to "#{RipleyUtils.base_url} TBD #{course.site_id}"
  end

  def create_list
    logger.info 'Clicking create-list button'
    wait_for_update_and_click create_list_button_element
    list_created_msg_element.when_present Utils.short_wait
  end

  # WELCOME EMAIL

  link(:welcome_email_link, id: 'TBD')
  text_field(:email_subject_input, id: 'TBD')
  elements(:email_body_text_area, :text_area, id: 'TBD')
  button(:email_save_button, id: 'TBD')
  button(:email_activation_toggle, id: 'TBD')
  div(:email_paused_msg, id: 'TBD "Sending welcome emails is paused until activation."')
  div(:email_activated_msg, id: 'TBD "Welcome email activated."')
  div(:email_subject, id: 'TBD')
  div(:email_body, id: 'TBD')
  button(:email_edit_button, id: 'TBD')
  button(:email_edit_cancel_button, id: 'TBD')
  button(:email_log_download_button, id: 'TBD')

  def enter_email_subject(subject)
    logger.info "Entering subject '#{subject}'"
    wait_for_element_and_type(email_subject_input_element, subject)
  end

  def enter_email_body(body)
    logger.info "Entering body '#{body}'"
    wait_for_textbox_and_type(email_body_text_area_elements[1], body)
  end

  def click_save_email_button
    logger.info 'Clicking the save email button'
    wait_for_update_and_click email_save_button_element
    email_subject_element.when_visible Utils.short_wait
  end

  def click_edit_email_button
    logger.info 'Clicking the edit button'
    wait_for_update_and_click email_edit_button_element
  end

  def click_cancel_edit_button
    logger.info 'Clicking the cancel email edit button'
    wait_for_update_and_click email_edit_cancel_button_element
  end

  def click_activation_toggle
    logger.info 'Clicking email activation toggle'
    wait_for_update_and_click email_activation_toggle_element
  end

  def download_csv
    logger.info 'Downloading mail audit CSV'
    Utils.prepare_download_dir
    path = "#{Utils.download_dir}/embedded-welcome-messages-log*.csv"
    wait_for_update_and_click email_log_download_button_element
    wait_until(Utils.short_wait) { Dir[path].any? }
    CSV.table Dir[path].first
  end
end
