module PageObject

  include Logging

  def initialize(driver)
    @driver = driver
  end

  ### DRIVER ###

  def browser
    @driver
  end

  def current_url
    @driver.current_url
  end

  def execute_script(snippet, element = nil)
    @driver.execute_script(snippet, (element.selenium_element if element))
  end

  def navigate_to(url)
    @driver.get url
  end

  def text
    @driver.page_source
  end

  def title
    @driver.title
  end

  def wait_until(timeout, msg = nil, &blk)
    wait = Selenium::WebDriver::Wait.new timeout: timeout, message: msg
    wait.until do
      yield
    rescue
      false
    end
  end

  ### ELEMENTS ###

  # Tag '_element' methods

  %i(button
     cell
     checkbox
     div
     form
     h1
     h2
     h3
     h4
     h5
     h6
     iframe
     image
     label
     link
     list_item
     paragraph
     radio_button
     row
     select_list
     span
     table
     text_area
     text_field
     title
     video
  ).each do |tag|
    send(:define_method, "#{tag}_element") do |*args|
      locator = args.first
      locator = locator.has_key?(:text) ? ({link_text: locator[:text]}) : locator
      el = Element.new(@driver, locator)
      el.find_selenium_element
      el
    end
    send(:define_method, "#{tag}_elements") do |*args|
      locator = args.first
      locator = locator.has_key?(:text) ? ({link_text: locator[:text]}) : locator
      els = @driver.find_elements(locator)
      els.map { |el| Element.new(@driver, locator, el) }
    end
  end

  def self.included(base)
    base.extend ClassMethods
  end

  module ClassMethods

    # Dynamic element methods

    def button(name, locator)
      clickable_element(name, locator)
    end

    def cell(name, locator)
      text_element(name, locator)
    end

    def checkbox(name, locator)
      checkable_element(name, locator)
    end

    def div(name, locator)
      text_element(name, locator)
    end

    def element(name, locator)
      text_element(name, locator)
    end

    def elements(name, tag, locator)
      to_elements(name, tag, locator)
    end

    def form_element(name, locator)
      to_element(name, locator)
    end

    def file_field(name, locator)
      input_element(name, locator)
    end

    def form(name, locator)
      to_element(name, locator)
    end

    def h1(name, locator)
      text_element(name, locator)
    end

    def h2(name, locator)
      text_element(name, locator)
    end

    def h3(name, locator)
      text_element(name, locator)
    end

    def h4(name, locator)
      text_element(name, locator)
    end

    def h5(name, locator)
      text_element(name, locator)
    end

    def h6(name, locator)
      text_element(name, locator)
    end

    def iframe(name, locator)
      to_element(name, locator)
    end

    def image(name, locator)
      to_element(name, locator)
    end

    def label(name, locator)
      text_element(name, locator)
    end

    def li(name, locator)
      text_element(name, locator)
    end

    def link(name, locator)
      locator = locator.has_key?(:text) ? {link_text: locator[:text]} : locator
      clickable_element(name, locator)
    end

    def list_item(name, locator)
      text_element(name, locator)
    end

    def paragraph(name, locator)
      text_element(name, locator)
    end

    def radio_button(name, locator)
      radio_element(name, locator)
    end

    def row(name, locator)
      text_element(name, locator)
    end

    def select_list(name, locator)
      select_element(name, locator)
    end

    def span(name, locator)
      text_element(name, locator)
    end

    def table(name, locator)
      text_element(name, locator)
    end

    def td(name, locator)
      text_element(name, locator)
    end

    def text_area(name, locator)
      input_element(name, locator)
    end

    def text_field(name, locator)
      input_element(name, locator)
    end

    def unordered_list(name, locator)
      text_element(name, locator)
    end

    def video(name, locator)
      text_element(name, locator)
    end

    # Dynamic method definitions

    def to_element(name, locator)
      define_method("#{name}_element") do
        el = Element.new(@driver, locator)
        el.find_selenium_element
        el
      end
      define_method("#{name}?") { self.send("#{name}_element").exists? }
    end

    def to_elements(name, tag, locator)
      define_method("#{name}_elements") do
        els = @driver.find_elements(locator)
        els.map { |el| Element.new(@driver, locator, el) }
      end
    end

    def checkable_element(name, locator)
      to_element(name, locator)
      define_method("check_#{name}") { self.send("#{name}_element").click unless self.send("#{name}_element").selected? }
      define_method("#{name}_checked?") { self.send("#{name}_element").selected? }
      define_method("uncheck_#{name}") { self.send("#{name}_element").click if self.send("#{name}_element").selected? }
    end

    def clickable_element(name, locator)
      to_element(name, locator)
      define_method(name) { self.send("#{name}_element").click }
    end

    def input_element(name, locator)
      to_element(name, locator)
      define_method(name) { self.send("#{name}_element").attribute('value') }
      define_method("#{name}=") { |text| self.send("#{name}_element").send_keys text }
    end

    def radio_element(name, locator)
      to_element(name, locator)
      define_method("select_#{name}") { self.send("#{name}_element").click unless self.send("#{name}_element").selected? }
      define_method("#{name}_selected?") { self.send("#{name}_element").selected? }
    end

    def select_element(name, locator)
      to_element(name, locator)
      define_method("#{name}_options") do
        el = self.send("#{name}_element")
        sel = Selenium::WebDriver::Support::Select.new el.selenium_element
        sel.options.map &:text
      end
      define_method(name) do
        el = self.send("#{name}_element")
        sel = Selenium::WebDriver::Support::Select.new el.selenium_element
        sel.first_selected_option&.text
      end
    end

    def text_element(name, locator)
      to_element(name, locator)
      define_method(name) { self.send("#{name}_element").text }
    end

  end
end
