module BOACListViewAdmitPages

  include Logging
  include PageObject
  include Page
  include BOACPages
  include BOACPagination
  include BOACAdmitPages

  def admit_row_xpath(admit)
    "//tr[@id=\"admit-#{admit.sis_id}\"]"
  end

  def visible_admit_row_data(admit_cs_id)
    search_heading_path = '//h1[@id="admit-results-page-header"]'
    row_xpath = if h1_element(xpath: search_heading_path).exists?
                  "#{search_heading_path}/following-sibling::div//tr[contains(.,\"#{admit_cs_id}\")]"
                else
                  "//tr[contains(.,\"#{admit_cs_id}\")]"
                end
    name_el = link_element(xpath: "#{row_xpath}//span[text()='Admitted student name']/following-sibling::a")
    sid_el = span_element(xpath: "#{row_xpath}//span[text()='C S I D ']/following-sibling::span")
    sir_el = span_element(xpath: "#{row_xpath}//span[text()='S I R']/..")
    cep_el = span_element(xpath: "#{row_xpath}//span[text()='C E P']/..")
    re_entry_el = span_element(xpath: "#{row_xpath}//span[text()='Re-entry']/..")
    first_gen_el = span_element(xpath: "#{row_xpath}//span[text()='First generation']/..")
    urem_el = span_element(xpath: "#{row_xpath}//span[text()='U R E M']/..")
    waiver_el = span_element(xpath: "#{row_xpath}//span[text()='Waiver']/..")
    fresh_trans_el = span_element(xpath: "#{row_xpath}//span[text()='Freshman or Transfer']/..")
    intl_el = span_element(xpath: "#{row_xpath}//span[text()='Residency']/..")
    {
      name: (name_el.text if name_el.exists?),
      cs_id: (sid_el.text if sid_el.exists?),
      sir: (sir_el.text.gsub('S I R', '').strip if sir_el.exists?),
      cep: (cep_el.text.gsub('C E P', '').strip if cep_el.exists?),
      re_entry: (re_entry_el.text.gsub('Re-entry', '').strip if re_entry_el.exists?),
      first_gen: (first_gen_el.text.gsub('First generation', '').strip if first_gen_el.exists?),
      urem: (urem_el.text.gsub('U R E M', '').strip if urem_el.exists?),
      waiver: (waiver_el.text.gsub("Waiver", '').strip if waiver_el.exists?),
      fresh_trans: (fresh_trans_el.text.gsub('Freshman or Transfer', '').strip if fresh_trans_el.exists?),
      intl: (intl_el.text.gsub('Residency', '').strip if intl_el.exists?)
    }
  end

  def verify_admit_row_data(admit_cs_id, expected, failures)
    begin
      logger.debug "Checking visible data for CS ID #{admit_cs_id}"
      visible = visible_admit_row_data admit_cs_id
      visible.delete_if { |k, _| [:name, :cs_id, :sir].include? k }
      expected_data = {
        cep: (expected[:special_program_cep].empty? ? 'No data' : expected[:special_program_cep]),
        re_entry: expected[:re_entry_status],
        first_gen: (expected[:first_gen_college].empty? ? "—\nNo data" : expected[:first_gen_college]),
        urem: expected[:urem],
        waiver: (expected[:fee_waiver].empty? ? "—\nNo data" : expected[:fee_waiver]),
        fresh_trans: expected[:freshman_or_transfer],
        intl: expected[:intl]
      }
      wait_until(1) { visible[:cep] == "#{expected_data[:cep]}" }
      wait_until(1) { visible[:re_entry] == "#{expected_data[:re_entry]}" }
      wait_until(1) { visible[:first_gen] == "#{expected_data[:first_gen]}" }
      wait_until(1) { visible[:urem] == "#{expected_data[:urem]}" }
      wait_until(1) { visible[:waiver] == "#{expected_data[:waiver]}" }
      wait_until(1) { visible[:fresh_trans] == "#{expected_data[:fresh_trans]}" }
      wait_until(1) { visible[:intl] == "#{expected_data[:intl]}" }
    rescue
      logger.error "Expected #{expected_data}, got #{visible}"
      failures << admit_cs_id
    end
  end

  def sort_by_name
    sort_by_option 'Name'
  end

  def expected_cs_ids_by_name_asc(admit_data)
    sorted_admits = admit_data.sort_by { |u| [u[:last_name_sortable_user_list].downcase, u[:first_name_sortable_user_list].downcase, u[:sid]] }
    sorted_admits.map { |u| u[:sid] }
  end

  def expected_cs_ids_by_name_desc(admit_data)
    sorted_admits = admit_data.sort do |a, b|
      [b[:last_name_sortable_user_list].downcase, a[:first_name_sortable_user_list], a[:sid]] <=> [a[:last_name_sortable_user_list].downcase, b[:first_name_sortable_user_list], b[:sid]]
    end
    sorted_admits.map { |u| u[:sid] }
  end

  def click_admit_link(cs_id)
    logger.info "Clicking the link for CS ID #{cs_id}"
    wait_for_update_and_click link_element(id: "link-to-admit-#{cs_id}")
  end

  # LIST VIEW - SEARCH RESULTS

  elements(:admit_search_results_sid, :span, xpath: '//h2[@id="admit-results-page-header"]/..//span[text()="C S I D "]/following-sibling::span')

  def search_result_all_row_cs_ids
    admit_search_results_sid_elements.map &:text
  end

  # LIST VIEW - COHORT/GROUP

  elements(:admit_cohort_sid, :span, xpath: '//span[contains(@id, "-cs-empl-id")]')

  def admit_cohort_row_sids
    admit_cohort_sid_elements.map &:text
  end

  def wait_for_admit_cohort_sids
    wait_until(Utils.short_wait) { admit_cohort_sid_elements.any? }
  end

  def list_view_admit_sids(cohort)
    wait_for_admit_cohort_sids unless cohort.member_data&.length&.zero? || cohort.members&.length&.zero?
    visible_sids = []
    sleep 1
    page_count = list_view_page_count
    page = 1
    if page_count == 1
      logger.debug 'There is 1 page'
      visible_sids << admit_cohort_row_sids
    else
      logger.debug "There are #{page_count} pages"
      visible_sids << admit_cohort_row_sids
      (page_count - 1).times do
        start_time = Time.now
        page += 1
        wait_for_update_and_click go_to_next_page_link_element
        wait_until(Utils.medium_wait) { admit_cohort_sid_elements.any? }
        logger.warn "Page #{page} took #{Time.now - start_time} seconds to load" unless page == 1
        visible_sids << admit_cohort_row_sids
      end
    end
    visible_sids.flatten
  end

  # ADMIT ADD-TO-GRP

  elements(:admit_row_cbx, :checkbox, xpath: '//input[contains(@id, "-admissions-group-checkbox")]')

  def admit_row_cbx_sids
    admit_row_cbx_elements.map { |el| el.attribute('id').split('-')[1] }
  end

  def wait_for_admit_checkboxes
    wait_until(Utils.short_wait) { admit_row_cbx_elements.any? }
  end

  def admits_available_to_add_to_grp(test, group)
    group_sids = group.members.map &:sis_id
    wait_for_admit_checkboxes
    visible_sids = admit_row_cbx_sids - group_sids
    test.admits.select { |m| visible_sids.include? m.sis_id }
  end

end
