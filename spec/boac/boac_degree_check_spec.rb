require_relative '../../util/spec_helper'

include Logging

test = BOACTestConfig.new
test.degree_progress

describe 'BOA degrees' do

  before(:all) do
    @driver = Utils.launch_browser
    @homepage = BOACHomePage.new @driver
    @pax_manifest = BOACPaxManifestPage.new @driver
    @degree_templates_mgmt_page = BOACDegreeCheckMgmtPage.new @driver
    @degree_template_page = BOACDegreeCheckTemplatePage.new @driver

    @homepage.dev_auth
    @pax_manifest.load_page
    @pax_manifest.search_for_advisor test.advisor
    @pax_manifest.edit_user test.advisor
    @pax_manifest.search_for_advisor test.read_only_advisor
    @pax_manifest.edit_user test.read_only_advisor
    @pax_manifest.log_out

    @homepage.dev_auth test.advisor
  end

  after(:all) { Utils.quit_browser @driver }

  test.degree_templates.each do |template|

    it "can include #{template.name}" do
      @homepage.click_degree_checks_link
      @degree_templates_mgmt_page.create_new_degree template
      @degree_template_page.complete_template template
    end
  end

end
