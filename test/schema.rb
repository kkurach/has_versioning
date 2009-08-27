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

require File.dirname(__FILE__) + '/has_versioning_models'

ActiveRecord::Schema.define(:version => 1) do

  create_table :articles, :force => true do |t|
    t.string :title
    #t.integer :version
  end
  
  Article.create_versioned_table(:force => true)

  create_table :users, :force => true do |t|
    t.string :name
    t.integer :version
  end
  
  User.create_versioned_table(:force => true)
  
  create_table :cars, :force => true do |t|
    t.string :color
    t.integer :user_id
    t.integer :version
  end
  
  Car.create_versioned_table(:force => true)
  
  create_table :engines, :force => true do |t|
    t.integer :power
    t.integer :car_id
    t.integer :version
  end
  
  Engine.create_versioned_table(:force => true)

  create_table :dogs, :force => true do |t|
    t.string :name
    t.integer :user_id
    t.integer :version
  end
  
  Dog.create_versioned_table(:force => true)
  
  create_table :changelists, :force => true do |t|
    t.string :who
    t.string :desc
  end

  create_table :changes , :force => true do |t|
    t.integer :changelist_id
    t.string  :class_name
    t.integer :row_id
    t.string  :change_type
  end
 
  # TEST FOR RELATIONS WITH CONDITIONS

  create_table :user_with_conditions, :force => true do |t|
    t.string :name
    t.integer :version
  end
  UserWithCondition.create_versioned_table(:force => true)
  
  create_table :car_with_conditions, :force => true do |t|
    t.string :color
    t.integer :user_with_condition_id
    t.integer :version
  end
  CarWithCondition.create_versioned_table(:force => true)
  
  # TEST INHERITANCE
  
  create_table :shapes, :force => true do |t|
    t.string :color
    t.string :type
    t.integer :version
  end
  Shape.create_versioned_table(:force => true)
  
  [:circles, :rectangles].each do |x|
    
    create_table "#{x}", :force => true do |t|
      t.string :color
      t.string :type
      t.integer :version
    end
  end
  Circle.create_versioned_table(:force => true)
  Rectangle.create_versioned_table(:force => true)

end

