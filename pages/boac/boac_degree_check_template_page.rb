class BOACDegreeCheckTemplatePage

  include PageObject
  include Page
  include BOACPages
  include Logging

  def template_heading(template)
    h1_element(xpath: "//h1[text()=\"#{template.name}\"]")
  end

end
