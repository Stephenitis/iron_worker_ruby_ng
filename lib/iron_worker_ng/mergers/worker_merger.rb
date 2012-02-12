module IronWorkerNG
  module Mergers
    class WorkerMerger < IronWorkerNG::Mergers::BaseMerger
      attr_reader :path
      attr_reader :name

      def initialize(path, name)
        @path = File.expand_path(path)
        @name = name
      end

      def merge(zip)
        zip.add('./' + File.basename(@path), @path)
      end

      def hash_string
        Digest::MD5.hexdigest(@path + @name)
      end

      def init_code
        "worker_file_name = '#{File.basename(@path)}'\nworker_class_name='#{@name}'"
      end
    end

    module InstanceMethods
      def merge_worker(path, name = nil)
        @merges ||= []

        worker = @merges.find { |m| m.class == IronWorkerNG::Mergers::WorkerMerger }
        return unless worker.nil?

        if name == nil
          name = File.basename(path).gsub(/\.rb$/, '').capitalize.gsub(/_./) { |x| x[1].upcase }
        end

        @merges << IronWorkerNG::Mergers::WorkerMerger.new(path, name)
      end
    end
  end
end
