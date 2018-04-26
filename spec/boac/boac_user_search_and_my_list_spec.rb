require_relative '../../util/spec_helper'

describe 'BOAC' do

  include Logging

  athletes = BOACUtils.get_all_athletes
  active_athletes = athletes.select { |a| a.status == 'active' }
  inactive_athletes = athletes.select { |a| a.status == 'inactive' }

  squads = BOACUtils.get_squads

  before(:all) do
    @driver = Utils.launch_browser
    @homepage = Page::BOACPages::HomePage.new @driver
    @student_page = Page::BOACPages::StudentPage.new @driver
    @homepage.dev_auth
  end

  after(:all) { Utils.quit_browser @driver }

  describe 'user search' do

    context 'when the search input is clicked' do

      before(:all) { @homepage.click_user_search_input }

      # Check that all active athletes appear under their squads, multi-sport athletes being listed under each.
      squads.each do |s|
        it("shows all active #{s.name} members") do
          squad_members = BOACUtils.get_squad_members([s], active_athletes)
          squad_members.each do |m|
            logger.debug "Looking for #{s.name} member #{m.uid}"
            @homepage.wait_until(Utils.short_wait, "Unable to find #{s.name} member #{m.uid}") { @homepage.squad_user_option(s, m).exists? }
          end
        end
      end

      # Check that inactive athletes appear nowhere in the search options.
      inactive_athletes.each do |a|
        it("does not show inactive athlete #{a.full_name}") do
          logger.debug "Making sure inactive athlete #{a.uid} is not present in user search"
          @homepage.wait_until(1, "Inactive athlete #{a.uid} is visible") { !@homepage.user_option(a).exists? }
        end
      end
    end

    context 'when a first name' do

      # Find a user with a first name of reasonable length
      before(:all) { @test_user = active_athletes.find { |a| 5 <= a.first_name.length && a.first_name.length <= 10 } }

      it 'finds a user with the complete first name' do
        @homepage.enter_search_string "#{@test_user.full_name}"
        @homepage.user_option(@test_user).when_visible Utils.short_wait
      end

      it 'finds a user with the first part of the first name' do
        string = @test_user.first_name[0..2].downcase
        @homepage.enter_search_string string
        @homepage.user_option(@test_user).when_visible 2
        @homepage.wait_until(2, "Visible user options are '#{@homepage.visible_user_options}'") do
          @homepage.visible_user_options.all? { |o| o.downcase.include? string }
        end
      end

      it 'cannot find a user with the last part of the first name' do
        string = @test_user.first_name[2..-1]
        @homepage.enter_search_string string
        @homepage.user_option(@test_user).when_not_visible 2
        @homepage.wait_until(2, "Visible user options are '#{@homepage.visible_user_options}'") do
          @homepage.visible_user_options.all? { |o| o.downcase.include? string }
        end if @homepage.visible_user_options.any?
      end
    end

    context 'when a last name' do

      # Find a user with a last name of reasonable length
      before(:all) { @test_user = active_athletes.find { |a| 5 <= a.last_name.length && a.last_name.length <= 10 } }

      it 'finds a user with the complete last name' do
        @homepage.enter_search_string "#{@test_user.full_name}"
        @homepage.user_option(@test_user).when_visible Utils.short_wait
      end

      it 'finds a user with the first part of the last name' do
        string = @test_user.last_name[0..2].downcase
        @homepage.enter_search_string string
        @homepage.user_option(@test_user).when_visible 2
        @homepage.wait_until(2, "Visible user options are '#{@homepage.visible_user_options}'") do
          @homepage.visible_user_options.all? { |o| o.downcase.include? string }
        end
      end

      it 'cannot find a user with the last part of the last name' do
        string = @test_user.last_name[2..-1]
        @homepage.enter_search_string string
        @homepage.user_option(@test_user).when_not_visible 2
        @homepage.wait_until(2, "Visible user options are '#{@homepage.visible_user_options}'") do
          @homepage.visible_user_options.all? { |o| o.downcase.include? string }
        end if @homepage.visible_user_options.any?
      end
    end

    context 'when a special character' do

      before(:all) do
        @test_hyphen_user = active_athletes.find { |a| a.full_name.include? '-'}
        @test_apostrophe_user = active_athletes.find { |a| a.full_name.include? "'" }
      end

      it 'finds a user with a name including a hyphen' do
        if @test_hyphen_user
          @homepage.enter_search_string '-'
          @homepage.user_option(@test_hyphen_user).when_visible 2
        else
          logger.warn 'Unable to test a user with a hyphen cuz unable to find one'
        end
      end

      it 'finds a user with a name including an apostrophe' do
        if @test_apostrophe_user
          @homepage.enter_search_string "'"
          @homepage.user_option(@test_apostrophe_user).when_visible 2
        else
          logger.warn 'Unable to test a user with an apostrophe cuz unable to find one'
        end
      end
    end

    context 'when a user option is clicked' do

      before(:all) { @test_user = active_athletes.find { |a| 5 <= a.first_name.length && a.first_name.length <= 10 } }

      it 'loads the student page' do
        @homepage.enter_search_string "#{@test_user.full_name}"
        @homepage.wait_for_update_and_click @homepage.user_option(@test_user)
        @student_page.wait_until { @student_page.current_url == "#{BOACUtils.base_url}/student/#{@test_user.uid}" }
      end
    end
  end

  describe 'My List' do

    before(:all) do
      @cohort_page = Page::BOACPages::CohortPages::FilteredCohortListViewPage.new @driver
      @student_page = Page::BOACPages::StudentPage.new @driver
      # Get test users for My List
      @cohort = FilteredCohort.new({:search_criteria => CohortSearchCriteria.new({:squads => [Squad::MGO_AA]})})
      students = active_athletes.select { |a| a.sports.include? @cohort.search_criteria.squads.first.code }
      @student_1 = students[0]
      @student_2 = students[1]
      @student_3 = active_athletes.find { |a| a.sports.include? Squad::WGO_AA.code }

      # Get rid of any test users currently on My List
      @homepage.remove_all_from_watchlist
    end

    it('shows a user a "nobody\'s on your list" message for an empty My List') { @homepage.my_list_no_users_msg_element.when_present Utils.short_wait }

    it 'allows a user to add students on the cohort page' do
      @cohort_page.click_sidebar_create_filtered
      @cohort_page.perform_search @cohort
      @cohort_page.wait_for_search_results
      @cohort_page.add_user_to_watchlist @student_1
      @cohort_page.add_user_to_watchlist @student_2
    end

    it 'allows a user to add a student on the student page' do
      @student_page.load_page @student_3
      @student_page.add_user_to_watchlist @student_3
    end

    it 'allows a user to view its list on the landing page' do
      @homepage.load_page
      [@student_1, @student_2, @student_3].each { |s| @homepage.curated_cohort_user_row(s).when_present Utils.short_wait }
    end

    it('allows a user to remove a student on the landing page') { @homepage.remove_curated_cohort_member @student_1 }

    it 'allows a user to remove students on the cohort page' do
      @cohort_page.click_sidebar_create_filtered
      @cohort_page.perform_search @cohort
      @cohort_page.wait_for_search_results
      @cohort_page.remove_curated_cohort_member @student_2
    end

    it 'allows a user to remove a student on the student page' do
      @student_page.load_page @student_3
      @student_page.remove_curated_cohort_member @student_3
    end

  end
end
