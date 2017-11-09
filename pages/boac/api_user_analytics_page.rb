require_relative '../../util/spec_helper'

class ApiUserAnalyticsPage

  include PageObject
  include Logging

  def get_data(driver, user)
    navigate_to "#{BOACUtils.base_url}/api/user/#{user.uid}/analytics"
    wait_until(Utils.long_wait) { driver.find_element(xpath: '//pre') }
    @parsed = JSON.parse driver.find_element(xpath: '//pre').text
  end

  # Canvas Profile

  def set_canvas_id(user)
    user.canvas_id = @parsed['canvasProfile']['id']
  end

  # SIS Profile

  def sis_profile
    @parsed['sisProfile']
  end

  def plan
    sis_profile['plan'] && sis_profile['plan']['description']
  end

  def level
    sis_profile['level'] && sis_profile['level']['description']
  end

  def cumulative_units
    units = sis_profile['cumulativeUnits']
    (units == units.floor) ? units.floor.to_s : units.to_s
  end

  def cumulative_gpa
    sis_profile['cumulativeGPA'] == 0 ? '--' : sis_profile['cumulativeGPA'].to_s
  end

  def degree_progress
    sis_profile['degreeProgress']
  end

  def writing_reqt
    degree_progress && degree_progress['entryLevelWriting']
  end

  def history_reqt
    degree_progress && degree_progress['americanHistory']
  end

  def cultures_reqt
    degree_progress && degree_progress['americanCultures']
  end

  def institutions_reqt
    degree_progress && degree_progress['americanInstitutions']
  end

  def language_reqt
    degree_progress && degree_progress['foreignLanguage']
  end

  def email
    sis_profile['emailAddress']
  end

  def phone
    sis_profile['phoneNumber'].to_s
  end

end
