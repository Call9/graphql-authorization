require 'spec_helper'

describe GraphqlAuthorization::Ability do
  before(:all) do
    BookType = GraphQL::ObjectType.define do
      name "Book"
      description "A book"
      field :id, !types.ID
      field :created_at, !types.String
      field :updated_at, !types.String
      field :pages, !types.Int
    end
    CoffeType = GraphQL::ObjectType.define do
      name "Book"
      description "A book"
      interfaces [PriceableInterface]
      field :id, !types.ID
      field :sugar, !types.Int
    end

    PriceableInterface = GraphQL::InterfaceType.define do
      name "Priceable"
      description "A priceable item"
      field :price, !types.Float
    end

    StoreType = GraphQL::ObjectType.define do
      name "Store"
      description "A book store"
      field :id, !types.ID
      field :created_at, !types.String
      field :updated_at, !types.String
      field :books, types[BookType]
      field :items, types[ItemsUnionType]
    end

    ItemsUnionType = GraphQL::UnionType.define do
      name "Items"
      possible_types [StoreType,BookType]
    end

  end
  it "doesn't allow black and white list" do
    class AbilityExample < GraphqlAuthorization::Ability
      def ability(user)
        allowed StoreType
        permit BookType, only: [:id], except: [:created_at]
      end
    end
    expect{AbilityExample.new(1)}.to raise_error ArgumentError
  end

  it "allows explicit execution" do
    class AbilityExample < GraphqlAuthorization::Ability
      def ability(user)
        permit BookType, execute: true, only: [:id]
        permit StoreType, execute: false, only: [:id]
      end
    end
    ability = AbilityExample.new(1)
    expect(ability.canExecute(BookType)).to be true
    expect(ability.canExecute(StoreType)).to be false
  end

  it "defaults to no allowed execution" do
    class AbilityExample < GraphqlAuthorization::Ability
      def ability(user)
        permit BookType, only: [:id]
      end
    end
    ability = AbilityExample.new(1)
    expect(ability.canExecute(BookType)).to be_falsey
  end

  it "allows white list access" do
    class AbilityExample < GraphqlAuthorization::Ability
      def ability(user)
        permit BookType, execute: true, only: [:id,:created_at]
      end
    end
    ability = AbilityExample.new(1)
    expect(ability.canAccess(BookType,:id)).to be_truthy
    expect(ability.canAccess(BookType,:created_at)).to be_truthy
    expect(ability.canAccess(BookType,:updated_at)).to be_falsey
    expect(ability.canAccess(BookType,:other)).to be_falsey
  end

  it "allows function evaluation for execution" do
    class AbilityExample < GraphqlAuthorization::Ability
      def ability(user)
        permit BookType, execute: -> (args) {args[:value] % 2 == 0}, only: GraphqlAuthorization::All
      end
    end
    ability = AbilityExample.new(1)
    expect(ability.canExecute(BookType,{value: 2})).to be_truthy
    expect(ability.canExecute(BookType,{value: 3})).to be_falsey
    expect(ability.canExecute(BookType,{value: 100})).to be_truthy
    expect(ability.canExecute(BookType,{value: 301})).to be_falsey
  end

  it "allows default access shorthand" do
    class AbilityExample < GraphqlAuthorization::Ability
      def ability(user)
        allowed BookType
      end
    end
    ability = AbilityExample.new(1)
    expect(ability.canExecute(BookType,{value: 2})).to be_truthy
    expect(ability.canAccess(BookType,:id)).to be_truthy
    expect(ability.canAccess(BookType,:created_at)).to be_truthy
    expect(ability.canAccess(BookType,:pages)).to be_truthy
    expect(ability.canAccess(BookType,:other)).to be_falsey
  end

  it "allows specification via block" do
    class AbilityExample < GraphqlAuthorization::Ability
      def ability(user)
        permit BookType do
          execute true if user > 5
          access GraphqlAuthorization::All if user > 10
        end
        permit StoreType do
          execute -> (args) { (user > 0) && (args[:big] == true)}
          access :id, -> (obj,args) { args && obj}
          access :books
        end
      end
    end
    expect(AbilityExample.new(1).canExecute(BookType)).to be_falsey
    expect(AbilityExample.new(6).canExecute(BookType)).to be_truthy
    expect(AbilityExample.new(6).canAccess(BookType,:id)).to be_falsey
    expect(AbilityExample.new(12).canAccess(BookType,:id)).to be_truthy

    expect(AbilityExample.new(1).canExecute(StoreType,{big: true})).to be_truthy
    expect(AbilityExample.new(1).canExecute(StoreType,{big: false})).to be_falsey
    expect(AbilityExample.new(-1).canExecute(StoreType,{big: true})).to be_falsey

    expect(AbilityExample.new(-1).canAccess(StoreType,:books)).to be_truthy
    expect(AbilityExample.new(0).canAccess(StoreType,:id,true,true)).to be_truthy
    expect(AbilityExample.new(0).canAccess(StoreType,:id,true,false)).to be_falsey
    expect(AbilityExample.new(0).canAccess(StoreType,:id,false,true)).to be_falsey
  end

  it "ignores access on unions as unions cannot be accessed" do
    class AbilityExample < GraphqlAuthorization::Ability
      def ability(user)
        allowed ItemsUnionType
      end
    end
    expect(AbilityExample.new(1).canExecute(ItemsUnionType)).to be_truthy
    expect(AbilityExample.new(1).canAccess(ItemsUnionType,:id)).to be_falsey
  end

  it "can handle fields from interfaces" do
    class AbilityExample < GraphqlAuthorization::Ability
      def ability(user)
        allowed CoffeType
      end
    end
    expect(AbilityExample.new(1).canAccess(CoffeType,:price)).to be_truthy
  end
end
