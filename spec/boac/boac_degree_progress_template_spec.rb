require_relative '../../util/spec_helper'

include Logging

test = BOACTestConfig.new
test.degree_progress

str_multiplier = ENV['STR_MULT'].to_i || 1

degree = DegreeProgressTemplate.new name: ("Teena Template #{test.id}" * str_multiplier)

units_req_1 = DegreeUnitReqt.new name: ("Engineering Units #{test.id}" * str_multiplier), unit_count: '48'
units_req_2 = DegreeUnitReqt.new name: ("Upper Division Topics Units #{test.id}" * str_multiplier), unit_count: '36'
units_req_3 = DegreeUnitReqt.new name: ("Upper Division BioE Units #{test.id}" * str_multiplier), unit_count: '24'

describe 'A BOA degree check template' do

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
      @degree_templates_mgmt_page.enter_degree_name degree.name
      @degree_templates_mgmt_page.click_save_new_degree
      @degree_template_page.template_heading(degree).when_visible Utils.short_wait
      degree.set_new_template_id
    end

    it 'is displayed in the list of existing degrees' do
      @degree_template_page.click_degree_checks_link
      @degree_templates_mgmt_page.degree_check_link(degree).when_visible Utils.short_wait
    end

    it 'shows its creation date' do
      expect(@degree_templates_mgmt_page.degree_check_create_date degree).to eql(degree.created_date)
    end

    it 'requires a unique name' do
      @degree_templates_mgmt_page.click_create_degree
      @degree_templates_mgmt_page.enter_degree_name degree.name
      @degree_templates_mgmt_page.click_save_new_degree
      @degree_templates_mgmt_page.dupe_name_msg_element.when_visible Utils.short_wait
    end

    it 'allows a maximum of 255 characters' do
      name = degree.name * 8
      @degree_templates_mgmt_page.enter_degree_name name
      expect(@degree_templates_mgmt_page.create_degree_name_input_element.value).to eql(name[0..254])
    end
  end

  context 'unit requirements' do

    before(:all) do
      @degree_templates_mgmt_page.click_degree_checks_link
      @degree_templates_mgmt_page.click_degree_link degree
    end

    context 'when created' do

      it 'requires a name' do
        @degree_template_page.click_add_unit_req
        @degree_template_page.unit_req_name_input_element.when_visible 1
        expect(@degree_template_page.unit_req_create_button_element.enabled?).to be false
      end

      it 'allows a maximum 255 character name' do
        name = units_req_1.name * 8
        @degree_template_page.enter_unit_req_name name
        expect(@degree_template_page.unit_req_name_input_element.value).to eql(name[0..254])
      end

      it 'requires a unit count' do
        expect(@degree_template_page.unit_req_create_button_element.enabled?).to be false
      end

      it 'requires a numeric unit count' do
        # TODO - expect a validation error
        @degree_template_page.enter_unit_req_num 'foo'
        expect(@degree_template_page.unit_req_num_input_element.value).to be_empty
      end

      it 'requires a positive unit count' do
        # TODO - expect a validation error
        @degree_template_page.enter_unit_req_num '-10'
        expect(@degree_template_page.unit_req_num_input_element.value).to be_empty
      end

      it 'can be canceled' do
        @degree_template_page.click_cancel_unit_req
        @degree_template_page.unit_reqs_empty_msg_element.when_visible 1
      end

      [units_req_1, units_req_2, units_req_3].each do |req|

        it("'#{req.name}' can be saved") { @degree_template_page.create_unit_req req }

        it "'#{req.name}' shows the right name in the list of existing unit requirements" do
          expect(@degree_template_page.visible_unit_req_name req).to eql(req.name)
        end

        it "'#{req.name}' shows the right unit count in the list of existing unit requirements" do
          expect(@degree_template_page.visible_unit_req_num req).to eql(req.unit_count)
        end
      end
    end

    context 'when edited' do

      it 'requires a name' do
        @degree_template_page.click_edit_unit_req units_req_2
        @degree_template_page.enter_unit_req_name ''
        expect(@degree_template_page.unit_req_save_button_element.enabled?).to be false
      end

      it 'allows a maximum 255 character name' do
        name = units_req_1.name * 8
        @degree_template_page.enter_unit_req_name name
        expect(@degree_template_page.unit_req_name_input_element.value).to eql(name[0..254])
      end

      it 'requires a unit count' do
        @degree_template_page.enter_unit_req_num ''
        expect(@degree_template_page.unit_req_save_button_element.enabled?).to be false
      end

      it 'requires a numeric unit count' do
        # TODO - expect a validation error
        @degree_template_page.enter_unit_req_num 'foo'
        expect(@degree_template_page.unit_req_num_input_element.value).to be_empty
      end

      it 'requires a positive unit count' do
        # TODO - expect a validation error
        @degree_template_page.enter_unit_req_num '-10'
        expect(@degree_template_page.unit_req_num_input_element.value).to be_empty
      end

      it 'can be canceled' do
        @degree_template_page.click_cancel_unit_req
        @degree_template_page.visible_unit_req_name(units_req_2)
      end

      it 'can be saved' do
        units_req_2.name = "EDITED #{units_req_2.name}"
        units_req_2.unit_count = "#{units_req_2.unit_count}0"
        @degree_template_page.edit_unit_req units_req_2
        expect(@degree_template_page.visible_unit_req_name units_req_2).to eql(units_req_2.name)
        expect(@degree_template_page.visible_unit_req_num units_req_2).to eql(units_req_2.unit_count)
      end
    end

    context 'when deleted' do

      # TODO

    end
  end

  context 'when renamed' do

    before(:all) { @degree_template_page.click_degree_checks_link }

    it 'requires a name' do
      @degree_templates_mgmt_page.click_rename_button degree
      @degree_templates_mgmt_page.rename_degree_save_button_element.when_visible Utils.short_wait
      expect(@degree_templates_mgmt_page.rename_degree_name_input_element.value).to eql(degree.name)
      expect(@degree_templates_mgmt_page.rename_degree_save_button_element.enabled?).to be true
    end

    it 'is displayed in the list of existing degrees' do
      name = "#{degree.name} - Edited"
      @degree_templates_mgmt_page.enter_new_name name
      @degree_templates_mgmt_page.click_save_new_name
      @degree_templates_mgmt_page.degree_check_link(degree).when_visible Utils.short_wait
      degree.name = name
    end

    it 'can be canceled' do
      @degree_templates_mgmt_page.click_rename_button degree
      @degree_templates_mgmt_page.click_cancel_new_name
      @degree_templates_mgmt_page.degree_check_link(degree).when_visible Utils.short_wait
    end
  end

  context 'when copied' do

    before(:all) { @degree_copy = DegreeProgressTemplate.new name: "Teena Template COPY #{test.id}" }

    it 'requires a unique name' do
      @degree_templates_mgmt_page.click_copy_button degree
      @degree_templates_mgmt_page.copy_degree_save_button_element.when_visible Utils.short_wait
      expect(@degree_templates_mgmt_page.copy_degree_name_input_element.value).to eql(degree.name)
      expect(@degree_templates_mgmt_page.copy_degree_save_button_element.enabled?).to be false
    end

    it 'allows a maximum of 255 characters' do
      name = degree.name * 8
      @degree_templates_mgmt_page.enter_copy_name name
      expect(@degree_templates_mgmt_page.copy_degree_name_input_element.value).to eql(name[0..254])
    end

    it 'can be canceled' do
      @degree_templates_mgmt_page.click_cancel_copy
      @degree_templates_mgmt_page.degree_check_link(degree).when_visible Utils.short_wait
    end

    it 'redirects to the list of existing degrees' do
      @degree_templates_mgmt_page.click_copy_button degree
      @degree_templates_mgmt_page.enter_copy_name @degree_copy.name
      @degree_templates_mgmt_page.click_save_copy
      @degree_templates_mgmt_page.degree_check_link(@degree_copy).when_visible Utils.short_wait
    end

    # TODO verify all the copy content once the feature is built
  end

  context 'when deleted' do

    it 'can have the deletion canceled' do
      @degree_templates_mgmt_page.click_delete_degree degree
      @degree_templates_mgmt_page.click_cancel_delete
      @degree_templates_mgmt_page.confirm_delete_or_discard_button_element.when_not_present 1
    end

    it 'is no longer displayed in the list of existing degrees' do
      @degree_templates_mgmt_page.click_delete_degree degree
      @degree_templates_mgmt_page.click_confirm_delete
      @degree_templates_mgmt_page.degree_check_link(degree).when_not_present Utils.short_wait
    end
  end
end
