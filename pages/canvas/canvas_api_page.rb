class CanvasAPIPage

  include PageObject
  include Logging
  include Page

  def get_course_site_sis_section_ids(site)
    navigate_to "#{Utils.canvas_base_url}/api/v1/courses/#{site.site_id}/sections"
    parse_json
    @parsed.map { |s| s['sis_section_id'].gsub('SEC:', '') }
  end

end
