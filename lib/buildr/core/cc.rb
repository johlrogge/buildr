# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with this
# work for additional information regarding copyright ownership.  The ASF
# licenses this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.  See the
# License for the specific language governing permissions and limitations under
# the License.

require 'buildr/core/common'
require 'buildr/core/project'
require 'buildr/core/build'
require 'buildr/core/compile'

module Buildr
  module CC
    include Extension
    
    class CCTask < Rake::Task
      attr_accessor :delay
      attr_reader :project
      
      def initialize(*args)
        super
        @delay = 0.2
        enhance do
          monitor_and_compile
        end
      end
      
    private
      
      def associate_with(project)
        @project = project
      end
      
      def monitor_and_compile
        # we don't want to actually fail if our dependencies don't succede
        [:compile, 'test:compile'].each { |name| project.task(name).invoke }
        
        main_dirs = project.compile.sources.map(&:to_s)
        test_dirs = project.task('test:compile').sources.map(&:to_s)
        res_dirs = project.resources.sources.map(&:to_s)
        
        main_ext = Buildr::Compiler.select(project.compile.compiler).source_ext.map(&:to_s)
        test_ext = Buildr::Compiler.select(project.task('test:compile').compiler).source_ext.map(&:to_s)
        
        test_tail = if test_dirs.empty? then '' else ",{#{test_dirs.join ','}}/**/*.{#{test_ext.join ','}}" end
        res_tail = if res_dirs.empty? then '' else ",{#{res_dirs.join ','}}/**/*" end
        
        pattern = "{{#{main_dirs.join ','}}/**/*.{#{main_ext.join ','}}#{test_tail}#{res_tail}}"
        
        times, _ = check_mtime pattern, {}     # establish baseline
        
        dir_names = (main_dirs + test_dirs + res_dirs).map { |file| strip_filename project, file }
        if dir_names.length == 1
          info "Monitoring directory: #{dir_names.first}"
        else
          info "Monitoring directories: [#{dir_names.join ', '}]"
        end
        trace "Monitoring extensions: [#{main_ext.join ', '}]"
        
        while true
          sleep delay
          
          times, changed = check_mtime pattern, times
          unless changed.empty?
            info ''    # better spacing
            
            changed.each do |file|
              info "Detected changes in #{strip_filename project, file}"
            end
            
            in_main = main_dirs.any? do |dir|
              changed.any? { |file| file.index(dir) == 0 }
            end
            
            in_test = test_dirs.any? do |dir|
              changed.any? { |file| file.index(dir) == 0 }
            end
            
            in_res = res_dirs.any? do |dir|
              changed.any? { |file| file.index(dir) == 0 }
            end
            
            project.task(:compile).reenable if in_main
            project.task('test:compile').reenable if in_test
            
            project.task(:resources).filter.run if in_res
            project.task(:compile).invoke
            project.task('test:compile').invoke
          end
        end
      end
      
      def check_mtime(pattern, old_times)
        times = {}
        changed = []
        
        Dir.glob pattern do |fname|
          times[fname] = File.mtime fname
          if old_times[fname].nil? || old_times[fname] < File.mtime(fname)
            changed << fname
          end
        end
        
        # detect deletion (slower than it could be)
        old_times.each_key do |fname|
          changed << fname unless times.has_key? fname
        end
        
        [times, changed]
      end
      
      def strip_filename(project, name)
        name.gsub project.base_dir + File::SEPARATOR, ''
      end
    end
    
    first_time do
      Project.local_task :cc
    end
    
    before_define do |project|
      cc = CCTask.define_task :cc
      cc.send :associate_with, project
    end
    
    def cc
      task :cc
    end
  end
  
  class Project
    include CC
  end
end
