require_relative '../../util/spec_helper'

include Logging

describe 'Blue form fill out tasks' do

  # Optionally specify a single evaluation form; otherwise, all forms will be tested.
  dept_form = ENV['FORM']

  begin

    question_bank = OecUtils.open_question_bank
    it('agree on the expected form types and those defined in the question bank') { expect(OecUtils.verify_all_forms_present question_bank).to be true }

    forms = OecUtils.get_forms
    form_codes = forms.map { |f| OecUtils.get_form_code f }

    # Track which forms have been tested or not, since depts might activate evals at different times
    forms_checked = []
    forms_not_checked = []

    if dept_form && !form_codes.include?(dept_form)
      it("do not recognize #{dept_form}") { fail }

    else
      @driver = Utils.launch_browser
      @blue = Page::BluePage.new @driver
      @cal_net = Page::CalNetPage.new @driver

      @blue.log_in @cal_net

      forms.each do |form|
        begin

          if (dept_form == OecUtils.get_form_code(form)) || !dept_form
            logger.info "Checking #{form}"
            @blue.load_project OecUtils.blue_project_title
            results = @blue.search_for_fill_out_form_tasks form

            if results.zero?
              logger.warn "No tasks found for #{form}, skipping"
              forms_not_checked << form
              it("are not present for #{form}, unable to perform any tests") { fail }

            else
              @blue.open_fill_out_form_task(@driver, form)
              forms_checked << form

              questions = OecUtils.get_form_questions(question_bank, form)
              questions.each do |q|
                begin

                  question_present = @blue.verify_question(@driver, form, q)
                  it "show a #{form} question of category #{q[:category]}, type #{q[:type]}, text '#{q[:question]}', options #{q[:options]}, sub-question type #{q[:sub_type]}, sub-question text '#{q[:sub_question]}', sub-question options #{q[:sub_options]}" do
                    expect(question_present).to be true
                  end

                rescue => e
                  Utils.log_error e
                  it("caused an unexpected error with #{form} question #{q[:question]}") { fail }
                end
              end

              question_count_right = @blue.verify_question_count questions
              it("show the right question count for #{form}") { expect(question_count_right).to be true }

            end
          else
            logger.warn "Skipping #{form}"
          end
        rescue => e
          Utils.log_error e
          it("caused an unexpected error with #{form}") { fail }
        ensure
          @blue.close_form @driver
        end
      end
      logger.warn "Forms checked: #{forms_checked}"
      logger.warn "Forms not checked: #{forms_not_checked}"
    end
  rescue => e
    Utils.log_error e
    it('caused an unexpected error when initializing') { fail }
  end
end
