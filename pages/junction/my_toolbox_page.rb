require_relative '../../util/spec_helper'

module Page

  module JunctionPages

    class MyToolboxPage

      include PageObject
      include Logging
      include Page
      include JunctionPages

      # Loads My Toolbox
      def load_page
        logger.info 'Loading My Toolbox page'
        navigate_to "#{JunctionUtils.junction_base_url}/toolbox"
      end

    end
  end
end
