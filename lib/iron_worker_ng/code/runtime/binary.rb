require_relative '../../feature/binary/merge_exec'

module IronWorkerNG
  module Code
    module Runtime
      module Binary
        def runtime_run_code(local = false)
          <<RUN_CODE
chmod +x #{File.basename(@exec.path)}

LD_LIBRARY_PATH=. ./#{File.basename(@exec.path)} "$@"
RUN_CODE
        end
      end
    end
  end
end
