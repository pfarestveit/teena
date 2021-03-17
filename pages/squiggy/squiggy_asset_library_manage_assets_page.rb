class SquiggyAssetLibraryManageAssetsPage

  include PageObject
  include Page
  include SquiggyPages
  include Logging

  h2(:manage_assets_heading, xpath: '//h2[text()="Manage Assets"]')

end
