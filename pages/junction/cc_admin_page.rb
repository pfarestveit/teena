require_relative '../../util/spec_helper'

class CCAdminPage

  include PageObject
  include Logging
  include Page
  include JunctionPages

  h1(:heading, xpath: '//h1[text()="Site Administration"]')
  row(:canvas_sync_row, class: 'canvas_csv_synchronization_row')
  cell(:last_enrollment_sync, xpath: '//td[contains(@class, "last_enrollment_sync_field")]')
  cell(:last_instructor_sync, xpath: '//td[contains(@class, "last_instructor_sync_field")]')
  text_field(:last_enrollment_sync_input, id: 'canvas_csv_synchronization_last_enrollment_sync')
  text_field(:last_instructor_sync_input, id: 'canvas_csv_synchronization_last_instructor_sync')
  button(:save_button, name: '_save')

  def load_page(cal_net_page, username, password)
    navigate_to "#{JunctionUtils.junction_base_url}/ccadmin"
    # Depending on current login state, either the page will load or CAS authentication will be required
    wait_until(Utils.medium_wait) { heading? || cal_net_page.sign_in_button? }
    if cal_net_page.sign_in_button?
      cal_net_page.enter_credentials(username, password)
      # Depending on current login state, either the page will load or CAS re-authentication will be required
      wait_until(Utils.long_wait) { heading? || cal_net_page.sign_in_button? }
      if cal_net_page.sign_in_button?
        cal_net_page.enter_credentials(username, password)
        heading_element.when_visible Utils.long_wait
      end
    end
  end

  def edit_date_field(element, date_str)
    element.when_visible Utils.short_wait
    element.click
    sleep Utils.click_wait
    hit_escape
    30.times { hit_delete; hit_backspace }
    element.send_keys date_str
    sleep 1
  end

  def edit_canvas_sync(date)
    navigate_to "#{JunctionUtils.junction_base_url}/ccadmin/canvas_csv~synchronization/1/edit"
    date_str = date.strftime('%B %d, %Y %H:%M')
    logger.info "Entering last sync date '#{date_str}'"
    edit_date_field(last_instructor_sync_input_element, date_str)
    edit_date_field(last_enrollment_sync_input_element, date_str)
    wait_for_update_and_click save_button_element
    canvas_sync_row_element.when_visible Utils.short_wait
    wait_until(1, "Expected #{date_str} got #{last_enrollment_sync}") { last_enrollment_sync == date_str }
    wait_until(1, "Expected #{date_str} got #{last_instructor_sync}") { last_instructor_sync == date_str}
  end

end
