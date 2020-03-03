module BOACAdmitPages

  include Logging
  include PageObject
  include Page
  include BOACPages

  def data_update_date_heading(date_string)
    h2_element(xpath: "//h2[text()='Note: admit data was last updated on #{date_string}']")
  end

end
