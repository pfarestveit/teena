describe 'A Canvas discussion' do

  it 'earns Discussion Topic Engagement Index points for the discussion creator'
  it 'adds discussion-topic activity to the CSV export for the discussion creator'

  describe 'entry' do

    context 'when added by someone other than the discussion topic creator' do
      it 'earns Discussion Entry Engagement Index points for the user adding the entry'
      it 'earns no points for the discussion topic creator'
      it 'adds discussion-entry activity to the CSV export for the user adding the entry'
    end

    context 'when added by the discussion topic creator' do
      it 'earns no Discussion Entry Engagement Index points for the user adding the entry'
      it 'adds no discussion-entry activity to the CSV export for the discussion creator'
    end

    context 'when added by someone who has already added an earlier discussion entry' do
      it 'earns Discussion Entry Engagement Index points for the user adding the entry'
      it 'earns no points for the discussion topic creator'
      it 'adds discussion-entry activity to the CSV export for the user adding the entry'
    end
  end

  describe 'entry reply' do

    context 'when added by someone who created the discussion topic but not the discussion entry' do
      it 'earns Discussion Entry Engagement Index points for the user who added the discussion entry reply'
      it 'earns Discussion Reply Engagement Index points for the user who received the discussion entry reply'
      it 'adds discussion-entry and discussion-reply activity to the CSV export for the users'
    end

    context 'when added by someone who created the discussion topic and the discussion entry' do
      it 'earns no Engagement Index points for the user'
    end

    context 'when added by someone who did not create the discussion topic or the discussion entry' do
      it 'earns Discussion Reply Engagement Index points for the user who received the discussion entry reply'
      it 'earns Discussion Entry Engagement Index points for the user who added the discussion entry reply'
      it 'adds discussion-entry and discussion-reply activity to the CSV export for the users'
    end

    context 'when added by someone who did not create the discussion topic but did create the discussion entry' do
      it 'earns no Engagement Index points for the user'
    end

    context 'when added by someone who did not create the discussion topic but did create the discussion entry' do
      it 'earns Discussion Reply Engagement Index points for the user who received the discussion entry reply'
      it 'earns Discussion Entry Engagement Index points for the user who added the discussion entry reply'
      it 'adds discussion-entry and discussion-reply activity to the CSV export for the users'
    end

    context 'when added by someone who added an earlier discussion entry reply' do
      it 'earns no Engagement Index points for the user'
    end
  end

  describe 'reply to reply' do

    context 'when added by someone who created the entry but not the reply' do
      it 'earns Discussion Entry Engagement Index points for the user who added the reply to reply'
      it 'earns Discussion Reply Engagement Index points for the user who received the reply to reply'
      it 'adds discussion-entry and discussion-reply activity to the CSV export for the users'
    end

    context 'when added by someone who created the reply but not the entry' do
      it 'earns no Engagement Index points for the user'
    end
  end
end
