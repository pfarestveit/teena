require_relative '../../util/spec_helper'

include Logging

test = BOACTestConfig.new
test.degree_progress

str_multiplier = (ENV['STR_MULT'] || 1).to_i

degree = DegreeProgressTemplate.new name: ("Teena Template #{test.id}" * str_multiplier)

### Unit requirements
units_req_1 = DegreeUnitReqt.new name: ("Unit Requirement 1 #{test.id}" * str_multiplier), unit_count: '48'
units_req_2 = DegreeUnitReqt.new name: ("Unit Requirement 2 #{test.id}" * str_multiplier), unit_count: '36'
units_req_3 = DegreeUnitReqt.new name: ("Unit Requirement 3 #{test.id}" * str_multiplier), unit_count: '24'

### Top category column requirements
req_category_1 = DegreeReqtCategory.new name: ("Category 1 #{test.id}" * str_multiplier),
                                        desc: ("Category 1 Description #{test.id}" * str_multiplier),
                                        column_num: 1
req_cat_course = DegreeReqtCourse.new name: "CAT 1 #{test.id}",
                                      units: '5-6',
                                      units_reqts: [units_req_2],
                                      parent: req_category_1
req_category_1.course_reqs = [req_cat_course]

req_category_2 = DegreeReqtCategory.new name: "Category 2 #{test.id}",
                                        column_num: 1

### Subcategory column requirements
req_sub_category_1 = DegreeReqtCategory.new name: ("Subcategory 1.1 #{test.id}" * str_multiplier),
                                            desc: ("Subcategory 1.1 Description www.teenamarieofficial.com #{test.id}" * str_multiplier),
                                            parent: req_category_1
req_sub_cat_course_1 = DegreeReqtCourse.new name: "SUBCAT 1 #{test.id}",
                                            units: '4',
                                            units_reqts: [units_req_2],
                                            parent: req_sub_category_1
req_sub_cat_course_2 = DegreeReqtCourse.new name: "SUBCAT 2 #{test.id}",
                                            units: '4.57',
                                            units_reqts: [units_req_2],
                                            parent: req_sub_category_1
req_category_1.sub_categories = [req_sub_category_1]
req_sub_category_1.course_reqs = [req_sub_cat_course_1]

req_sub_category_2 = DegreeReqtCategory.new name: "Subcategory 2.1 #{test.id}",
                                            parent: req_category_2

describe 'A BOA degree check template', order: :defined do

  before(:all) do
    @driver = Utils.launch_browser
    @homepage = BOACHomePage.new @driver
    @pax_manifest = BOACPaxManifestPage.new @driver
    @degree_templates_mgmt_page = BOACDegreeTemplateMgmtPage.new @driver
    @degree_template_page = BOACDegreeTemplatePage.new @driver

    unless test.advisor.degree_progress_perm == DegreeProgressPerm::WRITE && test.read_only_advisor.degree_progress_perm == DegreeProgressPerm::READ
      @homepage.dev_auth
      @pax_manifest.load_page
      @pax_manifest.set_deg_prog_perm(test.advisor, BOACDepartments::COE, DegreeProgressPerm::WRITE)
      @pax_manifest.set_deg_prog_perm(test.read_only_advisor, BOACDepartments::COE, DegreeProgressPerm::READ)
      @pax_manifest.log_out
    end

    @homepage.dev_auth test.advisor
    @homepage.click_degree_checks_link
  end

  after(:all) { Utils.quit_browser @driver }

  context 'when created' do

    it 'requires a name' do
      @homepage.click_degree_checks_link
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

  context 'unit requirement' do

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

      it 'can be canceled' do
        @degree_template_page.click_cancel_unit_req
        @degree_template_page.unit_reqs_empty_msg_element.when_visible 1
      end

      [units_req_1, units_req_2, units_req_3].each do |req|

        it("'#{req.name}' can be saved") { @degree_template_page.create_unit_req(req, degree) }

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

      it 'can be canceled' do
        @degree_template_page.click_cancel_unit_req
        @degree_template_page.visible_unit_req_name(units_req_2)
      end

      it 'can be saved' do
        units_req_2.name = "EDITED #{units_req_2.name}"
        units_req_2.unit_count = "#{units_req_2.unit_count.to_i - 1}"
        @degree_template_page.edit_unit_req units_req_2
        expect(@degree_template_page.visible_unit_req_name units_req_2).to eql(units_req_2.name)
        expect(@degree_template_page.visible_unit_req_num units_req_2).to eql(units_req_2.unit_count)
      end
    end

    context 'when deleted' do

      it 'can have the deletion canceled' do
        @degree_template_page.click_delete_unit_req units_req_1
        @degree_template_page.click_cancel_delete
      end

      it 'is no longer displayed in the list of existing unit requirements' do
        @degree_template_page.click_delete_unit_req units_req_1
        @degree_template_page.click_confirm_delete
        @degree_template_page.unit_req_name_el(units_req_1).when_not_present Utils.short_wait
      end
    end
  end

  context 'column requirement' do

    it 'requires a type selection' do
      @degree_template_page.click_add_col_req_button 1
      @degree_template_page.col_req_create_button_element.when_visible 1
      expect(@degree_template_page.col_req_create_button_element.enabled?).to be false
    end

    it 'allows only a category selection if no category exists in the column yet' do
      subcat_opt = @degree_template_page.col_req_type_options.find { |el| el.text == 'Subcategory' }
      expect(subcat_opt.enabled?).to be false
      course_opt = @degree_template_page.col_req_type_options.find { |el| el.text == 'Course Requirement' }
      expect(course_opt.enabled?).to be false
    end

    context 'category' do

      context 'when created' do

        it 'requires a name' do
          @degree_template_page.select_col_req_type 'Category'
          expect(@degree_template_page.col_req_create_button_element.enabled?).to be false
        end

        it 'allows a maximum of 255 characters in a name' do
          name = req_category_1.name * 10
          @degree_template_page.enter_col_req_name name
          expect(@degree_template_page.col_req_name_input_element.value).to eql(name[0..254])
        end

        it('does not require a description') { expect(@degree_template_page.col_req_create_button_element.enabled?).to be true }
        it('allows a description') { @degree_template_page.enter_col_req_desc req_category_1.desc }
        it('can be canceled') { @degree_template_page.click_cancel_col_req }
        it('can be saved') { @degree_template_page.create_col_req(req_category_1, degree) }
        it('shows the right name') { expect(@degree_template_page.visible_cat_name req_category_1).to eql(req_category_1.name) }
        it('shows the right description') { expect(@degree_template_page.visible_cat_desc req_category_1).to eql(req_category_1.desc) }
      end

      context 'subcategory' do

        context 'when created' do

          it 'requires a name' do
            @degree_template_page.click_add_col_req_button 1
            @degree_template_page.select_col_req_type 'Subcategory'
            expect(@degree_template_page.col_req_create_button_element.enabled?).to be false
          end

          it 'allows a maximum of 255 characters in a name' do
            name = req_sub_category_1.name * 10
            @degree_template_page.enter_col_req_name name
            expect(@degree_template_page.col_req_name_input_element.value).to eql(name[0..254])
          end

          it('requires a parent category') { expect(@degree_template_page.col_req_create_button_element.enabled?).to be false }
          it('allows a parent category selection') { @degree_template_page.select_col_req_parent req_category_1 }
          it('does not require a description') { expect(@degree_template_page.col_req_create_button_element.enabled?).to be true }
          it('allows a description') { @degree_template_page.enter_col_req_desc req_sub_category_1.desc }
          it('can be canceled') { @degree_template_page.click_cancel_col_req }
          it('can be saved') { @degree_template_page.create_col_req(req_sub_category_1, degree) }
          it('shows the right name') { expect(@degree_template_page.visible_cat_name req_sub_category_1).to eql(req_sub_category_1.name) }

          it 'supports external links in descriptions' do
            link = @degree_template_page.link_element(text: 'www.teenamarieofficial.com')
            expect(@degree_template_page.external_link_valid?(link, 'Teena Marie: Beautiful | Official Teena Marie Website')).to be true
          end

          it 'does not offer subcategories as parents' do
            @degree_template_page.click_add_col_req_button 1
            @degree_template_page.select_col_req_type 'Subcategory'
            option = @degree_template_page.col_req_parent_options.find { |el| el.text == req_sub_category_1.name }
            expect(option.enabled?).to be false
          end
        end

        context 'course' do

          context 'when added' do

            it 'requires a name' do
              @degree_template_page.click_cancel_col_req
              @degree_template_page.click_add_col_req_button 1
              @degree_template_page.select_col_req_type 'Course Requirement'
              expect(@degree_template_page.col_req_create_button_element.enabled?).to be false
            end

            it 'allows a maximum of 255 characters in a name' do
              name = req_sub_cat_course_1.name * 10
              @degree_template_page.enter_col_req_name name
              expect(@degree_template_page.col_req_name_input_element.value).to eql(name[0..254])
            end

            it('requires a parent category') { expect(@degree_template_page.col_req_create_button_element.enabled?).to be false }
            it('allows a parent category selection') { @degree_template_page.select_col_req_parent req_sub_category_1 }
            it('does not offer a description input') { expect(@degree_template_page.col_req_desc_input?).to be false }
            it('does not require units') { expect(@degree_template_page.col_req_create_button_element.enabled?).to be true }

            it 'requires numeric units' do
              @degree_template_page.enter_col_req_units '4A'
              @degree_template_page.col_req_course_units_error_msg_element.when_visible 1
            end

            it 'allows a maximum of 4 characters in units' do
              @degree_template_page.enter_col_req_units '3.351'
              expect(@degree_template_page.col_req_course_units_input_element.value).to eql('3.35')
            end

            it('allows a range of units') { @degree_template_page.enter_col_req_units '4-5' }
            it('does not require a requirement fulfillment selection') { expect(@degree_template_page.col_req_create_button_element.enabled?).to be true }

            it 'allows a requirement fulfillment selection' do
              @degree_template_page.select_col_req_unit_req req_sub_cat_course_1.units_reqts.first.name
              @degree_template_page.col_req_unit_req_remove_button(req_sub_cat_course_1.units_reqts.first).when_visible 1
            end

            it('can be canceled') { @degree_template_page.click_cancel_col_req }
            it('can be saved') { @degree_template_page.create_col_req(req_sub_cat_course_1, degree) }

            it 'shows the right name' do
              expect(@degree_template_page.visible_template_course_req_name req_sub_cat_course_1).to eql(req_sub_cat_course_1.name)
            end

            it 'shows the right units' do
              expect(@degree_template_page.visible_template_course_req_units req_sub_cat_course_1).to eql(req_sub_cat_course_1.units)
            end

            it 'shows the right unit requirements' do
              expect(@degree_template_page.visible_course_req_fulfillment req_sub_cat_course_1).to include(req_sub_cat_course_1.units_reqts.first.name)
            end
          end

          context 'when edited' do

            it 'requires a name' do
              @degree_template_page.click_edit_cat req_sub_cat_course_1
              @degree_template_page.enter_col_req_name ''
              expect(@degree_template_page.col_req_create_button_element.enabled?).to be false
            end

            it 'requires a parent category' do
              @degree_template_page.enter_col_req_name req_sub_cat_course_1.name
              @degree_template_page.select_col_req_parent
              expect(@degree_template_page.col_req_create_button_element.enabled?).to be false
            end

            it('does not offer a description input') { expect(@degree_template_page.col_req_desc_input?).to be false }

            it 'does not require units' do
              @degree_template_page.select_col_req_parent req_sub_category_1
              @degree_template_page.enter_col_req_units ''
              expect(@degree_template_page.col_req_create_button_element.enabled?).to be true
            end

            it 'does not require a requirement fulfillment selection' do
              @degree_template_page.remove_col_req_unit_req units_req_2
              expect(@degree_template_page.col_req_create_button_element.enabled?).to be true
            end

            it('can be canceled') { @degree_template_page.click_cancel_col_req }

            it 'can be saved' do
              req_sub_cat_course_1.name = "EDITED #{req_sub_cat_course_1.name}"
              req_sub_cat_course_1.parent = req_sub_category_1
              req_sub_cat_course_1.units = ''
              req_sub_cat_course_1.units_reqts = [units_req_3]
              @degree_template_page.click_edit_cat req_sub_cat_course_1
              @degree_template_page.enter_col_req_metadata req_sub_cat_course_1
              @degree_template_page.save_col_req
              @degree_template_page.course_req_row(req_sub_cat_course_1).when_present Utils.short_wait
            end

            it 'shows the right name' do
              expect(@degree_template_page.visible_template_course_req_name req_sub_cat_course_1).to eql(req_sub_cat_course_1.name)
            end

            it 'shows the right units' do
              expect(@degree_template_page.visible_template_course_req_units req_sub_cat_course_1).to eql('—')
            end

            it 'shows the right unit requirements' do
              expect(@degree_template_page.visible_course_req_fulfillment req_sub_cat_course_1).to include(req_sub_cat_course_1.units_reqts.first.name)
            end
          end

          context 'when deleted' do

            it 'can have the deletion canceled' do
              @degree_template_page.click_delete_cat req_sub_cat_course_1
              @degree_template_page.click_cancel_delete
            end

            it 'is removed from the column' do
              @degree_template_page.click_delete_cat req_sub_cat_course_1
              @degree_template_page.click_confirm_delete
              @degree_template_page.cat_name_el(req_sub_cat_course_1).when_not_present 2
            end
          end
        end

        context 'when edited' do

          before(:all) do
            @degree_template_page.create_col_req(req_category_2, degree)
            @degree_template_page.create_col_req(req_sub_cat_course_2, degree)
            req_sub_category_1.course_reqs << req_sub_cat_course_2
          end

          it 'requires a name' do
            @degree_template_page.click_edit_cat req_sub_category_1
            @degree_template_page.enter_col_req_name ''
            expect(@degree_template_page.col_req_create_button_element.enabled?).to be false
          end

          it 'requires a parent category' do
            @degree_template_page.enter_col_req_name req_sub_category_1.name
            @degree_template_page.select_col_req_parent
            expect(@degree_template_page.col_req_create_button_element.enabled?).to be false
          end

          it 'does not require a description' do
            @degree_template_page.select_col_req_parent req_category_1
            @degree_template_page.enter_col_req_desc ''
            expect(@degree_template_page.col_req_create_button_element.enabled?).to be true
          end

          it('can be canceled') { @degree_template_page.click_cancel_col_req }

          it 'can be saved' do
            req_sub_category_1.name = "EDITED #{req_sub_category_1.name}"
            req_sub_category_1.parent = req_category_2
            @degree_template_page.click_edit_cat req_sub_category_1
            @degree_template_page.enter_col_req_metadata req_sub_category_1
            @degree_template_page.save_col_req
          end

          it 'shows the right name' do
            expect(@degree_template_page.visible_cat_name req_sub_category_1).to eql(req_sub_category_1.name)
          end

          it 'shows the right description' do
            expect(@degree_template_page.visible_cat_desc req_sub_category_1).to eql(req_sub_category_1.desc)
          end

          it 'applies edits to subcategory courses' do
            expect(@degree_template_page.visible_template_course_req_name req_sub_cat_course_2).to eql(req_sub_cat_course_2.name)
          end
        end

        context 'when deleted' do

          it 'can have the deletion canceled' do
            @degree_template_page.click_delete_cat req_sub_category_1
            @degree_template_page.click_cancel_delete
          end

          it 'is removed from the column' do
            @degree_template_page.click_delete_cat req_sub_category_1
            @degree_template_page.click_confirm_delete
            @degree_template_page.cat_name_el(req_sub_category_1).when_not_present 2
          end
        end
      end

      context 'course' do

        context 'when added' do

          it 'requires a name' do
            @degree_template_page.click_add_col_req_button 1
            @degree_template_page.select_col_req_type 'Course Requirement'
            expect(@degree_template_page.col_req_create_button_element.enabled?).to be false
          end

          it 'allows a maximum of 255 characters in a name' do
            name = req_cat_course.name * 10
            @degree_template_page.enter_col_req_name name
            expect(@degree_template_page.col_req_name_input_element.value).to eql(name[0..254])
          end

          it('requires a parent category') { expect(@degree_template_page.col_req_create_button_element.enabled?).to be false }
          it('allows a parent category selection') { @degree_template_page.select_col_req_parent req_category_1 }
          it('does not offer a description input') { expect(@degree_template_page.col_req_desc_input?).to be false }
          it('does not require units') { expect(@degree_template_page.col_req_create_button_element.enabled?).to be true }

          it 'requires numeric units' do
            @degree_template_page.enter_col_req_units '4A'
            @degree_template_page.col_req_course_units_error_msg_element.when_visible 1
          end

          it 'allows a maximum of 4 characters in units' do
            @degree_template_page.enter_col_req_units '3.351'
            expect(@degree_template_page.col_req_course_units_input_element.value).to eql('3.35')
          end

          it('allows a range of units') { @degree_template_page.enter_col_req_units '4-5' }
          it('does not require a requirement fulfillment selection') { expect(@degree_template_page.col_req_create_button_element.enabled?).to be true }

          it 'allows a requirement fulfillment selection' do
            @degree_template_page.select_col_req_unit_req req_cat_course.units_reqts.first.name
            @degree_template_page.col_req_unit_req_remove_button(req_cat_course.units_reqts.first).when_visible Utils.short_wait
          end

          it('can be canceled') { @degree_template_page.click_cancel_col_req }
          it('can be saved') { @degree_template_page.create_col_req(req_cat_course, degree) }

          it 'shows the right name' do
            expect(@degree_template_page.visible_template_course_req_name req_cat_course).to eql(req_cat_course.name)
          end

          it 'shows the right units' do
            expect(@degree_template_page.visible_template_course_req_units req_cat_course).to eql(req_cat_course.units)
          end

          it 'shows the right unit requirements' do
            expect(@degree_template_page.visible_course_req_fulfillment req_cat_course).to include(req_cat_course.units_reqts.first.name)
          end
        end

        context 'when edited' do

          before(:all) do
            @degree_template_page.create_col_req(req_sub_category_2, degree)
            req_category_1.sub_categories << req_sub_category_2
          end

          it 'requires a name' do
            @degree_template_page.click_edit_cat req_cat_course
            @degree_template_page.enter_col_req_name ''
            expect(@degree_template_page.col_req_create_button_element.enabled?).to be false
          end

          it 'requires a parent category' do
            @degree_template_page.enter_col_req_name req_cat_course.name
            @degree_template_page.select_col_req_parent
            expect(@degree_template_page.col_req_create_button_element.enabled?).to be false
          end

          it('does not offer a description input') { expect(@degree_template_page.col_req_desc_input?).to be false }

          it 'does not require units' do
            @degree_template_page.select_col_req_parent req_category_1
            @degree_template_page.enter_col_req_units ''
            expect(@degree_template_page.col_req_create_button_element.enabled?).to be true
          end

          it 'does not require a requirement fulfillment selection' do
            @degree_template_page.remove_col_req_unit_req req_cat_course.units_reqts.first
            expect(@degree_template_page.col_req_create_button_element.enabled?).to be true
          end

          it('can be canceled') { @degree_template_page.click_cancel_col_req }

          it 'can be saved' do
            req_cat_course.name = "EDITED #{req_cat_course.name}"
            req_cat_course.parent = req_sub_category_2
            req_cat_course.units = '10'
            req_cat_course.units_reqts = [units_req_3]
            @degree_template_page.click_edit_cat req_cat_course
            @degree_template_page.enter_col_req_metadata req_cat_course
            @degree_template_page.save_col_req
          end

          it 'shows the right name' do
            expect(@degree_template_page.visible_template_course_req_name req_cat_course).to eql(req_cat_course.name)
          end

          it 'shows the right units' do
            expect(@degree_template_page.visible_template_course_req_units req_cat_course).to eql(req_cat_course.units)
          end

          it 'shows the right unit requirements' do
            expect(@degree_template_page.visible_course_req_fulfillment req_cat_course).to include(req_cat_course.units_reqts.first.name)
          end
        end

        context 'when deleted' do

          it 'can have the deletion canceled' do
            @degree_template_page.click_delete_cat req_cat_course
            @degree_template_page.click_cancel_delete
          end

          it 'is removed from the column' do
            @degree_template_page.click_delete_cat req_cat_course
            @degree_template_page.click_confirm_delete
            @degree_template_page.cat_name_el(req_cat_course).when_not_present 2
          end
        end
      end

      context 'when edited' do

        it 'requires a name' do
          @degree_template_page.click_edit_cat req_category_1
          @degree_template_page.enter_col_req_name ''
          expect(@degree_template_page.col_req_create_button_element.enabled?).to be false
        end

        it 'does not require a description' do
          @degree_template_page.enter_col_req_name req_category_1.name
          @degree_template_page.enter_col_req_desc ''
          expect(@degree_template_page.col_req_create_button_element.enabled?).to be true
        end

        it('can be canceled') { @degree_template_page.click_cancel_col_req }

        it 'can be saved' do
          req_category_1.name = "EDITED #{req_category_1.name}"
          req_category_1.desc = "EDITED #{req_category_1.desc}"
          @degree_template_page.click_edit_cat req_category_1
          @degree_template_page.enter_col_req_metadata req_category_1
          @degree_template_page.save_col_req
        end

        it 'shows the right name' do
          expect(@degree_template_page.visible_cat_name req_category_1).to eql(req_category_1.name)
        end

        it 'shows the right description' do
          expect(@degree_template_page.visible_cat_desc req_category_1).to eql(req_category_1.desc)
        end
      end

      context 'when deleted' do

        it 'can have the deletion canceled' do
          @degree_template_page.click_delete_cat req_category_1
          @degree_template_page.click_cancel_delete
        end

        it 'is removed from the column' do
          @degree_template_page.click_delete_cat req_category_1
          @degree_template_page.click_confirm_delete
          @degree_template_page.cat_name_el(req_category_1).when_not_present 2
        end
      end
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

    # TODO it 'includes all the data present in the original template'

  end

  context 'when deleted' do

    it 'can have the deletion canceled' do
      @degree_templates_mgmt_page.click_delete_degree degree
      @degree_templates_mgmt_page.click_cancel_delete
    end

    it 'is no longer displayed in the list of existing degrees' do
      @degree_templates_mgmt_page.click_delete_degree degree
      @degree_templates_mgmt_page.click_confirm_delete
      expect(@degree_templates_mgmt_page.degree_check_link(degree).exists?).to be false
    end
  end

  # TESTS FOR REALISTIC TEMPLATE CREATION

  test.degree_templates[0..(BOACUtils.degree_templates_max - 1)].each do |template|

    it "template for #{template.name} can be created" do
      @homepage.click_degree_checks_link
      @degree_templates_mgmt_page.create_new_degree template
      @degree_template_page.complete_template template
    end

    template.unit_reqts&.each do |u_req|
      it "shows units requirement #{u_req.name} name" do
        @degree_template_page.wait_until(1, "Expected #{u_req.name}, got #{@degree_template_page.visible_unit_req_name u_req}") do
          @degree_template_page.visible_unit_req_name(u_req) == u_req.name
        end
      end

      it "shows units requirement #{u_req.name} unit count #{u_req.unit_count}" do
        @degree_template_page.wait_until(1, "Expected #{u_req.unit_count}, got #{@degree_template_page.visible_unit_req_num u_req}") do
          @degree_template_page.visible_unit_req_num(u_req) == u_req.unit_count
        end
      end
    end

    template.categories&.each do |cat|
      it "shows category #{cat.id} name #{cat.name}" do
        @degree_template_page.wait_until(1, "Expected #{cat.name}, got #{@degree_template_page.visible_cat_name cat}") do
          @degree_template_page.visible_cat_name(cat) == cat.name
        end
      end

      it "shows category #{cat.name} description #{cat.desc}" do
        if cat.desc
          @degree_template_page.wait_until(1, "Expected '#{cat.desc}', got '#{@degree_template_page.visible_cat_desc cat}'") do
            @degree_template_page.visible_cat_desc(cat).to_s == cat.desc.to_s
          end
        end
      end

      cat.sub_categories&.each do |sub_cat|
        it "shows subcategory #{sub_cat.name} name" do
          @degree_template_page.wait_until(1, "Expected #{sub_cat.name}, got #{@degree_template_page.visible_cat_name(sub_cat)}") do
            @degree_template_page.visible_cat_name(sub_cat) == sub_cat.name
          end
        end

        it "shows subcategory #{sub_cat.name} description #{sub_cat.desc}" do
          if sub_cat.desc
            @degree_template_page.wait_until(1, "Expected '#{sub_cat.desc}', got '#{@degree_template_page.visible_cat_desc(sub_cat)}'") do
              @degree_template_page.visible_cat_desc(sub_cat).to_s == sub_cat.desc.to_s
            end
          end
        end

        sub_cat.course_reqs&.each do |course|
          it "shows subcategory #{sub_cat.name} course #{course.name} name" do
            @degree_template_page.wait_until(1, "Expected #{course.name}, got #{@degree_template_page.visible_template_course_req_name course}") do
              @degree_template_page.visible_template_course_req_name(course) == course.name
            end
          end

          it "shows subcategory #{sub_cat.name} course #{course.name} units #{course.units}" do
            @degree_template_page.wait_until(1, "Expected #{course.units}, got #{@degree_template_page.visible_template_course_req_units course}") do
              course.units ? (@degree_template_page.visible_template_course_req_units(course) == course.units) : (@degree_template_page.visible_template_course_req_units(course) == '—')
            end
          end

          it "shows subcategory #{sub_cat.name} course #{course.name} units requirements #{course.units_reqts}" do
            if course.units_reqts&.any?
              course.units_reqts.each do |u_req|
                @degree_template_page.wait_until(1, "Expected #{u_req.name}, got #{@degree_template_page.visible_course_req_fulfillment course}") do
                  @degree_template_page.visible_course_req_fulfillment(course).include? u_req.name
                end
              end
            else
              @degree_template_page.wait_until(1, "Expected —, got #{@degree_template_page.visible_course_req_fulfillment course}") do
                @degree_template_page.visible_course_req_fulfillment(course) == '—'
              end
            end
          end
        end
      end

      cat.course_reqs&.each do |course|
        it "shows category #{cat.name} course #{course.name} name" do
          @degree_template_page.wait_until(1, "Expected #{course.name}, got #{@degree_template_page.visible_template_course_req_name course}") do
            @degree_template_page.visible_template_course_req_name(course) == course.name
          end
        end

        it "shows category #{cat.name} course #{course.name} units #{course.units}" do
          @degree_template_page.wait_until(1, "Expected #{course.units}, got #{@degree_template_page.visible_template_course_req_units course}") do
            course.units ? (@degree_template_page.visible_template_course_req_units(course) == course.units) : (@degree_template_page.visible_template_course_req_units(course) == '—')
          end
        end

        it "shows category #{cat.name} course #{course.name} units requirements #{course.units_reqts}" do
          if course.units_reqts&.any?
            course.units_reqts.each do |u_req|
              @degree_template_page.wait_until(1, "Expected #{u_req.name}, got #{@degree_template_page.visible_course_req_fulfillment course}") do
                @degree_template_page.visible_course_req_fulfillment(course).include? u_req.name
              end
            end
          else
            @degree_template_page.wait_until(1, "Expected —, got #{@degree_template_page.visible_course_req_fulfillment course}") do
              @degree_template_page.visible_course_req_fulfillment(course) == '—'
            end
          end
        end
      end
    end
  end
end
