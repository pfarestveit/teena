class BOACDegreeCheckHistoryPage

  include PageObject
  include Logging
  include Page
  include BOACPages

  link(:create_new_degree_link, id: 'create-new-degree')

  def visible_degree_names
    link_elements(xpath: '//a[contains(@href, "/student/degree")]').map &:text
  end

  def visible_degree_update_dates
    div_elements(xpath: '//td[@data-label="Last Updated"]/div').map { |el| el.text.strip }
  end

  def visible_degree_updated_by(degree)
    div_element(xpath: "//a[@id='degree-check-#{degree.id}-link']/ancestor::tr/td[3]//div").text.strip
  end

  def template_updated_alert(degree)
    div_element(xpath: "//tr[contains(., \"#{degree.name}\")]/td[contains(., 'Revisions to the original degree template have been made since the creation of this degree check.')]")
  end

end
