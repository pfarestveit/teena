describe 'Canvas assignment submission' do

  begin

    students = []
    submissions = []

    students.each do
      begin
        # Upload asset for assignment
      end
    end

    submissions.each do
      begin
        it 'earn \'Submit an Assignment\' points on the Engagement Index'
        it 'appear in Asset Library search results'
        it 'appear in the Asset Library list view with the right title'
        it 'appear in the Asset Library list view with the right owner'
        it 'appear in the Asset Library detail view with the right title'
        it 'appear in the Asset Library detail view with the right owner'
        it 'appear in the Asset Library detail view with the right description'
        it 'appear in the Asset Library detail view with the right categories'
        it 'appear in the Asset Library detail view with the right source'
        it 'appear in the Asset Library detail view with the right preview type'
        it 'can be downloaded from the Asset Library detail view' if asset.type == 'File'
        it 'cannot be downloaded from the Asset Library detail view' if asset.type == 'Link'
      end
    end
  end
end
