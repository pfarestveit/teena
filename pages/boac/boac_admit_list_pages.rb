require_relative '../../util/spec_helper'

module BOACAdmitListPages

  include Logging
  include PageObject
  include Page
  include BOACPages
  include BOACPagination

  elements(:admit_sid, :span, xpath: '//h1[@id="admit-results-page-header"]/following-sibling::div//span[text()="C S I D"]/following-sibling::span')

  # Returns all the CS IDs visible in a list of admits
  # @return [Array<String>]
  def all_row_cs_ids
    admit_sid_elements.map &:text
  end

  # Returns all the data shown in a row for a given admit
  # @param admit [BOACUser]
  # @return [Hash]
  def visible_admit_row_data(admit)
    row_xpath = "//h1[@id='admit-results-page-header']/following-sibling::div//tr[contains(.,\"#{admit.sis_id}\")]"
    name_el = link_element(xpath: "#{row_xpath}//span[text()='Admitted student name']/following-sibling::a")
    sid_el = span_element(xpath: "#{row_xpath}//span[text()='C S I D']/following-sibling::span")
    sir_el = span_element(xpath: "#{row_xpath}//span[text()='S I R']/following-sibling::span")
    cep_el = span_element(xpath: "#{row_xpath}//span[text()='C E P']/following-sibling::span")
    re_entry_el = span_element(xpath: "#{row_xpath}//span[text()='Re-entry']/following-sibling::span")
    first_gen_el = span_element(xpath: "#{row_xpath}//span[text()='First generation']/following-sibling::span")
    urem_el = span_element(xpath: "#{row_xpath}//span[text()='U R E M']/following-sibling::span")
    waiver_el = span_element(xpath: "#{row_xpath}//span[text()='Waiver']/following-sibling::span")
    fresh_trans_el = span_element(xpath: "#{row_xpath}//span[text()='Transfer']/following-sibling::span")
    {
      name: (name_el.text if name_el.exists?),
      cs_id: (sid_el.text if sid_el.exists?),
      sir: (sir_el.text if sir_el.exists?),
      cep: (cep_el.text if cep_el.exists?),
      re_entry: (re_entry_el.text if re_entry_el.exists?),
      first_gen: (first_gen_el.text if first_gen_el.exists?),
      urem: (urem_el.text if urem_el.exists?),
      waiver: (waiver_el.text if waiver_el.exists?),
      fresh_trans: (fresh_trans_el.text if fresh_trans_el.exists?)
    }
  end

  # Clicks the Name header to sort ascending or descending
  def sort_by_name
    sort_by_option 'Name'
  end

  # Returns the sequence of SIDs that should be present when sorted by last name ascending
  # @param admit_data [Array<Hash>]
  # @return [Array<String>]
  def expected_cs_ids_by_name_asc(admit_data)
    sorted_admits = admit_data.sort_by { |u| [u[:last_name_sortable_user_list].downcase, u[:first_name_sortable_user_list].downcase, u[:sid]] }
    sorted_admits.map { |u| u[:sid] }
  end

  # Returns the sequence of SIDs that should be present when sorted by last name descending
  # @param admit_data [Array<Hash>]
  # @return [Array<String>]
  def expected_cs_ids_by_name_desc(admit_data)
    sorted_admits = admit_data.sort do |a, b|
      [b[:last_name_sortable_user_list].downcase, a[:first_name_sortable_user_list], a[:sid]] <=> [a[:last_name_sortable_user_list].downcase, b[:first_name_sortable_user_list], b[:sid]]
    end
    sorted_admits.map { |u| u[:sid] }
  end

  # Clicks the link to the admit page and waits for the page to load
  # @param admit [BOACUser]
  def click_admit_link(admit)
    logger.info "Clicking the link for CS ID #{admit.sis_id}"
    wait_for_update_and_click link_element(id: "link-to-admit-#{admit.sis_id}")
    wait_for_title "#{admit.first_name} #{admit.last_name} | BOA"
  end

end
