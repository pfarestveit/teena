require_relative '../../util/spec_helper'

module CanvasPeoplePage

  include PageObject
  include Logging
  include Page

  # COURSE USERS

  select_list(:enrollment_roles, name: 'enrollment_role_id')
  elements(:section_label, :div, xpath: '//div[@class="section"]')
  link(:add_people_button, id: 'addUsers')
  link(:find_person_to_add_link, xpath: '//a[text()="    Find a Person to Add  "]')
  div(:add_user_by_email, xpath: '//input[@id="peoplesearch_radio_cc_path"]/..')
  element(:add_user_by_email_label, xpath: '//label[@for="peoplesearch_radio_cc_path"]')
  div(:add_user_by_uid, xpath: '//input[@id="peoplesearch_radio_unique_id"]/..')
  element(:add_user_by_uid_label, xpath: '//label[@for="peoplesearch_radio_unique_id"]')
  div(:add_user_by_sid, xpath: '//input[@id="peoplesearch_radio_sis_user_id"]/..')
  element(:add_user_by_sid_label, xpath: '//label[@for="peoplesearch_radio_sis_user_id"]')
  link(:add_user_help_link,  text: 'How do I add users to my course site?')
  text_area(:user_list, xpath: '//textarea')
  select_list(:user_role, id: 'peoplesearch_select_role')
  elements(:user_role_option, :span, xpath: '//span[@role="option"]')
  select_list(:user_section, id: 'peoplesearch_select_section')
  button(:next_button, id: 'addpeople_next')
  div(:users_ready_to_add_msg, xpath: '//div[contains(text(),"The following users are ready to be added to the course.")]')
  li(:remove_user_success, xpath: '//*[contains(.,"User successfully removed")]')
  button(:done_button, xpath: '//button[contains(.,"Done")]')
  td(:default_email, xpath: '//th[text()="Default Email:"]/following-sibling::td')
  link(:edit_user_link, xpath: '//a[@class="edit_user_link"]')
  text_area(:user_email, id: 'user_email')
  button(:update_details_button, xpath: '//button[text()="Update Details"]')

  cell(:user_login, xpath: '//b[@class="unique_id"]')
  link(:edit_user_login_link, xpath: '//a[@class="edit_pseudonym_link"]')
  text_area(:user_login_input, id: 'pseudonym_unique_id')
  button(:update_user_login_button, xpath: '//button[text()="Update Login"]')

  text_area(:search_user_input, xpath: '//input[@placeholder="Search people"]')

  def load_users_page(course_site, canvas_base_url = nil)
    canvas_base_url ?
        navigate_to("#{canvas_base_url}/courses/#{course_site.site_id}/users") :
        navigate_to("#{Utils.canvas_base_url}/courses/#{course_site.site_id}/users")
    div_element(xpath: '//div[@data-view="users"]').when_present Utils.medium_wait
  end

  def wait_for_users(users)
    scroll_to_bottom
    users.each do |user|
      logger.debug "Waiting for user row with Canvas ID #{user.canvas_id}"
      wait_until(Utils.short_wait) { cell_element(xpath: "//tr[contains(@id,'#{user.canvas_id}')]").exists? }
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

  def visible_instruction_modes
    wait_until(Utils.medium_wait) { section_label_elements.any? }
    modes = section_label_elements.map { |el| el.text.split('(').last.gsub(')', '') }
    modes.uniq
  end

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

  def add_users(course_site, users_to_add, section = nil)
    logger.info "Users needed for the site are #{users_to_add.map &:uid}"

    # Users already on the site with the right role do not need to be added again
    users_missing = []
    load_users_page course_site
    sleep 4
    if h2_element(xpath: '//h2[text()="No people found"]').exists?
      users_missing = users_to_add
    else
      users_to_add.each do |user|
        user == users_to_add.first ? tries ||= 20 : tries ||= 1
        begin
          scroll_to_bottom
          wait_until(2) { cell_element(xpath: "//tr[contains(@id,'#{user.canvas_id}')]//td[contains(.,'#{user.role}')]").exists? }
        rescue
          (tries -= 1).zero? ? (users_missing << user) : retry
        end
      end
    end
    logger.info "Users who need to be added are #{users_missing.map &:uid}"

    # Reactivate inactivated test users and make sure all test users' emails match addresses in test data
    activate_user_and_reset_email users_missing

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

  link(:invalid_user_info_link, xpath: '//a[contains(., "Accessing bCourses Without a Calnet Account")]')

  def add_invalid_uid
    wait_for_load_and_click add_people_button_element
    wait_for_update_and_click add_user_by_uid_element
    wait_for_element_and_type_js(user_list_element, '123456')
    wait_for_update_and_click next_button_element
  end

  def click_edit_user(user)
    wait_for_update_and_click link_element(xpath: "//tr[@id='user_#{user.canvas_id}']//a[contains(@class,'al-trigger')]")
  end

  def remove_users_from_course(course_site, users)
    load_users_page course_site
    hide_canvas_footer_and_popup
    wait_for_users users
    users.each do |user|
      logger.info "Removing #{user.role} UID #{user.uid} from course site ID #{course_site.site_id}"
      click_edit_user user
      alert { wait_for_update_and_click link_element(xpath: "//tr[@id='user_#{user.canvas_id}']//a[@data-event='removeFromCourse']") }
      remove_user_success_element.when_present Utils.short_wait
    end
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

  def search_user_by_canvas_id(user)
    wait_for_element_and_type(search_user_input_element, user.canvas_id)
    sleep 1
  end

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

  def click_find_person_to_add(url=JunctionUtils.junction_base_url)
    logger.debug 'Clicking Find a Person to Add button'
    wait_for_update_and_click add_people_button_element
    wait_for_load_and_click find_person_to_add_link_element
    switch_to_canvas_iframe url
  end

  def enrollment_count_by_roles(course_site, roles, canvas_base_url = nil)
    load_users_page(course_site, canvas_base_url)
    wait_for_load_and_click enrollment_roles_element
    roles.map do |role|
      role_option = enrollment_roles_options.find { |option| option.include? role }
      count = role_option.delete("#{role} ()").to_i
      logger.debug "The count of #{role} users is currently #{count}"
      {:role => role, :count => count}
    end
  end

  def wait_for_enrollment_import(course_site, roles)
    current_count = enrollment_count_by_roles(course_site, roles)
    begin
      starting_count = current_count
      sleep Utils.medium_wait
      current_count = enrollment_count_by_roles(course_site, roles)
    end while current_count != starting_count
    current_count
  end

  elements(:user_row, :row, xpath: '//table[contains(@class, "roster")]/tbody/tr')
  elements(:student_enrollment_row, :row, :xpath => '//table[contains(@class, "roster")]/tbody/tr[contains(@class, "StudentEnrollment")]')
  elements(:waitlist_enrollment_row, :row, :xpath => '//table[contains(@class, "roster")]/tbody/tr[contains(@class, "Waitlist")]')

  def load_all_students(course_site, canvas_base_url = nil)
    counts = enrollment_count_by_roles(course_site, ['Student', 'Waitlist Student'], canvas_base_url)
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

  def get_users_with_sections(course_site, section = nil)
    load_all_students course_site
    rows = if section
             user_row_elements.select { |row| row.text.include? "#{section.course} #{section.label}" }
           else
             user_row_elements
           end
    users_with_sections = rows.map do |row|
      # Get the visible user data
      canvas_id = row.attribute('id').delete('user_')
      xpath = "//table[contains(@class, 'roster')]//tr[contains(@id,'user_#{canvas_id}')]"
      uid = cell_element(xpath: "#{xpath}//td[3]").text.gsub('inactive-', '').strip
      sid = cell_element(xpath: "#{xpath}//td[4]").text.strip
      section_codes = span_elements(xpath: "#{xpath}//td[5]/div").map &:text
      role_strings = div_elements(xpath: "#{xpath}//td[6]/div").map &:text

      # Combine a user object with a section object
      section_codes.each_with_index.map do |sec, i|
        section = course_site.sections.find { |section| "#{section.course} #{section.label}" == sec }
        role_str = role_strings[i]
        role = if %w(Teacher TA Student).include? role_str
                 role_str.downcase
               elsif ['Lead TA', 'Waitlist Student'].include? role_str
                 role_str
               else
                 logger.error "Unrecognized role '#{role_str}'"
                 nil
               end
        logger.debug "Canvas ID #{canvas_id}, UID #{uid}, role #{role}, section #{section.label}"
        {
            user: User.new(uid: uid, sis_id: sid, canvas_id: canvas_id, role: role),
            section: section
        }
      end
    end
    users_with_sections.flatten
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
    user_data.compact.sort_by { |h| [h[:uid], h[:section_id]] }
  end

  def get_students(course_site, section = nil, canvas_base_url = nil, opts = {})
    if opts[:enrollments]
      enrollments = course_site.sections.map(&:enrollments).flatten
      course_students = enrollments.map(&:user).flatten if enrollments.any?
    end

    load_all_students(course_site, canvas_base_url)
    els = student_enrollment_row_elements + waitlist_enrollment_row_elements

    rows = section ?
               (els.select { |row| row.text.include? "#{section.course} #{section.label}" }) :
               els

    students = rows.map do |row|
      canvas_id = row.attribute('id').delete('user_')
      uid = cell_element(xpath: "//table[contains(@class, 'roster')]//tr[contains(@id,'user_#{canvas_id}')]//td[3]").text.gsub('inactive-', '').strip
      logger.debug "Canvas ID #{canvas_id}, UID #{uid}"
      student = if course_students
                  course_students.find { |s| s.uid == uid }
                else
                  User.new uid: uid
                end
      student.canvas_id = canvas_id if student
      student
    end
    students.compact
  end
end
