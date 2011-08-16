require 'rake'
require 'rake/rdoctask'
require 'spec/rake/spectask'
require 'spec'

desc 'Generate documentation for the mem_cache_store_with_delete_groups plugin.'
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = 'mem_cache_store_with_delete_groups'
  rdoc.options << '--line-numbers' << '--inline-source'
  rdoc.rdoc_files.include('README')
  rdoc.rdoc_files.include('lib/**/*.rb')
end