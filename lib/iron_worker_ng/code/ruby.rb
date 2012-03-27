# -*- coding: undecided -*-
require_relative '../feature/ruby/merge_gem'
require_relative '../feature/ruby/merge_gemfile'
require_relative '../feature/ruby/merge_worker'

module IronWorkerNG
  module Code
    class Ruby < IronWorkerNG::Code::Base
      include IronWorkerNG::Feature::Ruby::MergeGem::InstanceMethods
      include IronWorkerNG::Feature::Ruby::MergeGemfile::InstanceMethods
      include IronWorkerNG::Feature::Ruby::MergeWorker::InstanceMethods

      def create_runner(zip, init_code)
        zip.get_output_stream('runner.rb') do |runner|
          runner.write <<RUNNER
# iron_worker_ng-#{IronWorkerNG.version}

root = nil
payload_file = nil
task_id = nil

($*.length - 2).downto(0) do |i|
  root = $*[i + 1] if $*[i] == '-d'
  payload_file = $*[i + 1] if $*[i] == '-payload'
  task_id = $*[i + 1] if $*[i] == '-id'
end

Dir.chdir(root)

#{init_code}
$:.unshift("\#{root}")

def log(*args)
  puts *args
end

require 'json'

@iron_worker_task_id = task_id

@payload = File.read(payload_file)

parsed_payload = JSON.parse(@payload)

raise "Хуй"

@iron_io_token = parsed_payload['token']
@iron_io_project_id = parsed_payload['project_id']
@params = parsed_payload['params'] || {}

keys = @params.keys
keys.each do |key|
  @params[key.to_sym] = @params[key]
end

def params
  @params
end

require worker_file_name

worker_class = nil

begin
  worker_class = Kernel.const_get(worker_class_name)
rescue
end

unless worker_class.nil?
  worker_inst = worker_class.new

  class << worker_inst
    attr_accessor :iron_io_token
    attr_accessor :iron_io_project_id
    attr_accessor :iron_worker_task_id
    attr_accessor :params
  end

  worker_inst.iron_io_token = @iron_io_token
  worker_inst.iron_io_project_id = @iron_io_project_id
  worker_inst.iron_worker_task_id = @iron_worker_task_id
  worker_inst.params = @params

  worker_inst.run
end
RUNNER
        end
      end

      def runtime
        'ruby'
      end

      def runner
        'runner.rb'
      end
    end
  end
end

IronWorkerNG::Code::Base.register_type(:name => 'ruby', :klass => IronWorkerNG::Code::Ruby)
