require_relative '../../util/spec_helper'

class RipleyCreateCourseSitePage < RipleySiteCreationPage

  include PageObject
  include Logging
  include Page
  include RipleyPages
  include RipleyCourseSectionsModule

  button(:need_help, id: 'TBD "Need help deciding which official sections to select"')
  div(:help, id: 'TBD')
  link(:instr_mode_link, id: 'TBD "Learn more about instruction modes in bCourses."')

  button(:switch_mode, id: 'TBD')
  button(:switch_to_instructor, id: 'TBD "Switch to acting as instructor"')
  button(:as_instructor_button, id: 'TBD')
  text_area(:instructor_uid, id: 'TBD')
  button(:switch_to_ccn, id: 'TBD "Switch to CCN input"')
  button(:review_ccns_button, id: 'TBD "Review matching CCNs"')
  text_area(:ccn_list, id: 'TBD')

  button(:next_button, id: 'TBD "Next"')

  text_field(:site_name_input, id: 'TBD')
  text_field(:site_abbreviation, id: 'TBD')
  div(:site_name_error, id: 'TBD "Please fill out a site name."')
  div(:site_abbreviation_error, id: 'TBD "Please fill out a site abbreviation."')

  button(:create_site_button, id: 'TBD "Create Course Site"')
  button(:go_back_button, id: 'TBD "Go Back"')

  def choose_term(course)
    button_element(id: "TBD #{course.term}").when_visible Utils.long_wait
    wait_for_update_and_click button_element(id: "TBD #{course.term}")
  end

  def search_for_course(site)
    logger.debug "Searching for #{site.course.code} in #{site.course.term.name}"
    if site.course.create_site_workflow == 'uid'
      teacher = site.course.teachers.first
      logger.debug "Searching by instructor UID #{teacher.uid}"
      switch_mode unless switch_to_ccn?
      wait_for_element_and_type(instructor_uid_element, teacher.uid)
      wait_for_update_and_click as_instructor_button_element
      choose_term site.course

    elsif site.create_site_workflow == 'ccn'
      logger.debug 'Searching by CCN list'
      switch_mode unless switch_to_instructor?
      choose_term site.course
      sleep 1
      ccn_list = site.sections.map &:id
      logger.debug "CCN list is '#{ccn_list}'"
      wait_for_element_and_type(ccn_list_element, ccn_list.join(', '))
      wait_for_update_and_click review_ccns_button_element

    else
      logger.debug 'Searching as the instructor'
      choose_term site.course
    end
  end

  def click_need_help
    wait_for_update_and_click need_help_element
  end

  def section_data(section_id)
    {
      code: section_course_code(section_id),
      label: section_label(section_id),
      id: section_id,
      schedules: section_schedules(section_id),
      locations: section_locations(section_id),
      instructors: section_instructors(section_id)
    }
  end

  def select_sections(sections)
    sections.each do |section|
      logger.debug "Selecting section ID #{section.id}"
      section_checkbox(section.id).when_present Utils.short_wait
      js_click section_checkbox(section.id) unless section_checkbox(section.id).selected?
    end
  end

  def section_cbx_xpath(section_id)
    "TBD #{section_id}"
  end

  def section_checkbox(section_id)
    checkbox_element(xpath: section_cbx_xpath(section_id))
  end

  def section_course_code(section_id)
    div_element(xpath: "#{section_cbx_xpath(section_id)}/ TBD").text.strip
  end

  def section_label(section_id)
    label_element(xpath: "#{section_cbx_xpath(section_id)}/ TBD").text.strip
  end

  def section_schedules(section_id)
    (el = div_element(xpath: "#{section_cbx_xpath(section_id)} TBD")).exists? ? el.text : ''
  end

  def section_locations(section_id)
    (el = div_element(xpath: "#{section_cbx_xpath(section_id)} TBD")).exists? ? el.text : ''
  end

  def section_instructors(section_id)
    (el = div_element(xpath: "#{section_cbx_xpath(section_id)} TBD")).exists? ? el.text : ''
  end

  def course_section_ids(course)
    cell_elements(xpath: "TBD #{course.code}: #{course.title}").map &:text
  end

  def click_next
    wait_until(Utils.short_wait) { !next_button_element.attribute('disabled') }
    wait_for_update_and_click_js next_button_element
    site_name_input_element.when_visible Utils.medium_wait
  end

  def enter_site_titles(course)
    site_abbreviation = "QA bCourses Test #{Utils.get_test_id}"
    wait_for_element_and_type(site_name_input_element, "#{site_abbreviation} - #{course.code}")
    wait_for_element_and_type(site_abbreviation_element, site_abbreviation)
    site_abbreviation
  end

  def click_create_site
    wait_for_update_and_click create_site_button_element
  end

  def click_go_back
    logger.debug 'Clicking go-back button'
    wait_for_update_and_click go_back_button_element
  end

  def wait_for_standalone_site_id(site, splash_page)
    wait_for_progress_bar
    site.create_site_workflow = 'self'
    tries = Utils.short_wait
    teacher = site.course.teachers.first
    begin
      splash_page.clear_cache
      splash_page.dev_auth teacher.uid
      load_standalone_tool
      click_create_course_site
      search_for_course site
      expand_available_sections site.course.code
      link = link_element(xpath: "TBD #{site.course.title}")
      site.site_id = link.attribute('href').gsub("#{Utils.canvas_base_url}/courses/", '')
      logger.info "Course site ID is #{site.site_id}"
    rescue => e
      Utils.log_error e
      logger.warn "UID #{teacher.uid} is not yet associated with the site"
      if (tries -= 1).zero?
        fail
      else
        sleep Utils.short_wait
        retry
      end
    end
  end

  def provision_course_site(site, opts={})
    opts[:standalone] ? load_standalone_tool : load_embedded_tool(site.course.teachers.first)
    click_create_course_site
    site.course.create_site_workflow = 'ccn' if opts[:admin]
    search_for_course site
    expand_available_sections site.course.code
    select_sections site.sections
    click_next
    site.course.title = enter_site_titles site.course
    click_create_site
    wait_for_site_id(site) unless opts[:standalone]
  end
end
