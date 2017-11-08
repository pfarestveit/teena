require_relative '../../util/spec_helper'

module Page

  module BOACPages

    class StudentPage

      include PageObject
      include Logging
      include Page
      include BOACPages

      h1(:name, xpath: '//h1[@data-ng-bind="student.sisProfile.primaryName"]')
      div(:phone, xpath: '//div[@data-ng-bind="student.sisProfile.phoneNumber"]')
      link(:email, xpath: '//a[@data-ng-bind="student.sisProfile.emailAddress"]')
      div(:cumulative_units, xpath: '//div[@data-ng-bind="student.sisProfile.cumulativeUnits"]')
      div(:cumulative_gpa, xpath: '//div[contains(@data-ng-bind,"student.sisProfile.cumulativeGPA")]')
      h3(:plan, xpath: '//h3[@data-ng-bind="student.sisProfile.plan.description"]')
      h3(:level, xpath: '//h3[@data-ng-bind="student.sisProfile.level.description"]')

      cell(:writing_reqt, xpath: '//td[text()="Entry Level Writing"]/following-sibling::td')
      cell(:history_reqt, xpath: '//td[text()="American History"]/following-sibling::td')
      cell(:institutions_reqt, xpath: '//td[text()="American Institutions"]/following-sibling::td')
      cell(:cultures_reqt, xpath: '//td[text()="American Cultures"]/following-sibling::td')
      cell(:language_reqt, xpath: '//td[text()="Foreign Language"]/following-sibling::td')

    end
  end
end
