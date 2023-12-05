class CanvasAPIPage

  include PageObject
  include Logging
  include Page

  def get_course_site_sis_section_ids(site_id)
    url = "#{Utils.canvas_base_url}/api/v1/courses/#{site_id}/sections?per_page=100"
    logger.info "Hitting #{url}"
    navigate_to url
    parse_json
    @parsed.map { |s| s['sis_section_id']&.gsub('SEC:', '') }.compact
  end

  def get_course_site_section_ccns(site_id)
    ids = get_course_site_sis_section_ids site_id
    ids.map { |i| i.split('-')[2] }
  end

  def get_external_tools(account, site = nil)
    path = site ? "courses/#{site.site_id}" : "accounts/#{account}"
    url = "#{Utils.canvas_base_url}/api/v1/#{path}/external_tools?per_page=50"
    logger.info "Hitting #{url}"
    navigate_to url
    parse_json
  end

  def tool_installed?(tool, site = nil)
    @parsed = get_external_tools(tool.account, site)
    if @parsed.find { |t| t['url'] == "#{RipleyUtils.base_url_prod}/api/lti/#{tool.path}" }
      fail "#{tool.name} is pointed at Production"
    end
    tool_installed = @parsed.find { |t| t['url'] == "#{RipleyUtils.base_url}/api/lti/#{tool.path}" }
    tool_enabled = tool_installed && tool_installed["#{tool.navigation}"] && tool_installed["#{tool.navigation}"]['enabled']
    logger.info "#{tool.name} installed and enabled is #{tool_enabled}"
    if tool_installed && !tool_enabled
      fail "#{tool.name} is installed but not enabled, sounds weird"
    end
    tool_enabled
  end

  def get_tool_id(tool, site = nil)
    tries ||= Utils.short_wait
    @parsed = get_external_tools(tool.account, site)
    tool.tool_id = (@parsed.find { |i| i['name'] == tool.name })['id']
    logger.info "#{tool.name} tool id is #{tool.tool_id}"
  rescue => e
    logger.error e.message
    sleep 5
    (tries -= 1).zero? ? fail(e.message) : retry
  end

end
