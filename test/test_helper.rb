# Copyright 2009 Google Inc.
# Original author: Karol Kurach <kkurach (at) gmail (dot) com>
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'rubygems'
require 'test/unit'
require File.dirname(__FILE__) + '/../../../../config/boot'
require 'active_record'
require File.dirname(__FILE__) + '/../lib/has_versioning'
require File.dirname(__FILE__) + '/../lib/associations_has_versioning'
require File.dirname(__FILE__) + '/../init'

config = YAML::load(IO.read(File.dirname(__FILE__) + '/database.yml'))
ActiveRecord::Base.logger = Logger.new(File.dirname(__FILE__) + '/debug.log')
ActiveRecord::Base.establish_connection(config[ENV['DB'] || 'sqlite3'])
load(File.dirname(__FILE__) + '/schema.rb')
