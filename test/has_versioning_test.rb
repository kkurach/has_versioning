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

class FindAndScopeTests < Test::Unit::TestCase

  def test_find_by_name_and_at_changelist
    
    u = User.new

    cl = Changelist.record! {
      u.name = 'karol'
      u.save!
    }

    u.name = 'nick'
    u.save!

    x = User.find_by_name("nick")
    assert_equal 'karol', x.at_changelist(cl).name 
    assert_equal 1, User.count
    assert_equal 'karol', User.find_by_name("nick").at_changelist(cl).name
  end

  def test_find_by_name_and_has_many
    u = User.new

    cl = Changelist.record! {
      u.name = 'karol'
      u.save!
    }

    c1 = Car.create(:color => 'red')
    c2 = Car.create(:color => 'blue')
    c3 = Car.create(:color => 'green')

    cl2 = Changelist.record! {
      u.cars << c1
      u.cars << c2
    }
    u.name = 'nick'
    u.save!                        # cl2.id + 1
    u.cars << c3                   # cl2.id + 2
    
    assert_equal 2, User.find_by_name('nick').at_changelist(cl2.id).cars.count
    assert_equal ['blue', 'green', 'red'],
                 User.find_by_name('nick').cars.map(&:color).sort

    assert_equal ['blue', 'red'],
                 User.find_by_name('nick').at_changelist(cl2.id+1).cars.map(&:color).sort
    
    
    assert_equal 1, User.find(:all).size


    u.name = 'karol'
    u.save!

    
    assert_equal 3, User.find_by_name('karol').version
    assert_equal 0, User.find_by_name('karol').at_changelist(cl.id+3).cars.size
      
    # TODO: fix tests below  (id condition after  at_changelist)  # FIXME
#    assert_equal ['red'], User.find_by_name('nick').at_changelist(cl2.id).cars.              
#                          find(:all, :conditions => { :id => c1.id }).map(&:color)
#    nick = User.find_by_name('nick').at_changelist(cl2.id)
#    assert_equal 'blue', nick.cars.find(:all,:conditions => ['id <= ?', c2.id], :order => :id).last.color
  end

  def test_at_changelist_with_user_scope
    
    ret = nil
   
    u = User.create(:name => 'joel')
    car1 = Car.create(:color => 'red')
    car2 = Car.create(:color => 'blue')
    car3 = Car.create(:color => 'green')
    u.cars << car2
    u.cars << car3
    
    cl = Changelist.record! { u.name = 'shane'; u.save! }
    u.cars << car1
    
    cars1 = []
    cars2 = []
    Car.send(:with_scope, :find => { :conditions => { :color => 'red' } }) do
      cars1 = u.at_changelist(cl.id).cars.find(:all)
      cars2 = u.at_changelist(cl.id+1).cars.find(:all).map(&:color)
    end

    assert_equal [], cars1
    assert_equal ['red'], cars2
  end

  def test_at_changelist_and_count
    
    u = User.create(:name => 'joel')
    car1 = Car.create(:color => 'red')
    car2 = Car.create(:color => 'blue')
    car3 = Car.create(:color => 'green')
    cl1 = Changelist.record! { u.cars << car1 }
    cl2 = Changelist.record! { u.cars << car2 }
    cl3 = Changelist.record! { u.cars << car3 }

    assert_equal 1, u.at_changelist(cl1.id).cars.count
    assert_equal 3*2, Car.find_all_versions.size
  end

end


class InheritanceTests < Test::Unit::TestCase
  def test_inheritance_at_changelist
    r = Rectangle.new

    r.color = 'red'
    cl = Changelist.record! { r.save! }

    r.color = 'green'
    r.save!

    assert_equal 'Rectangle', r.type
    assert_equal 'red', r.at_changelist(cl.id).color
    assert_equal 'green', r.at_changelist(cl.id+1).color
  end

end

class VersionAndChangelistTest < Test::Unit::TestCase

  def test_simple
    a = Article.new
    a.title = 'aaa'
    a.save!
  end

  def doit_rev(a)
    a.title = 'foo'
    a.save!
    a.title = 'bar'
    a.save!
  end

  def test_at_version
    a = Article.new
    doit_rev(a)
    assert_equal 'foo', a.at_version(1).title
    assert_equal 'bar', a.at_version(2).title
  end

  def test_revert_to_version
    a = Article.new
    a.title = 'foo'
    a.save!

    old_id = a.id
    old_title = a.title
    old_version = a.version

    a.title = 'bar'
    a.save!

    a.revert_to_version(1)

    assert_equal a.id, old_id
    assert_equal a.title, old_title
    assert_equal a.version, old_version + 2
  end

  def doit_cl(a, b)
    c1 = Changelist.record! do
      a.title = 'a_foo'
      a.save!
    end
    c2 = Changelist.record! do
      b.title = 'b_foo'
      b.save!
    end
    c3 = Changelist.record! do
      a.title = 'a_bar'
      a.save!
    end
    c4 = Changelist.record! do
      b.title = 'b_bar'
      b.save!
    end
    [c1.id,c2.id,c3.id,c4.id]
  end

  def test_at_changelist
    a = Article.new
    b = Article.new

    v = doit_cl(a, b)
    assert_raise RuntimeError do
      a.at_version(v[0] - 1)
    end

    assert_equal 'a_foo', a.at_changelist(v[0]).title
    assert_equal 'a_foo', a.at_changelist(v[1]).title
    assert_equal 'a_bar', a.at_changelist(v[2]).title
    assert_equal 'a_bar', a.at_changelist(v[3]).title
  end

  def test_revert_to_changelist
    a = Article.new
    b = Article.new
    v = doit_cl(a, b)

    assert_equal 'a_bar', a.title

    a.revert_to_changelist(v[1])
    assert_equal 'a_foo', a.title

    a.revert_to_changelist(v[2])
    assert_equal 'a_bar', a.title
  end

end

class CreateUpdateDestroyTest < Test::Unit::TestCase


  def test_changelist_record

    a = Article.new
    b = Article.new

    c1 = Changelist.record! do
      a.title = 'c1__title_a_1'
      a.save
      a.title = 'c1__title_a_2'
      a.save
      b.title = 'c1__title_b_1'
      b.save
    end

    assert_equal 'c1__title_a_2', a.title
    assert_equal 2, a.version
    assert_equal 1, b.version

    c2 = Changelist.record! do
      a.title = 'c2__title_a_3'
      a.save
    end

    assert_equal 3, a.version

  end


  def test_save_and_update_objects
    count1 = Changelist.count
    a = Article.new

    c1 = Changelist.record! do
      a.save!
    end

    b = Article.new
    c2 = Changelist.record! do
      a.title = 'bla'
      a.save!
      b.save!
    end
    count2 = Changelist.count

    v = a.versions.sort { |x,y| x.version <=> y.version }

    assert_equal 2, count2-count1
    assert_equal c1.id, v[0].cl_create
    assert_equal c2.id, v[0].cl_destroy
    assert_equal c2.id, v[1].cl_create
    assert_equal MAX_CL_NUMBER, v[1].cl_destroy
    assert_equal c2.id, b.versions[0].cl_create
    assert_equal MAX_CL_NUMBER, b.versions[0].cl_destroy

  end

  def test_destroy_objects

      cnt = Article.count
      a = Article.new
      c1 = Changelist.record! do
        a.save!
      end

      c2 = Changelist.record! do
        a.title = 'bla2'
        a.save!
      end

      id = a.id


      c3 = Changelist.record! do
        a.destroy
      end
      
      v = a.versions.sort { |x,y| x.version <=> y.version }

      assert_equal c1.id, v[0].cl_create
      assert_equal c2.id, v[0].cl_destroy
      assert_equal c2.id, v[1].cl_create
      assert_equal c3.id, v[1].cl_destroy
      assert_equal Article.count, cnt
  end

  def test_create_default_changelist

    n_chglst = Changelist.count

    a = Article.new;
    a.title = 'aaa'
    a.save!

    assert_equal (n_chglst + 1), Changelist.count
  end

  def test_save_failed
      a = Article.new
      a.save!
      Changelist.record! do
          a.destroy
      end
  end

  def test_changelists_nested
    a = Article.new
    b = Article.new

    Changelist.record! do
      a.save!
      assert_raise RuntimeError do
        Changelist.record! do
          b.save!
        end
      end

    end

  end

end

