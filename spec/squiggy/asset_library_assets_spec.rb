describe 'Asset Library' do

  describe 'links' do
    it 'can be added with title, category, and description'
    it 'earn "Add a new asset to the Asset Library" points on the Engagement Index'
    it 'add "add_asset" activity to the CSV export'
    it 'can be added with title and category only'
    it 'can be added with title only'
    it 'can be added with title and description only'
    it 'require that the user enter a URL'
    it 'require that the user enter a valid URL'
    it 'require that the user enter a title'
    it 'limit a title to 255 characters'
    it 'do not have a default category'
    it 'can have only non-deleted categories'
    it 'can be canceled and not added'
  end

  describe 'files' do
    it 'can be added with title, category, and description'
    it 'earn "Add a new asset to the Asset Library" points on the Engagement Index'
    it 'add "add_asset" activity to the CSV export'
    it 'can be added with title and category only'
    it 'can be added with title only'
    it 'can be added with title and description only'
    it 'require that the user enter a title'
    it 'limit a title to 255 characters'
    it 'do not have a default category'
    it 'can have only non-deleted categories'
    it 'can be canceled and not added'
  end
end

describe 'New asset uploads' do
  begin
    students = []
    students.each do |student|
      begin
        student.assets.each do |asset|
          begin
            if asset.type == 'File' && asset.size > 10
              it "do not permit files over 10MB to be uploaded to the Asset Library for #{student.full_name} uploading #{asset.title}"
            else
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
    end
  end
end

