class SquiggyAsset

  attr_accessor :id,
                :owner,
                :category,
                :comments,
                :count_likes,
                :count_views,
                :deleted,
                :description,
                :file_name,
                :preview_type,
                :size,
                :title,
                :url,
                :visible

  NO_PREVIEW_EXTENSIONS = %w(heic webp)

  def initialize(asset_data)
    asset_data.each { |k, v| public_send("#{k}=", v) }
    @comments ||= []
    @count_likes ||= 0
    @count_views ||= 0
    @visible ||= true
  end

end
