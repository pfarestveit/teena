require_relative '../../util/spec_helper'

class ApiMyClassesPage

  include PageObject
  include Logging

  def get_feed(driver)
    logger.info 'Parsing data from /api/my/classes'
    navigate_to "#{Utils.calcentral_base_url}/api/my/classes"
    wait_until(Utils.long_wait) { driver.find_element(xpath: '//pre[contains(.,"MyClasses::Merged")]') }
    @parsed = JSON.parse driver.find_element(xpath: '//pre').text
  end

  def current_term(driver)
    get_feed(driver)
    @parsed['current_term']
  end

end
