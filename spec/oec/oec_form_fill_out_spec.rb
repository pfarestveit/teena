require_relative '../../util/spec_helper'

include Logging

describe 'Blue form fill out tasks' do

  begin

    @driver = Utils.launch_browser
    @blue = Page::BluePage.new @driver
    @cal_net = Page::CalNetPage.new @driver

    @blue.log_in @cal_net

    question_bank = OecUtils.open_question_bank
    forms = OecUtils.get_forms
    forms.each do |form|

      begin
        logger.info "Checking #{form}"
        @blue.load_project OecUtils.blue_project_title
        results = @blue.search_for_fill_out_form_tasks(form[:dept_code], form[:eval_type])

        if results.zero?
          logger.warn "No tasks found for #{form}, skipping"

        else
          @blue.open_fill_out_form_task @driver
          questions = OecUtils.get_form_questions(question_bank, form)
          questions.each do |q|

            question_present = @blue.verify_question(@driver, form, q)
            it "show a #{form} question of category #{q[:category]}, type #{q[:type]}, text #{q[:question]}, options #{q[:options]}, nested question of type #{q[:sub_type]}, text #{q[:sub_question]}, sub-options #{q[:sub_options]}" do
              expect(question_present).to be true
            end

          end
        end

      rescue => e
        Utils.log_error e
        it("caused an unexpected error with #{form}") { fail }
      ensure
        @blue.close_form @driver
      end
    end
  rescue => e
    Utils.log_error e
    it('caused an unexpected error when initializing') { fail }
  end
end
