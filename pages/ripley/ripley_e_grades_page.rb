require_relative '../../util/spec_helper'

class RipleyEGradesPage

  include PageObject
  include Logging
  include Page
  include RipleyPages

  link(:back_to_gradebook_link, text: 'Back to Gradebook')
  paragraph(:not_auth_msg, id: 'TBD "You must be a teacher in this bCourses course to export to E-Grades CSV."')
  link(:how_to_post_grades_link, id: 'TBD "How do I post grades for an assignment?"')
  link(:course_settings_button, id: 'TBD "Course Settings"')

  radio_button(:pnp_cutoff_radio, id: 'TBD')
  radio_button(:no_pnp_cutoff_radio, id: 'TBD')
  select_list(:cutoff_select, id: 'TBD')
  select_list(:sections_select, id: 'TBD')
  button(:download_current_grades, id: 'TBD "Download Current Grades"')
  button(:download_final_grades, id: 'TBD "Download Final Grades"')
  link(:bcourses_to_egrades_link, id: 'TBD "From bCourses to E-Grades"')

  def embedded_tool_path(site)
    "/courses/#{site.site_id}/external_tools/#{Utils.canvas_e_grades_export_tool}"
  end

  def hit_embedded_tool_url(site)
    navigate_to "#{Utils.canvas_base_url}#{embedded_tool_path site}"
  end

  def load_embedded_tool(site)
    load_tool_in_canvas embedded_tool_path(site)
  end

  def load_standalone_tool(site)
    navigate_to "#{RipleyUtils.base_url} TBD #{site.site_id}"
  end

  def click_course_settings_button(site)
    wait_for_load_and_click course_settings_button_element
    wait_until(Utils.medium_wait) { current_url.include? "#{Utils.canvas_base_url}/courses/#{site.site_id}/settings" }
  end

  def set_cutoff(cutoff)
    if cutoff
      logger.info "Setting P/NP cutoff to '#{cutoff}'"
      wait_for_element_and_select(cutoff_select_element, cutoff)
    else
      logger.info 'Setting no P/NP cutoff'
      wait_for_update_and_click no_pnp_cutoff_radio_element
    end
  end

  def choose_section(section)
    # Parenthetical in section labels isn't shown on e-grades tool
    label = section.label.include?('(') ? section.label.split(' (').first : section.label
    section_name = "#{section.course} #{label}"
    Utils.prepare_download_dir
    wait_for_element_and_select(sections_select_element, section_name)
  end

  def parse_grades_csv(file_path)
    wait_until(Utils.long_wait) { Dir[file_path].any? }
    file = Dir[file_path].first
    sleep 2
    CSV.read(file, headers: true, header_converters: :symbol)
  end

  def grades_to_hash(csv)
    csv.map { |r| r.to_hash }
  end

  def download_current_grades(site, section, cutoff = nil)
    logger.info "Downloading current grades for #{site.course.code} #{section.label}"
    Utils.prepare_download_dir
    load_embedded_tool site
    click_continue
    set_cutoff cutoff
    choose_section section if site.course.sections.length > 1
    wait_for_load_and_click download_current_grades_element
    file_path = "#{Utils.download_dir}/egrades-current-#{section.id}-#{site.course.term.gsub(' ', '-')}-*.csv"
    csv = parse_grades_csv file_path
    csv.map { |r| r.to_hash }
  end

  def download_final_grades(site, section, cutoff = nil)
    logger.info "Downloading final grades for #{site.course.code} #{section.label}"
    Utils.prepare_download_dir
    load_embedded_tool site
    click_continue
    set_cutoff cutoff
    choose_section section if site.course.sections.length > 1
    wait_for_load_and_click download_final_grades_element
    file_path = "#{Utils.download_dir}/egrades-final-#{section.id}-#{site.course.term.gsub(' ', '-')}-*.csv"
    csv = parse_grades_csv file_path
    csv.map { |r| r.to_hash }
  end
end
