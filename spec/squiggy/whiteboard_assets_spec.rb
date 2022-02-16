describe 'Whiteboard Add Asset' do

  before(:all) do

    # Load test data
    # Create test course
    # Set "whiteboard add asset" points to non-zero value
    # Student 1 create whiteboard, invite Student 2
  end

  context 'when using existing assets' do

    before(:all) do
      # Student 1 add file to asset library
      # Student 2 add URL to asset library
      # Student 3 add file to asset library
      # Get initial scores
    end

    it 'allows the user to cancel adding assets'
    it 'allows the user to add the user\'s own assets'
    it 'allows the user to add a collaborator\'s assets'
    it 'allows the user to add a non-collaborator\'s assets'
    it 'allows the user to add multiple assets at once'
    it 'earns "Add an asset to a whiteboard" but not "Add a new asset to the Asset Library" points on the Engagement Index for each asset used'
    it 'shows "add_asset_to_whiteboard" but not "add_asset" activity on the CSV export for each asset belonging to another user'
  end

  context 'when uploading new assets' do

    it 'requires an asset title'
    it 'requires an asset title of 255 characters maximum'
    it 'allows the user to add the upload to the asset library'
    it 'allows the user to exclude the upload from the asset library' do
      # Asset is reachable via deep link
      # Asset is not searchable
    end
    it 'allows the asset owner to view a hidden asset deep link'
    it 'allows a whiteboard collaborator to view a hidden asset deep link'
    it 'does not allow a user who is not the owner or whiteboard collaborator to view a hidden asset deep link'
    it 'earns "Add a new asset to the Asset Library" points on the Engagement Index'
    it 'shows "add_asset" activity on the CSV export'
  end

  context 'when adding new URL assets' do

    it 'requires an asset title'
    it 'requires an asset title of 255 characters maximum'
    it 'allows the user to add the site to the asset library'
    it 'allows the user to exclude the site from the asset library' do
      # Asset is reachable via deep link
      # Asset is not searchable
    end
    it 'earns "Add a new asset to the Asset Library" points on the Engagement Index'
    it 'shows "add_asset" activity on the CSV export'
  end

  context 'when the asset is hidden from the asset library' do

    it 'allows the user to comment on it via the whiteboard'
    it 'allows the user to edit its metadata via the whiteboard'
    it 'does not allow a student user to delete it via the whiteboard'
  end
end
