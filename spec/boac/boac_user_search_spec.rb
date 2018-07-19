require_relative '../../util/spec_helper'

describe 'BOAC' do

  include Logging

  test_config = BOACUtils.get_user_search_test_config
  # Avoid using ASC 'inactive' students since they won't be visible if the dept is ASC
  students = test_config.max_cohort_members.select { |s| ['active', nil].include? s.status }

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

    students.each do |s|

      it "finds UID #{s.uid} with the complete first name" do
        result_count = @search_page.search s.first_name
        expect(@search_page.student_in_search_result?(@driver, s, result_count)).to be true
      end

      it "finds UID #{s.uid} with a partial first name" do
        result_count = @search_page.search s.first_name[0..2]
        expect(@search_page.student_in_search_result?(@driver, s, result_count)).to be true
      end

      it "finds UID #{s.uid} with the complete last name" do
        result_count = @search_page.search s.last_name
        expect(@search_page.student_in_search_result?(@driver, s, result_count)).to be true
      end

      it "finds UID #{s.uid} with a partial last name" do
        result_count = @search_page.search s.last_name[0..2]
        expect(@search_page.student_in_search_result?(@driver, s, result_count)).to be true
      end

      it "finds UID #{s.uid} with the complete first and last name" do
        result_count = @search_page.search "#{s.first_name} #{s.last_name}"
        expect(@search_page.student_in_search_result?(@driver, s, result_count)).to be true
      end

      it "finds UID #{s.uid} with the complete last and first name" do
        result_count = @search_page.search "#{s.last_name}, #{s.first_name}"
        expect(@search_page.student_in_search_result?(@driver, s, result_count)).to be true
      end

      it "finds UID #{s.uid} with a partial first and last name" do
        result_count = @search_page.search "#{s.first_name[0..2]} #{s.last_name[0..2]}"
        expect(@search_page.student_in_search_result?(@driver, s, result_count)).to be true
      end

      it "finds UID #{s.uid} with a partial last and first name" do
        result_count = @search_page.search "#{s.last_name[0..2]}, #{s.first_name[0..2]}"
        expect(@search_page.student_in_search_result?(@driver, s, result_count)).to be true
      end

      it "finds UID #{s.uid} with the complete SID" do
        result_count = @search_page.search s.sis_id.to_s
        expect(@search_page.student_in_search_result?(@driver, s, result_count)).to be true
      end

      it "finds UID #{s.uid} with a partial SID" do
        result_count = @search_page.search s.sis_id.to_s[0..4]
        expect(@search_page.student_in_search_result?(@driver, s, result_count)).to be true
      end
    end

    it 'limits results to 50' do
      expect(@search_page.search '303').to be > 50
      expect(@search_page.student_row_sids.length).to eql(50)
    end
  end

end
