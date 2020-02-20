require_relative '../../util/spec_helper'

describe 'BOA non-current students' do

  before(:all) do
    @test = BOACTestConfig.new
    @test.inactive_students

    @driver = Utils.launch_browser
    @homepage = BOACHomePage.new @driver
    @search_results_page = BOACSearchResultsPage.new @driver
    @student_page = BOACStudentPage.new @driver
    @group_page = BOACGroupPage.new @driver
    @cohort_page = BOACFilteredCohortPage.new(@driver, @test.advisor)
    @api_student_page = BOACApiStudentPage.new @driver

    @homepage.dev_auth @test.advisor

    # Get an inactive non-current student who has not yet received the VIP treatment
    inactive_sid = (NessieUtils.hist_profile_sids_of_career_status('Inactive') - BOACUtils.manual_advisee_sids).first
    @inactive_student = NessieUtils.get_hist_student inactive_sid
    @inactive_api_student_page = BOACApiStudentPage.new @driver
    @inactive_api_student_page.get_data(@driver, @inactive_student)
    @inactive_api_student_page.set_identity @inactive_student
    @inactive_student_profile = @inactive_api_student_page.sis_profile_data
    @inactive_student_profile[:academic_career_status] == 'Inactive'

    # Get a completed non-current student who has not yet received the VIP treatment
    completed_sid = (NessieUtils.hist_profile_sids_of_career_status('Completed') - BOACUtils.manual_advisee_sids).first
    @completed_student = NessieUtils.get_hist_student completed_sid
    @completed_api_student_page = BOACApiStudentPage.new @driver
    @completed_api_student_page.get_data(@driver, @completed_student)
    @completed_api_student_page.set_identity @completed_student
    @completed_student_profile = @completed_api_student_page.sis_profile_data
    @completed_student_profile[:academic_career_status] == 'Completed'
  end

  after(:all) { Utils.quit_browser @driver }

  it('are plentiful') { expect(NessieUtils.hist_profile_sids.length).to be > 275000 }

  it('include some with an Active academic career status') { expect(NessieUtils.hist_career_status_count 'Active').to be > 0 }
  it('include some with an Inactive academic career status') { expect(NessieUtils.hist_career_status_count 'Inactive').to be > 0 }
  it('include some with a Completed academic career status') { expect(NessieUtils.hist_career_status_count 'Inactive').to be > 0 }
  it('include none with an unexpected academic career status') { expect(NessieUtils.unexpected_hist_career_status_count).to be_zero }

  it('include some with an Active program status') { expect(NessieUtils.hist_prog_status_count 'Active').to be > 0 }
  it('include some with a Cancelled program status') { expect(NessieUtils.hist_prog_status_count 'Cancelled').to be > 0 }
  it('include some with a Completed Program program status') { expect(NessieUtils.hist_prog_status_count 'Completed Program').to be > 0 }
  it('include some with a Discontinued program status') { expect(NessieUtils.hist_prog_status_count 'Discontinued').to be > 0 }
  it('include some with a Dismissed program status') { expect(NessieUtils.hist_prog_status_count 'Dismissed').to be > 0 }
  it('include some with a Suspended program status') { expect(NessieUtils.hist_prog_status_count 'Suspended').to be > 0 }
  it('include none with an unexpected program status') { expect(NessieUtils.unexpected_hist_prog_status_count).to be_zero }

  it('include all those with historical term enrollments') { expect(NessieUtils.hist_enrollment_sids - NessieUtils.hist_profile_sids).to be_empty }
  it('include some with null academic career status and no historical term enrollments') { expect(NessieUtils.null_hist_career_status_sids - NessieUtils.hist_enrollment_sids).not_to be_empty }

  context 'when on the manually added advisee list' do

    it('have completed data') { expect(BOACUtils.deluxe_manual_advisee_sids & (@test.searchable_data.map { |d| d[:sid] })).not_to be_empty }
  end

  context 'when inactive' do

    context 'and searched for' do

      before(:all) { @homepage.load_page }

      it 'can be found by SID' do
        @homepage.type_non_note_string_and_enter @inactive_student.sis_id
        expect(@search_results_page.student_in_search_result?(@driver, @inactive_student)).to be true
      end

      it('are added to a queue for nightly data refresh') { expect(BOACUtils.student_in_deluxe_list? @inactive_student).to be true }
    end

    context 'and viewed on the student page' do

      before(:all) do
        @search_results_page.click_student_result @inactive_student
        @student_page.wait_for_title @inactive_student.full_name
        @visible_profile_data = @student_page.visible_sis_data
      end

      it('show a name') { expect(@visible_profile_data[:name]).to eql(@inactive_student.full_name) }
      it('show an inactive indicator') { expect(@visible_profile_data[:inactive]).to be true }
      it('show no email') { expect(@visible_profile_data[:email]).to be_nil }
      it('show no phone') { expect(@visible_profile_data[:phone]).to be_nil }
      it('show a GPA if one exists') { expect(@visible_profile_data[:cumulative_gpa]).to eql(@inactive_student_profile[:cumulative_gpa]) }
      it('offer no class page links') { expect(@student_page.class_page_link_elements).to be_empty }
    end
  end

  context 'when completed' do

    context 'and searched for' do

      before(:all) { @homepage.load_page }

      it 'can be found by SID' do
        @homepage.type_non_note_string_and_enter @completed_student.sis_id
        expect(@search_results_page.student_in_search_result?(@driver, @completed_student)).to be true
      end

      it('are added to a queue for nightly data refresh') { expect(BOACUtils.student_in_deluxe_list? @completed_student).to be true }
    end

    context 'and viewed on the student page' do

      before(:all) do
        @search_results_page.click_student_result @completed_student
        @student_page.wait_for_title @completed_student.full_name
        @visible_profile_data = @student_page.visible_sis_data
      end

      it('show a name') { expect(@visible_profile_data[:name]).to eql(@completed_student.full_name) }
      it('show no inactive indicator') { expect(@visible_profile_data[:inactive]).to be false }
      it('show no email') { expect(@visible_profile_data[:email]).to be_nil }
      it('show no phone') { expect(@visible_profile_data[:phone]).to be_nil }
      it('show a GPA if one exists') { expect(@visible_profile_data[:cumulative_gpa]).to eql(@completed_student_profile[:cumulative_gpa]) }
      it('show a degree') { expect(@visible_profile_data[:graduation_degree]).to include(@completed_student_profile[:graduation][:majors].join(', ')) }
      it('show a graduation date') { expect(@visible_profile_data[:graduation_date]).to eql('Awarded ' + Date.parse(@completed_student_profile[:graduation][:date]).strftime('%b %e, %Y')) }
      it('show a graduation colleges') { expect(@visible_profile_data[:graduation_colleges]).to eql(@completed_student_profile[:graduation][:colleges]) }
      it('offer no class page links') { expect(@student_page.class_page_link_elements).to be_empty }
    end
  end

  context 'on a curated group' do

    before(:all) { @group = CuratedGroup.new(name: "Non-current group #{@test.id}") }

    it 'can be added to a new group' do
      @homepage.click_sidebar_create_curated_group
      @group_page.create_group_with_bulk_sids([@inactive_student], @group)
      @group_page.wait_for_sidebar_group @group
    end

    it 'can be added from a student page' do
      @student_page.load_page @completed_student
      @student_page.add_student_to_grp(@completed_student, @group)
    end
  end

end
