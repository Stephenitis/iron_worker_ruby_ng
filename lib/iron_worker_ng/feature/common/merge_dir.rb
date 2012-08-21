require 'pathname'

module IronWorkerNG
  module Feature
    module Common
      module MergeDir
        class Feature < IronWorkerNG::Feature::Base
          attr_reader :path
          attr_reader :dest

          def initialize(code, path, dest)
            super(code)

            @path = path
            @dest = dest
            @dest = Pathname.new(dest).cleanpath.to_s + '/' unless @dest.empty?
          end

          def hash_string
            s = @path + @dest + File.mtime(rebase(@path)).to_i.to_s

            Dir.glob(rebase(@path) + '/**/**') do |path|
              s += path + File.mtime(path).to_i.to_s
            end

            Digest::MD5.hexdigest(s)
          end

          def bundle(container)
            IronCore::Logger.debug 'IronWorkerNG', "Bundling dir with path='#{@path}' and dest='#{@dest}'"

            container_add(container, @dest + File.basename(@path), rebase(@path))
          end
        end

        module InstanceMethods
          def merge_dir(path, dest = '')
            IronCore::Logger.info 'IronWorkerNG', "Merging dir with path='#{path}' and dest='#{dest}'"

            @features << IronWorkerNG::Feature::Common::MergeDir::Feature.new(self, path, dest)
          end

          alias :dir :merge_dir
        end
      end
    end
  end
end
