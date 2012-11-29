module ASBO
  module DSLEval
    module ExtendMethods
      def dsl_method(*methods)
        # Class variables as we *want* them to be inherited
        @@dsl_methods ||= []
        @@dsl_methods.push(*methods)
      end

      def dsl_methods
        @@dsl_methods || []
      end
    end

    def dsl_eval(*a, &block)
      # The class we're whose methods we're calling from the dsl
      that = self
      # Fetch the methods we're defining
      methods = self.class.dsl_methods.uniq
      # Create a new anonymous class to eval the block in
      c = Class.new
      # Define each of the methods in the anonyous class
      # They just wrap the methods from that
      methods.each do |method|
        c.send(:define_method, method) do |*args, &blk|
          that.send(method, *args, &blk)
        end
      end
      c.new.instance_eval(*a, &block)
    end

    def self.included(klass)
      klass.extend(ExtendMethods)
    end
  end
end