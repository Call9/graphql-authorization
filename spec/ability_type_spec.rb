require 'spec_helper'

describe GraphQL::Authorization::AbilityType do
  #before(:all) do
    #CoffeType = GraphQL::ObjectType.define do
      #name 'Book'
      #description 'A book'
      #interfaces [PriceableInterface]
      #field :id, !types.ID
      #field :sugar, !types.Int
    #end

    #PriceableInterface = GraphQL::InterfaceType.define do
      #name 'Priceable'
      #description 'A priceable item'
      #field :price, !types.Float
    #end
  #end

  it 'computes all using interfaces' do
    ability = GraphQL::Authorization::AbilityType.new(CoffeType)
    expect(ability.all).to match_array [:id,:sugar,:price]
  end
end
