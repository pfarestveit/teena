describe 'Whiteboard' do

  describe 'creation' do

    it 'shows a Create Your First Whiteboard link if the user has no existing whiteboards'
    it 'requires a title'
    it 'permits a title with 255 characters maximum'
    it 'can be done with the owner as the only member'
    it 'can be done with the owner plus other course site members as whiteboard members'
  end

  describe 'editing' do

    it 'allows the title to be changed'
  end

  describe 'deleting' do

    before(:all) do
      # Student creates two whiteboards
    end

    it 'can be done by a student who is a collaborator on the whiteboard' do
      # Student collaborator deletes board
      # Deleted board should close and be gone from list view
    end

    it 'can be done by an instructor who is not a collaborator on the whiteboard' do
      # Teacher deletes other board
      # Deleted board should close but remain in list view in deleted state
    end

    it 'can be reversed by an instructor' do
      # Teacher restores board
      # Student can now see board again
    end
  end

  describe 'search' do

    it 'is not available to a student'
    it 'is available to a teacher'
    it 'allows a teacher to perform a simple search by title that returns results'
    it 'allows a teacher to perform a simple search by title that returns no results'
    it 'allows a teacher to perform an advanced search by title that returns results'
    it 'allows a teacher to perform an advanced search by title that returns no results'
    it 'allows a teacher to perform an advanced search by collaborator that returns results'
    it 'allows a teacher to perform an advanced search by collaborator that returns no results'
    it 'allows a teacher to perform an advanced search by title and collaborator that returns results'
    it 'allows a teacher to perform an advanced search by title and collaborator that returns no results'
  end

  describe 'export' do

    before(:all) do
      # Upload assets to be used on whiteboard
      # Get current score
      # Get configured activity points to determine expected score
      # Create a whiteboard for tests
    end

    it 'is not possible if the whiteboard has no assets'
    it 'as a new asset is possible if the whiteboard has assets'
    it 'as a new asset allows a user to remix the whiteboard'
    it 'as a new asset earns "Export a whiteboard to the Asset Library" points'
    it 'as a new asset shows "export_whiteboard" activity on the CSV export'
    it 'as a PNG download is possible if the whiteboard has assets'
    it 'as a PNG download earns no "Export a whiteboard to the Asset Library" points'
  end

  describe 'asset detail' do

    before(:all) do
      # Create three whiteboards and add the same asset to each
      # Export two of the boards
      # Delete the resulting asset for one of the boards
      # Load the asset's detail
    end

    it 'lists whiteboard assets that use the asset'
    it 'does not list whiteboards that use the asset but have not been exported to the asset library'
    it 'does not list whiteboard assets that use the asset but have since been deleted'
    it 'links to the whiteboard asset detail'
  end
end
