class GraphqlAuthorization::Unauthorized < StandardError
  def initialize(msg="Unauthorized")
    super
  end
end
