describe 'Asset' do

  describe 'likes' do

    context 'when the user is the asset creator' do
      it 'cannot be added on the list view'
      it 'cannot be added on the detail view'
    end

    context 'when the user is not the asset creator' do
      it 'cannot be added on the list view'
    end

    context 'when added on the detail view' do
      it 'increase the asset\'s total likes'
      it 'earn Engagement Index "like" points for the liker'
      it 'earn Engagement Index "get_like" points for the asset creator'
      it 'add the liker\'s "like" activity to the activities csv'
      it 'add the asset creator\'s "get_like" activity to the activities csv'
    end

    context 'when removed on the detail view' do
      it 'decrease the asset\'s total likes'
      it 'remove Engagement Index "like" points from the un-liker'
      it 'remove Engagement Index "get_like" points from the asset creator'
      it 'remove the un-liker\'s "like" activity from the activities csv'
      it 'remove the asset creator\'s "get_like" activity from the activities csv'
    end
  end

  describe 'comments' do

    context 'by the asset uploader' do
      it 'can be added on the detail view'
      it 'can be added as a reply to an existing comment'
      it 'does not earn commenting points on the engagement index'
    end

    context 'by a user who is not the asset creator' do
      it 'can be added on the detail view'
      it 'can be added as a reply to the user\'s own comment'
      it 'can be added as a reply to another user\'s comment'
      it 'earns "Comment" points on the engagement index for the user adding a comment or reply'
      it 'earns "Receive a Comment" points on the engagement index for the user receiving the comment or reply'
      it 'shows "Comment" activity on the CSV export for the user adding the comment or reply'
      it 'shows "Receive a Comment" activity on the CSV export for the user receiving the comment or reply'
    end

    context 'by any user' do
      it 'can include a link that opens in a new browser window'
      it 'cannot be added as a reply to a reply'
      it 'can be canceled when a reply'
    end

    describe 'edit' do
      it 'can be done by the user who created the comment'
      it 'cannot be done by a user who did not create the comment'
      it 'can be done to any comment when the user is a teacher'
      it 'can be canceled'
      it 'does not alter existing engagement scores'
    end

    describe 'deletion' do
      it 'can be done by a student who created the comment'
      it 'cannot be done by a student who did not create the comment'
      it 'can be done by a teacher if the comment has no replies'
      it 'cannot be done by a teacher if the comment has replies'
      it 'removes engagement index points earned for the comment'
    end
  end

  describe 'views' do
    it 'are only incremented when viewed by users other than the asset creator'
  end
end