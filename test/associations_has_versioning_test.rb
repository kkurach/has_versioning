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

require File.dirname(__FILE__) + '/test_helper'
require 'flexmock/test_unit'
require File.dirname(__FILE__) + '/has_versioning_models'


class HasManyThroughTests < Test::Unit::TestCase
  def test_hmt_simple
    w1 = Writer.create(:name => 'karol')
    w2 = Writer.create(:name => 'nick' )
    p1 = Pen.create(:color => 'blue')
    p2 = Pen.create(:color => 'red')
    
    require 'pp'

    cl1 = Changelist.record! do
      w1.pens << p1
    end
    cl2 = Changelist.record! do
      w1.pens << p2
    end

    pp Writer.dump
    puts "--"
    pp PenWriter.dump
    puts "--"
    pp Pen.dump
    puts "at_changelist(#{cl1.id}) = "
    pp w1.at_changelist(cl1.id).pens
  end

end

class BelongsToTests < Test::Unit::TestCase 
  
  def test_belongs_to_simple
    u = User.create(:name => 'joel')
    c = Car.create(:color => 'yellow')
    c2 = Car.create(:color => 'pink')
    cl = Changelist.record! { u.cars << c }
    u.cars << c2

    u.name = 'dan'
    cl2 = Changelist.record! { u.save! }
    
    assert_equal 'dan', c.user.name
    assert_equal 'joel', c.user.at_changelist(cl.id).name
    assert_equal 'joel',  c.at_changelist(cl.id).user.name
    assert_equal 1, c.at_changelist(cl.id).user.cars.count
    assert_equal 2, c.at_changelist(cl.id+1).user.cars.size
  end

  
end

class HasManyTestWithConditions < Test::Unit::TestCase
  def test_user_has_cars_with_conditions
    u = UserWithCondition.new
    c1 = CarWithCondition.new
    c2 = CarWithCondition.new

    cl = Changelist.record! do
      u.name = 'karol'
      u.save!
      c1.color = 'red'
      c1.save!
      u.red_cars << c1

      c2.color = 'blue'
      c2.save!
      u.other_cars << c2
    end


    c3 = CarWithCondition.new
    c3.color = 'green'
    c3.save!

    u.red_cars << c3
    u.other_cars << c3


    cmp = Proc.new { |x,y| x.id <=> y.id }

    assert_equal u.red_cars, [c1]
    assert_equal u.other_cars.sort(&cmp), [c2,c3].sort(&cmp)

    assert_equal u.at_changelist(cl.id).red_cars, [c1]
    assert_equal u.at_changelist(cl.id).other_cars, [c2]

    assert_equal u.at_changelist(cl.id+1).red_cars.map(&:dup),
                 u.red_cars.map(&:dup)

    assert_equal u.at_changelist(cl.id+2).other_cars.sort(&cmp).map(&:dup),
                 u.other_cars.sort(&cmp).map(&:dup)

  end
end


class HasManyTestWithoutConditions < Test::Unit::TestCase

  def test_at_changelist_shows_history_correct_for_has_many
    u = User.new

    cl = Changelist.record! { u.name = 'karol'; u.save! }

    start_id = cl.id

    c1 = Car.create(:color => 'red')    # +1
    c2 = Car.create(:color => 'green')  # +2
    c3 = Car.create(:color => 'blue')   # +3

    Changelist.record! do               # +4
      u.cars << c1
      u.cars << c2
    end
    u.cars << c3                        # +5

    c1.color = 'black'
    c1.save!                            # +6



    assert_equal  2, u.at_changelist(start_id+4).cars.count
    assert_equal  3, u.at_changelist(start_id+5).cars.count

    assert_equal  ['blue','green','red'],
                  u.at_changelist(start_id+5).cars.map(&:color).sort

    assert_equal  ['black','blue','green'],
                  u.at_changelist(start_id+6).cars.map(&:color).sort


    Changelist.record! do               # +7
      c2.color = 'black'
      c2.save!
    end

    u.cars.delete(c3)                   # +8

    assert_equal  ['black','black', 'blue'],
                  u.at_changelist(start_id+7).cars.map(&:color).sort


    cmp = Proc.new { |x,y| x.id <=> y.id }

    # FIXME: find more gentle way to compare (insted of .map(&:dup) )
    assert_equal  u.at_changelist(start_id+7).cars.map(&:color).sort,   # FIXME: should be whole dup here
                  [c1,c2,c3].map(&:color).sort

    assert_equal  u.at_changelist(start_id+8).cars.map(&:id).sort,
                  [c1.id, c2.id].sort
  end

  def test_has_many_does_not_breake_when_elem_does_not_exists
    u = User.create
    c1 = Car.create
    c2 = Car.create

    u.cars << c1
    u.cars.delete(c2)
    assert_equal true, u.cars.include?(c1)
    assert_equal false, u.cars.include?(c2)
  end

  def test_from_spreadsheet_one_to_many
    # let User = A, Cars = C

    x = Car.create

    # 1
    u = User.new
    u.name = 'karol'
    chg = Changelist.record!{ u.save! }

    start_id = chg.id

    # 2
    c = Car.new
    c.color = 'red'
    c.save!

    assert_equal nil, c.user_id
    assert_equal 'red', c.color

    c_ver = c.versions.first
    assert_equal c.id, c_ver.car_id
    assert_equal nil, c_ver.user_id
    assert_equal start_id + 1, c_ver.cl_create

    # 3
    u.cars << c
    
    c_ver1 = c.get_version(1, { :car_id => c.id})
    c_ver2 = c.get_version(2, { :car_id => c.id})


    assert_equal u.id, c.user_id
    assert_equal start_id + 2, c_ver1.cl_destroy
    assert_equal u.id, c_ver2.user_id
    assert_equal start_id + 2, c_ver2.cl_create

    # 4
    u.cars.delete(c)

    c_ver2 = c.get_version(2, { :car_id => c.id})
    c_ver3 = c.get_version(3, { :car_id => c.id})
    

    assert_equal nil, c.user_id
    assert_equal start_id + 3, c_ver2.cl_destroy
    assert_equal nil, c_ver3.user_id
    assert_equal 'red', c_ver3.color
    assert_equal start_id + 3, c_ver3.cl_create
    assert_equal MAX_CL_NUMBER, c_ver3.cl_destroy

    # 5
    u.cars << c

    c_ver3 = c.get_version(3, { :car_id => c.id})
    c_ver4 = c.get_version(4, { :car_id => c.id})

    assert_equal 4, c.versions.to_ary.size
    assert_equal 1, u.versions.to_ary.size
    assert_equal u.id, c.user_id
    assert_equal c_ver4.cl_create, c_ver3.cl_destroy
    assert_equal start_id + 4, c_ver4.cl_create
    assert_equal MAX_CL_NUMBER, c_ver4.cl_destroy


  end

  def test_has_many
    c1 = Car.new
    c2 = Car.new

    chg1 = Changelist.record! do
      c1.color = 'red'
      c2.color = 'blue'
      c1.save!
      c2.save!
    end
    
    c1ver1 = c1.get_version(1)

    assert_equal 1, c1ver1.version
    assert_equal chg1.id, c1ver1.cl_create
    assert_equal MAX_CL_NUMBER, c1ver1.cl_destroy
    assert_equal nil, c1ver1.user_id

    u1 = User.new
    chg2 = Changelist.record! do
      u1.name = 'nick'
      u1.save!
      u1.cars << c1
      u1.cars << c2
    end

    c1ver1 = c1.get_version(1)
    c1ver2 = c2.get_version(2)
    c2ver2 = c2.get_version(2)
    u1ver1 = u1.get_version(1)


    assert_equal 2, c1ver2.version
    assert_equal 2, c2ver2.version
    assert_equal 1, u1ver1.version
    assert_equal u1.id, c1ver2.user_id
    assert_equal u1.id, c2ver2.user_id
    assert_equal chg2.id, c1ver1.cl_destroy
    assert_equal chg2.id, c1ver2.cl_create

    c3 = Car.new
    c4 = Car.new
    u2 = User.new

    chg2 = Changelist.record! do
      u2.name = 'joel'
      u2.save!
      c3.color = 'green'
      c3.save!
      u2.cars << c3

      c3.color = 'pink'
      c3.save!
    end

    c4.color = 'purple'
    c4.save!

  end
end

class HasOneTests < Test::Unit::TestCase
  
  def test_has_one_simple

    c = Car.new
    e = Engine.new
    cl = Changelist.record!('set color and power') {
      c.color = 'red'
      e.power = 100
      c.save!
      e.save!
    }
    
    
    c.engine = e        # +1
    c.save!             # +1
    
    e.power = 150
    e.save!             # +2
    
    c.color = 'blue'  
    c.save!             # +3

    c.engine= nil       
    c.save!             # +4
    
    assert_equal 2, c.versions.size
    assert_equal 2, c.versions.size
    assert_equal 4, e.versions.size
    assert_equal 100, c.at_changelist(cl.id+1).engine.power
    assert_equal 150, c.at_changelist(cl.id+2).engine.power
    assert_equal c.at_changelist(cl.id+3).engine,  e.at_changelist(cl.id+3)
    assert_equal 100, c.at_changelist(cl.id+2).engine.at_changelist(cl.id+1).power
  end
end


