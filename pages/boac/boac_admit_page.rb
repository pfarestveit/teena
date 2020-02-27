class BOACAdmitPage

  include Logging
  include PageObject
  include Page
  include BOACPages

  h1(:name, id: 'admit-name-header')
  cell(:uc_cpid, id: 'admit-apply-uc-cpid')
  cell(:sid, id: 'admit-sid')
  cell(:uid, id: 'admit-uid')
  cell(:birth_date, id: 'admit-birthdate')
  cell(:fresh_trans, id: 'admit.freshman-or-transfer')
  cell(:status, id: 'admit-admit-status')
  cell(:sir, id: 'admit-current-sir')
  cell(:college, id: 'admit-college')
  cell(:term, id: 'admit-admit-term')
  cell(:email, id: 'admit-email')
  cell(:campus_email, id: 'admit-campus-email')
  cell(:daytime_phone, id: 'admit-daytime-phone')
  cell(:mobile, id: 'admit-mobile')
  div(:address_street_1, id: 'admit-permanent-street-1')
  div(:address_street_2, id: 'admit-permanent-street-2')
  div(:address_city_region_postal, id: 'admit-permanent-city-region-postal')
  div(:address_country, id: 'admit-permanent-country')
  cell(:sex, id: 'admit-sex')
  cell(:gender_identity, id: 'admit-gender-identity')
  cell(:x_ethnic, id: 'admit-x-ethnic')
  cell(:hispanic, id: 'admit-hispanic')
  cell(:urem, id: 'admit-urem')
  cell(:residency_cat, id: 'admit-residency-category')
  cell(:citizen_status, id: 'admit-us-citizenship-status')
  cell(:non_citizen_status, id: 'admit-us-non-citizen-status')
  cell(:citizenship, id: 'admit-citizenship-country')
  cell(:residence_country, id: 'admit-permanent-residence-country')
  cell(:visa_status, id: 'admit-non-immigrant-visa-current')
  cell(:visa_planned, id: 'admit-non-immigrant-visa-planned')
  cell(:first_gen_student, id: 'admit-first-generation-student')
  cell(:first_gen_college, id: 'admit-first-generation-college')
  cell(:parent_1_educ, id: 'admit-parent-1-education-level')
  cell(:parent_2_educ, id: 'admit-parent-2-education-level')
  cell(:parent_highest_educ, id: 'admit-highest-parent-education-level')
  cell(:gpa_hs_unweighted, id: 'admit-gpa-hs-unweighted')
  cell(:gpa_hs_weighted, id: 'admit-gpa-hs-weighted')
  cell(:gpa_transfer, id: 'admit-gpa-transfer')
  cell(:act_composite, id: 'admit-act-composite')
  cell(:act_math, id: 'admit-act-math')
  cell(:act_english, id: 'admit-act-english')
  cell(:act_reading, id: 'admit-act-reading')
  cell(:act_writing, id: 'admit-act-writing')
  cell(:sat_total, id: 'admit-sat-total')
  cell(:sat_evidence, id: 'admit-sat-evidence')
  cell(:sat_math, id: 'admit-sat-math')
  cell(:sat_reading, id: 'admit-sat-reading')
  cell(:sat_analysis, id: 'admit-sat-analysis')
  cell(:sat_writing, id: 'admit-sat-writing')
  cell(:fee_waiver, id: 'admit-application-fee-waiver-flag')
  cell(:foster_care, id: 'admit-foster-care-flag')
  cell(:family_single_parent, id: 'admit-family-is-single-parent')
  cell(:student_single_parent, id: 'admit-student-is-single-parent')
  cell(:family_dependents, id: 'admit-family-dependents-num')
  cell(:student_dependents, id: 'admit-student-dependents-num')
  cell(:family_income, id: 'admit-family-income')
  cell(:student_income, id: 'admit-student-income')
  cell(:military_dependent, xpath: '//th[text()="Is Military Dependent"]/following-sibling::td')
  cell(:military_status, id: 'admit-military-status')
  cell(:re_entry_status, id: 'admit-reentry-status')
  cell(:athlete_status, id: 'admit-athlete-status')
  cell(:summer_bridge_status, id: 'admit-summer-bridge-status')
  cell(:last_school_lcff_plus, id: 'admit-last-school-lcff-plus-flag')
  cell(:special_pgm_cep, id: 'admit-special-program-cep')

  # Loads the page for a given admit
  # @param admit_csid [String]
  def load_page(admit_csid)
    logger.info "Loading admit page for CS ID #{admit_csid}"
    navigate_to "#{BOACUtils.base_url}/admit/student/#{admit_csid}"
    wait_for_spinner
    name_element.when_visible Utils.short_wait
  end

  # Returns the concatenated first, middle, and last names
  # @param admit [Hash]
  # @return [String]
  def concatenated_name(admit)
    "#{admit[:first_name]}#{' ' + admit[:middle_name] unless admit[:middle_name].empty?} #{admit[:last_name]}"
  end

  # Returns the link element for a student page
  # @param admit [Hash]
  # @return [PageObject::Elements::Link]
  def student_page_link(admit)
    link_element(xpath: "//a[text()=\"View #{concatenated_name admit}'s profile page\"]")
  end

  # Clicks the student page link
  # @param admit [Hash]
  def click_student_page_link(admit)
    logger.info "Clicking the student page link for SID #{admit[:cs_empl_id]}"
    wait_for_update_and_click student_page_link(admit)
  end

end
