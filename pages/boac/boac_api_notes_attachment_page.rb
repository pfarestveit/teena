require_relative '../../util/spec_helper'

class BOACApiNotesAttachmentPage

  include PageObject
  include Logging
  include Page

  div(:unauth_msg, xpath: '//*[contains(.,"Unauthorized")]')
  div(:not_found_msg, xpath: '//*[contains(.,"Attachment not found")]')

  def load_page(attachment_file)
    logger.info "Hitting download endpoint for attachment '#{attachment_file}'"
    navigate_to "#{BOACUtils.base_url}/api/notes/attachment/#{attachment_file}"
    sleep 2
  end

end
