module Buildr
  module Doc
    include Extension
    
    class << self
      def select(lang)
        fail 'Unable to define doc task for nil language' if lang == nil
        engines.detect { |e| e.language.to_sym == lang.to_sym }
      end
      
      def engines
        @engines ||= []
      end
    end
    
    # Base class for any documentation provider.  Defines most
    # common functionality (things like @into@, @from@ and friends).
    class Base < Rake::Task
      
      # The target directory for the generated documentation files.
      attr_reader :target

      # Classpath dependencies.
      attr_accessor :classpath

      # Additional sourcepaths that are not part of the documented files.
      attr_accessor :sourcepath
        
      # Returns the documentation tool options.
      attr_reader :options
      
      class << self
        attr_accessor :language, :source_ext
        
        def specify(options)
          @language = options[:language]
          @source_ext = options[:source_ext]
        end
        
        def to_sym
          @symbol ||= name.split('::').last.downcase.to_sym
        end
      end

      def initialize(*args) #:nodoc:
        super
        @options = {}
        @classpath = []
        @sourcepath = []
        @files = FileList[]
        enhance do |task|
          rm_rf target.to_s
          mkdir_p target.to_s
          generate source_files, File.expand_path(target.to_s), options.merge(:classpath=>classpath, :sourcepath=>sourcepath)
          touch target.to_s
        end
      end
      
      # :call-seq:
      #   into(path) => self
      #
      # Sets the target directory and returns self. This will also set the Javadoc task
      # as a prerequisite to a file task on the target directory.
      #
      # For example:
      #   package :zip, :classifier=>'docs', :include=>doc.target
      def into(path)
        @target = file(path.to_s).enhance([self]) unless @target && @target.to_s == path.to_s
        self
      end

      # :call-seq:
      #   include(*files) => self
      #
      # Includes additional source files and directories when generating the documentation
      # and returns self. When specifying a directory, includes all source files in that directory.
      def include(*files)
        @files.include *files.flatten.compact
        self
      end

      # :call-seq:
      #   exclude(*files) => self
      #
      # Excludes source files and directories from generating the documentation.
      def exclude(*files)
        @files.exclude *files
        self
      end

      # :call-seq:
      #   with(*artifacts) => self
      #
      # Adds files and artifacts as classpath dependencies, and returns self.
      def with(*specs)
        @classpath |= Buildr.artifacts(specs.flatten).uniq
        self
      end

      # :call-seq:
      #   using(options) => self
      #
      # Sets the documentation tool options from a hash and returns self.
      #
      # For example:
      #   doc.using :windowtitle=>'My application'
      def using(*args)
        # TODO  need to be able to select different engines (e.g. vscaladoc)
        args.pop.each { |key, value| @options[key.to_sym] = value } if Hash === args.last
        args.each { |key| @options[key.to_sym] = true }
        self
      end

      # :call-seq:
      #   from(*sources) => self
      #
      # Includes files, directories and projects in the documentation and returns self.
      #
      # You can call this method with source files and directories containing source files
      # to include these files in the documentation, similar to #include. You can also call
      # this method with projects. When called with a project, it includes all the source files compiled
      # by that project and classpath dependencies used when compiling.
      #
      # For example:
      #   doc.from projects('myapp:foo', 'myapp:bar')
      def from(*sources)
        sources.flatten.each do |source|
          case source
          when Project
            self.enhance source.prerequisites
            self.include source.compile.sources
            self.with source.compile.dependencies 
          when Rake::Task, String
            self.include source
          else
            fail "Don't know how to generate documentation from #{source || 'nil'}"
          end
        end
        self
      end

      def prerequisites #:nodoc:
        super + @files + classpath + sourcepath
      end

      def source_files #:nodoc:
        @source_files ||= @files.map(&:to_s).map do |file|
          File.directory?(file) ? FileList[File.join(file, "**/*.#{self.class.source_ext}")] : file 
        end.flatten.reject { |file| @files.exclude?(file) }
      end

      def needed?() #:nodoc:
        return false if source_files.empty?
        return true unless File.exist?(target.to_s)
        source_files.map { |src| File.stat(src.to_s).mtime }.max > File.stat(target.to_s).mtime
      end
    end
    
    
    first_time do
      desc 'Create the documentation for this project'
      Project.local_task('doc')
    end

    before_define do |project|
      DocTask = Doc.select project.compile.language
      
      DocTask.define_task('doc').tap do |doc|
        doc.into project.path_to(:target, :doc)
        doc.using :windowtitle=>project.comment || project.name
      end
    end

    after_define do |project|
      project.doc.from project
    end

    # :call-seq:
    #   doc(*sources) => JavadocTask
    #
    # This method returns the project's documentation task. It also accepts a list of source files,
    # directories and projects to include when generating the docs.
    #
    # By default the doc task uses all the source directories from compile.sources and generates
    # documentation in the target/doc directory. This method accepts sources and adds them by calling
    # Buildr::Doc::Base#from.
    #
    # For example, if you want to generate documentation for a given project that includes all source files
    # in two of its sub-projects:
    #   doc projects('myapp:foo', 'myapp:bar').using(:windowtitle=>'Docs for foo and bar')
    def doc(*sources, &block)
      task('doc').from(*sources).enhance &block
    end
    
    def javadoc(*sources, &block)
      warn 'The javadoc method is deprecated and will be removed in a future release.'
      doc(sources, block)
    end
  end
  
  class Project
    include Doc
  end
end