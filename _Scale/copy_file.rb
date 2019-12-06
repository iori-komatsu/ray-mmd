def new_name(filename)
  dirname, basename = File.split(filename)
  parts = basename.split(".")
  if parts.length == 1
    name = parts[0] + "_scale"
  else
    ext = parts.pop()
    name = parts.join(".") + "_scale." + ext
  end
  File.join(dirname, name)
end

def main()
  if ARGV.length != 1
    $stderr.puts "Usage: $0 SRC_FILE"
    exit 1
  end

  filename = ARGV[0]
  open(filename) do |input|
    content = input.read()
    dest = new_name(filename)
    open(dest, "w") do |output|
      output.write(content)
    end
    $stderr.puts "Success: #{filename} -> #{dest}"
  end
end

main()
