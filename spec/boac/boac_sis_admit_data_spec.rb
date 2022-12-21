require_relative '../../util/spec_helper'

unless ENV['DEPS']

  test = BOACTestConfig.new
  test.admit_pages

  all_admit_data = NessieUtils.get_admit_page_data
  test_sids = test.test_students.map &:sis_id
  admit_data = all_admit_data.select { |d| test_sids.include? d[:cs_empl_id] }
  latest_update_date = NessieUtils.get_admit_data_update_date
  all_student_sids = NessieUtils.get_all_students.map &:sis_id

  describe 'The BOA admit page' do

    include Logging

    begin

      # Sanity test the data
      all_admit_data.first.each_key do |k|
        values = all_admit_data.collect { |d| d[k] }
        it("has at least some data for field #{k}") { expect(values).not_to be_empty }
      end

      @driver = Utils.launch_browser
      @homepage = BOACHomePage.new @driver
      @admit_page = BOACAdmitPage.new @driver
      @student_page = BOACStudentPage.new @driver
      @homepage.dev_auth test.advisor

      admit_data.each do |admit|

        begin
          @admit_page.load_page admit[:cs_empl_id]

          update_date_present = @admit_page.data_update_date_heading(latest_update_date).exists?
          if Date.parse(latest_update_date) == Date.today
            it("shows no update date for CS ID #{admit[:cs_empl_id]}") { expect(update_date_present).to be false }
          else
            it("shows the most recent data update date for CS ID #{admit[:cs_empl_id]}") { expect(update_date_present).to be true }
          end

          visible_name = @admit_page.name
          expected_name = @admit_page.concatenated_name admit
          it("shows the name of CS ID #{admit[:cs_empl_id]}") { expect(visible_name).to eql(expected_name) }

          visible_applicant_id = @admit_page.uc_cpid
          it("shows the ApplyUC CPID of CS ID #{admit[:cs_empl_id]}") { expect(visible_applicant_id).to eql(admit[:applyuc_cpid]) }

          visible_cs_empl_id = @admit_page.sid
          it("shows the CS Empl ID of CS ID #{admit[:cs_empl_id]}") { expect(visible_cs_empl_id).to eql(admit[:cs_empl_id]) }

          visible_birth_date = @admit_page.birth_date
          nessie_date = admit[:birthdate]
          if nessie_date.include? '/'
            parts = nessie_date.split '/'
            year = (parts.last.to_i > Date.today.year.to_s[-2, 2].to_i) ? ((Date.today.year - 100).to_s[0..1] + parts.last) : parts.last
            nessie_date = "#{year}-#{parts[0]}-#{parts[1]}"
          end
          expected_birth_date = Time.parse(nessie_date).strftime('%b %-d, %Y')
          it("shows the birth date of CS ID #{admit[:cs_empl_id]}") { expect(visible_birth_date).to eql(expected_birth_date) }

          visible_fresh_trans = @admit_page.fresh_trans
          it("shows the freshman or transfer status of CS ID #{admit[:cs_empl_id]}") { expect(visible_fresh_trans).to eql(admit[:freshman_or_transfer]) }

          visible_status = @admit_page.status
          it("shows the admit status of CS ID #{admit[:cs_empl_id]}") { expect(visible_status).to eql(admit[:admit_status]) }

          visible_sir = @admit_page.sir
          it("shows the current SIR status of CS ID #{admit[:cs_empl_id]}") { expect(visible_sir).to eql(admit[:current_sir]) }

          visible_college = @admit_page.college
          it("shows the college of CS ID #{admit[:cs_empl_id]}") { expect(visible_college).to eql(admit[:college]) }

          visible_term = @admit_page.term
          it("shows the admit term of CS ID #{admit[:cs_empl_id]}") { expect(visible_term).to eql(admit[:admit_term]) }

          visible_email = @admit_page.email
          it("shows the email of CS ID #{admit[:cs_empl_id]}") { expect(visible_email).to eql(admit[:email]) }

          visible_campus_email = @admit_page.campus_email
          it("shows the campus email of CS ID #{admit[:cs_empl_id]}") { expect(visible_campus_email).to eql(admit[:campus_email_1]) }

          visible_phone = @admit_page.daytime_phone
          it("shows the daytime phone of CS ID #{admit[:cs_empl_id]}") { expect(visible_phone).to eql(admit[:daytime_phone]) }

          visible_mobile = @admit_page.mobile
          it("shows the mobile phone of CS ID #{admit[:cs_empl_id]}") { expect(visible_mobile).to eql(admit[:mobile]) }

          visible_address_1 = @admit_page.address_street_1
          it "shows the address street 1 of CS ID #{admit[:cs_empl_id]}"  do
            expect(visible_address_1).to eql(admit[:permanent_street_1].gsub('  ', ' '))
          end

          visible_address_2 = @admit_page.address_street_2
          it "shows the address street 2 of CS ID #{admit[:cs_empl_id]}" do
            expect(visible_address_2).to eql(admit[:permanent_street_2].gsub('  ', ' '))
          end

          visible_city_etc = @admit_page.address_city_region_postal
          it("shows the address city / region / post code of CS ID #{admit[:cs_empl_id]}") do
            expected = "#{admit[:permanent_city]&.strip}, #{+admit[:permanent_region].strip + ' ' if admit[:permanent_region]}#{admit[:permanent_postal]&.strip}"
            expect(visible_city_etc).to eql(expected.gsub('  ', ' '))
          end

          visible_country = @admit_page.address_country
          it("shows the address country of CS ID #{admit[:cs_empl_id]}") { expect(visible_country).to eql(admit[:permanent_country]) }

          visible_gender_id = @admit_page.gender_identity
          it("shows the gender identity of CS ID #{admit[:cs_empl_id]}") { expect(visible_gender_id).to eql(admit[:gender_identity]) }

          visible_x_ethnic = @admit_page.x_ethnic
          it("shows the x-ethnic status of CS ID #{admit[:cs_empl_id]}") { expect(visible_x_ethnic).to eql(admit[:xethnic]) }

          visible_hispanic = @admit_page.hispanic
          it("shows the hispanic status of CS ID #{admit[:cs_empl_id]}") { expect(visible_hispanic).to eql(admit[:hispanic]) }

          visible_urem = @admit_page.urem
          it("shows the UREM of CS ID #{admit[:cs_empl_id]}") { expect(visible_urem).to eql(admit[:urem]) }

          visible_residency = @admit_page.residency_cat
          it("shows the residency category of CS ID #{admit[:cs_empl_id]}") { expect(visible_residency).to eql(admit[:residency_category]) }

          visible_citizen_status = @admit_page.citizen_status
          it("shows the US citizenship status of CS ID #{admit[:cs_empl_id]}") { expect(visible_citizen_status).to eql(admit[:us_citizenship_status]) }

          visible_non_citizen_status = @admit_page.non_citizen_status
          it("shows the US non-citizenship status of CS ID #{admit[:cs_empl_id]}") { expect(visible_non_citizen_status).to eql(admit[:us_non_citizen_status]) }

          visible_citizenship = @admit_page.citizenship
          it("shows the citizenship country of CS ID #{admit[:cs_empl_id]}") { expect(visible_citizenship).to eql(admit[:citizenship_country]) }

          visible_residence_country = @admit_page.residence_country
          it("shows the permanent residency country of CS ID #{admit[:cs_empl_id]}") { expect(visible_residence_country).to eql(admit[:permanent_residence_country]) }

          visible_visa_status = @admit_page.visa_status
          it("shows the non-immigrant visa current status of CS ID #{admit[:cs_empl_id]}") { expect(visible_visa_status).to eql(admit[:non_immigrant_visa_current]) }

          visible_visa_planned = @admit_page.visa_planned
          it("shows the non-immigrant visa planned status of CS ID #{admit[:cs_empl_id]}") { expect(visible_visa_planned).to eql(admit[:non_immigrant_visa_planned]) }

          visible_first_gen_college = @admit_page.first_gen_college
          it("shows the first generation college status of CS ID #{admit[:cs_empl_id]}") { expect(visible_first_gen_college).to eql(admit[:first_generation_college]) }

          visible_parent_1_educ = @admit_page.parent_1_educ
          it("shows the parent 1 education level of CS ID #{admit[:cs_empl_id]}") { expect(visible_parent_1_educ).to eql(admit[:parent_1_education_level]) }

          visible_parent_2_educ = @admit_page.parent_2_educ
          it("shows the parent 2 education level of CS ID #{admit[:cs_empl_id]}") { expect(visible_parent_2_educ).to eql(admit[:parent_2_education_level]) }

          visible_parent_highest_educ = @admit_page.parent_highest_educ
          it("shows the highest parent education level of CS ID #{admit[:cs_empl_id]}") { expect(visible_parent_highest_educ).to eql(admit[:highest_parent_education_level]) }

          visible_gpa_hs_unweighted = @admit_page.gpa_hs_unweighted
          it("shows the high school unweighted GPA of CS ID #{admit[:cs_empl_id]}") { expect(visible_gpa_hs_unweighted).to eql(admit[:hs_unweighted_gpa]) }

          visible_gpa_hs_weighted = @admit_page.gpa_hs_weighted
          it("shows the high school weighted GPA of CS ID #{admit[:cs_empl_id]}") { expect(visible_gpa_hs_weighted).to eql(admit[:hs_weighted_gpa]) }

          visible_gpa_transfer = @admit_page.gpa_transfer
          it("shows the transfer GPA of CS ID #{admit[:cs_empl_id]}") { expect(visible_gpa_transfer).to eql(admit[:transfer_gpa]) }

          visible_fee_waiver = @admit_page.fee_waiver
          it("shows the application fee waiver status of CS ID #{admit[:cs_empl_id]}") { expect(visible_fee_waiver).to eql(admit[:application_fee_waiver_flag]) }

          visible_foster_care = @admit_page.foster_care
          it("shows the foster care status of CS ID #{admit[:cs_empl_id]}") { expect(visible_foster_care).to eql(admit[:foster_care_flag]) }

          visible_family_single_parent = @admit_page.family_single_parent
          it("shows the family-is-single-parent status of CS ID #{admit[:cs_empl_id]}") { expect(visible_family_single_parent).to eql(admit[:family_is_single_parent]) }

          visible_student_single_parent = @admit_page.student_single_parent
          it("shows the student-is-single-parent status of CS ID #{admit[:cs_empl_id]}") { expect(visible_student_single_parent).to eql(admit[:student_is_single_parent]) }

          visible_family_dependents = @admit_page.family_dependents
          it("shows the family dependent count of CS ID #{admit[:cs_empl_id]}") { expect(visible_family_dependents).to eql(admit[:family_dependents_num]) }

          visible_student_dependents = @admit_page.student_dependents
          it("shows the student dependent count of CS ID #{admit[:cs_empl_id]}") { expect(visible_student_dependents).to eql(admit[:student_dependents_num]) }

          visible_family_income = @admit_page.family_income
          expected_family_income = admit[:family_income].empty? ? '' : "$#{Utils.int_to_s_with_commas admit[:family_income].to_i}"
          it("shows the family income of CS ID #{admit[:cs_empl_id]}") { expect(visible_family_income).to eql(expected_family_income) }

          visible_student_income = @admit_page.student_income
          expected_student_income = admit[:student_income].empty? ? '' : "$#{Utils.int_to_s_with_commas admit[:student_income].to_i}"
          it("shows the student income of CS ID #{admit[:cs_empl_id]}") { expect(visible_student_income).to eql(expected_student_income) }

          visible_military_dependent = @admit_page.military_dependent
          it("shows the military dependent status of CS ID #{admit[:cs_empl_id]}") { expect(visible_military_dependent).to eql(admit[:is_military_dependent]) }

          visible_military_status = @admit_page.military_status
          it("shows the military status of CS ID #{admit[:cs_empl_id]}") { expect(visible_military_status).to eql(admit[:military_status]) }

          visible_re_entry_status = @admit_page.re_entry_status
          it("shows the re-entry status of CS ID #{admit[:cs_empl_id]}") { expect(visible_re_entry_status).to eql(admit[:reentry_status]) }

          visible_athlete_status = @admit_page.athlete_status
          it("shows the athlete status of CS ID #{admit[:cs_empl_id]}") { expect(visible_athlete_status).to eql(admit[:athlete_status]) }

          visible_summer_bridge_status = @admit_page.summer_bridge_status
          it("shows the Summer Bridge status of CS ID #{admit[:cs_empl_id]}") { expect(visible_summer_bridge_status).to eql(admit[:summer_bridge_status]) }

          visible_last_school_lcff_plus = @admit_page.last_school_lcff_plus
          it("shows the last school LCFF+ status of CS ID #{admit[:cs_empl_id]}") { expect(visible_last_school_lcff_plus).to eql(admit[:last_school_lcff_plus_flag]) }

          visible_special_pgm_cep = @admit_page.special_pgm_cep
          it("shows the special program CEP status of CS ID #{admit[:cs_empl_id]}") { expect(visible_special_pgm_cep).to eql(admit[:special_program_cep]) }

          student_page_link_present = @admit_page.student_page_link(admit).exists?
          if all_student_sids.include? admit[:cs_empl_id]
            it("shows a link to the student page for CS ID #{admit[:cs_empl_id]}") { expect(student_page_link_present).to be true }
          else
            it("shows no link to the student page for CS ID #{admit[:cs_empl_id]}") { expect(student_page_link_present).to be false }
          end

          if student_page_link_present
            student_page_link_works = @admit_page.verify_block do
              @admit_page.click_student_page_link admit
              @student_page.wait_until(Utils.short_wait) { @student_page.sid.include? "SID #{admit[:cs_empl_id]}" }
            end
            it("links to the student page for CS ID #{admit[:cs_empl_id]}") { expect(student_page_link_works).to be true }
          end

        rescue => e
          Utils.log_error e
          it("tests hit an error with admit CS ID #{admit[:cs_empl_id]}") { fail }
        end
      end
    rescue => e
      Utils.log_error e
      it('tests hit an error initializing') { fail }
    ensure
      Utils.quit_browser @driver
    end
  end
end