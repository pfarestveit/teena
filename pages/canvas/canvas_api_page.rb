class CanvasAPIPage

  include PageObject
  include Logging
  include Page

  def get_course_site_sis_section_ids(site)
    logger.info "Hitting #{Utils.canvas_base_url}/api/v1/courses/#{site.site_id}/sections"
    navigate_to "#{Utils.canvas_base_url}/api/v1/courses/#{site.site_id}/sections"
    parse_json
    @parsed.map { |s| s['sis_section_id'].gsub('SEC:', '') }
  end

  def get_tool_id(tool)
    logger.info "Getting #{tool.name} id from #{Utils.canvas_base_url}/api/v1/accounts/#{tool.account}/external_tools"
    navigate_to "#{Utils.canvas_base_url}/api/v1/accounts/#{tool.account}/external_tools?per_page=50"
    parse_json
    tool.tool_id = (@parsed.find { |i| i['name'] == tool.name })['id']
    logger.info "Tool id is #{tool.tool_id}"
  end

end
