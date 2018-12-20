require_relative '../../util/spec_helper'

class BOACAdminPage

  include PageObject
  include Logging
  include Page
  include BOACPages

  link(:admins_link, :text => 'Admins')

  # Loads the admin page
  def load_page
    navigate_to "#{BOACUtils.base_url}/admin"
  end

end
