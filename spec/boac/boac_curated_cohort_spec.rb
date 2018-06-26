require_relative '../../util/spec_helper'

describe 'BOAC', order: :defined do

  include Logging

  test_id = Utils.get_test_id
  advisor = BOACUtils.get_dept_advisors(BOACDepartments::ASC).first
  advisor_cohorts = []
  other_advisor = BOACUtils.get_authorized_users.find { |u| u.uid != advisor.uid }
  pre_existing_cohorts = BOACUtils.get_user_curated_cohorts advisor
  team = BOACUtils.curated_cohort_team
  students = BOACUtils.get_team_members(team).delete_if { |s| s.status == 'inactive' }

  before(:all) do
    @driver = Utils.launch_browser

    @cohort_1 = CuratedCohort.new({:name => "Cohort 1 #{test_id}"})
    @cohort_2 = CuratedCohort.new({:name => "Cohort 2 #{test_id}"})
    @cohort_3 = CuratedCohort.new({:name => "Cohort 3 #{test_id}"})
    @cohort_4 = CuratedCohort.new({:name => "Cohort 4 #{test_id}"})

    @analytics_page = ApiUserAnalyticsPage.new @driver
    @homepage = Page::BOACPages::HomePage.new @driver
    @curated_page = Page::BOACPages::CohortPages::CuratedCohortListViewPage.new @driver
    @filtered_page = Page::BOACPages::CohortPages::FilteredCohortListViewPage.new @driver
    @student_page = Page::BOACPages::StudentPage.new @driver
    @homepage.dev_auth advisor
  end

  after(:all) { Utils.quit_browser @driver }

  it('curated cohorts can all be deleted') { pre_existing_cohorts.each { |c| @curated_page.delete_curated c } }

  it 'shows a No Curated Cohorts message on the homepage when no curated cohorts exist' do
    @homepage.load_page
    @homepage.home_no_curated_cohorts_msg_element.when_visible Utils.short_wait
  end

  describe 'curated cohort creation' do

    # Some 'create' links only appear when there are no other curated cohorts, so get rid of existing ones prior to each example
    before(:all) do
      @cohorts_created = []
      @disposable_cohort_1 = CuratedCohort.new({:name => "Homepage Create-a-new-curated-cohort link #{test_id}"})
      @disposable_cohort_2 = CuratedCohort.new({:name => "Homepage Create link #{test_id}"})
      @disposable_cohort_3 = CuratedCohort.new({:name => "Sidebar + link #{test_id}"})
      @disposable_cohort_4 = CuratedCohort.new({:name => "Manage Curated Cohorts Create-a-new-curated-cohort link #{test_id}"})
      @disposable_cohort_5 = CuratedCohort.new({:name => "Filtered cohort list view curated cohort selector #{test_id}"})
    end

    before(:each) do
      @cohorts_created.each { |c| @curated_page.delete_curated c }
      @cohorts_created.clear
      @homepage.load_page
    end

    it 'can be done using the homepage "Creat a new curated cohort link"' do
      @homepage.home_create_first_curated @disposable_cohort_1
      @cohorts_created << @disposable_cohort_1
    end

    it 'can be done using the homepage "Create" link' do
      @homepage.home_create_curated @disposable_cohort_2
      @cohorts_created << @disposable_cohort_2
    end

    it 'can be done using the sidebar "+" link' do
      @homepage.sidebar_create_curated @disposable_cohort_3
      @cohorts_created << @disposable_cohort_3
    end

    it 'can be done using the Manage Curated Cohorts "Create a new curated cohort" link' do
      @homepage.click_home_manage_curated
      @curated_page.manage_create_first_curated @disposable_cohort_4
      @cohorts_created << @disposable_cohort_4
    end

    it 'can be done using the filtered cohort list view curated cohort selector' do
      @filtered_page.load_team_page team
      @filtered_page.selector_add_students_to_new_curated(students, @disposable_cohort_5)
      @cohorts_created << @disposable_cohort_5
    end

    # TODO - it('can be created from the class page list view curated cohort selector')
    # TODO - it('can be created from search results curated cohort selector')

  end

  describe 'curated cohort names' do

    before(:all) do

      @homepage.load_page

      @existing_curated_cohort = CuratedCohort.new({:name => "Existing Curated Cohort #{test_id}"})
      @homepage.sidebar_create_curated @existing_curated_cohort

      @deleted_curated_cohort = CuratedCohort.new({:name => "Deleted Curated Cohort #{test_id}"})
      @homepage.sidebar_create_curated @deleted_curated_cohort
      @curated_page.delete_curated @deleted_curated_cohort

      @existing_filtered_cohort = FilteredCohort.new({:name => "Existing Filtered Cohort #{test_id}", :search_criteria => BOACUtils.get_test_search_criteria.first})
      @curated_page.click_sidebar_create_filtered
      @filtered_page.perform_search @existing_filtered_cohort
      @filtered_page.create_new_cohort @existing_filtered_cohort

      @new_curated_cohort = CuratedCohort.new({})
    end

    before(:each) { @homepage.cancel_curated_cohort }

    after(:all) do
      [@existing_curated_cohort, @new_curated_cohort].each { |c| @curated_page.delete_curated c }
    end

    it 'are required' do
      @homepage.sidebar_click_create_curated
      expect(@homepage.curated_save_button_element.disabled?).to be true
    end

    it 'are truncated to 255 characters' do
      @new_curated_cohort.name = "#{'A llooooong title ' * 15}?"
      @homepage.sidebar_click_create_curated
      @homepage.enter_curated_cohort_name @new_curated_cohort
      expect(@homepage.curated_name_input).to eql(@new_curated_cohort.name[0..254])
    end

    it 'must not match a non-deleted curated cohort belonging to the same advisor' do
      @new_curated_cohort.name = @existing_curated_cohort.name
      @homepage.sidebar_click_create_curated
      @homepage.name_and_save_curated_cohort @new_curated_cohort
      @homepage.dupe_curated_name_msg_element.when_visible Utils.short_wait
    end

    it 'must not match a non-deleted filtered cohort belonging to the same advisor' do
      @new_curated_cohort.name = @existing_filtered_cohort.name
      @homepage.sidebar_click_create_curated
      @homepage.name_and_save_curated_cohort @new_curated_cohort
      @homepage.dupe_filtered_name_msg_element.when_visible Utils.short_wait
    end

    it 'can be the same as a deleted cohort belonging to the same advisor' do
      @new_curated_cohort.name = @deleted_curated_cohort.name
      @homepage.sidebar_click_create_curated
      @homepage.name_and_save_curated_cohort @new_curated_cohort
      @homepage.wait_for_sidebar_curated @new_curated_cohort
    end

    it 'can be changed' do
      @curated_page.rename_curated(@new_curated_cohort, "#{@new_curated_cohort.name} Renamed")
    end
  end

  describe 'curated cohort membership' do

    before(:all) do

      @homepage.load_page
      [@cohort_1, @cohort_2, @cohort_3, @cohort_4].each do |c|
        @homepage.home_create_curated c
        advisor_cohorts << c
      end
    end

    it 'can be added from filtered cohort list view using select-all' do
      @filtered_page.load_team_page team
      @filtered_page.selector_add_all_students_to_curated @cohort_1
    end

    it 'can be added from filtered cohort list view using individual selections' do
      students.pop
      @filtered_page.load_team_page team
      @filtered_page.selector_add_students_to_curated(students, @cohort_2)
    end

    it 'can be added on the student page using the curated cohort box' do
      student = students.last
      @student_page.load_page student
      @student_page.add_student_to_curated(student, @cohort_3)
    end

    # TODO - it('can be added on class page list view using select-all')
    # TODO - it('can be added on class page list view using individual selections')

    it 'is shown on the curated cohort list view page' do
      @curated_page.load_page @cohort_1
      @curated_page.wait_for_student_list
      @curated_page.wait_until(Utils.short_wait) do
        logger.debug "Visible SIDs are #{@curated_page.list_view_uids}, and they should be #{@cohort_1.members.map(&:uid)}"
        @curated_page.list_view_uids == @cohort_1.members.map(&:uid)
      end
    end

    it 'is shown on the student page' do
      @student_page.load_page students.last
      @student_page.wait_until(Utils.short_wait) { @student_page.curated_selected? @cohort_1 }
      expect(@student_page.curated_selected? @cohort_2).to be true
      expect(@student_page.curated_selected? @cohort_3).to be true
      expect(@student_page.curated_selected? @cohort_4).to be false
    end

    it 'can be removed on the curated cohort list view page' do
      student = students.last
      @curated_page.load_page @cohort_2
      @curated_page.curated_remove_student(student, @cohort_2)
    end

    it 'can be removed on the student page using the curated cohort box' do
      student = students.first
      @student_page.load_page student
      @student_page.remove_student_from_curated(student, @cohort_1)
    end
  end

  describe 'curated cohort management' do

    it('can be reached from the sidebar') { @homepage.sidebar_click_manage_curated }

    it 'can be reached from the homepage' do
      @homepage.load_page
      @homepage.click_home_manage_curated
    end
  end

  describe 'curated cohorts' do

    before(:all) do
      @homepage.log_out
      @homepage.dev_auth other_advisor
    end

    it 'cannot be seen by a user who does not own them' do
      expect(@homepage.sidebar_curated_cohorts & advisor_cohorts.map(&:name)).to be_empty
    end

    it 'cannot be reached by a user who does not own them' do
      advisor_cohorts.each do |c|
        @curated_page.load_page c
        @curated_page.no_cohort_access_msg(other_advisor, c)
      end
    end

  end
end
