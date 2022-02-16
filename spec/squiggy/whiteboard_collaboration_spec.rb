describe 'Whiteboard' do

  # Create three whiteboards

  describe 'access' do

    it 'allows a course [Teacher, Lead TA, TA, Designer, Reader] to search for whiteboards'
    it 'allows a course [Teacher, Lead TA, TA, Designer, Reader] to view any whiteboard and its membership'
    it 'allows a course [Teacher, Lead TA, TA, Designer, Reader] to delete any whiteboard'

    it 'does not allow a course [Observer, Student, Waitlist Student] to search for whiteboards'
    it 'does not allow a course [Observer, Student, Waitlist Student] to view others\' whiteboards or their membership'
    it 'does not allow a course [Observer, Student, Waitlist Student] to delete others\' whiteboards'

    context 'when the user is a Student with membership in some whiteboards but not all' do

      it 'the user can see its whiteboards'
      it 'the user cannot see or reach other whiteboards'
    end
  end

  describe 'collaboration members pane' do

    it 'allows a student to see a list of all whiteboard members'
    it 'allows a student to see which members are currently offline'
    it 'allows a student to see which members have just come online'
    it 'allows a student to see which members have just gone offline'
    it 'does not allow a student to see if a non-member teacher has just come online'
    it 'allows a student to close the collaborators pane'
    it 'allows a student to reopen the collaborators pane'
  end

  describe 'membership' do

    it 'allows a student to add a member'
    it 'allows a student to delete a member'
    it 'allows a student to delete its own membership'
  end

  describe 'Canvas syncing' do

    before(:all) do
      # Access to whiteboards is based on session cookie, so delete cookies or launch another browser to check cookie-less access
    end

    it 'removes a user from all whiteboards if the user has been removed from the course site'
    it 'prevents a user from reaching any whiteboards if the user has been removed from the course site'
  end
end
