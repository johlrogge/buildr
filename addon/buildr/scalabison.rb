require 'buildr/java'
require 'buildr/scala'

module Buildr
  # Provides ScalaBison compile tasks. Require explicitly using <code>require "buildr/scalabison"</code>.
  module ScalaBison
    SCALA_BISON = 'edu.uwm.cs:scalabison:jar:0.78'
    
    def scalabison(*dirs)
      target = _(:target, :generated, :scalabison)
      task = file target
      
      dirs.each do |dir|
        task.enhance [dir]
        dir = dir.to_s
        
        cwd = Dir.pwd
        Dir.chdir dir
        
        Dir.glob "**/*.y" do |fname|
          md = fname.match /^(([^\/\\]+[\/\\])*)([^\.]+)\.y$/
          
          cname = md[3] || md[2]
          package = md[1].split(File::SEPARATOR)
          
          name = File::SEPARATOR + (package.join File::SEPARATOR) + File::SEPARATOR + cname
          fname = dir + name + '.y'
          
          ftask = file target + name + 'Parser.scala' => fname do
            dname = target + File::SEPARATOR + (package.join File::SEPARATOR)
            FileUtils.mkdir_p dname
            
            cwd = Dir.pwd
            Dir.chdir dname
            
            trace "Running bison against #{fname}"
            system 'bison', '-v', '--no-parser', fname
            
            FileUtils.cp fname, dname
            
            Java.classpath << Buildr::Scala::Scalac.dependencies
            Java.classpath << artifact(SCALA_BISON)
            
            args = ['-v', cname + '.y']
            
            trace "Running ScalaBison against #{cname + '.y'}"
            
            Java.load
            Java.edu.uwm.cs.cool.meta.parser.RunGenerator.main(args.to_java(Java.java.lang.String))
            
            FileUtils.rm cname + '.y'
            
            Dir.chdir cwd
          end
          
          file(dir).enhance [ftask]
        end
        
        Dir.chdir cwd
      end
      
      task.to_s
    end
  end
  
  class Project
    include ScalaBison
  end
end
