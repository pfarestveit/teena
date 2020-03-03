class BOACApiAdmitPage

  include PageObject
  include Logging

  def hit_endpoint(admit)
    logger.info "Hitting the API for CS ID #{admit.sis_id}"
    navigate_to "#{BOACUtils.api_base_url}/api/admit/by_sid/#{admit.sis_id}"
    wait_until(Utils.long_wait) { browser.find_element(xpath: '//pre') }
    @parsed = JSON.parse browser.find_element(xpath: '//pre').text
  end

  def message
    @parsed['message']
  end

end
