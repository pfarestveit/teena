require_relative '../../util/spec_helper'

class BOACApiNotesPage

  include PageObject
  include Logging
  include Page

  div(:not_found_msg, xpath: '//*[contains(., "The requested resource could not be found.")]')
  div(:attach_not_found_msg, xpath: '//*[text()="Sorry, attachment not available."]')

  def load_attachment_page(attachment_file)
    logger.info "Hitting download endpoint for attachment '#{attachment_file}'"
    navigate_to "#{BOACUtils.base_url}/api/notes/attachment/#{attachment_file}"
    sleep 2
  end

  def load_download_page(student)
    navigate_to "#{BOACUtils.api_base_url}/api/notes/download_for_sid/#{student.sis_id}"
  end

end
