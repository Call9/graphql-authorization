module GraphQL
  module Authorization
    class Unauthorized < StandardError
      def initialize(msg="Unauthorized")
        super
      end
    end
  end
end
