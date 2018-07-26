require_relative '../../util/spec_helper'

module Page

  module BOACPages

    class AdminPage

      include PageObject
      include Logging
      include Page
      include BOACPages

      # Loads the admin page
      def load_page
        navigate_to "#{BOACUtils.base_url}/admin"
      end

    end
  end
end
