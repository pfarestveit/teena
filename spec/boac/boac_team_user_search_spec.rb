require_relative '../../util/spec_helper'

describe 'BOAC' do

  include Logging

  team = BOACUtils.user_search_team
  athletes = BOACUtils.get_team_members team
  active_athletes = athletes.select { |a| a.status == 'active' }
  inactive_athlete = athletes.find { |a| a.status == 'inactive' }

  asc_advisor = BOACUtils.get_dept_advisors(BOACDepartments::ASC).first
  non_asc_advisor = BOACUtils.get_dept_advisors(BOACDepartments::COE).first

  before(:all) do
    @driver = Utils.launch_browser
    @homepage = Page::BOACPages::HomePage.new @driver
    @search_page = Page::BOACPages::SearchResultsPage.new @driver
    @student_page = Page::BOACPages::StudentPage.new @driver
    @homepage.dev_auth
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'search' do

    after(:all) { @homepage.log_out }

    active_athletes.each do |a|

      it "finds UID #{a.uid} with the complete first name" do
        result_count = @search_page.search a.first_name
        expect(@search_page.student_in_search_result?(@driver, a, result_count)).to be true
      end

      it "finds UID #{a.uid} with a partial first name" do
        result_count = @search_page.search a.first_name[0..2]
        expect(@search_page.student_in_search_result?(@driver, a, result_count)).to be true
      end

      it "finds UID #{a.uid} with the complete last name" do
        result_count = @search_page.search a.last_name
        expect(@search_page.student_in_search_result?(@driver, a, result_count)).to be true
      end

      it "finds UID #{a.uid} with a partial last name" do
        result_count = @search_page.search a.last_name[0..2]
        expect(@search_page.student_in_search_result?(@driver, a, result_count)).to be true
      end

      it "finds UID #{a.uid} with the complete first and last name" do
        result_count = @search_page.search "#{a.first_name} #{a.last_name}"
        expect(@search_page.student_in_search_result?(@driver, a, result_count)).to be true
      end

      it "finds UID #{a.uid} with the complete last and first name" do
        result_count = @search_page.search "#{a.last_name}, #{a.first_name}"
        expect(@search_page.student_in_search_result?(@driver, a, result_count)).to be true
      end

      it "finds UID #{a.uid} with a partial first and last name" do
        result_count = @search_page.search "#{a.first_name[0..2]} #{a.last_name[0..2]}"
        expect(@search_page.student_in_search_result?(@driver, a, result_count)).to be true
      end

      it "finds UID #{a.uid} with a partial last and first name" do
        result_count = @search_page.search "#{a.last_name[0..2]}, #{a.first_name[0..2]}"
        expect(@search_page.student_in_search_result?(@driver, a, result_count)).to be true
      end

      it "finds UID #{a.uid} with the complete SID" do
        result_count = @search_page.search a.sis_id.to_s
        expect(@search_page.student_in_search_result?(@driver, a, result_count)).to be true
      end

      it "finds UID #{a.uid} with a partial SID" do
        result_count = @search_page.search a.sis_id.to_s[0..4]
        expect(@search_page.student_in_search_result?(@driver, a, result_count)).to be true
      end
    end

    it 'limits results to 50' do
      expect(@search_page.search '303').to be > 50
      expect(@search_page.student_row_sids.length).to eql(50)
    end
  end

  context 'when an ASC advisor searches for students' do

    before { @homepage.dev_auth asc_advisor }
    after { @homepage.log_out }

    it 'does not return inactive athletes' do
      result_count = @search_page.search inactive_athlete.sis_id.to_s
      expect(result_count).to eql(0)
    end
  end

  context 'when a non-ASC advisor searches for students' do

    before { @homepage.dev_auth non_asc_advisor }
    after { @homepage.log_out }

    it 'returns inactive athletes' do
      result_count = @search_page.search inactive_athlete.sis_id.to_s
      expect(@search_page.student_in_search_result?(@driver, inactive_athlete, result_count)).to be true
    end
  end
end
