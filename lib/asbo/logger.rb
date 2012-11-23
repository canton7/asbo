require 'logger'

module ASBO
  module Logger
    def log
      Logger.logger
    end

    def self.logger
      return @logger if @logger

      @logger = ::Logger.new(MultiIO.new(STDERR, File.expand_path('~/.asbo.log')))
      @logger.level = ::Logger::INFO
      @logger.formatter = Proc.new do |severity, datetime, progname, msg|
        severity = "[#{severity}]".ljust(7)
        "#{severity}: #{msg}\n"
      end
      @logger
    end

    def self.verbose=(value)
      self.logger.level = value ? ::Logger::DEBUG : ::Logger::INFO
    end

    def self.included(klass)
      klass.extend(self)
    end

    class MultiIO
      def initialize(*targets)
        # Assume strings mean files
        @targets = targets.map do |t|
          t.is_a?(String) ? File.open(t, 'a') : t
        end
      end

      def write(*args)
        @targets.each{ |t| t.write(*args) }
      end

      def close
        @targets.each{ |t| t.close }
      end
    end
  end
end
