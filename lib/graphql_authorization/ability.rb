class GraphqlAuthorization::Ability
  def initialize(user)
    @user = user
    @ability = {}

    #default white list builtin scalars
    permit GraphQL::STRING_TYPE, execute: true, only: []
    permit GraphQL::INT_TYPE, execute: true, only: []
    permit GraphQL::FLOAT_TYPE, execute: true, only: []
    permit GraphQL::ID_TYPE, execute: true, only: []
    permit GraphQL::BOOLEAN_TYPE, execute: true, only: []

    ability(user)
  end

  #permits execution, all access by default
  def permit(type,options={})
    raise NameError.new("duplicate ability definition") if @ability.key? type
    ability_object = GraphqlAuthorization::AbilityType.new(type,nil,{})
    if options.key?(:except) && options.key?(:only)
      raise ArgumentError.new("you cannot specify white list and black list")
    end
    if options[:except]
      ability_object.access(type.fields.keys.map(&:to_sym) - options[:except])
    elsif options[:only]
      ability_object.access(options[:only])
    end
    ability_object.execute options[:execute]
    if block_given?
      #note Proc.new creates a proc with the block given to the method
      ability_object.instance_eval(&Proc.new)
    end
    @ability[type] = ability_object
  end

  #calls a proc-like object with args comensorate with it's arity
  def callSetArgs(object,*args)
    arity = object&.arity || object.method(:call).arity
    if arity > 0
      object.call(*args[0..arity-1])
    elsif arity == 0
      object.call()
    else
      object.call(*args)
    end
  end

  #returns true if the user can execute queries of type, "type"
  def canExecute(type,args={})
    return false unless @ability[type]
    execute = @ability[type].execute_permission
    return callSetArgs(execute,args) if execute.respond_to? :call
    execute
  end

  #returns true if the user can access "field" on "type"
  def canAccess(type,field,object=nil,args={})
    return false unless @ability[type]
    access = @ability[type].access_permission[field]
    return callSetArgs(access,object,args) if access.respond_to? :call
    access
  end

  def allowed type
    if type.class == GraphQL::UnionType
      permit type, execute: true
    else
      permit type, execute: true, only: GraphqlAuthorization::All
    end
  end

  def ability(user)
    raise NotImplementedError.new("must implmenet ability funciton")
  end
end
