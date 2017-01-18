require 'spec_helper'

describe GraphqlAuthorization::Instrumentation do
  before(:all) do
    hashAccess = -> (key) {
      -> (obj,args,ctx) {obj[key]}
    }
    ChatMessageType = GraphQL::ObjectType.define do
      name "Chat Message"
      description "A session chat message"
      field :id, !types.ID, resolve: hashAccess.call(:id)
      field :session_id, !types.ID, resolve: hashAccess.call(:session_id)
      field :content, !types.String, resolve: hashAccess.call(:content)
    end


    SessionType = GraphQL::ObjectType.define do
      name "Session"
      description "A Call9 Session"
      field :id, !types.ID, resolve: hashAccess.call(:id)
      field :field, !types.String, resolve: hashAccess.call(:field)
      field :chat_messages, types[ChatMessageType], resolve: -> (obj,args,ctx) {
        obj[:chat_messages].map {|e| ChatMessages[e]}
      }
    end

    QueryType = GraphQL::ObjectType.define do
      name "Query"
      description "The query root of this schema"

      field :session do
        type SessionType
        argument :id, !types.ID
        description "Find a session by ID"
        resolve ->(obj, args, ctx) { Sessions[args["id"].to_i] }
      end
      field :chat_message do
        type ChatMessageType
        argument :id, !types.ID
        description "Find a chat message by ID"
        resolve ->(obj, args, ctx) { ChatMessages[args["id"].to_i]}
      end
    end

    @filesCreated = 0
    #method because resolves change scope?
    @getFilesCreated = -> {@filesCreated}
    @updateFilesCreated = -> (value) { @filesCreated = value }
    updateFilesCreated = @updateFilesCreated
    getFilesCreated = @getFilesCreated

    FileCreateType = GraphQL::ObjectType.define do
      name "FileCreate"
      description "CreatedFile"
      field :id, !types.ID, resolve: -> (obj,args,ctx) {getFilesCreated.call}
    end
    MutationType = GraphQL::ObjectType.define do
      name "Mutation"
      description "The mutation root of this schema"
      field :createFile do
        type FileCreateType
        argument :content, !types.Int
        description "Find create a fake file"
        resolve ->(obj, args, ctx) {
          updateFilesCreated.call(getFilesCreated.call + 1)
        }
      end
    end

    Schema = GraphQL::Schema.define do
      instrument(:field, GraphqlAuthorization::Instrumentation.new)
      query QueryType
      mutation MutationType
    end

    Sessions = {
      1 => {
        id: 1, field: "test", chat_messages: [1]
      },
      2 => {
        id: 2, field: "data2", chat_messages: []
      },
    }
    ChatMessages = {
      1 => {
        id: 1,
        session_id: 1,
        content: "test content"
      }
    }
    @executeQuery = -> (query:,user:,abilityClass:) do
      Schema.execute(query,context:{ability: abilityClass.new(user)})
    end
  end

  before(:each) do
    @updateFilesCreated.call 0
  end


  it 'rejects be default' do
    class AbilityExample < GraphqlAuthorization::Ability
      def ability(user)
        allowed QueryType
      end
    end
    query = '{session(id: 1) { id }}'
    expect {
      @executeQuery.call query: query, user: 1, abilityClass: AbilityExample
    }.to raise_error GraphqlAuthorization::Unauthorized
  end

  it 'allows selection of scalars if specified explicitly' do
    class AbilityExample < GraphqlAuthorization::Ability
      def ability(user)
        allowed QueryType
        permit SessionType, execute: true, only: [:id, :field]
      end
    end
    query = '{session(id: 1) { id field}}'
    bad_query = '{session(id: 1) { id field chat_messages {id}}}'
    #should not error
    res = @executeQuery.call query: query, user: 1, abilityClass: AbilityExample
    expect {
      @executeQuery.call query: bad_query, user: 1, abilityClass: AbilityExample
    }.to raise_error GraphqlAuthorization::Unauthorized
  end

  it 'allows selection of all' do
    class AbilityExample < GraphqlAuthorization::Ability
      def ability(user)
        allowed QueryType
        allowed SessionType
        permit ChatMessageType, execute: true, only: GraphqlAuthorization::All
      end
    end
    query = '{session(id: 1) { id field chat_messages {id content} }}'
    res = @executeQuery.call query: query, user: 1, abilityClass: AbilityExample
    expect(res.dig("data","session","chat_messages",0,"content")).to eq("test content")
  end

  it 'properly checks nested types' do
    class AbilityExample < GraphqlAuthorization::Ability
      def ability(user)
        allowed QueryType
        allowed SessionType
        permit ChatMessageType, execute: true, only: [:id, :content]
      end
    end
    query_session = '{session(id: 1) { id chat_messages {id content} }}'
    query_chatmessage = '{chat_message(id: 1) {content}}'
    query_bad = '{session(id: 1) { id chat_messages {id content session_id} }}'
    res = @executeQuery.call query: query_session, user: 1, abilityClass: AbilityExample
    expect(res.dig("data","session","chat_messages",0,"content")).to eq("test content")

    query = '{chat_message(id: 1) {content}}'
    res = @executeQuery.call query: query_chatmessage, user: 1, abilityClass: AbilityExample
    expect(res.dig("data","chat_message","content")).to eq("test content")

    query = '{session(id: 1) { id chat_messages {id content session_id} }}'
    expect {
      @executeQuery.call query: query_bad, user: 1, abilityClass: AbilityExample
    }.to raise_error GraphqlAuthorization::Unauthorized
  end

  it 'allows functional evaluation for access' do
    class AbilityExample < GraphqlAuthorization::Ability
      def ability(user)
        allowed QueryType
        permit SessionType, execute: true do
          access GraphqlAuthorization::All, -> (obj) {obj[:id] % 2 == user}
        end
      end
    end
    query = '{session(id: 1) { id }}'
    #no error
    res = @executeQuery.call query: query, user: 1, abilityClass: AbilityExample
    expect{
      @executeQuery.call query: query, user: 2, abilityClass: AbilityExample
    }.to raise_error GraphqlAuthorization::Unauthorized

    query = '{session(id: 2) { id }}'
    #no error
    res = @executeQuery.call query: query, user: 0, abilityClass: AbilityExample
    expect{
      @executeQuery.call query: query, user: 1, abilityClass: AbilityExample
    }.to raise_error GraphqlAuthorization::Unauthorized
  end

  it "doesn't run querys with diallowed execution" do
    class AbilityExample < GraphqlAuthorization::Ability
      def ability(user)
        allowed QueryType
        allowed MutationType
        permit FileCreateType do
          execute -> (args) { args[:content] > 10 }
          access GraphqlAuthorization::All
        end
      end
    end
    query = 'mutation{createFile(content: 11) { id }}'
    res = @executeQuery.call query: query, user: 1, abilityClass: AbilityExample
    expect(res.dig("data","createFile","id")).to eq "1"
    res = @executeQuery.call query: query, user: 1, abilityClass: AbilityExample
    expect(res.dig("data","createFile","id")).to eq "2"

    query = 'mutation{createFile(content: 9) { id }}'
    expect{
      @executeQuery.call query: query, user: 1, abilityClass: AbilityExample
    }.to raise_error GraphqlAuthorization::Unauthorized
    expect(@getFilesCreated.call).to eq 2
  end

  it "can skip authorization with root permissions" do
    query = 'mutation{createFile(content: 1) { id }}'
    res = Schema.execute(query,context:{ability: :root})
    expect(res.dig("data","createFile","id")).to eq "1"
  end
end
