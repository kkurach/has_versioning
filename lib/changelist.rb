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

class Changelist < ActiveRecord::Base  #FIXME: not thread-safe
  has_many :changes
  cattr_accessor :current,
                 :autocreate

  @@current = nil

  def self.current
    unless @@current
       cl = Changelist.new
       cl.who = 'has_versioning bot'
       cl.desc = 'Sample description'
       cl.save!
       @@current = cl
       @@autocreate = true
    end
    @@current
  end

  def self.after_save_change
    return unless @@autocreate
    @@current.save!
    @@current = nil
    @@autocreate = false
  end

  def self.info(changelist_num)
    Changelist.find(changelist_num).info
  end

  def self.record!(description="")

    raise RuntimeError, "Changelists can't be nested" unless @@current.nil?

    chglst = Changelist.new
    chglst.desc = description
    chglst.save!

    @@current = chglst

    yield

    @@current = nil

    if chglst.changes.empty?  # don't save empty changelist
      chglst.destroy
      return nil
    end

    chglst
  end

  def info
    self.changes.each do |chg|
      puts "class_name = #{chg.class_name}, row_id = #{chg.row_id}"
    end
  end

end
