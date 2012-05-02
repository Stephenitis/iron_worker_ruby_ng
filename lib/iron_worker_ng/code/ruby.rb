require_relative '../feature/ruby/merge_gem'
require_relative '../feature/ruby/merge_gemfile'
require_relative '../feature/ruby/merge_exec'

module IronWorkerNG
  module Code
    class Ruby < IronWorkerNG::Code::Base
      include IronWorkerNG::Feature::Ruby::MergeGem::InstanceMethods
      include IronWorkerNG::Feature::Ruby::MergeGemfile::InstanceMethods
      include IronWorkerNG::Feature::Ruby::MergeExec::InstanceMethods

      def create_runner(zip)
        gempath_code_array = []
      
        @features.each do |f|
          if f.respond_to?(:code_for_gempath)
            gempath_code_array << f.send(:code_for_gempath)
          end
        end

        gempath_code = gempath_code_array.join("\n")

        zip.get_output_stream(runner) do |runner|
          runner.write <<RUNNER
# iron_worker_ng-#{IronWorkerNG.version}

# https://github.com/intridea/hashie/ 6d21c6868512603e77a340827ec91ecd3bcef078 START

module Hashie
  module Extensions
    # The MergeInitializer is a super-simple mixin that allows
    # you to initialize a subclass of Hash with another Hash
    # to give you faster startup time for Hash subclasses. Note
    # that you can still provide a default value as a second
    # argument to the initializer.
    #
    # @example
    #   class MyHash < Hash
    #     include Hashie::Extensions::MergeInitializer
    #   end
    #
    #   h = MyHash.new(:abc => 'def')
    #   h[:abc] # => 'def'
    #
    module MergeInitializer
      def initialize(hash = {}, default = nil, &block)
        default ? super(default) : super(&block)
        update(hash)
      end
    end
  end
end

module Hashie
  module Extensions
    # IndifferentAccess gives you the ability to not care
    # whether your hash has string or symbol keys. Made famous
    # in Rails for accessing query and POST parameters, this
    # is a handy tool for making sure your hash has maximum
    # utility.
    #
    # One unique feature of this mixin is that it will recursively
    # inject itself into sub-hash instances without modifying
    # the actual class of the sub-hash.
    #
    # @example
    #   class MyHash < Hash
    #     include Hashie::Extensions::MergeInitializer
    #     include Hashie::Extensions::IndifferentAccess
    #   end
    #
    #   h = MyHash.new(:foo => 'bar', 'baz' => 'blip')
    #   h['foo'] # => 'bar'
    #   h[:foo]  # => 'bar'
    #   h[:baz]  # => 'blip'
    #   h['baz'] # => 'blip'
    #
    module IndifferentAccess
      def self.included(base)
        base.class_eval do
          alias_method :regular_writer, :[]=
          alias_method :[]=, :indifferent_writer
          %w(default update fetch delete key? values_at).each do |m|
            alias_method "regular_\#{m}", m
            alias_method m, "indifferent_\#{m}"
          end
        end
      end

      # This will inject indifferent access into an instance of
      # a hash without modifying the actual class. This is what
      # allows IndifferentAccess to spread to sub-hashes.
      def self.inject!(hash)
        (class << hash; self; end).send :include, Hashie::Extensions::IndifferentAccess
        hash.convert!
      end

      # Injects indifferent access into a duplicate of the hash
      # provided. See #inject!
      def self.inject(hash)
        inject!(hash.dup)
      end

      def convert_key(key)
        key.to_s
      end

      # Iterates through the keys and values, reconverting them to
      # their proper indifferent state. Used when IndifferentAccess
      # is injecting itself into member hashes.
      def convert!
        keys.each do |k|
          regular_writer convert_key(k), convert_value(self.regular_delete(k))
        end
        self
      end

      def convert_value(value)
        if hash_lacking_indifference?(value)
          Hashie::Extensions::IndifferentAccess.inject(value.dup)
        elsif value.is_a?(::Array)
          value.dup.replace(value.map { |e| convert_value(e) })
        else
          value
        end
      end
      
      def indifferent_default(key = nil)
        return self[convert_key(key)] if key?(key)
        regular_default(key)
      end

      def indifferent_update(other_hash)
        return regular_update(other_hash) if hash_with_indifference?(other_hash)
        other_hash.each_pair do |k,v|
          self[k] = v
        end
      end
      
      def indifferent_writer(key, value);  regular_writer convert_key(key), convert_value(value) end
      def indifferent_fetch(key, *args);   regular_fetch  convert_key(key), *args                end
      def indifferent_delete(key);         regular_delete convert_key(key)                       end
      def indifferent_key?(key);           regular_key?   convert_key(key)                       end
      def indifferent_values_at(*indices); indices.map{|i| self[i] }                             end

      def indifferent_access?; true end
      
      protected

      def hash_lacking_indifference?(other)
        other.is_a?(::Hash) &&
        !(other.respond_to?(:indifferent_access?) &&
          other.indifferent_access?)
      end

      def hash_with_indifference?(other)
        other.is_a?(::Hash) &&
        other.respond_to?(:indifferent_access?) &&
        other.indifferent_access?
      end
    end
  end
end

# https://github.com/intridea/hashie/ 6d21c6868512603e77a340827ec91ecd3bcef078 END

class IronWorkerNGHash < Hash
  include Hashie::Extensions::MergeInitializer
  include Hashie::Extensions::IndifferentAccess
end

root = nil
payload_file = nil
task_id = nil

0.upto($*.length - 2) do |i|
  root = $*[i + 1] if $*[i] == '-d'
  payload_file = $*[i + 1] if $*[i] == '-payload'
  task_id = $*[i + 1] if $*[i] == '-id'
end

Dir.chdir(root)

#{gempath_code}
$:.unshift("\#{root}")

require 'json'

@iron_task_id = task_id

@payload = File.read(payload_file)

params = {}
begin
  params = JSON.parse(@payload)
rescue
end

@params = IronWorkerNGHash.new(params)

def payload
  @payload
end

def params
  @params
end

def iron_task_id
  @iron_task_id
end

require '#{File.basename(@exec.path)}'

unless #{@exec.klass == nil}
  exec_class = Kernel.const_get('#{@exec.klass}')
  exec_inst = exec_class.new

  params.keys.each do |param|
    if param.class == String
      if exec_inst.respond_to?(param + '=')
        exec_inst.send(param + '=', params[param])
      end
    end
  end

  exec_inst.run
end
RUNNER
        end
      end

      def runtime(runtime = nil)
        'ruby'
      end

      def runner
        '__runner__.rb'
      end
    end
  end
end

IronWorkerNG::Code::Base.register_type(:name => 'ruby', :klass => IronWorkerNG::Code::Ruby)
