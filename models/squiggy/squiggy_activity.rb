class SquiggyActivity

  attr_accessor :type,
                :points,
                :title,
                :activity_drop

  def initialize(type, title, points, activity_drop)
    @type = type
    @title = title
    @points = points
    @activity_drop = activity_drop
  end

  ACTIVITIES = [
    VIEW_ASSET = new('asset_view', 'View an asset in the Asset Library', 0, 'viewed this asset'),
    GET_VIEW_ASSET = new('get_asset_view', 'Receive a view in the Asset Library', 0, 'viewed this asset'),

    LIKE = new('asset_like', 'Like an asset in the Asset Library', 1, 'liked this asset'),
    GET_LIKE = new('get_asset_like', 'Receive a like in the Asset Library', 1, 'liked this asset'),

    COMMENT = new('asset_comment', 'Comment on an asset in the Asset Library', 3, 'commented on this asset'),
    GET_COMMENT = new('get_asset_comment', 'Receive a comment in the Asset Library', 1, 'commented on this asset'),
    GET_COMMENT_REPLY = new('get_asset_comment_reply', 'Receive a reply on a comment in the Asset Library', 1, 'commented on this asset'),

    ADD_DISCUSSION_TOPIC = new('discussion_topic', 'Add a new topic in Discussions', 5, 'posted to a discussion'),
    ADD_DISCUSSION_ENTRY = new('discussion_entry', 'Add an entry on a topic in Discussions', 3, 'posted to a discussion'),
    GET_DISCUSSION_REPLY = new('get_discussion_entry_reply', 'Receive a reply on an entry in Discussions', 1, 'posted to a discussion'),

    ADD_ASSET_TO_LIBRARY = new('asset_add', 'Add a new asset to the Asset Library', 5, 'added this asset'),
    ADD_ASSET_TO_WHITEBOARD = new('whiteboard_add_asset', 'Add an asset to a whiteboard',  8, 'used this asset in a whiteboard'),
    GET_ADD_ASSET_TO_WHITEBOARD = new('get_whiteboard_add_asset', 'Have one\'s asset added to a whiteboard', 0, 'used this asset in a whiteboard'),

    REMIX_WHITEBOARD = new('whiteboard_remix', 'Remix a whiteboard', 0, 'remixed this asset in a whiteboard'),
    GET_REMIX_WHITEBOARD = new('get_whiteboard_remix', 'Have one\'s whiteboard remixed', 0, 'remixed this asset in a whiteboard'),

    EXPORT_WHITEBOARD = new('whiteboard_export', 'Export a whiteboard to the Asset Library', 10, 'exported a whiteboard'),

    SUBMIT_ASSIGNMENT = new('assignment_submit', 'Submit a new assignment in Assignments', 20, nil)
  ]

end
