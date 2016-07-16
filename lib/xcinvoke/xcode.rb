require 'liferaft'
require 'open3'

module Liferaft
  class Version
    unless instance_methods.include?(:other)
      def <=>(other)
        if self == other
          0
        elsif self < other
          -1
        else
          1
        end
      end
    end
  end
end

module XCInvoke
  class Xcode
    extend Enumerable

    attr_reader :developer_dir, :toolchain

    def initialize(path, toolchain: nil)
      @developer_dir = Pathname(path)
      @toolchain = toolchain
    end

    def self.selected
      dir, = Open3.capture2('xcode-select', '-p', err: '/dev/null')
      new(dir.strip)
    end

    def self.each(&blk)
      return enum_for __method__ unless blk

      xcodes, = Open3.capture2(
        'mdfind',
        "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'",
        err: '/dev/null',
      )
      xcodes = xcodes.split("\n").map(&:strip)
      xcodes = xcodes.map do |xc|
        xc = Pathname(xc) + 'Contents/Developer'
        new(xc)
      end
      xcodes.each(&blk)
    end

    def self.each_with_toolchains(&block)
      return enum_for __method__ unless block

      minimum_for_toolchains =
        Liferaft::Version.new(Liferaft.version_string_create(7, 3, 0))
      all.flat_map do |xc|
        next xc if xc.version < minimum_for_toolchains
        toolchains.map { |tc| new(xc.developer_dir, toolchain: tc) } << xc
      end.each(&block)
    end

    def self.toolchains
      toolchain_base = '/Library/Developer/Toolchains'
      toolchain_dirs = [toolchain_base, '~' + toolchain_base]
      toolchain_dirs.flat_map do |toolchain_dir|
        toolchain_dir = Pathname(toolchain_dir).expand_path
        next [] unless toolchain_dir.directory?
        toolchain_dir.children.map(&:realpath).uniq.select(&:directory?)
      end
    end

    def self.all
      to_a
    end

    def self.find_swift_version(swift_version)
      swift_version = Gem::Version.create(swift_version)
      each_with_toolchains.select do |xc|
        xc.swift_version == swift_version
      end.max
    end

    def swift_version
      info = swift_info
      Gem::Version.new(info.first) if info
    end

    def build_number
      info = xcodebuild_info
      info[1] if info
    end

    def version
      build = build_number
      Liferaft::Version.new(build) if build
    end

    def <=>(other)
      version <=> other.version
    end

    def xcrun(cmd, env: {}, err: false)
      env = env.merge(as_env)

      cmd[0] = which!(cmd.first, env: env)
      case err
      when :merge
        oe, = Open3.capture2e(env, *cmd)
        oe
      else
        o, e, = Open3.capture3(env, *cmd)
        err ? [o, e] : o
      end
    end

    def as_env
      {
        'DEVELOPER_DIR' => developer_dir.to_path,
        'DYLD_FRAMEWORK_PATH' =>
          unshift_paths(ENV['DYLD_FRAMEWORK_PATH'], dyld_framework_paths),
        'DYLD_LIBRARY_PATH' =>
          unshift_paths(ENV['DYLD_LIBRARY_PATH'], dyld_library_paths),
        'PATH' =>
          unshift_paths(ENV['PATH'], toolchain_bins),
      }
    end

    def dyld_framework_paths
      toolchain_dirs.map { |tc| tc + 'usr/lib' }
    end

    def dyld_library_paths
      toolchain_dirs.map { |tc| tc + 'usr/lib' }
    end

    def toolchain_bins
      toolchain_dirs.map { |tc| tc + 'usr/bin' }
    end

    def toolchain_dirs
      [toolchain,
       developer_dir + 'Toolchains/XcodeDefault.xctoolchain',
       developer_dir].compact
    end

    private

    def xcodebuild_info
      xcodebuild_info_regex = /\AXcode (.*?)\s*Build version (.*?)\s*\Z/i
      return unless xcrun(%w(xcodebuild -version)) =~ xcodebuild_info_regex
      [Regexp.last_match(1), Regexp.last_match(2)]
    end

    def swift_info
      swift_info_regex = /
        Swift \s version \s
        (#{Gem::Version::VERSION_PATTERN})
        \s
        \(
          (?:
            swift(?:lang)?-([\d\.]+)
          )?
      /ix
      return unless xcrun(%w(swift --version)) =~ swift_info_regex
      [Regexp.last_match(1), Regexp.last_match(2)]
    end

    def unshift_paths(paths, *new_paths)
      paths = (paths || '').split(File::PATH_SEPARATOR)
      paths.unshift(*new_paths.flatten.map(&:to_s))
      paths.join(File::PATH_SEPARATOR)
    end

    def which!(executable, env: ENV)
      if File.file?(executable) && File.executable?(executable)
        executable
      elsif paths = env.fetch('PATH') { '/usr/bin:/bin' }
        paths.split(File::PATH_SEPARATOR).find do |path|
          executable_path = File.expand_path(executable, path)
          if File.file?(executable_path) && File.executable?(executable_path)
            return executable_path
          end
        end
      end
      raise "Unable to find #{exe} in $PATH"
    end
  end
end
