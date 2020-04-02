class Element

  include Logging

  attr_reader :driver, :selenium_element, :locator

  def initialize(driver, locator, selenium_element = nil)
    @driver = driver
    @selenium_element = selenium_element
    @locator = locator
    find_selenium_element unless selenium_element
  end

  def attribute(name)
    @selenium_element.attribute name
  end

  def check
    click unless selected?
  end

  def checked?
    @selenium_element.selected?
  end

  def clear
    @selenium_element.clear
  end

  def click
    @selenium_element.click
  end

  def disabled?
    !@selenium_element.enabled?
  end

  def enabled?
    @selenium_element.enabled?
  end

  def exists?
    find_selenium_element unless @selenium_element
    begin
      @selenium_element.size
      true
    rescue Selenium::WebDriver::Error::NoSuchElementError, Selenium::WebDriver::Error::StaleElementReferenceError, NoMethodError
      false
    end
  end

  def find_selenium_element
    el = (@driver.find_element(@locator) rescue Selenium::WebDriver::Error::NoSuchElementError)
    @selenium_element = el.instance_of?(Selenium::WebDriver::Element) ? el : nil
  end

  def flash
    @selenium_element.flash
  end

  def options
    sel = Selenium::WebDriver::Support::Select.new @selenium_element
    sel.options
  end

  def selected?
    @selenium_element.selected?
  end

  def send_keys(string)
    @selenium_element.send_keys string
  end

  def tag_name
    @selenium_element.tag_name
  end

  def text
    @selenium_element.text
  end

  def visible?
    exists? && @selenium_element.displayed?
  end

  def when_present(timeout)
    wait = Selenium::WebDriver::Wait.new timeout: timeout
    wait.until { exists? }
  end

  def when_not_present(timeout)
    wait = Selenium::WebDriver::Wait.new timeout: timeout
    wait.until { !exists? }
  end

  def when_visible(timeout)
    wait = Selenium::WebDriver::Wait.new timeout: timeout
    wait.until { exists? && visible? }
  end

  def when_not_visible(timeout)
    wait = Selenium::WebDriver::Wait.new timeout: timeout
    wait.until { !visible? }
  end

end
