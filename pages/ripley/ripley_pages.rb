require_relative '../../util/spec_helper'

module RipleyPages

  include Logging
  include PageObject
  include Page

  element(:header, xpath: '//header')

  def hide_header
    header_element.when_present Utils.medium_wait
    execute_script(
      'const header = document.evaluate(
        "//header",
        document,
        null,
        XPathResult.FIRST_ORDERED_NODE_TYPE,
        null,
        ).singleNodeValue;

        header.style.display="none";'
    )
  end

  button(:header_menu_button, xpath: '//button[@aria-haspopup="menu"]')
  button(:log_out_link, id: 'log-out')

  def log_out
    wait_for_update_and_click header_menu_button_element
    wait_for_update_and_click log_out_link_element unless title.include? 'Welcome. Please log in. | bCourses Support'
    log_out_link_element.when_not_present Utils.short_wait
  end

  def load_tool_in_canvas(path)
    logger.info "Loading #{Utils.canvas_base_url}#{path}"
    navigate_to "#{Utils.canvas_base_url}#{path}"
    switch_to_canvas_iframe RipleyUtils.base_url
  end

  # UI shared across tools

  h1(:unexpected_error, id: 'TBD')
  h1(:denied_msg, id: 'TBD')
  div(:auth_check_failed_msg, xpath: '//div[contains(text(), "Authorization check failed.")]')
  div(:no_access_msg, id: 'TBD "This feature is only available to faculty and staff."')
  div(:error_message, id: 'error-message')
  div(:unauthorized_msg, xpath: '//div[@class="v-alert__content"][contains(., "Unauthorized") or contains(., "not authorized")]')
  div(:sis_import_error, xpath: '//div[text()="An error has occurred with your request. Please try again or contact bCourses support."]')

  div(:progress_bar, id: 'TBD')

  def wait_for_progress_bar
    logger.info 'Waiting for progress bar'
    progress_bar_element.when_visible Utils.medium_wait
    progress_bar_element.when_not_present Utils.long_wait
  end

  # Daily maintenance notice

  span(:maintenance_notice, xpath: '//div[contains(., "you may experience delays of up to 10 minutes")]')
  div(:maintenance_detail, xpath: '//div[contains(., "bCourses performs scheduled maintenance every day")]')
  link(:bcourses_service_link, id: 'link-to-httpsrtlberkeleyeduservicesprogramsbcourses')

  def expand_maintenance_notice
    wait_for_load_and_click maintenance_notice_button_element
    maintenance_detail_element.when_visible Utils.short_wait
  end

  def hide_maintenance_notice
    wait_for_load_and_click maintenance_notice_button_element
    maintenance_detail_element.when_not_visible Utils.short_wait
  end

  # Buttons

  button(:continue_button, id: 'continue-button')
  button(:cancel_button, id: 'cancel-button')

  def click_continue
    logger.debug 'Clicking continue'
    wait_for_load_and_click continue_button_element
  end

  def click_cancel(course_site)
    logger.debug 'Clicking cancel'
    wait_for_load_and_click cancel_button_element
    wait_until(Utils.medium_wait) { current_url == "#{Utils.canvas_base_url}/courses/#{course_site.site_id}/gradebook" }
  end
end
