require_relative '../../util/spec_helper'

class ApiAdminPage

  include PageObject
  include Logging

  h1(:unauth_msg, xpath: '//*[contains(.,"Unauthorized")]')

  def load_cachejob
    navigate_to "#{BOACUtils.base_url}/api/admin/cachejob"
  end

end
