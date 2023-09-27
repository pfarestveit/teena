class CanvasAPIPage

  include PageObject
  include Logging
  include Page

  def get_course_site_sis_section_ids(site_id)
    url = "#{Utils.canvas_base_url}/api/v1/courses/#{site_id}/sections?per_page=100"
    logger.info "Hitting #{url}"
    navigate_to url
    parse_json
    @parsed.map { |s| s['sis_section_id'].gsub('SEC:', '') }
  end

  def get_course_site_section_ccns(site_id)
    ids = get_course_site_sis_section_ids site_id
    ids.map { |i| i.split('-')[2] }
  end

  def get_tool_id(tool)
    tries ||= Utils.short_wait
    logger.info "Getting #{tool.name} id from #{Utils.canvas_base_url}/api/v1/accounts/#{tool.account}/external_tools"
    navigate_to "#{Utils.canvas_base_url}/api/v1/accounts/#{tool.account}/external_tools?per_page=50"
    parse_json
    tool.tool_id = (@parsed.find { |i| i['name'] == tool.name })['id']
    logger.info "Tool id is #{tool.tool_id}"
  rescue => e
    logger.error e.message
    sleep 5
    (tries -= 1).zero? ? fail(e.message) : retry
  end

end
