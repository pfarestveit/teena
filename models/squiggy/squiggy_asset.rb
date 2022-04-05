class SquiggyAsset

  attr_accessor :id,
                :owner,
                :category,
                :comments,
                :description,
                :file_name,
                :preview_type,
                :size,
                :title,
                :url,
                :visible

  def initialize(asset_data)
    asset_data.each { |k, v| public_send("#{k}=", v) }
  end

end
