require_relative '../../util/spec_helper'

class RipleyCreateCourseSitePage < RipleySiteCreationPage

  include PageObject
  include Logging
  include Page
  include RipleyPages
  include RipleyCourseSectionsModule

  div(:need_help, xpath: '//div[contains(text(), "Need help deciding which official sections to select?")]')
  link(:instr_mode_link, id: 'link-to-httpsberkeleyservicenowcomkb_viewdosysparm_articleKB0010732instructionmode')

  radio_button(:switch_to_instructor, id: 'radio-btn-mode-act-as')
  button(:as_instructor_button, id: 'sections-by-uid-button')
  text_area(:instructor_uid, id: 'instructor-uid')
  radio_button(:switch_to_ccn, id: 'radio-btn-mode-section-id')
  button(:review_ccns_button, id: 'sections-by-ids-button')
  text_area(:ccn_list, id: 'page-create-course-site-section-id-list')

  button(:next_button, id: 'page-create-course-site-continue')
  button(:cancel_button, id: 'page-create-course-site-cancel')

  text_field(:site_name_input, id: 'course-site-name')
  text_field(:site_abbreviation, id: 'course-site-abbreviation')
  div(:site_name_error, xpath: '//div[text()="Please provide site name."]')
  div(:site_abbreviation_error, xpath: '//div[text()="Please provide site abbreviation."]')

  button(:create_site_button, id: 'create-course-site-button')
  button(:go_back_button, id: 'go-back-button')

  def term_button(term)
    button_element(xpath: "//button[contains(., '#{term.name}')]")
  end

  def choose_term(course)
    wait_until(Utils.medium_wait) do
      term_button(course.term).exists? || h2_element(id: 'official-sections-heading').exists?
    end
    if term_button(course.term).exists?
      if term_button(course.term).attribute('class').include?('v-btn--active')
        logger.debug "Term #{course.term.name} is already selected"
      else
        wait_for_update_and_click term_button(course.term)
      end
    else
      logger.warn 'Only one term exists'
    end
  end

  def search_for_course(course_site)
    logger.debug "Searching for #{course_site.course.code} in #{course_site.course.term.name}"
    if course_site.create_site_workflow == 'uid'
      teacher = course_site.course.teachers.first
      logger.debug "Searching by instructor UID #{teacher.uid}"
      switch_to_instructor_element.when_present Utils.short_wait
      select_switch_to_instructor
      wait_for_textbox_and_type(instructor_uid_element, teacher.uid)
      wait_for_update_and_click as_instructor_button_element
      choose_term course_site.course

    elsif course_site.create_site_workflow == 'ccn'
      logger.debug 'Searching by CCN list'
      switch_to_ccn_element.when_present Utils.short_wait
      select_switch_to_ccn
      choose_term course_site.course
      sleep 1
      ccn_list = course_site.sections.map &:id
      logger.debug "CCN list is '#{ccn_list}'"
      wait_for_textbox_and_type(ccn_list_element, ccn_list.join(', '))
      wait_for_update_and_click review_ccns_button_element

    else
      logger.debug 'Searching as the instructor'
      choose_term course_site.course
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
      instructors_and_roles: section_instructors(section_id)
    }
  end

  def select_sections(sections)
    sections.sort_by! &:id
    sections.each do |section|
      if section_checkbox(section.id).selected?
        logger.debug "Section ID #{section.id} is already selected"
      else
        logger.debug "Selecting section ID #{section.id}"
        wait_for_update_and_click section_checkbox(section.id)
      end
    end
  end

  def section_checkbox(section_id)
    checkbox_element(id: "template-canvas-manage-sections-checkbox-#{section_id}")
  end

  def section_course_code(section_id)
    el = cell_element(xpath: "//td[contains(@id, '#{section_id}-course')]")
    el.when_present Utils.short_wait
    el.text.strip
  end

  def section_label(section_id)
    el = cell_element(xpath: "//td[contains(@id, '#{section_id}-name')]")
    el.when_present Utils.short_wait
    el.text.strip
  end

  def section_schedules(section_id)
    els = div_elements(xpath: "//td[contains(@id, '#{section_id}-schedule')]/*")
    wait_until(Utils.short_wait) { els.any? }
    els.map { |el| el.text.strip.upcase }.delete_if &:empty?
  end

  def section_locations(section_id)
    els = div_elements(xpath: "//td[contains(@id, '#{section_id}-location')]/*")
    wait_until(Utils.short_wait) { els.any? }
    els.map { |el| el.text.strip }.delete_if &:empty?
  end

  def section_instructors(section_id)
    els = div_elements(xpath: "//td[contains(@id, '#{section_id}-instructors')]/*")
    wait_until(Utils.short_wait) { els.any? }
    els.map { |el| el.text.strip }.delete_if &:empty?
  end

  elements(:section_id, :cell, xpath: '//td[@class="td-section-id"]')

  def all_section_ids
    wait_until(3) { section_id_elements.any? }
    sleep 1
    logger.debug "There are #{section_id_elements.length} section IDs"
    section_id_elements.map &:text
  end

  def course_section_ids(course)
    identifier = "#{course.code.downcase.split.join('-')}-#{course.term.code}"
    cell_elements(xpath: "//div[@id='sections-course-#{identifier}']//td[@class='td-section-id']").map &:text
  end

  def click_next
    wait_until(Utils.short_wait) { !next_button_element.attribute('disabled') }
    wait_for_update_and_click next_button_element
    site_name_input_element.when_visible Utils.medium_wait
  end

  def enter_site_name(string)
    wait_for_textbox_and_type(site_name_input_element, string)
  end

  def enter_site_abbreviation(string)
    wait_for_textbox_and_type(site_abbreviation_element, string)
  end

  def enter_site_titles(course)
    site_abbreviation = "QA bCourses Test #{Utils.get_test_id}"
    enter_site_name "#{site_abbreviation} - #{course.code}"
    enter_site_abbreviation site_abbreviation
    site_abbreviation
  end

  def click_create_site
    wait_for_update_and_click create_site_button_element
  end

  def click_go_back
    logger.debug 'Clicking go-back button'
    wait_for_update_and_click go_back_button_element
  end

  def wait_for_standalone_site_id(course_site, splash_page)
    wait_for_progress_bar
    course_site.create_site_workflow = 'self'
    tries = Utils.short_wait
    teacher = course_site.course.teachers.first
    begin
      splash_page.clear_cache
      splash_page.dev_auth teacher.uid
      load_standalone_tool
      click_create_course_site
      search_for_course course_site
      expand_available_course_sections(course_site.course.code, course_site.sections.first)
      link = link_element(xpath: "TBD #{course_site.course.title}")
      course_site.site_id = link.attribute('href').gsub("#{Utils.canvas_base_url}/courses/", '')
      logger.info "Course site ID is #{course_site.site_id}"
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

  def provision_course_site(course_site)
    load_embedded_tool course_site.course.teachers.first
    click_create_course_site
    search_for_course course_site
    expand_available_course_sections(course_site.course, course_site.sections.first)
    if course_site.sections == course_site.course.sections
      wait_for_update_and_click available_sections_select_all(course_site.course)
    else
      select_sections course_site.sections
    end
    click_next
    course_site.course.title = enter_site_titles course_site.course
    click_create_site
    wait_for_site_id course_site
  end
end
