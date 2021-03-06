module IronWorkerNG
  module Code
    module Runtime
      module Mono
        include IronWorkerNG::Feature::Common::MergeExec::InstanceMethods

        def runtime_run_code(local, params)
          <<RUN_CODE
mono #{File.basename(@exec.path)} #{params}
RUN_CODE
        end
      end
    end
  end
end
