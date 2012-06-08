require 'iron_worker_ng'

p params

puts "ENV"
p ENV

puts "pwd: " + `pwd`
puts `ls -al`

class WorkerFile

  attr_accessor :wruntime
  attr_accessor :wname
  attr_accessor :exec_file
  attr_accessor :files

  def initialize(raw)
    @files = []

    puts 'evaling'
    eval(raw)
    puts 'done evaling '
  end

  def runtime(s)
    @wruntime = s
  end

  def exec(s)
    @exec_file = s
  end

  def name(s)
    @wname = s
  end

  def file(s)
    @files << s
  end

end


code = nil

def get_code_by_runtime(runtime)
  if runtime == "ruby"
    return IronWorkerNG::Code::Ruby.new()
  end
end

if params['worker_file_url']
  wfurl = params['worker_file_url']
  puts "worker_file_url: #{wfurl}"
  if wfurl.include?("github.com")
    require 'open-uri'

    raw_url = wfurl.sub("blob", "raw")
    p raw_url

    raw = open(raw_url).read
    puts "raw worker file:\n#{raw}"

    worker_file = WorkerFile.new(raw)
    puts "worker_file: " + worker_file.inspect

    endpoint_dir = File.dirname(raw_url)
    puts "endpoint_dir: " + endpoint_dir

    get_files = worker_file.files + [worker_file.exec_file]
    get_files.each do |f|
      open(f, 'w') do |file|
        url = "#{endpoint_dir}/#{f}"
        puts "Getting #{url}"
        file << open(url).read
      end
    end

    code = get_code_by_runtime(worker_file.wruntime)
    code.name = params['name'] || worker_file.wname
    code.merge_exec worker_file.exec_file
    worker_file.files.each do |f|
      code.merge_file f
    end

  else
    raise "I don't know how to get your worker code from this location."
  end
end

if params['build_command']
  puts "build_commmand: #{params['build_command']}"
  puts `#{params['build_command']}`
  code = IronWorkerNG::Code::Binary.new()
  code.name = params['name']
  code.merge_exec params['exec']

end


puts `ls -al`

# just for testing
#puts `./hello`

puts "Uploading code..."
@client = IronWorkerNG::Client.new(params)
p @client.codes_create(code)

