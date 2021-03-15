class SquiggyAssetLibraryDetailPage

  include PageObject
  include Page
  include Logging
  include SquiggyAssetLibraryMetadataForm

  h2(:asset_title, id: 'asset.title')
  div(:asset_preview, xpath: '//div[starts-with(@id, "asset-preview-image-")]')
  # TODO - owner
  button(:like_button, id: 'like-asset-btn')
  # TODO - like count
  # TODO - view count
  # TODO - comment count

  # TODO - description
  # TODO - categories
  text_area(:comment_input, id: 'comment-body-textarea')
  # TODO - comments

  button(:edit_details_button, id: 'edit-asset-details-btn')
  link(:download_button, id: 'download-asset-btn')
  button(:delete_button, id: 'delete-asset-btn')
  button(:delete_confirm_button, id: 'confirm-delete-btn')
  button(:delete_cancel_button, id: 'cancel-delete-btn')

end
