require 'ostruct'
require 'json'
require 'base64'

require_relative 'api_client'

module IronWorkerNG
  class ClientProxyCaller
    def initialize(client, prefix)
      @client = client
      @prefix = prefix
    end

    def method_missing(name, *args, &block)
      full_name = @prefix.to_s + '_' + name.to_s
      if @client.respond_to?(full_name)
        @client.send(full_name, *args, &block)
      else
        super(name, *args, &block)
      end
    end
  end

  class Client
    attr_reader :api

    def initialize(options = {}, &block)
      @api = IronWorkerNG::APIClient.new(options)

      unless block.nil?
        instance_eval(&block)
      end
    end

    def token
      @api.token
    end

    def project_id
      @api.project_id
    end

    def method_missing(name, *args, &block)
      if args.length == 0
        IronWorkerNG::ClientProxyCaller.new(self, name)
      else
        super(name, *args, &block)
      end
    end

    def codes_list(options = {})
      IronCore::Logger.debug 'IronWorkerNG', "Calling codes.list with options='#{options.to_s}'"

      @api.codes_list(options)['codes'].map { |c| OpenStruct.new(c) }
    end

    # TODO: get rid of this when we have working filters
    def codes_whole_list(options = {})
      prev_level = IronCore::Logger.logger.level
      IronCore::Logger.logger.level = ::Logger::INFO

      result = []
      page = -1
      begin
        codes = codes_list({ :per_page => 100,
                             :page => page += 1
                           }.merge(options))
        result += codes
      end while codes.size == 100

      IronCore::Logger.logger.level = prev_level

      result
    end

    def codes_get(code_id)
      IronCore::Logger.debug 'IronWorkerNG', "Calling codes.get with code_id='#{code_id}'"

      OpenStruct.new(@api.codes_get(code_id))
    end

    def codes_create(code, options = {})
      IronCore::Logger.debug 'IronWorkerNG', "Calling codes.create with code='#{code.to_s}' and options='#{options.to_s}'"

      async = options.delete(:async) || options.delete('async')

      container_file = code.create_container

      if code.remote_build_command.nil?
        res = @api.codes_create(code.name, container_file, 'sh', '__runner__.sh', options)
      else
        builder_code_name = code.name + (code.name.capitalize == code.name ? '::Builder' : '::builder')

        IronCore::Logger.info 'IronWorkerNG', 'Uploading builder'

        @api.codes_create(builder_code_name, container_file, 'sh', '__runner__.sh', options)

        builder_task = tasks.create(builder_code_name, :code_name => code.name, :client_options => @api.options.to_json, :codes_create_options => options.to_json)

        if async
          IronCore::Logger.info 'IronWorkerNG', 'Running builder asynchronously'

          File.unlink(container_file)

          return builder_task.id
        end

        IronCore::Logger.info 'IronWorkerNG', 'Waiting for builder to complete'

        builder_task = tasks.wait_for(builder_task.id)

        unless builder_task.status == 'complete'
          log = tasks.log(builder_task.id)

          IronCore::Logger.error 'IronWorkerNG', 'Error while remote building worker: ' + log, IronCore::Error
        end

        res = JSON.parse(builder_task.msg)
      end

      File.unlink(container_file)

      OpenStruct.new(res)
    end

    def codes_delete(code_id)
      IronCore::Logger.debug 'IronWorkerNG', "Calling codes.delete with code_id='#{code_id}'"

      @api.codes_delete(code_id)

      true
    end

    def codes_revisions(code_id, options = {})
      IronCore::Logger.debug 'IronWorkerNG', "Calling codes.revisions with code_id='#{code_id}' and options='#{options.to_s}'"

      @api.codes_revisions(code_id, options)['revisions'].map { |c| OpenStruct.new(c) }
    end

    def codes_download(code_id, options = {})
      IronCore::Logger.debug 'IronWorkerNG', "Calling codes.download with code_id='#{code_id}' and options='#{options.to_s}'"

      @api.codes_download(code_id, options)
    end

    def tasks_list(options = {})
      IronCore::Logger.debug 'IronWorkerNG', "Calling tasks.list with options='#{options.to_s}'"

      @api.tasks_list(options)['tasks'].map { |t| OpenStruct.new(t) }
    end

    def tasks_get(task_id)
      IronCore::Logger.debug 'IronWorkerNG', "Calling tasks.get with task_id='#{task_id}'"

      OpenStruct.new(@api.tasks_get(task_id))
    end

    def tasks_create(code_name, params = {}, options = {})
      IronCore::Logger.debug 'IronWorkerNG', "Calling tasks.create with code_name='#{code_name}', params='#{params.to_s}' and options='#{options.to_s}'"

      res = @api.tasks_create(code_name, params.is_a?(String) ? params : params.to_json, options)

      OpenStruct.new(res['tasks'][0])
    end

    def tasks_create_legacy(code_name, params = {}, options = {})
      IronCore::Logger.debug 'IronWorkerNG', "Calling tasks.create_legacy with code_name='#{code_name}', params='#{params.to_s}' and options='#{options.to_s}'"

      res = @api.tasks_create(code_name, params_for_legacy(code_name, params), options)

      OpenStruct.new(res['tasks'][0])
    end

    def tasks_cancel(task_id)
      IronCore::Logger.debug 'IronWorkerNG', "Calling tasks.cancel with task_id='#{task_id}'"

      @api.tasks_cancel(task_id)

      true
    end

    def tasks_cancel_all(code_id)
      IronCore::Logger.debug 'IronWorkerNG', "Calling tasks.cancel_all with code_id='#{code_id}'"

      @api.tasks_cancel_all(code_id)

      true
    end

    def tasks_log(task_id)
      IronCore::Logger.debug 'IronWorkerNG', "Calling tasks.log with task_id='#{task_id}'"

      @api.tasks_log(task_id)
    end

    def tasks_set_progress(task_id, options = {})
      IronCore::Logger.debug 'IronWorkerNG', "Calling tasks.set_progress with task_id='#{task_id}' and options='#{options.to_s}'"

      @api.tasks_set_progress(task_id, options)

      true
    end

    def tasks_wait_for(task_id, options = {})
      IronCore::Logger.debug 'IronWorkerNG', "Calling tasks.wait_for with task_id='#{task_id}' and options='#{options.to_s}'"

      options[:sleep] ||= options['sleep'] || 5

      task = tasks_get(task_id)

      while task.status == 'queued' || task.status == 'running'
        yield task if block_given?
        sleep options[:sleep]
        task = tasks_get(task_id)
      end

      task
    end

    def tasks_retry(task_id, options = {})
      IronCore::Logger.debug 'IronWorkerNG', "Calling tasks.retry with task_id='#{task_id}' and options='#{options.to_s}'"

      res = @api.tasks_retry(task_id, options)

      OpenStruct.new(res['tasks'][0])
    end

    def schedules_list(options = {})
      IronCore::Logger.debug 'IronWorkerNG', "Calling schedules.list with options='#{options.to_s}'"

      @api.schedules_list(options)['schedules'].map { |s| OpenStruct.new(s) }
    end

    def schedules_get(schedule_id)
      IronCore::Logger.debug 'IronWorkerNG', "Calling schedules.get with schedule_id='#{schedule_id}"

      OpenStruct.new(@api.schedules_get(schedule_id))
    end

    def schedules_create(code_name, params = {}, options = {})
      IronCore::Logger.debug 'IronWorkerNG', "Calling schedules.create with code_name='#{code_name}', params='#{params.to_s}' and options='#{options.to_s}'"

      res = @api.schedules_create(code_name, params.is_a?(String) ? params : params.to_json, options)

      OpenStruct.new(res['schedules'][0])
    end

    def schedules_create_legacy(code_name, params = {}, options = {})
      IronCore::Logger.debug 'IronWorkerNG', "Calling schedules.create_legacy with code_name='#{code_name}', params='#{params.to_s}' and options='#{options.to_s}'"

      res = @api.schedules_create(code_name, params_for_legacy(code_name, params), options)

      OpenStruct.new(res['schedules'][0])
    end

    def schedules_cancel(schedule_id)
      IronCore::Logger.debug 'IronWorkerNG', "Calling schedules.cancel with schedule_id='#{schedule_id}"

      @api.schedules_cancel(schedule_id)

      true
    end

    def projects_get
      IronCore::Logger.debug 'IronWorkerNG', "Calling projects.get"

      res =@api.projects_get

      OpenStruct.new(res)
    end

    def params_for_legacy(code_name, params)
      if params.is_a?(String)
        params = JSON.parse(params)
      end

      attrs = {}

      params.keys.each do |k|
        attrs['@' + k.to_s] = params[k]
      end

      attrs = attrs.to_json

      {:class_name => code_name, :attr_encoded => Base64.encode64(attrs), :sw_config => {:project_id => project_id, :token => token}}.to_json
    end
  end
end
