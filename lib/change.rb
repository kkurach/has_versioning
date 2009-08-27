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

class Change < ActiveRecord::Base
  belongs_to :changelist

  def self.create_versioning_table(options={})
    self.connection.create_table('changes', options) do |t|
      t.integer :changelist_id
      t.string  :class_name
      t.integer :row_id
      t.string  :change_type
    end
  end
end
