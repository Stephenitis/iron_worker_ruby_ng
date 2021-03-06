module IronWorkerNG
  module Code
    module Runtime
      module Binary
        include IronWorkerNG::Feature::Common::MergeExec::InstanceMethods

        def runtime_run_code(local, params)
          <<RUN_CODE
chmod +x #{File.basename(@exec.path)}

#{File.basename(@exec.path)} #{params}
RUN_CODE
        end
      end
    end
  end
end
