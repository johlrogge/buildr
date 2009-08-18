require 'buildr/java'

module Buildr
  module GAE
    include Extension
    
    HOME = ENV['GAE_HOME'] or fail 'Are we forgetting something? GAE_HOME not set.'
    LIBS = Dir["#{HOME}/lib/user/**/*.jar"]

    GAE_SDK = Dir.glob(File.join(HOME, "lib", "user", "*.jar"))
    GAE_TOOLS = File.join(HOME, 'lib', 'appengine-tools-api.jar')
    GAE_SHARED = Dir.glob(File.join(HOME, "**", "shared", "*.jar"))

    class GAEConfig
      attr_reader :host, :email
      attr_writer :host, :email
      
      def options
	    back = []
		unless host.nil?
		  back << ['--host', host]
		end
		unless email.nil?
		  back << ['--email', email]
		end
		back
      end
    end
    
    first_time do
      Project.local_task :deploy
      Project.local_task :enhance
      Project.local_task :rollback
      Project.local_task :server
    end
    
    after_define do |project|
      appcfg = lambda do |action, *args|
        trace "#{HOME}/bin/appcfg.sh " + project.gae.options.join(' ') + action.to_s + args.join(' ')
        system "#{HOME}/bin/appcfg.sh", project.gae.options.join(' '), action.to_s, *args
      end
      
      dev_appserver = lambda do |*args|
        trace "#{HOME}/bin/dev_appserver.sh " + args.join(' ')
        system "#{HOME}/bin/dev_appserver.sh", *args
      end

      gae_enhance = lambda do |*sources|

        PROJECT_CP = project.compile.target.to_s

        project.ant('enhance') do |en|
          en.taskdef :name=>'enhance',
                     :classname=>'com.google.appengine.tools.enhancer.EnhancerTask',
                     :classpath=>GAE_TOOLS

          en.enhance :failonerror=>true do
            en.classpath :path=>[GAE_TOOLS, GAE_SHARED, GAE_SDK, PROJECT_CP].join(File::PATH_SEPARATOR)
            sources.map(&:to_s).each do |source|
              en.fileset :dir=>source.to_s, :includes=>"**/*.class"
            end
          end
        end
      end
      
      war = project.package :war
      
      war_dir = file project.path_to(:target, :war) => war do
        mkdir project.path_to(:target, :war) unless File.exists? project.path_to(:target, :war)
        
        cwd = Dir.pwd
        Dir.chdir project.path_to(:target, :war)
        
        cmd = "jar xf '#{war.name}'"
        trace cmd
        system cmd
        
        Dir.chdir cwd
      end
      
      desc 'deploy' 
      task :deploy => war_dir do
        appcfg.call :update, war_dir.name
      end

      desc 'enhance'
      task :enhance, :sources do |task, args|
        sources = args[:sources] or fail 'You must define sources to enhance!'
        gae_enhance.call(sources)
      end
      
      desc 'rollback'
      task :rollback => war_dir do
        appcfg.call :rollback, war_dir.name
      end
      
      desc 'dev_appserver'
      task :server => war_dir do
        dev_appserver.call war_dir.name
      end
    end
    
    def gae
      @gae || GAEConfig.new
    end
  end
  
  class Project
    include GAE
  end
end
