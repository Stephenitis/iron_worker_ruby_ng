require_relative '../feature/ruby/merge_gem'

module IronWorkerNG
  module Code
    class Builder < IronWorkerNG::Code::Base
      def initialize(*args, &block)
        @features = []
        @fixators = []

        @base_dir = ''
        @dest_dir = ''

        runtime(:ruby)
      end

      def bundle(container)
        @exec = IronWorkerNG::Feature::Common::MergeExec::Feature.new(self, '__builder__.rb', {})

        super(container)

        if remote_build_command
          container.get_output_stream(@dest_dir + '__builder__.sh') do |builder|
            builder.write <<BUILDER_SH
# #{IronWorkerNG.full_version}
#{remote_build_command}
BUILDER_SH
          end
        end

        container.get_output_stream(@dest_dir + '__builder__.rb') do |builder|
          builder.write <<BUILDER_RUBY
# #{IronWorkerNG.full_version}

require 'json'

require 'iron_worker_ng'

IronWorkerNG::Feature::Ruby::MergeGem.merge_binary = true

code = IronWorkerNG::Code::Base.new(params[:code_name])

if File.exists?('__builder__.sh')
  pre_build_list = Dir.glob('__build__/**/**')

  exit 1 unless system('cd __build__ && sh ../__builder__.sh && cd ..')

  post_build_list = Dir.glob('__build__/**/**')

  (post_build_list.sort - pre_build_list.sort).each do |new_file|
    code.file(new_file, File.dirname(new_file[10 .. -1]))
  end
end

code.install(true)

client = IronWorkerNG::Client.new(JSON.parse(params[:client_options]))

res = client.codes.create(code, JSON.parse(params[:codes_create_options]))

client.tasks.set_progress(iron_task_id, :msg => res.marshal_dump.to_json)
BUILDER_RUBY
        end
      end
    end
  end
end
