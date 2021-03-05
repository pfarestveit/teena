class BOACDegreeCheckMgmtPage

  include PageObject
  include Logging
  include Page
  include BOACPages

  link(:create_degree_check_link, id: 'degree-check-create-link')

  def degree_check_row_xpath(degree_check)
    "//tr[contains(., \"#{degree_check.name}\")]"
  end

  def degree_check_link(degree_check)
    link_element(xpath: "#{degree_check_row_xpath degree_check}//a")
  end

  def degree_check_create_date(degree_check)
    el = div_element(xpath: "#{degree_check_row_xpath degree_check}/td[@data-label='Created']/div")
    str = el.text.strip
    Time.strptime(str, '%B %-d, %Y')
  end

  def degree_check_print_button(degree_check)
    button_element(xpath: "#{degree_check_row_xpath degree_check}//button[text()=' Print ']")
  end

  def degree_check_rename_button(degree_check)
    button_element(xpath: "#{degree_check_row_xpath degree_check}//button[text()=' Rename ']")
  end

  def degree_check_copy_button(degree_check)
    button_element(xpath: "#{degree_check_row_xpath degree_check}//button[text()=' Copy ']")
  end

  def degree_check_delete_button(degree_check)
    button_element(xpath: "#{degree_check_row_xpath degree_check}//button[text()=' Delete ']")
  end

end
