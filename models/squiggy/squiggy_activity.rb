class SquiggyActivity

  attr_accessor :type,
                :points,
                :title

  def initialize(type, title, points)
    @type = type
    @title = title
    @points = points
  end

  ACTIVITIES = [
    VIEW_ASSET = new('view_asset', 'View an asset in the Asset Library', 0),
    GET_VIEW_ASSET = new('get_view_asset', 'Receive a view in the Asset Library', 0),

    LIKE = new('like', 'Like an asset in the Asset Library', 1),
    GET_LIKE = new('get_like', 'Receive a like in the Asset Library', 1),

    COMMENT = new('comment', 'Comment on an asset in the Asset Library', 3),
    GET_COMMENT = new('get_comment', 'Receive a comment in the Asset Library', 1),
    GET_COMMENT_REPLY = new('get_comment_reply', 'Receive a reply on a comment in the Asset Library', 1),

    ADD_DISCUSSION_TOPIC = new('discussion_topic', 'Add a new topic in Discussions', 5),
    ADD_DISCUSSION_ENTRY = new('discussion_entry', 'Add an entry on a topic in Discussions', 3),
    GET_DISCUSSION_REPLY = new('get_discussion_entry_reply', 'Receive a reply on an entry in Discussions', 1),

    PIN_ASSET = new('pin_asset', 'Pin an asset for the first time', 1),
    GET_PIN_ASSET = new('get_pin_asset', 'Receive a pin of an asset in the Asset Library', 1),
    REPIN_ASSET = new('repin_asset', 'Re-pin an asset (e.g., pin an asset for the third time)', 0),
    GET_REPIN_ASSET = new('get_repin_asset', 'Receive a re-pin of an asset in the Asset Library', 0),

    ADD_ASSET_TO_LIBRARY = new('add_asset', 'Add a new asset to the Asset Library', 5),

    SUBMIT_ASSIGNMENT = new('submit_assignment', 'Submit a new assignment in Assignments', 20)
  ]

end
