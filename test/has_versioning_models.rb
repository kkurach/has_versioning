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
# HAS MANY AND HAS ONE

class User < ActiveRecord::Base
  has_versioning
  has_many :cars, :order => "id", :versioned => true
  has_many :dogs, :order => "updated_at"

end

class Dog < ActiveRecord::Base
  belongs_to :user
  has_versioning
end

class Car < ActiveRecord::Base
  belongs_to :user
  has_one :engine
  has_versioning
end

class Engine < ActiveRecord::Base
  has_versioning
  belongs_to :car
end

class Article < ActiveRecord::Base
  has_versioning
end


# HAS MANY WITH CONDITIONS
class UserWithCondition < ActiveRecord::Base
  has_versioning
  has_many :red_cars,  :class_name => 'CarWithCondition', :conditions => 'car_with_conditions.color = \'red\'', :versioned => true
  has_many :other_cars, :class_name => 'CarWithCondition', :conditions => 'car_with_conditions.color = \'blue\' OR car_with_conditions.color = \'green\'', :versioned => true
end

class CarWithCondition < ActiveRecord::Base
  has_versioning
  belongs_to :user_with_condition
end

# INHERITANCE

class Shape < ActiveRecord::Base
  has_versioning
end

class Rectangle < Shape
  has_versioning
end

class Circle < Shape
  has_versioning
end

# HAS MANY THROUGH

class Writer < ActiveRecord::Base
  has_versioning
  has_many :pen_writers, :versioned => true
  has_many :pens, :through => :pen_writers, :versioned => true
  has_many :refills, :through => :pens, :versioned => true
end

class PenWriter < ActiveRecord::Base
  has_versioning
  belongs_to :writer
  belongs_to :pen
end

class Pen < ActiveRecord::Base
  has_versioning
  has_many :pen_writers, :versioned => true
  has_many :pens, :through => :pen_writers, :versioned => true
  has_many :pen_refills , :versioned => true
  has_many :refills, :through => :pen_refills, :versioned => true
end

class PenRefill < ActiveRecord::Base
  has_versioning
  belongs_to :pen
  belongs_to :refill
end

class Refill < ActiveRecord::Base
  has_many :pens, :through => :pen_refills
  has_versioning
end

# Unit Test HELPER
class Test::Unit::TestCase
  MAX_CL_NUMBER = ActiveRecord::HasVersioning::MAX_CL_NUMBER

  def teardown
    Change.delete_all
    Changelist.delete_all

    [Article, Car, Dog, Engine, User, Writer, PenWriter, Pen, PenRefill, Refill].each do |x|
      x.delete_all
    end
  end

end

