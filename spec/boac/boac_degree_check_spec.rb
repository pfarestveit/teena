require_relative '../../util/spec_helper'

include Logging

test = BOACTestConfig.new
test.degree_progress
template = test.degree_templates.find { |t| t.name.include? BOACUtils.degree_major.first }

describe 'A BOA degree check' do

  before(:all) do
    @student = test.cohort_members.shuffle.first
    @degree_check = DegreeProgressChecklist.new(template, @student)

    @driver = Utils.launch_browser
    @homepage = BOACHomePage.new @driver
    @pax_manifest = BOACPaxManifestPage.new @driver
    @degree_templates_mgmt_page = BOACDegreeCheckMgmtPage.new @driver
    @degree_template_page = BOACDegreeCheckTemplatePage.new @driver
    @student_page = BOACStudentPage.new @driver
    @degree_check_create_page = BOACDegreeCheckCreatePage.new @driver
    @degree_check_page = BOACDegreeCheckPage.new @driver

    unless test.advisor.degree_progress_perm == DegreeProgressPerm::WRITE && test.read_only_advisor.degree_progress_perm == DegreeProgressPerm::READ
      @homepage.dev_auth
      @pax_manifest.load_page
      @pax_manifest.set_deg_prog_perm(test.advisor, BOACDepartments::COE, DegreeProgressPerm::WRITE)
      @pax_manifest.set_deg_prog_perm(test.read_only_advisor, BOACDepartments::COE, DegreeProgressPerm::READ)
      @pax_manifest.log_out
    end

    @homepage.dev_auth test.advisor
    @homepage.click_degree_checks_link
    @degree_templates_mgmt_page.create_new_degree template
    @degree_template_page.complete_template template
    @student_page.load_page @student
  end

  after(:all) { Utils.quit_browser @driver }

  it 'can be selected from a list of degree check templates' do
    @degree_check_create_page.load_page @student
    @degree_check_create_page.select_template template
  end

  it 'can be canceled' do
    @degree_check_create_page.click_cancel_degree
    @student_page.toggle_personal_details_element.when_visible Utils.short_wait
  end

  it 'can be created' do
    @degree_check_create_page.load_page @student
    @degree_check_create_page.create_new_degree_check(@degree_check)
  end

  template.unit_reqts&.each do |u_req|
    it "shows units requirement #{u_req.name} name" do
      @degree_check_page.wait_until(1, "Expected #{u_req.name}, got #{@degree_check_page.visible_unit_req_name u_req}") do
        @degree_check_page.visible_unit_req_name(u_req) == u_req.name
      end
    end

    it "shows units requirement #{u_req.name} unit count #{u_req.unit_count}" do
      @degree_check_page.wait_until(1, "Expected #{u_req.unit_count}, got #{@degree_check_page.visible_unit_req_num u_req}") do
        @degree_check_page.visible_unit_req_num(u_req) == u_req.unit_count
      end
    end
  end

  template.categories&.each do |cat|
    it "shows category #{cat.id} name #{cat.name}" do
      @degree_check_page.wait_until(1, "Expected #{cat.name}, got #{@degree_check_page.visible_cat_name cat}") do
        @degree_check_page.visible_cat_name(cat) == cat.name
      end
    end

    it "shows category #{cat.name} description #{cat.desc}" do
      if cat.desc
        @degree_check_page.wait_until(1, "Expected #{cat.desc}, got #{@degree_check_page.visible_cat_desc cat}") do
          @degree_check_page.visible_cat_desc(cat) == cat.desc
        end
      end
    end

    cat.sub_categories&.each do |sub_cat|
      it "shows subcategory #{sub_cat.name} name" do
        @degree_check_page.wait_until(1, "Expected #{sub_cat.name}, got #{@degree_check_page.visible_cat_name(sub_cat)}") do
          @degree_check_page.visible_cat_name(sub_cat) == sub_cat.name
        end
      end

      it "shows subcategory #{sub_cat.name} description #{sub_cat.desc}" do
        @degree_check_page.wait_until(1, "Expected #{sub_cat.desc}, got #{@degree_check_page.visible_cat_desc(sub_cat)}") do
          @degree_check_page.visible_cat_desc(sub_cat) == sub_cat.desc
        end
      end

      sub_cat.courses&.each do |course|
        it "shows subcategory #{sub_cat.name} course #{course.name} name" do
          @degree_check_page.wait_until(1, "Expected #{course.name}, got #{@degree_check_page.visible_course_name course}") do
            @degree_check_page.visible_course_name(course) == course.name
          end
        end

        it "shows subcategory #{sub_cat.name} course #{course.name} units #{course.units}" do
          @degree_check_page.wait_until(1, "Expected #{course.units}, got #{@degree_check_page.visible_course_units course}") do
            course.units ? (@degree_check_page.visible_course_units(course) == course.units) : (@degree_check_page.visible_course_units(course) == '—')
          end
        end

        it "shows subcategory #{sub_cat.name} course #{course.name} units requirements #{course.units_reqts}" do
          if course.units_reqts&.any?
            course.units_reqts.each do |u_req|
              @degree_check_page.wait_until(1, "Expected #{u_req.name}, got #{@degree_check_page.visible_course_fulfillment course}") do
                @degree_check_page.visible_course_fulfillment(course).include? u_req.name
              end
            end
          else
            @degree_check_page.wait_until(1, "Expected —, got #{@degree_check_page.visible_course_fulfillment course}") do
              @degree_check_page.visible_course_fulfillment(course) == '—'
            end
          end
        end
      end
    end

    cat.courses&.each do |course|
      it "shows category #{cat.name} course #{course.name} name" do
        @degree_check_page.wait_until(1, "Expected #{course.name}, got #{@degree_check_page.visible_course_name course}") do
          @degree_check_page.visible_course_name(course) == course.name
        end
      end

      it "shows category #{cat.name} course #{course.name} units #{course.units}" do
        @degree_check_page.wait_until(1, "Expected #{course.units}, got #{@degree_check_page.visible_course_units course}") do
          course.units ? (@degree_check_page.visible_course_units(course) == course.units) : (@degree_check_page.visible_course_units(course) == '—')
        end
      end

      it "shows category #{cat.name} course #{course.name} units requirements #{course.units_reqts}" do
        if course.units_reqts&.any?
          course.units_reqts.each do |u_req|
            @degree_check_page.wait_until(1, "Expected #{u_req.name}, got #{@degree_check_page.visible_course_fulfillment course}") do
              @degree_check_page.visible_course_fulfillment(course).include? u_req.name
            end
          end
        else
          @degree_check_page.wait_until(1, "Expected —, got #{@degree_check_page.visible_course_fulfillment course}") do
            @degree_check_page.visible_course_fulfillment(course) == '—'
          end
        end
      end
    end
  end
end
