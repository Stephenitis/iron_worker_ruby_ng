require 'tmpdir'
require 'zip/zip'

require_relative 'features'
require_relative 'features/common'

module IronWorkerNG
  class Package
    include IronWorkerNG::Features::Common::InstanceMethods

    attr_reader :name

    @@registered_types = []
    
    def self.registered_types
      @@registered_types
    end
    
    def self.register_type(name, klass)
      @@registered_types << [name, klass]
    end

    def create_zip
      zip_name = Dir.tmpdir + '/' + Dir::Tmpname.make_tmpname("iron-worker-ng-", "code.zip")
      
      Zip::ZipFile.open(zip_name, Zip::ZipFile::CREATE) do |zip|
        bundle(zip)
        create_runner(zip)
      end

      zip_name
    end

    def create_runner(zip)
    end

    def runtime
      nil
    end

    def runner
      nil
    end
  end
end
