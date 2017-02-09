# Wrapps fields in authorization checks
module GraphQL
  module Authorization
    class Instrumentation
      def initialize(always_allow_execute: false)
        @always_allow_execute = always_allow_execute
      end

      # returns the essential type of a potentially wrapped type (i.e., list or non-null)
      def baseTypeOf(type)
        if type.class == GraphQL::NonNullType || type.class == GraphQL::ListType
          baseTypeOf(type.of_type)
        else
          type
        end
      end

      def toSymKeys(hash)
        hash.map { |key, value| [key.to_sym, value] }.to_h
      end

      def instrument(type, field)
        fieldType = baseTypeOf(field.type)
        old_resolve_proc = field.resolve_proc
        new_resolve_proc = lambda do |obj, args, ctx|
          unless ctx[:ability] == :root
            raise GraphQL::Authorization::Unauthorized, "not authorized to execute #{fieldType.name}" unless ctx[:ability].canExecute(fieldType, toSymKeys(args.to_h)) || @always_allow_execute
            raise GraphQL::Authorization::Unauthorized, "not authorized to access #{field.name} on #{type.name}" unless ctx[:ability].canAccess(type, field.name.to_sym, obj, toSymKeys(args.to_h))
          end
          old_resolve_proc.call(obj, args, ctx)
        end

        # Return a copy of `field`, with a new resolve proc
        field.redefine do
          resolve(new_resolve_proc)
        end
      end
    end
  end
end
