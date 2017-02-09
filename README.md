# graphql-authorization

[![Gem Version](https://badge.fury.io/rb/graphql-authorization.svg)](https://rubygems.org/gems/graphql-authorization)

An authorization framework for [graphql-ruby](https://rmosolgo.github.io/graphql-ruby)

## Installation

Install from RubyGems by adding it to your `Gemfile`, then bundling.

```ruby
# Gemfile
gem 'graphql-authorization'
```

```
$ bundle install
```

## Setup

Add the instrumentation to your graphql schema definition
```ruby
Schema = GraphQL::Schema.define do
  #Enables authorization
  instrument(:field, GraphQL::Authorization::Instrumentation.new)
  query QueryType
  mutation MutationType
end
 ```

 Change your query runner to inject an ability (discussed below) into the context
 ```ruby
Schema.execute(query, context: { ability: GraphqlAbility.new(current_user) })
 ```

## Usage
Permission are defined by an ability class which must impliment an ability method
```ruby
class GraphAbility < GraphQL::Authorization::Ability
  def ability(user)
    allowed QueryType
  end
end
```

The user object that the ability class is instantiated with passed in as the only argument. Function calls in this method define the access of the user. The ability specifies which types and fields are allowed to be read/computed by the user. If a type is not allowed, an exception is raised if any fields in the query resolve to that type. If a field is not allowed, an exception is raised if that field is requested in the query. These permissions can be computed dynamically using the context of the query.

### allowed

Setting a query as `allowed` permits access to all fields on the query
```ruby
class GraphAbility < GraphQL::Authorization::Ability
  def ability(user)
    allowed QueryType
    allowed BookType
  end
end
```
allows me to query any field on any book

### permit

To specify more fine grained authorization you can call `permit` on a type and pass either additional arguments, or a block
```ruby
class AbilityExample < GraphQL::Authorization::Ability
  def ability(user)
    allowed QueryType
    permit BookType, execute: true, only: [:id, :pages]
  end
end
```
the above allows me to execute fields which return BookType, and query only the `:id` and `:pages` fields

```ruby
class AbilityExample < GraphQL::Authorization::Ability
  def ability(user)
    allowed QueryType
    permit BookType do
      execute true
      access :id
      access :pages, ->(book) { book.page_count.even? }
    end
  end
end
```
the above allows me to execute fields which return BookType, and query only the `:id` field and the `:pages` field only if the object in the query (book) has an even page count.

## Tests

Run tests with `rspec`

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
