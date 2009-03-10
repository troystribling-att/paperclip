module Paperclip
  class Definition
    attr_accessor :url, :path, :default_style, :default_path, :whiny_processing,
                  :storage, :storage_method

    def initialize options = {}
      @url = options[:url]
      @path = options[:path]
      @default_style = options[:default_style]
      @default_path = options[:default_path]
      @whiny_processing = options[:whiny_processing]
      @styles = options[:styles]

      @storage_method = options[:storage] || :filesystem
      @storage = Storage.for(@storage_method, options)
    end

    def style name
      Style.new
    end

    class Options
      def initialize options = {}
        @methods ||= []
        options.each do |key, value|
          methodize(key, value)
        end
      end

      def option_methods
        @methods
      end

      def methodize method, value
        (@methods ||= []) << method.to_sym
        (class << self; self; end).class_eval do
          attr_accessor method
        end
        instance_variable_set("@#{method}", value)
      end

      def method_missing method, *args, &block
        method, assign = method.to_s.split(/(=)/)
        if assign
          methodize(method, args.first)
        elsif block
          methodize(method, block)
        else
          nil
        end
      end

      def merge other
        result = self.class.new
        option_methods.each do |method|
          result.send("#{method}=", self.send(method))
        end
        other.option_methods.each do |method|
          result.send("#{method}=", other.send(method))
        end
        result
      end
    end

    class Storage < Options
      def self.for(method, options = {})
        self.const_get(method.to_s.camelize).new(options)
      end

      class Filesystem < Storage
        def initialize options = {}
          self.method = :filesystem
          super(options)
        end
      end

      class S3 < Storage
        attr_reader :permissions
        def initialize options = {}
          self.method      = :s3
          self.bucket      = options.delete(:bucket)
          self.permissions = options.delete(:s3_permissions)
          self.headers     = options.delete(:s3_headers)
          self.host_alias  = options.delete(:s3_host_alias)
          self.protocol    = options.delete(:s3_protocol)
          super(options)
        end

        def permissions= yaml
          case yaml
          when Hash then @permissions = yaml
          when IO, StringIO then @permissions = YAML.load(yaml)
          when String then @permissions = YAML.load_file(yaml)
          end
        end
      end
    end

    class Style < Options
      def initialize options = {}, format = nil
        if options.is_a? String
          geometry = options
          options = {}
        end
        self.geometry         = options.delete(:geomtry) || geometry
        self.format           = options.delete(:format) || format
        self.processors       = options.delete(:processors) || [:thumbnail]
        self.convert_options  = options.delete(:convert_options)
        self.whiny_processing = options.delete(:whiny_processing)
        self.whiny_processing = whiny_processing.nil? ? true : whiny_processing
        super(options)
      end
    end
  end
end