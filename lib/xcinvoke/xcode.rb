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

    attr_reader :developer_dir

    def initialize(path)
      @developer_dir = Pathname(path)
    end

    def self.selected
      dir, = Open3.capture2('xcode-select', '-p', err: '/dev/null')
      new(dir.strip)
    end

    def self.each(&blk)
      xcodes, = Open3.capture2('mdfind',
                               "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'",
                               err: '/dev/null')
      xcodes = xcodes.split("\n").map(&:strip)
      xcodes = xcodes.map do |xc|
        xc = Pathname(xc) + 'Contents/Developer'
        new(xc)
      end
      xcodes.each(&blk)
    end

    alias_method :all, :to_a

    def self.find_swift_version(swift_version)
      select { |xc| xc.swift_version == swift_version }.sort.last
    end

    def swift_info
      swift_info_regex = /Swift version ([\d\.]+) \(swift(?:lang)?-([\d\.]+)/i
      return unless xcrun(%w(swift --version)) =~ swift_info_regex
      [Regexp.last_match(1), Regexp.last_match(2)]
    end

    def swift_version
      info = swift_info
      info.first if info
    end

    def xcodebuild_info
      return unless xcrun(%w(xcodebuild -version)) =~ /\AXcode (.*?)\s*Build version (.*?)\s*\Z/i
      [Regexp.last_match(1), Regexp.last_match(2)]
    end

    def build_number
      info = xcodebuild_info
      info[1] if info
    end

    def version
      Liferaft::Version.new(build_number)
    end

    def <=>(other)
      version <=> other.version
    end

    def xcrun(cmd, env: {})
      env = env.merge(as_env)
      cmd = %w(xcrun) + cmd
      output, = Open3.capture2(env, *cmd, err: '/dev/null')
      output
    end

    def as_env
      {
        'DEVELOPER_DIR' => developer_dir.to_path,
        'DYLD_FRAMEWORK_PATH' => dyld_framework_path.to_path,
        'DYLD_LIBRARY_PATH' => dyld_library_path.to_path,
      }
    end

    def dyld_framework_path
      developer_dir + 'Toolchains/XcodeDefault.xctoolchain/usr/lib'
    end

    def dyld_library_path
      developer_dir + 'Toolchains/XcodeDefault.xctoolchain/usr/lib'
    end
  end
end
