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

  button(:log_out_link, id: 'TBD')

  def log_out
    wait_for_update_and_click log_out_link_element unless title.include? 'Welcome. Please log in. | bCourses Support'
    log_out_link_element.when_not_present Utils.short_wait
  end

  def load_tool_in_canvas(path)
    navigate_to "#{Utils.canvas_base_url}#{path}"
    switch_to_canvas_iframe RipleyUtils.base_url
  end

  # UI shared across tools

  h1(:unexpected_error, id: 'TBD')
  h1(:denied_msg, id: 'TBD')
  div(:auth_check_failed_msg, id: 'TBD "Authorization check failed."')
  div(:no_access_msg, id: 'TBD "This feature is only available to faculty and staff."')

  div(:progress_bar, is: 'TBD')

  def wait_for_progress_bar
    logger.info 'Waiting for progress bar'
    progress_bar_element.when_visible Utils.medium_wait
    progress_bar_element.when_not_present Utils.long_wait
  end

  # Daily maintenance notice

  button(:maintenance_notice_button, id: 'TBD')
  span(:maintenance_notice, id: 'TBD')
  paragraph(:maintenance_detail, id: 'TBD')
  link(:bcourses_service_link, id: 'TBD')

  def expand_maintenance_notice
    wait_for_load_and_click maintenance_button_element
    maintenance_detail_element.when_visible Utils.short_wait
  end

  def hide_maintenance_notice
    wait_for_load_and_click maintenance_button_element
    maintenance_detail_element.when_not_visible Utils.short_wait
  end

  # Buttons

  button(:continue_button, id: 'TBD')
  button(:cancel_button, id: 'TBD')

  def click_continue
    logger.debug 'Clicking continue'
    wait_for_load_and_click_js continue_button_element
  end

  def click_cancel(course_site)
    logger.debug 'Clicking cancel'
    wait_for_load_and_click cancel_button_element
    wait_until(Utils.medium_wait) { current_url == "#{Utils.canvas_base_url}/courses/#{course_site.site_id}/gradebook" }
  end
end
