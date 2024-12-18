require_relative '../../util/spec_helper'

module CanvasPeoplePage

  include PageObject
  include Logging
  include Page

  def load_users_page(course_site)
    navigate_to("#{Utils.canvas_base_url}/courses/#{course_site.site_id}/users")
    div_element(xpath: '//div[@data-view="users"]').when_present Utils.medium_wait
  end

  # SEARCH

  text_area(:search_user_input, xpath: '//input[@placeholder="Search people"]')
  select_list(:enrollment_roles, name: 'enrollment_role_id')
  elements(:section_label, :div, xpath: '//div[@class="section"]')

  def search_user_by_canvas_id(user)
    wait_for_element_and_type(search_user_input_element, user.canvas_id)
    sleep 1
  end

  def search_user_by_uid(user)
    wait_for_element_and_type(search_user_input_element, user.uid)
    sleep 1
  end

  # ADD USER - Canvas

  link(:add_people_button, id: 'addUsers')
  link(:add_user_help_link, text: 'How do I add users to my course site?')
  div(:add_user_by_email, xpath: '//input[@id="peoplesearch_radio_cc_path"]/..')
  element(:add_user_by_email_label, xpath: '//label[@for="peoplesearch_radio_cc_path"]')
  div(:add_user_by_uid, xpath: '//input[@id="peoplesearch_radio_unique_id"]/..')
  element(:add_user_by_uid_label, xpath: '//label[@for="peoplesearch_radio_unique_id"]')
  div(:add_user_by_sid, xpath: '//input[@id="peoplesearch_radio_sis_user_id"]/..')
  element(:add_user_by_sid_label, xpath: '//label[@for="peoplesearch_radio_sis_user_id"]')
  text_area(:user_list, xpath: '//textarea')
  select_list(:user_role, id: 'peoplesearch_select_role')
  elements(:user_role_option, :span, xpath: '//span[@role="option"]')
  select_list(:user_section, id: 'peoplesearch_select_section')
  button(:next_button, id: 'addpeople_next')
  div(:users_ready_to_add_msg, xpath: '//div[contains(text(),"The following users are ready to be added to the course.")]')
  link(:invalid_user_info_link, xpath: '//a[contains(., "Accessing bCourses Without a Calnet Account")]')

  def click_add_people
    sleep 2
    wait_for_load_and_click add_people_button_element
    find_person_to_add_link_element.when_visible Utils.short_wait
  end

  def user_role_options
    wait_for_update_and_click user_role_element
    user_role_option_elements.map &:text
  end

  def click_add_by_email
    wait_for_update_and_click add_user_by_email_element
  end

  def click_add_by_uid
    wait_for_update_and_click add_user_by_uid_element
  end

  def click_add_by_sid
    wait_for_update_and_click add_user_by_sid_element
  end

  def add_user_placeholder
    user_list_element.attribute('placeholder')
  end

  def add_users(course_site, users_to_add)
    logger.info "Users needed for the site are #{users_to_add.map &:uid}"

    users_missing = []
    load_users_page course_site
    wait_until(Utils.short_wait) { no_users_msg? || user_row_elements.any? }
    if no_users_msg?
      users_missing = users_to_add
    else
      users_to_add.each do |user|
        search_user_by_canvas_id user
        user_row(user).when_present 1
      rescue
        users_missing << user
      end
    end
    logger.info "Users who need to be added are #{users_missing.map &:uid}"

    activate_user_and_reset_email users_missing

    canvas_api = CanvasAPIPage.new @driver
    canvas_api.get_tool_id RipleyTool::ADD_USER
    add_user_page = RipleyAddUserPage.new @driver
    add_user_page.load_embedded_tool course_site
    users_missing.each do |user|
      logger.info "Adding UID #{user.uid} with role #{user.role}"
      add_user_page.search(user.uid, 'CalNet UID')
      add_user_page.add_user_by_uid user
    end
  end

  def add_users_by_section(course_site, users)
    load_users_page course_site
    canvas_api = CanvasAPIPage.new @driver
    canvas_api.get_tool_id RipleyTool::ADD_USER
    add_user_page = RipleyAddUserPage.new @driver
    add_user_page.load_embedded_tool course_site
    users.each do |user|
      user.sections.each do |section|
        logger.info "Adding UID #{user.uid} to section #{section.sis_id}"
        add_user_page.search(user.uid, 'CalNet UID')
        add_user_page.add_user_by_uid(user, section)
      end
    end
  end

  def wait_for_added_user(user)
    retries ||= 10
    begin
      scroll_to_bottom
      wait_until(4) { cell_element(xpath: "//tr[contains(@id,'#{user.canvas_id}')]").exists? }
    rescue => e
      (retries -= 1).zero? ? fail(e.message) : retry
    end
  end

  def add_invalid_uid
    wait_for_load_and_click add_people_button_element
    wait_for_update_and_click add_user_by_uid_element
    wait_for_element_and_type_js(user_list_element, '123456')
    wait_for_update_and_click next_button_element
  end

  # ADD USER - LTI

  link(:find_person_to_add_link, xpath: '//a[contains(., "Find a Person to Add")]')

  def click_find_person_to_add(url = RipleyUtils.base_url)
    logger.debug 'Clicking Find a Person to Add button'
    wait_for_update_and_click add_people_button_element
    wait_for_load_and_click find_person_to_add_link_element
    switch_to_canvas_iframe url
  end

  # EDIT / REMOVE USER (USERS VIEW)

  button(:done_button, xpath: '//button[contains(.,"Done")]')
  li(:remove_user_success, xpath: '//*[contains(.,"User successfully removed")]')

  def click_edit_user(user)
    wait_for_update_and_click link_element(xpath: "//tr[@id='user_#{user.canvas_id}']//a[contains(@class,'al-trigger')]")
  end

  def remove_user_from_course(course_site, user)
    logger.info "Removing #{user.role} UID #{user.uid} from course site ID #{course_site.site_id}"
    click_edit_user user
    alert { wait_for_update_and_click link_element(xpath: "//tr[@id='user_#{user.canvas_id}']//a[@data-event='removeFromCourse']") }
    remove_user_success_element.when_present Utils.short_wait
  end

  def remove_users_from_course(course_site, users)
    load_users_page course_site
    hide_canvas_footer_and_popup
    wait_for_users users
    users.each { |user| remove_user_from_course(course_site, user) }
  end

  def remove_user_section(course_site, user, section)
    load_users_page course_site
    hide_canvas_footer_and_popup
    wait_for_users [user]
    click_edit_user user
    wait_for_update_and_click link_element(xpath: "//tr[@id='user_#{user.canvas_id}']//a[@data-event='editSections']")
    wait_for_update_and_click link_element(xpath: "//a[@title='Remove user from #{section.sis_id}']")
    wait_for_update_and_click button_element(xpath: '//button[contains(., "Update")]')
    sleep 2
    user.sections.delete section
  end

  # EDIT USER (SINGLE USER VIEW)

  link(:edit_user_link, xpath: '//a[@class="edit_user_link"]')
  button(:update_details_button, xpath: '//button[text()="Update Details"]')

  td(:default_email, xpath: '//th[text()="Default Email:"]/following-sibling::td')
  text_area(:user_email, id: 'user_email')

  cell(:user_login, xpath: '//b[@class="unique_id"]')
  link(:edit_user_login_link, xpath: '//a[@class="edit_pseudonym_link"]')
  text_area(:user_login_input, id: 'pseudonym_unique_id')
  button(:update_user_login_button, xpath: '//button[text()="Update Login"]')

  def activate_user_and_reset_email(test_users)
    test_users.each do |user|
      navigate_to "#{Utils.canvas_base_url}/users/#{user.canvas_id}"
      default_email_element.when_present Utils.short_wait
      if default_email == user.email
        logger.debug "Test user '#{user.uid}' already has an updated default email"
      else
        logger.debug "Resetting test user #{user.uid}'s email to #{user.email}"
        wait_for_load_and_click edit_user_link_element
        wait_for_element_and_type(user_email_element, user.email)
        wait_for_update_and_click update_details_button_element
        default_email_element.when_present Utils.short_wait
      end
      user_login_element.when_visible Utils.short_wait
      if user_login.include? 'inactive'
        logger.info "Reactivating UID #{user.uid}"
        wait_for_update_and_click edit_user_login_link_element
        wait_for_element_and_type(user_login_input_element, user.uid)
        wait_for_update_and_click update_user_login_button_element
        wait_until(Utils.short_wait) { user_login == "#{user.uid}" }
      end
    end
  end

  # USERS TABLE - Specific users

  def user_row(user)
    cell_element(xpath: "//tr[contains(@id,'#{user.canvas_id}')]//td[contains(.,'#{user.role}')]")
  end

  def wait_for_users(users)
    scroll_to_bottom
    users.each do |user|
      logger.debug "Waiting for user row with Canvas ID #{user.canvas_id}"
      wait_until(Utils.short_wait) { cell_element(xpath: "//tr[contains(@id,'#{user.canvas_id}')]").exists? }
    end
  end

  def roster_user?(canvas_id)
    cell_element(xpath: "//tr[contains(@id,'#{canvas_id}')]/td[3]").exists?
  end

  def roster_user_uid(canvas_id)
    cell_element(xpath: "//tr[contains(@id,'#{canvas_id}')]/td[3]").text
  end

  def roster_user_sections(canvas_id)
    cell_element(xpath: "//tr[contains(@id,'#{canvas_id}')]/td[5]").text
  end

  def roster_user_roles(canvas_id)
    cell_element(xpath: "//tr[contains(@id,'#{canvas_id}')]/td[6]").text
  end

  def roster_user_last_activity(uid)
    path = "//tr[contains(.,'#{uid}')]/td[7]"
    (cell = cell_element(xpath: path)).when_visible Utils.short_wait
    date_str = (div = div_element(xpath: "#{path}/div")).exists? ? div.text : cell.text
    date_str unless date_str.empty?
  end

  # USERS TABLE - All users

  h2(:no_users_msg, xpath: '//h2[text()="No people found"]')
  elements(:user_row, :row, xpath: '//tr[starts-with(@id, "user_")]')
  elements(:student_enrollment_row, :row, :xpath => '//table[contains(@class, "roster")]/tbody/tr[contains(@class, "StudentEnrollment")]')
  elements(:waitlist_enrollment_row, :row, :xpath => '//table[contains(@class, "roster")]/tbody/tr[contains(@class, "Waitlist")]')

  def visible_instruction_modes
    wait_until(Utils.medium_wait) { section_label_elements.any? }
    modes = section_label_elements.map { |el| el.text.split('(').last.gsub(')', '') }
    modes.uniq
  end

  def user_count_per_role(course_site, roles = [])
    load_users_page course_site
    wait_for_load_and_click enrollment_roles_element
    roles = roles.any? ? roles : CourseSiteRole::ROLES
    roles.map do |role|
      option = enrollment_roles_options.find { |o| o.start_with? role.name }
      parts = option&.split('(')
      {
        role: role.name,
        count: (option ? parts.last.delete(')').to_i : 0)
      }
    end
  end

  def expected_user_count_per_role(users)
    CourseSiteRole::ROLES.map do |role|
      {
        role: role.name,
        count: (users.select { |u| u.role == role.name }.length)
      }
    end
  end

  def wait_for_enrollment_import(course_site, expected_count_per_role = nil)
    current_count = user_count_per_role(course_site)
    unless expected_count_per_role && (current_count == expected_count_per_role)
      begin
        starting_count = current_count
        sleep Utils.short_wait
        current_count = user_count_per_role course_site
      end while current_count != starting_count
    end
    current_count
  end

  def load_all_students(course_site)
    counts = user_count_per_role(course_site, [CourseSiteRole::STUDENT, CourseSiteRole::WAITLIST_STUDENT])
    logger.debug "User count per role: #{counts}"
    total_count = counts[0][:count] + counts[1][:count]
    logger.debug "Trying to load #{total_count} students and wait list students"
    wait_until(Utils.short_wait) { user_row_elements.any? }
    scroll_to_bottom
    if user_row_elements.length >= total_count
      logger.debug 'All users are currently visible'
    else
      begin
        tries ||= total_count.to_i / 45
        new_count = user_row_elements.length
        logger.debug "There are now #{new_count} user rows"
        scroll_to_bottom
        wait_until(Utils.short_wait) { user_row_elements.length > new_count }
        wait_until(Utils.click_wait) { (student_enrollment_row_elements.length + waitlist_enrollment_row_elements.length) >= total_count }
      rescue
        if (tries -= 1).zero? || (user_row_elements.length == new_count)
          logger.error "Site role dropdown says #{total_count} students but got #{student_enrollment_row_elements.length + waitlist_enrollment_row_elements.length} rows"
        else
          retry
        end
      end
    end
    total_count
  end

  def get_users_with_sections(course_site, opts = {})
    load_all_students course_site

    section = opts[:section]
    rows = if section
             user_row_elements.select { |row| row.text.include? "#{section.course} #{section.label}" }
           else
             user_row_elements
           end

    enrolled_students = if opts[:enrollments]
                          enrollments = course_site.sections.map(&:enrollments).flatten
                          enrollments.map(&:user).flatten
                        else
                          []
                        end

    site_roles = CourseSiteRole::ROLES.map &:name
    primary_roles = %w(Teacher TA Student)
    other_roles = site_roles - primary_roles

    users_with_sections = rows.map do |row|
      canvas_id = row.attribute('id').delete('user_')
      xpath = "//tr[contains(@id,'user_#{canvas_id}')]"
      uid = cell_element(xpath: "#{xpath}//td[3]").text.gsub('inactive-', '').strip
      sid = cell_element(xpath: "#{xpath}//td[4]").text.strip
      section_codes = span_elements(xpath: "#{xpath}//td[5]/div").map &:text
      role_strings = div_elements(xpath: "#{xpath}//td[6]/div").map &:text
      section_codes = section_codes.select { |c| c.include? "#{section.course} #{section.label}" } if section
      section_codes.each_with_index.map do |section_code, i|
        user = enrolled_students.find { |stud| stud.uid == uid }.dup if enrolled_students.any?
        user ||= User.new uid: uid
        user.canvas_id = canvas_id
        user.sis_id = sid
        if course_site.sections&.any?
          sec = course_site.sections.find { |s| "#{s.course} #{s.label}" == section_code }
        end
        role_str = role_strings[i].strip
        role = if primary_roles.include? role_str
                 role_str.downcase
               elsif other_roles.include? role_str
                 role_str
               else
                 logger.error "Unrecognized role '#{role_str}'"
                 nil
               end
        user.role = role
        logger.debug "Canvas ID '#{canvas_id}', UID '#{uid}', role '#{role}', section '#{sec&.label}'"
        {
          user: user,
          section: sec
        }
      end
    end
    users_with_sections.flatten.compact.uniq
  end

  def get_students(course_site, opts = {})
    students = get_users_with_sections(course_site, opts).map do |h|
      h[:user] if ['student', 'Waitlist Student'].include? h[:user].role
    end
    students.compact
  end

  def visible_user_section_data(course_site)
    users_with_sections = get_users_with_sections course_site
    user_data = users_with_sections.map do |h|
      {
        uid: h[:user].uid,
        section_id: h[:section].id,
        role: h[:user].role&.downcase
      }
    end
    user_data.compact.uniq.sort_by { |h| [h[:uid], h[:section_id]] }
  end
end
