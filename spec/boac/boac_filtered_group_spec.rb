require_relative '../../util/spec_helper'

describe 'A BOA filtered cohort' do

  before(:all) do
    # Advisor logs in
  end

  context 'when a user has no groups' do

    it 'offers no group filter options' do
      # verify curated group filter is disabled
    end
  end

  context 'when a user has groups' do

    before(:all) do
      # create two groups
    end

    it 'shows the user\'s own groups as filter options' do
      # verify curated group filter contains groups
    end

    test_searches.each do |search|

      it "allows the user to filter a group by active students with #{search}" do
        # construct test cohorts using group(s) and verify membership
      end

    end
  end

  context 'when a user has a saved filtered group' do

    before(:all) do
      # save a cohort with groups as filters
    end

    it 'shows the group filter' do
      # verify the groups appear in the saved filters
    end

    context 'and removes active students from the group' do

      before(:all) do
        # remove some students from group(s)
      end

      it 'updates the filtered student list'
      it 'updates the cohort member count in the sidebar'
      it 'updates the cohort member count on the homepage'
      it 'updates the cohort member alert count on the homepage'
    end

    context 'and removes all active students from the group(s)' do

      before(:all) do
        # remove all students from group(s)
      end

      it 'updates the filtered student list'
      it 'updates the cohort member count in the sidebar'
      it 'updates the cohort member count on the homepage'
      it 'updates the cohort member alert count on the homepage'
    end

    context 'and adds active students to the group(s)' do

      before(:all) do
        # add students in bulk
        # add students via search results
      end

      it 'updates the filtered student list'
      it 'updates the cohort member count in the sidebar'
      it 'updates the cohort member count on the homepage'
      it 'updates the cohort member alert count on the homepage'
    end

    context 'and removes a group from the filtered group' do

      before(:all) do
        # remove group
      end

      it 'updates the filtered student list'
      it 'updates the cohort member count in the sidebar'
      it 'updates the cohort member count on the homepage'
      it 'updates the cohort member alert count on the homepage'
    end

    context 'and adds a group to the filtered group' do

      before(:all) do
        # add group
      end

      it 'updates the filtered student list'
      it 'updates the cohort member count in the sidebar'
      it 'updates the cohort member count on the homepage'
      it 'updates the cohort member alert count on the homepage'
    end

    context 'and renames a group in the filtered group' do

      before(:all) do
        # rename group
      end

      it 'updates the visible filter'
    end

    context 'and edits a group in the filtered group' do

      before(:all) do
        # edit groups
      end

      it 'updates the filtered student list'
      it 'updates the cohort member count in the sidebar'
      it 'updates the cohort member count on the homepage'
      it 'updates the cohort member alert count on the homepage'
    end

    context 'and attempts to delete group(s) in the filtered group' do

      it 'prevents the deletion(s)'
    end

    context 'and another user views the cohort' do

      before(:all) do
        # log Advisor out
        # log Another Advisor in
      end

      it 'shows the group filters'
      it 'prevents any edits'
    end
  end
end
