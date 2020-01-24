

class BOACFlightDataRecorderPage

  include PageObject
  include Logging
  include Page
  include BOACPages

  def load_page(dept)
    logger.info "Hitting the FDR page for #{dept.name}"
    navigate_to "#{BOACUtils.base_url}/analytics/#{dept.code}"
  end

  select_list(:dept_select, id: 'available-department-reports')
  button(:show_hide_report_button, id: 'show-hide-notes-report')
  div(:notes_count_boa, id: 'notes-count-boa')
  div(:notes_count_boa_authors, id: 'notes-count-boa-authors')
  div(:notes_count_boa_with_attachments, id: 'notes-count-boa-with-attachments')
  div(:notes_count_boa_with_topics, id: 'notes-count-boa-with-topics')
  div(:notes_count_sis, id: 'notes-count-sis')
  div(:notes_count_asc, id: 'notes-count-asc')

  def select_dept_report(dept)
    name = dept.export_name || dept.name
    logger.info "Selecting report for #{name}"
    wait_for_element_and_select_js(dept_select_element, name)
  end

  def toggle_note_report_visibility
    logger.info 'Clicking the show/hide report button'
    wait_for_update_and_click show_hide_report_button_element
  end

  elements(:advisor_link, :link, xpath: '//a[contains(@id, "directory-link-")]')
  elements(:advisor_non_link, :span, xpath: '//span[contains(text(), "Name unavailable (UID:")]')

  def dept_list_header(dept)
    name = dept.export_name || dept.name
    h3_element(xpath: "//h3[contains(text(), '#{name}')]")
  end

  def wait_for_user_count(dept, uid_count)
    wait_until(Utils.short_wait) { dept_list_header(dept).attribute('innerText').include? "#{uid_count}" }
  end

  # Returns all the UIDs in an advisor result set
  # @return [Array<String>]
  def list_view_uids(dept, uid_count)
    wait_until(Utils.short_wait) { advisor_link_elements.any? }
    links = advisor_link_elements.map { |el| el.attribute('id').split('-').last }
    non_links = advisor_non_link_elements.map { |el| el.text.split.last.delete(")") }
    links + non_links
  end




end
