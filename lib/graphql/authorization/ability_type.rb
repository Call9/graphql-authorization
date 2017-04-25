GraphQL::Authorization::AbilityType = Struct.new("AbilityType", :type, :execute_permission, :access_permission) do
  def execute value
    self.execute_permission = value
  end
  def access value, evaluator = true
    if self.type.class == GraphQL::UnionType
      raise ArgumentError.new "Specifying access on a union type which cannot be accessed"
    end
    if value == GraphQL::Authorization::All
      self.access all, evaluator
    elsif value.class == Array
      self.access value.map {|e| [e,evaluator]}.to_h
    elsif value.class != Hash
      self.access({value => evaluator})
    else
      self.access_permission = self.access_permission.merge(value)
    end
  end

  def all
    type.all_fields.map {|e| e.name.to_sym}
  end
end
