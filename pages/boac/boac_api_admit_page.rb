class BOACApiAdmitPage

  include PageObject
  include Logging
  include Page

  def hit_endpoint(admit)
    logger.info "Hitting the API for CS ID #{admit.sis_id}"
    navigate_to "#{BOACUtils.api_base_url}/api/admit/by_sid/#{admit.sis_id}"
    parse_json
  end

  def message
    @parsed['message']
  end

end
