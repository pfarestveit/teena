require_relative '../../util/spec_helper'

class BOACApiAdminPage

  include PageObject
  include Logging
  include Page

  h1(:unauth_msg, xpath: '//*[contains(.,"Unauthorized")]')

  def load_cachejob
    navigate_to "#{BOACUtils.api_base_url}/api/admin/cachejob"
  end

  def refresh_cache
    logger.info 'Refreshing BOA cache'
    navigate_to "#{BOACUtils.api_base_url}/api/admin/cachejob/refresh"
    parse_json
    wait_until(1) { @parsed['progress']['end'].nil? }
    tries = Utils.short_wait
    begin
      sleep Utils.short_wait
      tries -= 1
      logger.info 'Checking if refresh is done'
      load_cachejob
      parse_json
      wait_until(1) { !@parsed['progress']['end'].nil? }
    rescue => e
      tries.zero? ? fail(e) : retry
    end
  end

  def reindex_notes
    logger.info 'Indexing notes'
    navigate_to "#{BOACUtils.api_base_url}/api/admin/reindex/notes"
    sleep Utils.short_wait
  end

  def reindex_appts
    navigate_to "#{BOACUtils.api_base_url}/api/admin/reindex/appointments"
    sleep Utils.short_wait
  end
end
