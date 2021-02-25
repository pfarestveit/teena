describe 'Asset Library' do

  users = []

  describe 'categories' do

    users.each do |user|
      it "can be managed by a course #{user.role} if the user has permission to do so"
    end

    context 'when created' do
      it 'require a title'
      it 'require a title under 256 characters'
      it 'are added to the list of available categories'
      it 'can be added to existing assets'
      it 'show how many assets with which they are associated'
      it 'appear on the asset detail of associated assets as links to the asset library filtered for that category'
    end

    context 'when edited' do
      it 'can be canceled'
      it 'require a title'
      it 'are updated on assets with which they are associated'
    end

    context 'when deleted' do
      it 'no longer appear in the list of categories'
      it 'no longer appear in search options'
      it 'no longer appear on asset detail'
    end
  end

  describe 'search' do
    it 'lets a user perform a simple search by a string in the title'
    it 'lets a user perform a simple search by a string in the description'
    it 'lets a user perform a simple search by a hashtag in the description'
    it 'lets a user perform an advanced search by a string in the title, sorted by Most Recent'
    it 'lets a user perform an advanced search by a string in the description, sorted by Most Recent'
    it 'lets a user perform an advanced search by a hashtag in the description, sorted by Most Recent'
    it 'lets a user perform an advanced search by category, sorted by Most Recent'
    it 'lets a user perform an advanced search by uploader, sorted by Most Recent'
    it 'lets a user perform an advanced search by type, sorted by Most Recent'
    it 'lets a user perform an advanced search by keyword and category, sorted by Most Recent'
    it 'lets a user perform an advanced search by keyword and uploader, sorted by Most Recent'
    it 'lets a user perform an advanced search by keyword, category, and uploader, sorted by Most Recent'
    it 'lets a user perform an advanced search by keyword and type, sorted by Most Recent'
    it 'lets a user perform an advanced search by category and uploader, sorted by Most Recent'
    it 'lets a user perform an advanced search by uploader and type, sorted by Most Recent'
    it 'lets a user perform an advanced search by category and type, sorted by Most Recent'
    it 'returns a no results message for an advanced search by a hashtag in a comment, sorted by Most Recent'
    it 'lets a user perform an advanced search by keyword, category, and type, sorted by Most Recent'
    it 'lets a user perform an advanced search by keyword, uploader, and type, sorted by Most Recent'
    it 'lets a user perform an advanced search by keyword, category, uploader, and type, sorted by Most Recent'
    it 'lets a user perform an advanced search by keyword, sorted by Most Likes'
    it 'lets a user perform an advanced search by keyword, sorted by Most Comments'
    it 'lets a user perform an advanced search by keyword, sorted by Most Views'
    it 'lets a user perform an advanced search by keyword and uploader, sorted by Most Likes'
    it 'lets a user perform an advanced search by keyword and category, sorted by Most Comments'
    it 'lets a user perform an advanced search by keyword and uploader, sorted by Most Views'
    it 'lets a user click a commenter name to view the asset gallery filtered by the commenter\'s submissions'
    it 'allows sorting by "Most recent", "Most likes", "Most views", "Most comments", and "Pinned"'
  end
end
