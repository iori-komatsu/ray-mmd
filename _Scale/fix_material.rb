def fix(original, filename)
  path_to_root = nil

  original.each_line do |line|
    line = line.strip()

    if line.include?("{{{ scale.fx")
      $stderr.puts "#{filename} is already converted."
      exit 0
    end

    if %r|^//| =~ line
      next
    end

    if %r|\#include +\"([./]*)material_common_2.0.fxsub\"| =~ line
      path_to_root = "../#{$1}"
    end
  end

  unless path_to_root
    $stderr.puts "#{filename} does not include material_common_2.0.fxsub."
    exit 1
  end

  new_code = <<EOS
// {{{ scale.fx
#include "#{path_to_root}shader/Scale.fxsub"
#define SCALING_ENABLED 1
// }}}

EOS

  new_code + original
end

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
    $stderr.puts "Usage: $0 MATERIAL_FILE"
    exit 1
  end

  filename = ARGV[0]
  open(filename) do |input|
    fixed = fix(input.read(), filename)
    dest = new_name(filename)
    open(dest, "w") do |output|
      output.write(fixed)
    end
    $stderr.puts "Success: #{filename} -> #{dest}"
  end
end

main()
