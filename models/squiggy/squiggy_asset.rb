class SquiggyAsset

  attr_accessor :id,
                :category,
                :comments,
                :description,
                :file_name,
                :preview_type,
                :title,
                :url

  def initialize(asset_data)
    asset_data.each { |k, v| public_send("#{k}=", v) }
  end

end
