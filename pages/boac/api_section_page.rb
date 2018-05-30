require_relative '../../util/spec_helper'

class ApiSectionPage

  include PageObject
  include Logging

  def get_data(driver, term_id, ccn)
    logger.info "Getting data for section #{ccn}"
    navigate_to "#{BOACUtils.base_url}/api/section/#{term_id}/#{ccn}"
    wait_until(Utils.long_wait) { driver.find_element(xpath: '//pre') }
    @parsed = JSON.parse driver.find_element(xpath: '//pre').text
  end

  def meetings
    @parsed['meetings'] && @parsed['meetings'].map do |meet|
      {
        :instructors => (meet['instructors'].map { |i| i.gsub(/\s+/, ' ') }),
        :days => meet['days'],
        :time => meet['time'],
        :location => (meet['location'] && meet['location'].gsub(/\s+/, ' '))
      }
    end
  end

  def student_sids
    @parsed['students'] && @parsed['students'].map { |s| s['sid'] }
  end

end
