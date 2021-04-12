require_relative '../../util/spec_helper'

include Logging

describe 'A BOA degree check template' do

  before(:all) do
    @test = BOACTestConfig.new
    @test.degree_progress
    @degree = DegreeProgressTemplate.new name: "Teena Template #{@test.id}"

    @driver = Utils.launch_browser
    @homepage = BOACHomePage.new @driver
    @pax_manifest = BOACPaxManifestPage.new @driver
    @degree_templates_mgmt_page = BOACDegreeCheckMgmtPage.new @driver
    @degree_template_page = BOACDegreeCheckTemplatePage.new @driver

    @homepage.dev_auth
    @pax_manifest.load_page
    @pax_manifest.search_for_advisor @test.advisor
    @pax_manifest.edit_user @test.advisor
    @pax_manifest.search_for_advisor @test.read_only_advisor
    @pax_manifest.edit_user @test.read_only_advisor
    @pax_manifest.log_out

    @homepage.dev_auth @test.advisor
    @homepage.click_degree_checks_link
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when created' do

    it 'requires a name' do
      @degree_templates_mgmt_page.click_create_degree
      @degree_templates_mgmt_page.create_degree_save_button_element.when_present Utils.short_wait
      expect(@degree_templates_mgmt_page.create_degree_save_button_element.enabled?).to be false
    end

    it 'redirects to an empty degree template page' do
      @degree_templates_mgmt_page.enter_degree_name @degree.name
      @degree_templates_mgmt_page.click_save_new_degree
      @degree_template_page.template_heading(@degree).when_visible Utils.short_wait
      @degree.set_new_template_id
    end

    it 'is displayed in the list of existing degrees' do
      @degree_template_page.click_degree_checks_link
      @degree_templates_mgmt_page.degree_check_link(@degree).when_visible Utils.short_wait
    end

    it 'shows its creation date' do
      expect(@degree_templates_mgmt_page.degree_check_create_date @degree).to eql(@degree.created_date)
    end

    it 'requires a unique name' do
      @degree_templates_mgmt_page.click_create_degree
      @degree_templates_mgmt_page.enter_degree_name @degree.name
      @degree_templates_mgmt_page.click_save_new_degree
      @degree_templates_mgmt_page.dupe_name_msg_element.when_visible Utils.short_wait
    end

    it 'allows a maximum of 255 characters' do
      name = @degree.name * 8
      @degree_templates_mgmt_page.enter_degree_name name
      expect(@degree_templates_mgmt_page.create_degree_name_input_element.value).to eql(name[0..254])
    end
  end

  context 'when renamed' do

    it 'requires a name' do
      @degree_templates_mgmt_page.go_back
      @degree_templates_mgmt_page.click_rename_button @degree
      @degree_templates_mgmt_page.rename_degree_save_button_element.when_visible Utils.short_wait
      expect(@degree_templates_mgmt_page.rename_degree_name_input_element.value).to eql(@degree.name)
      expect(@degree_templates_mgmt_page.rename_degree_save_button_element.enabled?).to be true
    end

    it 'is displayed in the list of existing degrees' do
      name = "#{@degree.name} - Edited"
      @degree_templates_mgmt_page.enter_new_name name
      @degree_templates_mgmt_page.click_save_new_name
      @degree_templates_mgmt_page.degree_check_link(@degree).when_visible Utils.short_wait
      @degree.name = name
    end

    it 'can be canceled' do
      @degree_templates_mgmt_page.click_rename_button @degree
      @degree_templates_mgmt_page.click_cancel_new_name
      @degree_templates_mgmt_page.degree_check_link(@degree).when_visible Utils.short_wait
    end
  end

  context 'when copied' do

    before(:all) { @degree_copy = DegreeProgressTemplate.new name: "Teena Template COPY #{@test.id}" }

    it 'requires a unique name' do
      @degree_templates_mgmt_page.click_copy_button @degree
      @degree_templates_mgmt_page.copy_degree_save_button_element.when_visible Utils.short_wait
      expect(@degree_templates_mgmt_page.copy_degree_name_input_element.value).to eql(@degree.name)
      expect(@degree_templates_mgmt_page.copy_degree_save_button_element.enabled?).to be false
    end

    it 'allows a maximum of 255 characters' do
      name = @degree.name * 8
      @degree_templates_mgmt_page.enter_copy_name name
      expect(@degree_templates_mgmt_page.copy_degree_name_input_element.value).to eql(name[0..254])
    end

    it 'can be canceled' do
      @degree_templates_mgmt_page.click_cancel_copy
      @degree_templates_mgmt_page.degree_check_link(@degree).when_visible Utils.short_wait
    end

    it 'redirects to the list of existing degrees' do
      @degree_templates_mgmt_page.click_copy_button @degree
      @degree_templates_mgmt_page.enter_copy_name @degree_copy.name
      @degree_templates_mgmt_page.click_save_copy
      @degree_templates_mgmt_page.degree_check_link(@degree_copy).when_visible Utils.short_wait
    end

    # TODO verify all the copy content once the feature is built
  end

  context 'when deleted' do

    it 'can have the deletion canceled' do
      @degree_templates_mgmt_page.click_delete_degree @degree
      @degree_templates_mgmt_page.click_cancel_delete
      @degree_templates_mgmt_page.confirm_delete_or_discard_button_element.when_not_present 1
    end

    it 'is no longer displayed in the list of existing degrees' do
      @degree_templates_mgmt_page.click_delete_degree @degree
      @degree_templates_mgmt_page.click_confirm_delete
      @degree_templates_mgmt_page.degree_check_link(@degree).when_not_present Utils.short_wait
    end
  end
end
